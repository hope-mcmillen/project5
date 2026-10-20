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
- A1: local CLI config and CI/review templates implemented; runtime checks pending.
- A2–A11: pending.
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
