# ResuRhombus: User Stories

**Companion to:** [PRD.md](PRD.md) (v0.4) · **Work plan:** [TEAM_PLAN.md](TEAM_PLAN.md)

**Format:** *As a [user], I want to [do X], so I can [accomplish Y].*

**Each story contains:**
- **Done when**: acceptance criteria the reviewer checks before closing.
- **Technical implementation**:
  - **Flutter**: screens, widgets, providers, and repositories
  - **Backend**: Supabase tables, RLS, RPCs, Edge Functions, Storage, and Realtime
  - **AI**: anything touching the LLM or Document Intelligence
  - **Tests**: what proves it works
- **Refs**: PRD requirement IDs and sections, [TEAM_PLAN](TEAM_PLAN.md) task IDs, and the **backend** and **frontend** owners (A Backend: DB & API · B Backend: AI · C Frontend: candidate + design system · D Frontend: recruiter + auth). "—" means that layer has no work for the story.

**Priority:**
- **Must** is MVP, required for the course demo.
- **Should** is MVP stretch.
- **Could** is Phase 2.

**Conventions used below:**
- **Code locations:** Flutter code lives in `lib/features/<feature>/{data,domain,presentation}`. Backend code lives in `supabase/migrations`, `supabase/functions`, and `supabase/tests`.
- **Supabase client:** "Repo" means a repository class in the Flutter `data/` layer. It is the only code that calls `supabase_flutter`.
- **Status flow:** "Status flow" means the PRD §5.4 state machine.

---

## Index

| ID | Title | Priority | Backend | Frontend |
|---|---|---|---|---|
| US-01 | Choose my path at sign-up | Must | A | D |
| US-02 | Sign up with email or Google | Must | A | D |
| US-03 | Stay signed in, land on my home | Must | A | D |
| US-04 | Sign out | Must | — | D |
| US-05 | Reset forgotten password | Should | A | D |
| US-06 | Role-separated access | Must | A | D |
| US-07 | Upload resume | Must | A + B | C |
| US-08 | Live parse progress | Must | B | C |
| US-09 | Review & edit extracted skills | Must | A | C |
| US-10 | See evidence for each skill | Should | B | C |
| US-11 | Manual fallback when parsing fails | Must | B | C |
| US-12 | Set job preferences / hard filters | Must | A + B | C |
| US-13 | Re-upload resume (versioned) | Should | A | C |
| US-14 | Ranked job deck | Must | B | C |
| US-15 | Swipe right to apply | Must | A | C |
| US-16 | Undo an apply within 5 s | Must | A | C |
| US-17 | Swipe left to pass (+ reason) | Must | A + B | C |
| US-18 | Button alternatives to swiping | Must | — | C |
| US-19 | Warn before low-match apply | Should | — | C |
| US-20 | Empty-deck guidance | Must | B | C |
| US-21 | Daily apply cap | Should | A | C |
| US-22 | Offline swipe sync | Could | — | C |
| US-23 | Radar chart deep-dive | Must | B | C |
| US-24 | Plain-language gap list | Must | — | C |
| US-25 | Application pipeline | Must | A | C |
| US-26 | Live status updates | Must | A | C |
| US-27 | Push notification on interview | Should | A | C |
| US-28 | Withdraw an application | Should | A | C |
| US-29 | Recruiter contact on interview | Must | A | C |
| US-30 | Create company workspace | Must | A | D |
| US-31 | Generate invite codes | Must | A | D |
| US-32 | Join company by code | Must | A | D |
| US-33 | Verified company badge | Should | A | C + D |
| US-34 | Paste JD → extracted requirements | Must | B | D |
| US-35 | Edit requirements | Must | A + B | D |
| US-36 | Set job hard filters | Must | A | D |
| US-37 | Publish / pause / close job | Must | A | D |
| US-38 | Jobs list with counts | Must | A | D |
| US-39 | Re-score on requirement edit | Should | B | D |
| US-40 | Board sorted by Match Score | Must | A | D |
| US-41 | Blind tiles | Must | A | D |
| US-42 | Candidate detail view | Must | A | D |
| US-43 | One-click advance | Must | A | D |
| US-44 | One-click reject with undo | Must | A | D |
| US-45 | Touch-friendly tile actions | Must | — | D |
| US-46 | Board filters | Should | A | D |
| US-47 | Interview list | Must | A | D |
| US-48 | Keyboard triage shortcuts | Should | — | D |
| US-49 | Resume privacy until advanced | Must | A | — |
| US-50 | Delete my account | Should | A | C |
| US-51 | Skills-only AI (no personal traits) | Must | B | — |
| US-52 | Mock AI provider | Must | B | — |
| US-53 | Switchable LLM provider | Must | B | — |
| US-54 | Realistic seed data | Must | B + A | — |
| US-55 | Fake repositories in Flutter | Must | — | C + D |

---

## Epic 1: Accounts & Roles (shared)

### US-01 · Choose my path at sign-up · Must
> As a **new visitor**, I want to choose "I'm looking for a job" or "I'm hiring", so I can get the experience built for me.

**Done when:**
- Both options are shown with equal weight.
- The choice is saved to `profiles.role`.
- The `/recruiter` URL pre-selects "I'm hiring".

**Technical implementation**
- **Flutter:**
  - `features/auth/presentation/welcome_screen.dart` shows two `RoleChoiceCard`s.
  - The selected `AppRole` lives in a `signUpRoleProvider` (`StateProvider<AppRole?>`) and is passed into sign-up.
  - `go_router` reads the `?role=recruiter` query parameter (or the `/recruiter` path alias) to pre-select a card.
- **Backend:**
  - The role travels in `auth.signUp(options.data: {'role': 'recruiter'})`.
  - A `handle_new_user()` trigger on `auth.users` (`security definer`) inserts the `profiles` row. It reads `raw_user_meta_data->>'role'` and **rejects anything other than `candidate` or `recruiter`**, so nobody can self-assign `admin`.
- **Data:**
  - `profiles(id uuid pk references auth.users, role text check (role in ('candidate','recruiter')), display_name, created_at)`.
- **Tests:**
  - Widget test: selecting a card updates the provider.
  - pgTAP: the trigger creates a profile with the correct role, and an invalid role raises an error.

**Refs:** PRD §4, A-1, A-2 · Tasks PL-04, PL-07, PL-10 · **Backend:** A · **Frontend:** D

### US-02 · Sign up with email or Google · Must
> As a **new user**, I want to sign up with email and password or Google, so I can create an account in under a minute.

**Done when:**
- An account is created.
- A profile row exists with the chosen role.
- Terms are accepted.

**Technical implementation**
- **Flutter:**
  - `AuthRepository.signUpWithEmail(email, password, role)` calls `supabase.auth.signUp`.
  - `signInWithGoogle(role)`:
    - **Android:** the `google_sign_in` package returns an ID token, which goes to `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken:…)`.
    - **Web:** uses `supabase.auth.signInWithOAuth(OAuthProvider.google)`.
  - Form validation: email format, and a password of at least 8 characters. A Terms checkbox is required. Its timestamp is saved to `profiles.terms_accepted_at`.
- **Backend:**
  - Enable the Email and Google providers in Supabase Auth settings.
  - Add redirect URLs for web and the Android deep link (`io.resurhombus.app://login-callback`).
  - For Google first-time sign-in, the role is passed through the same metadata path as email sign-up.
  - **Edge case:** If an OAuth user arrives without role metadata, the trigger creates no profile. The router sends them to the role-choice screen, which calls a `set_initial_role(role)` RPC. That RPC only works while `role` is null.
- **Tests:**
  - Repository unit test with a mocked client.
  - Manual test on the Android emulator and Chrome.

**Refs:** PRD §4, A-6, X-1 · Tasks PL-07, PL-09, PL-10 · **Backend:** A · **Frontend:** D

