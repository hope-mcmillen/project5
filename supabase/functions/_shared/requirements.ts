// Turns a job extraction into draft job_requirements (AI-12, PRD R-JOB-1).
// Pure, so every rule is unit-tested; parse-job does the I/O.
//
//   1. evidence: quote must be in the JD, mention the skill, and not be an injection
//   2. normalize onto the taxonomy (caller passes the results); unmapped → unmapped[]
//   3. merge duplicates per skill: required wins, most years, first quote
//   4. "X or Y" alternatives in one quote become preferred, tagged with either_of_group
//   5. caps: ≤ 8 required (extras demoted), ≤ 15 total (extras → trimmed[])
import type { NormalizedSkill } from "./normalize.ts";
import { normalizeForEvidence, validateEvidence } from "./profile.ts";
import type { JobExtraction } from "./schemas.ts";

export const MAX_REQUIREMENTS = 15;
export const MAX_REQUIRED = 8;
export const WEIGHT_REQUIRED = 2;
export const WEIGHT_PREFERRED = 1;

type Requirement = JobExtraction["requirements"][number];

export interface DraftRequirement {
  skill_id: string;
  name: string;
  category: string | null;
  required: boolean;
  min_years: number;
  weight: number;
  evidence: string;
  /** Requirements sharing a group number were alternatives ("Riverpod or Bloc"). */
  either_of_group: number | null;
}

export interface UnmappedRequirement {
  raw: string;
  required_hint: Requirement["required_hint"];
  min_years: number | null;
  evidence: string;
}

export interface RequirementsDraft {
  requirements: DraftRequirement[];
  unmapped: UnmappedRequirement[];
  /** Mapped but over the 15-requirement cap. The recruiter can swap them in. */
  trimmed: DraftRequirement[];
  /** Failed the evidence check (hallucinated or injection). Logged, not shown. */
  dropped: Array<{ raw: string; reason: string }>;
}

/** Step 1: evidence check. Returns the requirements that may be normalized. */
export function verifiedRequirements(
  reqs: Requirement[],
  text: string,
): { kept: Requirement[]; dropped: RequirementsDraft["dropped"] } {
  const kept: Requirement[] = [];
  const dropped: RequirementsDraft["dropped"] = [];
  for (const r of reqs) {
    const check = validateEvidence(r, text);
    if (check.ok) kept.push(r);
    else dropped.push({ raw: r.raw, reason: check.reason });
  }
  return { kept, dropped };
}

/** Steps 2–5. `normalized[i]` is the normalization of `kept[i].raw`. */
export function draftRequirements(
  kept: Requirement[],
  normalized: NormalizedSkill[],
  dropped: RequirementsDraft["dropped"] = [],
): RequirementsDraft {
  const unmapped: UnmappedRequirement[] = [];
  const bySkill = new Map<string, DraftRequirement>();
  const spellings = new Map<string, string[]>(); // skill_id → raw spellings, for locating it in its quote

  kept.forEach((r, i) => {
    const n = normalized[i];
    if (!n.skill_id) {
      unmapped.push({ raw: r.raw, required_hint: r.required_hint, min_years: r.min_years, evidence: r.evidence });
      return;
    }
    const required = r.required_hint === "required";
    spellings.set(n.skill_id, [...(spellings.get(n.skill_id) ?? []), r.raw]);
    const prev = bySkill.get(n.skill_id);
    if (prev) {
      prev.required ||= required;
      prev.min_years = Math.max(prev.min_years, r.min_years ?? 0);
      return;
    }
    bySkill.set(n.skill_id, {
      skill_id: n.skill_id,
      name: n.name!,
      category: n.category,
      required,
      min_years: r.min_years ?? 0,
      weight: 0, // set below
      evidence: r.evidence,
      either_of_group: null,
    });
  });

  const reqs = [...bySkill.values()];
  markAlternatives(reqs, spellings);

  // Caps, keeping the description's order: first 8 required stay required.
  let requiredSeen = 0;
  for (const r of reqs) if (r.required && ++requiredSeen > MAX_REQUIRED) r.required = false;
  for (const r of reqs) r.weight = r.required ? WEIGHT_REQUIRED : WEIGHT_PREFERRED;
  const ordered = [...reqs.filter((r) => r.required), ...reqs.filter((r) => !r.required)];
  const requirements = ordered.slice(0, MAX_REQUIREMENTS);
  // An either-of group whose partners were all trimmed isn't a choice anymore.
  const groupSize = new Map<number, number>();
  for (const r of requirements) {
    if (r.either_of_group) groupSize.set(r.either_of_group, (groupSize.get(r.either_of_group) ?? 0) + 1);
  }
  for (const r of requirements) {
    if (r.either_of_group && groupSize.get(r.either_of_group)! < 2) r.either_of_group = null;
  }
  return { requirements, unmapped, trimmed: ordered.slice(MAX_REQUIREMENTS), dropped };
}

/**
 * Two or more requirements quoting the same sentence, where the sentence joins
 * them with "or" ("FastAPI or Django", "Riverpod or Bloc"), are alternatives:
 * a candidate needs one, so none of them is required on its own. They become
 * preferred and share an either_of_group so the UI can show "one of".
 */
function markAlternatives(reqs: DraftRequirement[], spellings: Map<string, string[]>) {
  const byQuote = new Map<string, DraftRequirement[]>();
  for (const r of reqs) {
    const key = normalizeForEvidence(r.evidence);
    byQuote.set(key, [...(byQuote.get(key) ?? []), r]);
  }

  let group = 0;
  for (const [quote, members] of byQuote) {
    if (members.length < 2 || !/\b(or|either)\b/.test(quote)) continue;
    const positions = members
      .map((m) => ({ m, at: firstIndex(quote, [...(spellings.get(m.skill_id) ?? []), m.name]) }))
      .filter((p) => p.at >= 0)
      .sort((a, b) => a.at - b.at);
    // Link neighbors with "or" between them: in "Unit testing (Jest or Vitest)" only Jest and
    // Vitest are alternatives; unit testing itself stays required.
    let run: DraftRequirement[] = [];
    const close = () => {
      if (run.length >= 2) {
        group++;
        for (const m of run) Object.assign(m, { required: false, either_of_group: group });
      }
      run = [];
    };
    for (let i = 0; i < positions.length; i++) {
      const joined = i > 0 && /\bor\b/.test(quote.slice(positions[i - 1].at, positions[i].at));
      if (!joined) close();
      run.push(positions[i].m);
    }
    close();
  }
}

function firstIndex(quote: string, raws: string[]): number {
  const hits = raws.map((r) => quote.indexOf(normalizeForEvidence(r))).filter((i) => i >= 0);
  return hits.length ? Math.min(...hits) : -1;
}
