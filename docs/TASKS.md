# ResuRhombus: Tasks by Person

**Companion to:** [TEAM_PLAN.md](TEAM_PLAN.md) (roles, rules) · [SCHEMA.md](SCHEMA.md) + [schema.sql](schema.sql) (database) · [USER_STORIES.md](USER_STORIES.md) · [PRD.md](PRD.md)

**How to read this**
- **Blocks, not tiny tasks.** Each block combines several related small tasks into one piece of work you can build, test, and review together. The original task IDs (`PL-18`, `CA-11`, …) are kept in each block's **Covers** line, so USER_STORIES.md, the scaffold pages, and TEAM_PLAN.md still resolve (see the [ID lookup](#id-lookup) at the bottom).
- **Work order:** Each person works **top to bottom** through **Core**. **Later** holds features to add once the core works. New features get a story in USER_STORIES.md first, then a block in the owner's Later list.
- **Block fields:**
  - **Title:** a user story you can paste straight into a GitHub issue, e.g. `[A7] As a candidate, I want to apply or pass…`.
  - **Covers:** the original task IDs folded into this block.
  - **Size:** rough days (S ≈ ½, M ≈ 1, L ≈ 2 per original task).
  - **Needs:** blocks that must exist before this one can use real data. Until then, build against the fake (frontend) or mock (AI).
  - **Stories:** the `US-xx` stories it delivers.
  - **Build:** the technical work, grouped by original task.
  - **Done when:** the check that closes the block.

