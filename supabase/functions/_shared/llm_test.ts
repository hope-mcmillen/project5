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

Deno.test("getProvider: gemini needs a key and keeps the embedding model pinned", () => {
  assertThrows(() => getProvider(env({ LLM_PROVIDER: "gemini" })), LlmConfigError, "GEMINI_API_KEY");
  const p = getProvider(env({ LLM_PROVIDER: "gemini", GEMINI_API_KEY: "test-key" }));
  assertEquals(p.name, "gemini"); // no network: the SDK loads lazily on first call
  assertThrows(
    () => getProvider(env({ LLM_PROVIDER: "gemini", GEMINI_API_KEY: "k", LLM_EMBED_MODEL: "text-embedding-3-small" })),
    LlmConfigError,
    "must stay gemini-embedding-001",
  );
  const migrating = getProvider(
    env({ LLM_PROVIDER: "gemini", GEMINI_API_KEY: "k", LLM_EMBED_MODEL: "other", ALLOW_EMBED_MODEL_CHANGE: "true" }),
  );
  assertEquals(migrating.name, "gemini");
});

Deno.test("getProvider: OpenAI/Azure were dropped in PRD v0.5", () => {
  for (const p of ["openai", "azure"]) {
    assertThrows(() => getProvider(env({ LLM_PROVIDER: p })), LlmConfigError, "must be one of mock, gemini");
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
  await assertRejects(() => empty.transcribe(new Uint8Array([1])), LlmConfigError, "No mock transcription");
});

Deno.test("mock transcribe returns the scanned fixture's text, else a default", async () => {
  const mock = new MockProvider();
  const scan = await Deno.readFile(new URL("../../seed/resumes/r08_scanned_image.pdf", import.meta.url));
  const { text, model, provider } = await mock.transcribe(scan);
  assertEquals([provider, model], ["mock", MockProvider.TRANSCRIBE_MODEL]);
  assert(text.startsWith("Casey Broussard"), "scan fixture should map to its own transcription");
  for (const skill of ["Java", "Spring Boot", "MySQL"]) assert(text.includes(skill), skill);

  const other = await mock.transcribe(new TextEncoder().encode("%PDF-1.4 unknown"));
  assert(other.text.startsWith("Sample Candidate"));
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
