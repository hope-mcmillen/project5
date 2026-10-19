import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1.0.13";
import { LlmConfigError, type LlmProvider, MockProvider } from "./llm.ts";
import {
  BudgetExceeded,
  dailyBudget,
  getMeteredProvider,
  MemoryUsageStore,
  MeteredProvider,
  startOfUtcDay,
  SupabaseUsageStore,
  type UsageDb,
  type UsageRow,
} from "./usage.ts";

const NOW = new Date("2026-10-18T15:00:00Z");

/** A "real" provider stand-in: the mock's behavior under the gemini name. */
function fakeGemini(): LlmProvider {
  const mock = new MockProvider();
  return {
    name: "gemini",
    extract: <T>(o: Parameters<LlmProvider["extract"]>[0]) =>
      mock.extract<T>(o).then((r) => ({ ...r, provider: "gemini" as const, model: "gemini-test" })),
    embed: (t) => mock.embed(t).then((r) => ({ ...r, provider: "gemini", model: "gemini-embedding-001@1536" })),
    transcribe: (p) => mock.transcribe(p).then((r) => ({ ...r, provider: "gemini", model: "gemini-test" })),
  };
}

const row = (over: Partial<UsageRow>): UsageRow => ({
  function_name: "parse-job",
  provider: "gemini",
  model: "gemini-test",
  input_tokens: 0,
  output_tokens: 0,
  latency_ms: 1,
  user_id: null,
  ...over,
});

Deno.test("startOfUtcDay", () => {
  assertEquals(startOfUtcDay(new Date("2026-10-18T23:59:59-05:00")).toISOString(), "2026-10-19T00:00:00.000Z");
  assertEquals(startOfUtcDay(NOW).toISOString(), "2026-10-18T00:00:00.000Z");
});

Deno.test("every call writes one llm_usage row with tokens, model, latency, and user", async () => {
  const store = new MemoryUsageStore(() => NOW);
  const llm = new MeteredProvider(fakeGemini(), store, {
    functionName: "parse-resume",
    userId: "user-1",
    budget: 1e9,
    now: () => NOW,
  });
  await llm.embed(["React", "Kubernetes"]);
  await llm.transcribe(new Uint8Array([1, 2, 3]));
  assertEquals(store.rows.length, 2);
  const [embedRow] = store.rows;
  assertEquals(
    [embedRow.function_name, embedRow.provider, embedRow.model, embedRow.user_id],
    ["parse-resume", "gemini", "gemini-embedding-001@1536", "user-1"],
  );
  assertEquals(embedRow.input_tokens > 0 && embedRow.latency_ms >= 0, true);
});

Deno.test("budget: calls stop at or above today's budget, counting only today and only real providers", async () => {
  const store = new MemoryUsageStore(() => NOW);
  store.rows.push(
    { ...row({ input_tokens: 900, output_tokens: 50 }), created_at: NOW }, // 950 today
    { ...row({ input_tokens: 10_000 }), created_at: new Date("2026-10-17T23:00:00Z") }, // yesterday
    { ...row({ provider: "mock", input_tokens: 10_000 }), created_at: NOW }, // mock is free
  );
  assertEquals(await store.tokensUsedSince(startOfUtcDay(NOW)), 950);

  const under = new MeteredProvider(fakeGemini(), store, { functionName: "parse-job", budget: 951, now: () => NOW });
  await under.embed(["x"]); // 950 < 951: allowed, and now over

  const err = await assertRejects(() => under.embed(["y"]), BudgetExceeded);
  assertEquals(err.budget, 951);
  const atLimit = new MeteredProvider(fakeGemini(), new MemoryUsageStore(), { functionName: "f", budget: 0 });
  await assertRejects(() => atLimit.embed(["z"]), BudgetExceeded);
});

Deno.test("budget: the mock provider is never blocked", async () => {
  const llm = new MeteredProvider(new MockProvider(), new MemoryUsageStore(), { functionName: "seed", budget: 0 });
  assertEquals((await llm.embed(["free"])).vectors.length, 1);
});

Deno.test("a failed call records nothing", async () => {
  const store = new MemoryUsageStore();
  const failing: LlmProvider = { ...fakeGemini(), embed: () => Promise.reject(new Error("boom")) };
  const llm = new MeteredProvider(failing, store, { functionName: "f", budget: 1e9 });
  await assertRejects(() => llm.embed(["a"]), Error, "boom");
  assertEquals(store.rows.length, 0);
});

Deno.test("dailyBudget reads LLM_DAILY_TOKEN_BUDGET", () => {
  assertEquals(dailyBudget(() => undefined), 200_000);
  assertEquals(dailyBudget(() => "5000"), 5000);
  assertThrows(() => dailyBudget(() => "lots"), LlmConfigError);
  assertThrows(() => dailyBudget(() => "-1"), LlmConfigError);
});

Deno.test("getMeteredProvider wraps the configured provider", async () => {
  const store = new MemoryUsageStore();
  const env = (k: string) => ({ LLM_PROVIDER: "mock", LLM_DAILY_TOKEN_BUDGET: "10" } as Record<string, string>)[k];
  const llm = getMeteredProvider({ functionName: "parse-job", store, env });
  assertEquals(llm.name, "mock");
  await llm.embed(["a"]);
  assertEquals(store.rows[0].function_name, "parse-job");
});

Deno.test("SupabaseUsageStore queries today's non-mock rows and never fails a call on insert errors", async () => {
  const seen: Record<string, unknown> = {};
  const db: UsageDb = {
    from: () => ({
      insert: (r) => {
        seen.inserted = r;
        return Promise.resolve({ error: { message: "permission denied" } });
      },
      select: (cols) => ({
        gte: (col, value) => ({
          neq: (col2, value2) => {
            Object.assign(seen, { cols, col, value, col2, value2 });
            return Promise.resolve({
              data: [{ input_tokens: 100, output_tokens: 20 }, { input_tokens: 5, output_tokens: 5 }],
              error: null,
            });
          },
        }),
      }),
    }),
  };
  const store = new SupabaseUsageStore(db);
  assertEquals(await store.tokensUsedSince(startOfUtcDay(NOW)), 130);
  assertEquals([seen.col, seen.value, seen.col2, seen.value2], [
    "created_at",
    "2026-10-18T00:00:00.000Z",
    "provider",
    "mock",
  ]);

  const origError = console.error;
  console.error = () => {};
  try {
    await store.record(row({ input_tokens: 1 })); // logs, doesn't throw
  } finally {
    console.error = origError;
  }
  assertEquals((seen.inserted as UsageRow).input_tokens, 1);
});
