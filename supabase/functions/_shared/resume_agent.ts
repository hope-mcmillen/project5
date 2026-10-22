// parse-resume agent (AI-07, PRD §8.1). The resume is read in memory and never
// stored: only the verified experiences, skills, and education are saved, as a
// new draft profile version for the caller. Storage/DB access is behind
// ProfileStore so the whole flow runs in tests without Supabase.
//
//   PARSING_LAYOUT  sniff the file type from its bytes, extract text, sanitize
//   EXTRACTING      extract (structured output) → verify (code) → repair (LLM) → verify …
//   NORMALIZING     evidence + roles check, years, taxonomy mapping, experiences
//   READY           save_parsed_profile() writes the version, skills, and experiences atomically
//
// The repair loop is bounded: at most maxRepairRounds extra LLM calls, none once
// less than REPAIR_MIN_REMAINING_MS of the deadline is left, and it stops as
// soon as a round doesn't improve the result. Whatever still fails verification
// after the last round is dropped, never saved. Any error ends in FAILED with a
// failure_reason; the PARSE_TIMEOUT_MS deadline does too.
import { DOCX_MIME, extractText, PDF_MIME, UnsupportedFile } from "./extract_text.ts";
import type { LlmProvider } from "./llm.ts";
import { normalizeSkills, type SkillIndex } from "./normalize.ts";
import {
  buildDraftProfile,
  type Experience,
  type Finding,
  reviewExtraction,
  skillKey,
  verifiedExperiences,
} from "./profile.ts";
import { RESUME_REPAIR_PROMPT, RESUME_SYSTEM_PROMPT, wrapUntrusted } from "./prompts.ts";
import { sanitize } from "./sanitize.ts";
import {
  EXTRACTION_SCHEMA_VERSION,
  EXTRACTION_SCHEMAS,
  ExtractionInvalid,
  type ResumeExtraction,
  validateExtraction,
} from "./schemas.ts";
import { BudgetExceeded } from "./usage.ts";

/** Progress the app shows; the same names as public.resume_status. */
export type ParseStep = "PARSING_LAYOUT" | "EXTRACTING" | "NORMALIZING";
export type FailureReason = "unreadable_scan" | "timeout" | "too_long" | "budget_exceeded" | "internal";

export const PARSE_TIMEOUT_MS = 75_000;
/** Resumes longer than this are almost certainly not resumes. */
export const MAX_PAGES = 10;
/** Same limit the app enforces before sending. */
export const MAX_FILE_BYTES = 5 * 1024 * 1024;
export const DEFAULT_REPAIR_ROUNDS = 1;
/** A repair call takes about as long as the first extraction; don't start one that can't finish. */
export const REPAIR_MIN_REMAINING_MS = 25_000;
/** Cap on the previous output echoed back to the model in a repair round. */
const MAX_FEEDBACK_CHARS = 40_000;

export interface DraftSkillRow {
  skill_id: string | null;
  raw_name: string;
  years: number | null;
  evidence: string;
}

export interface SaveProfileInput {
  candidateId: string;
  schemaVersion: number;
  llmModel: string;
  totalYears: number;
  education: ResumeExtraction["education"];
  skills: DraftSkillRow[];
  experiences: Experience[];
}

/** Thin wrapper over save_parsed_profile (migration 20261022200000). */
export interface ProfileStore {
  /** The caller has the candidate role and a candidates row. */
  isCandidate(userId: string): Promise<boolean>;
  saveParsedProfile(input: SaveProfileInput): Promise<{ profileVersionId: string; version: number }>;
}

/** Request-level errors, returned to the app as HTTP errors (API_CONTRACT §2). */
export class ParseRequestError extends Error {
  constructor(public code: "not_candidate" | "invalid_file", public httpStatus: number) {
    super(code);
    this.name = "ParseRequestError";
  }
}

/** Ends the parse with a specific failure_reason. */
class ParseFailure extends Error {
  constructor(public reason: FailureReason, detail: string) {
    super(detail);
  }
}

export type ParseResult =
  | {
    status: "READY";
    profile_version_id: string;
    version: number;
    skill_count: number;
    unmapped_count: number;
    experience_count: number;
    repair_rounds: number;
  }
  | { status: "FAILED"; failure_reason: FailureReason };

export interface ResumeUpload {
  userId: string;
  bytes: Uint8Array<ArrayBuffer>;
  /** Only used to tell DOCX from other zip files; the bytes decide the rest. */
  filename: string;
}

