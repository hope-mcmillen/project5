// Years and evidence (AI-08, PRD §8.2). The LLM returns facts; these pure
// functions compute the numbers, so scores stay reproducible and can't be
// inflated by a resume that says "10 years each".
import type { ResumeExtraction } from "./schemas.ts";

type Role = ResumeExtraction["roles"][number];
type Skill = ResumeExtraction["skills"][number];

/** Months since year 0, for interval math. */
type Month = number;

/**
 * Parses "YYYY-MM", "YYYY", or "present" into a month index. A year alone counts
 * as January when it starts a role and June when it ends one, so "2019 – 2023"
 * gives 4.5 years and a role within a single year gives half a year.
 */
export function parseMonth(value: string | null, edge: "start" | "end", today: Date): Month | null {
  if (!value) return null;
  const v = value.trim().toLowerCase();
  if (edge === "end" && /^(present|current|now|today|ongoing)$/.test(v)) {
    return today.getUTCFullYear() * 12 + today.getUTCMonth();
  }
  let m = /^(\d{4})-(\d{1,2})$/.exec(v);
  if (m) {
    const month = Number(m[2]);
    return month >= 1 && month <= 12 ? Number(m[1]) * 12 + month - 1 : null;
  }
  m = /^(\d{4})$/.exec(v);
  if (m) return Number(m[1]) * 12 + (edge === "start" ? 0 : 5);
  return null;
}

/** [start, end) in months, or null if the role's dates can't be used. */
function roleInterval(role: Role, today: Date): [Month, Month] | null {
  const start = parseMonth(role.start, "start", today);
  const end = parseMonth(role.end, "end", today);
  if (start === null || end === null || end < start) return null;
  const now = today.getUTCFullYear() * 12 + today.getUTCMonth();
  return [start, Math.min(end, now) + 1]; // end month counts; never count the future
}

/** Total length of the union of intervals, so overlapping roles aren't double-counted. */
function unionMonths(intervals: Array<[Month, Month]>): number {
  const sorted = [...intervals].sort((a, b) => a[0] - b[0]);
  let total = 0;
  let cur: [Month, Month] | null = null;
  for (const [s, e] of sorted) {
    if (cur && s <= cur[1]) cur[1] = Math.max(cur[1], e);
    else {
      if (cur) total += cur[1] - cur[0];
      cur = [s, e];
    }
  }
  if (cur) total += cur[1] - cur[0];
  return total;
}

/** Rounded to the nearest 0.5 year. */
const toYears = (months: number) => Math.round((months / 12) * 2) / 2;

export const skillKey = (raw: string) => raw.trim().toLowerCase().replace(/\s+/g, " ");

/**
 * Years per skill: the union of date ranges of the roles whose skills_used
 * list it. Keyed by skillKey(raw). Skills not used in any dated role are
 * absent (they become years = null, "listed, not evidenced").
 */
export function mergeYears(roles: Role[], today: Date): Map<string, number> {
  const bySkill = new Map<string, Array<[Month, Month]>>();
  for (const role of roles) {
    const interval = roleInterval(role, today);
    if (!interval) continue;
    for (const raw of new Set(role.skills_used.map(skillKey))) {
      bySkill.set(raw, [...(bySkill.get(raw) ?? []), interval]);
    }
  }
  return new Map([...bySkill].map(([k, v]) => [k, toYears(unionMonths(v))]));
}

/** Total professional experience: the union of all dated roles. */
export function totalYears(roles: Role[], today: Date): number {
  return toYears(unionMonths(roles.map((r) => roleInterval(r, today)).filter((i) => i !== null)));
}

// ---------------------------------------------------------------------------
// Evidence
// ---------------------------------------------------------------------------

/** Lowercase, unify quotes/dashes/bullets, collapse whitespace. */
export function normalizeForEvidence(s: string): string {
  return s
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[‘’‚‛′]/g, "'")
    .replace(/[“”„‟″]/g, '"')
    .replace(/[‐-―−]/g, "-")
    .replace(/[•·▪●◦‣∙]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export type EvidenceResult = { ok: true } | { ok: false; reason: "no_evidence" | "not_in_text" | "skill_not_in_quote" };

/**
 * A skill is kept only if its evidence is a real quote from the sanitized
 * text AND that quote actually mentions the skill. This drops hallucinated
 * skills and skills pinned to an unrelated sentence.
 */
export function validateEvidence(skill: Pick<Skill, "raw" | "evidence">, text: string): EvidenceResult {
  const quote = normalizeForEvidence(skill.evidence);
  if (quote.length < 2) return { ok: false, reason: "no_evidence" };
  if (!normalizeForEvidence(text).includes(quote)) return { ok: false, reason: "not_in_text" };
  if (!quote.includes(normalizeForEvidence(skill.raw))) return { ok: false, reason: "skill_not_in_quote" };
  return { ok: true };
}

export interface ProfileSkill {
  raw: string;
  evidence: string;
  /** null = listed, not evidenced in a dated role. */
  years: number | null;
}

export interface DraftProfile {
  skills: ProfileSkill[];
  dropped: Array<{ raw: string; evidence: string; reason: Exclude<EvidenceResult, { ok: true }>["reason"] }>;
  totalYears: number;
}

/** Evidence check + years, deduplicated by skill. The input to normalization (B5). */
export function buildDraftProfile(extraction: ResumeExtraction, text: string, today: Date): DraftProfile {
  const years = mergeYears(extraction.roles, today);
  const skills: ProfileSkill[] = [];
  const dropped: DraftProfile["dropped"] = [];
  const seen = new Set<string>();
  for (const s of extraction.skills) {
    const check = validateEvidence(s, text);
    if (!check.ok) {
      dropped.push({ raw: s.raw, evidence: s.evidence, reason: check.reason });
      continue;
    }
    const key = skillKey(s.raw);
    if (seen.has(key)) continue;
    seen.add(key);
    skills.push({ raw: s.raw.trim(), evidence: s.evidence.trim(), years: years.get(key) ?? null });
  }
  return { skills, dropped, totalYears: totalYears(extraction.roles, today) };
}
