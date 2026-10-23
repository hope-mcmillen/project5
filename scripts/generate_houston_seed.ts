// Houston demo jobs generator. From supabase/functions:
//   deno task generate:houston
//
// Writes supabase/seed/houston_jobs.sql (18 fictional companies, 80 OPEN jobs, mostly in
// Greater Houston) and supabase/seed/houston_manifest.json, from scripts/houston_jobs_data.ts.
// Unlike demo_data.sql this file is meant for the linked remote project too: it adds no
// users, candidates, or applications, only companies, jobs, and requirements, so a real
// candidate who signs in has a full deck to swipe.
//
// Deterministic, no AI: every requirement must name a skill in skills.csv (checked here and
// again at load time), job vectors come from skills_centroid() in SQL, and ids are fixed
// (prefix 484f5553 = "HOUS") so the file is safe to re-run and easy to find or remove.
import {
  band,
  computeMatch,
  type JobRequirement,
  relationKey,
} from "../supabase/functions/_shared/score.ts";
import {
  loadSeedRelations,
  loadSeedSkills,
} from "../supabase/functions/_shared/seed_taxonomy.ts";
import { COMPANIES, JOBS } from "./houston_jobs_data.ts";

const SEED = new URL("../supabase/seed/", import.meta.url);
const OUT_SQL = new URL("houston_jobs.sql", SEED);
const OUT_MANIFEST = new URL("houston_manifest.json", SEED);
const EMBEDDING_MODEL = "gemini-embedding-001@1536";
const ID_PREFIX = "484f5553";

const companyId = (i: number) =>
  `${ID_PREFIX}-0000-4000-8000-${String(i + 1).padStart(12, "0")}`;
const jobId = (i: number) =>
  `${ID_PREFIX}-0001-4000-8000-${String(i + 1).padStart(12, "0")}`;
const q = (
  s: string | null,
) => (s === null ? "null" : `'${s.replaceAll("'", "''")}'`);
const money = (n: number) => `$${n.toLocaleString("en-US")}`;
/** Days since publishing, spread over the last two weeks so freshness varies but stays high. */
const daysAgo = (i: number) => (i * 7) % 15;

// --- parse and validate ----------------------------------------------------------------------

const skills = await loadSeedSkills();
const category = new Map(skills.map((s) => [s.name, s.category]));
const relations = new Map(
  (await loadSeedRelations()).map((
    r,
  ) => [relationKey(r.skill, r.related), r.credit]),
);

interface Req extends JobRequirement {
  evidence: string;
}

function parseReq(spec: string, job: string): Req {
  const m = /^(~)?(.+?)(?: (\d+(?:\.\d)?)y)?( !)?$/.exec(spec);
  if (!m) throw new Error(`${job}: bad requirement "${spec}"`);
  const [, pref, name, years, core] = m;
  if (!category.has(name)) {
    throw new Error(`${job}: "${name}" is not in skills.csv`);
  }
  const required = !pref;
  if (!required && core) {
    throw new Error(`${job}: preferred "${name}" can't be core`);
  }
  const min = years ? Number(years) : 0;
  const evidence = !required
    ? `Nice to have: ${name}`
    : min > 0
    ? `${min}+ year${min === 1 ? "" : "s"} of experience with ${name}`
    : `Working knowledge of ${name}`;
  return {
    skill_id: name,
    name,
    category: category.get(name)!,
    required,
    min_years: min,
    weight: required ? (core ? 3 : 2) : 1,
    evidence,
  };
}