### US-03 · Stay signed in, land on my home · Must
> As a **returning user**, I want to stay signed in and land on my own home screen, so I can pick up where I left off.

**Done when:**
- The session survives an app restart.
- Candidates land on `/c/deck` and recruiters on `/r/jobs`.

**Technical implementation**
- **Flutter:**
  - `supabase_flutter` stores the session automatically (secure storage on Android, local storage on web).
  - `authStateProvider` is a `StreamProvider` over `supabase.auth.onAuthStateChange`.
  - `profileProvider` loads `profiles` for `auth.currentUser`.
  - The `go_router` `redirect` logic:
    - no session → `/welcome`
    - session but no profile role → `/welcome/role`
    - candidate without a confirmed profile → `/c/onboarding`
    - otherwise the role's home
  - `refreshListenable` is driven by the auth stream.
- **Tests:**
  - Unit tests on the pure redirect function, covering every combination of session, role, and onboarding state.

**Refs:** PRD A-5 · Tasks PL-09, PL-11 · **Backend:** A · **Frontend:** D

### US-04 · Sign out · Must
> As a **user**, I want to sign out, so others using my device can't get into my account.

**Done when:**
- The session is cleared and the user is routed to welcome.
- No cached private data remains visible.

**Technical implementation**
- **Flutter:**
  - `AuthRepository.signOut()` calls `supabase.auth.signOut()`, then `ref.invalidate(...)` on user-scoped providers (profile, feed, applications, board) so nothing stale renders.
  - Clear the local offline swipe queue (US-22).
  - Realtime channels are unsubscribed in each provider's `ref.onDispose`.
- **Tests:**
  - Widget test: after sign-out, the router is on `/welcome` and the providers are reset.

**Refs:** — · Tasks PL-09 · **Backend:** — · **Frontend:** D

### US-05 · Reset forgotten password · Should
> As a **user**, I want to reset a forgotten password, so I don't lose my account.

**Done when:**
- The reset email is sent.
- The link opens the app or web page and lets the user set a new password.

**Technical implementation**
- **Flutter:**
  - "Forgot password" calls `supabase.auth.resetPasswordForEmail(email, redirectTo: <deep link or web URL>)`.
  - On return, `onAuthStateChange` emits `AuthChangeEvent.passwordRecovery`. The router shows `/reset-password`, which calls `auth.updateUser(UserAttributes(password:))`.
  - **Android:** add an intent filter for the deep-link scheme in `AndroidManifest.xml`.
- **Backend:**
  - Customize the email template in Supabase.
  - Local email testing uses the built-in Inbucket/Mailpit at `localhost:54324`.

**Refs:** X-1 · Tasks PL-09, PL-10 · **Backend:** A · **Frontend:** D

### US-06 · Role-separated access · Must
> As a **candidate**, I want recruiter screens to be unreachable from my account, and the reverse for recruiters, so each role only sees what it should.

**Done when:**
- Wrong-role routes redirect.
- RLS blocks the data even when a route is forced or the API is called directly.

**Technical implementation**
- **Flutter:**
  - The router guard sends `/r/*` to the candidate home when `role == candidate`, and the reverse. This is for user experience only.
- **Backend (the real enforcement):**
  - RLS is enabled on every table.
  - A helper `current_app_role()` (`security definer`, `search_path = public`) is used in policies.
  - Recruiter-only tables and RPCs check `current_app_role() = 'recruiter'` plus company membership.
  - Candidate tables check `auth.uid()` ownership.
  - RPCs raise `insufficient_privilege` on a role mismatch.
- **Tests:**
  - pgTAP matrix for each table: owner can, other same-role user can't, other role can't, anon can't.

**Refs:** PRD A-5, §9.5 · Tasks PL-08, PL-11, PL-12, PL-20 · **Backend:** A · **Frontend:** D

---

## Epic 2: Candidate Onboarding ("Prism Upload")

### US-07 · Upload resume · Must
> As a **candidate**, I want to upload my resume as a PDF or DOCX, so I don't have to type out my history.

**Done when:**
- PDF and DOCX files up to 5 MB are accepted.
- Other files are rejected with a reason.
- The file is stored in my private folder.

**Technical implementation**
- **Flutter:**
  - `file_picker` with `allowedExtensions: ['pdf','docx']` and `withData: true`. This is needed on web, where there's no file path.
  - Client-side checks on size and extension, plus a magic-byte sniff (`%PDF` / `PK` zip header).
  - `ResumeRepository.upload(bytes, ext)`:
    1. Uploads to Storage `resumes/{uid}/{uuid}.{ext}` with `upsert: false`.
    2. Inserts a `resumes` row (`status = 'UPLOADED'`, `storage_path`, `file_hash` = SHA-256 computed with the `crypto` package).
    3. Calls `functions.invoke('parse-resume', body: {resume_id})`.
- **Backend:**
  - Private bucket `resumes` with a size limit of 5 MB and allowed MIME types.
  - Storage policy: `(storage.foldername(name))[1] = auth.uid()::text` for insert and select.
  - `resumes` table RLS: the owner has CRUD.
- **Tests:**
  - Unit tests for the validators.
  - Integration test against local Supabase: upload succeeds into your own folder and fails for another user's folder.

**Refs:** PRD C-ON-1 · Tasks CA-03, CA-07, PL-14 · **Backend:** A + B · **Frontend:** C

### US-08 · Live parse progress · Must
> As a **candidate**, I want to see live progress while my resume is processed, so I know the app is working.

**Done when:**
- Progress steps follow the real status.
- The user can leave and come back.
- p95 is 20 s or less.

**Technical implementation**
- **Flutter:**
  - `watchResume(id)` is a `StreamProvider` using `supabase.from('resumes').stream(primaryKey:['id']).eq('id', id)` (Realtime).
  - `PrismUploadProgress` maps `status` to a step: `UPLOADED → PARSING_LAYOUT → EXTRACTING → NORMALIZING → READY | FAILED`.
  - Because the state is stored in the database, re-opening the app resumes from the current status.
- **Backend:**
  - `parse-resume` Edge Function updates `resumes.status` at each stage. It uses the service-role client only for those writes, after verifying the caller owns the row through the user JWT.
  - **Doc Intelligence:** a POST to `…/documentModels/prebuilt-layout:analyze`, then the function polls the `Operation-Location` URL until it succeeds.
  - Add `resumes` to the `supabase_realtime` publication.
  - A hard timeout at 60 s sets `FAILED` with `failure_reason = 'timeout'`.
- **AI:** Document Intelligence, then the LLM extraction described in US-51.
- **Tests:**
  - Widget test with a fake stream emitting every status.
  - Deno test of the function with mocked DI and LLM.

**Refs:** PRD C-ON-2, §8.1 · Tasks CA-04, CA-07, AI-05, AI-07, PL-21 · **Backend:** B · **Frontend:** C

### US-09 · Review & edit extracted skills · Must
> As a **candidate**, I want to review and edit the skills and years the AI found, so my profile is accurate before anyone sees it.

**Done when:**
- Skills can be added, removed, and renamed, and years changed.
- Edits are marked `source: user`.
- Applying is impossible until the profile is confirmed.

**Technical implementation**
- **Flutter:**
  - `ReviewController` (an `AsyncNotifier`) loads the latest `profile_versions` row and its `candidate_skills`, and holds the edits locally.
  - `SkillReviewList` rows have a years stepper (0.5 steps) and swipe-to-remove.
  - "Add skill" opens a search over `skills` (`ilike` on name and aliases, limit 20).
  - The CTA calls `confirm_profile(version_id, skills jsonb)`.
- **Backend:**
  - `confirm_profile` RPC, in one transaction:
    1. Upserts the edited `candidate_skills` (`source = 'user'` on changed rows).
    2. Sets `profile_versions.confirmed = true` and `candidates.active_version_id`.
    3. Computes the profile embedding. This is either queued to an Edge Function or done by calling `embed` before confirming.
  - `swipe()` (US-15) refuses to run until `active_version_id` is confirmed.
