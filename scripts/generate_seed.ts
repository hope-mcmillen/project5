// Demo data generator (B10 / AI-20, PRD §9.8). From supabase/functions:
//   deno task generate:seed
//
// Writes supabase/seed/demo_data.sql (included by A6's seed.sql after skills.sql and
// skills_embeddings.sql) and supabase/seed/demo_manifest.json (stable ids + the
// scores the TypeScript scorer expects, for verification).
//
// Deterministic: a fixed PRNG seed and name-derived UUIDs, so re-running gives the
// same file. No AI at generation or load time: job requirements come from the
// recorded parse-job fixtures (mock provider), candidates are searched until the
// v2 scorer puts them in a target band, and at load time scores/breakdowns come
// from compute_match() and vectors from skills_centroid() in SQL.
import { MemoryJobRepo } from "../supabase/functions/_shared/job_repo.ts";
import { parseJob } from "../supabase/functions/_shared/job_pipeline.ts";
import { MockProvider } from "../supabase/functions/_shared/llm.ts";
import {
  type Band,
  band,
  computeMatch,
  type JobRequirement,
  relationKey,
  type Relations,
} from "../supabase/functions/_shared/score.ts";
import { loadSeedRelations, loadSeedSkills, seedSkillIndex } from "../supabase/functions/_shared/seed_taxonomy.ts";

const SEED = new URL("../supabase/seed/", import.meta.url);
const OUT_SQL = new URL("demo_data.sql", SEED);
const OUT_MANIFEST = new URL("demo_manifest.json", SEED);
const RANDOM_SEED = 20261020;

// --- deterministic helpers ----------------------------------------------------------

