# Person A delivery log

Source: docs/TASKS.md, A1–A10 (Core and Later). A11 push notifications are excluded by the user (October 20). There is no docs/claude.md.
Deadline: Thursday, October 22, 2026, America/Chicago.
Commits use their actual execution date. No backdating or empty commits.

## Schedule

| Date and time (Central) | Scope | Planned commits |
|---|---|---|
| Tue Oct 20, current session | A1 setup; A2 schema, policies, contract | 2 |
| Wed Oct 21, 9 AM | A3 identity and access; A4 companies/invites | 1–2 |
| Wed Oct 21, 3 PM | A5 storage/profile/preferences; A6 local seed/README | 1–2 |
| Thu Oct 22, 9 AM | A7 swipe/undo/cap; A8 blind board/status RPCs | 1–2 |
| Thu Oct 22, 3 PM | A9 live updates/resume links/tests; A10 deletion/verification; final validation | 1–2 |

Target roughly two meaningful commits a day; combine related blocks only when
needed for a working, tested unit. Complete work on the date it is scheduled.
If a prior run was missed, catch up before the Thursday deadline; never claim
untested or externally blocked acceptance criteria as complete.

## Current state

- Repository cloned from https://github.com/hope-mcmillen/project5.
- A1: local CLI config and CI/review templates implemented. Supabase starts locally.
  Hosted CLI access and the approved database/two-function deployment are verified. Google OAuth activation and GitHub admin setup remain unverified.
- A2: three schema/RLS migrations and the Person A API contract draft implemented;
  local reset, lint and 42 access tests pass. Team contract approval remains pending.
