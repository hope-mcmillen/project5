// Sanitizer (AI-06, PRD §8.5). Runs on extracted lines before the LLM sees
// anything: drops hidden text, scrubs contact details, and caps the length.
// Deterministic on purpose, so it can't be talked out of its job.
import { type TextLine, TINY_FONT_PT } from "./extract_text.ts";

/** ~15k tokens at chars ÷ 4 (same estimate as the token budget). */
export const MAX_CHARS = 60_000;
export const TRUNCATION_MARKER = "[…truncated]";

export interface DroppedLine extends TextLine {
  reason: NonNullable<TextLine["hidden"]>;
}

export interface Sanitized {
  /** One line per kept line, joined with "\n". This is what the LLM and the evidence check see. */
  text: string;
  dropped: DroppedLine[];
  truncated: boolean;
  redactions: number;
}

const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
// US-style numbers: (225) 555-0141, 225-555-0141, +1 225.555.0141. Year ranges like 2019-2023 don't match.
const PHONE = /(?:\+?1[\s.-]?)?\(?\b\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}\b/g;
// Everything below U+0020 except tab and newline, plus DEL and zero-width/bidi controls.
// deno-lint-ignore no-control-regex
const CONTROL = new RegExp(
  "[\\u0000-\\u0008\\u000B-\\u001F\\u007F\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\uFEFF]",
  "g",
);

export function sanitize(lines: TextLine[], maxChars = MAX_CHARS): Sanitized {
  const dropped: DroppedLine[] = [];
  const kept: string[] = [];
  let redactions = 0;

  for (const line of lines) {
    const reason = line.hidden ?? (line.fontSize !== null && line.fontSize < TINY_FONT_PT ? "tiny_font" : null);
    if (reason) {
      dropped.push({ ...line, reason });
      continue;
    }
    let text = line.text.replace(CONTROL, "");
    text = text.replace(EMAIL, () => (redactions++, "[email]")).replace(PHONE, () => (redactions++, "[phone]"));
    text = text.replace(/\s+/g, " ").trim();
    if (text) kept.push(text);
  }

  let text = kept.join("\n");
  const truncated = text.length > maxChars;
  if (truncated) {
    // Cut at the last line break before the cap so no line is split mid-sentence.
    const cut = text.lastIndexOf("\n", maxChars);
    text = `${text.slice(0, cut > 0 ? cut : maxChars)}\n${TRUNCATION_MARKER}`;
  }
  return { text, dropped, truncated, redactions };
}
