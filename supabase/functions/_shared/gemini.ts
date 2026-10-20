// Google Gemini provider (AI-09, PRD v0.5 §9.3). Uses the official SDK with an
// AI Studio key. The SDK is loaded lazily so mock-only runs never import it.
import { encodeBase64 } from "jsr:@std/encoding@1.0.10/base64";
import {
  EMBED_DIMS,
  type EmbedResult,
  estimateTokens,
  type ExtractOptions,
  type ExtractResult,
  LlmConfigError,
  type LlmProvider,
  type TranscribeResult,
  type Usage,
} from "./llm_base.ts";
import { TRANSCRIBE_PROMPT } from "./prompts.ts";

const SDK = "npm:@google/genai@2.27.0";

/** The only embedding model whose vectors may be stored (PRD §9.3). */
export const PINNED_EMBED_MODEL = "gemini-embedding-001";
/** Every embed call uses this task type; changing it means a full re-embed. */
export const EMBED_TASK_TYPE = "SEMANTIC_SIMILARITY";
/** Value for the `embedding_model` columns: model + dimensions. */
export const EMBEDDING_MODEL_TAG = `${PINNED_EMBED_MODEL}@${EMBED_DIMS}`;
export const DEFAULT_EXTRACT_MODEL = "gemini-3.8-flash";
const EMBED_BATCH = 100; // Gemini's per-request limit for batched embeddings

/** Why a Gemini call failed. parse-* maps all of these to failure_reason "internal". */
export type LlmCallErrorKind = "rate_limited" | "upstream" | "blocked" | "bad_output";

export class LlmCallError extends Error {
  constructor(public kind: LlmCallErrorKind, message: string, public status?: number) {
    super(message);
    this.name = "LlmCallError";
  }
}

// --- The slice of the SDK we use, so tests can pass a fake client. ----------

interface GenerateResponse {
  text?: string;
  usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number; thoughtsTokenCount?: number };
  promptFeedback?: { blockReason?: string };
  candidates?: Array<{ finishReason?: string }>;
}

export interface GeminiClient {
  models: {
    generateContent(params: {
      model: string;
      contents: unknown;
      config?: Record<string, unknown>;
    }): Promise<GenerateResponse>;
    embedContent(params: {
      model: string;
      contents: string[];
      config?: Record<string, unknown>;
    }): Promise<{ embeddings?: Array<{ values?: number[] }> }>;
  };
}

export interface GeminiOptions {
  apiKey: string;
  extractModel?: string;
  embedModel?: string;
  allowEmbedModelChange?: boolean;
  /** Retries after the first attempt for 429/5xx. */
  maxRetries?: number;
  sleep?: (ms: number) => Promise<void>;
  /** Injected in tests. Defaults to the real SDK client. */
  client?: GeminiClient;
}

export class GeminiProvider implements LlmProvider {
  readonly name = "gemini" as const;
  readonly extractModel: string;
  readonly embedModel: string;
  private clientPromise?: Promise<GeminiClient>;
  private maxRetries: number;
  private sleep: (ms: number) => Promise<void>;

  constructor(private opts: GeminiOptions) {
    if (!opts.apiKey) throw new LlmConfigError("GEMINI_API_KEY is not set.");
    this.extractModel = opts.extractModel || DEFAULT_EXTRACT_MODEL;
    this.embedModel = opts.embedModel || PINNED_EMBED_MODEL;
    if (this.embedModel !== PINNED_EMBED_MODEL && !opts.allowEmbedModelChange) {
      throw new LlmConfigError(
        `LLM_EMBED_MODEL must stay ${PINNED_EMBED_MODEL} (got ${this.embedModel}). Changing it means re-embedding ` +
          "every skill, profile, and job (PRD §9.3); set ALLOW_EMBED_MODEL_CHANGE=true only for that migration.",
      );
    }
    this.maxRetries = opts.maxRetries ?? 3;
    this.sleep = opts.sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
    if (opts.client) this.clientPromise = Promise.resolve(opts.client);
  }

  async extract<T = unknown>(opts: ExtractOptions): Promise<ExtractResult<T>> {
    const res = await this.call((c) =>
      c.models.generateContent({
        model: this.extractModel,
        contents: opts.untrustedText,
        config: {
          systemInstruction: opts.system,
          temperature: 0,
          responseMimeType: "application/json",
          responseJsonSchema: opts.schema,
        },
      })
    );
    const text = this.checkedText(res);
    let data: T;
    try {
      data = JSON.parse(text) as T;
    } catch {
      throw new LlmCallError("bad_output", `Gemini returned non-JSON output for ${opts.schemaName}`);
    }
    return {
      data,
      usage: usageOf(res, opts.system + opts.untrustedText, text),
      provider: this.name,
      model: this.extractModel,
    };
  }