- A3–A4: implemented, verified and merged into shared master (PR #3).
- A5–A6: implemented, verified and merged into shared master (PR #2).
- A7–A8: implemented, CI verified, and merged by the team in PR #8.
- A9–A10: implemented, CI verified, pushed in PR #9 and deployed to the hosted dev project with explicit approval; frontend acceptance remains pending.
- A11: out of scope per user, not completed.
- Keep personal work on feature branches; do not merge master without required review.
- Person B's work was merged into `origin/master` as `db084f3` (PR #1).
  The new A3 branch includes that merge plus A1/A2 replayed on top; B's AI files
  are preserved. Existing published A1/A2 branches were not rewritten.

## External setup and acceptance blockers

These require authenticated account access or teammate input, not just code:

- Supabase dev URL: https://ehgogfdaxmwnqfogjvmk.supabase.co (project ref `ehgogfdaxmwnqfogjvmk`). URL supplied by user; remote credentials/access and anon or publishable key are not yet configured.
- Google OAuth client credentials and provider activation. Email works locally;
  Google is intentionally disabled until real credentials are provided.
- GitHub Project board and master protection (one approving
  review plus green CI). CODEOWNERS now uses the supplied team handles; required review and
  auto-request behavior still depend on merging it and repository settings.
- Team API freeze/review by C and D; cross-team full-loop rehearsal.
- Push notifications / Firebase / FCM are excluded by the user; do not request FCM credentials or implement A11.
- B5 embeddings / B8 scoring are integrated from master. Confirmed profiles and swipes use B's actual centroid/scorer; deterministic and real API loop checks pass.

## Verification

Record commands and actual outcomes here after each run. A feature is not fully
accepted until its Done when criteria in TASKS.md are verified. Preserve failures
and remaining dependencies explicitly.

### Tuesday, October 20 — actual results

- Setup commit: `e47fa51`, branch `feat/A1-backend-foundation`.
- Schema/API work continues on `feat/A2-schema-contract`, based on that commit.
- Supabase CLI 2.121.0 downloaded to `/private/tmp/project5-tools/supabase`.
- Docker started; `supabase start` successfully starts the local stack.
- `supabase db reset --local`: all three migrations and seed placeholder pass.
- `supabase db lint --local --level error`: no schema errors.
- `supabase test db`: 42 assertions pass (anonymous denial, self/company isolation,
  no role/state bypass, pending application privacy, views and Realtime setup).
- `flutter analyze`: no issues. `flutter test`: all 8 tests pass.
- Generated schema types are in `supabase/types/database.types.ts`; keep them
  outside B's `_shared/` directory to respect team ownership. No Flutter models
  changed because those belong to C.
- App heartbeat automation `complete-project5-person-a-by-thursday` is ACTIVE
  for Wed/Thu at 9 AM and 3 PM Central, four runs total. Keep this computer on
  and Codex running at those times. Stop the automation after the final report.
- Google OAuth credentials, hosted Supabase access and GitHub admin
  setup remain explicit external acceptance dependencies.

### User configuration received October 20

- Person A: @MarcusReese1 (existing Git author / authenticated push identity).
- Person B: @kamarceneaux; Person C: @hope-mcmillen; Person D: @k6iith.
- Hosted project URL supplied above. A URL alone does not grant deployment access.
- GitHub API check confirms push access and no admin/maintain access. The repository owner must configure protected branches and other admin-only settings.
- User says "No notis": omit A11 and Firebase/FCM setup. Do not mark A11 completed.
- The supplied team CODEOWNERS configuration and follow-up delivery notes are
  included with Wednesday's first scheduled work commit.

### Wednesday, October 21 — account/company run

- Branch: `feat/A3-account-company-onboarding`, based on `origin/master`
  `db084f3` with A1/A2 replayed (`7029619`, `d8401d3`); the originally published
  branches remain intact. This is one meaningful onboarding commit covering
  A3/A4; the afternoon A5/A6 batch is intended as today's second commit.
- A3: signup trigger, safe role metadata handling, existing-user backfill,
  serialized one-time role choice. Existing A2 role/company helpers are reused.
- A4: company creation, owner/member access, random 8-character invites, expiry,
  use caps, revocation and lowercase/whitespace normalization.
- `supabase db reset --local`: all A and merged B migrations apply.
- `supabase db lint --local --level error`: no schema errors.
- `supabase test db`: 158 assertions pass across four test files, including
  B's 27 feed checks. Its profile fixture now upserts after the signup trigger.
- `python3 supabase/tests/company_concurrency.py`: four real concurrent-session
  race checks pass (role selection, creation, multiple-company joins, invite cap).
- `python3 supabase/tests/auth_smoke.py --supabase /private/tmp/project5-tools/supabase`:
  actual local Auth signups + PostgREST role/company/invite checks pass. All test
  users/companies are synthetic and removed afterward. No hosted writes.
- A company test initially used fixture codes containing the forbidden letter L;
  corrected those fixture codes. No failing assertions remain.
- Generated database types refreshed for merged B RPCs and A3/A4. CI now runs
  the concurrency and real Auth/API smoke tests as well as pgTAP.
- Published commit `ed352c0` on `origin/feat/A3-account-company-onboarding`.
- GitHub Backend checks PASSED for that exact commit:
  https://github.com/hope-mcmillen/project5/actions/runs/39648320373
- This CI evidence was added after publishing; include the delivery-log update
  in the next scheduled work commit. Required teammate review remains pending.
- Google provider enablement/hosted auth and admin-only GitHub settings remain
  external gates; A10 domain verification remains scheduled for Thursday.

### Wednesday, October 21 — profile/storage/demo run

- Branch: `feat/A5-profile-storage-demo`, based on published A3/A4 `ed352c0`.
- A5: private immutable resume uploads, owner-only company logo writes,
  serialized manual versions, transactional confirmation with reviewed skill
  validation/provenance/centroid, and strict preference replacement.
- A6: loads B's 343 skills/132 relations/precomputed vectors/demo world without
  modifying B's generated files. Local seed creates usable email identities for
  two documented demo accounts; 3 companies, 30 candidates, 4 recruiters and 60
  applications across all six statuses are verified. One company is verified.
- Caught and fixed the interaction where A3's trigger creates candidate rows
  before B's seed reaches them: A's seed now marks those rows `is_seed=true`.
- README rewritten with local setup, Android emulator addressing, defines,
  provider selection, test commands and the frontend scaffold limitation.
  Credentials appear only in seed.sql and README's local-dev section.
- Clean local database reset passes all migrations and four ordered seed files.
- `supabase test db`: 239 assertions pass across six files.
- `company_concurrency.py`: all six real concurrent-session checks pass, now
  including manual version numbering and immutable confirmation.
- `auth_smoke.py`: real local signup/role/company/invite checks pass.
- `profile_storage_smoke.py`: both seeded logins pass; real profile confirmation
  and preferences pass; private PDF upload/exact owner download pass; other
  candidates, recruiters, public URLs, cross-folder uploads, invalid MIME types
  and oversized uploads are denied. Synthetic test users/objects are removed.
- CI now runs the Storage/demo-login checks as well. Generated database types
  refreshed. Hosted project writes were not performed.
- Frontend main.dart still does not initialize Supabase; the README explicitly
  identifies this C/D integration dependency rather than claiming a full UI demo.

- Published afternoon commit `b64242e` on
  `origin/feat/A5-profile-storage-demo` (Wednesday's second implementation commit).
- GitHub Backend checks PASSED for that exact commit:
  https://github.com/hope-mcmillen/project5/actions/runs/39652623535
- This final CI evidence is saved locally after publishing; include the progress
  log update in Thursday's first work commit. Continue from the A5 feature branch.

### User-requested update and app launch (October 21)

- Pulled/fast-forwarded local `master` to `origin/master` `973fc16`, preserving
  the uncommitted CI evidence in this log. A3/A4 and A5/A6 are now merged into
  shared master (PRs #3/#2); D1–D4 are also merged (PRs #4–#7).
- D's main.dart now initializes Supabase; the earlier frontend initialization
  blocker in this historical log is superseded. New auth/routing/company screens
  are present. Continue Thursday's A7 work from this latest shared code.
- Created ignored `env/dev.json` using the running local backend's public anon
  key; no service-role/Gemini secrets are included in the Flutter configuration.
- App running at http://127.0.0.1:5210 via Flutter web-server; verified the new
  ResuRhombus welcome screen visibly in the in-app browser. No extra commit made.

### Thursday, October 22 — applications/recruiter run

- Branch: `feat/A7-applications-board`, based on merged master `b9a54d4`
  (includes the team's latest app logging update). Local CI evidence from
  Wednesday and the app-launch notes are preserved.
- A7: swipe/pass/reasons, five-second undo, UTC daily cap, real B v2 scorer and
  immutable application profile/score snapshots. No 50-point matching stub.
- A8: state changes, private rejection reasons, ten-second reject undo, candidate
  withdrawal/contacts, exact-key blind board/detail and interview listing.
- A-owned job requirements/lifecycle RPCs validate caps, build B centroids,
  re-score live nonterminal applicants with B's formula and cascade closure.
- Local clean reset/lint pass. `supabase test db`: 402 assertions across eight
  files pass, including the full transition matrix, 26th apply, UTC cap rollover,
  long-transaction undo expiry, privacy/ownership and job lifecycle/rescoring.
- Four independent-session application races pass: final cap slot, duplicates,
  competing reject/withdraw and closing a job during apply.
- Real local Auth/PostgREST loop passes: publish→confirm→apply→pending privacy→
  blind board→review/advance→identity/contact→reject/undo→withdraw.
- Existing onboarding/profile/storage/seed checks are included in final validation.
- Early test harness used a nonexistent pgTAP `unlike` helper; changed those
  assertions to `ok(... not like ...)`. Product checks all pass.
- User confirmed Supabase dashboard access on October 21. Deployment-tool
  authentication and final hosted-write approval remain separate; no remote
  Supabase writes were made. C/D live board integration and admin-only GitHub
  settings remain external acceptance gates.
- A9/A10 implementation note: account deletion must detach `applications.swipe_id`
  before removing candidate swipes; otherwise the existing FK cascade would
  remove applications that should be retained anonymized.

- Final clean-reset validation passes all prior onboarding/storage checks plus
  the new loop/race tests. Flutter analyze is clean and all 61 Flutter tests pass.
  No Dart or B-owned AI implementation files were edited by this batch.

- Published Thursday morning commit `c289ba1` to
  `origin/feat/A7-applications-board`; draft review PR:
  https://github.com/hope-mcmillen/project5/pull/8
- GitHub Backend checks PASSED for that exact commit:
  https://github.com/hope-mcmillen/project5/actions/runs/39787629520
  PR-triggered backend/Android checks were still running when recorded; their
  results are not claimed here. No merge or hosted deployment was performed.
- This post-push delivery evidence is intentionally saved locally for inclusion
  in Thursday afternoon's second meaningful commit. Continue from this branch,
  preserve the log update, and implement A9/A10 with final acceptance validation.


### Thursday, October 22 — final run brought forward at user request

- User requested completion now, so A9/A10 work was brought forward from the
  afternoon slot. Branch `feat/A9-A10-privacy-final` starts at team-merged master
  `49d5e96` (PR #8). Preserved morning delivery evidence. This is Thursday's
  second meaningful implementation commit; no empty or backdated commits.
- A9: `resume-url` verifies JWT, authorizes the recruiter's own advanced,
  committed application through caller-scoped `get_resume_access`, resolves the
  applied profile snapshot's resume and signs with the admin Storage client for
  600 seconds. Public origin is configured for local containers; no identity or
  service credentials enter the app. Rejection blocks new links, while issued
  bearer links expire naturally or stop working after file deletion.
- A9: actual socket clients cover application updates and resume parse progress
  for the owning candidate, job updates for the owning company, and absence of
  those events for another candidate/company. This automates the Studio check.
  The five-second commit deadline does not emit another insert: the recruiter
  client must refetch after the deadline and after reconnecting.
- A10: soft verification uses confirmed email and exact lowercased website host
  matching, strips `www.`, denies common free-mail hosts, and recomputes the badge
  on website edits. Existing feed/pipeline surfaces already carry the badge.
- A10: deletion first locks/clears private database data, detaches swipe FKs and
  anonymizes retained applications, then drains every owned Storage page and
  hard-deletes Auth last. Retry after partial cleanup is verified. A key-share
  permission lock makes deletion wait for active uploads; later uploads fail.
  Private rejection text, interview notes, score breakdown evidence, identifiable
  actors, usage/device rows, profile versions/skills/resumes and orphan files are
  removed. Aggregate application/status records remain anonymized.
- All 112 Edge unit/mock tests pass; six live Gemini tests intentionally skipped
  (no hosted AI calls). New handler tests cover authentication, authorization,
  signing TTL, deletion order, body-selected victim rejection and failure handling.
- Real local Edge/Auth/Storage integration passes: signed PDF download only after
  advance; anonymous/candidate/cross-company/pending/unadvanced/rejected denial;
  multi-client live-event privacy; deletion across 107 files; no remaining private
  rows/files/Auth; retained application anonymized; old link no longer serves PDF.
- All prior company/profile/apply concurrency and real Auth/API/Storage smoke
  checks pass. Flutter analysis is clean and all 61 tests pass. Generated types,
  API/PRD/schema/README/task status and CI are updated. No Dart or B-owned AI files
  were edited.
- Test corrections: synthetic verified seed must survive trusted seed updates;
  resume progress fixture uses `PARSING_LAYOUT`, not nonexistent `PARSING`.
  One combined live-event assertion timed out; split diagnostics and isolated
  rerun exposed the cold-start cause: channel join precedes PostgreSQL subscription
  installation. The harness now waits for the database system acknowledgement.
  A fresh-reset rerun passes with that fix; no timing sleeps were used to conceal it.
- Final clean reset and all 421 pgTAP assertions pass across nine files. Schema
  lint is clean. Real privacy/Realtime/deletion integration passes immediately
  after reset, including 107 files. Upload/deletion race check passes.
- Completed the remaining non-admin A1 label setup through GitHub: verified all
  59 labels (owner:A–D plus story:US-01–US-55), creating the missing ones.
  Project board/protection enforcement still requires owner/admin action.
- Confirmed app URL/key fields and the private server env file are already
  present without printing secrets. Local tests inject local keys; no hosted
  database password or service-role key belongs in the Flutter app.
  GitHub publication/CI results follow.

## Final acceptance audit (A1–A10)

| Block | Verified evidence | Remaining acceptance/dependency |
|---|---|---|
| A1 | Local services/config; reset/lint/test CI; review template/CODEOWNERS; all 59 owner/story labels | Hosted Google OAuth/provider settings and owner-admin Project/protection/auto-review enforcement unverified |
| A2 | Full schema/RLS, generated types, documented contract; clean reset and CI | Explicit C/D team contract approval/freeze remains a team gate |
| A3 | Actual Auth role signups, one-time role selection, isolation and concurrency tests | Hosted Google sign-in remains unverified |
| A4 | Company/invite creation/join/revoke, ownership and cap races; merged | No backend implementation blocker; hosted rehearsal pending |
| A5 | Private upload/read boundaries, confirmed immutable profiles/preferences; actual Storage/API tests | C's complete onboarding UI integration/rehearsal pending |
| A6 | Working local demo logins; deterministic taxonomy/vectors/world; current README | Fresh-teammate setup and full demo rehearsal remain unobserved |
| A7 | Apply/pass/reasons, five-second undo, UTC 26th-apply denial and real-scoring/concurrency tests; merged | C's complete deck/pipeline integration and hosted rehearsal pending |
| A8 | Blind exact-key board/detail, transitions/reject undo/withdraw/contact, company isolation and job lifecycle; merged | D's complete board/interview UI integration and hosted rehearsal pending |
| A9 | Real signed links, multi-client live updates/isolation and full loop rules in CI | C/D subscription/deadline-refetch wiring and full-loop rehearsal pending |
| A10 | Confirmed-domain verification; real retryable deletion, pagination, no-private-data and upload race tests | C's deletion UI/confirmation flow pending |

A1–A10 backend implementation is present; **not all end-to-end acceptance criteria
are complete**. The implementation handoff initially left hosted deployment
pending. The user subsequently signed in and explicitly approved the 17 migrations
and two functions; that deployment is now verified below. No demo seed or secret
changes were included. Google OAuth needs real provider configuration;
GitHub admin controls require the owner. A11 is excluded, not completed. Required
cross-boundary reviews and shared-device/demo rehearsal remain team work.

The scheduled work is superseded by this final run. Disable the heartbeat after
publishing and recording final check results so it does not make duplicate commits
later today. Final delivery/CI and automation-stop evidence follows below.


### Approved hosted deployment — October 22

- User confirmed CLI sign-in. Read-only project listing verified access to
  `ehgogfdaxmwnqfogjvmk`. A migration dry-run identified all 17 migrations pending.
- The user explicitly answered **yes** to deploying those 17 migrations and the
  `resume-url` / `delete-account` functions, with no demo seed or secret changes.
- All 17 migrations applied successfully using `--skip-vault`; a subsequent
  read-only dry-run reports the remote database up to date with no pending items.
- Deployed exactly the two approved functions from code commit `f842ae4`, both
  ACTIVE, version 1, with `verify_jwt=true`. No B-owned parse functions deployed.
- Hosted schema lint passes with zero error results. Both public function URLs
  return 401 for unauthenticated POST and 200 with CORS headers for browser
  preflight. No hosted test users/files or demo seed were created. Positive
  authenticated application/deletion coverage remains the real local test suite;
  hosted full-loop rehearsal still requires actual taxonomy/data and app wiring.
- Supabase dashboard:
  https://supabase.com/dashboard/project/ehgogfdaxmwnqfogjvmk/functions
- Backend GitHub checks passed for `f842ae4` (both branch and PR runs):
  https://github.com/hope-mcmillen/project5/actions/runs/39795526579
  https://github.com/hope-mcmillen/project5/actions/runs/39795662736
  Android build was still running when recorded; its final result is not claimed.
- Final draft review PR: https://github.com/hope-mcmillen/project5/pull/9
  No master merge was performed by this run.
- Automation `complete-project5-person-a-by-thursday` was deleted after the final
  implementation was brought forward; it will not repeat the afternoon work.
- This follow-up commit records deployment evidence only, after Thursday's two
  implementation commits. It does not change the deployed source or secrets.
