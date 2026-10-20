# Person A delivery log

Source: docs/TASKS.md, A1–A11 (Core and Later). There is no docs/claude.md.
Deadline: Thursday, October 22, 2026, America/Chicago.
Commits use their actual execution date. No backdating or empty commits.

## Schedule

| Date and time (Central) | Scope | Planned commits |
|---|---|---|
| Tue Oct 20, current session | A1 setup; A2 schema, policies, contract | 2 |
| Wed Oct 21, 9 AM | A3 identity and access; A4 companies/invites | 1–2 |
| Wed Oct 21, 3 PM | A5 storage/profile/preferences; A6 local seed/README | 1–2 |
| Thu Oct 22, 9 AM | A7 swipe/undo/cap; A8 blind board/status RPCs | 1–2 |
| Thu Oct 22, 3 PM | A9 live updates/resume links/tests; A10 deletion/verification; A11 notification delivery | 1–2 |

Target roughly two meaningful commits a day; combine related blocks only when
needed for a working, tested unit. Complete work on the date it is scheduled.
If a prior run was missed, catch up before the Thursday deadline; never claim
untested or externally blocked acceptance criteria as complete.

## Current state

- Repository cloned from https://github.com/hope-mcmillen/project5.
- A1: local CLI config and CI/review templates implemented. Supabase starts locally.
  Hosted project, Google OAuth activation and GitHub admin/reviewer setup remain blocked.
- A2: three schema/RLS migrations and the Person A API contract draft implemented;
  local reset, lint and 42 access tests pass. Team contract approval remains pending.
- A3–A11: scheduled; not yet implemented.
- Keep personal work on feature branches; do not merge master without required review.
- Person B has additional unmerged work on origin/kameron-a. Do not merge it
  automatically or edit AI-owned functions. Coordinate integration via contracts.

## External setup and acceptance blockers

These require authenticated account access or teammate input, not just code:

- Hosted Supabase dev project and privately shared project URL/anon key.
- Google OAuth client credentials and provider activation. Email works locally;
  Google is intentionally disabled until real credentials are provided.
- GitHub Project board, owner/story labels and master protection (one approving
  review plus green CI). CODEOWNERS is a commented template until actual team
  handles are known; it does not yet auto-request reviewers.
- Team API freeze/review by C and D; cross-team full-loop rehearsal.
- FCM service-account secrets and a real device for closed-app push verification.
- B5 embeddings / B8 scoring integration must be validated when B's branch lands.

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
- Google OAuth credentials, hosted Supabase access, GitHub reviewer handles/admin
  setup and FCM/device setup remain explicit external acceptance dependencies.
