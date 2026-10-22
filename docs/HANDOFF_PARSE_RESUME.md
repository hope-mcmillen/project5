# Handoff: deploy in-memory resume parsing

**From:** Kameron (Person B) · **For:** the database owner and their AI agent · **Date:** 2026-10-22
**Branch:** `resume-parsing` · **Remote project ref:** `ehgogfdaxmwnqfogjvmk` (the URL in `env/dev.json`)

## What this change is

Candidates were stuck in a loop: after uploading a resume they were sent back to Upload. The Supabase build used fake resume and profile repositories, so `confirm_profile` never ran and `candidates.active_version_id` stayed null. The route guard then sent them back to Consent → Upload.

This branch fixes that and changes how resumes are handled:

- **The resume file is never stored.** The app posts it to the `parse-resume` Edge Function as multipart. The function reads it in memory and saves only what it verified: a draft `profile_versions` row (with `resume_id` null), its `candidate_skills`, and a new `candidate_experiences` table. Nothing goes to Storage or `resumes`.
- **Parsing is a bounded agent loop:** extract (Gemini structured output, schema v3) → code verifier → at most one repair call → keep the best verified answer.
- **The app uses real `SupabaseResumeRepository` and `SupabaseProfileRepository`.** The deck and pipeline are still fakes.

Full contract: `docs/API_CONTRACT.md` §2. Design decisions: `docs/PRD.md` v0.9 changelog. Tables: `docs/SCHEMA.md`.

## Database changes (all additive)

Migration `supabase/migrations/20261022200000_parsed_profiles_without_storage.sql`:

| Object | What |
|---|---|
| `experience_kind` enum | job, internship, research, project, volunteer, other |
| `candidate_experiences` table | One row per experience per profile version. RLS: candidates read their own rows; nobody else has access. Only `service_role` can write. |
| `profile_versions.schema_version`, `.llm_model` | New nullable columns |
| `save_parsed_profile(...)` | Service role only. `parse-resume` calls it to save a draft version, skills, and experiences in one transaction. |
| `create_review_draft()` | Candidates. Copies the active version (skills and experiences) into a new draft for editing. |

Nothing is dropped or altered destructively. `save_resume_draft` and the old parse-status RPCs stay, but nothing calls them now.

**Not yet verified:** the migration and its pgTAP test (`supabase/tests/parsed_profiles.test.sql`) have **never run against a real Postgres**, because Docker wasn't available on the author's machine. Step 1 below is required, not optional.

## Steps

Run everything from the repository root. The Supabase CLI isn't installed globally on every machine, so `npx -y supabase …` works too.

### 1. Verify locally (required)

```sh
supabase start
supabase db reset --local
supabase db lint --local --level error
supabase test db
```

- **Expected:** every test file passes, including the new `parsed_profiles.test.sql` and the updated count in `schema_access.test.sql` ("all 20 tables enforce RLS").
- **If the migration or test fails:** fix it in place. It hasn't been applied anywhere yet, so editing it is allowed. Keep the behavior described in the table above. If a test expectation looks wrong rather than the SQL, explain why before changing it.

Then regenerate the types and run the function tests:

```sh
supabase gen types typescript --local > supabase/types/database.types.ts
cd supabase/functions && npx -y deno@2.9.6 task check && npx -y deno@2.9.6 task test && cd ../..
```

**Expected:** type check is clean and about 113 tests pass (6 ignored live tests).

### 2. Check the remote before changing it

```sh
supabase login
supabase link --project-ref ehgogfdaxmwnqfogjvmk
supabase migration list
supabase db push --dry-run
supabase secrets list
```

- **Migrations:** `migration list` and the dry run should show **only** `20261022200000_parsed_profiles_without_storage` as pending. If other migrations are pending, or the remote has migrations this branch doesn't, stop and ask the owner. Someone else's work may not be merged yet.
- **Secrets** (names only; never print values):
  - `LLM_PROVIDER` must be `gemini`.
  - `GEMINI_API_KEY` must be set.
  - `LLM_EXTRACT_MODEL` and `LLM_DAILY_TOKEN_BUDGET` are optional.
  - `RESUME_REPAIR_ROUNDS` is optional: default 1, and 0 turns the repair call off.

  If a required secret is missing, ask the owner to set it with `supabase secrets set`. Don't invent or paste keys.

