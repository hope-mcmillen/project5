// Opt-in contract test against the real Gemini API (uses quota; on the free
// tier Google may use the inputs, which are synthetic fixtures). Skipped
// unless LLM_PROVIDER=gemini. Run with:  deno task test:live (forces gemini)
// Three calls total: one job extraction, one embedding batch, one transcription.
import { assert, assertEquals } from "jsr:@std/assert@1.0.13";
import { EMBED_DIMS, getProvider } from "./llm.ts";
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
    console.table(sims); // useful for tuning the 0.88 match_skills threshold (B5)
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
