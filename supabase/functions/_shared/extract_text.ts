// Resume text extraction (AI-05, PRD v0.5 §8.1). Replaces Azure Document
// Intelligence: code reads the text and keeps the formatting facts the
// sanitizer needs to drop hidden text. Only image-only PDFs go to the LLM.
//
//   PDF with text  → unpdf (pdf.js) text items in content-stream order, with
//                    font size, fill color, render mode, and page position
//   image-only PDF → llm.transcribe() (a scan has no hidden text layer)
//   DOCX           → word/document.xml runs with w:vanish, w:color, w:sz
import { unzipSync } from "npm:fflate@0.8.2";
import { getDocumentProxy, getResolvedPDFJS } from "npm:unpdf@1.8.1";
import type { LlmProvider, TranscribeResult } from "./llm.ts";

export type TextSource = "pdf_text" | "docx" | "ocr";
export type HiddenReason = "tiny_font" | "white_text" | "invisible" | "off_page" | "vanish";

export interface TextLine {
  text: string;
  page: number;
  /** Points. null when unknown (DOCX run without an explicit size). */
  fontSize: number | null;
  /** Set when formatting makes this text invisible to a human reader. */
  hidden: HiddenReason | null;
}

export interface ExtractedText {
  source: TextSource;
  pages: number;
  lines: TextLine[];
  /** Present when the OCR path ran, for usage logging by the caller. */
  transcribeUsage?: TranscribeResult["usage"];
}

export const PDF_MIME = "application/pdf";
export const DOCX_MIME = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
/** Fewer visible non-space characters than this per page means "image-only". */
export const MIN_TEXT_CHARS_PER_PAGE = 50;
/** Text this small is unreadable on paper (pt). */
export const TINY_FONT_PT = 4;

export class UnsupportedFile extends Error {
  constructor(mime: string) {
    super(`Unsupported file type: ${mime}`);
    this.name = "UnsupportedFile";
  }
}

export async function extractText(
  bytes: Uint8Array<ArrayBuffer>,
  mime: string,
  llm: Pick<LlmProvider, "transcribe">,
): Promise<ExtractedText> {
  if (mime === DOCX_MIME) return extractDocx(bytes);
  if (mime !== PDF_MIME) throw new UnsupportedFile(mime);

  // pdf.js may detach the buffer it's given, so keep the original for OCR.
  const pdf = await extractPdfText(bytes.slice());
  const visibleChars = pdf.lines.filter((l) => !l.hidden).reduce((n, l) => n + l.text.replace(/\s/g, "").length, 0);
  if (visibleChars >= MIN_TEXT_CHARS_PER_PAGE * pdf.pages) return pdf;

  const { text, usage } = await llm.transcribe(bytes);
  const lines = text.split(/\r?\n/).filter((t) => t.trim()).map((t) => ({
    text: t,
    page: 1,
    fontSize: null,
    hidden: null,
  }));
  return { source: "ocr", pages: pdf.pages, lines, transcribeUsage: usage };
}

// ---------------------------------------------------------------------------
// PDF
// ---------------------------------------------------------------------------

interface PdfTextItem {
  str: string;
  transform: number[];
  height: number;
  hasEOL: boolean;
}

interface DrawnText {
  text: string;
  fill: string;
  renderMode: number;
}

export async function extractPdfText(bytes: Uint8Array): Promise<ExtractedText> {
  const { OPS } = await getResolvedPDFJS();
  const doc = await getDocumentProxy(bytes);
  const lines: TextLine[] = [];

  for (let p = 1; p <= doc.numPages; p++) {
    const page = await doc.getPage(p);
    const [x0, y0, x1, y1] = page.view as number[];
    const items = (await page.getTextContent()).items as PdfTextItem[];
    const drawn = drawnTexts(await page.getOperatorList(), OPS);
    const styleOf = matcher(drawn);

    let current: TextLine | null = null;
    let lastY: number | null = null;
    const flush = () => {
      if (current && current.text.trim()) lines.push(current);
      current = null;
    };

    for (const item of items) {
      const [, , c, d, x, y] = item.transform;
      if (item.str) {
        const fontSize = round1(Math.hypot(c, d));
        const style = styleOf(item.str);
        const hidden: HiddenReason | null = fontSize < TINY_FONT_PT
          ? "tiny_font"
          : style && (style.renderMode === 3 || style.renderMode === 7)
          ? "invisible"
          : style && isNearWhite(style.fill)
          ? "white_text"
          : x < x0 || x > x1 || y < y0 || y > y1
          ? "off_page"
          : null;
        // New line on a vertical jump or when the hidden state changes, so every
        // line is all-visible or all-hidden.
        const jumped = lastY !== null && Math.abs(y - lastY) > Math.max(2, fontSize * 0.5);
        if (current && (jumped || current.hidden !== hidden)) flush();
        current ??= { text: "", page: p, fontSize, hidden };
        current.text += item.str;
        current.fontSize = Math.max(current.fontSize ?? 0, fontSize);
        lastY = y;
      }
      if (item.hasEOL) flush();
    }
    flush();
  }
  return { source: "pdf_text", pages: doc.numPages, lines };
}

