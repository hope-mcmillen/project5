// Supabase implementation of ResumeRepo: the resume_parse RPCs, Storage, and
// two reads. Uses the service-role client; parseResume() checks ownership first.
import {
  type DraftSummary,
  type FailureReason,
  objectKey,
  type ResumeRepo,
  type ResumeRow,
  ResumeStateChanged,
  type ResumeStatus,
  type SaveDraftInput,
} from "./resume_pipeline.ts";
import { type ResumeExtraction, validateExtraction } from "./schemas.ts";
import type { SupabaseClient } from "./supabase.ts";

export const RESUME_BUCKET = "resumes";

export class SupabaseResumeRepo implements ResumeRepo {
  constructor(private db: SupabaseClient) {}

  async get(resumeId: string): Promise<ResumeRow | null> {
    const { data, error } = await this.db.from("resumes")
      .select("id, candidate_id, storage_path, mime_type, status")
      .eq("id", resumeId)
      .maybeSingle();
    if (error) throw new Error(`resumes read failed: ${error.message}`);
    return data as ResumeRow | null;
  }

  claim(resumeId: string, staleSeconds: number): Promise<boolean> {
    return this.bool("claim_resume_parse", { p_resume_id: resumeId, p_stale_seconds: staleSeconds });
  }

  advance(resumeId: string, from: ResumeStatus, to: ResumeStatus): Promise<boolean> {
    return this.bool("advance_resume_status", { p_resume_id: resumeId, p_from: from, p_to: to });
  }

  fail(resumeId: string, reason: FailureReason): Promise<boolean> {
    return this.bool("fail_resume_parse", { p_resume_id: resumeId, p_reason: reason });
  }

  async download(storagePath: string): Promise<Uint8Array<ArrayBuffer>> {
    const { data, error } = await this.db.storage.from(RESUME_BUCKET).download(objectKey(storagePath));
    if (error || !data) throw new Error(`download failed: ${error?.message ?? "empty"}`);
    return new Uint8Array(await data.arrayBuffer());
  }

  async findCachedExtraction(fileHash: string, schemaVersion: number) {
    // Only READY rows: save_resume_draft overwrote their file_hash with the server-computed hash,
    // so a client can't fake a hash to borrow someone else's extraction.
    const { data, error } = await this.db.from("resumes")
      .select("extraction, llm_provider, llm_model")
      .eq("file_hash", fileHash)
      .eq("schema_version", schemaVersion)
      .eq("status", "READY")
      .not("extraction", "is", null)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw new Error(`cache lookup failed: ${error.message}`);
    if (!data) return null;
    return {
      extraction: validateExtraction("resume", data.extraction) as ResumeExtraction,
      llmProvider: data.llm_provider as string,
      llmModel: data.llm_model as string,
    };
  }

  async saveDraft(input: SaveDraftInput): Promise<{ profileVersionId: string; version: number }> {
    const { data, error } = await this.db.rpc("save_resume_draft", {
      p_resume_id: input.resumeId,
      p_file_hash: input.fileHash,
      p_extraction: input.extraction,
      p_schema_version: input.schemaVersion,
      p_llm_provider: input.llmProvider,
      p_llm_model: input.llmModel,
      p_total_years: input.totalYears,
      p_education: input.education,
      p_skills: input.skills,
    });
    if (error) {
      if (error.message.includes("resume_not_normalizing")) throw new ResumeStateChanged();
      throw new Error(`save_resume_draft failed: ${error.message}`);
    }
    const row = (data as Array<{ profile_version_id: string; version: number }>)[0];
    return { profileVersionId: row.profile_version_id, version: row.version };
  }

  async latestDraft(resumeId: string): Promise<DraftSummary | null> {
    const { data, error } = await this.db.from("profile_versions")
      .select("id, version, candidate_skills(skill_id)")
      .eq("resume_id", resumeId)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (error) throw new Error(`profile_versions read failed: ${error.message}`);
    if (!data) return null;
    const skills = (data.candidate_skills ?? []) as Array<{ skill_id: string | null }>;
    return {
      profileVersionId: data.id,
      version: data.version,
      skillCount: skills.length,
      unmappedCount: skills.filter((s) => !s.skill_id).length,
    };
  }

  private async bool(fn: string, args: Record<string, unknown>): Promise<boolean> {
    const { data, error } = await this.db.rpc(fn, args);
    if (error) throw new Error(`${fn} failed: ${error.message}`);
    return data === true;
  }
}
