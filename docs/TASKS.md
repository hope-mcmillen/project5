# ResuRhombus: Tasks by Person

**Companion to:** [TEAM_PLAN.md](TEAM_PLAN.md) (roles, rules) · [SCHEMA.md](SCHEMA.md) + [schema.sql](schema.sql) (database) · [USER_STORIES.md](USER_STORIES.md) · [PRD.md](PRD.md)

**How to read this**
- **Work order:** Each person works **top to bottom** through **Core**. **Later** holds features to add once the core works. New features get a story in USER_STORIES.md first, then a task in the owner's Later list.
- **Task fields:**
  - **Title:** an action-style name you can paste straight into a GitHub issue title, e.g. `[PL-18] Build the swipe, undo, and daily apply cap functions`.
  - **Build:** the technical work.
  - **Enables:** what can be done once it's merged.
  - **Needs:** what must exist before it can use real data. Until then, build against the fake (frontend) or mock (AI).
  - **Size:** S is half a day or less, M is about 1 day, L is about 2 days.
- **Task IDs** are stable references, also used in the scaffold pages and USER_STORIES.md. The section a task is in tells you its owner, not its prefix.

| Person | Silo | Core tasks | Later |
|---|---|---|---|
| [A](#person-a-backend-database--api) | Backend: database & API | 19 | 3 |
| [B](#person-b-backend-ai--matching) | Backend: AI & matching | 19 | 2 |
| [C](#person-c-frontend-candidate-app--design-system) | Frontend: candidate app + design system | 22 | 4 |
| [D](#person-d-frontend-recruiter-app--auth--routing) | Frontend: recruiter app + auth & routing | 23 | 3 |
| [Everyone](#everyone) | Shared checkpoints | 4 | — |

---

## Task index
Every task by person, in work order. Full technical details for each task are in the person sections below.

### A · Backend (database & API)

| ID | Title | Size | List |
|---|---|---|---|
| PL-01 | Set up the Supabase project and local backend | S | Core |
| PL-03 | Set up the GitHub board, PR rules, CI, and CODEOWNERS | S | Core |
| PL-04 | Create the identity and company tables with RLS | M | Core |
| PL-05 | Create the candidate, resume, and skill tables with RLS | M | Core |
| PL-06 | Create the job, swipe, and application tables with RLS | M | Core |
| PL-27 | Write the API contract for every backend function | M | Core |
| PL-07 | Create user profiles automatically on sign-up | S | Core |
| PL-08 | Add the role helper and refactor role-based policies | S | Core |
| PL-12 | Test account and company access rules | M | Core |
| PL-13 | Build company create, invite, and join functions | M | Core |
| PL-14 | Create the resume and company logo storage buckets | S | Core |
| PL-17 | Build the confirm-profile and save-preferences functions | S | Core |
| PL-16 | Seed the database with skills, companies, and demo accounts | M | Core |
| PL-18 | Build the swipe, undo, and daily apply cap functions | M | Core |
| PL-19 | Build the application status change functions | M | Core |
| AI-16 | Build the blind applicant board and candidate detail functions | M | Core |
| PL-20 | Test the swipe and status rules | M | Core |
| PL-21 | Enable live updates for resumes, applications, and jobs | S | Core |
| PL-23 | Build the secure resume download link function | S | Core |
| PL-25 | Write the README for local setup and demo accounts | S | Core |
| PL-26 | Verify companies by email domain | S | Later |
| PL-22 | Send push notifications on status changes | M | Later |
| PL-24 | Build the delete-account function | M | Later |

### B · Backend (AI & matching)

| ID | Title | Size | List |
|---|---|---|---|
| AI-01 | Build the skill taxonomy and related-skill list | M | Core |
| AI-02 | Define the resume and job extraction schemas | M | Core |
| AI-03 | Build the LLM adapter with a free mock provider | M | Core |
| AI-04 | Create fake resumes and job descriptions for testing | M | Core |
| PL-27 | Write the API contract for every backend function | M | Core |
| AI-05 | Build the Document Intelligence client | M | Core |
| AI-06 | Sanitize resume text before it reaches the AI | S | Core |
| AI-08 | Calculate years of experience and verify skill evidence | M | Core |
| AI-07 | Build the resume parsing function | L | Core |
| AI-09 | Add the OpenAI and Azure OpenAI providers | M | Core |
| AI-13 | Log AI usage and enforce the daily token budget | S | Core |
| AI-10 | Match extracted skills to the skill taxonomy | M | Core |
| AI-11 | Precompute skill embeddings for the seed data | S | Core |
| AI-12 | Build the job description parsing function | M | Core |
| AI-14 | Build the Match Score calculation | L | Core |
| AI-15 | Build the ranked candidate job feed | L | Core |
| AI-17 | Add a scoring regression test with labeled examples | M | Core |
| AI-19 | Test that resumes can't manipulate the AI | S | Core |
| AI-20 | Generate realistic demo data for every status and score band | L | Core |
| AI-18 | Re-score applicants when job requirements change | M | Later |
| AI-21 | Measure and tune AI extraction accuracy | M | Later |

### C · Frontend (candidate app + design system)

| ID | Title | Size | List |
|---|---|---|---|
| CA-01 | Create the shared Dart data models | M | Core |
| CA-02 | Create candidate repositories with fake data | M | Core |
| RC-01 | Build the app theme from the design tokens | M | Core |
| RC-02 | Build the shared UI components and gallery | M | Core |
| CA-03 | Build the resume upload screen | M | Core |
| CA-04 | Build the resume parsing progress screen | M | Core |
| CA-05a | Build the skill review list with years editing | M | Core |
| CA-05b | Add skill add, remove, and evidence views to review | M | Core |
| CA-06 | Build the job preferences screen | M | Core |
| CA-07 | Connect resume upload and progress to the backend | M | Core |
| CA-08 | Connect skill review and preferences to the backend | M | Core |
| CA-09 | Handle parse failures with a manual skill fallback | S | Core |
| CA-10 | Build the job card widget | M | Core |
| CA-11 | Build the swipe deck | L | Core |
| CA-12 | Add apply/pass buttons and the undo toast | M | Core |
| CA-13 | Add optional pass reason chips | S | Core |
| CA-15 | Build the empty deck state | S | Core |
| CA-14 | Connect the swipe deck to the live feed | M | Core |
| CA-16 | Build the radar chart match details view | L | Core |
| CA-17 | Build the applications pipeline screen | M | Core |
| CA-18 | Show recruiter contact info for interview requests | S | Core |
| CA-21 | Run the candidate accessibility and performance pass | M | Core |
| CA-19 | Warn before applying to low-match jobs | S | Later |
| CA-20 | Add the animated geometric background | M | Later |
| CA-22 | Queue swipes made offline and sync them later | M | Later |
| CA-23 | Build the delete account screen | S | Later |

### D · Frontend (recruiter app + auth & routing)

| ID | Title | Size | List |
|---|---|---|---|
| PL-02 | Connect the Flutter app to Supabase and Riverpod | S | Core |
| RC-03 | Create recruiter and auth repositories with fake data | S | Core |
| RC-04 | Create wireframes for every screen | M | Core |
| PL-09 | Build real sign-up, sign-in, and password reset | M | Core |
| PL-10 | Build the welcome, role choice, and sign-in screens | M | Core |
| PL-11 | Replace fake routing with real auth-based routing | M | Core |
| RC-05 | Build the responsive recruiter navigation shell | M | Core |
| RC-07 | Build the company create and join screens | M | Core |
| PL-15 | Connect company screens to the backend | M | Core |
| RC-18 | Build company settings with invite code management | S | Core |
| RC-06 | Build the recruiter jobs list | M | Core |
| RC-08 | Build the paste-job-description screen | M | Core |
| RC-09a | Build the requirement editor table | M | Core |
| RC-09b | Add requirement limits, skill search, and evidence highlights | M | Core |
| RC-10 | Build the job details form | M | Core |
| RC-11 | Connect jobs to the backend with publish, pause, and close | M | Core |
| RC-12 | Build the Mosaic grid of blind candidate tiles | L | Core |
| RC-13 | Add advance and reject triangle actions to tiles | M | Core |
| RC-14 | Connect the applicant board to the backend with live updates | M | Core |
| RC-15 | Build the recruiter candidate detail view | M | Core |
| RC-16 | Build the interview list with resume links | M | Core |
| RC-20 | Run the recruiter accessibility and responsive pass | M | Core |
| RC-21 | Build and host the recruiter web app | S | Core |
| RC-17 | Add applicant board filters | M | Later |
| RC-19 | Add keyboard shortcuts for board triage | M | Later |
| RC-22 | Show the verified badge in the recruiter header | S | Later |

### All · Everyone

| ID | Title |
|---|---|
| ALL-01 | Review and freeze the API contract as a team |
| ALL-02 | Test the full candidate-to-recruiter loop together |
| ALL-03 | Run a cross-team bug bash |
| ALL-04 | Rehearse the demo |

---

## Person A: Backend (database & API)

Folders: `supabase/migrations/`, `supabase/tests/`, `supabase/seed.sql`, non-AI Edge Functions. Skill: `resurhombus-supabase`.

### Core

#### PL-01 · Supabase project setup · S
**Title:** Set up the Supabase project and local backend

**Build:**
- Install the Supabase CLI and run `supabase init`. Commit `supabase/config.toml`.
- In `config.toml`, enable the Email and Google auth providers. Set `site_url` and the redirect URLs (`http://localhost:*`, `io.resurhombus.app://login-callback`).
- Create the hosted dev project and share its URL and anon key privately.
- Add `supabase/functions/.env` to `.gitignore`.

**Enables:** `supabase start` runs Postgres, Auth, Storage, Realtime, and Studio locally for everyone.
**Needs:** — · **Stories:** —

#### PL-03 · Repo & CI setup · S
**Title:** Set up the GitHub board, PR rules, CI, and CODEOWNERS

**Build:**
- Create a GitHub Project board with the columns To do / In progress / In review / Done.
- Add labels `owner:A..D` and `story:US-xx`, plus `.github/pull_request_template.md` (task ID, stories, test notes).
- Turn on branch protection for `master`: require 1 review and green CI.
- Add `flutter analyze` and the `supabase db reset` + `supabase test db` steps to `.github/workflows`.
- Add `.github/CODEOWNERS` (template in TEAM_PLAN §1).

**Enables:** Every task becomes an issue, PRs auto-request the right reviewer, and broken code can't merge.
**Needs:** — · **Stories:** —

#### PL-04 · Migration: identity & companies · M
**Title:** Create the identity and company tables with RLS

**Build:**
- `supabase migration new identity_companies`.
- From [schema.sql](schema.sql), copy the enum types, `touch_updated_at()`, `profiles`, `companies`, `recruiters`, `company_invites`, and `app_config`.
- Write the RLS policies for these tables per [SCHEMA.md §4](SCHEMA.md#4-row-level-security-summary). Profiles are self-only, and `role` can't be changed by update (compare it in a `with check` or use a trigger).

**Enables:** Users, roles, companies, and invite codes can be stored safely.
**Needs:** PL-01 · **Stories:** US-01, US-30

#### PL-05 · Migration: candidates & skills · M
**Title:** Create the candidate, resume, and skill tables with RLS

**Build:**
- Create `vector` and `pgcrypto` in the `extensions` schema.
- Add `skills` (GIN index on aliases, HNSW index on embedding), `skill_relations`, `candidates`, `resumes`, `profile_versions`, `candidate_skills`, and the circular `active_version_id` foreign key.
- RLS: candidates have owner-only access, recruiters have **none**, and skills are readable by everyone.

**Enables:** Resumes, versioned profiles, and the skill taxonomy have a home.
**Needs:** PL-04 · **Stories:** US-07, US-09, US-13

#### PL-06 · Migration: jobs & the loop · M
**Title:** Create the job, swipe, and application tables with RLS

**Build:**
- Add `jobs`, `job_requirements`, `swipes`, `applications`, `application_reject_reasons`, `status_events`, `llm_usage`, and `device_tokens`.
- Add the `company_jobs_overview` and `my_applications` views (`security_invoker`).
- RLS:
  - Candidates can read jobs that are `OPEN` **or** that they've applied to.
  - Recruiters can read applications for their own company's jobs where `committed_at <= now()`.
  - Reject reasons are recruiter-only.

**Enables:** Jobs, swipes, applications, and a full status history can be stored.
**Needs:** PL-05 · **Stories:** US-14, US-25, US-38

#### PL-27 · API contract (with B) · M
**Title:** Write the API contract for every backend function

**Build:** Write `docs/API_CONTRACT.md`. For every RPC and Edge Function in [SCHEMA.md §5](SCHEMA.md#5-functions-the-api-surface), include:
- the exact parameter names and types
- one realistic example response as JSON
- the error codes (`P0001` messages such as `daily_cap_reached`)
- who can call it

A writes the database and status RPCs. B writes `get_feed`, `compute_match`, `parse-*`, and the `breakdown` shape.

**Enables:** C and D build fake repositories that return exactly these examples, so every screen can be finished before the backend.
**Needs:** PL-04..06, AI-02 · **Stories:** US-55

#### PL-07 · Sign-up trigger · S
**Title:** Create user profiles automatically on sign-up

**Build:**
- Write `handle_new_user()` as `security definer`, run `after insert on auth.users`.
- It inserts into `profiles` with `role` from `raw_user_meta_data->>'role'` only when that value is `candidate` or `recruiter`. Otherwise it leaves `role` null and never raises an error (Google sign-in may have no metadata).
- When the role is `candidate`, it also inserts a `candidates` row.
- Add `set_initial_role(p_role)`. It only works when `role is null`, and it creates the `candidates` row if needed.

**Enables:** Signing up automatically sets up the right kind of account. Nobody can make themselves an admin.
**Needs:** PL-04, PL-05 · **Stories:** US-01, US-02

#### PL-08 · Role helper · S
**Title:** Add the role helper and refactor role-based policies

**Build:**
- Write `current_app_role()` as `stable security definer set search_path = public`, returning `profiles.role` for `auth.uid()`.
- Refactor the policies to use it, wrapping `(select auth.uid())` so it's evaluated once per query.
- Add a `my_company_id()` helper in the same style.

**Enables:** Consistent, fast role and company checks in every policy and RPC.
**Needs:** PL-07 · **Stories:** US-06

#### PL-12 · RLS tests: accounts & companies · M
**Title:** Test account and company access rules

**Build:**
- Write pgTAP tests in `supabase/tests/rls_identity.test.sql`.
- Create 2 candidates, 2 recruiters in different companies, and an anon user using `set local role` plus `request.jwt.claims`.
- Assert:
  - users can select and update their own profile only
  - role changes are blocked
  - companies are readable by everyone but only updatable by the owner
- Run with `supabase test db`.

**Enables:** Proof that accounts are isolated. Regressions get caught in CI.
**Needs:** PL-08 · **Stories:** US-06

#### PL-13 · Company RPCs · M
**Title:** Build company create, invite, and join functions

**Build:**
- `create_company(p_name, p_website)`: the role must be recruiter with no existing company. Inserts the company and a `recruiters(owner)` row, and sets `verified` (see PL-26, a simple version is OK).
- `create_invite(p_expires_in_days)`: owner only. Generates the code from `gen_random_bytes` mapped onto the unambiguous alphabet, retrying on collision.
- `join_company(p_code)`: locks the invite with `select … for update`, checks that it isn't expired or revoked and `uses < max_uses`, inserts a `member` row, and increments `uses`.
- `revoke_invite(p_code)`.
- Add pgTAP tests.

**Enables:** Recruiters create company workspaces, owners invite teammates, and teammates join by code.
**Needs:** PL-08 · **Stories:** US-30, US-31, US-32

#### PL-14 · Storage buckets · S
**Title:** Create the resume and company logo storage buckets

**Build:**
- A migration that inserts into `storage.buckets`:
  - private `resumes`: `file_size_limit` 5 MB, `allowed_mime_types` PDF and DOCX
  - public `company-logos`
- Policies on `storage.objects`:
  - `resumes`: `(storage.foldername(name))[1] = auth.uid()::text` for select and insert
  - logos: write only if the caller owns that company
- Add a test that a user can't read another user's folder.

**Enables:** Candidates upload resumes only they can access, and companies get logos.
**Needs:** PL-07 · **Stories:** US-07, US-49

#### PL-17 · Profile RPCs · S
**Title:** Build the confirm-profile and save-preferences functions

**Build:**
- `confirm_profile(p_version_id, p_skills jsonb)` in one transaction:
  - checks ownership
  - replaces the version's `candidate_skills` with the submitted list, setting `source = 'user'` for edited rows
  - sets `confirmed = true`, `confirmed_at`, and `total_years`
  - sets `candidates.active_version_id`
  - The profile embedding is filled in by B's `parse-resume` / `embed` helper.
- `create_manual_profile()`: creates an empty version with `source = 'manual'`.
- `save_preferences(p_prefs)`: validates keys and types against the [SCHEMA.md §6](SCHEMA.md#6-json-shapes) shape and rejects unknown keys.

**Enables:** Candidates lock in their reviewed skills and job filters. Swiping requires a confirmed profile.
**Needs:** PL-05 · **Stories:** US-09, US-11, US-12

#### PL-16 · Seed v1 · M
**Title:** Seed the database with skills, companies, and demo accounts

**Build:**
- In `supabase/seed.sql`:
  - import the taxonomy from AI-01's CSV, with embeddings from AI-11 as `'[…]'::vector` literals
  - insert 3 companies, one verified
  - insert demo users into `auth.users` (`crypt(password, gen_salt('bf'))`, `email_confirmed_at = now()`) and matching `auth.identities` rows
- Every row has `is_seed = true`.
- Write the demo credentials only in the README's local-dev section.

**Enables:** `supabase db reset` gives everyone working demo logins and real skills.
**Needs:** AI-01, AI-11, PL-13 · **Stories:** US-54

#### PL-18 · Swipe RPCs · M
**Title:** Build the swipe, undo, and daily apply cap functions

**Build:**
- `swipe(p_job_id, p_direction, p_reason)`:
  1. Checks the role is candidate, the profile is confirmed (`profile_not_confirmed`), and the job is `OPEN` (`job_not_open`).
  2. For a right swipe, counts today's right swipes against `app_config.daily_apply_cap` (`daily_cap_reached`).
  3. Inserts the `swipes` row.
  4. For a right swipe, calls B's `compute_match` and inserts the `applications` row with `committed_at = now() + undo_seconds`, plus a `status_events` row.
  5. Returns `{swipe_id, application_id, committed_at}`.
- `undo_swipe(p_swipe_id)`: deletes only while `now() < committed_at` (`undo_window_expired`).
- `set_pass_reason(p_swipe_id, p_reason)`.

**Enables:** Candidates apply and pass. Accidental applies can be undone, and the 25-per-day cap holds.
**Needs:** PL-06, AI-14 (use a stub `compute_match` returning 50 until it lands) · **Stories:** US-15, US-16, US-17, US-21

#### PL-19 · Status RPCs · M
**Title:** Build the application status change functions

**Build:**
- `open_application`, `advance(p_note)`, `reject(p_reason)`, `undo_reject`, and `withdraw`.
- Each one:
  - locks the row
  - checks the caller (recruiter of the job's company, or the owning candidate)
  - validates the transition against the table in [SCHEMA.md §3](SCHEMA.md#3-enum-types)
  - writes `previous_status`, `rejected_at`, or `advanced_by` as needed
  - inserts a `status_events` row
- `reject` writes its reason to `application_reject_reasons`.
- `get_application_contact` returns recruiter info only when the status is INTERVIEW_REQUESTED.

**Enables:** Recruiters advance or reject (with undo), candidates withdraw, and invalid status jumps are impossible.
**Needs:** PL-06 · **Stories:** US-28, US-29, US-42, US-43, US-44

#### AI-16 · Blind board RPCs · M
**Title:** Build the blind applicant board and candidate detail functions

**Build:**
- `get_board(p_job_id, p_filters, p_limit, p_offset)`:
  - checks own company
  - selects committed, non-terminal applications ordered by `match_score desc, committed_at asc`
  - builds tile JSON ([SCHEMA.md §6](SCHEMA.md#6-json-shapes)) using only safe fields. `handle` = `'◆ ' || upper(substr(md5(id::text), 1, 4))`. Top skills and gaps come from `breakdown`.
- `get_candidate_detail(p_application_id)`: the tile plus the full `breakdown` and each skill's evidence. Identity (`display_name`, email) is included only at INTERVIEW_REQUESTED.
- `get_interview_list(p_job_id)`.
- Add a test that the JSON keys are exactly the allowed set.

**Enables:** Recruiters see applicants ranked by score with no names or photos, enforced in the database.
**Needs:** PL-19, AI-14 · **Stories:** US-40, US-41, US-47

#### PL-20 · RLS & rules tests: the loop · M
**Title:** Test the swipe and status rules

**Build:** pgTAP tests asserting that:
- the 26th right swipe raises `daily_cap_reached`
- `undo_swipe` fails after the window (simulate with an `update … set committed_at = now() - interval '1s'`)
- every invalid transition raises
- recruiter B can't read or advance company A's applications
- candidates can't read `application_reject_reasons`

**Enables:** Proof the core loop's rules hold, guarded in CI.
**Needs:** PL-18, PL-19, AI-16 · **Stories:** US-06, US-21

#### PL-21 · Realtime · S
**Title:** Enable live updates for resumes, applications, and jobs

**Build:**
- Make sure the migration includes `alter publication supabase_realtime add table resumes, applications, jobs`.
- Test with two signed-in clients in Studio that a candidate only receives their own application changes.

**Enables:** Parse progress, pipeline statuses, and new applicants update live in the app.
**Needs:** PL-19 · **Stories:** US-08, US-26

#### PL-23 · `resume-url` Edge Function · S
**Title:** Build the secure resume download link function

**Build:**
- Write `supabase/functions/resume-url/index.ts` (Deno).
- Verify the JWT, then use a user-scoped client to confirm the caller is a recruiter of the application's company and the status is INTERVIEW_REQUESTED.
- Use an admin client to run `storage.from('resumes').createSignedUrl(path, 600)` and return `{url}`.

**Enables:** Recruiters open a candidate's resume only after advancing them.
**Needs:** PL-14, PL-19 · **Stories:** US-47, US-49

#### PL-25 · README · S
**Title:** Write the README for local setup and demo accounts

**Build:**
- Rewrite `README.md` covering the prerequisites (Flutter, Supabase CLI), `supabase start`, copying `env/example.json` to `env/dev.json`, the emulator URL `http://10.0.2.2:54321`, and `flutter run` / `-d chrome`.
- Include the demo accounts, how to switch `LLM_PROVIDER`, and how to run the tests.

**Enables:** A new teammate or grader can run everything from the README alone.
**Needs:** PL-16 · **Stories:** —

### Later

#### PL-26 · Verified company badge · S
**Title:** Verify companies by email domain

**Build:** In `create_company`, compare `split_part(auth.email(), '@', 2)` with the host of `website` (lowercased, `www.` stripped), using a free-mail denylist (gmail.com, outlook.com, yahoo.com, …). Expose `verified` in feed cards.
**Enables:** Candidates can tell verified companies from unverified ones.
**Needs:** PL-13 · **Stories:** US-33

#### PL-22 · Push notifications · M
**Title:** Send push notifications on status changes

**Build:**
- `register_device(p_token, p_platform)`.
- A database webhook on `status_events` insert (to_status INTERVIEW_REQUESTED / NOT_SELECTED) calls the `notify` Edge Function.
- `notify` sends through the FCM HTTP v1 API using a service-account JSON stored in function secrets.

**Enables:** Candidates get a phone notification with the app closed.
**Needs:** PL-21 · **Stories:** US-27

#### PL-24 · `delete-account` Edge Function · M
**Title:** Build the delete-account function

**Build:** With an admin client:
1. Delete `resumes/{uid}/*` from Storage.
2. Update the candidate's applications to `anonymized = true`, with `candidate_id` and `profile_version_id` null.
3. Delete the candidate rows.
4. Call `auth.admin.deleteUser(uid)`, which cascades to `profiles`.

Add an integration test that no rows remain.
**Enables:** Candidates permanently delete their data.
**Needs:** PL-19 · **Stories:** US-50

---

## Person B: Backend (AI & matching)

Folders: `supabase/functions/parse-resume`, `parse-job`, `_shared/`, the scoring SQL migrations, `scripts/`. Skill: `resurhombus-matching`.

### Core

#### AI-01 · Skill taxonomy · M
**Title:** Build the skill taxonomy and related-skill list

**Build:**
- Write `supabase/seed/skills.csv` with about 300 rows (`name, category, aliases`), using categories from [SCHEMA.md](SCHEMA.md) (Languages, Frameworks, Data, Cloud/DevOps, Tools, Domain) and lowercase, `|`-separated aliases.
- Write `skill_relations.csv` with about 80 rows (`skill, related, credit`).
- Cover the stacks in the fake job descriptions (mobile/Flutter, backend/Python, data, DevOps, frontend).

**Enables:** "ReactJS" and "React" count as the same skill, and related skills get partial credit.
**Needs:** — · **Stories:** US-14

#### AI-02 · Extraction schemas · M
**Title:** Define the resume and job extraction schemas

**Build:**
- In `supabase/functions/_shared/schemas.ts`, write JSON Schemas for `resume` and `job` that follow the OpenAI strict rules (every property listed in `required`, `additionalProperties: false`, `["string","null"]` for optional values).
- Write matching Zod validators.
- Export `EXTRACTION_SCHEMA_VERSION`.
- The resume schema has **no** name, contact, age, or graduation-year fields.

**Enables:** Defines exactly what the AI may return. Personal traits are impossible by construction.
**Needs:** — · **Stories:** US-51

#### AI-03 · LLM adapter + mock · M
**Title:** Build the LLM adapter with a free mock provider

**Build:**
- In `_shared/llm.ts`, define the `LlmProvider` interface with `extract<T>({schemaName, schema, system, untrustedText})` and `embed(texts)`.
- `getProvider()` reads `LLM_PROVIDER`.
- `MockProvider`:
  - `extract` returns `_shared/fixtures/extract/<sha256(text)>.json`, or a default fixture
  - `embed` returns deterministic unit vectors seeded from a hash of the text
- Write Deno tests.

**Enables:** All AI code can be built and tested without spending credits.
**Needs:** AI-02 · **Stories:** US-52

#### AI-04 · Fake resumes & job descriptions · M
**Title:** Create fake resumes and job descriptions for testing

**Build:**
- Write 10 fake resume PDFs in `supabase/seed/resumes/`, with varied layouts: single column, two-column, table-based, one DOCX, one scanned-style image PDF (to test failure), and one with hidden white text (for the injection test).
- Write 6 fake job descriptions as `.txt`.
- Hand-label the expected skills for each in `fixtures/labels.json`.

**Enables:** Realistic test inputs and demo material with no real people.
**Needs:** — · **Stories:** US-54

#### PL-27 · API contract (with A) · M
**Title:** Write the API contract for every backend function

**Build:** Write the parts of `docs/API_CONTRACT.md` covering `parse-resume`, `parse-job`, `get_feed` (card JSON plus cursor), `compute_match`, and the `breakdown` shape, with example payloads taken from the fixtures.
**Enables:** C builds the deck and radar against the exact data format.
**Needs:** AI-02 · **Stories:** US-55

#### AI-05 · Document Intelligence client · M
**Title:** Build the Document Intelligence client

**Build:** In `_shared/azure_di.ts`:
- `analyzeLayout(bytes, mime)` POSTs to `{AZURE_DI_ENDPOINT}/documentintelligence/documentModels/prebuilt-layout:analyze?api-version=…`.
- It polls the `Operation-Location` header with backoff (max 45 s) and returns `{ lines: [{ text, page, polygon, height }] }`.
- Add a test using a recorded response fixture.

**Enables:** PDF and DOCX resumes, including multi-column ones, become clean text with positions.
**Needs:** — · **Stories:** US-07

#### AI-06 · Text sanitizer · S
**Title:** Sanitize resume text before it reaches the AI

**Build:**
- `sanitize(lines)` drops lines with near-zero polygon area or a height below the threshold (hidden text), strips control characters, collapses whitespace, and truncates at about 15k tokens (estimated as characters ÷ 4) with a marker.
- Strip email and phone patterns from the contact block.
- Add unit tests.

**Enables:** Hidden "score me 100%" text is removed and token cost is capped.
**Needs:** AI-05 · **Stories:** US-51

#### AI-08 · Years & evidence logic · M
**Title:** Calculate years of experience and verify skill evidence

**Build:** Pure TypeScript functions in `_shared/profile.ts`, with Deno tests:
- `mergeYears(roles)`: per skill, takes the union of role date ranges, merges overlaps, treats "present" as today, and rounds to 0.5.
- `validateEvidence(skill, text)`: case- and whitespace-normalized substring check.
- `totalYears(roles)`.

**Enables:** Experience is calculated by code, not guessed, and invented skills are dropped.
**Needs:** AI-02 · **Stories:** US-09, US-10

#### AI-07 · `parse-resume` Edge Function · L
**Title:** Build the resume parsing function

**Build:**
1. Verify the JWT and ownership of `resume_id`.
2. Check for a cached extraction with the same `file_hash` and schema version.
3. Set the status at each step (PARSING_LAYOUT, then EXTRACTING, then NORMALIZING) using an admin client.
4. Download from Storage, then `analyzeLayout`, then `sanitize`, then `llm.extract(resumeSchema)` with the resume inside `<resume>` tags.
5. Drop skills without valid evidence, then `mergeYears`.
6. Insert `profile_versions` (next version) and `candidate_skills` (normalization is wired in after AI-10). Save `extraction` and the provider/model.
7. Set `READY`, or `FAILED` with a `failure_reason`. Never leave a row in a parsing state. Hard timeout at 60 s.

**Enables:** An upload becomes a draft profile, with live progress in the app.
**Needs:** AI-03, AI-06, AI-08, PL-05 · **Stories:** US-07, US-08, US-11

#### AI-09 · Real providers · M
**Title:** Add the OpenAI and Azure OpenAI providers

**Build:**
- `OpenAIProvider`: `new OpenAI({apiKey})`.
- `AzureOpenAIProvider`: `new AzureOpenAI({endpoint, apiKey, apiVersion, deployment})`.
- Both come from `npm:openai` and use `chat.completions.create` with `response_format: {type: 'json_schema', json_schema: {name, schema, strict: true}}` and temperature 0, plus `embeddings.create({model: LLM_EMBED_MODEL})`.
- Assert the embedding model is `text-embedding-3-small`.

**Enables:** Real AI works, and switching between OpenAI and Azure is one setting.
**Needs:** AI-03 · **Stories:** US-53

#### AI-13 · Usage log & budget guard · S
**Title:** Log AI usage and enforce the daily token budget

**Build:**
- Wrap every provider call to insert into `llm_usage`.
- Before each call, sum today's tokens. If the total is at or above `LLM_DAILY_TOKEN_BUDGET`, throw `BudgetExceeded`, which `parse-*` turns into `FAILED` with `budget_exceeded`.

**Enables:** Spend is visible, and parsing stops cleanly before credits run out.
**Needs:** AI-09, PL-06 · **Stories:** US-53

#### AI-10 · Skill normalization · M
**Title:** Match extracted skills to the skill taxonomy

**Build:**
- Migration: `match_skills(p_embedding, p_threshold, p_k)` returns `skill_id` and similarity, using `1 - (embedding <=> p_embedding)` ordered by distance.
- `_shared/normalize.ts`:
  1. lowercase exact or alias match (`aliases @> array[x]`)
  2. otherwise, batch-embed the unmatched strings, then `match_skills` with a threshold of 0.88
  3. otherwise, `skill_id = null` (unmapped)
- Wire it into `parse-resume`.

**Enables:** Free-text skills map onto the taxonomy, so candidates and jobs can be compared.
**Needs:** AI-09, PL-05 · **Stories:** US-14

#### AI-11 · Precompute taxonomy embeddings · S
**Title:** Precompute skill embeddings for the seed data

**Build:** `scripts/embed_taxonomy.ts` (Deno) reads `skills.csv`, embeds `name + aliases` in batches of 100, and writes `supabase/seed/skills_embeddings.sql` with vector literals. Run it once and commit the output.
**Enables:** Seeding and local development never call the AI for embeddings.
**Needs:** AI-09, AI-01 · **Stories:** US-54

#### AI-12 · `parse-job` Edge Function · M
**Title:** Build the job description parsing function

**Build:**
1. Verify the JWT and that the caller is a recruiter of the job's company.
2. Sanitize `raw_description`, then `llm.extract(jobSchema)`. The output has title, requirements with `required_hint` / `min_years` / evidence, and location, remote, and salary if stated.
3. Normalize the requirement skills. Unmapped ones are returned in the response as `unmapped[]` so the UI can show them.
4. Insert draft `job_requirements` (weight 2 if required, 1 if preferred) and pre-fill the job fields.
5. Set `parse_status = READY`.

**Enables:** Recruiters paste a job description and get draft requirements automatically.
**Needs:** AI-09, AI-10, PL-06 · **Stories:** US-34

#### AI-14 · `compute_match()` · L
**Title:** Build the Match Score calculation

**Build:** Migration with a SQL function implementing PRD §8.4:
- For each requirement:
  - `coverage` is 1 for an exact match, else the best `skill_relations.credit`, else 0
  - `depth = min(1, years / min_years)` (1 if `min_years` is 0, 0.5 if years is null)
  - `score = coverage × (0.6 + 0.4 × depth)`
- `raw` is the weighted average of the scores.
- The penalty is 0.15 per missing required skill.
- `score = round(100 × clamp(raw − penalty, 0, 1))`.
- Returns `{score, breakdown}` ([SCHEMA.md §6](SCHEMA.md#6-json-shapes)).
- Mark it `stable`.

**Enables:** Every candidate-job pair gets an explainable 0–100 score, plus the per-skill data behind the radar.
**Needs:** AI-10 · **Stories:** US-14, US-23

#### AI-15 · `get_feed()` · L
**Title:** Build the ranked candidate job feed

**Build:** Migration for `get_feed(p_limit, p_cursor)` (security definer, scoped to `auth.uid()`):
1. Read the candidate's active version and preferences.
2. Hard filters: OPEN jobs, not already swiped, remote/type/sponsorship/salary compatible.
3. Vector prefilter: `order by jobs.embedding <=> pv.embedding limit 500`.
4. `compute_match` for each remaining job.
5. Feed Rank = `0.70·match + 0.15·freshness + 0.10·affinity + 0.05·exploration`. Affinity comes from pass-reason counts and exploration from a hash of the job id and today's date. Drop jobs with a score below 50 unless `include_stretch` is set.
6. Diversity: no more than 2 cards in a row from the same company.
7. Return cards plus `next_cursor = (rank, job_id)`.

**Enables:** Candidates get a deck of eligible jobs with the best matches first, loaded page by page.
**Needs:** AI-14 · **Stories:** US-12, US-14, US-17, US-20

#### AI-17 · Scoring regression test · M
**Title:** Add a scoring regression test with labeled examples

**Build:** `supabase/tests/fixtures/match_pairs.json` holds about 50 hand-labeled resume × job pairs with expected bands. A pgTAP or Deno test computes the scores and asserts band agreement of at least 80%, and prints a confusion table.
**Enables:** Any change to weights or the formula is checked against human judgment.
**Needs:** AI-14 · **Stories:** —

#### AI-19 · Prompt-injection tests · S
**Title:** Test that resumes can't manipulate the AI

**Build:** Deno tests run `parse-resume` (mock and, optionally, real) on the hidden-text fixture and on fixtures containing "ignore previous instructions" and "Age: 52". Assert that no extra skills appear, that no personal fields exist, and that the output validates against the schema.
**Enables:** Proof the AI can't be manipulated by a resume.
**Needs:** AI-07 · **Stories:** US-51

#### AI-20 · Seed generator · L
**Title:** Generate realistic demo data for every status and score band

**Build:**
- `scripts/generate_seed.ts` with a fixed random seed generates about 30 candidates.
  - Each candidate's skills are chosen to hit Strong, Good, Stretch, and Low bands against each of the 6 jobs.
- Also generate about 60 applications across **every** status (with matching `status_events`), about 150 swipes with pass reasons, and precomputed scores and embeddings.
- Write the output to `supabase/seed/demo_data.sql`, which PL-16 includes.

**Enables:** The demo has a full board and real pipelines from the first screen, with no live AI.
**Needs:** AI-14, PL-16 · **Stories:** US-54

### Later

#### AI-18 · Re-score on requirement edit · M
**Title:** Re-score applicants when job requirements change

**Build:** Inside `save_requirements` (with A), when the job is OPEN or PAUSED, run `update applications set (match_score, breakdown, scoring_version) = …compute_match(...)` for non-terminal rows, and set `jobs.rescored_at`. Add a test that changing a weight changes both the score and the order.
**Enables:** Editing a live job's requirements keeps the ranking fair.
**Needs:** AI-14 · **Stories:** US-39

#### AI-21 · Real-AI evaluation · M
**Title:** Measure and tune AI extraction accuracy

**Build:** `deno task eval:extract` runs real extraction on the AI-04 resumes, compares against the labels, and prints per-skill precision and recall. Sweep the normalization threshold (0.80–0.92) and pick the best. Ask the team before running, because it costs credits.
**Enables:** Measurably better extraction and skill matching.
**Needs:** AI-10 · **Stories:** —

---

## Person C: Frontend (candidate app + design system)

Folders: `lib/ui/`, `lib/core/models/`, `lib/features/{onboarding,deck,deep_dive,pipeline,profile}/`. Skills: `resurhombus-ui`, `resurhombus-flutter`. Each scaffold page lists the task IDs that replace it.

### Core

#### CA-01 · Dart models · M
**Title:** Create the shared Dart data models

**Build:**
- In `lib/core/models/`, add immutable classes with `fromJson` / `toJson` that map the snake_case columns from [SCHEMA.md](SCHEMA.md): `Profile`, `Skill`, `CandidateSkill`, `ProfileVersion`, `Preferences`, `JobCard`, `BreakdownItem`, `Application`, `StatusEvent`, `CandidateTile`.
- Add enums mirroring the Postgres enums (`ApplicationStatus`, `JobStatus`, `ResumeStatus`, `PassReason`, …) with `fromDb` / `toDb`.
- Add `ScoreBand.fromScore(int)`.
- Write unit tests that round-trip the contract examples.

**Enables:** Both frontends share one set of types that match the database.
**Needs:** PL-27 draft · **Stories:** —

#### CA-02 · Candidate repositories + fakes · M
**Title:** Create candidate repositories with fake data

**Build:**
- In `lib/features/*/data/`, add abstract `ProfileRepository`, `ResumeRepository`, `FeedRepository`, and `ApplicationRepository`.
- Add `Fake…` implementations backed by in-memory lists seeded from the contract JSON. They use a 300 ms delay and an error toggle.
- Add Riverpod providers, plus a `lib/main_fake.dart` that overrides them all.

**Enables:** Every candidate screen can be built and demoed before the backend exists.
**Needs:** CA-01, PL-02 · **Stories:** US-55

#### RC-01 · Theme · M
**Title:** Build the app theme from the design tokens

**Build:**
- Add `lib/ui/theme/rr_tokens.dart`, `rr_theme_ext.dart`, and `rr_theme.dart`, copied from `.claude/skills/resurhombus-ui/references/tokens-and-theme.md`.
- Add `google_fonts` (Space Grotesk and Inter).
- Replace the placeholder `ThemeData` in `lib/app/app.dart` (coordinate with D) and add the `context.rr` extension.

**Enables:** The whole app, both roles, gets the brand colors, type, and spacing from one source.
**Needs:** — · **Stories:** —

#### RC-02 · Shared components · M
**Title:** Build the shared UI components and gallery

**Build:**
- In `lib/ui/components/`:
  - `RhombusMark` (a `CustomPainter` with filled, outlined, and dashed variants)
  - `ScoreBadge` (3 sizes, with the band label and semantics)
  - `EmptyState`
  - `ShimmerShape`
  - `StatusChip`
  - `CompanyBadge`
- A `/dev/gallery` route (debug only) that shows each one.
- Golden tests for `ScoreBadge` and `StatusChip`.

**Enables:** Both apps reuse the same visual pieces, and the gallery lets anyone preview them.
**Needs:** RC-01 · **Stories:** —

#### CA-03 · Upload screen · M
**Title:** Build the resume upload screen

**Build:**
- Replace `UploadResumeScreen`'s placeholder.
- Use `file_picker` (`allowedExtensions: ['pdf','docx']`, `withData: true` so it works on web).
- Validate that the size is ≤ 5 MB, the extension, and the magic bytes (`%PDF` or the `PK` zip header).
- Compute a sha256 with the `crypto` package.
- Call `ResumeRepository.upload()` (fake for now) and navigate to `Routes.parseProgress(id)`.
- Show inline errors.

**Enables:** Candidates choose a resume and get clear feedback on bad files.
**Needs:** CA-02 · **Stories:** US-07

#### CA-04 · Prism progress · M
**Title:** Build the resume parsing progress screen

**Build:**
- `PrismUploadProgress` widget: a `CustomPainter` rhombus splitting a beam into the palette colors, with steps mapped from `ResumeStatus`.
- `ParseProgressScreen` uses `ref.watch(resumeStatusProvider(id))`, which is a fake stream for now.
- On READY it navigates to Review, and on FAILED it shows the error state.
- Respect `MediaQuery.disableAnimationsOf`.

**Enables:** Candidates see branded, live progress while their resume is read.
**Needs:** RC-01, CA-02 · **Stories:** US-08

#### CA-05a · Review skills: list & years · M
**Title:** Build the skill review list with years editing

**Build:**
- `ReviewController` (`AsyncNotifier`) loads the latest version and its skills.
- `SkillReviewList` rows have the name, a years stepper in 0.5 steps, and an "edited" badge when the row changes.
- The controller keeps edits locally until confirm.

**Enables:** Candidates check what the AI found and fix their years.
**Needs:** CA-02 · **Stories:** US-09

#### CA-05b · Review skills: add, remove, evidence · M
**Title:** Add skill add, remove, and evidence views to review

**Build:**
- Swipe-to-remove or an ✕ button on each row.
- "Add skill" opens a search sheet querying `skills` (`ilike` on name or aliases, limit 20) through the repository.
- An evidence bottom sheet shows the quote with the skill highlighted (`TextSpan`).
- A sticky "Looks right, continue" CTA.

**Enables:** Candidates fix mistakes, add missing skills, and see where each skill came from.
**Needs:** CA-05a · **Stories:** US-09, US-10

#### CA-06 · Preferences screen · M
**Title:** Build the job preferences screen

**Build:**
- Replace `PreferencesScreen`'s placeholder, which has an `editing` flag for onboarding vs. Profile.
- Fields: location chips with text entry, remote `FilterChip`s, job type chips, a sponsorship switch, and a salary floor slider.
- It builds the [SCHEMA.md §6](SCHEMA.md#6-json-shapes) `preferences` JSON. On the onboarding finish it marks onboarding complete.

**Enables:** Candidates rule out jobs they can't take.
**Needs:** CA-02 · **Stories:** US-12

#### CA-07 · Connect upload & progress · M
**Title:** Connect resume upload and progress to the backend

**Build:** `SupabaseResumeRepository`:
1. `storage.from('resumes').uploadBinary('${uid}/${uuid}.${ext}', bytes)`
2. insert the `resumes` row
3. `functions.invoke('parse-resume', body: {resume_id})`
4. `watchStatus(id)` = `from('resumes').stream(primaryKey: ['id']).eq('id', id)`

Also reuse the flow for the Profile → Update resume path.
**Enables:** Real resumes upload and parse, with progress driven by the actual backend.
**Needs:** PL-14, AI-07, PL-21 · **Stories:** US-07, US-08, US-13

#### CA-08 · Connect review & preferences · M
**Title:** Connect skill review and preferences to the backend

**Build:**
- `SupabaseProfileRepository`:
  - `latestVersion()` (select with nested `candidate_skills`)
  - `confirm(versionId, skills)` → `rpc('confirm_profile')`
  - `savePreferences` → `rpc('save_preferences')`
  - `searchSkills`
- Map `PostgrestException` to `AppFailure`.

**Enables:** Candidates finish onboarding for real and become matchable.
**Needs:** PL-17 · **Stories:** US-09, US-12

#### CA-09 · Parse failure & manual fallback · S
**Title:** Handle parse failures with a manual skill fallback

**Build:**
- When the status is FAILED, show a `passTint` banner with a message mapped from `failure_reason`.
- "Try another file" goes to upload.
- "Add skills manually" calls `rpc('create_manual_profile')`, then opens Review in add mode.

**Enables:** Onboarding never dead-ends, even when a resume can't be read.
**Needs:** CA-07, PL-17 · **Stories:** US-11

#### CA-10 · Job card · M
**Title:** Build the job card widget

**Build:**
- `JobCard` per the UI skill's components reference: `deck` surface with `ink` text, logo or `RhombusMark`, title, a meta row, `ScoreBadge`, 3 skill chips, and up to 2 gap chips.
- APPLY / PASS stamps whose opacity is driven by a `dragProgress` parameter (−1…1).
- Golden test.

**Enables:** Jobs display as on-brand cards with the score and top skills.
**Needs:** RC-02, CA-01 · **Stories:** US-14

#### CA-11 · Swipe deck · L
**Title:** Build the swipe deck

**Build:**
- `SwipeDeck`: 3 stacked cards (back cards scaled 0.94 / 0.88 and tilted −3° / +2°).
- The top card has a `GestureDetector` pan with `Transform.translate` + `rotate` (origin bottom-center, max ±15°).
- Commit when |dx| > 35% of the width or the velocity is > 800 px/s. Fly out over 250 ms `easeOutCubic`, or spring back over 400 ms `easeOutBack`.
- Haptics.
- Exposes `onCommit(direction)` and `commit(direction)` for the buttons.
- The card subtree is built once and wrapped in a `RepaintBoundary`.

**Enables:** The core swipe experience, smooth at 60 fps.
**Needs:** CA-10 · **Stories:** US-15, US-17

#### CA-12 · Action bar & undo toast · M
**Title:** Add apply/pass buttons and the undo toast

**Build:**
- `DeckActionBar` has ✕ / ⓘ / ✓ buttons, at least 56 px, calling `deck.commit()`.
- `UndoToast` counts down to the server's `committed_at` (adjusted for clock offset). "Undo" calls `undoSwipe` and plays the reverse animation.
- Semantics custom actions on the top card.

**Enables:** Tap-to-apply for accessibility, and an accidental apply can be undone.
**Needs:** CA-11 · **Stories:** US-16, US-18

#### CA-13 · Pass reasons · S
**Title:** Add optional pass reason chips

**Build:** `PassReasonChips` appears for about 3 s after a left swipe and calls `setPassReason(swipeId, reason)` on tap. The next card stays interactive underneath.
**Enables:** Candidates say why they passed, which tunes their future deck order.
**Needs:** CA-11 · **Stories:** US-17

#### CA-15 · Empty deck · S
**Title:** Build the empty deck state

**Build:** When the feed returns no cards and no cursor, show `EmptyState` ("Your deck is all squared away") with actions linking to `Routes.profilePreferences` and `Routes.profileResume`, plus a "Show stretch roles" toggle that sets `include_stretch`.
**Enables:** Candidates always know what to do when the deck runs out.
**Needs:** CA-11 · **Stories:** US-20

#### CA-14 · Connect the deck · M
**Title:** Connect the swipe deck to the live feed

**Build:**
- `FeedController` (`AsyncNotifier<List<JobCard>>`) calls `rpc('get_feed', {p_limit: 20, p_cursor})` and prefetches when 5 or fewer cards remain.
- It removes cards optimistically, calls `rpc('swipe')`, and rolls back on error.
- Map `daily_cap_reached` to a non-blocking banner.

**Enables:** Real ranked jobs, and swipes become real applications on the recruiter board.
**Needs:** PL-18, AI-15 · **Stories:** US-14, US-15, US-21

#### CA-16 · Radar deep-dive (shared widget) · L
**Title:** Build the radar chart match details view

**Build:**
- `lib/ui/components/radar_deep_dive.dart`:
  - an `fl_chart` `RadarChart` with a job polygon (outline at 1.0) and a "You" polygon (teal fill at 25%)
  - an axis builder: 3–8 required skills each get an axis, more are grouped by category, and fewer than 3 falls back to bars
  - a gap list (✓ / ◐ / ✕ with text) as the accessible version of the chart
- A `legendLabel` parameter so D can show "Candidate".
- Replace `DeepDiveScreen`'s placeholder, with a Hero / flip transition.
- Unit tests for the axis builder.

**Enables:** Candidates see why they matched and what's missing. D reuses the widget for recruiters.
**Needs:** AI-14 `breakdown` shape (use the contract sample until then) · **Stories:** US-23, US-24

#### CA-17 · Applications pipeline · M
**Title:** Build the applications pipeline screen

**Build:**
- `ApplicationRepository.watchMine()` streams `applications` through Realtime and joins job info from `my_applications`.
- `PipelineScreen` uses `StatusChip`s, grouped or sorted by most recent update.
- `ApplicationDetailScreen` has a `PipelineTimeline` from `status_events` and a "Withdraw" button (confirm, then `rpc('withdraw')`).
- Show a "No response yet" hint after 21 days.
- Announce status changes to screen readers.

**Enables:** Candidates track every application, with live updates when recruiters act.
**Needs:** PL-19, PL-21 · **Stories:** US-25, US-26, US-28

#### CA-18 · Interview contact · S
**Title:** Show recruiter contact info for interview requests

**Build:** On INTERVIEW_REQUESTED, `ApplicationDetailScreen` calls `rpc('get_application_contact')` and shows the recruiter's name, email, and note, with "Copy" (`Clipboard`) and "Email" (`url_launcher` `mailto:`).
**Enables:** Invited candidates can reach the recruiter directly.
**Needs:** CA-17 · **Stories:** US-29

#### CA-21 · Candidate accessibility & performance pass · M
**Title:** Run the candidate accessibility and performance pass

**Build:**
- Test with TalkBack on the emulator.
- Check text scale at 1.3× and 2.0×.
- Check contrast against the UI skill's table.
- Turn animations off and verify the reduced-motion behavior.
- Run `flutter run --profile` and confirm DevTools frame times stay under 16 ms during a fast swipe streak.
- Fix any issues found.

**Enables:** The candidate app works with screen readers and large text, and stays smooth on mid-range Android.
**Needs:** all CA · **Stories:** US-18

### Later

#### CA-19 · Low-match warning · S
**Title:** Warn before applying to low-match jobs

**Build:** Before committing a right swipe, if `score < 50` or any required item has coverage 0, pause at the threshold and show a confirm dialog naming the missing skill.
**Enables:** Fewer wasted applications.
**Needs:** CA-14 · **Stories:** US-19

#### CA-20 · Geometric background · M
**Title:** Add the animated geometric background

**Build:** `GeometricBackground`: one `CustomPainter(repaint: controller)` with 6–10 wireframe rhombuses and hexagons in `framework` at 25–40% alpha and a 60 s loop, wrapped in a `RepaintBoundary`. It pauses with `AppLifecycleListener` and shows a static frame when animations are disabled.
**Enables:** The playful geometric brand feel without a performance cost.
**Needs:** RC-01 · **Stories:** —

#### CA-22 · Offline swipe queue · M
**Title:** Queue swipes made offline and sync them later

**Build:** `SwipeQueue` persisted in `shared_preferences`. `connectivity_plus` triggers an in-order flush. Rejected items (cap, closed job) go into a "Couldn't apply" list.
**Enables:** Swipes made with no signal aren't lost.
**Needs:** CA-14 · **Stories:** US-22

#### CA-23 · Delete account screen · S
**Title:** Build the delete account screen

**Build:** Profile → "Delete account" opens a type-to-confirm dialog, then calls `functions.invoke('delete-account')`, then signs out.
**Enables:** Candidates remove their data from inside the app.
**Needs:** PL-24 · **Stories:** US-50

---

## Person D: Frontend (recruiter app + auth & routing)

Folders: `lib/app/`, `lib/features/{auth,company,jobs,board}/`, the web build. Skills: `resurhombus-ui`, `resurhombus-flutter`. Each scaffold page lists the task IDs that replace it.

### Core

#### PL-02 · Finish the Flutter skeleton · S
**Title:** Connect the Flutter app to Supabase and Riverpod

**Build:**
- The folders, routing, and placeholder pages already exist.
- `flutter pub add supabase_flutter flutter_riverpod fl_chart google_fonts file_picker crypto url_launcher`.
- In `main.dart`, call `Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.anonKey)` and wrap the app in `ProviderScope`.
- Add `lib/app/env.dart` reading `String.fromEnvironment`.
- Commit `env/example.json` and gitignore `env/dev.json`.
- The run command becomes `flutter run --dart-define-from-file=env/dev.json`.

**Enables:** The app can talk to Supabase, and everyone runs it with their own config.
**Needs:** PL-01 · **Stories:** —

#### RC-03 · Recruiter & auth repositories + fakes · S
**Title:** Create recruiter and auth repositories with fake data

**Build:**
- Abstract `AuthRepository`, `CompanyRepository`, `JobRepository`, and `BoardRepository`.
- `Fake…` implementations from the contract JSON, with providers overridden in `main_fake.dart` (shared with C).

**Enables:** Every recruiter screen can be built and demoed before the backend exists.
**Needs:** CA-01 · **Stories:** US-55

#### RC-04 · Wireframes · M
**Title:** Create wireframes for every screen

**Build:** Low-fidelity layouts for every scaffold page (paper photos or Figma), covering compact and wide layouts and the four states. Review them with the team and store them in `docs/wireframes/`.
**Enables:** Agreed layouts before building, so less rework.
**Needs:** — · **Stories:** —

#### PL-09 · Real auth repository · M
**Title:** Build real sign-up, sign-in, and password reset

**Build:** `SupabaseAuthRepository`:
- `signUpWithEmail(email, pw, role)` → `auth.signUp(data: {'role': role.name})`
- `signInWithEmail`
- `signInWithGoogle`: on Android, `google_sign_in` then `signInWithIdToken`. On web, `signInWithOAuth`.
- `signOut` (also invalidates user-scoped providers)
- `resetPassword(email)` → `resetPasswordForEmail(redirectTo:)`
- `updatePassword`
- Expose `authStateProvider` (a `StreamProvider` over `onAuthStateChange`) and `profileProvider`.
- Add the Android deep-link intent filter in `AndroidManifest.xml`.

**Enables:** Real accounts: sign up, sign in, sign out, and recover a password.
**Needs:** PL-02, PL-07 · **Stories:** US-02, US-04, US-05

#### PL-10 · Auth screens · M
**Title:** Build the welcome, role choice, and sign-in screens

**Build:**
- Replace the placeholders for Welcome (two `RoleChoiceCard`s, honoring `?role=recruiter`), Role choice (calls `rpc('set_initial_role')`), Sign up (email, password ≥ 8, Terms checkbox, Google button), Sign in, Forgot password, and Reset password.
- Add form validation, and map loading and error states from `AsyncValue`.

**Enables:** New users pick "I'm looking for a job" or "I'm hiring" and get into the right experience.
**Needs:** RC-01, PL-09 · **Stories:** US-01, US-02, US-05

#### PL-11 · Real routing · M
**Title:** Replace fake routing with real auth-based routing

**Build:**
- Delete `lib/app/dev_session.dart`. `resolveRedirect` now reads `authStateProvider` + `profileProvider`.
- The candidate-onboarded flag becomes `candidates.active_version_id != null`, and the recruiter-has-company flag becomes "a `recruiters` row exists".
- Add a signed-in-without-role state that routes to `/welcome/role`.
- `refreshListenable` is a `ChangeNotifier` bridging the auth stream.
- Handle `AuthChangeEvent.passwordRecovery` by routing to the reset page.
- Keep the existing router tests passing with fake providers.

**Enables:** Users stay signed in, land on their own home, and can never open the other role's pages.
**Needs:** PL-09 · **Stories:** US-03, US-06

#### RC-05 · Recruiter shell · M
**Title:** Build the responsive recruiter navigation shell

**Build:** In `RecruiterShell`, use a `LayoutBuilder`: at ≥ 900 px a `NavigationRail` (extended at ≥ 1200) beside the content, below that the existing `NavigationBar`. Keep the selected index in sync with `navigationShell`.
**Enables:** The portal feels native on laptop web and on Android.
**Needs:** RC-01 · **Stories:** US-45

#### RC-07 · Company onboarding screens · M
**Title:** Build the company create and join screens

**Build:**
- Replace the placeholders for Company setup, Create company (name, website URL validation, logo picker), and Join company (8-character code field that auto-uppercases and maps the `invalid_invite` / `already_in_company` errors).
- On success, refresh `profileProvider` so the router moves to Jobs.

**Enables:** Recruiters set up or join their company workspace.
**Needs:** RC-03 · **Stories:** US-30, US-32

#### PL-15 · Real company repository · M
**Title:** Connect company screens to the backend

**Build:** `SupabaseCompanyRepository`:
- `create` → `rpc('create_company')`, plus a logo upload to `company-logos/{id}/logo.png`
- `join` → `rpc('join_company')`
- `myCompany()`
- `invites()` / `createInvite()` / `revokeInvite()`

Connect it to the RC-07 screens.
**Enables:** Company creation and joining work for real.
**Needs:** PL-13, PL-14, RC-07 · **Stories:** US-30, US-32

#### RC-18 · Company settings · S
**Title:** Build company settings with invite code management

**Build:** Replace `CompanySettingsScreen`'s placeholder. It shows the company info and `CompanyBadge`. If the user is the owner, it also shows an invite code list with Generate, Copy (`Clipboard`), and Revoke. Plus Sign out.
**Enables:** Owners bring teammates in and shut off old codes.
**Needs:** PL-15 · **Stories:** US-31

#### RC-06 · Jobs list · M
**Title:** Build the recruiter jobs list

**Build:**
- Replace `JobsListScreen`'s placeholder: a `ListView` on compact layouts and a `DataTable` on expanded ones, from `company_jobs_overview`.
- Show `StatusChip`s, new/total badges, a "New job" button, pull-to-refresh, and an empty state ("Post your first job").

**Enables:** Recruiters see every job and where new applicants are waiting.
**Needs:** RC-03 · **Stories:** US-38

#### RC-08 · New job screen · M
**Title:** Build the paste-job-description screen

**Build:**
- Replace `NewJobScreen`'s placeholder: a multiline field with a 20k character counter.
- Submit runs `JobRepository.createDraft(raw)`: insert the job, invoke `parse-job`, and watch `jobs.parse_status` through Realtime.
- Show a progress state, then navigate to `Routes.jobRequirementsFor(id)`.

**Enables:** Recruiters create a job by pasting a description.
**Needs:** AI-12 (fake until then) · **Stories:** US-34

#### RC-09a · Requirement editor: table · M
**Title:** Build the requirement editor table

**Build:**
- Replace `RequirementEditorScreen`'s placeholder. A `RequirementsController` holds `List<RequirementDraft>`.
- Rows show the skill name, a Required/Preferred `SegmentedButton`, a min-years stepper, and weight pips (1–3).
- Use a `DataTable` when expanded and cards when compact.

**Enables:** Recruiters decide which skills matter most, which directly shapes every score.
**Needs:** RC-08 · **Stories:** US-35

#### RC-09b · Requirement editor: limits & evidence · M
**Title:** Add requirement limits, skill search, and evidence highlights

**Build:**
- Show "8/8 required" and "12/15 total" counters. The controller enforces the limits and the UI disables toggles with a tooltip explaining why.
- "Add skill" opens a taxonomy search.
- Show unmapped skills from `parse-job` with a "map to…" action.
- Selecting a row highlights its evidence in the JD panel (side-by-side when expanded).
- Save calls `rpc('save_requirements')`.

**Enables:** Focused requirements, with a visible source for each one.
**Needs:** RC-09a · **Stories:** US-35

#### RC-10 · Job details form · M
**Title:** Build the job details form

**Build:** Replace `JobDetailsScreen`'s placeholder. It has fields for location, remote chips, job type, a sponsorship switch, and salary min/max (validated so min ≤ max), pre-filled from the `parse-job` output.
**Enables:** Only candidates who can take the job see it.
**Needs:** RC-03 · **Stories:** US-36

#### RC-11 · Real job repository · M
**Title:** Connect jobs to the backend with publish, pause, and close

**Build:** `SupabaseJobRepository`:
- `list()` (from `company_jobs_overview`)
- `get(id)`
- `createDraft`
- `update(fields)`
- `saveRequirements`
- `setStatus(id, status)` → `rpc('set_job_status')`

Add publish, pause, and close actions (close asks for confirmation) to Job details and the jobs list.
**Enables:** Jobs go live, pause, and close for real. Closing a job updates its applicants.
**Needs:** PL-06, PL-11 · **Stories:** US-37, US-38

#### RC-12 · Mosaic grid & blind tiles · L
**Title:** Build the Mosaic grid of blind candidate tiles

**Build:**
- `MosaicGrid`: `SliverGrid` with `SliverGridDelegateWithMaxCrossAxisExtent(320)`, and keyed animated removal.
- `CandidateTile`: `RhombusMark` avatar, handle, `ScoreBadge`, years, 3 skills, 2 gaps, with `e1` → `e2` elevation on hover or focus. It has **no identity fields**.
- Replace `BoardScreen`'s placeholder with the header (job title, count, "Sorted by Match").

**Enables:** Recruiters see a ranked grid of skill-only tiles, 1–5 columns depending on width.
**Needs:** RC-02 · **Stories:** US-40, US-41

#### RC-13 · Triangle actions · M
**Title:** Add advance and reject triangle actions to tiles

**Build:**
- `TriangleActions`: two `ClipPath` triangles inside 48×48 `InkWell` hit areas.
- On web, `MouseRegion` hover slides them in over 150 ms. On touch, a tap toggles them (`selectedTileProvider`, so one tile at a time), and a long-press opens the detail view.
- Reject shows a 10 s "Not a fit · Undo" SnackBar. Advance opens an optional note popover.

**Enables:** One-click advance and reject on web and phone.
**Needs:** RC-12 · **Stories:** US-43, US-44, US-45

#### RC-14 · Connect the board · M
**Title:** Connect the applicant board to the backend with live updates

**Build:**
- `SupabaseBoardRepository`: `rpc('get_board')` with pagination (50), `advance`, `reject`, and `undoReject`.
- A Realtime subscription on `applications` filtered `job_id=eq.<id>` inserts new applicants in score order.
- Optimistic updates with rollback.

**Enables:** Candidates who swiped right appear live, and decisions reach candidates instantly.
**Needs:** AI-16, PL-19 · **Stories:** US-40, US-43, US-44

#### RC-15 · Candidate detail · M
**Title:** Build the recruiter candidate detail view

**Build:**
- Replace `CandidateDetailScreen`'s placeholder. On open it calls `rpc('open_application')`, then `rpc('get_candidate_detail')`.
- Show C's `RadarDeepDive(legendLabel: 'Candidate')` and an evidence list per skill, with advance and reject buttons.
- On expanded layouts it can render as a side panel next to the grid.

**Enables:** Recruiters verify a match before deciding, and candidates see "Under review".
**Needs:** CA-16, AI-16 · **Stories:** US-42

#### RC-16 · Interview list · M
**Title:** Build the interview list with resume links

**Build:** Replace `InterviewListScreen`'s placeholder with `rpc('get_interview_list')`. Rows show the name, job, score, an "Email" link (`mailto:`), and a "Resume" button: `functions.invoke('resume-url')`, then `launchUrl`. Allow filtering by job.
**Enables:** Recruiters follow up with advanced candidates, and identity appears only here.
**Needs:** AI-16, PL-23 · **Stories:** US-47

#### RC-20 · Recruiter accessibility & responsive pass · M
**Title:** Run the recruiter accessibility and responsive pass

**Build:**
- Test every recruiter page at 360 px and 1280 px.
- Check the tab and focus order, visible focus rings (`matchStrong`), and contrast.
- Make sure all triangle buttons have tooltips and semantics labels.
- Test with 2.0× text scale.

**Enables:** The portal works on small phones and laptops, and with assistive tech.
**Needs:** all RC · **Stories:** US-45

#### RC-21 · Host the web build · S
**Title:** Build and host the recruiter web app

**Build:**
- `flutter build web --release --dart-define-from-file=env/prod.json`.
- Deploy `build/web` to a static host (Netlify, Vercel, or GitHub Pages) with an SPA fallback to `index.html`.
- Add the hosted URL to Supabase Auth's redirect URLs.

**Enables:** A public URL for the recruiter portal, for the demo and grading.
**Needs:** RC-20 · **Stories:** —

### Later

#### RC-17 · Board filters · M
**Title:** Add applicant board filters

**Build:** A filter chip row (skills from the job's requirements, minimum years, minimum score) that passes `p_filters` to `get_board`. The order is unchanged. Sync the state to query parameters so it survives a web refresh.
**Enables:** Recruiters narrow a big pool without losing the ranking.
**Needs:** RC-14 · **Stories:** US-46

#### RC-19 · Keyboard shortcuts · M
**Title:** Add keyboard shortcuts for board triage

**Build:** `Shortcuts` + `Actions` on the board: J/K move focus between tiles (one `FocusNode` each), A advances, R rejects, Enter opens, and ? shows the help dialog. Shortcuts are disabled while a text field has focus.
**Enables:** Fast laptop triage without the mouse.
**Needs:** RC-14 · **Stories:** US-48

#### RC-22 · Verified badge in recruiter header · S
**Title:** Show the verified badge in the recruiter header

**Build:** Show `CompanyBadge` in the recruiter shell header and on Company settings, reading `companies.verified`.
**Enables:** Recruiters see their company's verification status.
**Needs:** PL-26 · **Stories:** US-33

---

## Everyone

| ID | Task | Title | Technical description |
|---|---|---|---|
| ALL-01 | **Contract review** | Review and freeze the API contract as a team | Walk through [schema.sql](schema.sql), `API_CONTRACT.md`, the Dart models, and the AI schemas together. Any disagreement is fixed in those files before building. After this, contract changes need a chat heads-up and frontend approval. |
| ALL-02 | **Loop test** | Test the full candidate-to-recruiter loop together | With `supabase db reset` seed data and a real AI provider: candidate on the Android emulator, recruiter on Chrome. Swipe right, then see the tile appear, advance it, and see the candidate's status update live. File an issue for every break. |
| ALL-03 | **Bug bash** | Run a cross-team bug bash | Each person spends 1 hour using the other silos' flows (including edge cases: bad files, an expired invite, the 26th swipe, undo timing) and files issues with steps to reproduce. |
| ALL-04 | **Demo rehearsal** | Rehearse the demo | Write a 5-minute script using the seed accounts and do 2 dry runs with the candidate and recruiter side by side. Have a pre-parsed resume ready in case live parsing is slow. |
