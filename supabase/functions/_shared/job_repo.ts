// Supabase implementation of JobRepo (service-role client; parseJob checks the
// caller's company first) and an in-memory one for tests that mirrors the SQL
// rules in migration 20261018220000_parse_job_rpcs.sql.
import type { DraftRequirement } from "./requirements.ts";
import { type JobFields, type JobRepo, type JobRow, JobStateChanged, type SavedRequirement } from "./job_pipeline.ts";
import { MAX_REQUIRED, MAX_REQUIREMENTS } from "./requirements.ts";
import type { SupabaseClient } from "./supabase.ts";

export class SupabaseJobRepo implements JobRepo {
  constructor(private db: SupabaseClient) {}

  async get(jobId: string): Promise<JobRow | null> {
    const { data, error } = await this.db.from("jobs")
      .select("id, company_id, status, raw_description")
      .eq("id", jobId)
      .maybeSingle();
    if (error) throw new Error(`jobs read failed: ${error.message}`);
    return data as JobRow | null;
  }

  async recruiterCompanies(userId: string): Promise<string[]> {
    const { data, error } = await this.db.from("recruiters").select("company_id").eq("profile_id", userId);
    if (error) throw new Error(`recruiters read failed: ${error.message}`);
    return (data ?? []).map((r) => r.company_id as string);
  }

  start(jobId: string): Promise<boolean> {
    return this.bool("start_job_parse", { p_job_id: jobId });
  }

  fail(jobId: string): Promise<boolean> {
    return this.bool("fail_job_parse", { p_job_id: jobId });
  }

  async saveDraft(jobId: string, fields: JobFields, requirements: DraftRequirement[]): Promise<SavedRequirement[]> {
    const { data, error } = await this.db.rpc("save_job_draft", {
      p_job_id: jobId,
      p_fields: fields,
      p_requirements: requirements.map(({ skill_id, required, min_years, weight, evidence }) => ({
        skill_id,
        required,
        min_years,
        weight,
        evidence,
      })),
    });
    if (error) {
      if (error.message.includes("job_not_pending")) throw new JobStateChanged();
      throw new Error(`save_job_draft failed: ${error.message}`);
    }
    return (data as Array<SavedRequirement & { min_years: string | number }>).map((r) => ({
      ...r,
      min_years: Number(r.min_years),
    }));
  }

  private async bool(fn: string, args: Record<string, unknown>): Promise<boolean> {
    const { data, error } = await this.db.rpc(fn, args);
    if (error) throw new Error(`${fn} failed: ${error.message}`);
    return data === true;
  }
}

type ParseStatus = "PENDING" | "READY" | "FAILED";

export interface MemoryJob extends JobRow {
  parse_status: ParseStatus;
  fields: Partial<JobFields>;
  requirements: SavedRequirement[];
}

export class MemoryJobRepo implements JobRepo {
  jobs = new Map<string, MemoryJob>();
  recruiters = new Map<string, string>(); // user → company

  add(job: Partial<MemoryJob> & Pick<JobRow, "id" | "company_id" | "raw_description">) {
    const j: MemoryJob = { status: "DRAFT", parse_status: "PENDING", fields: {}, requirements: [], ...job };
    this.jobs.set(j.id, j);
    return j;
  }

  get(id: string): Promise<JobRow | null> {
    const j = this.jobs.get(id);
    return Promise.resolve(
      j ? { id: j.id, company_id: j.company_id, status: j.status, raw_description: j.raw_description } : null,
    );
  }

  recruiterCompanies(userId: string): Promise<string[]> {
    const c = this.recruiters.get(userId);
    return Promise.resolve(c ? [c] : []);
  }

  start(id: string): Promise<boolean> {
    const j = this.jobs.get(id);
    if (!j || j.status !== "DRAFT") return Promise.resolve(false);
    j.parse_status = "PENDING";
    return Promise.resolve(true);
  }

  fail(id: string): Promise<boolean> {
    const j = this.jobs.get(id);
    if (!j || j.parse_status !== "PENDING") return Promise.resolve(false);
    j.parse_status = "FAILED";
    return Promise.resolve(true);
  }

  saveDraft(id: string, fields: JobFields, reqs: DraftRequirement[]): Promise<SavedRequirement[]> {
    const j = this.jobs.get(id);
    if (!j || j.status !== "DRAFT" || j.parse_status !== "PENDING") return Promise.reject(new JobStateChanged());
    if (reqs.length > MAX_REQUIREMENTS || reqs.filter((r) => r.required).length > MAX_REQUIRED) {
      return Promise.reject(new Error("too_many_requirements"));
    }
    // Pre-fill only what the recruiter hasn't set (SQL uses coalesce(existing, extracted)).
    for (const [k, v] of Object.entries(fields) as Array<[keyof JobFields, never]>) {
      if (j.fields[k] === undefined || j.fields[k] === null) (j.fields as Record<string, unknown>)[k] = v;
    }
    j.requirements = reqs.map(({ either_of_group: _, ...r }, i) => ({ ...r, id: `jr-${id}-${i}` }));
    j.parse_status = "READY";
    return Promise.resolve(j.requirements);
  }
}