const companyIndex = new Map(COMPANIES.map((c, i) => [c.key, i]));
const jobs = JOBS.map((j, i) => {
  const label = `${j.company}/${j.title}`;
  if (!companyIndex.has(j.company)) {
    throw new Error(`${label}: unknown company`);
  }
  if (!!j.salary === !!j.hourly) {
    throw new Error(`${label}: give exactly one of salary or hourly`);
  }
  const reqs = j.reqs.map((r) => parseReq(r, label));
  const required = reqs.filter((r) => r.required).length;
  // R-JOB-2 caps (15 total, 8 required) plus the demo's own 3–10 range.
  if (reqs.length < 3 || reqs.length > 10 || required < 1 || required > 8) {
    throw new Error(
      `${label}: ${reqs.length} requirements (${required} required)`,
    );
  }
  if (new Set(reqs.map((r) => r.name)).size !== reqs.length) {
    throw new Error(`${label}: duplicate skill`);
  }
  const [lo, hi] = j.salary ??
    [
      Math.round(j.hourly![0] * j.hourly![2] * 52),
      Math.round(j.hourly![1] * j.hourly![2] * 52),
    ];
  if (lo > hi) throw new Error(`${label}: salary min > max`);
  return {
    ...j,
    i,
    id: jobId(i),
    reqs,
    salaryMin: lo,
    salaryMax: hi,
    days: daysAgo(i),
  };
});
const seenTitles = new Set<string>();
for (const j of jobs) {
  const k = `${j.company}|${j.title}`;
  if (seenTitles.has(k)) throw new Error(`duplicate job ${k}`);
  seenTitles.add(k);
}

// --- descriptions ----------------------------------------------------------------------------------

const REMOTE_LABEL = {
  onsite: "On-site",
  hybrid: "Hybrid (three days a week in the office)",
  remote: "Remote (within Texas)",
};
const TYPE_LABEL = {
  full_time: "Full-time",
  part_time: "Part-time",
  contract: "Contract",
  internship: "Internship",
};

function description(j: (typeof jobs)[number]): string {
  const c = COMPANIES[companyIndex.get(j.company)!];
  const pay = j.salary
    ? `Salary: ${money(j.salary[0])} to ${
      money(j.salary[1])
    } a year, plus medical, dental, and a 401(k) match.`
    : `Pay: ${money(j.hourly![0])} to ${money(j.hourly![1])} an hour, about ${
      j.hourly![2]
    } hours a week.`;
  const required = j.reqs.filter((r) => r.required).map((r) =>
    `- ${r.evidence}`
  );
  const preferred = j.reqs.filter((r) => !r.required).map((r) => `- ${r.name}`);
  return [
    j.title,
    `${c.name} · ${j.location} · ${REMOTE_LABEL[j.remote]} · ${
      TYPE_LABEL[j.type]
    }`,
    "",
    "About us",
    c.blurb,
    "",
    "About the role",
    j.summary,
    "",
    "What you'll do",
    ...j.duties.map((d) => `- ${d}`),
    "",
    "What you'll bring",
    ...required,
    ...(preferred.length ? ["", "Nice to have", ...preferred] : []),
    "",
    pay,
    ...(j.sponsorship ? ["Visa sponsorship is available for this role."] : []),
  ].join("\n");
}

// --- SQL ------------------------------------------------------------------------------------------

const allSkills = [...new Set(jobs.flatMap((j) => j.reqs.map((r) => r.name)))]
  .sort();
const sql: string[] = [];
const emit = (s: string) => sql.push(s);

emit(
  `-- Houston demo jobs: ${COMPANIES.length} fictional companies and ${jobs.length} OPEN jobs, mostly in Greater Houston.
-- GENERATED by scripts/generate_houston_seed.ts from scripts/houston_jobs_data.ts. Do not edit by hand.
-- Needs the taxonomy with vectors (skills.sql + skills_embeddings.sql) and the skills_centroid migration.
-- Safe to re-run: upserts by fixed id (prefix ${ID_PREFIX}), so a re-run also refreshes published_at and
-- expires_at (published + 60 days, R-JOB-4). No users, candidates, swipes, or applications are touched.
-- Every company and job has is_seed = true; companies have no recruiters (seed jobs are read-only demo data).
begin;

-- Fail early, before writing anything, if the taxonomy isn't loaded.
do $$
declare missing text;
begin
  select string_agg(n, ', ' order by n) into missing
  from unnest(array[${allSkills.map(q).join(", ")}]) n
  where not exists (select 1 from public.skills s where s.name = n and s.embedding is not null
                    and s.embedding_model = '${EMBEDDING_MODEL}');
  if missing is not null then
    raise exception 'houston_jobs.sql: load supabase/seed/skills.sql and skills_embeddings.sql first; missing or unembedded skills: %', missing;
  end if;
end $$;
`,
);