/** Walks the operator list, tracking fill color and render mode across save/restore. */
function drawnTexts(ops: { fnArray: number[]; argsArray: unknown[][] }, OPS: Record<string, number>): DrawnText[] {
  const out: DrawnText[] = [];
  const stack: Array<{ fill: string; renderMode: number }> = [];
  let state = { fill: "#000000", renderMode: 0 };
  ops.fnArray.forEach((fn, i) => {
    const args = ops.argsArray[i];
    switch (fn) {
      case OPS.save:
        stack.push({ ...state });
        break;
      case OPS.restore:
        state = stack.pop() ?? state;
        break;
      case OPS.setFillRGBColor:
        if (typeof args?.[0] === "string") state.fill = args[0];
        break;
      case OPS.setTextRenderingMode:
        state.renderMode = Number(args?.[0] ?? 0);
        break;
      case OPS.showText:
      case OPS.showSpacedText: {
        const glyphs = (args?.[0] ?? []) as unknown[];
        const text = glyphs.map((g) => (g && typeof g === "object" && "unicode" in g ? String(g.unicode) : "")).join(
          "",
        );
        if (text.trim()) out.push({ text, ...state });
      }
    }
  });
  return out;
}

/**
 * Text-content items and drawn texts come from the same content stream in the
 * same order, but pdf.js may split one draw into several items. Walk both in
 * order, looking a few draws ahead, and return the style the item was drawn with.
 */
function matcher(drawn: DrawnText[]) {
  const norm = (s: string) => s.replace(/\s+/g, "");
  let at = 0;
  return (str: string): DrawnText | null => {
    const needle = norm(str);
    if (!needle) return null;
    for (let i = at; i < Math.min(drawn.length, at + 25); i++) {
      if (norm(drawn[i].text).includes(needle)) {
        at = i;
        return drawn[i];
      }
    }
    return null; // unknown style: treat as visible rather than guess
  };
}

/** White or near-white fill (luminance ≥ 0.9). Text drawn this way vanishes on a white page. */
export function isNearWhite(hex: string): boolean {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (!m) return false;
  const n = parseInt(m[1], 16);
  const [r, g, b] = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 >= 0.9;
}

// ---------------------------------------------------------------------------
// DOCX
// ---------------------------------------------------------------------------

export function extractDocx(bytes: Uint8Array): ExtractedText {
  let files: Record<string, Uint8Array>;
  try {
    files = unzipSync(bytes, { filter: (f) => f.name === "word/document.xml" });
  } catch {
    throw new UnsupportedFile("corrupt DOCX");
  }
  const xml = files["word/document.xml"];
  if (!xml) throw new UnsupportedFile("DOCX without word/document.xml");
  return { source: "docx", pages: 1, lines: docxLines(new TextDecoder().decode(xml)) };
}

/** One line per paragraph (split where hidden state changes). Tables come through cell by cell. */
export function docxLines(xml: string): TextLine[] {
  const lines: TextLine[] = [];
  for (const { 0: para } of xml.matchAll(/<w:p[\s>][\s\S]*?<\/w:p>/g)) {
    let current: TextLine | null = null;
    for (const run of para.matchAll(/<w:r[\s>][\s\S]*?<\/w:r>/g)) {
      const body = run[0];
      const props = /<w:rPr>([\s\S]*?)<\/w:rPr>/.exec(body)?.[1] ?? "";
      const text = runText(body);
      if (!text) continue;
      const halfPoints = attr(props, "w:sz");
      const fontSize = halfPoints ? Number(halfPoints) / 2 : null;
      const color = attr(props, "w:color");
      const vanish = /<w:vanish(?:\s*\/>|\s+w:val="(?:1|true|on)"\s*\/>)/.test(props);
      const hidden: HiddenReason | null = vanish
        ? "vanish"
        : fontSize !== null && fontSize < TINY_FONT_PT
        ? "tiny_font"
        : color && color !== "auto" && isNearWhite(color)
        ? "white_text"
        : null;
      if (current && current.hidden !== hidden) {
        if (current.text.trim()) lines.push(current);
        current = null;
      }
      current ??= { text: "", page: 1, fontSize, hidden };
      current.text += text;
      if (fontSize !== null) current.fontSize = Math.max(current.fontSize ?? 0, fontSize);
    }
    if (current && current.text.trim()) lines.push(current);
  }
  return lines;
}

function runText(run: string): string {
  let out = "";
  for (const m of run.matchAll(/<w:t(?:\s[^>]*)?>([\s\S]*?)<\/w:t>|<w:tab\s*\/>|<w:br\s*\/>/g)) {
    out += m[1] !== undefined ? decodeXml(m[1]) : m[0].startsWith("<w:tab") ? "\t" : " ";
  }
  return out;
}

function attr(props: string, tag: string): string | null {
  return new RegExp(`<${tag}\\s+w:val="([^"]*)"`).exec(props)?.[1] ?? null;
}

function decodeXml(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (_, e: string) => {
    if (e[0] === "#") {
      return String.fromCodePoint(e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : Number(e.slice(1)));
    }
    return ({ amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" } as Record<string, string>)[e.toLowerCase()];
  });
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}
