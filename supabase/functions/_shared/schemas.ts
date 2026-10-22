// Extraction schemas (AI-02): the single source of truth shared by the LLM
// prompt (structured outputs), the runtime validators, and the tests.
//
// Rules (PRD §8.2, §8.5):
// - The LLM returns facts with evidence. Never scores, never date math.
// - The resume schema has NO fields for name, contact info, photo, age,
//   graduation year, gender, nationality, or address. Don't add them.
// - JSON Schemas use the strict structured-output style: every property is
//   listed in `required`, every object has `additionalProperties: false`, and
//   optional values use ["<type>", "null"]. Gemini receives them as
//   `responseJsonSchema` (B3); if it rejects a construct, convert it in the
//   adapter rather than loosening these.
//
// Bump EXTRACTION_SCHEMA_VERSION whenever either schema changes; cached
// extractions are keyed by (file_hash, schema version).
import { z } from "npm:zod@3.25.76";

export const EXTRACTION_SCHEMA_VERSION = 3; // v3: roles carry kind, organization, and highlights

const nullableString = (description: string) => ({ type: ["string", "null"], description });

/** public.experience_kind. Projects and research count as experience for students. */
export const EXPERIENCE_KINDS = ["job", "internship", "research", "project", "volunteer", "other"] as const;
/** Bullets kept per experience. */
export const MAX_HIGHLIGHTS = 6;

// ---------------------------------------------------------------------------
// Resume
// ---------------------------------------------------------------------------

export const resumeJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["roles", "skills", "education"],
  properties: {
    roles: {
      type: "array",
      description: "Every experience entry (jobs, internships, research, projects, volunteering), most recent first.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["kind", "title", "organization", "start", "end", "highlights", "skills_used", "evidence"],
        properties: {
          kind: { type: "string", enum: [...EXPERIENCE_KINDS] },
          title: { type: "string", description: "Role or project title as written." },
          organization: nullableString("Employer, lab, or organization as written. null if not stated."),
          start: nullableString('Start as "YYYY-MM" or "YYYY". null if not stated.'),
          end: nullableString('End as "YYYY-MM", "YYYY", or "present". null if not stated.'),
          highlights: {
            type: "array",
            items: { type: "string" },
            description: `Up to ${MAX_HIGHLIGHTS} accomplishment bullets from this entry, each copied verbatim.`,
          },
          skills_used: {
            type: "array",
            items: { type: "string" },
            description:
              "Individual technical skills this role's text shows being used, one name per item, as written.",
          },
          evidence: {
            type: "string",
            description: "Verbatim quote from this entry's text that shows the title or what was done.",
          },
        },
      },
    },
    skills: {
      type: "array",
      description:
        'Every technical skill in the resume, once each. One entry per individual skill: split lists such as "Flutter and Dart" or "Firebase (Auth, Firestore)" into separate entries.',
      items: {
        type: "object",
        additionalProperties: false,
        required: ["raw", "evidence", "context"],
        properties: {
          raw: {
            type: "string",
            description: 'A single skill name as written, e.g. "Flutter", never "Flutter and Dart".',
          },
          evidence: {
            type: "string",
            description:
              "Verbatim quote from the resume that mentions the skill. Split skills may share the same quote.",
          },
          context: nullableString('"role:<index>" if it comes from a role, "skills" if only listed, else null.'),
        },
      },
    },
    education: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["level", "field"],
        properties: {
          level: nullableString('Degree level, e.g. "BS", "MS", "PhD", "AA", "Bootcamp".'),
          field: nullableString("Field of study."),
        },
      },
    },
  },
} as const;

export const ResumeExtraction = z.object({
  roles: z.array(
    z.object({
      kind: z.enum(EXPERIENCE_KINDS),
      title: z.string(),
      organization: z.string().nullable(),
      start: z.string().nullable(),
      end: z.string().nullable(),
      highlights: z.array(z.string()),
      skills_used: z.array(z.string()),
      evidence: z.string(),
    }).strict(),
  ),
  skills: z.array(
    z.object({
      raw: z.string().min(1),
      evidence: z.string(),
      context: z.string().nullable(),
    }).strict(),
  ),
  education: z.array(
    z.object({
      level: z.string().nullable(),
      field: z.string().nullable(),
    }).strict(),
  ),
}).strict();
export type ResumeExtraction = z.infer<typeof ResumeExtraction>;

