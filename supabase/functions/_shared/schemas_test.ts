import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1.0.13";
import {
  EXTRACTION_SCHEMAS,
  ExtractionInvalid,
  jobJsonSchema,
  resumeJsonSchema,
  validateExtraction,
} from "./schemas.ts";

const FIXTURES = new URL("./fixtures/extract/", import.meta.url);
const SEED_JOBS = new URL("../../seed/jobs/", import.meta.url);

type Json = Record<string, unknown>;

/** Visit every object-typed node of a JSON Schema. */
function eachObjectSchema(node: Json, path: string, visit: (n: Json, path: string) => void) {
  if (node.type === "object") visit(node, path);
  for (const [key, child] of Object.entries((node.properties ?? {}) as Record<string, Json>)) {
    eachObjectSchema(child, `${path}.${key}`, visit);
  }
  if (node.items) eachObjectSchema(node.items as Json, `${path}[]`, visit);
}

async function readFixtures(): Promise<Array<{ file: string; data: unknown }>> {
  const out = [];
  for await (const entry of Deno.readDir(FIXTURES)) {
    if (entry.name.endsWith(".json")) {
      out.push({ file: entry.name, data: JSON.parse(await Deno.readTextFile(new URL(entry.name, FIXTURES))) });
    }
  }
  return out;
}

Deno.test("JSON schemas follow the strict structured-output rules", () => {
  for (const [name, { jsonSchema }] of Object.entries(EXTRACTION_SCHEMAS)) {
    eachObjectSchema(jsonSchema as unknown as Json, name, (node, path) => {
      assertEquals(node.additionalProperties, false, `${path}: additionalProperties must be false`);
      assertEquals(
        [...(node.required as string[])].sort(),
        Object.keys(node.properties as Json).sort(),
        `${path}: every property must be required`,
      );
    });
  }
});

Deno.test("resume schema has no protected-attribute fields (US-51)", () => {
  const forbidden =
    /^(name|full_?name|first_?name|last_?name|email|phone|contact|address|city|zip|age|birth|dob|gender|sex|nationality|citizenship|race|ethnicity|religion|marital|photo|image|graduation|grad_?year|year)/i;
  const keys: string[] = [];
  eachObjectSchema(resumeJsonSchema as unknown as Json, "resume", (node, path) => {
    for (const key of Object.keys(node.properties as Json)) keys.push(`${path}.${key}`);
  });
  for (const key of keys) assert(!forbidden.test(key.split(".").pop()!), `forbidden field ${key}`);
  assert(keys.length > 0);
});

Deno.test("every mock fixture validates", async () => {
  const fixtures = await readFixtures();
  assert(fixtures.some((f) => f.file === "default.resume.json"));
  assert(fixtures.some((f) => f.file === "default.job.json"));
  for (const { file, data } of fixtures) {
    const schema = file === "default.resume.json" || "roles" in (data as Json) ? "resume" : "job";
    validateExtraction(schema, data); // throws on failure
  }
});

Deno.test("validators reject smuggled personal fields and bad enums", () => {
  const valid = { roles: [], skills: [], education: [] };
  assertEquals(validateExtraction("resume", valid), valid);
  assertThrows(() => validateExtraction("resume", { ...valid, age: 52 }), ExtractionInvalid);
  assertThrows(
    () => validateExtraction("resume", { ...valid, skills: [{ raw: "Go", evidence: "Go", context: null, years: 10 }] }),
    ExtractionInvalid,
  );
  assertThrows(() => validateExtraction("resume", { roles: [], skills: [] }), ExtractionInvalid);

  const job = {
    title: null,
    location: null,
    remote: null,
    job_type: null,
    sponsorship: null,
    salary_min: null,
    salary_max: null,
    requirements: [],
  };
  assertEquals(validateExtraction("job", job), job);
  assertThrows(() => validateExtraction("job", { ...job, remote: "anywhere" }), ExtractionInvalid);
  assertThrows(() => validateExtraction("job", { ...job, salary_min: -5 }), ExtractionInvalid);
  assertThrows(
    () =>
      validateExtraction("job", {
        ...job,
        requirements: [{ raw: "Go", required_hint: "must", min_years: null, evidence: "" }],
      }),
    ExtractionInvalid,
  );
});

Deno.test("JSON schema enums match the Zod enums", () => {
  const props = jobJsonSchema.properties;
  assertEquals(props.remote.enum.filter((v) => v !== null), ["onsite", "hybrid", "remote"]);
  assertEquals(props.job_type.enum.filter((v) => v !== null), ["full_time", "part_time", "contract", "internship"]);
});

Deno.test("job fixture evidence is a verbatim quote from its JD", async () => {
  const jds: string[] = [];
  for await (const entry of Deno.readDir(SEED_JOBS)) {
    jds.push((await Deno.readTextFile(new URL(entry.name, SEED_JOBS))).replace(/\s+/g, " ").toLowerCase());
  }
  for (const { file, data } of await readFixtures()) {
    if (!("requirements" in (data as Json))) continue;
    const job = validateExtraction("job", data);
    for (const r of job.requirements) {
      const quote = r.evidence.replace(/\s+/g, " ").toLowerCase();
      assert(jds.some((jd) => jd.includes(quote)), `${file}: evidence not in any JD: "${r.evidence}"`);
    }
  }
});
