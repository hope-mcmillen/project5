// LLM provider adapter (AI-03, PRD §9.3). Every LLM call in the Edge
// Functions goes through getProvider(), so switching providers is one setting
// (LLM_PROVIDER) and tests/CI/seeding run on the free mock.
//
// The real provider is Google Gemini (PRD v0.5, gemini.ts). Edge Functions
// should use getMeteredProvider() from usage.ts, which adds the llm_usage log
// and the daily token budget (AI-13) on top of this.
import { GeminiProvider } from "./gemini.ts";
import {
  EMBED_DIMS,
  type EmbedResult,
  estimateTokens,
  type ExtractOptions,
  type ExtractResult,
  fixtureKey,
  LlmConfigError,
  type LlmProvider,
  normalizeForKey,
  PROVIDER_NAMES,
  sha256Hex,
  type TranscribeResult,
} from "./llm_base.ts";
import { EXTRACTION_SCHEMAS } from "./schemas.ts";

export * from "./llm_base.ts";

type Env = (key: string) => string | undefined;

/**
 * Picks the provider from LLM_PROVIDER. There is deliberately no default:
 * an unset value in production must fail loudly, not silently return mock data.
 * Local `supabase/functions/.env` sets LLM_PROVIDER=mock.
 */
export function getProvider(env: Env = (k) => Deno.env.get(k)): LlmProvider {
  const name = env("LLM_PROVIDER")?.trim().toLowerCase();
  switch (name) {
    case "mock":
      return new MockProvider();
    case "gemini":
      return new GeminiProvider({
        apiKey: env("GEMINI_API_KEY") ?? "",
        extractModel: env("LLM_EXTRACT_MODEL"),
        embedModel: env("LLM_EMBED_MODEL"),
        allowEmbedModelChange: env("ALLOW_EMBED_MODEL_CHANGE") === "true",
      });
    default:
      throw new LlmConfigError(
        `LLM_PROVIDER must be one of ${PROVIDER_NAMES.join(", ")} (got ${
          name === undefined ? "nothing" : `"${name}"`
        }).`,
      );
  }
}

// ---------------------------------------------------------------------------
// Mock provider (US-52): free, deterministic, offline.
// ---------------------------------------------------------------------------

const FIXTURE_ROOT = new URL("./fixtures/", import.meta.url);

export class MockProvider implements LlmProvider {
  readonly name = "mock" as const;
  static readonly EXTRACT_MODEL = "mock-extract";
  static readonly EMBED_MODEL = "mock-embed";
  static readonly TRANSCRIBE_MODEL = "mock-transcribe";

  constructor(private fixtureRoot: URL = FIXTURE_ROOT) {}

  /**
   * Returns fixtures/extract/<sha256(normalized text)>.json if present,
   * otherwise fixtures/extract/default.<schemaName>.json.
   */
  async extract<T = unknown>(opts: ExtractOptions): Promise<ExtractResult<T>> {
    if (!(opts.schemaName in EXTRACTION_SCHEMAS)) {
      throw new LlmConfigError(`Unknown schemaName "${opts.schemaName}"`);
    }
    const key = await fixtureKey(opts.untrustedText);
    const raw = (await this.read(`extract/${key}.json`)) ??
      (await this.read(`extract/default.${opts.schemaName}.json`));
    if (raw === null) throw new LlmConfigError(`No mock fixture for ${opts.schemaName} (key ${key})`);
    return {
      data: JSON.parse(raw) as T,
      usage: { inputTokens: estimateTokens(opts.system + opts.untrustedText), outputTokens: estimateTokens(raw) },
      provider: this.name,
      model: MockProvider.EXTRACT_MODEL,
    };
  }

  /**
   * Deterministic unit vectors seeded from sha256(text). Identical text gives
   * identical vectors, so similarity code runs, but the numbers carry no
   * meaning. They're tagged "mock-embed" and must never be stored next to
   * real embeddings.
   */
  async embed(texts: string[]): Promise<EmbedResult> {
    const vectors = await Promise.all(texts.map(mockVector));
    return {
      vectors,
      usage: { inputTokens: texts.reduce((n, t) => n + estimateTokens(t), 0), outputTokens: 0 },
      provider: this.name,
      model: MockProvider.EMBED_MODEL,
    };
  }

  /**
   * Returns fixtures/transcribe/<sha256(file bytes)>.txt if present (written
   * by scripts/make_fake_resumes.py for the scanned fixture), otherwise
   * fixtures/transcribe/default.txt.
   */
  async transcribe(pdf: Uint8Array<ArrayBuffer>): Promise<TranscribeResult> {
    const key = await sha256Hex(pdf);
    const text = (await this.read(`transcribe/${key}.txt`)) ?? (await this.read("transcribe/default.txt"));
    if (text === null) throw new LlmConfigError(`No mock transcription (key ${key})`);
    return {
      text,
      usage: { inputTokens: 258, outputTokens: estimateTokens(text) }, // Gemini bills ~258 tokens per PDF page
      provider: this.name,
      model: MockProvider.TRANSCRIBE_MODEL,
    };
  }

  private async read(path: string): Promise<string | null> {
    try {
      return await Deno.readTextFile(new URL(path, this.fixtureRoot));
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null;
      throw e;
    }
  }
}

async function mockVector(text: string): Promise<number[]> {
  const hash = await sha256Hex(normalizeForKey(text));
  // xorshift128, seeded with the first 16 bytes of the hash.
  let [a, b, c, d] = [0, 8, 16, 24].map((i) => parseInt(hash.slice(i, i + 8), 16) | 0);
  if ((a | b | c | d) === 0) a = 1;
  const next = () => {
    const t = a ^ (a << 11);
    [a, b, c] = [b, c, d];
    d = (d ^ (d >>> 19)) ^ (t ^ (t >>> 8));
    return (d >>> 0) / 0x100000000; // [0, 1)
  };
  const v = Array.from({ length: EMBED_DIMS }, () => next() * 2 - 1);
  const norm = Math.hypot(...v);
  return v.map((x) => x / norm);
}
