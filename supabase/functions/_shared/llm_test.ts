import { assert, assertEquals, assertNotEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.13";
import { EMBED_DIMS, fixtureKey, getProvider, LlmConfigError, MockProvider } from "./llm.ts";
import { EXTRACTION_SCHEMAS, type JobExtraction, validateExtraction } from "./schemas.ts";

const SEED_JOBS = new URL("../../seed/jobs/", import.meta.url);
const env = (vars: Record<string, string>) => (k: string) => vars[k];

const extractJob = (provider: MockProvider, text: string) =>
  provider.extract<JobExtraction>({
    schemaName: "job",
    schema: EXTRACTION_SCHEMAS.job.jsonSchema,
    system: "Extract job requirements.",
    untrustedText: text,
  });

Deno.test("getProvider: mock, case-insensitive", () => {
  assertEquals(getProvider(env({ LLM_PROVIDER: "mock" })).name, "mock");
  assertEquals(getProvider(env({ LLM_PROVIDER: " MOCK " })).name, "mock");
});

Deno.test("getProvider: unset or unknown fails loudly instead of defaulting", () => {
  assertThrows(() => getProvider(env({})), LlmConfigError, "got nothing");
  assertThrows(() => getProvider(env({ LLM_PROVIDER: "claude" })), LlmConfigError, '"claude"');
});

Deno.test("getProvider: real providers are not wired up until B3", () => {
  for (const p of ["gemini", "openai", "azure"]) {
    assertThrows(() => getProvider(env({ LLM_PROVIDER: p })), LlmConfigError, "not implemented");
  }
});

Deno.test("mock extract returns the hash-matched fixture for every seed JD", async () => {
  const mock = new MockProvider();
  const defaultJob = JSON.parse(
    await Deno.readTextFile(new URL("./fixtures/extract/default.job.json", import.meta.url)),
  );
  let count = 0;
  for await (const entry of Deno.readDir(SEED_JOBS)) {
    const text = await Deno.readTextFile(new URL(entry.name, SEED_JOBS));
    const { data, provider, model, usage } = await extractJob(mock, text);
    const job = validateExtraction("job", data);
    assertEquals(provider, "mock");
    assertEquals(model, MockProvider.EXTRACT_MODEL);
    assert(usage.inputTokens > 0 && usage.outputTokens > 0);
    assert(text.includes(job.title!), `${entry.name}: got fixture for "${job.title}"`);
    if (!entry.name.startsWith("job01")) assertNotEquals(job, defaultJob, `${entry.name} fell back to default`);
    count++;
  }
  assertEquals(count, 6);
});

Deno.test("mock extract keys ignore whitespace differences", async () => {
  const text = await Deno.readTextFile(new URL("job04_devops_sre.txt", SEED_JOBS));
  assertEquals(await fixtureKey(text), await fixtureKey(`  ${text.replace(/\n/g, "\n\n\t")}  `));
  const { data } = await extractJob(new MockProvider(), text.replace(/ /g, "   "));
  assertEquals(data.title, "DevOps / Site Reliability Engineer");
});

Deno.test("mock extract falls back to the default fixture per schema", async () => {
  const mock = new MockProvider();
  const resume = await mock.extract({
    schemaName: "resume",
    schema: EXTRACTION_SCHEMAS.resume.jsonSchema,
    system: "Extract skills.",
    untrustedText: "<resume>Some resume nobody has a fixture for.</resume>",
  });
  assert(validateExtraction("resume", resume.data).skills.length > 0);
  const job = await extractJob(mock, "Unknown job text");
  assertEquals(job.data.title, "Mobile Engineer (Flutter)");
});

Deno.test("mock extract errors clearly when fixtures are missing", async () => {
  const empty = new MockProvider(new URL("./no-such-dir/", import.meta.url));
  await assertRejects(() => extractJob(empty, "x"), LlmConfigError, "No mock fixture");
});

Deno.test("mock embed: deterministic 1536-dim unit vectors", async () => {
  const mock = new MockProvider();
  const { vectors, model, usage } = await mock.embed(["React", "react ", "Kubernetes", "React"]);
  assertEquals(model, MockProvider.EMBED_MODEL);
  assertEquals(vectors.length, 4);
  for (const v of vectors) {
    assertEquals(v.length, EMBED_DIMS);
    assert(Math.abs(Math.hypot(...v) - 1) < 1e-9);
  }
  assertEquals(vectors[0], vectors[3]); // same text → same vector
  assertNotEquals(vectors[0], vectors[1]); // case matters (normalization is the caller's job)
  assertNotEquals(vectors[0], vectors[2]);
  assert(usage.inputTokens > 0);

  const again = await new MockProvider().embed(["React"]);
  assertEquals(again.vectors[0], vectors[0]); // stable across instances/runs
});
