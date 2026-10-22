// Provider-neutral types, constants, and helpers shared by llm.ts (getProvider,
// MockProvider) and gemini.ts. Kept separate so those two don't import each
// other. Import from "./llm.ts", which re-exports everything here.
import type { SchemaName } from "./schemas.ts";

/** Vector width of skills/profile_versions/jobs.embedding (vector(1536)). */
export const EMBED_DIMS = 1536;

export type ProviderName = "mock" | "gemini";
export const PROVIDER_NAMES: readonly ProviderName[] = ["mock", "gemini"];

export interface Usage {
  inputTokens: number;
  outputTokens: number;
}

export interface ExtractOptions {
  schemaName: SchemaName;
  /** JSON Schema sent as the structured-output format (from EXTRACTION_SCHEMAS). */
  schema: Record<string, unknown>;
  /** Short declarative instructions. Never contains user text. */
  system: string;
  /** Sanitized resume/JD text. Callers wrap it in <resume>…</resume> or <job>…</job>. */
  untrustedText: string;
}

export interface ExtractResult<T> {
  /** Raw model output. Callers must still run validateExtraction() on it. */
  data: T;
  usage: Usage;
  provider: ProviderName;
  model: string;
}

export interface EmbedResult {
  vectors: number[][];
  usage: Usage;
  provider: ProviderName;
  model: string;
}

export interface TranscribeResult {
  text: string;
  usage: Usage;
  provider: ProviderName;
  model: string;
}

export interface LlmProvider {
  readonly name: ProviderName;
  extract<T = unknown>(opts: ExtractOptions): Promise<ExtractResult<T>>;
  embed(texts: string[]): Promise<EmbedResult>;
  /** OCR for image-only PDFs (PRD §8.1). Text-layer PDFs and DOCX never come here. */
  transcribe(pdf: Uint8Array<ArrayBuffer>): Promise<TranscribeResult>;
}

export class LlmConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LlmConfigError";
  }
}

/** Whitespace-insensitive key, so sanitizer spacing changes don't break fixtures. */
export function normalizeForKey(text: string): string {
  return text.replace(/\s+/g, " ").trim();
}

export async function sha256Hex(data: string | Uint8Array<ArrayBuffer>): Promise<string> {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join("");
}

/** File name stem the mock looks up for a given input text. */
export function fixtureKey(text: string): Promise<string> {
  return sha256Hex(normalizeForKey(text));
}

/** Rough token estimate (chars ÷ 4), matching the sanitizer's budget math. */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}
