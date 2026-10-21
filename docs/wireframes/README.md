# Wireframes (RC-04)

Low-fidelity layouts for every auth and recruiter page, used to agree on
structure before styling. Visual design (colors, type, motifs) comes from the
`resurhombus-ui` skill and C2's theme; these only fix **what is where**.

| File | Pages |
|---|---|
| [auth.md](auth.md) | Welcome, Role choice, Sign up, Sign in, Forgot password, Reset password |
| [company.md](company.md) | Company setup, Create company, Join company, Company settings |
| [recruiter.md](recruiter.md) | Recruiter shell, Jobs list, New job, Requirements, Job details, Board, Candidate detail, Interviews |

**Layouts.** *Compact* is a phone (< 900 px, bottom `NavigationBar`). *Wide* is
a laptop browser (≥ 900 px, `NavigationRail`, extended at ≥ 1200 px).

**The four states.** Every data page shows:

| State | Pattern |
|---|---|
| Loading | Shimmer in the shape of the content (rows, tiles), not a lone spinner |
| Empty | Geometric illustration, one sentence, at most one action |
| Error | What happened, plus **Retry** |
| Content | The layout drawn below |

Forms show loading as a disabled form with a progress indicator in the submit
button, and errors inline under the field or above the submit button.

**Review status:** draft for team review.
