// Opt-in contract test against the real Gemini API (uses quota; on the free
// tier Google may use the inputs, which are synthetic fixtures). Skipped
// unless LLM_PROVIDER=gemini. Run with:  deno task test:live (forces gemini)
// About eight calls total: job extraction, embeddings, transcription, and two full resume parses.
import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { EMBED_DIMS, getProvider } from "./llm.ts";
import { MATCH_THRESHOLD, normalizeSkills } from "./normalize.ts";
import { parseJob } from "./job_pipeline.ts";
import { MemoryJobRepo } from "./job_repo.ts";
import { parseResume } from "./resume_pipeline.ts";
import { MemoryResumeRepo } from "./resume_repo_memory.ts";
import { seedSkillIndex } from "./seed_taxonomy.ts";
import { JOB_SYSTEM_PROMPT, wrapUntrusted } from "./prompts.ts";
import { EXTRACTION_SCHEMAS, validateExtraction } from "./schemas.ts";

const live = Deno.env.get("LLM_PROVIDER") === "gemini";
const seed = (path: string) => new URL(`../../seed/${path}`, import.meta.url);
const norm = (s: string) => s.replace(/\s+/g, " ").trim().toLowerCase();
const cos = (a: number[], b: number[]) => a.reduce((n, x, i) => n + x * b[i], 0); // vectors are unit length

