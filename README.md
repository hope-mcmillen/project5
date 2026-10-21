# ResuRhombus (project5)

A Flutter candidate/recruiter prototype with a Supabase backend. The backend has
real account/company onboarding, private resume storage, profile review,
preferences, parsing, scoring and a ranked feed. The Flutter screens are currently
navigation scaffolds: `lib/main.dart` still has the frontend team's Supabase
initialization TODO. Running Flutter opens that prototype; it does not yet make
the backend calls automatically. Application/status RPCs are the next Person A
batch. See [delivery status](docs/PERSON_A_PROGRESS.md) and [API contract](docs/API_CONTRACT.md).

## Prerequisites

- Flutter with Dart **3.13.1 or newer**, matching `pubspec.yaml`.
- Supabase CLI **2.121.0** and Docker Desktop, running.
- Python 3 for backend integration tests.
- For Android: a configured Android SDK and Java 17 or newer (`flutter doctor`).
- Optional Deno 2 for the AI function tests. A Gemini key is not needed for the
  local demo, seed or mock tests.

## Local development

From the repository root:

```sh
flutter pub get
supabase start
supabase db reset --local
cp env/example.json env/dev.json
```

`db reset --local` replaces this project's local database with the committed
schema and synthetic demo data. It loads, in order, the skill taxonomy,
precomputed vectors, Person B's generated demo world and Person A's demo-account
setup through `supabase/config.toml`. It makes no AI calls. Do not run the local
demo seed against a production database.

Run `supabase status` locally and copy its **anon/publishable key**, never its
service-role/secret key, into the ignored `env/dev.json`. Desktop/web uses
`http://127.0.0.1:54321`. An Android emulator uses **`http://10.0.2.2:54321`** to
reach the host; a physical phone needs the development computer's reachable LAN
address and appropriate local network setup. Studio is at
`http://127.0.0.1:54323` and local test emails at `http://127.0.0.1:54324`.

```sh
flutter run --dart-define-from-file=env/dev.json
flutter run -d chrome --dart-define-from-file=env/dev.json
flutter build apk --debug --dart-define-from-file=env/dev.json
```

The define names are `SUPABASE_URL` and `SUPABASE_ANON_KEY` (see
`env/example.json`). These are ready for the frontend integration; the current
scaffold does not initialize Supabase yet. Backend accounts can already be used
through Supabase Auth/Studio and the documented APIs.

### Local-dev demo accounts

These intentionally public credentials work **only in the locally seeded demo**.
They are not hosted-project or production credentials. Other synthetic users have
no usable password. Do not reuse these passwords elsewhere.

| Role | Email | Password |
|---|---|---|
| candidate | candidate@demo.resurhombus.test | LocalDemo-4330! |
| recruiter | recruiter@demo.resurhombus.test | LocalDemo-4330! |

The candidate has a confirmed profile and sample applications. The recruiter is
Pelican Path Health's owner. Demo data includes 343 skills, 132 relations,
3 companies (one verified), 4 recruiters, 30 candidates, 6 jobs and 60 applications
covering every status. All people/resumes are synthetic. See
`supabase/seed/demo_manifest.json` for fixture IDs and expected match scores.

### Local Edge Functions and AI provider

If `supabase/functions/.env` does not already exist, copy
`supabase/functions/.env.example` to that path. Keep existing local credentials;
never commit the `.env` file. Set `LLM_PROVIDER=mock` for ordinary development.

```sh
supabase functions serve --env-file supabase/functions/.env
```

To deliberately test real AI, change the local provider to `gemini` and configure
`GEMINI_API_KEY`, `LLM_EXTRACT_MODEL`, `LLM_EMBED_MODEL` and the daily token budget
from the example. The embedding model remains `gemini-embedding-001`. Real AI
calls use credits; seeding does not. No Gemini or service-role keys belong in the
Flutter defines, APK or repository.

Google OAuth is disabled locally until OAuth client credentials are configured.
Hosted deployment, provider configuration and secrets require authenticated
Supabase access; the project URL alone does not grant it.

## Verification

With the local Supabase stack running:

```sh
supabase db lint --local --level error
supabase test db
python3 supabase/tests/company_concurrency.py
python3 supabase/tests/auth_smoke.py
python3 supabase/tests/profile_storage_smoke.py
flutter analyze
flutter test
```

The Python checks target only local Supabase, create synthetic data where needed
and remove it afterward. The profile/storage smoke check also verifies both
seeded demo logins and actual private Storage upload/download boundaries.
CI runs the database and API checks on feature branches and pull requests.

Optional AI validation (from `supabase/functions`):

```sh
deno task test
deno task check
```

`deno task test:live` is opt-in and uses real Gemini calls. The committed vectors
make both seeding and SQL matching work offline. To stop the local stack:
`supabase stop`.

## Working together

Person A owns database/access/status APIs; B owns AI/scoring; C owns candidate UI;
D owns auth/recruiter UI. Work on feature branches, request the cross-boundary
review described in [TEAM_PLAN.md](docs/TEAM_PLAN.md), and require green checks
before merging. No automatic merges or remote database pushes are performed by
the scheduled Person A work. Push notifications are excluded from this delivery.