- **Data:**
  - `candidate_skills(profile_version_id, skill_id null, raw_name, years numeric(3,1) null, evidence text, source text check in ('ai','user'))`.
- **Tests:**
  - Controller unit tests for add, edit, and remove.
  - pgTAP: an unconfirmed profile can't swipe.

**Refs:** PRD C-ON-4, C-ON-5 · Tasks CA-05a, CA-05b, CA-08, PL-17 · **Backend:** A · **Frontend:** C

### US-10 · See evidence for each skill · Should
> As a **candidate**, I want to see the line in my resume each skill came from, so I can trust the extraction.

**Done when:**
- Tapping a skill shows its evidence snippet.

**Technical implementation**
- **Flutter:**
  - A bottom sheet shows `candidate_skills.evidence`, with the skill name highlighted using `TextSpan` matching.
  - User-added skills show "Added by you".
- **AI:**
  - The extraction schema requires `evidence` for every skill.
  - `parse-resume` drops any skill whose evidence isn't a substring of the sanitized text (case- and whitespace-normalized) before saving.
- **Tests:**
  - Deno unit test for the evidence validator (exact match, normalized whitespace, fabricated quote rejected).

**Refs:** PRD C-ON-3, §8.5 · Tasks CA-05b, AI-08 · **Backend:** B · **Frontend:** C

### US-11 · Manual fallback when parsing fails · Must
> As a **candidate**, I want to add skills by hand if my resume can't be read, so I'm never stuck at onboarding.

**Done when:**
- A failure or timeout shows the reason and offers a manual skill picker.

**Technical implementation**
- **Flutter:**
  - When `resumes.status == FAILED`, show a `passTint` banner with a message mapped from `failure_reason` (`unreadable_scan`, `timeout`, `too_long`, `budget_exceeded`), plus two actions:
    - "Try another file" returns to the upload screen.
    - "Add skills manually" creates an empty `profile_versions` row with `source = 'manual'` through a `create_manual_profile()` RPC, then opens the same `SkillReviewList` in add mode.
- **Backend:**
  - The function catches every error and always writes `FAILED` plus a reason. It never leaves a row stuck in `PARSING`.
  - A `pg_cron` sweep (optional) marks rows stuck in `PARSING` for more than 2 minutes as `FAILED`.

**Refs:** PRD §8.5 · Tasks CA-09 · **Backend:** B · **Frontend:** C

### US-12 · Set job preferences / hard filters · Must
> As a **candidate**, I want to set my location, remote preference, job type, work authorization, and minimum salary, so I only see jobs I can actually take.

**Done when:**
- Preferences are saved.
- The deck excludes jobs that fail the hard filters.

**Technical implementation**
- **Flutter:**
  - The preferences form uses chips for remote (`onsite` / `hybrid` / `remote`) and job type, a city text field (free text in MVP; geocoding is Phase 2), a work-authorization toggle, and an optional salary slider.
  - It saves through the `save_preferences(jsonb)` RPC.
- **Backend:**
  - `candidates.preferences jsonb`, validated in the RPC.
  - `get_feed()` applies the filters in SQL **before** scoring:
    - `jobs.status = 'OPEN'`
    - remote overlap
    - job type in the candidate's set
    - `jobs.salary_max >= pref.salary_min` (when both are set)
    - work authorization compatible
- **Tests:**
  - pgTAP: a seeded job that fails each filter never appears in `get_feed`.

**Refs:** PRD §5.1, C-SW-1 · Tasks CA-06, CA-08, PL-17, AI-15 · **Backend:** A + B · **Frontend:** C

### US-13 · Re-upload resume (versioned) · Should
> As a **candidate**, I want to upload a newer resume later, so my profile stays current without changing applications I already sent.

**Done when:**
- A new profile version is created.
- Old applications still reference their original version.

**Technical implementation**
- **Flutter:**
  - Profile tab → "Update resume" reuses the US-07 and US-08 flow, then the review screen.
  - User-edited skills from the previous version are pre-merged (`source = 'user'` wins).
- **Backend:**
  - `profile_versions.version` increments per candidate.
  - `applications.profile_version_id` is set at swipe time and never updated.
  - The new active version changes future feed scores only.
- **Tests:**
  - pgTAP: an application keeps its old `profile_version_id` and old score after a new version is confirmed.

**Refs:** PRD C-ON-6 · Tasks CA-07, CA-08 · **Backend:** A · **Frontend:** C

---

## Epic 3: Swipe Deck & Apply

### US-14 · Ranked job deck · Must
> As a **candidate**, I want a deck of job cards ranked by how well they match my skills, so I see my best opportunities first.

**Done when:**
- The deck loads from `get_feed` in Feed Rank order.
- Each card shows title, company, location, salary, score, and band.

**Technical implementation**
- **Flutter:**
  - `FeedController` (`AsyncNotifier<List<JobCard>>`) calls `rpc('get_feed', params: {limit: 20, cursor})` and refetches when 5 or fewer cards remain.
  - The `JobCard` widget follows the UI skill spec.
  - `ScoreBand.fromScore(int)` lives in `core/models`.
- **Backend:** `get_feed(p_limit int, p_cursor text)`, a `security definer` function scoped to `auth.uid()`:
  1. Hard filters (US-12), excluding already-swiped jobs.
  2. ANN prefilter: `order by jobs.embedding <=> candidate_embedding limit 500` (HNSW index).
  3. `compute_match(active_version_id, job_id)` for each remaining row.
  4. `feed_rank = 0.70·match + 0.15·freshness + 0.10·affinity + 0.05·exploration`.
  5. Diversity: no more than 2 cards in a row from the same company.
  6. Returns card JSON plus `breakdown` for the radar.
  - The cursor is `(feed_rank, job_id)`.
- **AI:** No live calls. The embeddings were computed at confirm or publish time.
- **Tests:**
  - pgTAP with seed data: the ordering is deterministic and swiped jobs are excluded.
  - The scoring regression fixture (AI-17).

**Refs:** PRD §5.2, §8.4, §8.6 · Tasks CA-10, CA-14, AI-14, AI-15 · **Backend:** B · **Frontend:** C

### US-15 · Swipe right to apply · Must
> As a **candidate**, I want to swipe right to apply instantly, so I can apply to a job in one gesture.

**Done when:**
- A right swipe creates an application linked to the current profile version.
- The card leaves the deck.

**Technical implementation**
- **Flutter:**
  - `SwipeDeck` calls `onCommit(direction)` once the commit animation is past its threshold.
  - The controller removes the card optimistically and calls `rpc('swipe', {job_id, direction: 'right'})`.
  - On error it re-inserts the card and shows a snackbar.
- **Backend:** `swipe(p_job_id, p_direction, p_reason)` does the following in one transaction:
  1. Validates that the role is candidate, the profile is confirmed, and the job is `OPEN`.
  2. Inserts `swipes`.
  3. For a right swipe, inserts `applications(status 'APPLIED', profile_version_id, match_score, breakdown, scoring_version, committed_at = now() + interval '5 seconds')`.
  4. Returns `{swipe_id, application_id, committed_at}`.
  - A unique constraint `(candidate_id, job_id)` on `swipes` prevents double-applying.
- **Tests:**
  - pgTAP: an application is created with a score, a duplicate swipe errors, and a closed job errors.

**Refs:** PRD C-SW-2 · Tasks CA-11, CA-14, PL-18 · **Backend:** A · **Frontend:** C

### US-16 · Undo an apply within 5 s · Must
> As a **candidate**, I want 5 seconds to undo an accidental right swipe, so a slip doesn't send an application.