Deno.test({ name: "live: Gemini accepts the job schema and quotes evidence verbatim", ignore: !live }, async () => {
  const jd = await Deno.readTextFile(seed("jobs/job01_flutter_mobile.txt"));
  const res = await getProvider().extract({
    schemaName: "job",
    schema: EXTRACTION_SCHEMAS.job.jsonSchema,
    system: JOB_SYSTEM_PROMPT,
    untrustedText: wrapUntrusted("job", jd),
  });
  const job = validateExtraction("job", res.data);
  const verbatim = job.requirements.filter((r) => norm(jd).includes(norm(r.evidence)));
  console.log(
    `model=${res.model} tokens=${res.usage.inputTokens}+${res.usage.outputTokens} ` +
      `requirements=${job.requirements.length} verbatim=${verbatim.length}`,
  );
  console.table(job.requirements.map((r) => ({ raw: r.raw, hint: r.required_hint, min_years: r.min_years })));
  assertEquals(job.salary_min, 95000);
  assert(job.requirements.some((r) => /flutter/i.test(r.raw) && r.required_hint === "required"));
  assert(verbatim.length >= job.requirements.length * 0.8, "most evidence should be verbatim quotes");
  // One skill per entry (schema v2): "Flutter and Dart" must come back as two requirements.
  const raws = job.requirements.map((r) => r.raw.toLowerCase());
  assert(raws.includes("flutter") && raws.includes("dart"), `expected separate Flutter and Dart, got ${raws}`);
  const grouped = job.requirements.filter((r) => /\band\b|\bor\b|[(,]/i.test(r.raw));
  assert(grouped.length === 0, `grouped skills: ${grouped.map((r) => r.raw).join(" | ")}`);
});

Deno.test(
  { name: "live: embeddings are 1536-dim and put aliases closer than unrelated skills", ignore: !live },
  async () => {
    const { vectors, model } = await getProvider().embed(["React", "ReactJS", "Kubernetes", "k8s"]);
    const [react, reactjs, kube, k8s] = vectors;
    assertEquals([model, react.length], ["gemini-embedding-001@1536", EMBED_DIMS]);
    const sims = {
      "React~ReactJS": cos(react, reactjs),
      "Kubernetes~k8s": cos(kube, k8s),
      "React~Kubernetes": cos(react, kube),
    };
    console.table(sims); // useful for sanity-checking the 0.89 match_skills threshold (B5)
    assert(sims["React~ReactJS"] > sims["React~Kubernetes"]);
    assert(sims["Kubernetes~k8s"] > sims["React~Kubernetes"]);
  },
);

Deno.test({ name: "live: transcribe reads the scanned resume", ignore: !live }, async () => {
  const pdf = await Deno.readFile(seed("resumes/r08_scanned_image.pdf"));
  const { text, usage } = await getProvider().transcribe(pdf);
  console.log(`transcribed ${text.length} chars, tokens=${usage.inputTokens}+${usage.outputTokens}`);
  for (const s of ["Java", "Spring Boot", "MySQL"]) assert(text.includes(s), `missing ${s}`);
});

Deno.test({ name: "live: labeled alias pairs normalize at the tuned threshold", ignore: !live }, async () => {
  const pairs: Array<{ query: string; expect: string | null }> = JSON.parse(
    await Deno.readTextFile(new URL("../../tests/fixtures/alias_pairs.json", import.meta.url)),
  ).pairs;
  const res = await normalizeSkills(pairs.map((p) => p.query), getProvider(), await seedSkillIndex());
  const right = res.filter((r, i) => r.name === pairs[i].expect).length;
  const falseMaps = res.filter((r, i) => pairs[i].expect === null && r.name !== null).map((r) => `${r.raw}→${r.name}`);
  console.log(
    `threshold ${MATCH_THRESHOLD}: ${right}/${pairs.length} correct; false maps: ${falseMaps.join(", ") || "none"}`,
  );
  assert(right / pairs.length >= 0.9, "accuracy dropped below 90%: re-run deno task tune:threshold");
  assert(falseMaps.length <= 1);
});

Deno.test(
  { name: "live AI-19: injection resumes parse with real Gemini and leak nothing", ignore: !live },
  async () => {
    const labels = JSON.parse(await Deno.readTextFile(new URL("fixtures/labels.json", seed("")))).resumes;
    const index = await seedSkillIndex();
    for (const file of ["r09_hidden_white_text.pdf", "r10_visible_injection_age.pdf"]) {
      const repo = new MemoryResumeRepo();
      const user = crypto.randomUUID();
      const id = crypto.randomUUID();
      repo.add({ id, candidate_id: user }, await Deno.readFile(seed(`resumes/${file}`)));
      const res = await parseResume({ repo, llm: getProvider(), index, log: () => {} }, { resumeId: id, userId: user });
      assertEquals(res.status, "READY", file);
      const names = repo.versions[0].skills.map((s) => s.skill_id).filter(Boolean) as string[];
      const leaked = (labels[file].forbidden_skills as string[]).filter((s) => names.includes(s));
      console.log(`${file}: ${names.join(", ")} | forbidden leaked: ${leaked.join(", ") || "none"}`);
      assertEquals(leaked, [], file);
      const saved = JSON.stringify({ e: repo.resumes.get(id)!.extraction, v: repo.versions });
      for (const pii of ["@example.com", "555-01", "Age", "1974", "Married", "Hebert", "Landry"]) {
        assert(!saved.includes(pii), `${file} saved ${pii}`);
      }
    }
  },
);

Deno.test({ name: "live: parse-job on real Gemini respects caps and groups alternatives", ignore: !live }, async () => {
  const index = await seedSkillIndex();
  for (const file of ["job01_flutter_mobile.txt", "job05_frontend_react.txt"]) {
    const repo = new MemoryJobRepo();
    repo.recruiters.set("rec", "co");
    const id = crypto.randomUUID();
    repo.add({ id, company_id: "co", raw_description: await Deno.readTextFile(seed(`jobs/${file}`)) });
    const res = await parseJob({ repo, llm: getProvider(), index, log: () => {} }, { jobId: id, userId: "rec" });
    if (res.parse_status !== "READY") throw new Error(`${file}: ${JSON.stringify(res)}`);
    const req = res.requirements.filter((r) => r.required).map((r) => r.name);
    const alt = res.requirements.filter((r) => r.either_of_group).map((r) => `${r.name}#${r.either_of_group}`);
    console.log(
      `${file}: required [${req.join(", ")}] | alternatives [${alt.join(", ")}] | ` +
        `${res.requirements.length} kept, trimmed [${res.trimmed.map((r) => r.name).join(", ")}], ` +
        `unmapped [${res.unmapped.map((u) => u.raw).join(", ")}]`,
    );
    assert(res.requirements.length <= 15 && req.length <= 8);
  }
});