export interface AgentDeps {
  store: ProfileStore;
  llm: LlmProvider;
  index: SkillIndex;
  now?: () => Date;
  timeoutMs?: number;
  maxRepairRounds?: number;
  log?: (msg: string, extra?: Record<string, unknown>) => void;
  /** Called as each step starts, for streamed progress. */
  onStep?: (step: ParseStep) => void;
}

/** PDF or DOCX from the file's own bytes; null for anything else. */
export function sniffMime(bytes: Uint8Array, filename: string): typeof PDF_MIME | typeof DOCX_MIME | null {
  const starts = (sig: number[]) => sig.every((b, i) => bytes[i] === b);
  if (starts([0x25, 0x50, 0x44, 0x46, 0x2d])) return PDF_MIME; // %PDF-
  if (starts([0x50, 0x4b, 0x03, 0x04]) && /\.docx$/i.test(filename)) return DOCX_MIME; // zip
  return null;
}

/** Checks that can fail fast, before any work: the caller and the file. */
export async function checkUpload(deps: Pick<AgentDeps, "store">, upload: ResumeUpload) {
  if (!upload.bytes.length || upload.bytes.length > MAX_FILE_BYTES || !sniffMime(upload.bytes, upload.filename)) {
    throw new ParseRequestError("invalid_file", 400);
  }
  if (!(await deps.store.isCandidate(upload.userId))) throw new ParseRequestError("not_candidate", 403);
}

