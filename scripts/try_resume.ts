// Dev tool: run the resume pipeline on one file and print every step, so you can
// see what was parsed without the app. From supabase/functions:
//
//   deno task try:resume ../seed/resumes/r09_hidden_white_text.pdf
//   deno task try:resume ~/Downloads/my_resume.pdf --text-only   (free: no LLM call)
//   deno task try:resume <file> --mock                           (fixtures instead of Gemini)
//   deno task try:resume <file> --full                           (print all sanitized text)
//
// Uses Gemini by default (one extract call, plus one transcribe call for scans).
// On the free tier Google may use what you send, so prefer the synthetic fixtures.
import { parseArgs } from "jsr:@std/cli@1.0.20/parse-args";
import { basename, extname, resolve } from "jsr:@std/path@1.1.1";
import {
  DOCX_MIME,
  extractText,
  PDF_MIME,
} from "../supabase/functions/_shared/extract_text.ts";
import {
  EMBED_DIMS,
  getProvider,
  type LlmProvider,
  MockProvider,
} from "../supabase/functions/_shared/llm.ts";
import { normalizeSkills } from "../supabase/functions/_shared/normalize.ts";
import {
  buildDraftProfile,
  mergeYears,
  skillKey,
} from "../supabase/functions/_shared/profile.ts";
import {
  RESUME_SYSTEM_PROMPT,
  wrapUntrusted,
} from "../supabase/functions/_shared/prompts.ts";
import { sanitize } from "../supabase/functions/_shared/sanitize.ts";
import {
  EXTRACTION_SCHEMAS,
  validateExtraction,
} from "../supabase/functions/_shared/schemas.ts";
import { seedSkillIndex } from "../supabase/functions/_shared/seed_taxonomy.ts";

const SEED = new URL("../supabase/seed/", import.meta.url);
const args = parseArgs(Deno.args, { boolean: ["mock", "text-only", "full"] });
const file = args._[0] ? resolve(String(args._[0])) : null;
if (!file) {
  console.error(
    "usage: deno task try:resume <resume.pdf|.docx> [--text-only] [--mock] [--full]",
  );
  Deno.exit(2);
}

const mime =
  { ".pdf": PDF_MIME, ".docx": DOCX_MIME }[extname(file).toLowerCase()];
if (!mime) {
  console.error(`Only .pdf and .docx are supported (got ${extname(file)})`);
  Deno.exit(2);
}

const llm: LlmProvider = args.mock
  ? new MockProvider()
  : getProvider((k) => (k === "LLM_PROVIDER" ? "gemini" : Deno.env.get(k)));
const today = new Date();
const width = (() => {
  try {
    return Math.min(Deno.consoleSize().columns, 140);
  } catch {
    return 110; // not a terminal (piped output)
  }
})();
const cut = (
  s: string,
  n = width - 12,
) => (s.length > n ? `${s.slice(0, n - 1)}…` : s);
const heading = (s: string) =>
  console.log(`\n── ${s} ${"─".repeat(Math.max(0, width - s.length - 4))}`);
let tokens = 0;

// 1. Extract ---------------------------------------------------------------
const bytes = await Deno.readFile(file);
const extracted = await extractText(bytes, mime, llm);
if (extracted.transcribeUsage) {
  tokens += extracted.transcribeUsage.inputTokens +
    extracted.transcribeUsage.outputTokens;
}
heading(`1. Text extraction · ${basename(file)}`);
const how = {
  pdf_text: "PDF text layer (unpdf)",
  docx: "DOCX XML",
  ocr: `image-only PDF → ${llm.name} transcription`,
};
console.log(
  `source: ${
    how[extracted.source]
  } · pages: ${extracted.pages} · lines: ${extracted.lines.length}`,
);

// 2. Sanitize --------------------------------------------------------------
const clean = sanitize(extracted.lines);
heading(`2. Hidden text dropped (${clean.dropped.length})`);
if (!clean.dropped.length) console.log("none");
for (const d of clean.dropped) {
  console.log(
    `✗ [${d.reason}, ${d.fontSize ?? "?"}pt] ${cut(d.text, width - 30)}`,
  );
}

heading(
  `3. Sanitized text sent to the LLM (${clean.text.length} chars, ~${
    Math.ceil(clean.text.length / 4)
  } tokens)`,
);
console.log(
  `contact details redacted: ${clean.redactions} · truncated: ${
    clean.truncated ? "yes" : "no"
  }`,
);
const textLines = clean.text.split("\n");
const shown = args.full ? textLines : textLines.slice(0, 25);
for (const l of shown) console.log(`  ${cut(l)}`);
if (shown.length < textLines.length) {
  console.log(
    `  … ${textLines.length - shown.length} more lines (--full to show all)`,
  );
}

if (args["text-only"]) Deno.exit(0);

