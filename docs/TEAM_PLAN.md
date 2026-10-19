# ResuRhombus: Team Plan (4 people)

**Companion to:** [TASKS.md](TASKS.md) · [SCHEMA.md](SCHEMA.md) · [PRD.md](PRD.md) · [USER_STORIES.md](USER_STORIES.md) · Scaffold pages in `lib/features/` list the task IDs that will replace them.

**How to use this plan**
- Each person has **one silo** and **one ordered list of task blocks** in [TASKS.md](TASKS.md) (A1, A2, …). A block combines several related small tasks, and its title is a user story. Work top to bottom. The order is the suggested sequence, not a deadline.
- **Needs** names the blocks that must exist before yours can be connected to real data. If something you need isn't done yet, build against the **fake** (frontend) or the **mock** (AI) and connect it later. Nobody waits idle.
- **Core** blocks are the starting product. **Later** blocks are features to add once the core works. More can be added to either list at any time.
- **Size:** **S** is half a day or less, **M** is about 1 day, **L** is about 2 days. Split anything bigger.
- Block IDs are `A1…`, `B1…`, `C1…`, `D1…` (and `T1…` for team tasks). The original task IDs (`PL-`, `AI-`, `CA-`, `RC-`) still appear in each block's **Covers** line and in the ID lookup at the bottom of TASKS.md, so USER_STORIES.md, the scaffold pages, and the checkpoints below still resolve.

---

## 1. Who owns what

| Person | Silo | Owns (folders) | Does **not** touch | Claude skills |
|---|---|---|---|---|
| **A** | **Backend: database & API** | `supabase/migrations/`, `supabase/tests/`, `supabase/seed.sql`, non-AI Edge Functions (`notify`, `resume-url`, `delete-account`), Auth / Storage / Realtime config, CI | `lib/`, AI functions | `resurhombus-supabase` |
| **B** | **Backend: AI & matching** | `supabase/functions/parse-resume`, `parse-job`, `_shared/` (LLM adapter, schemas, Doc Intelligence), scoring SQL (`compute_match`, `match_skills`, `get_feed`), taxonomy, seed *generator* | `lib/`, auth/RLS migrations | `resurhombus-matching`, `resurhombus-supabase` |
| **C** | **Frontend: candidate app + design system** | `lib/ui/` (theme + shared components incl. Radar), `lib/core/models/`, `lib/features/{onboarding,deck,deep_dive,pipeline,profile}/` (screens **and** their repositories) | `supabase/` | `resurhombus-ui`, `resurhombus-flutter` |
| **D** | **Frontend: recruiter app + auth & routing** | `lib/app/` (router, shells, main), `lib/features/{auth,company,jobs,board}/` (screens **and** their repositories), web build | `supabase/` | `resurhombus-ui`, `resurhombus-flutter` |

**Why this split**
- **Two backend people:**
  - A owns *who can see and change what*: tables, access rules, status changes.
  - B owns *what the AI and the score say*.
  - B's functions write to tables A defines, and A's functions call B's `compute_match`.
- **Two frontend people, split by role:**
  - D takes sign-in and routing because the recruiter portal (the deliverable) starts at sign-up.
  - C takes the design system because the swipe deck and radar are the most visual parts. D reuses C's components.
- **Frontend people write their own repositories** (the Dart files that call Supabase) using the contract. Backend people never edit Dart, and frontend people never edit SQL.

### How the silos connect
1. **The API contract is the handoff.** A and B write `docs/API_CONTRACT.md` first (PL-27). It lists every RPC and Edge Function with its parameters, an example JSON response, and error codes. C and D build fake repositories that return exactly those examples.
2. **Changing the contract takes a heads-up.** Post it in the team chat, update the contract doc in the same PR, and get approval from both frontend owners.
3. **Every backend endpoint ships with a test and a JSON sample**, so frontend people never have to read SQL.
4. **Reviews cross the boundary.** Each PR is reviewed by the person on the other side of it: A with D (auth, company, board), A with C (swipes, pipeline), B with C (feed, parsing), B with D (parse-job, scores).
5. **CODEOWNERS** auto-requests the right reviewer. Add `.github/CODEOWNERS` with your GitHub usernames:
   ```
   /supabase/migrations/          @person-a
   /supabase/tests/               @person-a
   /supabase/seed.sql             @person-a
   /supabase/functions/           @person-b
   /lib/ui/                       @person-c
   /lib/core/                     @person-c
   /lib/features/onboarding/      @person-c
   /lib/features/deck/            @person-c
   /lib/features/deep_dive/       @person-c
   /lib/features/pipeline/        @person-c
   /lib/features/profile/         @person-c
   /lib/app/                      @person-d
   /lib/features/auth/            @person-d
   /lib/features/company/         @person-d
   /lib/features/jobs/            @person-d
   /lib/features/board/           @person-d
   ```

