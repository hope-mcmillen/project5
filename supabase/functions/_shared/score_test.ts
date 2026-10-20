import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { band, computeMatch, type JobRequirement, relationKey, type Relations } from "./score.ts";
import { loadSeedRelations, loadSeedSkills } from "./seed_taxonomy.ts";

const skills = await loadSeedSkills();
const category = new Map(skills.map((s) => [s.name, s.category]));
const relations: Relations = new Map(
  (await loadSeedRelations()).map((r) => [relationKey(r.skill, r.related), r.credit]),
);
const req = (name: string, required = true, min_years = 0): JobRequirement => ({
  skill_id: name,
  name,
  category: category.get(name) ?? "Tools",
  required,
  min_years,
  weight: required ? 2 : 1,
});

// --- Formula rules -------------------------------------------------------------------

Deno.test("exact match with enough years scores 100; bands follow PRD §3.3", () => {
  const r = computeMatch([{ skill_id: "Python", years: 5 }], [req("Python", true, 3)], relations);
  assertEquals(r.score, 100);
  assertEquals(r.breakdown[0], {
    skill_id: "Python",
    name: "Python",
    category: "Languages",
    required: true,
    weight: 2,
    min_years: 3,
    candidate_years: 5,
    matched_via: "exact",
    coverage: 1,
    depth: 1,
    score: 1,
  });
  assertEquals([band(100), band(85), band(84), band(70), band(69), band(50), band(49), band(0)], [
    "Strong",
    "Strong",
    "Good",
    "Good",
    "Stretch",
    "Stretch",
    "Low",
    "Low",
  ]);
});

Deno.test("depth: years / min_years, 1 when no minimum, 0.5 when years are unknown", () => {
  const d = (years: number | null, min: number) =>
    computeMatch([{ skill_id: "Go", years }], [req("Go", true, min)], relations).breakdown[0].depth;
  assertEquals([d(1, 2), d(3, 2), d(null, 2), d(null, 0), d(0, 0)], [0.5, 1, 0.5, 1, 1]);
  // having the skill matters more than years: 1 of 4 years still earns 0.7
  assertEquals(computeMatch([{ skill_id: "Go", years: 1 }], [req("Go", true, 4)], relations).score, 70);
});

Deno.test("related skills earn the curated credit; best relation wins, ties go to more years", () => {
  // MySQL → PostgreSQL 0.6; MariaDB → PostgreSQL has no relation; MariaDB → MySQL 0.85
  const r = computeMatch(
    [{ skill_id: "MySQL", years: 4 }, { skill_id: "SQLite", years: 9 }],
    [req("PostgreSQL", true, 2)],
    relations,
  );
  assertEquals([r.breakdown[0].matched_via, r.breakdown[0].coverage, r.breakdown[0].candidate_years], [
    "related",
    0.6,
    4,
  ]);
  assertEquals(r.score, 60);
  const exact = computeMatch([{ skill_id: "MySQL", years: 1 }, { skill_id: "PostgreSQL", years: 1 }], [
    req("PostgreSQL"),
  ], relations);
  assertEquals(exact.breakdown[0].matched_via, "exact"); // exact always beats related
});

Deno.test("v2: 85% from required, 15% from preferred; a lone group counts fully", () => {
  // Storybook has no skill_relations, so it only ever counts for itself.
  const job = [req("React"), req("TypeScript"), req("Storybook", false)];
  const score = (have: string[], reqs = job) =>
    computeMatch(have.map((skill_id) => ({ skill_id, years: 3 })), reqs, relations).score;
  assertEquals(score(["React"]), 43); // 0.85 × ½
  assertEquals(score(["React", "TypeScript"]), 85);
  assertEquals(score(["React", "TypeScript", "Storybook"]), 100);
  assertEquals(score(["Storybook"]), 15); // preferred skills alone are worth little
  assertEquals(score(["Storybook"], [req("Storybook", false)]), 100); // a job that lists only preferred skills
  assertEquals(score([]), 0);
  assertEquals(computeMatch([{ skill_id: "React", years: 1 }], [], relations), { score: 0, breakdown: [] });
});