// 3. Extract with the LLM --------------------------------------------------
const res = await llm.extract({
  schemaName: "resume",
  schema: EXTRACTION_SCHEMAS.resume.jsonSchema,
  system: RESUME_SYSTEM_PROMPT,
  untrustedText: wrapUntrusted("resume", clean.text),
});
tokens += res.usage.inputTokens + res.usage.outputTokens;
const extraction = validateExtraction("resume", res.data);
const draft = buildDraftProfile(extraction, clean.text, today);
const years = mergeYears(extraction.roles, today);

heading(
  `4. Roles (${extraction.roles.length}) · total experience ${draft.totalYears} yrs`,
);
for (const r of extraction.roles) {
  const y = r.skills_used.length
    ? Math.max(...r.skills_used.map((s) => years.get(skillKey(s)) ?? 0))
    : 0;
  console.log(
    `• ${r.title}  ${r.start ?? "?"} → ${
      r.end ?? "?"
    }  (up to ${y} yrs per skill)`,
  );
  console.log(`    uses: ${cut(r.skills_used.join(", "), width - 12)}`);
}

// 5. Normalize onto the taxonomy (B5) ----------------------------------------
// --mock has no real query vectors, so it stops at exact/alias matching.
const embedder = args.mock
  ? {
    embed: (t: string[]) =>
      Promise.resolve({
        vectors: t.map(() => new Array(EMBED_DIMS).fill(0)),
        usage: { inputTokens: 0, outputTokens: 0 },
        provider: "mock" as const,
        model: "none",
      }),
  }
  : {
    embed: async (t: string[]) => {
      const r = await llm.embed(t);
      tokens += r.usage.inputTokens;
      return r;
    },
  };
const normalized = await normalizeSkills(
  draft.skills.map((s) => s.raw),
  embedder,
  await seedSkillIndex(),
);

heading(
  `5. Skills kept (${draft.skills.length}) — evidence verified, mapped onto the taxonomy`,
);
const nameW = Math.max(8, ...draft.skills.map((s) => s.raw.length));
const canonW = Math.max(
  10,
  ...normalized.map((n) => (n.name ?? "unmapped").length),
);
draft.skills.forEach((s, i) => {
  const n = normalized[i];
  const y = s.years === null ? "listed" : `${s.years} yrs`;
  const via = n.via === "embedding"
    ? `~${n.similarity}`
    : n.via === "unmapped"
    ? `best ${n.similarity ?? "-"}`
    : n.via;
  const canon = `${n.name ?? "unmapped"}`.padEnd(canonW);
  console.log(
    `${n.skill_id ? "✓" : "?"} ${s.raw.padEnd(nameW)} → ${canon} ${
      via.padEnd(10)
    } ${y.padStart(7)}  "${cut(s.evidence, width - nameW - canonW - 32)}"`,
  );
});
const unmapped = normalized.filter((n) => !n.skill_id).length;
console.log(
  `(✓ mapped, ? unmapped: kept on the profile but not scored · ${unmapped} unmapped${
    args.mock ? " · --mock skips the embedding step" : ""
  })`,
);

heading(`6. Skills dropped by the evidence check (${draft.dropped.length})`);
if (!draft.dropped.length) console.log("none");
for (const d of draft.dropped) {
  console.log(
    `✗ ${d.raw} [${d.reason}]  "${cut(d.evidence, width - d.raw.length - 30)}"`,
  );
}
console.log(
  `\neducation: ${
    extraction.education.map((e) =>
      [e.level, e.field].filter(Boolean).join(" ")
    ).join("; ") || "none"
  }`,
);

// 6. Compare with hand labels when the file is a seed fixture ---------------
const labels =
  JSON.parse(await Deno.readTextFile(new URL("fixtures/labels.json", SEED)))
    .resumes[basename(file)];
if (labels) {
  const found = new Set(normalized.map((n) => n.name).filter(Boolean));
  const expected: string[] = labels.skills;
  const hit = expected.filter((s) => found.has(s));
  const leaked = (labels.forbidden_skills as string[]).filter((s) =>
    found.has(s)
  );
  heading("7. Compared with supabase/seed/fixtures/labels.json");
  console.log(
    `recall: ${hit.length}/${expected.length} labeled skills found after normalization`,
  );
  const missed = expected.filter((s) => !found.has(s));
  if (missed.length) console.log(`missed: ${missed.join(", ")}`);
  const extra = [...found].filter((s) => !expected.includes(s!));
  if (extra.length) {
    console.log(`also found (not labeled): ${extra.join(", ")}`);
  }
  console.log(
    leaked.length
      ? `⚠ INJECTED SKILLS GOT THROUGH: ${leaked.join(", ")}`
      : "injection check: no forbidden skills ✓",
  );
}

console.log(
  `\nprovider: ${res.provider} · model: ${res.model} · tokens: ${tokens}`,
);
