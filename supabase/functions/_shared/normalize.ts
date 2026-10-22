// Skill normalization (AI-10, PRD §8.3): map free-text skills onto the
// canonical taxonomy so "ReactJS" and "React" score as the same skill.
//
//   1. exact name or alias (lowercase)          → via "exact" / "alias"
//   2. embedding nearest neighbor ≥ threshold   → via "embedding"
//   3. otherwise unmapped (kept on the profile, not scored, logged for review)
import type { LlmProvider } from "./llm.ts";
import { skillKey } from "./profile.ts";

/**
 * Cosine-similarity cutoff for step 2. Tuned on supabase/tests/fixtures/alias_pairs.json
 * with `deno task tune:threshold` (2026-10-18): 0.89 → 96% correct with no non-skill mapped;
 * 0.88 maps "Auth" to Auth0, 0.90 starts missing real matches. Re-tune if the taxonomy or
 * skillEmbedText changes.
 */
export const MATCH_THRESHOLD = 0.89;

export interface TaxonomySkill {
  id: string;
  name: string;
  category: string;
  aliases: string[];
}

export interface SkillMatch {
  skill_id: string;
  name: string;
  similarity: number;
}

/** Where the taxonomy lives: Postgres in Edge Functions, memory in scripts and tests. */
export interface SkillIndex {
  skills(): Promise<TaxonomySkill[]>;
  /** Nearest skills with similarity ≥ threshold, best first (the match_skills RPC). */
  nearest(embedding: number[], threshold: number, k: number): Promise<SkillMatch[]>;
}

export type MatchedVia = "exact" | "alias" | "embedding" | "unmapped";

export interface NormalizedSkill {
  raw: string;
  skill_id: string | null;
  name: string | null;
  category: string | null;
  via: MatchedVia;
  /** Cosine similarity for "embedding"; also the best below-threshold score for "unmapped" when known. */
  similarity: number | null;
}

/**
 * The text embedded for each taxonomy skill (scripts/embed_taxonomy.ts); queries embed the raw
 * string. "name: aliases" beat name alone in tuning (96% vs 84%). Changing it means re-running
 * embed:taxonomy and tune:threshold.
 */
export function skillEmbedText(name: string, aliases: string[]): string {
  return aliases.length ? `${name}: ${aliases.join(", ")}` : name;
}

export async function normalizeSkills(
  raws: string[],
  llm: Pick<LlmProvider, "embed">,
  index: SkillIndex,
  { threshold = MATCH_THRESHOLD } = {},
): Promise<NormalizedSkill[]> {
  const taxonomy = await index.skills();
  const byName = new Map(taxonomy.map((s) => [skillKey(s.name), s]));
  const byAlias = new Map(taxonomy.flatMap((s) => s.aliases.map((a) => [skillKey(a), s] as const)));
  const byId = new Map(taxonomy.map((s) => [s.id, s]));

  const out: NormalizedSkill[] = raws.map((raw) => {
    const key = skillKey(raw);
    const exact = byName.get(key);
    const alias = exact ? undefined : byAlias.get(key);
    const hit = exact ?? alias;
    return {
      raw,
      skill_id: hit?.id ?? null,
      name: hit?.name ?? null,
      category: hit?.category ?? null,
      via: exact ? "exact" : alias ? "alias" : "unmapped",
      similarity: null,
    };
  });

  // Step 2: one batched embed call for everything still unmapped.
  const pending = out.filter((n) => n.via === "unmapped" && n.raw.trim());
  if (pending.length) {
    const { vectors } = await llm.embed(pending.map((n) => n.raw.trim()));
    await Promise.all(pending.map(async (n, i) => {
      // Ask for the best match even below the threshold so "unmapped" can report how close it came.
      const [best] = await index.nearest(vectors[i], -1, 1);
      if (!best) return;
      n.similarity = round3(best.similarity);
      if (best.similarity >= threshold) {
        const s = byId.get(best.skill_id);
        Object.assign(n, { skill_id: best.skill_id, name: best.name, category: s?.category ?? null, via: "embedding" });
      }
    }));
  }
  return out;
}

const round3 = (n: number) => Math.round(n * 1000) / 1000;

// ---------------------------------------------------------------------------
// Index implementations
// ---------------------------------------------------------------------------

/** Brute-force cosine search over unit vectors. 343 skills × 1536 dims is instant. */
export class MemorySkillIndex implements SkillIndex {
  constructor(private taxonomy: TaxonomySkill[], private vectors: Map<string, number[]>) {}

  skills(): Promise<TaxonomySkill[]> {
    return Promise.resolve(this.taxonomy);
  }

  nearest(embedding: number[], threshold: number, k: number): Promise<SkillMatch[]> {
    const scored: SkillMatch[] = [];
    for (const s of this.taxonomy) {
      const v = this.vectors.get(s.id);
      if (!v) continue;
      let dot = 0;
      for (let i = 0; i < v.length; i++) dot += v[i] * embedding[i];
      if (dot >= threshold) scored.push({ skill_id: s.id, name: s.name, similarity: dot });
    }
    return Promise.resolve(scored.sort((a, b) => b.similarity - a.similarity).slice(0, k));
  }
}

/** The slice of a supabase-js client the Postgres index needs (service-role or user client). */
export interface SkillDb {
  from(table: "skills"): {
    select(columns: string): PromiseLike<{ data: TaxonomySkill[] | null; error: { message: string } | null }>;
  };
  rpc(
    fn: "match_skills",
    args: { p_embedding: number[]; p_threshold: number; p_k: number },
  ): PromiseLike<{ data: SkillMatch[] | null; error: { message: string } | null }>;
}

export class SupabaseSkillIndex implements SkillIndex {
  private cache?: Promise<TaxonomySkill[]>;
  constructor(private db: SkillDb) {}

  skills(): Promise<TaxonomySkill[]> {
    this.cache ??= Promise.resolve(this.db.from("skills").select("id, name, category, aliases")).then(
      ({ data, error }) => {
        if (error) throw new Error(`skills read failed: ${error.message}`);
        return data ?? [];
      },
    );
    return this.cache;
  }

  async nearest(embedding: number[], threshold: number, k: number): Promise<SkillMatch[]> {
    const { data, error } = await this.db.rpc("match_skills", {
      p_embedding: embedding,
      p_threshold: threshold,
      p_k: k,
    });
    if (error) throw new Error(`match_skills failed: ${error.message}`);
    return data ?? [];
  }
}