Deno.test("API_CONTRACT §5 example: default resume vs job01 = 92", () => {
  const have = {
    Flutter: 6.5,
    Dart: 4.5,
    "State Management": null,
    "REST APIs": 1.5,
    Git: 1.5,
    "Code Review": null,
    Bloc: 1.5,
    "Cloud Firestore": 4.5,
    Firebase: 4.5,
    Riverpod: 4.5,
  };
  const job = [
    req("Flutter", true, 2),
    req("Dart", true, 2),
    req("State Management"),
    req("REST APIs"),
    req("Git"),
    req("Code Review"),
    ...[
      "Accessibility",
      "Bloc",
      "Cloud Firestore",
      "Firebase",
      "HIPAA Compliance",
      "Kotlin",
      "Push Notifications",
      "Riverpod",
      "Swift",
    ]
      .map((n) => req(n, false)),
  ];
  const r = computeMatch(Object.entries(have).map(([skill_id, years]) => ({ skill_id, years })), job, relations);
  assertEquals(r.score, 92); // 0.85 × 1 + 0.15 × 4/9
  assertEquals(r.breakdown.slice(0, 6).every((e) => e.required), true); // required first
  assertEquals(r.breakdown.find((e) => e.name === "Kotlin")!.matched_via, "none");
});

// --- AI-17 regression against human judgment ---------------------------------------------

type Pairs = {
  profiles: Record<string, Array<{ skill: string; years: number | null }>>;
  synthetic_profiles: Record<string, Array<{ skill: string; years: number | null }>>;
  jobs: Record<string, Array<{ skill: string; required: boolean; min_years: number; weight: number }>>;
  pairs: Array<{ profile: string; job: string; expect: string }>;
};
const data: Pairs = JSON.parse(
  await Deno.readTextFile(new URL("../../tests/fixtures/match_pairs.json", import.meta.url)),
);
const BANDS = ["Strong", "Good", "Stretch", "Low"];

export function runRegression(score = computeMatch) {
  const profiles = { ...data.profiles, ...data.synthetic_profiles };
  return data.pairs.map((p) => {
    const reqs = data.jobs[p.job].map((r) => ({
      ...r,
      skill_id: r.skill,
      name: r.skill,
      category: category.get(r.skill)!,
    }));
    const res = score(profiles[p.profile].map((s) => ({ skill_id: s.skill, years: s.years })), reqs, relations);
    return { ...p, score: res.score, got: band(res.score) };
  });
}

Deno.test("match_pairs.json uses only taxonomy skills and known profiles/jobs", () => {
  const profiles = { ...data.profiles, ...data.synthetic_profiles };
  for (const [k, v] of Object.entries(profiles)) for (const s of v) assert(category.has(s.skill), `${k}: ${s.skill}`);
  for (const [k, v] of Object.entries(data.jobs)) for (const r of v) assert(category.has(r.skill), `${k}: ${r.skill}`);
  for (const p of data.pairs) {
    assert(profiles[p.profile] && data.jobs[p.job] && BANDS.includes(p.expect), JSON.stringify(p));
  }
  assert(data.pairs.length >= 50);
});

Deno.test("AI-17: computed bands agree with human labels on at least 80% of pairs", () => {
  const results = runRegression();
  const agree = results.filter((r) => r.got === r.expect).length;
  const table = Object.fromEntries(BANDS.map((e) => [
    `human ${e}`,
    Object.fromEntries(BANDS.map((g) => [`score ${g}`, results.filter((r) => r.expect === e && r.got === g).length])),
  ]));
  console.log(`\nband agreement: ${agree}/${results.length} = ${(100 * agree / results.length).toFixed(1)}%`);
  console.table(table);
  for (const r of results.filter((r) => r.got !== r.expect)) {
    console.log(`  ✗ ${r.profile} × ${r.job}: human ${r.expect}, score ${r.score} (${r.got})`);
  }
  assert(agree / results.length >= 0.8, "band agreement below 80%: review the formula or the labels");
});

Deno.test("an exact .5 rounds up despite repeating decimals (r04 × job04 = 80.5 → 81)", () => {
  const r = runRegression().find((x) => x.profile === "r04_devops_single_column" && x.job === "job04_devops_sre")!;
  assertEquals(r.score, 81); // 0.85 × 4/5 + 0.15 × 5/6 = 0.805 exactly; SQL matches (verified in Postgres)
});
