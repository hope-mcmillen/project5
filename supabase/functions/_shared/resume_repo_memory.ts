// In-memory ResumeRepo for tests. Mirrors the SQL rules in migration
// 20261018210000_resume_parse_rpcs.sql (claim, compare-and-set, draft merge).
import type {
  DraftSkillRow,
  DraftSummary,
  FailureReason,
  ResumeRepo,
  ResumeRow,
  ResumeStatus,
  SaveDraftInput,
} from "./resume_pipeline.ts";
import { ResumeStateChanged } from "./resume_pipeline.ts";
import type { ResumeExtraction } from "./schemas.ts";

const PARSING: ResumeStatus[] = ["PARSING_LAYOUT", "EXTRACTING", "NORMALIZING"];

export interface MemoryResume extends ResumeRow {
  failure_reason: FailureReason | null;
  file_hash: string;
  extraction: ResumeExtraction | null;
  schema_version: number | null;
  llm_provider: string | null;
  llm_model: string | null;
  updated_at: number;
  history: ResumeStatus[];
}

export interface MemoryVersion {
  id: string;
  candidate_id: string;
  resume_id: string;
  version: number;
  total_years: number;
  education: unknown;
  skills: DraftSkillRow[];
}

export class MemoryResumeRepo implements ResumeRepo {
  resumes = new Map<string, MemoryResume>();
  files = new Map<string, Uint8Array<ArrayBuffer>>();
  versions: MemoryVersion[] = [];
  cacheLookups: string[] = [];
  now = () => Date.now();

  add(row: Partial<MemoryResume> & Pick<ResumeRow, "id" | "candidate_id">, file?: Uint8Array<ArrayBuffer>) {
    const r: MemoryResume = {
      storage_path: `resumes/${row.candidate_id}/${row.id}.pdf`,
      mime_type: "application/pdf",
      status: "UPLOADED",
      failure_reason: null,
      file_hash: "client-supplied-hash",
      extraction: null,
      schema_version: null,
      llm_provider: null,
      llm_model: null,
      updated_at: this.now(),
      history: [],
      ...row,
    };
    this.resumes.set(r.id, r);
    if (file) this.files.set(r.storage_path, file);
    return r;
  }

  private set(r: MemoryResume, status: ResumeStatus, reason: FailureReason | null = null) {
    r.status = status;
    r.failure_reason = reason;
    r.updated_at = this.now();
    r.history.push(status);
  }

  get(id: string): Promise<ResumeRow | null> {
    const r = this.resumes.get(id);
    return Promise.resolve(r ? { ...r } : null);
  }

  claim(id: string, staleSeconds: number): Promise<boolean> {
    const r = this.resumes.get(id);
    const stale = r && PARSING.includes(r.status) && r.updated_at < this.now() - staleSeconds * 1000;
    if (!r || !(r.status === "UPLOADED" || r.status === "FAILED" || stale)) return Promise.resolve(false);
    this.set(r, "PARSING_LAYOUT");
    return Promise.resolve(true);
  }

  advance(id: string, from: ResumeStatus, to: ResumeStatus): Promise<boolean> {
    const r = this.resumes.get(id);
    if (!r || r.status !== from) return Promise.resolve(false);
    this.set(r, to);
    return Promise.resolve(true);
  }

  fail(id: string, reason: FailureReason): Promise<boolean> {
    const r = this.resumes.get(id);
    if (!r || !PARSING.includes(r.status)) return Promise.resolve(false);
    this.set(r, "FAILED", reason);
    return Promise.resolve(true);
  }

  download(path: string): Promise<Uint8Array<ArrayBuffer>> {
    const f = this.files.get(path);
    return f ? Promise.resolve(f.slice()) : Promise.reject(new Error(`no file at ${path}`));
  }

  findCachedExtraction(fileHash: string, schemaVersion: number) {
    this.cacheLookups.push(fileHash);
    const hit = [...this.resumes.values()].find((r) =>
      r.status === "READY" && r.file_hash === fileHash && r.schema_version === schemaVersion && r.extraction
    );
    return Promise.resolve(
      hit ? { extraction: hit.extraction!, llmProvider: hit.llm_provider!, llmModel: hit.llm_model! } : null,
    );
  }

  saveDraft(input: SaveDraftInput): Promise<{ profileVersionId: string; version: number }> {
    const r = this.resumes.get(input.resumeId);
    if (!r || r.status !== "NORMALIZING") return Promise.reject(new ResumeStateChanged());
    const version =
      Math.max(0, ...this.versions.filter((v) => v.candidate_id === r.candidate_id).map((v) => v.version)) + 1;
    // Same merge as SQL: one row per skill_id (or lowercase raw when unmapped); most years, first evidence.
    const merged = new Map<string, DraftSkillRow>();
    for (const s of input.skills) {
      const key = s.skill_id ?? `raw:${s.raw_name.toLowerCase()}`;
      const prev = merged.get(key);
      merged.set(key, prev ? { ...prev, years: maxYears(prev.years, s.years) } : s);
    }
    const id = `pv-${this.versions.length + 1}`;
    this.versions.push({
      id,
      candidate_id: r.candidate_id,
      resume_id: r.id,
      version,
      total_years: input.totalYears,
      education: input.education,
      skills: [...merged.values()],
    });
    Object.assign(r, {
      file_hash: input.fileHash,
      extraction: input.extraction,
      schema_version: input.schemaVersion,
      llm_provider: input.llmProvider,
      llm_model: input.llmModel,
    });
    this.set(r, "READY");
    return Promise.resolve({ profileVersionId: id, version });
  }

  latestDraft(resumeId: string): Promise<DraftSummary | null> {
    const v = this.versions.filter((x) => x.resume_id === resumeId).sort((a, b) => b.version - a.version)[0];
    return Promise.resolve(
      v
        ? {
          profileVersionId: v.id,
          version: v.version,
          skillCount: v.skills.length,
          unmappedCount: v.skills.filter((s) => !s.skill_id).length,
        }
        : null,
    );
  }
}

function maxYears(a: number | null, b: number | null): number | null {
  return a === null ? b : b === null ? a : Math.max(a, b);
}
