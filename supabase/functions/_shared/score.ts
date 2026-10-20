// Match Score v2 (AI-14, PRD §8.4): TypeScript mirror of public.compute_match().
// Keep the two identical: change both, bump SCORING_VERSION, and re-run the
// regression (supabase/tests/fixtures/match_pairs.json). Used by the seed
// generator (B10) and tests; the app gets scores from SQL.
//
//   coverage(r) = 1 exact | best skill_relations.credit | 0
//   depth(r)    = min_years == 0 ? 1 : (years null ? 0.5 : min(1, years / min_years))
//   score(r)    = coverage × (0.6 + 0.4 × depth)
//   req         = Σ weight·score(r) / Σ weight over required r   (pref: same over preferred)
//   raw         = 0.85 × req + 0.15 × pref   (only one group present → that group's average)
//   Match Score = round(100 × clamp(raw, 0, 1))
//
// v2 (2026-10-19) replaced v1's single weighted average − 0.15 per missing required:
// on 74 hand-labeled pairs v1 agreed with human bands 70% of the time (0% on pairs
// rated Stretch or better) and v2 84% (45%). Missing required skills are still costly
// through the 85% required share; v1 counted them twice. Tune: deno task tune:score.

export const SCORING_VERSION = "v2";
/** Share of the score that comes from required skills (preferred get the rest). */
export const REQUIRED_SHARE = 0.85;

export interface CandidateSkill {
  skill_id: string;
  years: number | null;
}

export interface JobRequirement {
  skill_id: string;
  name: string;
  category: string;
  required: boolean;
  min_years: number;
  weight: number;
}

/** skill_relations: `${skill_id}>${related_skill_id}` → credit (candidate has skill_id, job wants related). */
export type Relations = Map<string, number>;
export const relationKey = (have: string, want: string) => `${have}>${want}`;

export type MatchedVia = "exact" | "related" | "none";

/** One radar spoke (SCHEMA §6 / API_CONTRACT §4). */
export interface BreakdownEntry {
  skill_id: string;
  name: string;
  category: string;
  required: boolean;
  weight: number;
  min_years: number;
  candidate_years: number | null;
  matched_via: MatchedVia;
  coverage: number;
  depth: number;
  score: number;
}

export interface MatchResult {
  score: number;
  breakdown: BreakdownEntry[];
}

export type Band = "Strong" | "Good" | "Stretch" | "Low";

/** PRD §3.3 bands. */
export function band(score: number): Band {
  return score >= 85 ? "Strong" : score >= 70 ? "Good" : score >= 50 ? "Stretch" : "Low";
}

const r3 = (n: number) => Math.round(n * 1000) / 1000;

export function computeMatch(
  skills: CandidateSkill[],
  requirements: JobRequirement[],
  relations: Relations,
): MatchResult {
  const have = new Map(skills.map((s) => [s.skill_id, s.years]));
  const sums = { req: [0, 0], pref: [0, 0] }; // [Σ weight·score, Σ weight]

  const entries = requirements.map((r) => {
    // Best match: exact first, else the highest relation credit (ties → more years).
    let coverage = 0;
    let years: number | null = null;
    let via: MatchedVia = "none";
    if (have.has(r.skill_id)) {
      coverage = 1;
      years = have.get(r.skill_id)!;
      via = "exact";
    } else {
      for (const [id, y] of have) {
        const credit = relations.get(relationKey(id, r.skill_id)) ?? 0;
        if (
          credit > coverage ||
          (credit === coverage && credit > 0 && (y ?? -1) > (years ?? -1))
        ) {
          coverage = credit;
          years = y;
          via = "related";
        }
      }
    }
    const depth = r.min_years === 0 ? 1 : years === null ? 0.5 : Math.min(1, years / r.min_years);
    const score = coverage * (0.6 + 0.4 * depth);
    const group = r.required ? sums.req : sums.pref;
    group[0] += r.weight * score;
    group[1] += r.weight;
    return {
      skill_id: r.skill_id,
      name: r.name,
      category: r.category,
      required: r.required,
      weight: r.weight,
      min_years: r.min_years,
      candidate_years: years,
      matched_via: via,
      coverage: r3(coverage),
      depth: r3(depth),
      score: r3(score),
    };
  });

  const req = sums.req[1] ? sums.req[0] / sums.req[1] : null;
  const pref = sums.pref[1] ? sums.pref[0] / sums.pref[1] : null;
  const raw = req === null ? pref ?? 0 : pref === null ? req : REQUIRED_SHARE * req + (1 - REQUIRED_SHARE) * pref;
  // Round to 6 decimals first, like the SQL: floating point (and SQL's truncated decimals)
  // can land an exact .5 such as 80.5 just below it.
  const score = Math.round(Math.round(100 * Math.min(1, Math.max(0, raw)) * 1e6) / 1e6);
  entries.sort((a, b) =>
    Number(b.required) - Number(a.required) || b.weight - a.weight ||
    cmp(a.name, b.name)
  );
  return { score, breakdown: entries };
}

/** Byte-order comparison, like Postgres "C"-collation ORDER BY on names. */
function cmp(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}
