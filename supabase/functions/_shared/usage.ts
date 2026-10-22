// Usage log and daily token budget (AI-13, PRD §9.3). Wrap the provider with
// MeteredProvider so every call writes an llm_usage row, and refuse new calls
// once today's (UTC) real-provider tokens reach LLM_DAILY_TOKEN_BUDGET.
//
// The check runs before each call, so a few parses already in flight can
// overshoot the budget slightly. That's acceptable for a soft guard.
import {
  type EmbedResult,
  type ExtractOptions,
  type ExtractResult,
  getProvider,
  LlmConfigError,
  type LlmProvider,
  type ProviderName,
  type TranscribeResult,
} from "./llm.ts";

export const DEFAULT_DAILY_TOKEN_BUDGET = 200_000;

/** One llm_usage row (docs/schema.sql). */
export interface UsageRow {
  function_name: string;
  provider: ProviderName;
  model: string;
  input_tokens: number;
  output_tokens: number;
  latency_ms: number;
  user_id: string | null;
}

export interface UsageStore {
  /** Input + output tokens of non-mock calls since `since`. */
  tokensUsedSince(since: Date): Promise<number>;
  record(row: UsageRow): Promise<void>;
}

/** Thrown before a call when the budget is used up. parse-* maps it to failure_reason "budget_exceeded". */
export class BudgetExceeded extends Error {
  constructor(public used: number, public budget: number) {
    super(`Daily LLM token budget reached (${used} of ${budget} tokens used today)`);
    this.name = "BudgetExceeded";
  }
}

export function startOfUtcDay(now: Date): Date {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
}

export interface MeterOptions {
  functionName: string;
  userId?: string | null;
  budget: number;
  now?: () => Date;
}

export class MeteredProvider implements LlmProvider {
  readonly name: ProviderName;
  private now: () => Date;

  constructor(private inner: LlmProvider, private store: UsageStore, private opts: MeterOptions) {
    this.name = inner.name;
    this.now = opts.now ?? (() => new Date());
  }

  extract<T = unknown>(o: ExtractOptions): Promise<ExtractResult<T>> {
    return this.metered(() => this.inner.extract<T>(o));
  }

  embed(texts: string[]): Promise<EmbedResult> {
    return this.metered(() => this.inner.embed(texts));
  }

  transcribe(pdf: Uint8Array<ArrayBuffer>): Promise<TranscribeResult> {
    return this.metered(() => this.inner.transcribe(pdf));
  }

  private async metered<R extends { usage: { inputTokens: number; outputTokens: number }; model: string }>(
    call: () => Promise<R>,
  ): Promise<R> {
    // Mock calls are free, so they never consume or check the budget.
    if (this.inner.name !== "mock") {
      const used = await this.store.tokensUsedSince(startOfUtcDay(this.now()));
      if (used >= this.opts.budget) throw new BudgetExceeded(used, this.opts.budget);
    }
    const started = performance.now();
    const result = await call();
    await this.store.record({
      function_name: this.opts.functionName,
      provider: this.inner.name,
      model: result.model,
      input_tokens: result.usage.inputTokens,
      output_tokens: result.usage.outputTokens,
      latency_ms: Math.round(performance.now() - started),
      user_id: this.opts.userId ?? null,
    });
    return result;
  }
}

// --- Stores -----------------------------------------------------------------

/** In-memory store for tests and local scripts. */
export class MemoryUsageStore implements UsageStore {
  rows: Array<UsageRow & { created_at: Date }> = [];
  constructor(private now: () => Date = () => new Date()) {}

  tokensUsedSince(since: Date): Promise<number> {
    return Promise.resolve(
      this.rows
        .filter((r) => r.provider !== "mock" && r.created_at >= since)
        .reduce((n, r) => n + r.input_tokens + r.output_tokens, 0),
    );
  }

  record(row: UsageRow): Promise<void> {
    this.rows.push({ ...row, created_at: this.now() });
    return Promise.resolve();
  }
}

/**
 * The slice of a supabase-js client this store needs. Pass the service-role
 * (admin) client: llm_usage has RLS on with no policies (service role only).
 */
export interface UsageDb {
  from(table: "llm_usage"): {
    insert(row: UsageRow): PromiseLike<{ error: { message: string } | null }>;
    select(columns: string): {
      gte(column: string, value: string): {
        neq(column: string, value: string): PromiseLike<{
          data: Array<{ input_tokens: number; output_tokens: number }> | null;
          error: { message: string } | null;
        }>;
      };
    };
  };
}

/** Postgres-backed store. A day is at most a few hundred rows, so summing client-side is fine. */
export class SupabaseUsageStore implements UsageStore {
  constructor(private db: UsageDb) {}

  async tokensUsedSince(since: Date): Promise<number> {
    const { data, error } = await this.db.from("llm_usage")
      .select("input_tokens, output_tokens")
      .gte("created_at", since.toISOString())
      .neq("provider", "mock");
    if (error) throw new Error(`llm_usage read failed: ${error.message}`);
    return (data ?? []).reduce((n, r) => n + r.input_tokens + r.output_tokens, 0);
  }

  async record(row: UsageRow): Promise<void> {
    const { error } = await this.db.from("llm_usage").insert(row);
    // Losing a log row must not fail a parse the user already waited for.
    if (error) console.error(`llm_usage insert failed: ${error.message}`, row);
  }
}

// --- Entry point for Edge Functions -------------------------------------------

type Env = (key: string) => string | undefined;

export function dailyBudget(env: Env): number {
  const raw = env("LLM_DAILY_TOKEN_BUDGET");
  if (raw === undefined || raw === "") return DEFAULT_DAILY_TOKEN_BUDGET;
  const n = Number(raw);
  if (!Number.isFinite(n) || n < 0) throw new LlmConfigError(`LLM_DAILY_TOKEN_BUDGET must be a number (got "${raw}")`);
  return n;
}

/**
 * The provider Edge Functions should use:
 *   const llm = getMeteredProvider({ functionName: "parse-resume", userId, store: new SupabaseUsageStore(admin) });
 */
export function getMeteredProvider(opts: {
  functionName: string;
  userId?: string | null;
  store: UsageStore;
  env?: Env;
}): MeteredProvider {
  const env = opts.env ?? ((k: string) => Deno.env.get(k));
  return new MeteredProvider(getProvider(env), opts.store, {
    functionName: opts.functionName,
    userId: opts.userId,
    budget: dailyBudget(env),
  });
}
