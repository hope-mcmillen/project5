---
name: resurhombus-supabase
description: Backend specialist for ResuRhombus on Supabase. Covers Postgres schema and migrations, pgvector, Row-Level Security policies, RPC (SQL) functions like get_feed/get_board/swipe, Edge Functions in Deno/TypeScript, Storage buckets, Realtime, auth role handling (candidate vs recruiter), and synthetic seed data. Use this skill whenever the task touches the database, a migration, a policy, an RPC, an Edge Function, supabase CLI commands, seed.sql, auth/sign-up roles, or "why can't this user see this row", even if the user doesn't say "Supabase".
---

# ResuRhombus Supabase Backend

The backend is **Supabase** (Postgres + pgvector, Auth, Storage, Realtime, Edge Functions). Azure Document Intelligence and a configurable LLM are called **only** from Edge Functions. The architecture is in `docs/PRD.md` §9: §9.4 is the data model, §9.5 RLS, §9.6 RPCs and functions, and §9.8 seed data. Read the relevant section first and keep the PRD in sync when you change the contract.

## Layout

```
supabase/
  config.toml
  migrations/            # YYYYMMDDHHMMSS_<verb>_<thing>.sql, append-only
  seed.sql               # synthetic demo data, runs on `supabase db reset`
  seed/resumes/*.pdf     # fake resumes for the live parse demo
  functions/
    _shared/             # llm.ts, azure_di.ts, cors.ts, supabase_admin.ts, schemas.ts
    parse-resume/index.ts
    parse-job/index.ts
    notify/index.ts
  tests/                 # pgTAP: *.test.sql
```

## Non-negotiables (and why)

1. **RLS on every table, in the same migration that creates it.** Supabase exposes tables over the public API. A table without RLS is readable by anyone who has the anon key, and that key ships in the app. Write `alter table … enable row level security;` and the policies together.
2. **Secrets live only in Edge Function secrets.** The Flutter app gets the **anon key** and nothing else. The service-role key, Azure keys, and OpenAI keys go in `supabase secrets set` and in `supabase/functions/.env` locally, which is gitignored.
3. **The role comes from the database, not the client.** `profiles.role` is set by the `on auth.users insert` trigger from sign-up metadata. The trigger only accepts `candidate` or `recruiter`. Policies read the role through a `security definer` helper (`public.current_app_role()`. Not `current_role`, which is a reserved SQL keyword.), or from the JWT claim added by a custom access-token hook. Never trust a role the client sends in a request body.
4. **Recruiters never touch candidate tables directly.** They read candidates only through `get_board()` and `get_candidate_detail()`. These are `security definer` functions that return **blind** fields until the application reaches `INTERVIEW_REQUESTED`. This enforces PRD R-TRI-1 at the data layer, so a UI bug can't leak identities.
5. **Status changes go through RPCs** (`advance`, `reject`, `withdraw`). Each one validates the transition against the state machine in PRD §5.4 and writes a `status_events` row in the same transaction.
6. **Migrations are append-only.** Never edit a migration that has been applied to a shared project. Write a new one.
7. **Scoring is deterministic SQL.** `compute_match(profile_version_id, job_id)` follows the formula in PRD §8.4 exactly and stamps `scoring_version`. If you change the formula, bump the version and add a re-score migration or script.

## Patterns

**Role helper + policy example**
```sql
create or replace function public.current_app_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create policy "recruiters manage own company jobs" on public.jobs
  for all to authenticated
  using (public.current_app_role() = 'recruiter'
         and company_id = (select company_id from public.recruiters where profile_id = auth.uid()))
  with check (company_id = (select company_id from public.recruiters where profile_id = auth.uid()));
```
- Wrap `auth.uid()` in `(select auth.uid())` in hot policies so Postgres evaluates it once per query, not once per row.
- Every `security definer` function sets `search_path = public` (to prevent search-path hijacking) and checks authorization itself.

**Undo window (PRD §9.4):** A right swipe inserts the application with `committed_at = now() + interval '5 seconds'`. `undo_swipe` deletes it only while `now() < committed_at`. Board queries filter `committed_at <= now()`.

**Daily cap:** Enforced inside `swipe()` by counting the caller's right swipes since `date_trunc('day', now() at time zone 'utc')`. Raise a clear error code (`P0001` with message `daily_cap_reached`) so the app can show a friendly message.

**pgvector:** `create extension if not exists vector with schema extensions;`. Columns are `vector(1536)`, which matches `text-embedding-3-small`. Use an HNSW index with `vector_cosine_ops`. Store an `embedding_model` text column next to each vector (PRD §9.3).

**Realtime:** Add only the tables the UI listens to (`resumes`, `applications`) to the `supabase_realtime` publication. RLS also applies to Realtime.

**Storage:** The private bucket `resumes` has object paths `{auth.uid()}/{uuid}.{pdf|docx}`. Policies compare `(storage.foldername(name))[1] = auth.uid()::text`. Recruiters get short-lived signed URLs from an RPC, and only after advancing.

**Edge Functions:**
- Verify the caller's JWT, which is the default.
- Create a user-scoped client for reads that should respect RLS. Create an admin client only for the specific writes that need it.
- Call the LLM only through `_shared/llm.ts`. That file is owned by the `resurhombus-matching` skill.
- Set statuses as you go (`PARSING`, then `READY` or `FAILED` with a reason) so Realtime drives the UI.
- Handle the Edge Function wall-clock limit (see the PRD §9.2 note).

## Seed data (PRD §9.8)
- Synthetic only, with no real people. Every row has `is_seed = true`.
- Embeddings are precomputed and stored as literals. Seeding never calls an LLM.
- Include applications in **every** status, and score bands spread across each job, so every UI state can be demoed.
- Demo account credentials live in `seed.sql` (local and dev only). Don't repeat them in chat or in docs other than the README's local-dev section.

## Workflow
1. Write the migration (schema + RLS + grants + indexes together).
2. Run `supabase db reset` locally. This applies migrations and the seed.
3. Add pgTAP tests in `supabase/tests/` for each policy. At minimum: the owner can, the other role can't, and anon can't. Run them with `supabase test db`.
4. Run `supabase gen types typescript --local > supabase/functions/_shared/database.types.ts` after schema changes. Update the Dart models too.
5. If the change affects a PRD contract (RPC signature, table, status), update `docs/PRD.md`.

Ask before running anything against a **linked remote project** (`supabase db push`, `supabase secrets set` on remote, `functions deploy`). Those are shared and outward-facing.
