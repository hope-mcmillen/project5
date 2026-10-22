// ProfileStore implementations: Supabase (save_parsed_profile RPC, service
// role) and in-memory for tests and local scripts. parseResume() passes the
// caller's id from their verified JWT; the RPC re-checks the candidate role.
import type { ProfileStore, SaveProfileInput } from "./resume_agent.ts";
import type { SupabaseClient } from "./supabase.ts";

export class SupabaseProfileStore implements ProfileStore {
  constructor(private db: SupabaseClient) {}

  async isCandidate(userId: string): Promise<boolean> {
    const { data, error } = await this.db.from("candidates")
      .select("profile_id, profiles!inner(role)")
      .eq("profile_id", userId)
      .eq("profiles.role", "candidate")
      .maybeSingle();
    if (error) throw new Error(`candidate lookup failed: ${error.message}`);
    return data !== null;
  }

  async saveParsedProfile(input: SaveProfileInput): Promise<{ profileVersionId: string; version: number }> {
    const { data, error } = await this.db.rpc("save_parsed_profile", {
      p_candidate_id: input.candidateId,
      p_schema_version: input.schemaVersion,
      p_llm_model: input.llmModel,
      p_total_years: input.totalYears,
      p_education: input.education,
      p_skills: input.skills,
      p_experiences: input.experiences,
    });
    if (error) throw new Error(`save_parsed_profile failed: ${error.message}`);
    const row = (data as Array<{ profile_version_id: string; version: number }>)[0];
    return { profileVersionId: row.profile_version_id, version: row.version };
  }
}

export interface SavedVersion extends SaveProfileInput {
  id: string;
  version: number;
}

/** Mirrors save_parsed_profile's version numbering and skill merge. */
export class MemoryProfileStore implements ProfileStore {
  versions: SavedVersion[] = [];
  constructor(public candidates: Set<string> = new Set()) {}

  isCandidate(userId: string): Promise<boolean> {
    return Promise.resolve(this.candidates.has(userId));
  }

  saveParsedProfile(input: SaveProfileInput): Promise<{ profileVersionId: string; version: number }> {
    if (!this.candidates.has(input.candidateId)) return Promise.reject(new Error("not_candidate"));
    const version = this.versions.filter((v) => v.candidateId === input.candidateId).length + 1;
    const merged = new Map<string, SaveProfileInput["skills"][number]>();
    for (const s of input.skills) {
      const key = s.skill_id ?? s.raw_name.trim().toLowerCase();
      const prev = merged.get(key);
      merged.set(key, prev ? { ...prev, years: maxYears(prev.years, s.years) } : s);
    }
    const saved = { ...structuredClone(input), skills: [...merged.values()], id: crypto.randomUUID(), version };
    this.versions.push(saved);
    return Promise.resolve({ profileVersionId: saved.id, version });
  }
}

const maxYears = (a: number | null, b: number | null) => a === null ? b : b === null ? a : Math.max(a, b);