### Integration checkpoints
These are not deadlines. They're the moments the silos plug into each other, so test them together when you reach each one.

| # | Checkpoint | What works end to end | Main blocks involved |
|---|---|---|---|
| 1 | **Contract agreed** | Everyone builds against the same API, models, and theme | A2, B2, C1, C2 |
| 2 | **Roles work** | Anyone can sign up as a candidate or recruiter and land on the right home | A3, A4, D2, D3 |
| 3 | **Inputs work** | Resume → confirmed profile, and pasted JD → published job, with real AI | B6, B7, C5, D5, D6 |
| 4 | **The loop** ⭐ | A candidate's right swipe shows up on the recruiter board, sorted by score | A7, A8, B8, B9, C8, D8 |
| 5 | **Loop closed** | Advance or reject updates the candidate's applications live | A8, A9, C10, D9 |

---

## 2. Tasks and schema

- **[TASKS.md](TASKS.md):** every task block, grouped by person (Core, then Later). Each has a user-story **title**, the original tasks it **Covers**, a technical **Build** description, what it **Needs**, its size, its stories, and a **Done when** check.
- **[SCHEMA.md](SCHEMA.md) + [schema.sql](schema.sql):** the agreed database. Tables, enums, RLS rules, storage buckets, every RPC and Edge Function, and the JSON shapes. Person A turns `schema.sql` into migrations (PL-04..06).

---

## 3. Working agreements

**Board:** GitHub Projects with columns *To do → In progress → In review → Done*. One issue per block, titled with the block ID and story (e.g. `[A7] As a candidate, I want to apply or pass…`), labeled with its owner and linked to its `US-xx` stories.

**Branches and PRs**
- Branch per block: `feat/<block>-short-name` (e.g., `feat/C6-swipe-deck`). A block is a few days of work, so open a PR for each natural piece (e.g., one per original task in **Covers**) instead of one giant PR.
- Keep PRs small (under about 400 changed lines). Each needs **1 approving review** from across the boundary and **green CI** before it's squash-merged into `master`.

**Migrations:** **A merges all migrations.** B writes scoring SQL as migrations on their branch, posts in the team chat first, and rebases onto the newest migration before merging. C and D never write migrations; they ask for changes through the contract. Never edit a merged migration. Write a new one instead.

**Secrets:** `env/dev.json` and `supabase/functions/.env` are shared privately (password manager or private message) and **never committed**. The app only ever contains the anon key.

**Rhythm**
- **Async check-in** in the team chat a few times a week: what's done, what's next, any blockers.
- **Weekly sync** (30–45 min): merge to `master`, demo what's new on a real device and the web, and test any checkpoint that's been reached.

**Definition of Done (per block)**
1. The block's **Done when** line in TASKS.md and the "Done when" criteria of its stories in USER_STORIES.md pass.
2. Tests are added: widget or unit tests for Flutter, pgTAP for SQL, Deno tests for Edge Functions.
3. `flutter analyze` is clean and CI is green.
4. Screens handle all four states: loading, empty, error, content.
5. The API contract and PRD are updated if anything they describe changed.

**When blocked:** Keep building against the fake or mock, and say so in the check-in. Never wait idle.

**Adding features later:** Add a story to USER_STORIES.md first, then add tasks to the owner's **Later** list, using the next free ID with that person's prefix.

---

## 4. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Backend arrives late and frontend stalls | Fake repositories (CA-02, RC-03) and the mock AI (AI-03) from the start, built from the API contract |
| Contract keeps changing and breaks everyone | Agree it early (ALL-01). Later changes need a chat heads-up, a doc update, and frontend approval. |
| Swipe deck takes longer than expected (CA-11) | Timebox to 2 days. Fall back to `flutter_card_swiper` and polish later. |
| AI parsing is slow or flaky during the demo | Seed data fills the board with no live parsing needed. Cache results by file hash. Rehearse with a resume parsed beforehand. |
| API credits run out | Mock provider for development, daily token budget, precomputed embeddings in the seed |
| One silo falls behind | Backend owners (A, B) can cover for each other, and so can frontend owners (C, D), since each pair shares a stack. |
| Recruiter deliverable incomplete | Checkpoint 4 (the loop) is the must-hit goal. Everything in **Later** can be cut. |
