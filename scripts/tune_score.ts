// Sweeps Match Score parameters against the hand labels in
// supabase/tests/fixtures/match_pairs.json (PRD §8.4: tune before launch).
// From supabase/functions:  deno task tune:score
//
// Variant formula: raw = α × avg(required) + (1 − α) × avg(preferred), minus
// p per missing required skill. Reports exact band agreement overall and on the
// pairs humans rated Stretch or better (where v1 fails), plus how far off misses are.
import { band, computeMatch, type JobRequirement, relationKey, type Relations } from "../supabase/functions/_shared/score.ts";
import { loadSeedRelations, loadSeedSkills } from "../supabase/functions/_shared/seed_taxonomy.ts";

const data = JSON.parse(await Deno.readTextFile(new URL("../supabase/tests/fixtures/match_pairs.json", import.meta.url)));
const category = new Map((await loadSeedSkills()).map((s) => [s.name, s.category]));
const relations: Relations = new Map((await loadSeedRelations()).map((r) => [relationKey(r.skill, r.related), r.credit]));
const profiles = { ...data.profiles, ...data.synthetic_profiles };
const BANDS = ["Low", "Stretch", "Good", "Strong"];

type Scorer = (s: Array<{ skill_id: string; years: number | null }>, r: JobRequirement[]) => number;

function variant(alpha: number, penalty: number): Scorer {
  return (skills, reqs) => {
    // Reuse v1 for per-requirement scores, then aggregate differently.
    const b = computeMatch(skills, reqs, relations).breakdown;
    const avg = (xs: typeof b) => xs.length ? xs.reduce((n, e) => n + e.weight * e.score, 0) / xs.reduce((n, e) => n + e.weight, 0) : null;
    const req = avg(b.filter((e) => e.required));
    const pref = avg(b.filter((e) => !e.required));
    const raw = req === null ? pref ?? 0 : pref === null ? req : alpha * req + (1 - alpha) * pref;
    const missing = b.filter((e) => e.required && e.coverage === 0).length;
    return Math.round(100 * Math.min(1, Math.max(0, raw - penalty * missing)) + 1e-9);
  };
}

function evaluate(score: Scorer) {
  let all = 0, mid = 0, midN = 0, dist = 0;
  for (const p of data.pairs) {
    const reqs = data.jobs[p.job].map((r: { skill: string }) => ({ ...r, skill_id: r.skill, name: r.skill, category: category.get(r.skill)! }));
    const got = band(score(profiles[p.profile].map((s: { skill: string; years: number | null }) => ({ skill_id: s.skill, years: s.years })), reqs));
    const ok = got === p.expect;
    all += +ok;
    dist += Math.abs(BANDS.indexOf(got) - BANDS.indexOf(p.expect));
    if (p.expect !== "Low") (midN++, mid += +ok);
  }
  return { all: all / data.pairs.length, mid: mid / midN, dist: dist / data.pairs.length };
}

const fmt = (n: number) => `${(100 * n).toFixed(1)}%`;
const v1 = evaluate((s, r) => computeMatch(s, r, relations).score);
console.log(`v1 (current):             overall ${fmt(v1.all)}  stretch+ ${fmt(v1.mid)}  mean band error ${v1.dist.toFixed(2)}`);
const rows = [];
for (const alpha of [0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9]) {
  for (const penalty of [0, 0.05, 0.1, 0.15]) rows.push({ alpha, penalty, ...evaluate(variant(alpha, penalty)) });
}
rows.sort((a, b) => b.all - a.all || b.mid - a.mid || a.dist - b.dist);
console.log("best variants (α = share of required, p = penalty per missing required):");
for (const r of rows.slice(0, 10)) {
  console.log(`  α=${r.alpha.toFixed(2)} p=${r.penalty.toFixed(2)}  overall ${fmt(r.all)}  stretch+ ${fmt(r.mid)}  mean band error ${r.dist.toFixed(2)}`);
}