**Done when:**
- The undo toast shows a countdown.
- Undo deletes the pending application.
- The recruiter never sees an undone application.

**Technical implementation**
- **Flutter:**
  - `UndoToast` counts down from the **server's** `committed_at`, using `committed_at - now` adjusted for the clock offset estimated from the response time.
  - "Undo" calls `rpc('undo_swipe', {swipe_id})` and puts the card back on top with the reverse animation.
- **Backend:**
  - `undo_swipe` deletes the swipe and application only `where committed_at > now()`. After the window it raises `undo_window_expired`.
  - `get_board` filters `committed_at <= now()`, so pending applications are invisible to recruiters with no timer or cron job.
- **Tests:**
  - pgTAP: undo within the window succeeds, and undo after the window fails. Use `set local` time or `pg_sleep` in the test.

**Refs:** PRD C-SW-2, §9.4 · Tasks CA-12, PL-18 · **Backend:** A · **Frontend:** C

### US-17 · Swipe left to pass (+ reason) · Must
> As a **candidate**, I want to swipe left to pass and optionally say why, so the deck learns what I don't want.

**Done when:**
- The pass is recorded.
- Reason chips never block the next card.
- Reasons affect Feed Rank only.

**Technical implementation**
- **Flutter:**
  - A left commit calls `swipe(direction: 'left')` right away.
  - `PassReasonChips` appears for about 3 s. A tap calls `rpc('set_pass_reason', {swipe_id, reason})`.
  - The next card is already interactive underneath.
- **Backend:**
  - `swipes.pass_reason text check in ('location','salary','stack','seniority','company')`.
  - **Affinity (v1):** a simple SQL view aggregates the candidate's pass reasons and company sizes into small penalty weights inside `get_feed`'s `affinity` term.
  - It **never** touches `compute_match` (PRD §1.3).
- **Tests:**
  - pgTAP: passing jobs from one company lowers that company's later jobs in feed order, while `match_score` stays the same.

**Refs:** PRD C-SW-4, §1.3, §8.6 · Tasks CA-13, PL-18, AI-15 · **Backend:** A + B · **Frontend:** C

### US-18 · Button alternatives to swiping · Must
> As a **candidate using a screen reader or limited motor control**, I want Apply and Pass buttons, so I can use the deck without swiping.

**Done when:**
- The ✕ and ✓ buttons are always visible and trigger the same animation.
- TalkBack offers custom actions.

**Technical implementation**
- **Flutter:**
  - `DeckActionBar` buttons call `deckController.commit(direction)`, which runs the same `AnimationController` fly-out as a gesture.
  - The top card is wrapped in `Semantics(label: <summary>, customSemanticsActions: {apply, pass, details})`.
  - Buttons are at least 56 px with tooltips.
- **Tests:**
  - Widget test: tapping ✓ calls `swipe(right)`.
  - Semantics test: the custom actions exist (`tester.getSemantics`).

**Refs:** PRD §3.2 · Tasks CA-12, CA-21 · **Backend:** — · **Frontend:** C

### US-19 · Warn before low-match apply · Should
> As a **candidate**, I want a warning before applying to a job where I'm missing a required skill, so I don't waste my application.

**Done when:**
- A confirmation appears when the score is below 50 or a required skill is missing.

**Technical implementation**
- **Flutter:**
  - Before calling `swipe(right)`, the controller checks `card.score < 50 || card.breakdown.any((r) => r.required && r.coverage == 0)`.
  - If true, it pauses the fly-out at the threshold, shows a dialog ("You're missing Kubernetes (required). Apply anyway?"), then commits or springs back.
- **Backend:** None. `breakdown` is already in the feed payload.

**Refs:** PRD §5.2 · Tasks CA-19 · **Backend:** — · **Frontend:** C

### US-20 · Empty-deck guidance · Must
> As a **candidate**, I want a helpful message when I run out of cards, so I know what to do next.

**Done when:**
- An empty state shows with "Widen filters" and "Update resume" actions.

**Technical implementation**
- **Flutter:**
  - When `get_feed` returns `[]` with no cursor, show `EmptyState` ("Your deck is all squared away").
  - The actions route to `/c/preferences` and `/c/profile/resume`.
  - Optionally show a count of "stretch" jobs hidden below 50 with a "Show stretch roles" toggle, using a `p_include_stretch` parameter on `get_feed`.

**Refs:** PRD §5.2 · Tasks CA-15 · **Backend:** B · **Frontend:** C

### US-21 · Daily apply cap · Should
> As a **recruiter**, I want candidates limited to 25 applications a day, so my board isn't flooded with low-effort applications.

**Done when:**
- The 26th apply is rejected with `daily_cap_reached`.
- The app shows a friendly message.

**Technical implementation**
- **Backend:**
  - Inside `swipe()`, count the right swipes `where created_at >= date_trunc('day', now() at time zone 'utc')`.
  - If the count is at or above `app_config.daily_apply_cap` (a one-row config table, default 25), `raise exception 'daily_cap_reached' using errcode = 'P0001'`.
  - Withdrawals don't refund the slot (PRD Q7).
- **Flutter:**
  - The repository maps `PostgrestException.message == 'daily_cap_reached'` to `AppFailure.dailyCap`.
  - The deck shows a non-blocking banner ("You've hit today's 25 applications, back tomorrow"). Left swipes still work.
- **Tests:**
  - pgTAP: 25 succeed and the 26th raises.

**Refs:** PRD C-SW-3 · Tasks PL-18, CA-14 · **Backend:** A · **Frontend:** C

### US-22 · Offline swipe sync · Could
> As a **candidate**, I want swipes I make offline to sync when I reconnect, so a spotty connection doesn't lose my decisions.

**Done when:**
- Queued swipes are sent in order on reconnect.
- Server rules still apply.

**Technical implementation**
- **Flutter:**
  - A `SwipeQueue` stored in `shared_preferences` (JSON list) or `drift`.
  - `connectivity_plus` triggers a flush that calls `swipe()` sequentially.
  - Right swipes queued offline skip the undo UI, because they're already past 5 s by the time they sync.
  - If the server rejects one (cap, closed job), surface it in a "Couldn't apply" list.
  - The deck uses the cached last feed page.
- **Backend:** None. `swipe()` is already idempotent through the unique constraint.

**Refs:** PRD C-SW-6 · Tasks CA-22 (Later) · **Backend:** — · **Frontend:** C

---

## Epic 4: Radar Deep-Dive

### US-23 · Radar chart deep-dive · Must
> As a **candidate**, I want to tap a card and see a radar chart of my skills against the job's requirements, so I understand why I matched.

**Done when:**
- The radar shows the job and candidate polygons with 3–8 axes.
- With fewer than 3 axes it falls back to bars.

**Technical implementation**
- **Flutter:**
  - The shared `RadarDeepDive` widget lives in `lib/ui/components/` (D reuses it in US-42).
  - Uses `fl_chart` `RadarChart` with two `RadarDataSet`s: job (all 1.0, outline) and candidate (`score(r)` per axis, teal fill at 25%).
  - **Axis builder:** 3–8 required skills become one axis each. More than 8 are grouped by `skills.category` and averaged. Fewer than 3 render `LinearProgressIndicator` bars.
  - Opens with a `Hero` plus Y-axis flip on compact layouts, or a side panel on expanded layouts.
- **Backend:**
  - `compute_match` returns `breakdown jsonb`: `[{skill_id, name, category, required, weight, coverage, depth, score, candidate_years, min_years}]`, which is already in the feed and board payloads.
- **Tests:**
  - Unit tests on the axis builder (2, 5, and 12 requirements).
  - A golden test of the widget.

**Refs:** PRD §5.3, §8.4 · Tasks CA-16, AI-14 · **Backend:** B · **Frontend:** C

### US-24 · Plain-language gap list · Must
> As a **candidate**, I want a plain-language list of my gaps, such as "AWS: 1 of 3 years", so I know what to learn or highlight.