### 3. Push the migration, then deploy the function (in this order)

```sh
supabase db push
supabase functions deploy parse-resume
```

The new function calls `save_parsed_profile`. If it's deployed before the migration, every parse fails with `internal`.

**As of 2026-10-22, neither `parse-resume` nor `parse-job` is deployed on the remote project.** Both return HTTP 404 ("Requested function was not found"); only `resume-url` exists. The app logs this as `FunctionsHttpException(status: 404, … NOT_FOUND)`. Deploy `parse-job` too, so recruiters can parse job descriptions. It needs no new migration, only the same Gemini secrets:

```sh
supabase functions deploy parse-job
```

To check what's deployed without logging in: `curl -s -o /dev/null -w "%{http_code}\n" -X OPTIONS https://ehgogfdaxmwnqfogjvmk.supabase.co/functions/v1/parse-resume`. 404 means not deployed; 200 means it's there.

**Agent rule:** both commands change the shared remote project. Get an explicit yes from the owner right before running each one.

### 4. End-to-end check

1. Run the app against the remote project: `flutter run -d chrome --dart-define-from-file=env/dev.json`.
2. Sign up a new **candidate** account, accept consent, and upload `supabase/seed/resumes/r01_flutter_single_column.pdf`. It's synthetic, so it's safe to send to Gemini.
3. **Expected:**
   - The progress screen finishes, and Review shows skills plus an "Experience from your resume" section with two jobs.
   - Confirm → Preferences → the Deck. The user must **not** loop back to Upload.
4. Check in the SQL editor, replacing the uid with the new user's id:

```sql
select pv.version, pv.source, pv.resume_id, pv.confirmed, count(ce.id) as experiences
from public.profile_versions pv
left join public.candidate_experiences ce on ce.profile_version_id = pv.id
where pv.candidate_id = '<uid>'
group by 1, 2, 3, 4;
-- expect: version 1, source resume, resume_id null, confirmed true, experiences 2

select active_version_id is not null as onboarded from public.candidates where profile_id = '<uid>';
-- expect: true

select count(*) from storage.objects where bucket_id = 'resumes' and name like '<uid>/%';
-- expect: 0, because the file was not stored
```

5. In the dashboard (Edge Functions → `parse-resume` → Logs), look for a `ready` line with `skills`, `experiences`, and `repair_rounds`. A `failed` line includes the reason.

## If something goes wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| Progress ends with "could not read this resume" and the logs show `save_parsed_profile failed` | Migration not pushed | Step 3, migration first |
| Logs show `config_error`, or `LLM_PROVIDER must be one of…` | Secrets missing | Set `LLM_PROVIDER=gemini` and `GEMINI_API_KEY` |
| `budget_exceeded` | Daily token budget used up | Raise `LLM_DAILY_TOKEN_BUDGET`, or wait for the UTC day to roll over |
| Parses take over 60 s or time out | The repair call is adding latency | `supabase secrets set RESUME_REPAIR_ROUNDS=0` |
| Still loops to Upload after confirming | The app build isn't this branch, or `confirm_profile` failed | Check that `lib/main.dart` uses `feedAndApplicationOverrides()`; check the network tab for a `confirm_profile` error |

**Rollback:** the migration is additive and safe to leave in place. To go back fully, redeploy `parse-resume` from `master`, *and* ship the app from `master`. The old function expects `{resume_id}` and the new app sends a file, so the two must match.

## Known follow-ups (not part of this handoff)

- Recruiters can't open a resume file for profiles parsed this way: `resume-url` returns `resume_not_available` (PRD Q16).
- 9 golden-image tests in `test/ui/` already failed before this change on the author's machine (rendering differences). Don't treat them as regressions from this branch.

## Prompt to give your AI agent

> Read `docs/HANDOFF_PARSE_RESUME.md` and carry out steps 1–4 on the `resume-parsing` branch. Step 1 is local only: fix anything that fails and tell me what you changed. Stop and ask me before steps 2–3 change anything remote, and get my yes right before `supabase db push` and right before `supabase functions deploy parse-resume`. Never print secret values. Report the results of each step, including the SQL checks in step 4.
