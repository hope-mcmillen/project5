import { assertEquals } from "jsr:@std/assert@1.0.13";
import {
  buildDraftProfile,
  mergeYears,
  normalizeForEvidence,
  parseMonth,
  totalYears,
  validateEvidence,
} from "./profile.ts";
import type { ResumeExtraction } from "./schemas.ts";

const TODAY = new Date("2026-10-18T12:00:00Z");
type Role = ResumeExtraction["roles"][number];
const role = (start: string | null, end: string | null, skills: string[]): Role => ({
  title: "Engineer",
  start,
  end,
  skills_used: skills,
  evidence: "",
});

Deno.test("parseMonth handles YYYY-MM, YYYY, present, and junk", () => {
  assertEquals(parseMonth("2021-06", "start", TODAY), 2021 * 12 + 5);
  assertEquals(parseMonth("2021-6", "start", TODAY), 2021 * 12 + 5);
  assertEquals(parseMonth("2021", "start", TODAY), 2021 * 12);
  assertEquals(parseMonth("2021", "end", TODAY), 2021 * 12 + 5);
  assertEquals(parseMonth("Present", "end", TODAY), 2026 * 12 + 9);
  assertEquals(parseMonth("present", "start", TODAY), null);
  for (const bad of ["2021-13", "June 2021", "", null]) assertEquals(parseMonth(bad, "start", TODAY), null);
});

Deno.test("mergeYears unions overlapping roles per skill and rounds to 0.5", () => {
  const years = mergeYears([
    role("2020-01", "2021-12", ["Python", "Django"]), // 24 months
    role("2021-07", "2022-12", ["python", "FastAPI"]), // overlaps 6 months
    role("2024-01", "present", ["Python"]), // 34 months to Oct 2026
  ], TODAY);
  assertEquals(years.get("python"), 6); // (36 + 34) / 12 = 5.83 → 6
  assertEquals(years.get("django"), 2);
  assertEquals(years.get("fastapi"), 1.5);
  assertEquals(years.has("go"), false);
});

Deno.test("mergeYears skips undated or backwards roles and never counts the future", () => {
  const years = mergeYears([
    role(null, "2022-01", ["Go"]),
    role("2023-05", "2022-01", ["Rust"]),
    role("2026-01", "2030-12", ["Zig"]), // capped at today
    role("2019", "2023", ["Java"]),
  ], TODAY);
  assertEquals([years.has("go"), years.has("rust")], [false, false]);
  assertEquals(years.get("zig"), 1); // Jan–Oct 2026 = 10 months → 1.0
  assertEquals(years.get("java"), 4.5);
});

Deno.test("totalYears counts each month once across all roles", () => {
  assertEquals(totalYears([role("2020-01", "2020-12", []), role("2020-07", "2021-06", [])], TODAY), 1.5);
  assertEquals(totalYears([], TODAY), 0);
});

Deno.test("validateEvidence: quote must be in the text and mention the skill", () => {
  const text = "Experience\n• Led migration of the dashboard to\nReactJS — cut load time “in half”.";
  assertEquals(validateEvidence({ raw: "ReactJS", evidence: "Led migration of the dashboard to ReactJS" }, text), {
    ok: true,
  });
  // Smart quotes and dashes from the model still match.
  assertEquals(validateEvidence({ raw: "ReactJS", evidence: 'ReactJS - cut load time "in half"' }, text), { ok: true });
  assertEquals(validateEvidence({ raw: "Kubernetes", evidence: "Ran Kubernetes clusters" }, text), {
    ok: false,
    reason: "not_in_text",
  });
  assertEquals(
    validateEvidence({ raw: "Kubernetes", evidence: "Led migration of the dashboard" }, text),
    { ok: false, reason: "skill_not_in_quote" },
  );
  assertEquals(validateEvidence({ raw: "React", evidence: " " }, text), { ok: false, reason: "no_evidence" });
});

Deno.test("normalizeForEvidence unifies punctuation and spacing", () => {
  assertEquals(normalizeForEvidence("  It’s  “Node.js” – fast\n• really "), `it's "node.js" - fast really`);
});

Deno.test("buildDraftProfile: evidence filter, dedupe, years or listed", () => {
  const extraction: ResumeExtraction = {
    roles: [role("2022-01", "2023-12", ["Flutter"])],
    skills: [
      { raw: "Flutter", evidence: "Built apps in Flutter", context: "role:0" },
      { raw: "flutter ", evidence: "Built apps in Flutter", context: "skills" },
      { raw: "Dart", evidence: "Dart", context: "skills" },
      { raw: "Kubernetes", evidence: "Kubernetes 10 years", context: null },
    ],
    education: [],
  };
  const draft = buildDraftProfile(extraction, "Skills: Dart\nBuilt apps in Flutter", TODAY);
  assertEquals(draft.skills, [
    { raw: "Flutter", evidence: "Built apps in Flutter", years: 2 },
    { raw: "Dart", evidence: "Dart", years: null },
  ]);
  assertEquals(draft.dropped, [{ raw: "Kubernetes", evidence: "Kubernetes 10 years", reason: "not_in_text" }]);
  assertEquals(draft.totalYears, 2);
});