// ---------------------------------------------------------------------------
// Job description
// ---------------------------------------------------------------------------

const REMOTE = ["onsite", "hybrid", "remote"] as const; // public.remote_type
const JOB_TYPE = ["full_time", "part_time", "contract", "internship"] as const; // public.job_type

export const jobJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "location", "remote", "job_type", "sponsorship", "salary_min", "salary_max", "requirements"],
  properties: {
    title: nullableString("Job title as stated."),
    location: nullableString('City and state, e.g. "Baton Rouge, LA". null if not stated.'),
    remote: { type: ["string", "null"], enum: [...REMOTE, null] },
    job_type: { type: ["string", "null"], enum: [...JOB_TYPE, null] },
    sponsorship: { type: ["boolean", "null"], description: "Whether visa sponsorship is offered. null if not stated." },
    salary_min: { type: ["integer", "null"], description: "Annual USD. null if not stated." },
    salary_max: { type: ["integer", "null"], description: "Annual USD. null if not stated." },
    requirements: {
      type: "array",
      description:
        'Technical skills the job asks for, once each. One entry per individual skill: split lists such as "Flutter and Dart" or "Firebase (Auth, Firestore)" into separate entries.',
      items: {
        type: "object",
        additionalProperties: false,
        required: ["raw", "required_hint", "min_years", "evidence"],
        properties: {
          raw: {
            type: "string",
            description: 'A single skill name as written, e.g. "Flutter", never "Flutter and Dart".',
          },
          required_hint: { type: "string", enum: ["required", "preferred"] },
          min_years: { type: ["number", "null"], description: "Minimum years if stated, else null." },
          evidence: {
            type: "string",
            description: "Verbatim quote from the description. Split skills may share the same quote.",
          },
        },
      },
    },
  },
} as const;

export const JobExtraction = z.object({
  title: z.string().nullable(),
  location: z.string().nullable(),
  remote: z.enum(REMOTE).nullable(),
  job_type: z.enum(JOB_TYPE).nullable(),
  sponsorship: z.boolean().nullable(),
  salary_min: z.number().int().nonnegative().nullable(),
  salary_max: z.number().int().nonnegative().nullable(),
  requirements: z.array(
    z.object({
      raw: z.string().min(1),
      required_hint: z.enum(["required", "preferred"]),
      min_years: z.number().nonnegative().nullable(),
      evidence: z.string(),
    }).strict(),
  ),
}).strict();
export type JobExtraction = z.infer<typeof JobExtraction>;

// ---------------------------------------------------------------------------
// Registry used by the adapter and callers: extract({ schemaName, schema }) then
// validateExtraction(schemaName, data) as defense in depth.
// ---------------------------------------------------------------------------

export const EXTRACTION_SCHEMAS = {
  resume: { jsonSchema: resumeJsonSchema, validator: ResumeExtraction },
  job: { jsonSchema: jobJsonSchema, validator: JobExtraction },
} as const;
export type SchemaName = keyof typeof EXTRACTION_SCHEMAS;

export class ExtractionInvalid extends Error {
  constructor(public schemaName: SchemaName, public issues: z.ZodIssue[]) {
    super(
      `LLM output failed ${schemaName} validation: ${
        issues.map((i) => `${i.path.join(".")}: ${i.message}`).join("; ")
      }`,
    );
    this.name = "ExtractionInvalid";
  }
}

export function validateExtraction(schemaName: "resume", data: unknown): ResumeExtraction;
export function validateExtraction(schemaName: "job", data: unknown): JobExtraction;
export function validateExtraction(schemaName: SchemaName, data: unknown): ResumeExtraction | JobExtraction;
export function validateExtraction(schemaName: SchemaName, data: unknown) {
  const result = EXTRACTION_SCHEMAS[schemaName].validator.safeParse(data);
  if (!result.success) throw new ExtractionInvalid(schemaName, result.error.issues);
  return result.data;
}
