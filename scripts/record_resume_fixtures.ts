// Records real Gemini resume extractions as MockProvider fixtures (AI-03/AI-19).
// From supabase/functions:  deno task record:resumes   (one Gemini call per seed resume)
//
// For each supabase/seed/resumes/* file this runs the same text path as
// parse-resume (scans use the mock transcription, so the key matches what the
// mock pipeline sends), then saves the raw Gemini output to
// _shared/fixtures/extract/<fixtureKey(untrustedText)>.json. Re-run after
// changing the prompt, the schema, the sanitizer, or a fixture resume.
import { basename } from "jsr:@std/path@1.1.1";
import {
  DOCX_MIME,
  extractText,
  PDF_MIME,
} from "../supabase/functions/_shared/extract_text.ts";
import {
  fixtureKey,
  getProvider,
  MockProvider,
} from "../supabase/functions/_shared/llm.ts";
import {
  RESUME_SYSTEM_PROMPT,
  wrapUntrusted,
} from "../supabase/functions/_shared/prompts.ts";
import { sanitize } from "../supabase/functions/_shared/sanitize.ts";
import {
  EXTRACTION_SCHEMAS,
  validateExtraction,
} from "../supabase/functions/_shared/schemas.ts";

const RESUMES = new URL("../supabase/seed/resumes/", import.meta.url);
const OUT = new URL(
  "../supabase/functions/_shared/fixtures/extract/",
  import.meta.url,
);
const gemini = getProvider((
  k,
) => (k === "LLM_PROVIDER" ? "gemini" : Deno.env.get(k)));
const mock = new MockProvider();

const files = [...Deno.readDirSync(RESUMES)].map((e) => e.name).sort();
for (const name of files) {
  const bytes = await Deno.readFile(new URL(name, RESUMES));
  const extracted = await extractText(
    bytes,
    name.endsWith(".docx") ? DOCX_MIME : PDF_MIME,
    mock,
  );
  const untrustedText = wrapUntrusted("resume", sanitize(extracted.lines).text);
  const res = await gemini.extract({
    schemaName: "resume",
    schema: EXTRACTION_SCHEMAS.resume.jsonSchema,
    system: RESUME_SYSTEM_PROMPT,
    untrustedText,
  });
  const data = validateExtraction("resume", res.data);
  const key = await fixtureKey(untrustedText);
  await Deno.writeTextFile(
    new URL(`${key}.json`, OUT),
    JSON.stringify(data, null, 2) + "\n",
  );
  console.log(
    `${basename(name).padEnd(34)} → ${
      key.slice(0, 12)
    }… (${data.skills.length} skills, ${data.roles.length} roles)`,
  );
}