  /** 1536-dim, L2-normalized (Gemini only pre-normalizes its full 3072-dim output). */
  async embed(texts: string[]): Promise<EmbedResult> {
    const vectors: number[][] = [];
    for (let i = 0; i < texts.length; i += EMBED_BATCH) {
      const batch = texts.slice(i, i + EMBED_BATCH);
      const res = await this.call((c) =>
        c.models.embedContent({
          model: this.embedModel,
          contents: batch,
          config: { taskType: EMBED_TASK_TYPE, outputDimensionality: EMBED_DIMS },
        })
      );
      const got = res.embeddings ?? [];
      if (got.length !== batch.length) {
        throw new LlmCallError("bad_output", `Expected ${batch.length} embeddings, got ${got.length}`);
      }
      for (const e of got) vectors.push(normalize(e.values ?? []));
    }
    return {
      vectors,
      // The Gemini API doesn't report embedding tokens, so estimate them for the budget.
      usage: { inputTokens: texts.reduce((n, t) => n + estimateTokens(t), 0), outputTokens: 0 },
      provider: this.name,
      model: EMBEDDING_MODEL_TAG,
    };
  }

  async transcribe(pdf: Uint8Array<ArrayBuffer>): Promise<TranscribeResult> {
    const res = await this.call((c) =>
      c.models.generateContent({
        model: this.extractModel,
        contents: [{
          role: "user",
          parts: [{ inlineData: { mimeType: "application/pdf", data: encodeBase64(pdf) } }, {
            text: TRANSCRIBE_PROMPT,
          }],
        }],
        config: { temperature: 0 },
      })
    );
    const text = this.checkedText(res, { allowEmpty: true });
    return { text, usage: usageOf(res, "", text), provider: this.name, model: this.extractModel };
  }

  // --- internals ------------------------------------------------------------

  private client(): Promise<GeminiClient> {
    this.clientPromise ??= import(SDK).then(({ GoogleGenAI }) =>
      new GoogleGenAI({ apiKey: this.opts.apiKey }) as unknown as GeminiClient
    );
    return this.clientPromise;
  }

  /** Runs one SDK call, retrying 429 and 5xx with exponential backoff (1 s, 2 s, 4 s…). */
  private async call<R>(fn: (c: GeminiClient) => Promise<R>): Promise<R> {
    const client = await this.client();
    for (let attempt = 0;; attempt++) {
      try {
        return await fn(client);
      } catch (e) {
        const status = statusOf(e);
        const retryable = status === 429 || (status !== undefined && status >= 500);
        if (retryable && attempt < this.maxRetries) {
          await this.sleep(1000 * 2 ** attempt);
          continue;
        }
        const msg = e instanceof Error ? e.message : String(e);
        if (status === 429) throw new LlmCallError("rate_limited", `Gemini rate limit: ${msg}`, status);
        throw new LlmCallError("upstream", `Gemini call failed: ${msg}`, status);
      }
    }
  }

  private checkedText(res: GenerateResponse, { allowEmpty = false } = {}): string {
    const blocked = res.promptFeedback?.blockReason;
    if (blocked) throw new LlmCallError("blocked", `Gemini blocked the prompt: ${blocked}`);
    const finish = res.candidates?.[0]?.finishReason;
    if (finish && finish !== "STOP") throw new LlmCallError("bad_output", `Gemini stopped early: ${finish}`);
    const text = res.text ?? "";
    if (!text.trim() && !allowEmpty) throw new LlmCallError("bad_output", "Gemini returned an empty response");
    return text;
  }
}

function statusOf(e: unknown): number | undefined {
  const s = (e as { status?: unknown })?.status;
  return typeof s === "number" ? s : undefined;
}

function usageOf(res: GenerateResponse, input: string, output: string): Usage {
  const m = res.usageMetadata;
  return {
    inputTokens: m?.promptTokenCount ?? estimateTokens(input),
    // Thinking tokens are billed as output, so they count against the budget.
    outputTokens: (m?.candidatesTokenCount ?? estimateTokens(output)) + (m?.thoughtsTokenCount ?? 0),
  };
}

function normalize(v: number[]): number[] {
  if (v.length !== EMBED_DIMS) throw new LlmCallError("bad_output", `Expected ${EMBED_DIMS} dims, got ${v.length}`);
  const norm = Math.hypot(...v);
  if (!norm) throw new LlmCallError("bad_output", "Gemini returned a zero vector");
  return v.map((x) => x / norm);
}
