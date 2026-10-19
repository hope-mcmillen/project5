// parse-resume pipeline (AI-07, PRD §8.1). Storage/DB access is behind
// ResumeRepo so the whole flow runs in tests without Supabase.
//
//   PARSING_LAYOUT  download, hash (server-side), cache lookup, text extraction, sanitize
//   EXTRACTING      Gemini structured extraction (skipped on a cache hit)
//   NORMALIZING     evidence + roles check, years, taxonomy mapping
//   READY           save_resume_draft() writes the version, skills, and READY atomically
//
// Any error ends in FAILED with a failure_reason; a 60 s timeout does too.
import { DOCX_MIME, extractText, PDF_MIME, UnsupportedFile } from "./extract_text.ts";
import { type LlmProvider, sha256Hex } from "./llm.ts";
import { normalizeSkills, type SkillIndex } from "./normalize.ts";
import { buildDraftProfile, mergeYears, skillKey, totalYears } from "./profile.ts";
import { RESUME_SYSTEM_PROMPT, wrapUntrusted } from "./prompts.ts";
import { sanitize } from "./sanitize.ts";
import { EXTRACTION_SCHEMA_VERSION, EXTRACTION_SCHEMAS, type ResumeExtraction, validateExtraction } from "./schemas.ts";
import { BudgetExceeded } from "./usage.ts";

export type ResumeStatus = "UPLOADED" | "PARSING_LAYOUT" | "EXTRACTING" | "NORMALIZING" | "READY" | "FAILED";
export type FailureReason = "unreadable_scan" | "timeout" | "too_long" | "budget_exceeded" | "internal";

export const PARSE_TIMEOUT_MS = 60_000;
/** A parse whose row hasn't changed for this long is assumed crashed and may be re-claimed. */
export const STALE_PARSE_SECONDS = 120;
/** Resumes longer than this are almost certainly not resumes. */
export const MAX_PAGES = 10;

export interface ResumeRow {
  id: string;
  candidate_id: string;
  storage_path: string;
  mime_type: string;
  status: ResumeStatus;
}

export interface DraftSkillRow {
  skill_id: string | null;
  raw_name: string;
  years: number | null;
  evidence: string;
}

export interface SaveDraftInput {
  resumeId: string;
  fileHash: string;
  extraction: ResumeExtraction;
  schemaVersion: number;
  llmProvider: string;
  llmModel: string;
  totalYears: number;
  education: ResumeExtraction["education"];
  skills: DraftSkillRow[];
}

export interface DraftSummary {
  profileVersionId: string;
  version: number;
  skillCount: number;
  unmappedCount: number;
}

/** Thin wrappers over the resume_parse RPCs (migration 20261018210000) and Storage. */
export interface ResumeRepo {
  get(resumeId: string): Promise<ResumeRow | null>;
  claim(resumeId: string, staleSeconds: number): Promise<boolean>;
  advance(resumeId: string, from: ResumeStatus, to: ResumeStatus): Promise<boolean>;
  fail(resumeId: string, reason: FailureReason): Promise<boolean>;
  download(storagePath: string): Promise<Uint8Array<ArrayBuffer>>;
  /** A previous verified extraction of the same bytes and schema version, from any resume row. */
  findCachedExtraction(
    fileHash: string,
    schemaVersion: number,
  ): Promise<{ extraction: ResumeExtraction; llmProvider: string; llmModel: string } | null>;
  /** Throws ResumeStateChanged if the row left NORMALIZING (e.g. timed out). */
  saveDraft(input: SaveDraftInput): Promise<{ profileVersionId: string; version: number }>;
  latestDraft(resumeId: string): Promise<DraftSummary | null>;
}

/** The row moved on without us (timed out and marked FAILED, or re-claimed after going stale). */
export class ResumeStateChanged extends Error {
  constructor(detail = "resume_not_normalizing") {
    super(detail);
    this.name = "ResumeStateChanged";
  }
}