**Done when:**
- The list shows matched, partial, and missing items with icons and text.
- It's accessible to screen readers.

**Technical implementation**
- **Flutter:**
  - Rows are built from `breakdown`:
    - `coverage == 1 && depth == 1` → ✓ matched
    - `coverage > 0` → ◐ partial ("AWS: 1 of 3 years", or "Related: MySQL for PostgreSQL")
    - `coverage == 0` → ✕ missing (marked as required or preferred)
  - The list sorts missing required items first.
  - Each row is a plain `ListTile` with full text, so it is the accessible version of the radar. The chart itself is `ExcludeSemantics`.
- **Tests:**
  - Unit test for the breakdown-to-row mapping.

**Refs:** PRD §5.3 · Tasks CA-16 · **Backend:** — · **Frontend:** C

---

## Epic 5: Application Pipeline

### US-25 · Application pipeline · Must
> As a **candidate**, I want to see every job I applied to and its status, so I can keep track of where I stand.

**Done when:**
- The list shows every status in the status flow.

**Technical implementation**
- **Flutter:**
  - `ApplicationsRepository.watchMine()` streams `applications` joined to job title and company name. This uses a view `my_applications` with `security_invoker = true`, because Realtime streams need a table. Alternatively, stream the table and fetch job info once.
  - `PipelineScreen` groups by status, with `StatusChip` and a `PipelineTimeline` built from `status_events`.
  - `ApplicationStatus` enum: `applied, underReview, interviewRequested, notSelected, withdrawn, jobClosed`.
  - Applications older than 21 days with no action show a "No response yet" hint.
- **Backend:**
  - RLS on `applications`: the candidate can select where the profile belongs to `auth.uid()`.
  - `status_events(application_id, from_status, to_status, actor, created_at)`.

**Refs:** PRD §5.4 · Tasks CA-17 · **Backend:** A · **Frontend:** C

### US-26 · Live status updates · Must
> As a **candidate**, I want status changes to show up instantly, so I don't have to keep refreshing.

**Done when:**
- Realtime updates the list and badge while the app is open.

**Technical implementation**
- **Backend:**
  - Add `applications` to the `supabase_realtime` publication.
  - Realtime respects RLS, so candidates only receive their own rows.
- **Flutter:**
  - `supabase.from('applications').stream(primaryKey: ['id'])`. New statuses animate in with a fade and slide.
  - A bottom-nav badge counts unseen changes (`applications.updated_at > last_seen_at` stored locally).
  - Screen readers get a `SemanticsService.announce` for a status change.
- **Tests:**
  - Manual two-device test: recruiter advances, and the candidate's chip updates within about 1 s.

**Refs:** PRD X-2 · Tasks PL-21, CA-17 · **Backend:** A · **Frontend:** C

### US-27 · Push notification on interview · Should
> As a **candidate**, I want a push notification when a recruiter requests an interview, so I can respond quickly.

**Done when:**
- An FCM push is received while the app is closed.

**Technical implementation**
- **Flutter:**
  - `firebase_messaging` (FCM only, no other Firebase services).
  - Request `POST_NOTIFICATIONS` permission on Android 13+.
  - Save the token through `rpc('register_device', {token, platform})`.
  - Tapping a notification deep-links to `/c/pipeline/:id`.
- **Backend:**
  - `device_tokens(user_id, token, platform, updated_at)` table.
  - A database webhook on `status_events` insert (to_status in `INTERVIEW_REQUESTED`, `NOT_SELECTED`) calls the `notify` Edge Function.
  - `notify` sends with the FCM HTTP v1 API, using a service-account JSON stored in function secrets.
- **Tests:**
  - Manual test on the emulator with Google Play services.

**Refs:** PRD X-2 · Tasks PL-22 · **Backend:** A · **Frontend:** C

### US-28 · Withdraw an application · Should
> As a **candidate**, I want to withdraw an application, so recruiters don't spend time on a job I no longer want.

**Done when:**
- The status becomes Withdrawn.
- The candidate disappears from the recruiter board.

**Technical implementation**
- **Flutter:** "Withdraw" on the pipeline detail shows a confirm dialog, then calls `rpc('withdraw', {application_id})`.
- **Backend:**
  - `withdraw` checks ownership and that the current status is one of `APPLIED`, `UNDER_REVIEW`, `INTERVIEW_REQUESTED`.
  - Updates the status and writes a `status_events` row.
  - `get_board` excludes terminal statuses.
- **Tests:**
  - pgTAP: valid transitions pass, invalid ones (from `NOT_SELECTED`) raise.

**Refs:** PRD §5.4 · Tasks PL-19, CA-17 · **Backend:** A · **Frontend:** C

### US-29 · Recruiter contact on interview · Must
> As a **candidate**, I want to see the recruiter's contact info when I'm invited to interview, so I can arrange the next step.

**Done when:**
- Interview Requested shows the recruiter's email and optional note.