export async function parseResume(deps: AgentDeps, upload: ResumeUpload): Promise<ParseResult> {
  const log = deps.log ?? ((m, e) => console.log(JSON.stringify({ fn: "parse-resume", msg: m, ...e })));
  await checkUpload(deps, upload);

  const timeoutMs = deps.timeoutMs ?? PARSE_TIMEOUT_MS;
  const deadline = Date.now() + timeoutMs;
  const run = { timedOut: false };
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<ParseResult>((resolve) => {
    timer = setTimeout(() => {
      run.timedOut = true;
      log("timeout", { user_id: upload.userId });
      resolve({ status: "FAILED", failure_reason: "timeout" });
    }, timeoutMs);
  });

  const work = agent(deps, upload, deadline, run, log).catch((e): ParseResult => {
    const reason = failureReason(e);
    log("failed", {
      user_id: upload.userId,
      reason,
      error: e instanceof Error ? `${e.name}: ${e.message}` : String(e),
    });
    return { status: "FAILED", failure_reason: reason };
  });

  try {
    return await Promise.race([work, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

async function agent(
  deps: AgentDeps,
  upload: ResumeUpload,
  deadline: number,
  run: { timedOut: boolean },
  log: NonNullable<AgentDeps["log"]>,
): Promise<ParseResult> {
  const { llm, index, store } = deps;
  const today = (deps.now ?? (() => new Date()))();
  const step = (s: ParseStep) => {
    if (run.timedOut) throw new ParseFailure("timeout", `timed out before ${s}`);
    deps.onStep?.(s);
  };

  // PARSING_LAYOUT ------------------------------------------------------------
  step("PARSING_LAYOUT");
  const mime = sniffMime(upload.bytes, upload.filename);
  if (!mime) throw new UnsupportedFile("unknown");
  const extracted = await extractText(upload.bytes, mime, llm);
  if (extracted.pages > MAX_PAGES) throw new ParseFailure("too_long", `${extracted.pages} pages`);
  const text = sanitize(extracted.lines).text;
  if (!text.trim()) throw new ParseFailure("unreadable_scan", `no readable text (${extracted.source})`);

  // EXTRACTING: extract → verify → repair ----------------------------------------
  step("EXTRACTING");
  const best = await extractWithRepair(deps, text, today, deadline, log);

  // NORMALIZING ---------------------------------------------------------------
  step("NORMALIZING");
  const draft = buildDraftProfile(best.extraction, text, today);
  const normalized = await normalizeSkills(draft.skills.map((s) => s.raw), llm, index);
  const skills: DraftSkillRow[] = draft.skills.map((s, i) => ({
    skill_id: normalized[i].skill_id,
    raw_name: s.raw,
    years: s.years,
    evidence: s.evidence,
  }));
  const experiences = verifiedExperiences(
    best.extraction.roles,
    text,
    new Set(draft.skills.map((s) => skillKey(s.raw))),
  );

  // READY ---------------------------------------------------------------------
  // The client already got FAILED; don't leave a draft it doesn't know about.
  if (run.timedOut) throw new ParseFailure("timeout", "timed out before saving");
  const saved = await store.saveParsedProfile({
    candidateId: upload.userId,
    schemaVersion: EXTRACTION_SCHEMA_VERSION,
    llmModel: best.model,
    totalYears: draft.totalYears,
    education: best.extraction.education,
    skills,
    experiences,
  });
  const distinct = new Map(skills.map((s) => [s.skill_id ?? `raw:${skillKey(s.raw_name)}`, s]));
  log("ready", {
    user_id: upload.userId,
    skills: distinct.size,
    experiences: experiences.length,
    dropped: draft.dropped.length,
    repair_rounds: best.rounds,
  });
  return {
    status: "READY",
    profile_version_id: saved.profileVersionId,
    version: saved.version,
    skill_count: distinct.size,
    unmapped_count: [...distinct.values()].filter((s) => !s.skill_id).length,
    experience_count: experiences.length,
    repair_rounds: best.rounds,
  };
}

interface Attempt {
  extraction: ResumeExtraction;
  findings: Finding[];
  /** Verified skills + roles: what would actually be saved. */
  kept: number;
  model: string;
}

/**
 * The agent loop. The first call extracts; while the verifier still has
 * findings, the model gets its previous output and those findings back and
 * returns a corrected extraction. The best verified attempt wins.
 */
async function extractWithRepair(
  deps: AgentDeps,
  text: string,
  today: Date,
  deadline: number,
  log: NonNullable<AgentDeps["log"]>,
): Promise<Attempt & { rounds: number }> {
  const maxRounds = deps.maxRepairRounds ?? DEFAULT_REPAIR_ROUNDS;
  const untrustedText = wrapUntrusted("resume", text);

  const attempt = async (system: string, feedback?: string) => {
    const res = await deps.llm.extract({
      schemaName: "resume",
      schema: EXTRACTION_SCHEMAS.resume.jsonSchema,
      system,
      untrustedText,
      feedback,
    });
    try {
      const extraction = validateExtraction("resume", res.data);
      const draft = buildDraftProfile(extraction, text, today);
      return {
        ok: true as const,
        attempt: {
          extraction,
          findings: reviewExtraction(extraction, text, today),
          kept: draft.skills.length + draft.roles.length,
          model: res.model,
        },
      };
    } catch (e) {
      if (!(e instanceof ExtractionInvalid)) throw e;
      return { ok: false as const, error: e, data: res.data };
    }
  };

  let first = await attempt(RESUME_SYSTEM_PROMPT);
  let rounds = 0;
  // Output that doesn't match the schema gets one chance to be fixed too.
  if (!first.ok) {
    if (maxRounds < 1 || deadline - Date.now() < REPAIR_MIN_REMAINING_MS) throw first.error;
    rounds++;
    log("repair", { round: rounds, schema_issues: first.error.issues.length });
    first = await attempt(
      RESUME_REPAIR_PROMPT,
      feedback(first.data, first.error.issues.map((i) => ({ path: i.path.join("."), problem: i.message }))),
    );
    if (!first.ok) throw first.error;
  }

  let best = first.attempt;
  while (best.findings.length && rounds < maxRounds && deadline - Date.now() >= REPAIR_MIN_REMAINING_MS) {
    rounds++;
    log("repair", { round: rounds, findings: best.findings.length });
    const next = await attempt(RESUME_REPAIR_PROMPT, feedback(best.extraction, best.findings));
    const better = next.ok &&
      (next.attempt.kept > best.kept ||
        (next.attempt.kept === best.kept && next.attempt.findings.length < best.findings.length));
    if (!better) break;
    best = next.attempt;
  }
  return { ...best, rounds };
}

function feedback(previous: unknown, findings: Finding[]): string {
  const json = JSON.stringify(previous).slice(0, MAX_FEEDBACK_CHARS);
  const problems = findings.map((f) => `- ${f.path}: ${f.problem}`).join("\n");
  return `${wrapUntrusted("previous_extraction", json)}\nProblems found by the checker:\n${problems}`;
}

/** Gemini errors, invalid model output, unsupported files, and anything unexpected are "internal". */
export function failureReason(e: unknown): FailureReason {
  if (e instanceof ParseFailure) return e.reason;
  if (e instanceof BudgetExceeded) return "budget_exceeded";
  return "internal";
}
