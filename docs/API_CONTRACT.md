# ResuRhombus: API Contract

**Companion to:** [SCHEMA.md](SCHEMA.md) (tables, function list) · [PRD.md](PRD.md) §8 (AI & matching) · [TEAM_PLAN.md](TEAM_PLAN.md) (how to change this file)

This is the handoff between backend and frontend (PL-27). Frontend fakes return **exactly** these examples. Changing anything here needs a team-chat heads-up, an update to this file in the same PR, and approval from both frontend owners.

| Section | Owner | Status |
|---|---|---|
| [Conventions](#1-conventions) | A + B | Draft |
| Database & status RPCs (`swipe`, `get_board`, `advance`, …) | A | **To do (A2)** |
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
`cached` is `true` when the same file (by SHA-256) with the same `EXTRACTION_SCHEMA_VERSION` was parsed before, so no AI call was made.

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
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `not_owner` | Resume belongs to someone else |
| 404 | `resume_not_found` | No such `resume_id` |
| 409 | `already_parsing` | Row is already in a parsing state |

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

**Response `200`**: example from `supabase/seed/jobs/job01_flutter_mobile.txt` (mock fixture `default.job.json`).
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
      "evidence": "2+ years building production apps with Flutter and Dart." },
    { "id": "…", "skill_id": "…", "name": "Dart", "category": "Languages", "required": true, "min_years": 2, "weight": 2,
      "evidence": "2+ years building production apps with Flutter and Dart." },
    { "id": "…", "skill_id": "…", "name": "State Management", "category": "Domain", "required": true, "min_years": 0, "weight": 2,
      "evidence": "Experience with a state management approach (Riverpod or Bloc)." },
    { "id": "…", "skill_id": "…", "name": "REST APIs", "category": "Tools", "required": true, "min_years": 0, "weight": 2,
      "evidence": "Experience consuming REST APIs." },
    { "id": "…", "skill_id": "…", "name": "Git", "category": "Tools", "required": true, "min_years": 0, "weight": 2,
      "evidence": "Comfortable with Git and code review." },
    { "id": "…", "skill_id": "…", "name": "Code Review", "category": "Domain", "required": true, "min_years": 0, "weight": 2,
      "evidence": "Comfortable with Git and code review." },
    { "id": "…", "skill_id": "…", "name": "Firebase", "category": "Cloud/DevOps", "required": false, "min_years": 0, "weight": 1,
      "evidence": "Firebase (Auth, Firestore, push notifications)." },
    { "id": "…", "skill_id": "…", "name": "Riverpod", "category": "Frameworks", "required": false, "min_years": 0, "weight": 1,
      "evidence": "Own state management with Riverpod and keep our offline-first appointment cache reliable." }
  ],
  "unmapped": [
    { "raw": "WCAG audits", "required_hint": "preferred", "min_years": null, "evidence": "…" }
  ]
}
```
- `requirements` are already saved as draft `job_requirements` rows (weight 2 if required, 1 if preferred), at most 15 total and 8 required. The full fixture has 15. This example is shortened.
- `min_years` is `0` when the description doesn't state a minimum.
- `unmapped` lists skills the AI found that aren't in the taxonomy. They aren't saved, because only mapped skills can be scored. Show them so the recruiter can pick the closest skill or ignore them.
- Job fields are only pre-filled where the description states them. Otherwise they're `null`.

**Errors**

| HTTP | `code` | When |
|---|---|---|
| 401 | `unauthorized` | Missing or invalid JWT |
| 403 | `not_company_recruiter` | Caller isn't a recruiter in the job's company |
| 404 | `job_not_found` | No such `job_id` |
| 409 | `job_not_draft` | Job is already published (use `save_requirements` to edit) |
| 200 | (`parse_status: "FAILED"`, `failure_reason`) | Same reasons as `parse-resume`, except `unreadable_scan` |

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
**Gaps:** entries with `matched_via = "none"`. Required gaps cost 15 points each.

---

## 5. `compute_match` (RPC)

```sql
compute_match(p_profile_version_id uuid, p_job_id uuid) returns jsonb  -- stable
```
**Caller:** other RPCs (`swipe`, `get_feed`, `save_requirements`) and the seed. The app doesn't call it directly.
**Formula:** PRD §8.4 (`scoring_version` 1).

**Example:** the default mock resume (`default.resume.json`, Flutter developer, years as of Oct 2026) against job01. Score **76**, band `Good`.
```json
{
  "score": 76,
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
Check: raw = (6 × 2 × 1.0 + 4 × 1 × 1.0) / (6 × 2 + 9 × 1) = 16 / 21 = 0.762. No required gaps, so the penalty is 0. round(76.2) = **76**.

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
      "match_score": 76,
      "band": "Good",
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
- `next_cursor` is **opaque**. Pass it back unchanged. It's `null` when there are no more cards.
- An empty `cards` array with `next_cursor: null` means the deck is empty (show the empty state).

**Errors:** `not_candidate`, `profile_not_confirmed` (send the user to onboarding), `invalid_cursor`.
