# ResuRhombus: API Contract

**Companion to:** [SCHEMA.md](SCHEMA.md) (tables, function list) · [PRD.md](PRD.md) §8 (AI & matching) · [TEAM_PLAN.md](TEAM_PLAN.md) (how to change this file)

This is the handoff between backend and frontend (PL-27). Frontend fakes return **exactly** these examples. Changing anything here needs a team-chat heads-up, an update to this file in the same PR, and approval from both frontend owners.

| Section | Owner | Status |
|---|---|---|
| [Conventions](#1-conventions) | A + B | Draft |
| [Database & status RPCs](#7-database-and-status-rpcs-person-a-pl-27) | A | Draft (A2); business RPC implementation A3–A11 |
| [`parse-resume`](#2-parse-resume-edge-function) | B | Draft |
| [`parse-job`](#3-parse-job-edge-function) | B | Draft |
| [`breakdown` shape](#4-breakdown-shape) | B | Draft |
| [`compute_match`](#5-compute_match-rpc) | B | Draft |
| [`get_feed`](#6-get_feed-rpc) | B | Draft |

---

## 1. Conventions

- **IDs** are UUID strings. `"…"` in examples stands for one.
- **Timestamps** are ISO 8601 UTC strings.
- **RPC errors** are raised as `P0001` with the code as the message (e.g., `profile_not_confirmed`). Dart: catch `PostgrestException` and switch on `e.message`.
- **Edge Function errors** return a non-2xx status and the body `{ "error": { "code": "not_owner", "message": "…" } }`. Dart: catch `FunctionException` and read `e.details['error']['code']`.
- **Scores:** `match_score` is an integer 0–100. `band` is derived from it:

  | Band | Score |
  |---|---|
  | `Strong` | 85–100 |
  | `Good` | 70–84 |
  | `Stretch` | 50–69 |
  | `Low` | 0–49 (hidden from the deck unless `include_stretch`) |

---

## 2. `parse-resume` (Edge Function)

Turns an uploaded resume into a **draft** profile version. The candidate reviews it and then calls `confirm_profile` (A).

**Caller:** candidate who owns the resume.
**Call:** `supabase.functions.invoke('parse-resume', body: {'resume_id': '…'})`
**Flow:** The app uploads the file to the `resumes` bucket, inserts the `resumes` row (status `UPLOADED`), then invokes this function. While it runs, the app watches `resumes.status` through Realtime to drive the progress screen:

```
UPLOADED → PARSING_LAYOUT → EXTRACTING → NORMALIZING → READY
                                     ↘ FAILED (failure_reason set)
```

The function returns when the row reaches `READY` or `FAILED` (60 s hard limit). It never leaves a row in a parsing state.

**Request**
```json
{ "resume_id": "…" }
```

**Response `200` (ready)**
```json
{
  "resume_id": "…",
  "status": "READY",
  "cached": false,
  "profile_version_id": "…",
  "version": 1,
  "skill_count": 15,
  "unmapped_count": 2
}
```
`cached` is `true` when the same file (SHA-256 computed by the server from the stored bytes, never the client's `file_hash`) with the same `EXTRACTION_SCHEMA_VERSION` was parsed before, so no AI call was made. Calling `parse-resume` again on a `READY` resume returns its latest draft with `cached: true` and doesn't re-parse.

**Response `200` (failed)**: parsing failures are a normal outcome, not an HTTP error. The app shows the manual fallback (`create_manual_profile`).
```json
{ "resume_id": "…", "status": "FAILED", "failure_reason": "unreadable_scan" }
```

| `failure_reason` | Meaning | Suggested UI |
|---|---|---|
| `unreadable_scan` | No readable text, even after Gemini transcribed the image-only PDF (e.g., a blurry photo) | "We couldn't read this file. Try a text PDF or add skills manually." |
| `too_long` | Over the input cap even after truncation | Same, mention length |
| `timeout` | Took longer than 60 s | Offer retry |
| `budget_exceeded` | Daily AI budget used up | "Try again tomorrow, or add skills manually." |
| `internal` | Anything else | Offer retry |

**Errors**

| HTTP | `code` | When |
|---|---|---|
| 400 | `invalid_request` | Body isn't JSON or `resume_id` isn't a UUID |
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `not_owner` | Resume (or its storage folder) belongs to someone else |
| 404 | `resume_not_found` | No such `resume_id` |
| 409 | `already_parsing` | Row is already in a parsing state (a run stuck for over 2 minutes can be retried) |
| 500 | `config_error` / `internal` | Server misconfiguration or an unexpected error. The row is still left `FAILED`, never mid-parse. |

**Reading the draft:** after `READY`, read the draft skills with a normal select on `candidate_skills` for `profile_version_id` (RLS: own rows only). Each row:
```json
{
  "id": "…", "profile_version_id": "…", "skill_id": "…",
  "raw_name": "Riverpod", "years": 4.5,
  "evidence": "Migrated state management from Provider to Riverpod, cutting rebuild bugs by half.",
  "source": "ai"
}
```
- `skill_id = null` means **unmapped**: show it, but it isn't scored.
- `years = null` means **listed, not evidenced** (shown as "listed").
- `evidence` is always a verbatim quote from the resume. Skills without one are dropped before saving (C-ON-3).

---

## 3. `parse-job` (Edge Function)

Turns a pasted job description into **draft** requirements. The recruiter reviews them and saves with `save_requirements` (A).

**Caller:** recruiter in the job's company.
**Call:** `supabase.functions.invoke('parse-job', body: {'job_id': '…'})`
**Flow:** The app creates the job (`DRAFT`, `raw_description` set, `parse_status = PENDING`), then invokes this function. It returns in about 20 s or less, and also sets `jobs.parse_status` to `READY` or `FAILED`.

**Request**
```json
{ "job_id": "…" }
```

**Response `200`**: from a real Gemini run on `supabase/seed/jobs/job01_flutter_mobile.txt` (shortened).
```json
{
  "job_id": "…",
  "parse_status": "READY",
  "job": {
    "title": "Mobile Engineer (Flutter)",
    "location": "Baton Rouge, LA",
    "remote": "hybrid",
    "job_type": "full_time",
    "sponsorship": false,
    "salary_min": 95000,
    "salary_max": 120000
  },
  "requirements": [
    { "id": "…", "skill_id": "…", "name": "Flutter", "category": "Frameworks", "required": true, "min_years": 2, "weight": 2,
      "evidence": "2+ years building production apps with Flutter and Dart.", "either_of_group": null },
    { "id": "…", "skill_id": "…", "name": "Dart", "category": "Languages", "required": true, "min_years": 2, "weight": 2,
      "evidence": "2+ years building production apps with Flutter and Dart.", "either_of_group": null },
    { "id": "…", "skill_id": "…", "name": "REST APIs", "category": "Tools", "required": true, "min_years": 0, "weight": 2,
      "evidence": "Experience consuming REST APIs.", "either_of_group": null },
    { "id": "…", "skill_id": "…", "name": "Riverpod", "category": "Frameworks", "required": false, "min_years": 0, "weight": 1,
      "evidence": "Experience with a state management approach (Riverpod or Bloc).", "either_of_group": 1 },
    { "id": "…", "skill_id": "…", "name": "Bloc", "category": "Frameworks", "required": false, "min_years": 0, "weight": 1,
      "evidence": "Experience with a state management approach (Riverpod or Bloc).", "either_of_group": 1 },
    { "id": "…", "skill_id": "…", "name": "Swift", "category": "Languages", "required": false, "min_years": 0, "weight": 1,
      "evidence": "Native iOS (Swift) or Android (Kotlin) experience.", "either_of_group": 2 }
  ],
  "unmapped": [
    { "raw": "Auth", "required_hint": "preferred", "min_years": null, "evidence": "Firebase (Auth, Firestore, push notifications)." }
  ],
  "trimmed": []
}
```
- `requirements` are already saved as draft `job_requirements` rows (weight 2 if required, 1 if preferred), required first, at most **15 total and 8 required**. Saving also pre-fills the job fields and sets `jobs.embedding`.
- `min_years` is `0` when the description doesn't state a minimum.
- `either_of_group`: requirements with the same number were alternatives in one sentence ("Riverpod **or** Bloc"). They're saved as *preferred* so a candidate isn't penalized for missing the one they didn't pick. Show them as "one of". It's `null` for ordinary requirements. Not stored in the database: it's only a hint for the review screen.
- `unmapped` lists skills the AI found that aren't in the taxonomy. They aren't saved, because only mapped skills can be scored. Show them so the recruiter can pick the closest skill or ignore them.
- `trimmed` lists mapped requirements cut by the 15-requirement cap (lowest priority first). Not saved. The recruiter can swap one in for another requirement.
- Job fields are only pre-filled where the description states them and the recruiter hasn't already set them. Re-parsing a draft replaces its requirements.
- Requirements whose quote isn't really in the description, or reads like an instruction to an AI, are dropped silently.

**Errors**

| HTTP | `code` | When |
|---|---|---|
| 400 | `invalid_request` | Body isn't JSON or `job_id` isn't a UUID |
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `not_company_recruiter` | Caller isn't a recruiter in the job's company |
| 404 | `job_not_found` | No such `job_id` |
| 409 | `job_not_draft` | Job is already published (use `save_requirements` to edit) |
| 500 | `config_error` / `internal` | Server misconfiguration or an unexpected error (`parse_status` is left `FAILED`) |
| 200 | (`parse_status: "FAILED"`, `failure_reason`) | `timeout`, `budget_exceeded`, or `internal`. The draft's previous requirements, if any, are kept. |

---

## 4. `breakdown` shape

One entry per job requirement. It's stored on `applications.breakdown`, returned by `compute_match`, included in every `get_feed` card, and shown in board detail. It drives the radar chart and the gap list.

| Field | Type | Meaning |
|---|---|---|
| `skill_id` | uuid | Canonical skill of the requirement |
| `name` | string | Skill name |
| `category` | string | `Languages` · `Frameworks` · `Data` · `Cloud/DevOps` · `Tools` · `Domain` |
| `required` | bool | Required (weight 2) or preferred (weight 1) |
| `weight` | int 1–3 | Weight used in the average |
| `min_years` | number | `0` = no minimum stated |
| `candidate_years` | number \| null | Candidate's years in the matched skill. `null` = listed, not evidenced, or no match |
| `matched_via` | string | `exact`, `related` (via `skill_relations`), or `none` |
| `coverage` | number 0–1 | 1 exact, the relation credit if related, 0 none |
| `depth` | number 0–1 | `min(1, candidate_years / min_years)`. 1 if `min_years = 0`, 0.5 if years are unknown |
| `score` | number 0–1 | `coverage × (0.6 + 0.4 × depth)`. One radar spoke |

**Radar:** use one spoke per requirement, or one per category with the average `score` of that category's entries.
**Gaps:** entries with `matched_via = "none"`. A required gap costs much more than a preferred one, because required skills make up 85% of the score (PRD §8.4, v2).

---

## 5. `compute_match` (RPC)

```sql
compute_match(p_profile_version_id uuid, p_job_id uuid) returns jsonb  -- stable
```
**Caller:** other RPCs (`swipe`, `get_feed`, `save_requirements`) and the seed. The app doesn't call it directly.
**Formula:** PRD §8.4 (`scoring_version` 1).

**Example:** the default mock resume (`default.resume.json`, Flutter developer, years as of Oct 2026) against job01. Score **92**, band `Strong` (scoring v2).
```json
{
  "score": 92,
  "breakdown": [
    {"skill_id": "…", "name": "Flutter", "category": "Frameworks", "required": true, "weight": 2, "min_years": 2, "candidate_years": 6.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Dart", "category": "Languages", "required": true, "weight": 2, "min_years": 2, "candidate_years": 4.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "State Management", "category": "Domain", "required": true, "weight": 2, "min_years": 0, "candidate_years": null, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "REST APIs", "category": "Tools", "required": true, "weight": 2, "min_years": 0, "candidate_years": 1.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Git", "category": "Tools", "required": true, "weight": 2, "min_years": 0, "candidate_years": 1.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Code Review", "category": "Domain", "required": true, "weight": 2, "min_years": 0, "candidate_years": null, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Accessibility", "category": "Domain", "required": false, "weight": 1, "min_years": 0, "candidate_years": null, "matched_via": "none", "coverage": 0.0, "depth": 1.0, "score": 0.0},
    {"skill_id": "…", "name": "Bloc", "category": "Frameworks", "required": false, "weight": 1, "min_years": 0, "candidate_years": 1.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Cloud Firestore", "category": "Data", "required": false, "weight": 1, "min_years": 0, "candidate_years": 4.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Firebase", "category": "Cloud/DevOps", "required": false, "weight": 1, "min_years": 0, "candidate_years": 4.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "HIPAA Compliance", "category": "Domain", "required": false, "weight": 1, "min_years": 0, "candidate_years": null, "matched_via": "none", "coverage": 0.0, "depth": 1.0, "score": 0.0},
    {"skill_id": "…", "name": "Kotlin", "category": "Languages", "required": false, "weight": 1, "min_years": 0, "candidate_years": null, "matched_via": "none", "coverage": 0.0, "depth": 1.0, "score": 0.0},
    {"skill_id": "…", "name": "Push Notifications", "category": "Domain", "required": false, "weight": 1, "min_years": 0, "candidate_years": null, "matched_via": "none", "coverage": 0.0, "depth": 1.0, "score": 0.0},
    {"skill_id": "…", "name": "Riverpod", "category": "Frameworks", "required": false, "weight": 1, "min_years": 0, "candidate_years": 4.5, "matched_via": "exact", "coverage": 1.0, "depth": 1.0, "score": 1.0},
    {"skill_id": "…", "name": "Swift", "category": "Languages", "required": false, "weight": 1, "min_years": 0, "candidate_years": null, "matched_via": "none", "coverage": 0.0, "depth": 1.0, "score": 0.0}
  ]
}
```
Check: required average = 6 × 2 × 1.0 / (6 × 2) = 1.0. Preferred average = 4 × 1 × 1.0 / 9 = 0.444. raw = 0.85 × 1.0 + 0.15 × 0.444 = 0.917, so round(91.7) = **92**.

For radar testing, these entries show the other cases (a related match, partial depth, and a required gap):
```json
[
  {"skill_id": "…", "name": "PostgreSQL", "category": "Data", "required": true, "weight": 2, "min_years": 2, "candidate_years": 3, "matched_via": "related", "coverage": 0.6, "depth": 1.0, "score": 0.6},
  {"skill_id": "…", "name": "Python", "category": "Languages", "required": true, "weight": 2, "min_years": 3, "candidate_years": 1.5, "matched_via": "exact", "coverage": 1.0, "depth": 0.5, "score": 0.8},
  {"skill_id": "…", "name": "Kubernetes", "category": "Cloud/DevOps", "required": true, "weight": 2, "min_years": 2, "candidate_years": null, "matched_via": "none", "coverage": 0.0, "depth": 0.5, "score": 0.0}
]
```

**Errors:** `profile_version_not_found`, `job_not_found`.

---

## 6. `get_feed` (RPC)

```sql
get_feed(p_limit int = 20, p_cursor text = null) returns jsonb
```
**Caller:** candidate with a confirmed profile. The result is scoped to `auth.uid()`.
**Call:** `supabase.rpc('get_feed', params: {'p_limit': 20, 'p_cursor': cursor})`

Returns eligible `OPEN` jobs the candidate hasn't swiped, ordered by **Feed Rank** (best first). Hard filters come from `candidates.preferences` (location, remote, job type, sponsorship, salary). Cards below 50 are left out unless `preferences.include_stretch` is true. No more than 2 cards in a row come from the same company.

Feed Rank only orders the deck. **`match_score` never changes because of swipes or pass reasons.**

**Response**
```json
{
  "cards": [
    {
      "job_id": "…",
      "title": "Mobile Engineer (Flutter)",
      "company": { "id": "…", "name": "Pelican Path Health", "verified": true },
      "location": "Baton Rouge, LA",
      "remote": "hybrid",
      "job_type": "full_time",
      "sponsorship": false,
      "salary_min": 95000,
      "salary_max": 120000,
      "published_at": "2026-10-12T14:00:00Z",
      "match_score": 92,
      "band": "Strong",
      "top_matches": ["Flutter", "Dart", "Riverpod"],
      "gaps": ["Accessibility", "HIPAA Compliance", "Kotlin", "Push Notifications", "Swift"],
      "required_gaps": [],
      "breakdown": [ "…same shape as §4, one entry per requirement…" ]
    }
  ],
  "next_cursor": "eyJyIjowLjgxMjMsImoiOiLigKYifQ"
}
```
- `top_matches`: up to 3 matched requirement names, required first, then by `score`.
- `gaps`: every requirement with `matched_via = "none"`. `required_gaps` is the required subset, for the low-match warning.
- `next_cursor` is **opaque**. Pass it back unchanged. It's `null` when there are no more cards. Pages never repeat or skip a card, as long as the cursor is used the same day. A new day re-ranks, so start again from `null`.
- `p_limit` is clamped to 1–50.
- Only jobs sharing at least one skill with the profile (exactly or via a related skill) are considered, so "show stretch roles" never shows score-0 jobs.
- Measured: a 20-card page over 600 open jobs takes about 85 ms (target p95 < 300 ms).
- An empty `cards` array with `next_cursor: null` means the deck is empty (show the empty state).

**Errors:** `not_candidate`, `profile_not_confirmed` (send the user to onboarding), `invalid_cursor`.

---

## 7. Database and status RPCs (Person A, PL-27)

**Draft for frontend review.** A2 supplies the schema and access policies; the
identity/company, profile, application, board and job RPCs in §§7.1–7.4
are implemented and locally tested (A3–A8). Secure links/deletion remain A9–A10; A11 notifications are
excluded by the user. A documented signature does not mean its implementation
has landed. Do not replace B's parsing/scoring sections.
All UUID parameters use PostgreSQL `uuid`; timestamps use `timestamptz`; JSON is
`jsonb`; enums are listed in SCHEMA.md §3. RPCs run atomically. Unauthorized calls
return `P0001` and the documented message. Direct table writes can instead return
Postgres `42501` (permission denied/RLS); uniqueness violations use `23505`.
`void` RPCs return JSON `null`. All application RPCs require a valid user JWT.

### 7.1 Identity and company onboarding (A3–A4)

| Signature → result | Caller | Errors (`P0001`) | Example JSON result |
|---|---|---|---|
| `current_app_role() → app_role` | authenticated, policies | — (null before role choice) | `"candidate"` |
| `my_company_id() → uuid` | authenticated, policies | — (null before joining) | `"20000000-0000-0000-0000-000000000001"` |
| `my_owned_company_id() → uuid` | authenticated, policies | — (null unless owner) | `null` |
| `has_my_application(p_job_id uuid) → boolean` | authenticated, policies; only tests caller's own applications | — | `true` |
| `set_initial_role(p_role app_role) → void` | user with null role | `not_authenticated`, `role_already_set`, `invalid_role` | `null` |
| `create_company(p_name text, p_website text default null) → companies` | recruiter with no company | `not_recruiter`, `already_in_company`, `invalid_company` | Company object below |
| `create_invite(p_expires_in_days integer default 7) → text` | company owner | `not_owner`, `invalid_expiry`, `internal` | `"ABCD2345"` |
| `join_company(p_code text) → companies` | recruiter with no company | `not_recruiter`, `already_in_company`, `invalid_invite` | Company object below |
| `revoke_invite(p_code text) → void` | owner of code's company | `not_owner`, `invalid_invite` | `null` |

Company result (create/join):
```json
{
  "id": "20000000-0000-0000-0000-000000000001",
  "name": "Rhombus Labs", "website": "https://rhombus.example.test",
  "logo_path": null, "verified": false,
  "created_by": "10000000-0000-0000-0000-000000000003",
  "is_seed": false, "created_at": "2026-10-21T14:00:00Z",
  "updated_at": "2026-10-21T14:00:00Z"
}
```
Invite expiration is 1–30 days. Codes are 8 uppercase unambiguous characters;
expired, revoked, exhausted and nonexistent codes all produce `invalid_invite`.
Codes are trimmed and uppercased on join/revoke. Company names are trimmed and
must be 1–120 characters; optional websites are trimmed HTTP(S) URLs (at most
2048 characters). New companies are softly verified only when their creator has a confirmed email
whose exact domain matches the lowercased website host (with `www.` removed).
Common free-mail domains are denied. Missing/mismatched/unconfirmed domains yield
`verified=false`; unverified companies can still post. Website edits recompute
the badge from the creator's confirmed email. This is not legal company verification.
Only authenticated callers can execute these RPCs; anonymous calls fail `42501`.
Role choice is immutable once set, including for Google accounts. An invalid
non-null enum string is rejected as PostgreSQL `22P02` before the function runs.

### 7.2 Reviewed profiles and preferences (A5)

| Signature → result | Caller | Errors (`P0001`) | Example JSON result |
|---|---|---|---|
| `create_manual_profile() → profile_versions` | candidate | `not_candidate` | Profile object below |
| `confirm_profile(p_version_id uuid, p_skills jsonb) → void` | owning candidate | `not_candidate`, `not_owner`, `invalid_skills`, `profile_already_confirmed` | `null` |
| `save_preferences(p_prefs jsonb) → void` | candidate | `not_candidate`, `invalid_preferences` | `null` |

Manual profile result:
```json
{
  "id": "30000000-0000-0000-0000-000000000001",
  "candidate_id": "10000000-0000-0000-0000-000000000001", "resume_id": null,
  "version": 1, "source": "manual", "confirmed": false, "confirmed_at": null,
  "total_years": null, "education": [], "embedding": null,
  "embedding_model": null, "is_seed": false, "created_at": "2026-10-21T20:00:00Z"
}
```
`p_skills` is an array of skill objects. `skill_id` may be null for unmapped
skills; `raw_name` is required, nonempty text; `years` is nonnegative numeric or
null; `evidence` is text or null. Edited rows must be recorded as `source='user'`,
never trusted as AI evidence. Confirmation sets the active version atomically and rebuilds its taxonomy
embedding using B's `skills_centroid`; the model is `gemini-embedding-001@1536`
when a vector exists, otherwise null. Unchanged AI rows retain their provenance;
edited or newly added rows are `user`. Re-confirming an accepted snapshot fails.
Manual version numbering is serialized with resume parsing. At most 100 skills
are accepted; names are trimmed to 1–120 characters, evidence is at most 2000
characters, years are 0–99.9 with at most one decimal, and duplicate/unknown
canonical IDs or duplicate case-insensitive unmapped names are rejected. No
client `source` or other unknown properties are accepted. Empty fallback profiles
are allowed. Parsed career totals are preserved; manual totals use the greatest
skill duration rather than adding overlapping years.
```json
{
  "p_version_id": "30000000-0000-0000-0000-000000000001",
  "p_skills": [{"skill_id": null, "raw_name": "Custom Tool", "years": 1.5, "evidence": "Built internal tooling"}]
}
```
Preferences replace the object rather than merge it. Allowed optional keys are
`locations: string[]`, `remote: remote_type[]`, `job_types: job_type[]`,
`needs_sponsorship: boolean`, `salary_min: nonnegative integer`,
`include_stretch: boolean`. Arrays are limited to 50 entries; strings must be
1–120 characters; salary must fit a nonnegative 32-bit integer. Unknown keys,
nulls and wrong types are rejected.
```json
{"p_prefs":{"locations":["Baton Rouge, LA"],"remote":["remote","hybrid"],"job_types":["full_time"],"needs_sponsorship":false,"salary_min":70000,"include_stretch":false}}
```

Resume rows store bucket-relative paths: `{uid}/{uuid}.pdf` or `.docx`. The bucket
name `resumes` is passed separately to Storage APIs. A5 supplies bucket policies;
A2 already blocks registering another user's path and client-forged parse state.
The `resumes` bucket is private, limits each upload to 5 MiB, and accepts PDF/DOCX
MIME types only. A candidate can read/insert/delete only their own objects;
filenames must be a UUID plus `.pdf` or `.docx`. Uploads are immutable: use a new
UUID for a replacement rather than upsert. Recruiters have no direct access.
`company-logos` is public (PNG/JPEG/WebP, 5 MiB); only a company's owner can write
or delete its `{company_id}/...` objects.

### 7.3 Applying, passing and the candidate pipeline (A7–A8)

| Signature → result | Caller | Errors (`P0001`) | Example JSON result |
|---|---|---|---|
| `swipe(p_job_id uuid, p_direction swipe_direction, p_reason pass_reason default null) → jsonb` | candidate with confirmed profile | `not_candidate`, `profile_not_confirmed`, `job_not_open`, `daily_cap_reached`, `already_swiped`, `invalid_reason`, `invalid_direction` | Swipe object below |
| `undo_swipe(p_swipe_id uuid) → void` | owning candidate | `not_candidate`, `not_owner`, `undo_window_expired` | `null` |
| `set_pass_reason(p_swipe_id uuid, p_reason pass_reason) → void` | owning candidate | `not_candidate`, `not_owner`, `not_left_swipe` | `null` |
| `withdraw(p_application_id uuid) → void` | owning candidate | `not_candidate`, `not_owner`, `invalid_transition` | `null` |
| `get_application_contact(p_application_id uuid) → jsonb` | owning candidate at INTERVIEW_REQUESTED | `not_candidate`, `not_owner`, `contact_not_available` | `{"name":"Demo Recruiter","email":"recruiter@rhombus.example.test","note":"Please suggest interview times."}` |

Right swipe response:
```json
{"swipe_id":"60000000-0000-0000-0000-000000000001","application_id":"50000000-0000-0000-0000-000000000001","committed_at":"2026-10-22T14:00:05Z"}
```
Left swipe returns the same keys with `application_id` and `committed_at` null.
Undo is allowed for five seconds for either direction; an expired right swipe
must use `withdraw` instead. The cap counts right swipes in the UTC day and must
be serialized per candidate so concurrent requests cannot bypass it. A right
swipe cannot include a pass reason. `compute_match` is owned by B and the real v2 SQL scorer is integrated. The
application stores its confirmed profile-version ID, score, breakdown and scoring
version. No scoring stub is used. Withdrawal keeps the right swipe and does not
refund the daily cap. A successful undo removes the pending application and its
events atomically. Time windows use the wall clock, including after lock waits;
a long transaction cannot extend them. Null direction returns `invalid_direction`.
Expired jobs are rejected even before the scheduled expiry sweep closes them.

### 7.4 Recruiter jobs, blind board and decisions (A8)

| Signature → result | Caller | Errors (`P0001`) | Example JSON result |
|---|---|---|---|
| `save_requirements(p_job_id uuid, p_requirements jsonb) → void` | recruiter in job's company | `not_recruiter`, `not_owner`, `invalid_requirements`, `invalid_transition` | `null` |
| `set_job_status(p_job_id uuid, p_status job_status) → void` | recruiter in job's company | `not_recruiter`, `not_owner`, `invalid_transition`, `requirements_not_ready` | `null` |
| `get_board(p_job_id uuid, p_filters jsonb default '{}', p_limit integer default 50, p_offset integer default 0) → jsonb` | recruiter in job's company | `not_recruiter`, `not_owner`, `invalid_filters`, `invalid_pagination` | Array of tiles below |
| `get_candidate_detail(p_application_id uuid) → jsonb` | recruiter in job's company | `not_recruiter`, `not_owner`, `application_not_committed` | Detail object below |
| `open_application(p_application_id uuid) → void` | recruiter in job's company | `not_recruiter`, `not_owner`, `application_not_committed`, `invalid_transition` | `null` |
| `advance(p_application_id uuid, p_note text default null) → void` | recruiter in job's company | `not_recruiter`, `not_owner`, `application_not_committed`, `invalid_transition`, `invalid_note` | `null` |
| `reject(p_application_id uuid, p_reason text default null) → void` | recruiter in job's company | `not_recruiter`, `not_owner`, `application_not_committed`, `invalid_transition`, `invalid_reason` | `null` |
| `undo_reject(p_application_id uuid) → void` | recruiter in job's company | `not_recruiter`, `not_owner`, `invalid_transition`, `undo_window_expired` | `null` |
| `get_interview_list(p_job_id uuid default null) → jsonb` | recruiter; own company only | `not_recruiter`, `not_owner` | Array of advanced detail objects |

`p_requirements` is an array of `{skill_id: uuid, required: boolean,
min_years: nonnegative number, weight: integer 1..3, evidence: string|null}`;
at most 15 total and 8 required. An empty array is permitted only for a DRAFT job. Duplicate/unmapped skills are rejected. The RPC builds the job centroid using B's `skills_centroid` and, for OPEN/PAUSED
jobs, refreshes nonterminal application scores using B's existing `compute_match`
formula in the same transaction. Confirmed candidate snapshots stay unchanged.
Closed-job requirements cannot be edited. Years are 0–99.9 to one decimal and
optional evidence is limited to 2000 characters.
```json
{"p_job_id":"40000000-0000-0000-0000-000000000001","p_requirements":[{"skill_id":"70000000-0000-0000-0000-000000000001","required":true,"min_years":2,"weight":2,"evidence":"Two years of Flutter"}]}
```
Allowed job transitions: DRAFT→OPEN, OPEN→PAUSED/CLOSED, PAUSED→OPEN/CLOSED;
CLOSED is terminal. Publishing requires a nonempty title, READY parsing and at least one validated
requirement. First publication sets a 60-day expiry; pausing/resuming preserves
the publication/expiry timestamps. Expired or CLOSED jobs cannot be reopened. Closing/expiry turns nonterminal applications into JOB_CLOSED with
status events in the same transaction. Candidate transitions follow SCHEMA.md §3;
opening an UNDER_REVIEW application is idempotent. Reject undo lasts 10 seconds and cannot revive an application on a CLOSED/expired
job. Advance notes and internal reject reasons are limited to 2000 characters.
Internal reject reasons never appear in any candidate-visible response.

Board filters are optional `statuses: application_status[]` and
`min_score: integer 0..100`. Unknown keys/types are rejected. Limit is 1–100;
offset is nonnegative. The default excludes NOT_SELECTED, WITHDRAWN, JOB_CLOSED.
All responses exclude pending applications, including detail and interviews.
Sort by match_score descending, committed_at ascending, id ascending as tie-break.
Empty lists return `[]`.

The tile key set is exactly the following (no identity or profile IDs):
```json
[{
  "application_id":"50000000-0000-0000-0000-000000000001","handle":"◆ 4F2A",
  "match_score":87,"band":"Strong","total_years":4.5,
  "top_skills":["Flutter","Dart","Firebase"],"gaps":["Kubernetes"],
  "status":"APPLIED","committed_at":"2026-10-22T14:00:05Z"
}]
```
Detail adds `breakdown` (the exact §4 array) and `skills` (reviewed skill evidence).
Before advancement it has no `identity` key. Known candidate names and contact
patterns (email, links and phone numbers) are redacted from reviewed free-text
skill names/evidence; canonical taxonomy names remain visible. Internal redaction
and state-dispatch helpers are not callable as client RPCs. At INTERVIEW_REQUESTED it also adds
`identity: {display_name: string|null, email: string}`. Resume links are requested
separately from `resume-url`; evidence should not expose raw contact information.
```json
{
  "application_id":"50000000-0000-0000-0000-000000000001","handle":"◆ 4F2A",
  "match_score":87,"band":"Strong","total_years":4.5,
  "top_skills":["Flutter"],"gaps":[],"status":"INTERVIEW_REQUESTED",
  "committed_at":"2026-10-22T14:00:05Z","breakdown":[],
  "skills":[{"name":"Flutter","years":3,"evidence":"Built mobile applications"}],
  "identity":{"display_name":"Demo Candidate","email":"candidate@example.test"}
}
```
`get_interview_list` returns an array of these advanced detail objects. The example's
empty breakdown is valid for an empty fixture; real scored jobs return §4 entries.

### 7.5 Secure links and deletion (A9–A10); excluded notification design (A11)

All Edge requests use `Content-Type: application/json`. User endpoints require
`Authorization: Bearer <user JWT>` and verify it server-side. They never accept a
client-supplied user ID as authority. Errors use the §1 Edge error envelope.

| Endpoint / signature | Caller / payload | Success example | Error codes |
|---|---|---|---|
| `resume-url` Edge | own-company recruiter after advance; `{"application_id":"50000000-0000-0000-0000-000000000001"}` | `{"url":"http://127.0.0.1:54321/storage/v1/object/sign/resumes/10000000-0000-0000-0000-000000000001/resume.pdf?token=example"}` | `unauthorized`, `not_recruiter`, `not_owner`, `resume_not_available`, `invalid_request`, `method_not_allowed`, `internal` |
| `delete-account` Edge | candidate; `{}` | `{"deleted":true}` | `unauthorized`, `not_candidate`, `method_not_allowed`, `internal` |
| `register_device(p_token text, p_platform text) → void` | authenticated; platform `android`, `web` | `null` | `not_authenticated`, `invalid_device` |
| `notify` Edge webhook | trusted system secret; payload below | `{"delivered":1}` | `unauthorized`, `invalid_event`, `delivery_failed`, `internal` |

Signed resume URLs expire after 600 seconds. Missing, wrong-company, pending or
non-advanced applications must not yield URLs. Deletion removes owned Storage
objects, anonymizes retained applications, deletes candidate-owned rows and the
auth user; failures must be explicit and retries safe. It is not accepted until
the no-remaining-data integration test passes.

**Implemented, locally/CI verified and deployed to the approved hosted dev project October 22 (A9/A10).** `resume-url` calls
`get_resume_access(p_application_id uuid) → text` with the caller's JWT. It checks
role, company, committed deadline, non-anonymized INTERVIEW_REQUESTED status, and
the applied profile snapshot's own resume. Only signing uses the service client.
Missing/manual-only resumes return `resume_not_available`. `{url}` is a bearer
link valid for 600 seconds: already issued links remain usable until expiry or
file deletion even if the application status changes. New links are denied after
rejection/withdrawal. Set `PUBLIC_SUPABASE_URL` to the externally reachable API
origin for local containers; hosted deployments default to `SUPABASE_URL`.

`delete-account` takes no required body and ignores caller-supplied user IDs.
It invokes `prepare_account_deletion() → void` with the caller's JWT; this
candidate-only RPC locks the candidate and applications, detaches swipe FKs,
anonymizes retained applications (clearing breakdown, profile references, notes
and private rejection text), removes candidate/version/skill/resume/swipe data,
usage and device rows, clears identifiable status-event actors, and scrubs the
profile display name. It can be retried while Auth still exists. Storage upload
permission holds a candidate key-share lock, so preparation waits for active
uploads and later uploads are refused. The Edge Function drains all owned Storage
pages (including files without resume metadata), then hard-deletes the Auth user,
which cascades the remaining profile. Failures return `internal`; Auth is removed
last so callers can retry cleanup. There is no cross-service transaction: a failed
call may already have irreversibly removed some owned data. The test exercises a
retry after preparation and verifies no private rows or files remain.

Realtime publishes `resumes`, `applications` and `jobs` with their existing RLS.
Actual signed-in socket clients verify own application/parse updates, own-company
job updates, and absence of those events for another candidate/company. A pending
insert does not emit another insert when its five-second deadline elapses;
recruiter clients should refetch the board after that deadline. Channel join may
precede the PostgreSQL subscription acknowledgement; wait for the database
`system` success event before relying on changes, and refetch on reconnect. These live tests
cover backend delivery; frontend subscription wiring remains C/D ownership.

**A11 is out of scope per user direction (October 20); no Firebase/FCM setup or
notification endpoints are being implemented.** The following describes only the
original deferred design.

The notify handler validates the webhook source and reloads the actual event
from the database, rather than trusting recipient IDs or statuses in the body.
Only INTERVIEW_REQUESTED and NOT_SELECTED send notifications; other events return
`{"delivered":0}`. No contact details, resume contents or internal reject reasons
belong in notification payloads. Requires FCM service-account secrets and device
testing before A11 can be called complete.
```json
{"type":"INSERT","schema":"public","table":"status_events","record":{"id":42,"application_id":"50000000-0000-0000-0000-000000000001","to_status":"INTERVIEW_REQUESTED"}}
```