/** Request-level errors, returned to the app as HTTP errors (API_CONTRACT §2). */
export class ParseRequestError extends Error {
  constructor(public code: "resume_not_found" | "not_owner" | "already_parsing", public httpStatus: number) {
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
    resume_id: string;
    status: "READY";
    cached: boolean;
    profile_version_id: string;
    version: number;
    skill_count: number;
    unmapped_count: number;
  }
  | { resume_id: string; status: "FAILED"; failure_reason: FailureReason };

export interface ParseDeps {
  repo: ResumeRepo;
  llm: LlmProvider;
  index: SkillIndex;
  now?: () => Date;
  timeoutMs?: number;
  log?: (msg: string, extra?: Record<string, unknown>) => void;
}

export async function parseResume(deps: ParseDeps, req: { resumeId: string; userId: string }): Promise<ParseResult> {
  const { repo } = deps;
  const log = deps.log ?? ((m, e) => console.log(JSON.stringify({ fn: "parse-resume", msg: m, ...e })));

  const row = await repo.get(req.resumeId);
  if (!row) throw new ParseRequestError("resume_not_found", 404);
  // The storage folder must be the owner's too, so a row can't point at someone else's file.
  if (row.candidate_id !== req.userId || objectKey(row.storage_path).split("/")[0] !== row.candidate_id) {
    throw new ParseRequestError("not_owner", 403);
  }

  if (row.status === "READY") {
    const latest = await repo.latestDraft(row.id);
    if (latest) return ready(row.id, latest, true);
  }
  if (!(await repo.claim(row.id, STALE_PARSE_SECONDS))) throw new ParseRequestError("already_parsing", 409);

  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<ParseResult>((resolve) => {
    timer = setTimeout(async () => {
      log("timeout", { resume_id: row.id });
      await repo.fail(row.id, "timeout").catch(() => {});
      resolve({ resume_id: row.id, status: "FAILED", failure_reason: "timeout" });
    }, deps.timeoutMs ?? PARSE_TIMEOUT_MS);
  });

  const work = run(deps, row).catch(async (e): Promise<ParseResult> => {
    // A timed-out run lands here when save_resume_draft refuses; the timeout already answered.
    const reason = failureReason(e);
    log("failed", { resume_id: row.id, reason, error: e instanceof Error ? `${e.name}: ${e.message}` : String(e) });
    await repo.fail(row.id, reason).catch(() => {});
    return { resume_id: row.id, status: "FAILED", failure_reason: reason };
  });

  try {
    return await Promise.race([work, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

async function run(deps: ParseDeps, row: ResumeRow): Promise<ParseResult> {
  const { repo, llm, index } = deps;
  const today = (deps.now ?? (() => new Date()))();

  // PARSING_LAYOUT ------------------------------------------------------------
  if (row.mime_type !== PDF_MIME && row.mime_type !== DOCX_MIME) throw new UnsupportedFile(row.mime_type);
  const bytes = await repo.download(row.storage_path);
  const fileHash = await sha256Hex(bytes); // never trust the client's file_hash for cache lookups
  const cached = await repo.findCachedExtraction(fileHash, EXTRACTION_SCHEMA_VERSION);

  let extraction: ResumeExtraction;
  let provider: string;
  let model: string;
  let roles: ResumeExtraction["roles"];
  let kept: Array<{ raw: string; evidence: string; years: number | null }>;

  if (cached) {
    // Cached extractions were already evidence-checked; only years (date-relative) are recomputed.
    await step(repo, row.id, "PARSING_LAYOUT", "EXTRACTING");
    ({ extraction, llmProvider: provider, llmModel: model } = cached);
    roles = extraction.roles;
    const years = mergeYears(roles, today);
    kept = extraction.skills.map((s) => ({
      raw: s.raw,
      evidence: s.evidence,
      years: years.get(skillKey(s.raw)) ?? null,
    }));
  } else {
    const extracted = await extractText(bytes, row.mime_type, llm);
    if (extracted.pages > MAX_PAGES) throw new ParseFailure("too_long", `${extracted.pages} pages`);
    const clean = sanitize(extracted.lines);
    if (!clean.text.trim()) throw new ParseFailure("unreadable_scan", `no readable text (${extracted.source})`);

    // EXTRACTING --------------------------------------------------------------
    await step(repo, row.id, "PARSING_LAYOUT", "EXTRACTING");
    const res = await llm.extract({
      schemaName: "resume",
      schema: EXTRACTION_SCHEMAS.resume.jsonSchema,
      system: RESUME_SYSTEM_PROMPT,
      untrustedText: wrapUntrusted("resume", clean.text),
    });
    const raw = validateExtraction("resume", res.data);
    const draft = buildDraftProfile(raw, clean.text, today);
    roles = draft.roles;
    kept = draft.skills;
    // Store only what passed verification, so a cache hit can skip re-checking.
    const keptKeys = new Set(kept.map((s) => skillKey(s.raw)));
    extraction = { roles, skills: raw.skills.filter((s) => keptKeys.has(skillKey(s.raw))), education: raw.education };
    provider = res.provider;
    model = res.model;
  }

  // NORMALIZING ---------------------------------------------------------------
  await step(repo, row.id, "EXTRACTING", "NORMALIZING");
  const normalized = await normalizeSkills(kept.map((s) => s.raw), llm, index);
  const skills: DraftSkillRow[] = kept.map((s, i) => ({
    skill_id: normalized[i].skill_id,
    raw_name: s.raw,
    years: s.years,
    evidence: s.evidence,
  }));

  const saved = await repo.saveDraft({
    resumeId: row.id,
    fileHash,
    extraction,
    schemaVersion: EXTRACTION_SCHEMA_VERSION,
    llmProvider: provider,
    llmModel: model,
    totalYears: totalYears(roles, today),
    education: extraction.education,
    skills,
  });
  const distinct = new Map(skills.map((s) => [s.skill_id ?? `raw:${skillKey(s.raw_name)}`, s]));
  return ready(row.id, {
    ...saved,
    skillCount: distinct.size,
    unmappedCount: [...distinct.values()].filter((s) => !s.skill_id).length,
  }, !!cached);
}

async function step(repo: ResumeRepo, id: string, from: ResumeStatus, to: ResumeStatus) {
  if (!(await repo.advance(id, from, to))) throw new ResumeStateChanged(`expected ${from}`);
}

function ready(resumeId: string, d: DraftSummary, cached: boolean): ParseResult {
  return {
    resume_id: resumeId,
    status: "READY",
    cached,
    profile_version_id: d.profileVersionId,
    version: d.version,
    skill_count: d.skillCount,
    unmapped_count: d.unmappedCount,
  };
}

/** Gemini errors, invalid model output, unsupported files, and anything unexpected are "internal". */
export function failureReason(e: unknown): FailureReason {
  if (e instanceof ParseFailure) return e.reason;
  if (e instanceof BudgetExceeded) return "budget_exceeded";
  return "internal";
}

/** "resumes/{uid}/{file}" → "{uid}/{file}" (the bucket is "resumes"). */
export function objectKey(storagePath: string): string {
  return storagePath.replace(/^\/?resumes\//, "");
}
