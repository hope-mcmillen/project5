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
  Hosted project URL is known; authenticated project access, Google OAuth activation and GitHub admin setup remain unverified.
- A2: three schema/RLS migrations and the Person A API contract draft implemented;
  local reset, lint and 42 access tests pass. Team contract approval remains pending.
- A3–A4: backend implemented, locally verified and passing GitHub CI; teammate review pending.
- A5–A6: backend/storage, demo login setup and README implemented and locally verified; CI/review pending.
- A7–A10: scheduled; not yet implemented.
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
- GitHub Project board, owner/story labels and master protection (one approving
  review plus green CI). CODEOWNERS now uses the supplied team handles; required review and
  auto-request behavior still depend on merging it and repository settings.
- Team API freeze/review by C and D; cross-team full-loop rehearsal.
- Push notifications / Firebase / FCM are excluded by the user; do not request FCM credentials or implement A11.
- B5 embeddings / B8 scoring are integrated from master. A5 confirms reviewed profiles with B's centroid; the seed-score checks validate B's live scorer. A7 still needs the swipe integration.

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