function mulberry32(seed: number) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(RANDOM_SEED);
const pick = <T>(xs: readonly T[]) => xs[Math.floor(rand() * xs.length)];
const chance = (p: number) => rand() < p;
const between = (lo: number, hi: number) => lo + rand() * (hi - lo);
const halfYears = (n: number) => Math.max(0.5, Math.round(n * 2) / 2);
function shuffle<T>(xs: T[]): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Stable UUID (v4 layout) from a name, so other seed files can reference rows. */
async function uuidFor(name: string): Promise<string> {
  const h = new Uint8Array(
    await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(`resurhombus-seed:${name}`),
    ),
  );
  h[6] = (h[6] & 0x0f) | 0x40;
  h[8] = (h[8] & 0x3f) | 0x80;
  const hex = Array.from(h.slice(0, 16), (b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}
const q = (
  s: string | null,
) => (s === null ? "null" : `'${s.replaceAll("'", "''")}'`);
const ago = (hours: number) => `now() - interval '${hours.toFixed(2)} hours'`;

// --- static demo world (PRD §9.8) ------------------------------------------------------

const COMPANIES = [
  {
    key: "pelican",
    name: "Pelican Path Health",
    website: "https://pelicanpath.example.com",
    verified: true,
  },
  {
    key: "bayou",
    name: "Bayou Ledger",
    website: "https://bayouledger.example.com",
    verified: false,
  },
  {
    key: "crescent",
    name: "Crescent Freight Analytics",
    website: "https://crescentfreight.example.com",
    verified: true,
  },
] as const;

/** Each seed JD → company and status. The JD's own company name is swapped for the seed company's. */
const JOBS = [
  {
    file: "job01_flutter_mobile.txt",
    company: "pelican",
    status: "OPEN",
    originalCompany: "Pelican Path Health",
    daysAgo: 2,
  },
  {
    file: "job02_python_backend.txt",
    company: "bayou",
    status: "OPEN",
    originalCompany: "Bayou Ledger",
    daysAgo: 6,
  },
  {
    file: "job03_data_engineer.txt",
    company: "crescent",
    status: "OPEN",
    originalCompany: "Crescent Freight Analytics",
    daysAgo: 10,
  },
  {
    file: "job04_devops_sre.txt",
    company: "crescent",
    status: "CLOSED",
    originalCompany: "Magnolia Grid Systems",
    daysAgo: 45,
  },
  {
    file: "job05_frontend_react.txt",
    company: "bayou",
    status: "DRAFT",
    originalCompany: "Cypress Lane Commerce",
    daysAgo: 0,
  },
  {
    file: "job06_ml_engineer.txt",
    company: "pelican",
    status: "OPEN",
    originalCompany: "Gulfstream Diagnostics",
    daysAgo: 4,
  },
] as const;

/** One owner per company; Crescent also has a member (invite-code demo). Seed users can't sign in. */
const RECRUITERS = [
  {
    key: "rec-pelican",
    company: "pelican",
    role: "owner",
    name: "Dana Pelican (seed)",
  },
  {
    key: "rec-bayou",
    company: "bayou",
    role: "owner",
    name: "Sam Bayou (seed)",
  },
  {
    key: "rec-crescent",
    company: "crescent",
    role: "owner",
    name: "Lee Crescent (seed)",
  },
  {
    key: "rec-crescent-2",
    company: "crescent",
    role: "member",
    name: "Jo Crescent (seed)",
  },
] as const;

const FIRST = [
  "Avery",
  "Blake",
  "Casey",
  "Devon",
  "Emery",
  "Finley",
  "Harper",
  "Jordan",
  "Kai",
  "Logan",
  "Morgan",
  "Noel",
  "Parker",
  "Quinn",
  "Reese",
  "Rowan",
  "Sage",
  "Skyler",
  "Tatum",
  "Wren",
];
const LAST = [
  "Arceneaux",
  "Boudreaux",
  "Comeaux",
  "Doucet",
  "Fontenot",
  "Guidry",
  "Hebert",
  "Landry",
  "LeBlanc",
  "Melancon",
  "Naquin",
  "Ortego",
  "Prejean",
  "Robichaux",
  "Savoie",
  "Thibodeaux",
  "Trahan",
  "Vidrine",
];
const EMPLOYERS = [
  "Levee Labs",
  "Bayou Byte",
  "Delta Digital",
  "Red Stick Systems",
  "Atchafalaya Tech",
  "Gulf South Software",
  "Cajun Cloud",
  "Riverbend Data",
];

// Five candidates per job, searched until the scorer lands them in these bands for that job.
// Every job also gets ~25 Low candidates for free: the other jobs' candidates.
const TARGETS: Band[] = ["Strong", "Strong", "Good", "Good", "Stretch"];
const STATUSES = [
  "APPLIED",
  "UNDER_REVIEW",
  "INTERVIEW_REQUESTED",
  "NOT_SELECTED",
  "WITHDRAWN",
] as const;

// --- load taxonomy and parse the jobs with the recorded fixtures ------------------------------

const skills = await loadSeedSkills();
const category = new Map(skills.map((s) => [s.name, s.category]));
const relations: Relations = new Map(
  (await loadSeedRelations()).map((
    r,
  ) => [relationKey(r.skill, r.related), r.credit]),
);
const index = await seedSkillIndex();
const llm = new MockProvider();

type Job = (typeof JOBS)[number] & {
  id: string;
  key: string;
  raw: string;
  fields: Record<string, unknown>;
  reqs: JobRequirement[];
};
const jobs: Job[] = [];
for (const j of JOBS) {
  const raw = (await Deno.readTextFile(new URL(`jobs/${j.file}`, SEED)))
    .replaceAll(
      j.originalCompany,
      COMPANIES.find((c) => c.key === j.company)!.name,
    );
  const repo = new MemoryJobRepo();
  repo.recruiters.set("rec", "co");
  repo.add({
    id: "seed",
    company_id: "co",
    raw_description: await Deno.readTextFile(new URL(`jobs/${j.file}`, SEED)),
  });
  const res = await parseJob({ repo, llm, index, log: () => {} }, {
    jobId: "seed",
    userId: "rec",
  });
  if (res.parse_status !== "READY") {
    throw new Error(`${j.file}: ${JSON.stringify(res)}`);
  }
  const key = j.file.replace(/\.txt$/, "");
  jobs.push({
    ...j,
    key,
    id: await uuidFor(`job:${key}`),
    raw,
    fields: res.job,
    reqs: res.requirements.map((r) => ({
      skill_id: r.skill_id,
      name: r.skill_id,
      category: category.get(r.skill_id)!,
      required: r.required,
      min_years: r.min_years,
      weight: r.weight,
    })),
  });
}

// --- candidates --------------------------------------------------------------------------------

interface Candidate {
  key: string;
  id: string;
  versionId: string;
  name: string;
  forJob: string;
  target: Band;
  skills: Array<{ skill: string; years: number | null }>;
  prefs: Record<string, unknown>;
  employer: string;
}

/** A plausible profile for `job` aimed at `target`; deterministic given the PRNG state. */
function proposal(job: Job, target: Band): Candidate["skills"] {
  const p = {
    Strong: [1, 0.7, 1.3],
    Good: [0.85, 0.4, 0.8],
    Stretch: [0.5, 0.25, 0.6],
    Low: [0.15, 0.1, 0.5],
  }[target];
  const [pRequired, pPreferred, yearsFactor] = p;
  const out = new Map<string, number | null>();
  for (const r of job.reqs) {
    if (!chance(r.required ? pRequired : pPreferred)) continue;
    const base = r.min_years || between(1, 4);
    out.set(
      r.skill_id,
      chance(0.1) ? null : halfYears(base * between(yearsFactor * 0.6, yearsFactor * 1.4)),
    );
  }
  // A few neighbors from the same categories, so profiles don't look copied from the JD.
  const cats = new Set(job.reqs.map((r) => r.category));
  const pool = skills.filter((s) => cats.has(s.category) && !out.has(s.name));
  for (let i = 0; i < 2 + Math.floor(rand() * 3); i++) {
    out.set(pick(pool).name, halfYears(between(0.5, 5)));
  }
  if (target === "Low") {
    // Mostly a different stack: borrow from another job's requirements.
    const other = pick(jobs.filter((x) => x.key !== job.key));
    for (const r of shuffle(other.reqs).slice(0, 5)) {
      out.set(r.skill_id, halfYears(between(1, 6)));
    }
  }
  return [...out].map(([skill, years]) => ({ skill, years }));
}

const scoreOf = (cs: Candidate["skills"], job: Job) =>
  computeMatch(
    cs.map((s) => ({ skill_id: s.skill, years: s.years })),
    job.reqs,
    relations,
  ).score;

const candidates: Candidate[] = [];
let n = 0;
for (const job of jobs) {
  for (const target of TARGETS) {
    let found: Candidate["skills"] | null = null;
    for (let attempt = 0; attempt < 5000 && !found; attempt++) {
      const s = proposal(job, target);
      if (s.length >= 3 && band(scoreOf(s, job)) === target) found = s;
    }
    if (!found) throw new Error(`no ${target} candidate found for ${job.key}`);
    n++;
    const key = `cand-${String(n).padStart(2, "0")}`;
    const remotePrefs = chance(0.7) ? [] : shuffle(["remote", "hybrid", "onsite"]).slice(0, 2);
    candidates.push({
      key,
      id: await uuidFor(`user:${key}`),
      versionId: await uuidFor(`profile_version:${key}`),
      name: `${pick(FIRST)} ${pick(LAST)}`,
      forJob: job.key,
      target,
      skills: found.sort((a, b) => a.skill.localeCompare(b.skill)),
      prefs: remotePrefs.length ? { remote: remotePrefs } : {},
      employer: pick(EMPLOYERS),
    });
  }
}

// Full score matrix (TypeScript expectation; SQL compute_match must agree).
const scores = new Map<string, number>();
for (const c of candidates) {
  for (const j of jobs) scores.set(`${c.key}|${j.key}`, scoreOf(c.skills, j));
}

// --- applications and swipes ------------------------------------------------------------------

interface Application {
  id: string;
  swipeId: string;
  cand: Candidate;
  job: Job;
  status: string;
  hoursAgo: number;
}
interface Pass {
  id: string;
  cand: Candidate;
  job: Job;
  reason: string;
  hoursAgo: number;
}

const applications: Application[] = [];
const passes: Pass[] = [];
const swipeable = jobs.filter((j) => j.status !== "DRAFT");
const quota: Record<string, number> = {
  job01_flutter_mobile: 15,
  job02_python_backend: 15,
  job03_data_engineer: 12,
  job06_ml_engineer: 12,
  job04_devops_sre: 6,
};

for (const job of swipeable) {
  // Applicants: mostly the best matches, plus a couple of hopeful stretch/low applies.
  const ranked = [...candidates].sort((a, b) =>
    scores.get(`${b.key}|${job.key}`)! - scores.get(`${a.key}|${job.key}`)!
  );
  const want = quota[job.key];
  const top = ranked.slice(0, want - 2);
  const hopeful = shuffle(ranked.slice(want)).slice(0, 2);
  // Recruiter decisions by rank within the job: the best are invited or under review, the
  // middle waits, one withdraws, and the weakest are not selected. The closed job's
  // applicants all end JOB_CLOSED.
  const plan = [
    "INTERVIEW_REQUESTED",
    "INTERVIEW_REQUESTED",
    "UNDER_REVIEW",
    "UNDER_REVIEW",
    "UNDER_REVIEW",
    "APPLIED",
    "APPLIED",
    "APPLIED",
    "WITHDRAWN",
    "APPLIED",
    "NOT_SELECTED",
    "APPLIED",
    "NOT_SELECTED",
    "NOT_SELECTED",
    "NOT_SELECTED",
  ];
  for (const [i, cand] of [...top, ...hopeful].entries()) {
    const status = job.status === "CLOSED" ? "JOB_CLOSED" : plan[Math.min(i, plan.length - 1)];
    const hoursAgo = job.status === "CLOSED" ? between(24 * 20, 24 * 40) : between(1, 24 * Math.max(1, job.daysAgo));
    applications.push({
      id: await uuidFor(`application:${cand.key}:${job.key}`),
      swipeId: await uuidFor(`swipe:${cand.key}:${job.key}`),
      cand,
      job,
      status,
      hoursAgo,
    });
  }
}
// Every status must appear (PRD §9.8); patch the lowest-risk applications if the dice missed one.
for (const status of [...STATUSES, "JOB_CLOSED"]) {
  if (!applications.some((a) => a.status === status)) {
    const victim = applications.find((a) => a.job.status === "OPEN" && a.status === "APPLIED")!;
    victim.status = status;
  }
}

// Passes: candidates skip open jobs they didn't apply to; reasons follow the mismatch.
const applied = new Set(applications.map((a) => `${a.cand.key}|${a.job.key}`));
for (const cand of candidates) {
  for (const job of swipeable) {
    if (applied.has(`${cand.key}|${job.key}`) || !chance(0.85)) continue;
    const s = scores.get(`${cand.key}|${job.key}`)!;
    // Weak matches are mostly passed for stack/seniority, good ones for practical reasons.
    // Every reason appears, so Feed Rank's affinity rules have signal in the demo.
    const reason = s < 50
      ? pick(["stack", "stack", "stack", "seniority", "seniority", "location", "salary", "company"])
      : job.fields.remote === "onsite"
      ? "location"
      : pick(["salary", "salary", "location", "location", "company", "seniority"]);
    passes.push({
      id: await uuidFor(`swipe:${cand.key}:${job.key}`),
      cand,
      job,
      reason,
      hoursAgo: between(1, 24 * Math.max(1, job.daysAgo)),
    });
  }
}

// --- SQL ------------------------------------------------------------------------------------------

const ids = {
  company: Object.fromEntries(
    await Promise.all(
      COMPANIES.map(async (c) => [c.key, await uuidFor(`company:${c.key}`)]),
    ),
  ),
  recruiter: Object.fromEntries(
    await Promise.all(
      RECRUITERS.map(async (r) => [r.key, await uuidFor(`user:${r.key}`)]),
    ),
  ),
};
const ownerOf = (company: string) =>
  ids.recruiter[
    RECRUITERS.find((r) => r.company === company && r.role === "owner")!.key
  ];
const skillId = (name: string) => `(select id from public.skills where name = ${q(name)})`;
const sql: string[] = [];
const emit = (s: string) => sql.push(s);

emit(
  `-- Demo data (B10 / AI-20, PRD §9.8). GENERATED by scripts/generate_seed.ts (seed ${RANDOM_SEED}). Do not edit.
-- Load after skills.sql and skills_embeddings.sql (needs compute_match/skills_centroid migrations).
-- Every row has is_seed = true where the table has the column. Seed users have no password and can't sign in;
-- demo accounts (A6) attach to these companies by the ids in demo_manifest.json.
begin;
`,
);

const userRow = (id: string, email: string, role: string) =>
  `insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', ${q(id)}, 'authenticated', 'authenticated', ${
    q(email)
  }, '', now(), '{"provider":"email","providers":["email"]}', ${q(JSON.stringify({ role }))}, now(), now())
on conflict (id) do nothing;`;
const profileRow = (id: string, role: string, name: string) =>
  `insert into public.profiles (id, role, display_name, is_seed) values (${q(id)}, ${q(role)}, ${q(name)}, true)
on conflict (id) do update set role = excluded.role, display_name = excluded.display_name, is_seed = true;`;

emit(
  "-- Companies and recruiters --------------------------------------------------------------",
);
for (const r of RECRUITERS) {
  emit(userRow(ids.recruiter[r.key], `${r.key}@seed.example.com`, "recruiter"));
  emit(profileRow(ids.recruiter[r.key], "recruiter", r.name));
}
for (const c of COMPANIES) {
  emit(
    `insert into public.companies (id, name, website, verified, created_by, is_seed)
values (${q(ids.company[c.key])}, ${q(c.name)}, ${q(c.website)}, ${c.verified}, ${
      q(ownerOf(c.key))
    }, true) on conflict (id) do nothing;`,
  );
}
for (const r of RECRUITERS) {
  emit(`insert into public.recruiters (profile_id, company_id, company_role)
values (${q(ids.recruiter[r.key])}, ${q(ids.company[r.company])}, ${q(r.role)}) on conflict (profile_id) do nothing;`);
}

emit(
  "\n-- Jobs (requirements from the recorded parse-job fixtures; vectors from the taxonomy) ----------",
);
for (const j of jobs) {
  const f = j.fields as Record<string, string | number | boolean | null>;
  const published = j.status === "DRAFT" ? "null" : `now() - interval '${j.daysAgo} days'`;
  emit(
    `insert into public.jobs (id, company_id, created_by, title, raw_description, parse_status, status, location, remote, job_type,
  sponsorship, salary_min, salary_max, published_at, expires_at, is_seed)
values (${q(j.id)}, ${q(ids.company[j.company])}, ${q(ownerOf(j.company))}, ${q(f.title as string)}, ${
      q(j.raw)
    }, 'READY', ${q(j.status)},
  ${q((f.location as string) ?? null)}, ${f.remote ? q(f.remote as string) : "null"}, ${
      f.job_type ? q(f.job_type as string) : "null"
    },
  ${f.sponsorship === true}, ${f.salary_min ?? "null"}, ${f.salary_max ?? "null"}, ${published},
  ${j.status === "DRAFT" ? "null" : `now() - interval '${j.daysAgo} days' + interval '60 days'`}, true)
on conflict (id) do nothing;`,
  );
  for (const r of j.reqs) {
    emit(
      `insert into public.job_requirements (job_id, skill_id, required, min_years, weight)
values (${q(j.id)}, ${
        skillId(r.skill_id)
      }, ${r.required}, ${r.min_years}, ${r.weight}) on conflict (job_id, skill_id) do nothing;`,
    );
  }
  emit(
    `update public.jobs set embedding = public.skills_centroid(array(select skill_id from public.job_requirements where job_id = ${
      q(j.id)
    })),
  embedding_model = 'gemini-embedding-001@1536' where id = ${q(j.id)};`,
  );
}

emit(
  "\n-- Candidates: confirmed profiles aimed at a band for one job each ------------------------------",
);
for (const c of candidates) {
  const total = Math.max(...c.skills.map((s) => s.years ?? 0));
  emit(userRow(c.id, `${c.key}@seed.example.com`, "candidate"));
  emit(profileRow(c.id, "candidate", c.name));
  emit(
    `insert into public.candidates (profile_id, preferences, is_seed) values (${q(c.id)}, ${
      q(JSON.stringify(c.prefs))
    }, true)
on conflict (profile_id) do nothing;`,
  );
  emit(
    `insert into public.profile_versions (id, candidate_id, version, source, confirmed, confirmed_at, total_years, education, is_seed)
values (${q(c.versionId)}, ${
      q(c.id)
    }, 1, 'resume', true, now() - interval '30 days', ${total}, '[{"level":"BS","field":"Computer Science"}]', true)
on conflict (id) do nothing;`,
  );
  for (const s of c.skills) {
    const evidence = s.years === null ? `Skills: ${s.skill}` : `Used ${s.skill} for ${s.years} years at ${c.employer}`;
    emit(
      `insert into public.candidate_skills (profile_version_id, skill_id, raw_name, years, evidence, source)
values (${q(c.versionId)}, ${skillId(s.skill)}, ${q(s.skill)}, ${s.years ?? "null"}, ${q(evidence)}, 'ai')
on conflict do nothing;`,
    );
  }
  emit(
    `update public.profile_versions set embedding = public.skills_centroid(array(
    select skill_id from public.candidate_skills where profile_version_id = ${
      q(c.versionId)
    } and skill_id is not null)),
  embedding_model = 'gemini-embedding-001@1536' where id = ${q(c.versionId)};
update public.candidates set active_version_id = ${q(c.versionId)} where profile_id = ${q(c.id)};`,
  );
}

emit(
  "\n-- Applications (right swipes) with status history; scores computed by compute_match() ----------",
);
const PATH: Record<string, string[]> = {
  APPLIED: ["APPLIED"],
  UNDER_REVIEW: ["APPLIED", "UNDER_REVIEW"],
  INTERVIEW_REQUESTED: ["APPLIED", "UNDER_REVIEW", "INTERVIEW_REQUESTED"],
  NOT_SELECTED: ["APPLIED", "UNDER_REVIEW", "NOT_SELECTED"],
  WITHDRAWN: ["APPLIED", "WITHDRAWN"],
  JOB_CLOSED: ["APPLIED", "UNDER_REVIEW", "JOB_CLOSED"],
};
for (const a of applications) {
  const path = PATH[a.status];
  const rec = ownerOf(a.job.company);
  const prev = path.length > 1 ? path[path.length - 2] : null;
  emit(
    `insert into public.swipes (id, candidate_id, job_id, direction, is_seed, created_at)
values (${q(a.swipeId)}, ${q(a.cand.id)}, ${q(a.job.id)}, 'right', true, ${ago(a.hoursAgo)}) on conflict do nothing;`,
  );
  emit(
    `insert into public.applications (id, swipe_id, candidate_id, job_id, profile_version_id, status, previous_status, match_score,
  breakdown, scoring_version, committed_at, advanced_by, interview_note, rejected_at, is_seed, created_at)
select ${q(a.id)}, ${q(a.swipeId)}, ${q(a.cand.id)}, ${q(a.job.id)}, ${q(a.cand.versionId)}, ${q(a.status)},
  ${a.status === "NOT_SELECTED" ? q(prev) : "null"}, (m.r ->> 'score')::smallint, m.r -> 'breakdown', 'v2',
  ${ago(a.hoursAgo)} + interval '5 seconds',
  ${a.status === "INTERVIEW_REQUESTED" ? q(rec) : "null"},
  ${
      a.status === "INTERVIEW_REQUESTED"
        ? q(
          "Thanks for applying! I'd love to set up a 30-minute call. Reply with a few times that work.",
        )
        : "null"
    },
  ${a.status === "NOT_SELECTED" ? `${ago(a.hoursAgo * 0.3)}` : "null"}, true, ${ago(a.hoursAgo)}
from (select public.compute_match(${q(a.cand.versionId)}, ${q(a.job.id)}) as r) m
on conflict (id) do nothing;`,
  );
  path.forEach((to, i) => {
    const from = i === 0 ? null : path[i - 1];
    // Candidate acts first and on withdraw; recruiters review/advance/reject; closing is the system.
    const actor = i === 0 || to === "WITHDRAWN" ? q(a.cand.id) : to === "JOB_CLOSED" ? "null" : q(rec);
    const when = ago(a.hoursAgo * (1 - (0.7 * i) / path.length));
    emit(
      `insert into public.status_events (application_id, from_status, to_status, actor_id, created_at)
select ${q(a.id)}, ${from ? q(from) : "null"}, ${q(to)}, ${actor}, ${when}
where not exists (select 1 from public.status_events where application_id = ${q(a.id)} and to_status = ${q(to)});`,
    );
  });
}

emit(
  "\n-- Passes (left swipes) with reasons, so Feed Rank has signal ------------------------------------",
);
for (const p of passes) {
  emit(
    `insert into public.swipes (id, candidate_id, job_id, direction, pass_reason, is_seed, created_at)
values (${q(p.id)}, ${q(p.cand.id)}, ${q(p.job.id)}, 'left', ${q(p.reason)}, true, ${
      ago(p.hoursAgo)
    }) on conflict do nothing;`,
  );
}
emit("\ncommit;");

await Deno.writeTextFile(OUT_SQL, sql.join("\n") + "\n");

// --- manifest ---------------------------------------------------------------------------------
const manifest = {
  note: "GENERATED by scripts/generate_seed.ts. Stable ids for A6's demo accounts, plus the scores the TypeScript " +
    "scorer expects (SQL compute_match must agree).",
  companies: COMPANIES.map((c) => ({
    key: c.key,
    id: ids.company[c.key],
    name: c.name,
    verified: c.verified,
  })),
  recruiters: RECRUITERS.map((r) => ({
    key: r.key,
    id: ids.recruiter[r.key],
    company: r.company,
    role: r.role,
  })),
  jobs: jobs.map((j) => ({
    key: j.key,
    id: j.id,
    company: j.company,
    status: j.status,
    title: j.fields.title,
    requirements: j.reqs.length,
  })),
  candidates: candidates.map((c) => ({
    key: c.key,
    id: c.id,
    profile_version_id: c.versionId,
    aimed_at: c.forJob,
    target: c.target,
    skills: c.skills.length,
    scores: Object.fromEntries(
      jobs.map((j) => [j.key, scores.get(`${c.key}|${j.key}`)]),
    ),
  })),
  counts: {
    candidates: candidates.length,
    applications: applications.length,
    swipes: applications.length + passes.length,
    passes: passes.length,
    statuses: Object.fromEntries(
      [...STATUSES, "JOB_CLOSED"].map((s) => [
        s,
        applications.filter((a) => a.status === s).length,
      ]),
    ),
    pass_reasons: Object.fromEntries(
      ["location", "salary", "stack", "seniority", "company"].map((
        r,
      ) => [r, passes.filter((p) => p.reason === r).length]),
    ),
  },
};
await Deno.writeTextFile(
  OUT_MANIFEST,
  JSON.stringify(manifest, null, 2) + "\n",
);

// --- summary -----------------------------------------------------------------------------------
console.log(
  `wrote supabase/seed/demo_data.sql (${sql.length} statements) and demo_manifest.json`,
);
console.log(
  "candidates per band, per job (all 30 candidates scored against every job):",
);
const table: Record<string, Record<Band, number>> = {};
for (const j of jobs) {
  table[`${j.key} (${j.status})`] = { Strong: 0, Good: 0, Stretch: 0, Low: 0 };
  for (const c of candidates) {
    table[`${j.key} (${j.status})`][band(scores.get(`${c.key}|${j.key}`)!)]++;
  }
}
console.table(table);
console.log("counts:", JSON.stringify(manifest.counts));