**Technical implementation**
- **Backend:**
  - `advance(application_id, note)` stores `applications.advanced_by` (the recruiter's profile id) and `interview_note`.
  - A `get_application_contact(application_id)` RPC returns the recruiter's name and email (from `auth.users` through `security definer`) **only** when the caller owns the application and the status is `INTERVIEW_REQUESTED`.
- **Flutter:** The pipeline detail card shows contact info with "Copy email" and a `mailto:` link (`url_launcher`).

**Refs:** PRD §5.4 · Tasks CA-18, PL-19 · **Backend:** A · **Frontend:** C

---

## Epic 6: Recruiter & Company Onboarding

### US-30 · Create company workspace · Must
> As a **recruiter**, I want to create my company's workspace, so I can post jobs under my company's name.

**Done when:**
- The company is created with name, website, and logo.
- The creator becomes `owner`.

**Technical implementation**
- **Flutter:**
  - `CreateCompanyScreen` form: name (required), website (URL validation), and logo (`file_picker` image upload to the public bucket `company-logos/{company_id}/logo.png`).
  - `CompanyRepository.create()` calls `rpc('create_company', {...})`.
  - The router guard sends a recruiter without a company to `/r/onboarding`.
- **Backend:**
  - `create_company(name, website)`:
    1. Checks the role is recruiter and the user has no existing company.
    2. Inserts `companies`.
    3. Inserts `recruiters(profile_id, company_id, company_role 'owner')`.
    4. Computes `verified` (US-33).
    5. Returns the company.
  - RLS: companies are readable by authenticated users (for job cards) and updatable by the owner.

**Refs:** PRD A-3 · Tasks RC-07, PL-13, PL-15 · **Backend:** A · **Frontend:** D

### US-31 · Generate invite codes · Must
> As a **company owner**, I want to generate invite codes, so my teammates can join our workspace.

**Done when:**
- A code is generated with an expiry.
- The owner can revoke it.

**Technical implementation**
- **Backend:**
  - `company_invites(code text pk, company_id, created_by, expires_at, revoked_at, max_uses int default 10, uses int default 0)`.
  - `create_invite(expires_in_days default 7)` generates an 8-character code from an unambiguous alphabet (e.g., `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, using `gen_random_bytes`). Owner only.
  - `revoke_invite(code)`.
- **Flutter:** The Company settings screen lists active codes with Copy (`Clipboard.setData`) and Revoke buttons.
- **Tests:** pgTAP: a member (non-owner) can't create invites.

**Refs:** PRD A-3 · Tasks PL-13, RC-18 · **Backend:** A · **Frontend:** D

### US-32 · Join company by code · Must
> As a **recruiter**, I want to join my company with an invite code, so I can work on the same jobs as my team.

**Done when:**
- A valid code links the recruiter to the company.
- An invalid or expired code shows an error.

**Technical implementation**
- **Backend:**
  - `join_company(code)` locks the invite row (`for update`) and validates that it isn't expired, isn't revoked, and `uses < max_uses`.
  - Inserts `recruiters(... 'member')` and increments `uses`.
  - Raises `invalid_invite` or `already_in_company` on failure.
- **Flutter:**
  - The join screen has a code field (auto-uppercase, 8 characters) and maps errors to messages.
  - On success, refresh `profileProvider`, and the router moves to `/r/jobs`.

**Refs:** PRD A-3 · Tasks PL-13, RC-07, PL-15 · **Backend:** A · **Frontend:** D

### US-33 · Verified company badge · Should
> As a **candidate**, I want to see whether a company is verified, so I can avoid fake job postings.

**Done when:**
- The Verified badge shows when the email domain matches the company website.
- Otherwise the card shows an Unverified tag with an explanatory tooltip.

**Technical implementation**
- **Backend:**
  - In `create_company`, compare the domain part of `split_part(auth.email(), '@', 2)` with the host of `website` (after stripping `www.`), and set `companies.verified`.
  - Free-mail domains (gmail.com, outlook.com, …) never verify.
  - `get_feed` includes `company_verified` in the card JSON.
- **Flutter:** The `CompanyBadge` component appears on `JobCard` and the recruiter header.

**Refs:** PRD A-4 · Tasks PL-26, RC-22 · **Backend:** A · **Frontend:** C + D

---

## Epic 7: Job Posting

### US-34 · Paste JD → extracted requirements · Must
> As a **recruiter**, I want to paste a raw job description and have the requirements pulled out for me, so I don't have to tag skills by hand.

**Done when:**
- `parse-job` returns draft requirements in about 20 s or less.
- Progress is shown.

**Technical implementation**
- **Flutter:**
  - `NewJobScreen` has a multiline text field with a character counter (max about 20k) and calls `JobRepository.createDraft(rawText)`:
    1. Inserts `jobs(status 'DRAFT', raw_description, parse_status 'PENDING')`.
    2. Invokes `parse-job`.
    3. Watches `jobs.parse_status` through Realtime or polling.
- **Backend / AI:** `parse-job` Edge Function:
  1. Verifies the caller is a recruiter at the job's company.
  2. Sanitizes the text.
  3. `llm.extract(jobSchema)` returns the title, a requirements list (`raw`, `required_hint`, `min_years`, evidence), location, remote, and salary if stated.
  4. Normalizes skills (alias, then vector).
  5. Inserts draft `job_requirements` with default weights (required = 2, preferred = 1).
  6. Sets `parse_status 'READY'`.
  - There's no Document Intelligence step, because the input is plain text.
- **Tests:** Deno test using the mock provider with fixture job descriptions.

**Refs:** PRD §6.1 · Tasks AI-12, RC-08 · **Backend:** B · **Frontend:** D

### US-35 · Edit requirements · Must
> As a **recruiter**, I want to mark each skill Required or Preferred and set minimum years, so the Match Score reflects what I actually need.

**Done when:**
- The editor enforces 15 total and 8 required.
- Changes are saved.

**Technical implementation**
- **Flutter:**
  - `RequirementEditor` uses a `DataTable` (expanded) or a `ListView` of cards (compact).
  - The controller holds `List<RequirementDraft>`, and the limits are validated in the controller so the UI disables toggles past the limit.
  - "Add skill" uses the same taxonomy search as US-09.
  - Saving calls `rpc('save_requirements', {job_id, requirements jsonb})`.
- **Backend:**
  - `save_requirements` replaces the job's rows in one transaction and re-checks the limits server-side (a constraint trigger on count).
  - Recomputes `jobs.embedding` from the requirement skill names. A deferred call to the `embed` Edge Function, or an embedding computed from the average of the skill vectors in SQL, is fine for MVP.
- **Tests:**
  - Controller unit tests for the limits.
  - pgTAP: a 9th required skill is rejected.

**Refs:** PRD R-JOB-1, R-JOB-2 · Tasks RC-09a, RC-09b · **Backend:** A + B · **Frontend:** D

### US-36 · Set job hard filters · Must
> As a **recruiter**, I want to set location, remote, work authorization, and a salary range, so only eligible candidates see the job.

**Done when:**
- The fields are saved and used as hard filters in candidates' feeds.

**Technical implementation**
- **Flutter:** `JobDetailsForm`: location text, remote chips, job type, a "sponsorship available" toggle, and salary min and max (validated min ≤ max). The LLM's guesses (US-34) are pre-filled.
- **Backend:** Columns on `jobs` (`location`, `remote`, `job_type`, `sponsorship`, `salary_min`, `salary_max`), mirrored in the `get_feed` filters (US-12).

**Refs:** PRD §6.1 · Tasks RC-10 · **Backend:** A · **Frontend:** D

### US-37 · Publish / pause / close job · Must
> As a **recruiter**, I want to publish, pause, and close a job, so I control when it accepts applicants.

**Done when:**
- The lifecycle is DRAFT → OPEN ⇄ PAUSED → CLOSED.
- Closing moves open applications to Job Closed.

**Technical implementation**
- **Backend:**
  - `set_job_status(job_id, status)` validates the transition and requires at least 1 requirement to publish.
  - Sets `published_at` and `expires_at = published_at + 60 days`.
  - On `CLOSED`, it updates the non-terminal applications to `JOB_CLOSED` and writes `status_events`.
  - A `pg_cron` daily job closes expired jobs.
- **Flutter:** The job header has a status menu, with a confirm dialog for Close.
- **Tests:** pgTAP: closing cascades, and an invalid transition (CLOSED → OPEN) raises.

**Refs:** PRD R-JOB-4 · Tasks RC-11, PL-19 · **Backend:** A · **Frontend:** D

### US-38 · Jobs list with counts · Must
> As a **recruiter**, I want a list of my company's jobs with applicant counts, so I can see where to focus.

**Done when:**
- The list shows each job's status and its new and total applicant counts.

**Technical implementation**
- **Backend:**
  - A `company_jobs_overview` view (`security_invoker = true`) with `count(*) filter (where status = 'APPLIED' and committed_at <= now())` as `new_count` and the total, scoped by RLS to the recruiter's company.
- **Flutter:** `JobsListScreen` uses a `ListView` (compact) or a table (expanded) with `StatusChip` and count badges, plus a "New job" FAB or button and pull-to-refresh.

**Refs:** PRD §6 nav · Tasks RC-06, RC-11 · **Backend:** A · **Frontend:** D

### US-39 · Re-score on requirement edit · Should
> As a **recruiter**, I want scores to update when I edit a live job's requirements, so the ranking stays fair.

**Done when:**
- Existing applications are re-scored.
- A "Scores updated" banner appears.

**Technical implementation**
- **Backend:**
  - The `save_requirements` RPC, when the job is `OPEN` or `PAUSED`, runs `update applications set (match_score, breakdown, scoring_version) = (select … from compute_match(profile_version_id, job_id))` for the job's non-terminal applications.
  - Sets `jobs.rescored_at = now()`.
  - Fine for MVP sizes (fewer than 5k rows). For larger sizes, move it to a background job.
- **Flutter:** The board shows a dismissible banner when `jobs.rescored_at > last_viewed_at`.
- **Tests:** pgTAP: changing a weight changes the stored scores and the order.

**Refs:** PRD R-JOB-3 · Tasks AI-18 · **Backend:** B · **Frontend:** D

---

## Epic 8: Mosaic Board (Triage)

### US-40 · Board sorted by Match Score · Must
> As a **recruiter**, I want applicants shown as tiles sorted by Match Score, so I can find my strongest candidates in seconds.

**Done when:**
- `get_board` returns tiles sorted by score, ties broken by earliest application.
- The grid is responsive.

**Technical implementation**
- **Backend:**
  - `get_board(p_job_id, p_filters jsonb, p_limit, p_offset)`, `security definer`.
  - Checks that the caller is a recruiter at the job's company.
  - Returns non-terminal, committed applications ordered by `match_score desc, committed_at asc`, with blind tile JSON (US-41).
- **Flutter:**
  - `BoardController` is paginated (50 per page, infinite scroll).
  - `MosaicGrid` uses `SliverGrid` with `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 320)`, giving 1–5 columns.
  - Removing a tile animates through a keyed `AnimatedSwitcher` or `implicitly_animated` list.
  - A Realtime subscription on `applications` filtered by `job_id` inserts new applicants live, keeping the sort.

**Refs:** PRD R-TRI-2 · Tasks AI-16, RC-12, RC-14 · **Backend:** A · **Frontend:** D

### US-41 · Blind tiles · Must
> As a **recruiter**, I want tiles to hide names, photos, and schools, so I judge candidates on skills without bias.

**Done when:**
- Tiles show only the handle, score, skills, gaps, and years.
- The data layer never returns identity before advancing.

**Technical implementation**
- **Backend (the enforcement):**
  - `get_board` builds JSON from **only** safe columns: `handle` (e.g., `'◆ ' || upper(substr(md5(application_id::text), 1, 4))`), `match_score`, the top 3 matched skills and 2 gaps from `breakdown`, and total years.
  - Recruiters have **no** RLS select policy on `profiles`, `candidates`, `profile_versions`, `resumes`, or Storage, so identity can't leak through any other query.
- **Flutter:** The `CandidateTile` model simply has no name field before advance. The interview list (US-47) uses a different model.
- **Tests:** pgTAP: a recruiter selecting from `candidates` or `profiles` of applicants returns 0 rows, and the `get_board` JSON keys are exactly the allowed set.

**Refs:** PRD R-TRI-1 · Tasks AI-16, RC-12 · **Backend:** A · **Frontend:** D

### US-42 · Candidate detail view · Must
> As a **recruiter**, I want to open a candidate's detail with the radar chart and skill evidence, so I can verify the match.

**Done when:**
- The detail view opens.
- The status changes to Under Review.

**Technical implementation**
- **Backend:**
  - `get_candidate_detail(application_id)` returns the blind payload plus the full `breakdown` and each skill's evidence snippet. It returns identity fields only if the status is `INTERVIEW_REQUESTED`.
  - `open_application(application_id)` moves `APPLIED → UNDER_REVIEW` (idempotent) and writes `status_events`.
- **Flutter:**
  - `CandidateDetailScreen` (or a side panel on expanded layouts) reuses `RadarDeepDive` (from US-23) with the "Candidate" legend, plus an evidence list and the advance and reject actions.
- **Tests:** pgTAP: opening twice writes only one event.

**Refs:** PRD §6.2 · Tasks RC-15, AI-16, PL-19 · **Backend:** A · **Frontend:** D

### US-43 · One-click advance · Must
> As a **recruiter**, I want to advance a candidate to interview with one click, so I can move fast on good fits.

**Done when:**
- The teal ▲ moves the application to Interview Requested, reveals identity and contact, and notifies the candidate.

**Technical implementation**
- **Backend:**
  - `advance(application_id, note text default null)` validates the transition (from `APPLIED` or `UNDER_REVIEW`).
  - Sets the status, `advanced_by`, and `interview_note`, and writes `status_events`.
  - Realtime and push (US-26, US-27) fire from the update and event.
- **Flutter:**
  - The `TriangleActions` ▲ tap opens an optional note popover ("Add a note?", skippable). The call is optimistic: the tile flies to the Interview list and rolls back on error.
- **Tests:** pgTAP: transitions, and a recruiter from another company is denied.

**Refs:** PRD §6.2 · Tasks PL-19, RC-13, RC-14 · **Backend:** A · **Frontend:** D

### US-44 · One-click reject with undo · Must
> As a **recruiter**, I want to reject a candidate with one click and a short undo window, so I can clear my board quickly without mistakes.

**Done when:**
- The red ▼ moves the application to Not Selected, removes the tile, and offers a 10 s undo.
- The candidate sees "Not selected".

**Technical implementation**
- **Backend:**
  - `reject(application_id, reason text default null)` stores `reject_reason` (internal only, never exposed to candidate queries) and sets `NOT_SELECTED` and `rejected_at`.
  - `undo_reject(application_id)` restores `previous_status` only `where rejected_at > now() - interval '10 seconds'`.
  - The candidate's RLS select on `applications` uses a view that excludes `reject_reason`. Alternatively, `reject_reason` lives in a separate recruiter-only table, which is the safer option.
- **Flutter:**
  - The ▼ tap removes the tile with an animation, then shows a SnackBar "Not a fit · Undo" for 10 s.
  - An optional reason menu offers internal analytics reasons.
- **Tests:**
  - pgTAP: undo within and after the window.
  - A candidate can't read `reject_reason`.

**Refs:** PRD R-TRI-4, R-TRI-5 · Tasks PL-19, RC-13, RC-14 · **Backend:** A · **Frontend:** D

### US-45 · Touch-friendly tile actions · Must
> As a **recruiter on a phone**, I want to tap tiles to show the action buttons, so I can triage without a mouse.

**Done when:**
- A tap toggles the triangles.
- A long-press opens the detail view.

**Technical implementation**
- **Flutter:**
  - `CandidateTile` is wrapped in a `MouseRegion` (hover → show actions on web or desktop) and a `GestureDetector` (`onTap` → toggle `showActions`, `onLongPress` → detail).
  - `TriangleActions` uses a `ClipPath` triangle inside a 48×48 `InkWell` hit area. Only one tile shows actions at a time (a `selectedTileProvider`).
  - The mode is picked by pointer kind and breakpoint, not by `Platform`.
- **Tests:** Widget tests for tap → actions visible and long-press → navigates.

**Refs:** PRD §6 platform · Tasks RC-13 · **Backend:** — · **Frontend:** D

### US-46 · Board filters · Should
> As a **recruiter**, I want to filter the board by skill or years, so I can narrow a big pool without losing the ranking.

**Done when:**
- Filters narrow the list but never re-order it.

**Technical implementation**
- **Backend:** `get_board`'s `p_filters` (`{has_skill_ids: [], min_total_years: n, min_score: n}`) are applied as `WHERE` clauses using `breakdown @> …` / jsonb path queries. The `ORDER BY` is unchanged.
- **Flutter:** A filter chip row above the grid (skills drawn from the job's requirements). The filter state is stored in the query parameters so it survives refresh on web.

**Refs:** PRD R-TRI-2 · Tasks RC-17, AI-16 · **Backend:** A · **Frontend:** D

### US-47 · Interview list · Must
> As a **recruiter**, I want a list of candidates I've advanced, so I can follow up with them.

**Done when:**
- The list shows advanced candidates with full identity and a resume link.

**Technical implementation**
- **Backend:**
  - `get_interview_list(job_id)` returns applications in `INTERVIEW_REQUESTED` with `display_name` and email (`security definer` join to `profiles` and `auth.users`).
  - `get_resume_url(application_id)` returns `storage.create_signed_url('resumes', path, 600)`. The URL can only be signed through the Edge Function or service role, so implement this as a tiny Edge Function `resume-url` that checks the status and returns a 10-minute signed URL.
- **Flutter:**
  - `InterviewListScreen` shows a name, score, "Email" (`mailto:`), and "Resume" (`url_launcher` opens the signed URL).

**Refs:** PRD §6 nav, X-4 · Tasks RC-16, PL-23 · **Backend:** A · **Frontend:** D

### US-48 · Keyboard triage shortcuts · Should
> As a **recruiter on a laptop**, I want keyboard shortcuts (J/K/A/R), so I can triage dozens of tiles quickly.

**Done when:**
- The shortcuts work and are listed in a "?" help dialog.

**Technical implementation**
- **Flutter:**
  - The board is wrapped in `Shortcuts` + `Actions`, with `SingleActivator(LogicalKeyboardKey.keyJ)` etc. mapped to intents such as `NextTileIntent` and `AdvanceIntent`.
  - Focus is managed with a `FocusNode` per tile and a visible focus ring (`matchStrong`).
  - `?` opens the help dialog.
  - The shortcuts are disabled while a text field has focus.
- **Tests:** Widget test sending key events with `tester.sendKeyEvent`.

**Refs:** PRD R-TRI-3 · Tasks RC-19 · **Backend:** — · **Frontend:** D

---

## Epic 9: Privacy & Trust

### US-49 · Resume privacy until advanced · Must
> As a **candidate**, I want my resume visible only to recruiters who advanced me, so my personal details aren't widely exposed.

**Done when:**
- Storage policies block other access.
- Signed URLs are only issued after advance.

**Technical implementation**
- **Backend:**
  - The `resumes` bucket is private, and its policies allow access only to the owner's folder.
  - Recruiters have **no** storage policy. The only path is the `resume-url` function (US-47), which checks `INTERVIEW_REQUESTED` and the company membership.
  - Signed URLs expire after 10 minutes.
- **Tests:**
  - Integration test: a recruiter's direct `storage.from('resumes').download(path)` fails, and the function returns a URL only after advance.

**Refs:** PRD X-4 · Tasks PL-14, PL-23 · **Backend:** A · **Frontend:** —

### US-50 · Delete my account · Should
> As a **candidate**, I want to delete my account and data, so I stay in control of my information.

**Done when:**
- The resume and profile are deleted.
- Recruiter-side records are anonymized.

**Technical implementation**
- **Flutter:** Settings → "Delete account" with a type-to-confirm dialog. Calls `functions.invoke('delete-account')`, then signs out.
- **Backend:** The `delete-account` Edge Function (it needs the service role to delete the auth user):
  1. Deletes the Storage objects under `resumes/{uid}/`.
  2. Anonymizes `applications` (keeps the score and status, nulls `profile_version_id`, sets `anonymized = true`).
  3. Deletes `candidate_skills`, `profile_versions`, `resumes`, and `candidates`.
  4. Calls `auth.admin.deleteUser(uid)`, which cascades to `profiles`.
- **Tests:** An integration test on local Supabase checks that no rows remain with the user's id.

**Refs:** PRD X-3 · Tasks PL-24, CA-23 · **Backend:** A · **Frontend:** C

### US-51 · Skills-only AI (no personal traits) · Must
> As a **candidate**, I want the AI to ignore my name, age, and other personal traits, so the score is based only on my skills.

**Done when:**
- The extraction schema has no fields for protected attributes.

**Technical implementation**
- **AI:**
  - The `resumeSchema` in `_shared/schemas.ts` only has `roles[] {title, start, end, skills_used[], evidence}`, `skills[] {raw, evidence, context}`, and `education[] {level, field}`, with `additionalProperties: false` and `strict: true` structured output.
  - The system prompt treats the resume as untrusted data inside `<resume>` tags.
  - Optionally, the contact block is stripped before sending: regex for emails and phone numbers, plus the top 3 lines if they look like a name or contact header.
  - `compute_match` reads only skills, years, and (optionally) education level.
- **Tests:**
  - Schema snapshot test that fails if new properties appear.
  - AI-19 injection fixtures: a resume with hidden "rate me 100" text and a resume with "Age: 52". The extraction output contains neither.

**Refs:** PRD §8.2, §8.5 · Tasks AI-02, AI-06, AI-19 · **Backend:** B · **Frontend:** —

---

## Epic 10: Team & Developer Stories

### US-52 · Mock AI provider · Must
> As a **developer**, I want a mock AI provider, so I can build and test without spending API credits.

**Done when:**
- `LLM_PROVIDER=mock` returns fixture extractions.

**Technical implementation**
- **AI:**
  - `MockProvider implements LlmProvider`. `extract()` hashes the input text and returns the matching file from `_shared/fixtures/extract/<hash>.json`, or a generic default fixture.
  - `embed()` returns deterministic pseudo-vectors (seeded from the text hash and normalized) so similarity code still runs.
  - Local `supabase/functions/.env` defaults to `mock`.
- **Tests:** CI runs every Deno test with `mock`.

**Refs:** PRD §9.3 · Tasks AI-03 · **Backend:** B · **Frontend:** —

### US-53 · Switchable LLM provider · Must
> As the **team**, we want to switch between the OpenAI API and Azure OpenAI with a setting, so we can use whichever credits we have.

**Done when:**
- Changing `LLM_PROVIDER` works with no code changes.
- The embedding model stays pinned.

**Technical implementation**
- **AI:**
  - `getProvider()` reads `LLM_PROVIDER`.
  - `OpenAIProvider` uses `new OpenAI({apiKey})`. `AzureOpenAIProvider` uses `new AzureOpenAI({endpoint, apiKey, apiVersion, deployment})`. Both come from `npm:openai`.
  - Both use `chat.completions.create` with `response_format: {type: 'json_schema', json_schema: {name, schema, strict: true}}` and `embeddings.create({model: LLM_EMBED_MODEL})`.
  - On startup, assert `LLM_EMBED_MODEL === 'text-embedding-3-small'` unless `ALLOW_EMBED_MODEL_CHANGE=true`.
  - Every call is logged to `llm_usage` and checked against `LLM_DAILY_TOKEN_BUDGET`.
- **Tests:** A contract test runs the same fixture through both providers (opt-in, costs credits) and checks the outputs validate against the schema.

**Refs:** PRD §9.3 · Tasks AI-09, AI-13 · **Backend:** B · **Frontend:** —

### US-54 · Realistic seed data · Must
> As a **presenter**, I want realistic fake candidates, jobs, and applications, so the demo looks alive from the first screen.

**Done when:**
- `supabase db reset` loads data covering every status and score band, plus the demo accounts.

**Technical implementation**
- **Generation:**
  - `scripts/generate_seed.ts` (Deno) uses a fixed random seed. It creates candidates with skill sets drawn to hit each score band per job, then calls `compute_match` logic in TypeScript, or runs the SQL after insert.
  - Writes `supabase/seed.sql` with explicit UUIDs and **precomputed embeddings** as literals.
- **Demo users:**
  - Inserted into `auth.users` with `crypt('<password>', gen_salt('bf'))` and `email_confirmed_at = now()`, plus matching `auth.identities` rows, so email login works locally.
  - Credentials are kept in `seed.sql` and the README's local-dev section only.
- **Data:** Every seed row has `is_seed = true`.
- **Tests:** CI runs `supabase db reset` followed by a `select` smoke check that counts per status are at least 1.

**Refs:** PRD §9.8 · Tasks PL-16, AI-11, AI-20 · **Backend:** B + A · **Frontend:** —

### US-55 · Fake repositories in Flutter · Must
> As a **developer**, I want fake repositories in the Flutter app, so I can build screens before the backend is finished.

**Done when:**
- Every repository has a fake implementation, switchable with one provider override.

**Technical implementation**
- **Flutter:**
  - Each repository is an abstract class (`abstract interface class FeedRepository`) with `SupabaseFeedRepository` and `FakeFeedRepository` implementations.
  - Providers return the real one by default.
  - `main_fake.dart` runs with `ProviderScope(overrides: [feedRepositoryProvider.overrideWithValue(FakeFeedRepository()), …])`. Run it with `flutter run -t lib/main_fake.dart`.
  - Fakes use in-memory lists, an artificial delay (300 ms), and a toggle to simulate errors, so every UI state can be built.
  - Tests reuse the same fakes.

**Refs:** TEAM_PLAN §1 · Tasks CA-02, RC-03 · **Backend:** — · **Frontend:** C + D
