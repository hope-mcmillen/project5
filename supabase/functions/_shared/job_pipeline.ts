// parse-job pipeline (AI-12, PRD §8.1 / R-JOB-1). DB access is behind JobRepo
// so the flow is testable without Supabase.
//
//   start_job_parse → sanitize JD → Gemini → evidence check → normalize →
//   draftRequirements (merge, alternatives, caps) → save_job_draft (atomic, READY)
import type { TextLine } from "./extract_text.ts";
import type { LlmProvider } from "./llm.ts";
import { normalizeSkills, type SkillIndex } from "./normalize.ts";
import { JOB_SYSTEM_PROMPT, wrapUntrusted } from "./prompts.ts";
import {
  type DraftRequirement,
  draftRequirements,
  type UnmappedRequirement,
  verifiedRequirements,
} from "./requirements.ts";
import { sanitize } from "./sanitize.ts";
import { EXTRACTION_SCHEMAS, type JobExtraction, validateExtraction } from "./schemas.ts";
import { BudgetExceeded } from "./usage.ts";

export const JOB_PARSE_TIMEOUT_MS = 60_000;

export type JobFailureReason = "timeout" | "too_long" | "budget_exceeded" | "internal";
export type JobFields = Omit<JobExtraction, "requirements">;

export interface JobRow {
  id: string;
  company_id: string;
  status: "DRAFT" | "OPEN" | "PAUSED" | "CLOSED";
  raw_description: string;
}

/** A requirement as saved, with its database id. */
export interface SavedRequirement extends Omit<DraftRequirement, "either_of_group"> {
  id: string;
}

export interface JobRepo {
  get(jobId: string): Promise<JobRow | null>;
  /** Company ids the user is a recruiter in (normally one). */
  recruiterCompanies(userId: string): Promise<string[]>;
  /** False if the job isn't a DRAFT. */
  start(jobId: string): Promise<boolean>;
  fail(jobId: string): Promise<boolean>;
  /** Throws JobStateChanged if the job left DRAFT/PENDING meanwhile. */
  saveDraft(jobId: string, fields: JobFields, requirements: DraftRequirement[]): Promise<SavedRequirement[]>;
}

export class JobStateChanged extends Error {
  constructor() {
    super("job_not_pending");
    this.name = "JobStateChanged";
  }
}

export class JobRequestError extends Error {
  constructor(public code: "job_not_found" | "not_company_recruiter" | "job_not_draft", public httpStatus: number) {
    super(code);
    this.name = "JobRequestError";
  }
}

export type JobParseResult =
  | {
    job_id: string;
    parse_status: "READY";
    job: JobFields;
    requirements: Array<SavedRequirement & { either_of_group: number | null }>;
    unmapped: UnmappedRequirement[];
    trimmed: DraftRequirement[];
  }
  | { job_id: string; parse_status: "FAILED"; failure_reason: JobFailureReason };

export interface JobParseDeps {
  repo: JobRepo;
  llm: LlmProvider;
  index: SkillIndex;
  timeoutMs?: number;
  log?: (msg: string, extra?: Record<string, unknown>) => void;
}

export async function parseJob(deps: JobParseDeps, req: { jobId: string; userId: string }): Promise<JobParseResult> {
  const { repo } = deps;
  const log = loggerOf(deps);

  const job = await repo.get(req.jobId);
  if (!job) throw new JobRequestError("job_not_found", 404);
  if (!(await repo.recruiterCompanies(req.userId)).includes(job.company_id)) {
    throw new JobRequestError("not_company_recruiter", 403);
  }
  if (job.status !== "DRAFT" || !(await repo.start(job.id))) throw new JobRequestError("job_not_draft", 409);

  let timer: ReturnType<typeof setTimeout> | undefined;
  const failed = (reason: JobFailureReason): JobParseResult => ({
    job_id: job.id,
    parse_status: "FAILED",
    failure_reason: reason,
  });
  const timeout = new Promise<JobParseResult>((resolve) => {
    timer = setTimeout(async () => {
      log("timeout", { job_id: job.id });
      await repo.fail(job.id).catch(() => {});
      resolve(failed("timeout"));
    }, deps.timeoutMs ?? JOB_PARSE_TIMEOUT_MS);
  });
  const work = run(deps, job).catch(async (e): Promise<JobParseResult> => {
    const reason: JobFailureReason = e instanceof BudgetExceeded ? "budget_exceeded" : "internal";
    log("failed", { job_id: job.id, reason, error: e instanceof Error ? `${e.name}: ${e.message}` : String(e) });
    await repo.fail(job.id).catch(() => {});
    return failed(reason);
  });

  try {
    return await Promise.race([work, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

function loggerOf(deps: JobParseDeps) {
  return deps.log ??
    ((m: string, e?: Record<string, unknown>) => console.log(JSON.stringify({ fn: "parse-job", msg: m, ...e })));
}

/** Raw JD text as lines for the sanitizer (no hidden-text signals in plain text). */
export function jobLines(raw: string): TextLine[] {
  return raw.split(/\r?\n/).map((text) => ({ text, page: 1, fontSize: null, hidden: null }));
}

async function run(deps: JobParseDeps, job: JobRow): Promise<JobParseResult> {
  const { repo, llm, index } = deps;
  const clean = sanitize(jobLines(job.raw_description));
  if (!clean.text.trim()) throw new Error("empty job description");

  const res = await llm.extract({
    schemaName: "job",
    schema: EXTRACTION_SCHEMAS.job.jsonSchema,
    system: JOB_SYSTEM_PROMPT,
    untrustedText: wrapUntrusted("job", clean.text),
  });
  const extraction = validateExtraction("job", res.data);
  const { requirements: raw, ...fields } = extraction;

  const { kept, dropped } = verifiedRequirements(raw, clean.text);
  const normalized = await normalizeSkills(kept.map((r) => r.raw), llm, index);
  const draft = draftRequirements(kept, normalized, dropped);
  if (dropped.length) loggerOf(deps)("dropped requirements", { job_id: job.id, dropped });

  const saved = await repo.saveDraft(job.id, fields, draft.requirements);
  const groups = new Map(draft.requirements.map((r) => [r.skill_id, r.either_of_group]));
  return {
    job_id: job.id,
    parse_status: "READY",
    job: fields,
    requirements: saved.map((s) => ({ ...s, either_of_group: groups.get(s.skill_id) ?? null })),
    unmapped: draft.unmapped,
    trimmed: draft.trimmed,
  };
}