| Person | Silo | Core blocks | Core size | Later blocks |
|---|---|---|---|---|
| [A](#person-a-backend-database--api) | Backend: database & API | 9 | ≈ 15 days | 2 |
| [B](#person-b-backend-ai--matching) | Backend: AI & matching | 10 | ≈ 20 days | 2 |
| [C](#person-c-frontend-candidate-app--design-system) | Frontend: candidate app + design system | 11 | ≈ 22 days | 3 |
| [D](#person-d-frontend-recruiter-app--auth--routing) | Frontend: recruiter app + auth & routing | 10 | ≈ 22 days | 2 |
| [Everyone](#everyone) | Shared checkpoints | 3 | — | — |

A has the lightest load, so A has room to pair with B, review across the boundary, and run the integration checkpoints.

## Task index

### A · Backend (database & API)

| ID | Title | Days | List |
|---|---|---|---|
| A1 | As a teammate, I want the backend, repo rules, and CI set up once, so I can run the whole stack locally and trust every PR. | 1 | Core |
| A2 | As a teammate, I want one agreed database schema and API contract, so I can build my part against stable interfaces. | 4 | Core |
| A3 | As a user, I want my account created with the role I chose and kept separate from everyone else's, so I can sign up safely and only see my own data. | 2 | Core |
| A4 | As a recruiter, I want to create a company, invite teammates, and join with a code, so my team can post jobs from one workspace. | 1 | Core |
| A5 | As a candidate, I want my resume stored privately and my reviewed profile and preferences saved, so only I control what is used for matching. | 1 | Core |
| A6 | As a presenter, I want demo accounts, realistic starter data, and a clear README, so anyone can run and demo the project in minutes. | 1.5 | Core |
| A7 | As a candidate, I want to apply or pass on a job in one gesture and undo within 5 seconds, so I can move fast without fear of mistakes. | 1 | Core |
| A8 | As a recruiter, I want to see applicants ranked by score without identities and advance or reject them, so I can triage on skills alone and move fast. | 2 | Core |
| A9 | As a teammate, I want live updates, secure resume links, and automated tests of the loop's rules, so the core flow is fast, private, and doesn't regress. | 2 | Core |
| A10 | As a candidate, I want verified companies marked and a way to delete my account, so I can trust postings and control my data. | 1.5 | Later |
| A11 | As a candidate, I want a push notification when a recruiter acts on my application, so I can respond quickly. | 1 | Later |

### B · Backend (AI & matching)

| ID | Title | Days | List |
|---|---|---|---|
| B1 | As a developer, I want a curated skill list and realistic fake resumes and job descriptions, so I can test matching and demo without anyone's real data. | 2 | Core |
| B2 | As a developer, I want locked extraction schemas and an LLM adapter with a free mock, so I can build and test every AI feature without spending credits. | 2.5 | Core |
| B3 | As a developer, I want a real Gemini provider with a usage log and daily budget, so real AI works with one setting and never overspends. | 1.5 | Core |
| B4 | As a candidate, I want my resume turned into clean, safe text with calculated years and verified evidence, so the AI only extracts real skills and can't be tricked. | 2.5 | Core |
| B5 | As a candidate, I want the skills on my resume mapped to a standard skill list, so jobs recognize "ReactJS" and "React" as the same skill. | 1.5 | Core |
| B6 | As a candidate, I want to upload a resume and get a draft profile with live progress, so I don't have to type my history. | 2.5 | Core |
| B7 | As a recruiter, I want to paste a job description and get draft requirements, so I don't have to tag skills by hand. | 1 | Core |
| B8 | As a recruiter or candidate, I want an explainable 0–100 Match Score for every candidate and job pair, so I can trust the ranking and see why. | 3 | Core |
| B9 | As a candidate, I want a ranked deck of jobs I'm eligible for, so I see my best opportunities first. | 2 | Core |
| B10 | As a presenter, I want generated demo data covering every status and score band, so the demo looks alive without live AI. | 2 | Core |
| B11 | As a recruiter, I want applicant scores to update when I edit a live job's requirements, so the ranking stays fair. | 1 | Later |
| B12 | As a developer, I want measured extraction accuracy and a tuned matching threshold, so AI quality improves with evidence. | 1 | Later |

### C · Frontend (candidate app + design system)

| ID | Title | Days | List |
|---|---|---|---|
| C1 | As a developer, I want shared Dart models and fake repositories, so I can build candidate screens before the backend exists. | 2 | Core |
| C2 | As a user, I want one consistent branded look and reusable components, so every screen feels polished and readable. | 2 | Core |
| C3 | As a candidate, I want to pick my resume and watch a branded progress screen, so I know it is uploading and being read. | 2 | Core |
| C4 | As a candidate, I want to review and fix the AI's skills and set my job preferences, so my profile is accurate and my deck only has jobs I can take. | 3 | Core |
| C5 | As a candidate, I want onboarding to work end to end with real data and a manual fallback, so I can finish even when a resume can't be read. | 2.5 | Core |
| C6 | As a candidate, I want job cards I can swipe right to apply or left to pass, so applying takes a single gesture. | 3 | Core |
| C7 | As a candidate, I want buttons, an undo toast, optional pass reasons, and a helpful empty state, so I can use the deck without swiping, fix mistakes, and know what to do next. | 2 | Core |
| C8 | As a candidate, I want my deck to show real ranked jobs and my swipes to become real applications, so recruiters can see me. | 1 | Core |
| C9 | As a candidate, I want a radar chart and gap list for each job, so I understand why I matched and what I'm missing. | 2 | Core |
| C10 | As a candidate, I want to track every application with live status and see interview contact details, so I know where I stand and can reach the recruiter. | 1.5 | Core |
| C11 | As a candidate using a screen reader or large text, I want an accessible, smooth app, so I can use it as easily as anyone. | 1 | Core |
| C12 | As a candidate, I want a warning before a low-match apply and offline swipes that sync later, so I don't waste applications or lose decisions. | 1.5 | Later |
| C13 | As a candidate, I want a subtle animated geometric background, so the app feels playful without hurting performance. | 1 | Later |
| C14 | As a candidate, I want to delete my account from inside the app, so I control my data. | 0.5 | Later |

### D · Frontend (recruiter app + auth & routing)

| ID | Title | Days | List |
|---|---|---|---|
| D1 | As a developer, I want the app connected to Supabase with fake repositories and agreed wireframes, so I can build auth and recruiter screens in parallel with the backend. | 2 | Core |
| D2 | As a new user, I want to choose my role and sign up, sign in, or reset my password, so I can get into the right experience. | 2 | Core |
| D3 | As a signed-in user, I want to stay signed in and land on a home the other role can't reach, with navigation that fits my phone or laptop, so the app routes me correctly. | 2 | Core |
| D4 | As a recruiter, I want to create or join a company and manage invite codes, so my team shares one workspace. | 2.5 | Core |
| D5 | As a recruiter, I want a list of my company's jobs with applicant counts and the ability to publish, pause, or close them, so I control what is live. | 2 | Core |
| D6 | As a recruiter, I want to paste a job description, review the extracted requirements, and set job details, so I can publish a job in minutes. | 4 | Core |
| D7 | As a recruiter, I want a ranked grid of skill-only tiles with one-click advance and reject, so I can triage fast on any device. | 3 | Core |
| D8 | As a recruiter, I want the board connected to live data, so new applicants appear in score order and my decisions reach candidates instantly. | 1 | Core |
| D9 | As a recruiter, I want a candidate detail view and an interview list with resume links, so I can verify a match and follow up. | 2 | Core |
| D10 | As a recruiter on a phone or laptop, I want an accessible, responsive portal at a public URL, so I can use and demo it anywhere. | 1.5 | Core |
| D11 | As a recruiter, I want board filters and keyboard shortcuts, so I can triage large applicant pools quickly. | 2 | Later |
| D12 | As a recruiter, I want to see my company's verified status, so I know candidates can trust it. | 0.5 | Later |

### All · Everyone

| ID | Title |
|---|---|
| T1 | As a team, we want to review and freeze the API contract together, so everyone builds on the same agreement. |
| T2 | As a team, we want to test the full candidate-to-recruiter loop together, so we know the silos actually connect. |
| T3 | As a team, we want a cross-team bug bash and a demo rehearsal, so the demo goes smoothly. |

---

## Person A: Backend (database & API)

Folders: `supabase/migrations/`, `supabase/tests/`, `supabase/seed.sql`, non-AI Edge Functions. Skill: `resurhombus-supabase`.

### Core

#### A1 · As a teammate, I want the backend, repo rules, and CI set up once, so I can run the whole stack locally and trust every PR.
**Covers:** PL-01, PL-03 · **Size:** ≈ 1 day · **Needs:** — · **Stories:** —

**Build**
- **PL-01 Supabase:** Install the CLI, run `supabase init`, and commit `supabase/config.toml`. Enable the Email and Google auth providers and set `site_url` and redirect URLs (`http://localhost:*`, `io.resurhombus.app://login-callback`). Create the hosted dev project and share its URL and anon key privately. Gitignore `supabase/functions/.env`.
- **PL-03 Repo & CI:** Create the GitHub Project board (To do / In progress / In review / Done), labels (`owner:A..D`, `story:US-xx`), and `.github/pull_request_template.md` (task ID, stories, test notes). Protect `master` (1 review, green CI). Add `flutter analyze`, `supabase db reset`, and `supabase test db` to the workflow. Add `.github/CODEOWNERS` (template in TEAM_PLAN §1).

**Done when:** `supabase start` runs Postgres, Auth, Storage, Realtime, and Studio for everyone. PRs auto-request the right reviewer and can't merge with failing CI.

#### A2 · As a teammate, I want one agreed database schema and API contract, so I can build my part against stable interfaces.
**Covers:** PL-04, PL-05, PL-06, PL-27 (shared with B) · **Size:** ≈ 4 days · **Needs:** A1 · **Stories:** US-01, US-07, US-09, US-14, US-25, US-30, US-55

**Build**
- **PL-04 Identity & companies:** `supabase migration new identity_companies`. From [schema.sql](schema.sql), copy the enums, `touch_updated_at()`, `profiles`, `companies`, `recruiters`, `company_invites`, and `app_config`. Write RLS per [SCHEMA.md §4](SCHEMA.md#4-row-level-security-summary): profiles are self-only, and `role` can't be changed by update (`with check` or a trigger).
- **PL-05 Candidates & skills:** Create `vector` and `pgcrypto` in the `extensions` schema. Add `skills` (GIN on aliases, HNSW on embedding), `skill_relations`, `candidates`, `resumes`, `profile_versions`, `candidate_skills`, and the circular `active_version_id` foreign key. RLS: candidates own their rows, recruiters get **none**, skills are readable by everyone.
- **PL-06 Jobs & the loop:** Add `jobs`, `job_requirements`, `swipes`, `applications`, `application_reject_reasons`, `status_events`, `llm_usage`, `device_tokens`, plus the `company_jobs_overview` and `my_applications` views (`security_invoker`). RLS: candidates read jobs that are `OPEN` **or** that they've applied to. Recruiters read applications for their own company's jobs where `committed_at <= now()`. Reject reasons are recruiter-only.
- **PL-27 API contract (with B):** Write `docs/API_CONTRACT.md`. For every RPC and Edge Function in [SCHEMA.md §5](SCHEMA.md#5-functions-the-api-surface), give the exact parameters and types, one realistic example JSON response, the error codes (`P0001` messages like `daily_cap_reached`), and who can call it. A writes the database and status RPCs. B writes `get_feed`, `compute_match`, `parse-*`, and the `breakdown` shape.

**Done when:** `supabase db reset` applies all three migrations, and the contract is merged so C and D can build fakes that return its examples.

#### A3 · As a user, I want my account created with the role I chose and kept separate from everyone else's, so I can sign up safely and only see my own data.
**Covers:** PL-07, PL-08, PL-12 · **Size:** ≈ 2 days · **Needs:** A2 · **Stories:** US-01, US-02, US-06

**Build**
- **PL-07 Sign-up trigger:** `handle_new_user()` is `security definer`, runs `after insert on auth.users`, and inserts a `profiles` row with `role` from `raw_user_meta_data->>'role'` **only** when it is `candidate` or `recruiter`. Otherwise it leaves `role` null and never raises (Google sign-in may have no metadata). For candidates it also inserts a `candidates` row. Add `set_initial_role(p_role)`, which only works while `role is null` and creates the `candidates` row if needed.
- **PL-08 Role helpers:** `current_app_role()` (`stable security definer set search_path = public`) returns the caller's `profiles.role`. Add `my_company_id()` in the same style. Refactor policies to use them, wrapping `(select auth.uid())` so it's evaluated once per query.
- **PL-12 Access tests:** pgTAP tests in `supabase/tests/rls_identity.test.sql` with 2 candidates, 2 recruiters in different companies, and an anon user (`set local role` plus `request.jwt.claims`). Assert that users read and update only their own profile, role changes are blocked, and companies are readable by all but only updatable by the owner.

**Done when:** Signing up gives the chosen role, nobody can make themselves an admin, and the RLS tests pass in CI.

#### A4 · As a recruiter, I want to create a company, invite teammates, and join with a code, so my team can post jobs from one workspace.
**Covers:** PL-13 · **Size:** ≈ 1 day · **Needs:** A3 · **Stories:** US-30, US-31, US-32

**Build**
- `create_company(p_name, p_website)`: the role must be recruiter with no existing company. Inserts the company and a `recruiters(owner)` row, and sets `verified` (a simple version is fine; see A10).
- `create_invite(p_expires_in_days)`: owner only. Generates a code from `gen_random_bytes` mapped to the unambiguous alphabet and retries on collision.
- `join_company(p_code)`: locks the invite with `select … for update`, checks it isn't expired or revoked and `uses < max_uses`, inserts a `member` row, and increments `uses`.
- `revoke_invite(p_code)`. Add pgTAP tests for all four.

**Done when:** A recruiter creates a company and becomes its owner, generates a code, and a teammate joins with it. Bad or expired codes return `invalid_invite`.

#### A5 · As a candidate, I want my resume stored privately and my reviewed profile and preferences saved, so only I control what is used for matching.
**Covers:** PL-14, PL-17 · **Size:** ≈ 1 day · **Needs:** A2, A3 · **Stories:** US-07, US-09, US-11, US-12, US-49

**Build**
- **PL-14 Storage:** A migration inserting into `storage.buckets`: private `resumes` (5 MB limit, PDF and DOCX only) and public `company-logos`. Policies on `storage.objects`: for `resumes`, `(storage.foldername(name))[1] = auth.uid()::text` for select and insert. For logos, write only if the caller owns that company. Add a test that a user can't read another user's folder.
- **PL-17 Profile RPCs:**
  - `confirm_profile(p_version_id, p_skills jsonb)`: in one transaction, check ownership, replace the version's `candidate_skills` (edited rows get `source = 'user'`), set `confirmed`, `confirmed_at`, and `total_years`, and set `candidates.active_version_id`. The profile embedding is filled by B's parse step.
  - `create_manual_profile()`: an empty version with `source = 'manual'`.
  - `save_preferences(p_prefs)`: validates keys and types against the [SCHEMA.md §6](SCHEMA.md#6-json-shapes) shape and rejects unknown keys.

**Done when:** A candidate can upload only into their own folder, confirm a reviewed profile, and save preferences. Swiping later requires the confirmed profile.

#### A6 · As a presenter, I want demo accounts, realistic starter data, and a clear README, so anyone can run and demo the project in minutes.
**Covers:** PL-16, PL-25 · **Size:** ≈ 1.5 days · **Needs:** A4, B1, B5 · **Stories:** US-54

**Build**
- **PL-16 Seed v1:** In `supabase/seed.sql`, import the taxonomy from B1's CSV with B5's embeddings as `'[…]'::vector` literals, insert 3 companies (one verified), and insert demo users into `auth.users` (`crypt(password, gen_salt('bf'))`, `email_confirmed_at = now()`) with matching `auth.identities` rows. Every row has `is_seed = true`.
- **PL-25 README:** Rewrite `README.md`: prerequisites (Flutter, Supabase CLI), `supabase start`, copying `env/example.json` to `env/dev.json`, the emulator URL `http://10.0.2.2:54321`, `flutter run` and `-d chrome`, how to switch `LLM_PROVIDER`, how to run tests. Put the demo credentials **only** in the README's local-dev section.

**Done when:** `supabase db reset` gives working demo logins and real skills, and a new teammate can run everything from the README alone.

#### A7 · As a candidate, I want to apply or pass on a job in one gesture and undo within 5 seconds, so I can move fast without fear of mistakes.
**Covers:** PL-18 · **Size:** ≈ 1 day · **Needs:** A2, B8 (use a stub `compute_match` returning 50 until it lands) · **Stories:** US-15, US-16, US-17, US-21

**Build**
- `swipe(p_job_id, p_direction, p_reason)`:
  1. Check the role is candidate, the profile is confirmed (`profile_not_confirmed`), and the job is `OPEN` (`job_not_open`).
  2. For a right swipe, count today's right swipes against `app_config.daily_apply_cap` (`daily_cap_reached`).
  3. Insert the `swipes` row.
  4. For a right swipe, call `compute_match` and insert the `applications` row with `committed_at = now() + undo_seconds` plus a `status_events` row.
  5. Return `{swipe_id, application_id, committed_at}`.
- `undo_swipe(p_swipe_id)`: deletes only while `now() < committed_at` (`undo_window_expired`).
- `set_pass_reason(p_swipe_id, p_reason)`.

**Done when:** Candidates apply and pass, an accidental apply can be undone for 5 s, and the 26th apply of a day is rejected.

#### A8 · As a recruiter, I want to see applicants ranked by score without identities and advance or reject them, so I can triage on skills alone and move fast.
**Covers:** PL-19, AI-16 · **Size:** ≈ 2 days · **Needs:** A2, B8 · **Stories:** US-28, US-29, US-40, US-41, US-42, US-43, US-44, US-47

**Build**
- **PL-19 Status RPCs:** `open_application`, `advance(p_note)`, `reject(p_reason)`, `undo_reject`, `withdraw`, and `get_application_contact`. Each locks the row, checks the caller (recruiter of the job's company, or the owning candidate), validates the transition against the table in [SCHEMA.md §3](SCHEMA.md#3-enum-types), sets `previous_status`, `rejected_at`, or `advanced_by` as needed, and inserts a `status_events` row. `reject` writes its reason to `application_reject_reasons`. `get_application_contact` returns recruiter info only at INTERVIEW_REQUESTED.
- **AI-16 Blind board:**
  - `get_board(p_job_id, p_filters, p_limit, p_offset)`: checks own company, selects committed non-terminal applications ordered by `match_score desc, committed_at asc`, and builds tile JSON ([SCHEMA.md §6](SCHEMA.md#6-json-shapes)) from safe fields only. `handle` = `'◆ ' || upper(substr(md5(id::text), 1, 4))`. Top skills and gaps come from `breakdown`.
  - `get_candidate_detail(p_application_id)`: the tile plus the full `breakdown` and each skill's evidence. Identity (`display_name`, email) appears only at INTERVIEW_REQUESTED.
  - `get_interview_list(p_job_id)`.
  - Add a test that the tile's JSON keys are exactly the allowed set.

**Done when:** Recruiters see ranked, nameless tiles and can advance or reject (with undo). Candidates can withdraw. Invalid status jumps are impossible.

#### A9 · As a teammate, I want live updates, secure resume links, and automated tests of the loop's rules, so the core flow is fast, private, and doesn't regress.
**Covers:** PL-20, PL-21, PL-23 · **Size:** ≈ 2 days · **Needs:** A5, A7, A8 · **Stories:** US-06, US-08, US-21, US-26, US-47, US-49

**Build**
- **PL-21 Realtime:** Make sure the migration includes `alter publication supabase_realtime add table resumes, applications, jobs`. Confirm with two signed-in clients in Studio that a candidate only receives their own application changes.
- **PL-23 `resume-url`:** `supabase/functions/resume-url/index.ts` (Deno). Verify the JWT, use a user-scoped client to confirm the caller is a recruiter of the application's company and the status is INTERVIEW_REQUESTED, then use an admin client for `storage.from('resumes').createSignedUrl(path, 600)` and return `{url}`.
- **PL-20 Loop tests:** pgTAP tests asserting the 26th right swipe raises `daily_cap_reached`, `undo_swipe` fails after the window (simulate with `update … set committed_at = now() - interval '1s'`), every invalid transition raises, recruiter B can't read or advance company A's applications, and candidates can't read `application_reject_reasons`.

**Done when:** Parse progress and statuses update live, a resume link works only after advancing, and the loop's rules are guarded in CI.

### Later

#### A10 · As a candidate, I want verified companies marked and a way to delete my account, so I can trust postings and control my data.
**Covers:** PL-26, PL-24 · **Size:** ≈ 1.5 days · **Needs:** A4, A8 · **Stories:** US-33, US-50

**Build**
- **PL-26 Verified badge:** In `create_company`, compare `split_part(auth.email(), '@', 2)` with the host of `website` (lowercased, `www.` stripped), with a free-mail denylist (gmail.com, outlook.com, yahoo.com, …). Expose `verified` in feed cards.
- **PL-24 `delete-account`:** With an admin client: delete `resumes/{uid}/*` from Storage, set the candidate's applications to `anonymized = true` with `candidate_id` and `profile_version_id` null, delete the candidate rows, then `auth.admin.deleteUser(uid)` (cascades to `profiles`). Add an integration test that no rows remain.

**Done when:** Candidates can tell verified companies from unverified ones, and can permanently delete their data.

#### A11 · As a candidate, I want a push notification when a recruiter acts on my application, so I can respond quickly.
**Covers:** PL-22 · **Size:** ≈ 1 day · **Needs:** A9 · **Stories:** US-27

**Build:** `register_device(p_token, p_platform)`. A database webhook on `status_events` insert (to_status INTERVIEW_REQUESTED or NOT_SELECTED) calls the `notify` Edge Function, which sends through the FCM HTTP v1 API using a service-account JSON stored in function secrets.

**Done when:** A candidate gets a phone notification with the app closed.

---

## Person B: Backend (AI & matching)

Folders: `supabase/functions/parse-resume`, `parse-job`, `_shared/`, scoring SQL migrations, `scripts/`. Skill: `resurhombus-matching`.

### Core

#### B1 · As a developer, I want a curated skill list and realistic fake resumes and job descriptions, so I can test matching and demo without anyone's real data.
**Covers:** AI-01, AI-04 · **Size:** ≈ 2 days · **Needs:** — · **Stories:** US-14, US-54

**Build**
- **AI-01 Taxonomy:** `supabase/seed/skills.csv` with about 300 rows (`name, category, aliases`), using the categories from [SCHEMA.md](SCHEMA.md) (Languages, Frameworks, Data, Cloud/DevOps, Tools, Domain) and lowercase `|`-separated aliases. Add `skill_relations.csv` with about 80 rows (`skill, related, credit`). Cover the stacks in the fake job descriptions (mobile/Flutter, backend/Python, data, DevOps, frontend).
- **AI-04 Fake inputs:** 10 fake resume PDFs in `supabase/seed/resumes/` with varied layouts (single column, two-column, table-based, one DOCX, one scanned-style image PDF to test failure, one with hidden white text for injection tests). Add 6 fake job descriptions as `.txt`. Hand-label the expected skills for each in `fixtures/labels.json`.

**Done when:** The CSVs load, and every fixture has labels.

#### B2 · As a developer, I want locked extraction schemas and an LLM adapter with a free mock, so I can build and test every AI feature without spending credits.
**Covers:** AI-02, AI-03, PL-27 (AI parts, shared with A) · **Size:** ≈ 2.5 days · **Needs:** — · **Stories:** US-51, US-52, US-55

**Build**
- **AI-02 Schemas:** In `_shared/schemas.ts`, JSON Schemas for `resume` and `job` following the OpenAI strict rules (every property in `required`, `additionalProperties: false`, `["string","null"]` for optional values) with matching Zod validators and an exported `EXTRACTION_SCHEMA_VERSION`. The resume schema has **no** name, contact, age, or graduation-year fields.
- **AI-03 Adapter + mock:** In `_shared/llm.ts`, define `LlmProvider` with `extract<T>({schemaName, schema, system, untrustedText})` and `embed(texts)`. `getProvider()` reads `LLM_PROVIDER`. `MockProvider.extract` returns `_shared/fixtures/extract/<sha256(text)>.json` or a default fixture. `MockProvider.embed` returns deterministic unit vectors seeded from a hash of the text. Add Deno tests.
- **PL-27 (AI parts):** Contribute the `parse-resume`, `parse-job`, `get_feed` (card JSON plus cursor), `compute_match`, and `breakdown` sections of `API_CONTRACT.md`, with example payloads from the fixtures.

**Done when:** All AI code can run with `LLM_PROVIDER=mock`, and C can build the deck and radar from the contract examples.

#### B3 · As a developer, I want a real Gemini provider with a usage log and daily budget, so real AI works with one setting and never overspends.
**Covers:** AI-09, AI-13 · **Size:** ≈ 1.5 days · **Needs:** B2, A2 · **Stories:** US-53

**Build**
- **AI-09 Gemini provider (PRD v0.5):** `GeminiProvider` in `_shared/gemini.ts` (shared types in `llm_base.ts`, selected by `getProvider()` in `llm.ts`) uses `new GoogleGenAI({apiKey: GEMINI_API_KEY})` from `npm:@google/genai`.
  - `extract`: `models.generateContent` with `config: {responseMimeType: 'application/json', responseJsonSchema: schema, temperature: 0, systemInstruction: system}`. Check that Gemini accepts the `["string","null"]` style from `schemas.ts`. If not, convert it inside the adapter rather than changing `schemas.ts`.
  - `embed`: `models.embedContent` with `model: LLM_EMBED_MODEL`, `outputDimensionality: 1536`, `taskType: 'SEMANTIC_SIMILARITY'`, then L2-normalize each vector. Assert at startup that the model is `gemini-embedding-001`.
  - `transcribe(pdf)`: `generateContent` with the PDF as `inlineData` (`application/pdf`) and "Transcribe the visible text exactly. Output plain text only." Used only for image-only PDFs.
  - Map HTTP 429 (rate limit) to a retry with backoff, then `internal`. Add an opt-in contract test (`LLM_PROVIDER=gemini`) that runs one JD and one resume and validates the output.
- **AI-13 Usage & budget:** `_shared/usage.ts`. `getMeteredProvider({functionName, userId, store})` wraps every provider call to insert into `llm_usage`. Before each call, sum today's tokens and throw `BudgetExceeded` at or above `LLM_DAILY_TOKEN_BUDGET`. `parse-*` turns that into `FAILED` with `budget_exceeded`.

**Done when:** Real AI works with `LLM_PROVIDER=gemini`, `mock` still runs everything offline, and parsing stops cleanly before the budget runs out.

#### B4 · As a candidate, I want my resume turned into clean, safe text with calculated years and verified evidence, so the AI only extracts real skills and can't be tricked.
**Covers:** AI-05, AI-06, AI-08 · **Size:** ≈ 2.5 days · **Needs:** B2 · **Stories:** US-07, US-09, US-10, US-51

**Build**
- **AI-05 Text extraction (replaces Document Intelligence, PRD v0.5 §8.1):** `_shared/extract_text.ts`. `extractText(bytes, mime, llm)` returns `{ source: 'pdf_text' | 'docx' | 'ocr', lines: [{ text, page, fontSize, hidden }] }`.
  - **PDF:** `npm:unpdf` `getDocumentProxy`, then per page `getTextContent()`. Group items into lines by y position. `fontSize` = `hypot(transform[2], transform[3])`. Mark items `hidden` when the fill color in the page's `getOperatorList()` is white or near-white at the point the text is drawn.
  - **Image-only PDF:** fewer than about 50 non-space characters per page, so call `llm.transcribe(bytes)` and return its lines with `source: 'ocr'` (no hidden flags needed). If that comes back empty too, fail with `unreadable_scan`.
  - **DOCX:** `npm:fflate` unzip, then read `word/document.xml`. Each `w:p` is a line. Mark runs `hidden` for `w:vanish`, `w:color` `FFFFFF`, or `w:sz` under 8 (half-points).
  - Tests use the fixtures in `supabase/seed/resumes/`: two-column order is readable, `r09`'s white and 1pt text is flagged, and `r08` takes the OCR path (mock).
- **AI-06 Sanitizer:** `sanitize(lines)` drops lines that are `hidden` or have `fontSize` under about 4 pt, strips control characters, collapses whitespace, truncates at about 15k tokens (characters ÷ 4) with a marker, and strips email and phone patterns from the contact block. Unit tests.
- **AI-08 Years & evidence:** Pure functions in `_shared/profile.ts` with Deno tests. `mergeYears(roles)` takes, per skill, the union of role date ranges, merges overlaps, treats "present" as today, and rounds to 0.5. `validateEvidence(skill, text)` does a case- and whitespace-normalized substring check. `totalYears(roles)`.

- **Dev tool:** `deno task try:resume <file> [--text-only|--mock|--full]` (`scripts/try_resume.ts`) prints each step: extraction path, dropped hidden lines, sanitized text, Gemini extraction, kept and dropped skills with evidence, years, and a comparison with `labels.json` for fixtures.

**Done when:** PDFs (including scans) and DOCX files become clean text with no Azure service, hidden "score me 100%" text is removed, years are computed by code, and any skill without a real quote is dropped.

#### B5 · As a candidate, I want the skills on my resume mapped to a standard skill list, so jobs recognize "ReactJS" and "React" as the same skill.
**Covers:** AI-10, AI-11 · **Size:** ≈ 1.5 days · **Needs:** B3, A2 · **Stories:** US-14, US-54

**Build**
- **AI-10 Normalization:** Migration for `match_skills(p_embedding, p_threshold, p_k)`, returning `skill_id` and similarity via `1 - (embedding <=> p_embedding)` ordered by distance. `_shared/normalize.ts` tries (1) a lowercase exact or alias match (`aliases @> array[x]`), then (2) batch-embeds the unmatched strings and calls `match_skills` at threshold 0.89 (tuned with `deno task tune:threshold`), then (3) leaves `skill_id = null` (unmapped).
- **AI-11 Taxonomy embeddings:** `scripts/embed_taxonomy.ts` (Deno) reads `skills.csv`, embeds `name + aliases` in batches of 100, and writes `supabase/seed/skills_embeddings.sql` with vector literals. Run once and commit the output.

**Done when:** Free-text skills map onto the taxonomy, and seeding never calls the AI for embeddings.

#### B6 · As a candidate, I want to upload a resume and get a draft profile with live progress, so I don't have to type my history.
**Covers:** AI-07, AI-19 · **Size:** ≈ 2.5 days · **Needs:** B2, B4, B5, A2 · **Stories:** US-07, US-08, US-11, US-51

**Build**
- **AI-07 `parse-resume`:**
  1. Verify the JWT and ownership of `resume_id` (and that the storage folder is the owner's).
  2. Download, hash the bytes server-side, and check for a cached extraction with that hash and schema version (never trust the client's `file_hash`).
  3. Set the status at each step (PARSING_LAYOUT, then EXTRACTING, then NORMALIZING) with an admin client.
  4. `extractText`, `sanitize`, then `llm.extract(resumeSchema)` with the resume inside `<resume>` tags.
  5. Drop skills without valid evidence, then `mergeYears` and normalize.
  6. Insert `profile_versions` (next version) and `candidate_skills`. Save `extraction` and the provider and model.
  7. Set `READY`, or `FAILED` with a `failure_reason`. Never leave a row in a parsing state. Hard timeout at 60 s.
  - *As built:* status changes and the save go through service-role RPCs in `supabase/migrations/20261018210000_resume_parse_rpcs.sql` (`claim_resume_parse`, `advance_resume_status`, `fail_resume_parse`, `save_resume_draft`), so every transition is compare-and-set and the draft save is one transaction. Skills and roles quoted from injection-like sentences are dropped, and roles must quote the text and match a start year in it.
- **AI-19 Injection tests:** Deno tests run `parse-resume` (mock and, optionally, real) on the hidden-text fixture and on fixtures containing "ignore previous instructions" and "Age: 52". Assert no extra skills, no personal fields, and schema-valid output.

**Done when:** An upload becomes a draft profile with live status, and the injection tests prove a resume can't manipulate the AI.

#### B7 · As a recruiter, I want to paste a job description and get draft requirements, so I don't have to tag skills by hand.
**Covers:** AI-12 · **Size:** ≈ 1 day · **Needs:** B3, B5, A2 · **Stories:** US-34

**Build**
1. Verify the JWT and that the caller is a recruiter of the job's company.
2. Sanitize `raw_description`, then `llm.extract(jobSchema)`: title, requirements (`required_hint`, `min_years`, evidence), and location, remote, and salary if stated.
3. Normalize the requirement skills. Return unmapped ones as `unmapped[]` so the UI can show them.
4. Insert draft `job_requirements` (weight 2 if required, 1 if preferred) and pre-fill the job fields.
5. Set `parse_status = READY`.

*As built:* `_shared/job_pipeline.ts` + `_shared/requirements.ts`, saved atomically by `save_job_draft` (migration `20261018220000_parse_job_rpcs.sql`, which also adds `skills_centroid`, `start_job_parse`, `fail_job_parse`). Requirements need verified quotes (injection quotes dropped). Duplicates merge, "X or Y" alternatives become preferred with `either_of_group`, and caps of 8 required / 15 total are enforced (overflow → `trimmed[]`). `jobs.embedding` is set from the requirements' skill embeddings (PRD v0.6).

**Done when:** A pasted description becomes draft requirements ready for the recruiter to review.

#### B8 · As a recruiter or candidate, I want an explainable 0–100 Match Score for every candidate and job pair, so I can trust the ranking and see why.
**Covers:** AI-14, AI-17 · **Size:** ≈ 3 days · **Needs:** B5 · **Stories:** US-14, US-23

**Build**
- **AI-14 `compute_match()`:** A SQL function implementing PRD §8.4. Per requirement: `coverage` is 1 for an exact match, else the best `skill_relations.credit`, else 0. `depth = min(1, years / min_years)` (1 if `min_years` is 0, 0.5 if years is null). `score = coverage × (0.6 + 0.4 × depth)`. `raw` is the weighted average. The penalty is 0.15 per missing required skill. `score = round(100 × clamp(raw − penalty, 0, 1))`. Returns `{score, breakdown}` ([SCHEMA.md §6](SCHEMA.md#6-json-shapes)). Mark it `stable`.
- **AI-17 Regression test:** `supabase/tests/fixtures/match_pairs.json` with about 50 hand-labeled resume × job pairs and expected bands. A pgTAP or Deno test computes scores, asserts at least 80% band agreement, and prints a confusion table.

**Done when:** Every pair gets an explainable score plus the per-skill data behind the radar, and formula changes are checked against human judgment.

#### B9 · As a candidate, I want a ranked deck of jobs I'm eligible for, so I see my best opportunities first.
**Covers:** AI-15 · **Size:** ≈ 2 days · **Needs:** B8 · **Stories:** US-12, US-14, US-17, US-20

**Build:** Migration for `get_feed(p_limit, p_cursor)` (security definer, scoped to `auth.uid()`):
1. Read the candidate's active version and preferences.
2. Hard filters: OPEN jobs, not already swiped, remote/type/sponsorship/salary compatible.
3. Vector prefilter: `order by jobs.embedding <=> pv.embedding limit 500`.
4. `compute_match` for each remaining job.
5. Feed Rank = `0.70·match + 0.15·freshness + 0.10·affinity + 0.05·exploration`. Affinity comes from pass-reason counts, and exploration from a hash of the job id and today's date. Drop scores below 50 unless `include_stretch` is set.
6. Diversity: no more than 2 cards in a row from the same company.
7. Return cards plus `next_cursor = (rank, job_id)`.

**Done when:** Candidates get eligible jobs best match first, page by page, and pass reasons nudge the order without changing any score.

#### B10 · As a presenter, I want generated demo data covering every status and score band, so the demo looks alive without live AI.
**Covers:** AI-20 · **Size:** ≈ 2 days · **Needs:** B8, A6 · **Stories:** US-54

**Build:** `scripts/generate_seed.ts` with a fixed random seed generates about 30 candidates, with skills chosen to hit Strong, Good, Stretch, and Low bands against each of the 6 jobs. Also generate about 60 applications across **every** status (with matching `status_events`), about 150 swipes with pass reasons, and precomputed scores and embeddings. Output `supabase/seed/demo_data.sql`, which A6's `seed.sql` includes.

**Done when:** The demo has a full board and real pipelines from the first screen.

### Later

#### B11 · As a recruiter, I want applicant scores to update when I edit a live job's requirements, so the ranking stays fair.
**Covers:** AI-18 · **Size:** ≈ 1 day · **Needs:** B8 · **Stories:** US-39

**Build:** Inside `save_requirements` (with A), when the job is OPEN or PAUSED, run `update applications set (match_score, breakdown, scoring_version) = …compute_match(...)` for non-terminal rows and set `jobs.rescored_at`. Test that changing a weight changes both the score and the order.

**Done when:** Editing requirements updates every applicant's score and the board order.

#### B12 · As a developer, I want measured extraction accuracy and a tuned matching threshold, so AI quality improves with evidence.
**Covers:** AI-21 · **Size:** ≈ 1 day · **Needs:** B5 · **Stories:** —

**Build:** `deno task eval:extract` runs real extraction on the B1 resumes, compares against the labels, and prints per-skill precision and recall. Sweep the normalization threshold (0.80–0.92) and pick the best. Ask the team before running, because it costs credits.

**Done when:** There's a precision and recall report and a chosen threshold.

---

## Person C: Frontend (candidate app + design system)

Folders: `lib/ui/`, `lib/core/models/`, `lib/features/{onboarding,deck,deep_dive,pipeline,profile}/`. Skills: `resurhombus-ui`, `resurhombus-flutter`. Each scaffold page lists the task IDs it will replace.

### Core

#### C1 · As a developer, I want shared Dart models and fake repositories, so I can build candidate screens before the backend exists.
**Covers:** CA-01, CA-02 · **Size:** ≈ 2 days · **Needs:** A2 (contract draft) · **Stories:** US-55

**Build**
- **CA-01 Models:** In `lib/core/models/`, immutable classes with `fromJson` / `toJson` mapping the snake_case columns from [SCHEMA.md](SCHEMA.md): `Profile`, `Skill`, `CandidateSkill`, `ProfileVersion`, `Preferences`, `JobCard`, `BreakdownItem`, `Application`, `StatusEvent`, `CandidateTile`. Enums mirroring the Postgres enums (`ApplicationStatus`, `JobStatus`, `ResumeStatus`, `PassReason`, …) with `fromDb` / `toDb`. `ScoreBand.fromScore(int)`. Unit tests that round-trip the contract examples.
- **CA-02 Fake repositories:** In `lib/features/*/data/`, abstract `ProfileRepository`, `ResumeRepository`, `FeedRepository`, and `ApplicationRepository`. `Fake…` implementations backed by in-memory lists seeded from the contract JSON, with a 300 ms delay and an error toggle. Riverpod providers plus a `lib/main_fake.dart` that overrides them all.

**Done when:** Both frontends share one set of types, and every candidate screen can run on fake data.

#### C2 · As a user, I want one consistent branded look and reusable components, so every screen feels polished and readable.
**Covers:** RC-01, RC-02 · **Size:** ≈ 2 days · **Needs:** — · **Stories:** —

**Build**
- **RC-01 Theme:** `lib/ui/theme/rr_tokens.dart`, `rr_theme_ext.dart`, and `rr_theme.dart`, copied from `.claude/skills/resurhombus-ui/references/tokens-and-theme.md`. Add `google_fonts` (Space Grotesk and Inter). Replace the placeholder `ThemeData` in `lib/app/app.dart` (coordinate with D) and add the `context.rr` extension.
- **RC-02 Components:** In `lib/ui/components/`: `RhombusMark` (a `CustomPainter` with filled, outlined, and dashed variants), `ScoreBadge` (3 sizes, band label, semantics), `EmptyState`, `ShimmerShape`, `StatusChip`, and `CompanyBadge`. A debug-only `/dev/gallery` route showing each one. Golden tests for `ScoreBadge` and `StatusChip`.

**Done when:** The whole app, both roles, gets the brand colors, type, and spacing from one source, and both apps reuse the same components.

#### C3 · As a candidate, I want to pick my resume and watch a branded progress screen, so I know it is uploading and being read.
**Covers:** CA-03, CA-04 · **Size:** ≈ 2 days · **Needs:** C1, C2 · **Stories:** US-07, US-08

**Build**
- **CA-03 Upload screen:** Replace `UploadResumeScreen`'s placeholder. Use `file_picker` (`allowedExtensions: ['pdf','docx']`, `withData: true` so it works on web). Validate size ≤ 5 MB, the extension, and the magic bytes (`%PDF` or the `PK` zip header). Compute a sha256 with the `crypto` package, call `ResumeRepository.upload()` (fake for now), and navigate to `Routes.parseProgress(id)`. Show inline errors.
- **CA-04 Prism progress:** `PrismUploadProgress` is a `CustomPainter` rhombus splitting a beam into the palette colors, with steps mapped from `ResumeStatus`. `ParseProgressScreen` uses `ref.watch(resumeStatusProvider(id))` (a fake stream for now), navigates to Review on READY, and shows the error state on FAILED. Respect `MediaQuery.disableAnimationsOf`.

**Done when:** A candidate picks a file, gets clear errors for bad ones, and watches live-style progress.

#### C4 · As a candidate, I want to review and fix the AI's skills and set my job preferences, so my profile is accurate and my deck only has jobs I can take.
**Covers:** CA-05a, CA-05b, CA-06 · **Size:** ≈ 3 days · **Needs:** C1 · **Stories:** US-09, US-10, US-12

**Build**
- **CA-05a Review list:** `ReviewController` (`AsyncNotifier`) loads the latest version and its skills. `SkillReviewList` rows show the name, a years stepper in 0.5 steps, and an "edited" badge. Edits stay local until confirm.
- **CA-05b Add, remove, evidence:** Swipe-to-remove or ✕ on each row. "Add skill" opens a search sheet querying `skills` (`ilike` on name or aliases, limit 20) through the repository. An evidence bottom sheet shows the quote with the skill highlighted (`TextSpan`). A sticky "Looks right, continue" CTA.
- **CA-06 Preferences:** Replace `PreferencesScreen`'s placeholder (it has an `editing` flag for onboarding vs. Profile). Location chips with text entry, remote and job type `FilterChip`s, a sponsorship switch, and a salary floor slider. Build the [SCHEMA.md §6](SCHEMA.md#6-json-shapes) `preferences` JSON. On the onboarding finish, mark onboarding complete.

**Done when:** A candidate can correct what the AI found, add missing skills, see each skill's source, and set the filters that shape the deck.

#### C5 · As a candidate, I want onboarding to work end to end with real data and a manual fallback, so I can finish even when a resume can't be read.
**Covers:** CA-07, CA-08, CA-09 · **Size:** ≈ 2.5 days · **Needs:** A5, A9 (Realtime), B6 · **Stories:** US-07, US-08, US-09, US-11, US-12, US-13

**Build**
- **CA-07 Upload & progress:** `SupabaseResumeRepository`: `storage.from('resumes').uploadBinary('${uid}/${uuid}.${ext}', bytes)`, insert the `resumes` row, `functions.invoke('parse-resume', body: {resume_id})`, and `watchStatus(id)` = `from('resumes').stream(primaryKey: ['id']).eq('id', id)`. Reuse the flow for Profile → Update resume.
- **CA-08 Profile & preferences:** `SupabaseProfileRepository`: `latestVersion()` (select with nested `candidate_skills`), `confirm(versionId, skills)` → `rpc('confirm_profile')`, `savePreferences` → `rpc('save_preferences')`, and `searchSkills`. Map `PostgrestException` to `AppFailure`.
- **CA-09 Failure fallback:** On FAILED, show a `passTint` banner with a message mapped from `failure_reason`. "Try another file" goes to upload. "Add skills manually" calls `rpc('create_manual_profile')` and opens Review in add mode.

**Done when:** Real resumes upload and parse, onboarding finishes for real, and a failed parse never dead-ends.

#### C6 · As a candidate, I want job cards I can swipe right to apply or left to pass, so applying takes a single gesture.
**Covers:** CA-10, CA-11 · **Size:** ≈ 3 days · **Needs:** C2 · **Stories:** US-14, US-15, US-17

**Build**
- **CA-10 Job card:** `JobCard` per the UI skill's components reference: `deck` surface with `ink` text, logo or `RhombusMark`, title, meta row, `ScoreBadge`, 3 skill chips, and up to 2 gap chips. APPLY and PASS stamps whose opacity follows a `dragProgress` parameter (−1…1). Golden test.
- **CA-11 Swipe deck:** `SwipeDeck` with 3 stacked cards (back cards scaled 0.94 and 0.88, tilted −3° and +2°). The top card has a `GestureDetector` pan with `Transform.translate` and `rotate` (origin bottom-center, max ±15°). Commit when |dx| > 35% of the width or velocity > 800 px/s: fly out over 250 ms `easeOutCubic`, or spring back over 400 ms `easeOutBack`. Haptics. Exposes `onCommit(direction)` and `commit(direction)` for the buttons. The card subtree is built once and wrapped in a `RepaintBoundary`.

**Done when:** Cards swipe smoothly at 60 fps, with stamps, haptics, and a stacked look.

#### C7 · As a candidate, I want buttons, an undo toast, optional pass reasons, and a helpful empty state, so I can use the deck without swiping, fix mistakes, and know what to do next.
**Covers:** CA-12, CA-13, CA-15 · **Size:** ≈ 2 days · **Needs:** C6 · **Stories:** US-16, US-17, US-18, US-20

**Build**
- **CA-12 Buttons & undo:** `DeckActionBar` with ✕ / ⓘ / ✓ buttons (at least 56 px) calling `deck.commit()`. `UndoToast` counts down to the server's `committed_at` (adjusted for clock offset). "Undo" calls `undoSwipe` and plays the reverse animation. Semantics custom actions on the top card.
- **CA-13 Pass reasons:** `PassReasonChips` appears for about 3 s after a left swipe and calls `setPassReason(swipeId, reason)` on tap. The next card stays interactive underneath.
- **CA-15 Empty deck:** When the feed returns no cards and no cursor, show `EmptyState` ("Your deck is all squared away") with actions to `Routes.profilePreferences` and `Routes.profileResume`, plus a "Show stretch roles" toggle that sets `include_stretch`.

**Done when:** The deck works with taps or swipes, an accidental apply can be undone, and an empty deck always says what to do next.

#### C8 · As a candidate, I want my deck to show real ranked jobs and my swipes to become real applications, so recruiters can see me.
**Covers:** CA-14 · **Size:** ≈ 1 day · **Needs:** A7, B9 · **Stories:** US-14, US-15, US-21

**Build:** `FeedController` (`AsyncNotifier<List<JobCard>>`) calls `rpc('get_feed', {p_limit: 20, p_cursor})` and prefetches when 5 or fewer cards remain. It removes cards optimistically, calls `rpc('swipe')`, and rolls back on error. Map `daily_cap_reached` to a non-blocking banner.

**Done when:** Real ranked jobs appear, and a right swipe shows up on the recruiter board.

#### C9 · As a candidate, I want a radar chart and gap list for each job, so I understand why I matched and what I'm missing.
**Covers:** CA-16 · **Size:** ≈ 2 days · **Needs:** B8 (use the contract sample until then), C2 · **Stories:** US-23, US-24

**Build:** `lib/ui/components/radar_deep_dive.dart`, shared with D:
- An `fl_chart` `RadarChart` with a job polygon (outline at 1.0) and a "You" polygon (teal fill at 25%).
- An axis builder: 3–8 required skills each get an axis, more are grouped by category, and fewer than 3 falls back to bars.
- A gap list (✓ / ◐ / ✕ with text) as the accessible version of the chart.
- A `legendLabel` parameter so D can show "Candidate".
- Replace `DeepDiveScreen`'s placeholder, with a Hero or flip transition.
- Unit tests for the axis builder.

**Done when:** Candidates see why they matched and what's missing, and D can reuse the widget for recruiters.

#### C10 · As a candidate, I want to track every application with live status and see interview contact details, so I know where I stand and can reach the recruiter.
**Covers:** CA-17, CA-18 · **Size:** ≈ 1.5 days · **Needs:** A8, A9 · **Stories:** US-25, US-26, US-28, US-29

**Build**
- **CA-17 Pipeline:** `ApplicationRepository.watchMine()` streams `applications` through Realtime and joins job info from `my_applications`. `PipelineScreen` shows `StatusChip`s sorted by most recent update. `ApplicationDetailScreen` has a `PipelineTimeline` from `status_events` and a "Withdraw" button (confirm, then `rpc('withdraw')`). Show a "No response yet" hint after 21 days. Announce status changes to screen readers.
- **CA-18 Interview contact:** On INTERVIEW_REQUESTED, call `rpc('get_application_contact')` and show the recruiter's name, email, and note, with "Copy" (`Clipboard`) and "Email" (`url_launcher` `mailto:`).

**Done when:** Candidates see status changes the moment a recruiter acts, and invited candidates can reach the recruiter directly.

#### C11 · As a candidate using a screen reader or large text, I want an accessible, smooth app, so I can use it as easily as anyone.
**Covers:** CA-21 · **Size:** ≈ 1 day · **Needs:** C1–C10 · **Stories:** US-18

**Build:** Test with TalkBack on the emulator. Check text scale at 1.3× and 2.0×. Check contrast against the UI skill's table. Turn animations off and verify the reduced-motion behavior. Run `flutter run --profile` and confirm DevTools frame times stay under 16 ms during a fast swipe streak. Fix what you find.

**Done when:** The candidate app works with a screen reader and large text, and stays smooth on a mid-range Android.

### Later

#### C12 · As a candidate, I want a warning before a low-match apply and offline swipes that sync later, so I don't waste applications or lose decisions.
**Covers:** CA-19, CA-22 · **Size:** ≈ 1.5 days · **Needs:** C8 · **Stories:** US-19, US-22

**Build**
- **CA-19 Low-match warning:** Before committing a right swipe, if `score < 50` or any required item has coverage 0, pause at the threshold and show a confirm dialog naming the missing skill.
- **CA-22 Offline queue:** `SwipeQueue` persisted in `shared_preferences`. `connectivity_plus` triggers an in-order flush. Rejected items (cap, closed job) go into a "Couldn't apply" list.

**Done when:** Fewer wasted applications, and swipes made with no signal aren't lost.

#### C13 · As a candidate, I want a subtle animated geometric background, so the app feels playful without hurting performance.
**Covers:** CA-20 · **Size:** ≈ 1 day · **Needs:** C2 · **Stories:** —

**Build:** `GeometricBackground`: one `CustomPainter(repaint: controller)` with 6–10 wireframe rhombuses and hexagons in `framework` at 25–40% alpha and a 60 s loop, wrapped in a `RepaintBoundary`. It pauses with `AppLifecycleListener` and shows a static frame when animations are disabled.

**Done when:** The brand feel is there with no measurable frame cost.

#### C14 · As a candidate, I want to delete my account from inside the app, so I control my data.
**Covers:** CA-23 · **Size:** ≈ ½ day · **Needs:** A10 · **Stories:** US-50

**Build:** Profile → "Delete account" opens a type-to-confirm dialog, then calls `functions.invoke('delete-account')`, then signs out.

**Done when:** A candidate can remove their data without leaving the app.

---

## Person D: Frontend (recruiter app + auth & routing)

Folders: `lib/app/`, `lib/features/{auth,company,jobs,board}/`, the web build. Skills: `resurhombus-ui`, `resurhombus-flutter`. Each scaffold page lists the task IDs it will replace.

### Core

#### D1 · As a developer, I want the app connected to Supabase with fake repositories and agreed wireframes, so I can build auth and recruiter screens in parallel with the backend.
**Covers:** PL-02, RC-03, RC-04 · **Size:** ≈ 2 days · **Needs:** A1, C1 · **Stories:** US-55

**Build**
- **PL-02 Skeleton:** The folders, routing, and placeholder pages already exist. Run `flutter pub add supabase_flutter flutter_riverpod fl_chart google_fonts file_picker crypto url_launcher`. In `main.dart`, call `Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.anonKey)` and wrap the app in `ProviderScope`. Add `lib/app/env.dart` reading `String.fromEnvironment`. Commit `env/example.json` and gitignore `env/dev.json`. Run with `flutter run --dart-define-from-file=env/dev.json`.
- **RC-03 Fakes:** Abstract `AuthRepository`, `CompanyRepository`, `JobRepository`, and `BoardRepository` with `Fake…` implementations from the contract JSON. Providers are overridden in `main_fake.dart` (shared with C).
- **RC-04 Wireframes:** Low-fidelity layouts for every scaffold page (paper photos or Figma), covering compact and wide layouts and the four states. Team review, stored in `docs/wireframes/`.

**Done when:** The app talks to Supabase, everyone runs it with their own config, and every recruiter and auth screen can run on fake data.

#### D2 · As a new user, I want to choose my role and sign up, sign in, or reset my password, so I can get into the right experience.
**Covers:** PL-09, PL-10 · **Size:** ≈ 2 days · **Needs:** D1, A3, C2 · **Stories:** US-01, US-02, US-04, US-05

**Build**
- **PL-09 Auth repository:** `SupabaseAuthRepository`. `signUpWithEmail(email, pw, role)` → `auth.signUp(data: {'role': role.name})`. `signInWithEmail`. `signInWithGoogle`: on Android, `google_sign_in` then `signInWithIdToken`; on web, `signInWithOAuth`. `signOut` (also invalidates user-scoped providers). `resetPassword(email)` → `resetPasswordForEmail(redirectTo:)`. `updatePassword`. Expose `authStateProvider` (a `StreamProvider` over `onAuthStateChange`) and `profileProvider`. Add the Android deep-link intent filter in `AndroidManifest.xml`.
- **PL-10 Auth screens:** Replace the placeholders for Welcome (two `RoleChoiceCard`s, honoring `?role=recruiter`), Role choice (calls `rpc('set_initial_role')`), Sign up (email, password ≥ 8, Terms checkbox, Google button), Sign in, Forgot password, and Reset password. Add form validation and map loading and error states from `AsyncValue`.

**Done when:** Users create accounts as a candidate or recruiter, sign in and out, and recover a forgotten password.

#### D3 · As a signed-in user, I want to stay signed in and land on a home the other role can't reach, with navigation that fits my phone or laptop, so the app routes me correctly.
**Covers:** PL-11, RC-05 · **Size:** ≈ 2 days · **Needs:** D2 · **Stories:** US-03, US-06, US-45

**Build**
- **PL-11 Real routing:** Delete `lib/app/dev_session.dart`. `resolveRedirect` now reads `authStateProvider` and `profileProvider`. The candidate-onboarded flag becomes `candidates.active_version_id != null`, and the recruiter-has-company flag becomes "a `recruiters` row exists". Add a signed-in-without-role state that routes to `/welcome/role`. `refreshListenable` is a `ChangeNotifier` bridging the auth stream. Handle `AuthChangeEvent.passwordRecovery` by routing to the reset page. Keep the existing router tests passing with fake providers.
- **RC-05 Recruiter shell:** In `RecruiterShell`, use a `LayoutBuilder`: at ≥ 900 px a `NavigationRail` (extended at ≥ 1200), below that the existing `NavigationBar`. Keep the selected index in sync with `navigationShell`.

**Done when:** Users stay signed in, land on their own home, can never open the other role's pages, and the recruiter portal feels native on laptop web and on Android.

#### D4 · As a recruiter, I want to create or join a company and manage invite codes, so my team shares one workspace.
**Covers:** RC-07, PL-15, RC-18 · **Size:** ≈ 2.5 days · **Needs:** D1, A4, A5 · **Stories:** US-30, US-31, US-32

**Build**
- **RC-07 Screens:** Replace the placeholders for Company setup, Create company (name, website URL validation, logo picker), and Join company (8-character code field that auto-uppercases and maps `invalid_invite` and `already_in_company`). On success, refresh `profileProvider` so the router moves to Jobs.
- **PL-15 Repository:** `SupabaseCompanyRepository`: `create` → `rpc('create_company')` plus a logo upload to `company-logos/{id}/logo.png`, `join` → `rpc('join_company')`, `myCompany()`, `invites()`, `createInvite()`, `revokeInvite()`. Connect it to the screens.
- **RC-18 Company settings:** Replace `CompanySettingsScreen`'s placeholder: company info and `CompanyBadge`. For the owner, an invite code list with Generate, Copy (`Clipboard`), and Revoke. Plus Sign out.

**Done when:** Recruiters set up or join a company for real, owners bring teammates in, and old codes can be shut off.

#### D5 · As a recruiter, I want a list of my company's jobs with applicant counts and the ability to publish, pause, or close them, so I control what is live.
**Covers:** RC-06, RC-11 · **Size:** ≈ 2 days · **Needs:** D1, D3, A2 · **Stories:** US-37, US-38

**Build**
- **RC-06 Jobs list:** Replace `JobsListScreen`'s placeholder: a `ListView` on compact layouts and a `DataTable` on expanded ones, from `company_jobs_overview`. Show `StatusChip`s, new and total badges, a "New job" button, pull-to-refresh, and an empty state ("Post your first job").
- **RC-11 Job repository:** `SupabaseJobRepository`: `list()` (from `company_jobs_overview`), `get(id)`, `createDraft`, `update(fields)`, `saveRequirements`, and `setStatus(id, status)` → `rpc('set_job_status')`. Add publish, pause, and close actions (close asks for confirmation) to Job details and the jobs list.

**Done when:** Recruiters see every job and where new applicants wait. Jobs go live, pause, and close for real, and closing a job updates its applicants.

#### D6 · As a recruiter, I want to paste a job description, review the extracted requirements, and set job details, so I can publish a job in minutes.
**Covers:** RC-08, RC-09a, RC-09b, RC-10 · **Size:** ≈ 4 days · **Needs:** B7, D1 · **Stories:** US-34, US-35, US-36

**Build**
- **RC-08 New job:** Replace `NewJobScreen`'s placeholder: a multiline field with a 20k character counter. Submit runs `JobRepository.createDraft(raw)`: insert the job, invoke `parse-job`, and watch `jobs.parse_status` through Realtime. Show progress, then navigate to `Routes.jobRequirementsFor(id)`.
- **RC-09a Requirement table:** Replace `RequirementEditorScreen`'s placeholder. A `RequirementsController` holds `List<RequirementDraft>`. Rows show the skill name, a Required/Preferred `SegmentedButton`, a min-years stepper, and weight pips (1–3). `DataTable` when expanded, cards when compact.
- **RC-09b Limits & evidence:** Show "8/8 required" and "12/15 total" counters. The controller enforces the limits, and the UI disables toggles with a tooltip explaining why. "Add skill" opens a taxonomy search. Show unmapped skills from `parse-job` with a "map to…" action. Selecting a row highlights its evidence in the JD panel (side by side when expanded). Save calls `rpc('save_requirements')`.
- **RC-10 Job details:** Replace `JobDetailsScreen`'s placeholder: location, remote chips, job type, a sponsorship switch, and salary min and max (validated min ≤ max), pre-filled from the `parse-job` output.

**Done when:** A pasted description becomes confirmed requirements and job details, and only candidates who can take the job will see it.

#### D7 · As a recruiter, I want a ranked grid of skill-only tiles with one-click advance and reject, so I can triage fast on any device.
**Covers:** RC-12, RC-13 · **Size:** ≈ 3 days · **Needs:** C2 · **Stories:** US-40, US-41, US-43, US-44, US-45

**Build**
- **RC-12 Mosaic grid & blind tiles:** `MosaicGrid` is a `SliverGrid` with `SliverGridDelegateWithMaxCrossAxisExtent(320)` and keyed animated removal. `CandidateTile` has a `RhombusMark` avatar, handle, `ScoreBadge`, years, 3 skills, and 2 gaps, with `e1` → `e2` elevation on hover or focus. It has **no identity fields**. Replace `BoardScreen`'s placeholder with the header (job title, count, "Sorted by Match").
- **RC-13 Triangle actions:** `TriangleActions` are two `ClipPath` triangles inside 48×48 `InkWell` hit areas. On web, `MouseRegion` hover slides them in over 150 ms. On touch, a tap toggles them (`selectedTileProvider`, so one tile at a time) and a long-press opens the detail view. Reject shows a 10 s "Not a fit · Undo" SnackBar. Advance opens an optional note popover.

**Done when:** Recruiters see a ranked grid of nameless tiles, 1–5 columns by width, with one-click advance and reject on web and phone.

#### D8 · As a recruiter, I want the board connected to live data, so new applicants appear in score order and my decisions reach candidates instantly.
**Covers:** RC-14 · **Size:** ≈ 1 day · **Needs:** A8, D7 · **Stories:** US-40, US-43, US-44

**Build:** `SupabaseBoardRepository`: `rpc('get_board')` with pagination (50), `advance`, `reject`, and `undoReject`. A Realtime subscription on `applications` filtered `job_id=eq.<id>` inserts new applicants in score order. Optimistic updates with rollback.

**Done when:** Candidates who swiped right appear live, and a recruiter's decision reaches the candidate immediately.

#### D9 · As a recruiter, I want a candidate detail view and an interview list with resume links, so I can verify a match and follow up.
**Covers:** RC-15, RC-16 · **Size:** ≈ 2 days · **Needs:** C9, A8, A9 · **Stories:** US-42, US-47

**Build**
- **RC-15 Candidate detail:** Replace `CandidateDetailScreen`'s placeholder. On open it calls `rpc('open_application')`, then `rpc('get_candidate_detail')`. Show C's `RadarDeepDive(legendLabel: 'Candidate')`, an evidence list per skill, and advance and reject buttons. On expanded layouts it can render as a side panel next to the grid.
- **RC-16 Interview list:** Replace `InterviewListScreen`'s placeholder with `rpc('get_interview_list')`. Rows show the name, job, score, an "Email" link (`mailto:`), and a "Resume" button (`functions.invoke('resume-url')`, then `launchUrl`). Allow filtering by job.

**Done when:** Recruiters verify a match in depth before deciding, and identity and resumes appear only after advancing.

#### D10 · As a recruiter on a phone or laptop, I want an accessible, responsive portal at a public URL, so I can use and demo it anywhere.
**Covers:** RC-20, RC-21 · **Size:** ≈ 1.5 days · **Needs:** D1–D9 · **Stories:** US-45

**Build**
- **RC-20 Pass:** Test every recruiter page at 360 px and 1280 px. Check the tab and focus order, visible focus rings (`matchStrong`), and contrast. Make sure all triangle buttons have tooltips and semantics labels. Test at 2.0× text scale.
- **RC-21 Hosting:** `flutter build web --release --dart-define-from-file=env/prod.json`. Deploy `build/web` to a static host (Netlify, Vercel, or GitHub Pages) with an SPA fallback to `index.html`. Add the hosted URL to Supabase Auth's redirect URLs.

**Done when:** The portal works on small phones and laptops, and has a public URL for the demo and grading.

### Later

#### D11 · As a recruiter, I want board filters and keyboard shortcuts, so I can triage large applicant pools quickly.
**Covers:** RC-17, RC-19 · **Size:** ≈ 2 days · **Needs:** D8 · **Stories:** US-46, US-48

**Build**
- **RC-17 Filters:** A filter chip row (skills from the job's requirements, minimum years, minimum score) that passes `p_filters` to `get_board`. The order is unchanged. Sync the state to query parameters so it survives a web refresh.
- **RC-19 Shortcuts:** `Shortcuts` + `Actions` on the board: J/K move focus between tiles (one `FocusNode` each), A advances, R rejects, Enter opens, and ? shows the help dialog. Shortcuts are disabled while a text field has focus.

**Done when:** Recruiters narrow a big pool without losing the ranking and triage from the keyboard.

#### D12 · As a recruiter, I want to see my company's verified status, so I know candidates can trust it.
**Covers:** RC-22 · **Size:** ≈ ½ day · **Needs:** A10 · **Stories:** US-33

**Build:** Show `CompanyBadge` in the recruiter shell header and on Company settings, reading `companies.verified`.

**Done when:** Recruiters see whether their company is verified.

---

## Everyone

#### T1 · As a team, we want to review and freeze the API contract together, so everyone builds on the same agreement.
**Covers:** ALL-01 · **Needs:** A2, B2, C1

**Build:** Walk through [schema.sql](schema.sql), `API_CONTRACT.md`, the Dart models, and the AI schemas together. Fix any disagreement in those files before building. After this, contract changes need a chat heads-up and frontend approval.

#### T2 · As a team, we want to test the full candidate-to-recruiter loop together, so we know the silos actually connect.
**Covers:** ALL-02 · **Needs:** A7, A8, B9, C8, D8

**Build:** With `supabase db reset` seed data and a real AI provider, run the candidate on the Android emulator and the recruiter on Chrome. Swipe right, see the tile appear, advance it, and see the candidate's status update live. File an issue for every break.

#### T3 · As a team, we want a cross-team bug bash and a demo rehearsal, so the demo goes smoothly.
**Covers:** ALL-03, ALL-04 · **Needs:** all core blocks

**Build**
- **Bug bash:** Each person spends 1 hour using the other silos' flows, including edge cases (bad files, an expired invite, the 26th swipe, undo timing), and files issues with steps to reproduce.
- **Rehearsal:** Write a 5-minute script using the seed accounts and do 2 dry runs with the candidate and recruiter side by side. Keep a pre-parsed resume ready in case live parsing is slow.

---

## ID lookup

The original task IDs are still used in USER_STORIES.md, TEAM_PLAN.md, and the scaffold pages (`lib/features/*`). This table points each one to its block.

| Original ID | Block |
|---|---|
| AI-01 | B1 |
| AI-02 | B2 |
| AI-03 | B2 |
| AI-04 | B1 |
| AI-05 | B4 |
| AI-06 | B4 |
| AI-07 | B6 |
| AI-08 | B4 |
| AI-09 | B3 |
| AI-10 | B5 |
| AI-11 | B5 |
| AI-12 | B7 |
| AI-13 | B3 |
| AI-14 | B8 |
| AI-15 | B9 |
| AI-16 | A8 |
| AI-17 | B8 |
| AI-18 | B11 |
| AI-19 | B6 |
| AI-20 | B10 |
| AI-21 | B12 |
| ALL-01 | T1 |
| ALL-02 | T2 |
| ALL-03 | T3 |
| ALL-04 | T3 |
| CA-01 | C1 |
| CA-02 | C1 |
| CA-03 | C3 |
| CA-04 | C3 |
| CA-05a | C4 |
| CA-05b | C4 |
| CA-06 | C4 |
| CA-07 | C5 |
| CA-08 | C5 |
| CA-09 | C5 |
| CA-10 | C6 |
| CA-11 | C6 |
| CA-12 | C7 |
| CA-13 | C7 |
| CA-14 | C8 |
| CA-15 | C7 |
| CA-16 | C9 |
| CA-17 | C10 |
| CA-18 | C10 |
| CA-19 | C12 |
| CA-20 | C13 |
| CA-21 | C11 |
| CA-22 | C12 |
| CA-23 | C14 |
| PL-01 | A1 |
| PL-02 | D1 |
| PL-03 | A1 |
| PL-04 | A2 |
| PL-05 | A2 |
| PL-06 | A2 |
| PL-07 | A3 |
| PL-08 | A3 |
| PL-09 | D2 |
| PL-10 | D2 |
| PL-11 | D3 |
| PL-12 | A3 |
| PL-13 | A4 |
| PL-14 | A5 |
| PL-15 | D4 |
| PL-16 | A6 |
| PL-17 | A5 |
| PL-18 | A7 |
| PL-19 | A8 |
| PL-20 | A9 |
| PL-21 | A9 |
| PL-22 | A11 |
| PL-23 | A9 |
| PL-24 | A10 |
| PL-25 | A6 |
| PL-26 | A10 |
| PL-27 | A2, B2 |
| RC-01 | C2 |
| RC-02 | C2 |
| RC-03 | D1 |
| RC-04 | D1 |
| RC-05 | D3 |
| RC-06 | D5 |
| RC-07 | D4 |
| RC-08 | D6 |
| RC-09a | D6 |
| RC-09b | D6 |
| RC-10 | D6 |
| RC-11 | D5 |
| RC-12 | D7 |
| RC-13 | D7 |
| RC-14 | D8 |
| RC-15 | D9 |
| RC-16 | D9 |
| RC-17 | D11 |
| RC-18 | D4 |
| RC-19 | D11 |
| RC-20 | D10 |
| RC-21 | D10 |
| RC-22 | D12 |