emit(
  "-- Companies ------------------------------------------------------------------------------------",
);
emit(`insert into public.companies (id, name, website, verified, is_seed) values
${
  COMPANIES.map((c, i) =>
    `  (${q(companyId(i))}, ${q(c.name)}, ${q(c.website)}, ${c.verified}, true)`
  ).join(",\n")
}
on conflict (id) do update set name = excluded.name, website = excluded.website, verified = excluded.verified,
  is_seed = true;
`);

emit(
  "-- Jobs -----------------------------------------------------------------------------------------",
);
emit(
  `insert into public.jobs (id, company_id, title, raw_description, parse_status, status, location, remote, job_type,
  sponsorship, salary_min, salary_max, published_at, expires_at, is_seed) values
${
    jobs.map((j) =>
      `  (${q(j.id)}, ${q(companyId(companyIndex.get(j.company)!))}, ${
        q(j.title)
      },
   ${q(description(j))},
   'READY', 'OPEN', ${q(j.location)}, '${j.remote}', '${j.type}', ${!!j
        .sponsorship}, ${j.salaryMin}, ${j.salaryMax},
   date_trunc('day', now()) - interval '${j.days} days', date_trunc('day', now()) - interval '${j.days} days' + interval '60 days', true)`
    ).join(",\n")
  }
on conflict (id) do update set company_id = excluded.company_id, title = excluded.title,
  raw_description = excluded.raw_description, parse_status = 'READY', status = 'OPEN', location = excluded.location,
  remote = excluded.remote, job_type = excluded.job_type, sponsorship = excluded.sponsorship,
  salary_min = excluded.salary_min, salary_max = excluded.salary_max, published_at = excluded.published_at,
  expires_at = excluded.expires_at, is_seed = true;
`,
);

emit(
  "-- Requirements (replaced on every run, so edits to the data file take effect) --------------------",
);
emit(
  `delete from public.job_requirements where job_id in (select id from public.jobs where id::text like '${ID_PREFIX}-0001-%');
insert into public.job_requirements (job_id, skill_id, required, min_years, weight, evidence)
select v.job_id::uuid, s.id, v.required, v.min_years, v.weight, v.evidence
from (values
${
    jobs.flatMap((j) =>
      j.reqs.map((r) =>
        `  (${q(j.id)}, ${
          q(r.name)
        }, ${r.required}, ${r.min_years}, ${r.weight}, ${q(r.evidence)})`
      )
    ).join(",\n")
  }
) v (job_id, skill, required, min_years, weight, evidence)
join public.skills s on s.name = v.skill;
`,
);

emit(
  "-- Job vectors: centroid of the requirement skills, like save_requirements() -----------------------",
);
emit(`update public.jobs j set embedding = public.skills_centroid(array(
    select jr.skill_id from public.job_requirements jr where jr.job_id = j.id)),
  embedding_model = '${EMBEDDING_MODEL}'
where j.id::text like '${ID_PREFIX}-0001-%';
`);

emit(`-- Roll everything back if any job came out incomplete.
do $$
declare bad text;
begin
  select string_agg(j.title, ', ') into bad
  from public.jobs j
  where j.id::text like '${ID_PREFIX}-0001-%'
    and (j.embedding is null or (select count(*) from public.job_requirements jr where jr.job_id = j.id) not between 3 and 10);
  if bad is not null then raise exception 'houston_jobs.sql: incomplete jobs: %', bad; end if;
  if (select count(*) from public.jobs where id::text like '${ID_PREFIX}-0001-%') <> ${jobs.length} then
    raise exception 'houston_jobs.sql: expected ${jobs.length} jobs';
  end if;
end $$;

commit;

-- Summary (expect ${COMPANIES.length} companies, ${jobs.length} open jobs, ${
  jobs.reduce((n, j) => n + j.reqs.length, 0)
} requirements, ${jobs.length} vectors).
select
  (select count(*) from public.companies where id::text like '${ID_PREFIX}-0000-%') as companies,
  (select count(*) from public.jobs where id::text like '${ID_PREFIX}-0001-%' and status = 'OPEN' and expires_at > now()) as open_jobs,
  (select count(*) from public.job_requirements where job_id::text like '${ID_PREFIX}-0001-%') as requirements,
  (select count(*) from public.jobs where id::text like '${ID_PREFIX}-0001-%' and embedding is not null) as vectors;`);

await Deno.writeTextFile(OUT_SQL, sql.join("\n") + "\n");

// --- feed check: sample candidates ------------------------------------------------------------------
// get_feed hides cards under 50 (unless include_stretch), so check that typical profiles get a
// deck. "student" mirrors the pgTAP feed test in supabase/tests/houston_jobs.test.sql.

const SAMPLE_PROFILES: Record<string, Record<string, number>> = {
  student: {
    Python: 2,
    Java: 2,
    "C++": 1,
    SQL: 1,
    Git: 2,
    JavaScript: 1,
    HTML: 1,
    CSS: 1,
    Flutter: 1,
    Dart: 1,
    "Data Structures": 2,
    Algorithms: 2,
    "Object-Oriented Programming": 2,
    Linux: 1,
  },
  analyst: {
    SQL: 2,
    "Microsoft Excel": 3,
    "Power BI": 1,
    "Data Analysis": 2,
    Python: 1,
    Statistics: 1,
  },
  frontend: {
    JavaScript: 3,
    TypeScript: 2,
    React: 3,
    HTML: 3,
    CSS: 3,
    "Node.js": 1,
    Git: 3,
  },
  data: {
    Python: 4,
    SQL: 4,
    "Machine Learning": 2,
    Pandas: 3,
    Statistics: 2,
    "Apache Spark": 1,
    AWS: 1,
  },
};
for (const p of Object.values(SAMPLE_PROFILES)) {
  for (const name of Object.keys(p)) {
    if (!category.has(name)) {
      throw new Error(`sample skill ${name} not in taxonomy`);
    }
  }
}
const scoreFor = (profile: Record<string, number>, j: (typeof jobs)[number]) =>
  computeMatch(
    Object.entries(profile).map(([skill_id, years]) => ({ skill_id, years })),
    j.reqs,
    relations,
  ).score;

const count = <K extends string>(xs: K[]) =>
  Object.fromEntries(
    [...new Set(xs)].sort().map((k) => [k, xs.filter((x) => x === k).length]),
  );

const manifest = {
  note:
    "GENERATED by scripts/generate_houston_seed.ts. Fixed ids for the Houston demo companies and jobs, plus the " +
    "TypeScript scorer's match score for sample profiles (get_feed shows scores of 50 and up by default).",
  id_prefix: ID_PREFIX,
  companies: COMPANIES.map((c, i) => ({
    key: c.key,
    id: companyId(i),
    name: c.name,
    hq: c.hq,
    industry: c.industry,
    verified: c.verified,
    jobs: jobs.filter((j) => j.company === c.key).length,
  })),
  jobs: jobs.map((j) => ({
    id: j.id,
    company: j.company,
    title: j.title,
    location: j.location,
    remote: j.remote,
    job_type: j.type,
    salary_min: j.salaryMin,
    salary_max: j.salaryMax,
    published_days_ago: j.days,
    requirements: j.reqs.length,
    required: j.reqs.filter((r) => r.required).length,
    sample_scores: Object.fromEntries(
      Object.entries(SAMPLE_PROFILES).map(([k, p]) => [k, scoreFor(p, j)]),
    ),
  })),
  counts: {
    companies: COMPANIES.length,
    jobs: jobs.length,
    requirements: jobs.reduce((n, j) => n + j.reqs.length, 0),
    by_job_type: count(jobs.map((j) => j.type)),
    by_remote: count(jobs.map((j) => j.remote)),
    by_location: count(jobs.map((j) => j.location)),
    feed_cards_at_50_plus: Object.fromEntries(
      Object.entries(SAMPLE_PROFILES).map((
        [k, p],
      ) => [k, jobs.filter((j) => scoreFor(p, j) >= 50).length]),
    ),
  },
};
await Deno.writeTextFile(
  OUT_MANIFEST,
  JSON.stringify(manifest, null, 2) + "\n",
);

console.log(
  `wrote supabase/seed/houston_jobs.sql and houston_manifest.json (${COMPANIES.length} companies, ${jobs.length} jobs)`,
);
console.log(JSON.stringify(manifest.counts, null, 2));
const bands = (p: Record<string, number>) =>
  count(jobs.map((j) => band(scoreFor(p, j))));
for (const [k, p] of Object.entries(SAMPLE_PROFILES)) {
  console.log(k, JSON.stringify(bands(p)));
}
