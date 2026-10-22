# ResuRhombus (project5)

A Flutter candidate/recruiter app with a Supabase backend. Authentication, routing
and company onboarding are connected to Supabase. The backend also supplies
private resume storage, confirmed profiles/preferences, parsing, matching,
ranked feed, application/undo, blind recruiter triage, status changes and job
lifecycle APIs. Candidate screens and recruiter board/jobs still contain some
scaffolds or fake repositories awaiting frontend integration. See
[delivery status](docs/PERSON_A_PROGRESS.md) and [API contract](docs/API_CONTRACT.md).

## Prerequisites

- Flutter with Dart **3.13.1 or newer**, matching `pubspec.yaml`.
- Supabase CLI **2.121.0** and Docker Desktop, running.
- Python 3 for backend integration tests.
- For Android: a configured Android SDK and Java 17 or newer (`flutter doctor`).
- Deno **2.5.4** for Edge unit and live-service integration tests. A Gemini key is not needed for the
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
`env/example.json`). The current app initializes Supabase from these defines. Backend accounts can
be used through the app's sign-in/company screens and the documented APIs; some
candidate/board/job screens still use frontend fakes.

### Running the app on Supabase

1. Copy the example config: `cp env/example.json env/dev.json` (gitignored).
2. Fill in `env/dev.json`:
   - Local stack: `SUPABASE_URL` is `http://127.0.0.1:54321` (or
     `http://10.0.2.2:54321` on the Android emulator) and `SUPABASE_ANON_KEY`
     is the anon/publishable key from `supabase status`.
   - Hosted project: use the project URL and its anon/publishable key from the
     Supabase dashboard (Project Settings → API). Never use the service-role key.
3. Run with the config:

```sh
flutter run --dart-define-from-file=env/dev.json            # Android
flutter run -d chrome --dart-define-from-file=env/dev.json  # web
```

`lib/main.dart` initializes Supabase from these values. If they are missing,
the app shows a setup message instead of starting.

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
python3 supabase/tests/application_concurrency.py
python3 supabase/tests/application_api_smoke.py
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

### Secure resume links and account deletion (A9/A10)

Copy `supabase/functions/.env.example` to the ignored `.env` only if you do not
already have one. Set `PUBLIC_SUPABASE_URL` to the API address the app can reach
(`http://127.0.0.1:54321` for desktop/web, `http://10.0.2.2:54321` for an Android
emulator, or your HTTPS hosted project URL). Start functions locally:

```sh
supabase functions serve --env-file supabase/functions/.env
```

`resume-url` accepts `{ "application_id": "<UUID>" }` with a recruiter JWT and
returns a ten-minute signed link only for an advanced application in that
recruiter's company. `delete-account` accepts a candidate JWT and removes its
private data and files before deleting Auth; applications are retained anonymized.
Deletion failures may leave partial cleanup and can be retried while Auth exists.
Company badges require a confirmed, non-free-mail email with an exact website
host match. See the API contract for authorization and error details.

With the local stack and functions running:

```sh
(cd supabase/functions && deno test --allow-read=..,. --allow-env _shared/ parse-resume/ parse-job/ resume-url/ delete-account/)
python3 supabase/tests/deletion_concurrency.py
deno test --allow-env --allow-net --allow-run supabase/tests/privacy_integration.ts
```

The last test refuses remote endpoints and uses temporary synthetic accounts. It
checks actual signed downloads, live events for two candidates and two companies,
and deletion across more than one Storage page. Backend CI runs it automatically.
Live Gemini tests remain opt-in. The backend is ready for C/D integration; this
does not imply that all candidate/recruiter frontend screens are wired yet.

## Candidate development without a backend (C1)

Run `flutter run -t lib/main_fake.dart`. This entry point starts the existing
navigation scaffold inside Riverpod with all four candidate repositories
overridden. No Supabase configuration or AI credentials are required.

Shared immutable models are exported by
`lib/core/models/candidate_models.dart`. They include profile versions, skills,
preferences, job cards, score breakdowns, applications, status events, and blind
candidate tiles. JSON uses the database's snake_case field names.

Screens can use `profileRepositoryProvider`, `resumeRepositoryProvider`,
`feedRepositoryProvider`, and `applicationRepositoryProvider`. The candidate implementations remain demo repositories until C5/C8. Both entry points supply these candidate overrides; configured authentication and recruiter repositories remain live.

For previews and tests:

- Future operations default to a 300 ms delay. Pass `latency: Duration.zero`
  to a fake, or to `fakeRepositoryOverrides`, for fast tests.
- Set `failNext = const AppFailure('offline')` to simulate a request error.
- Pass `cards: []`, `applications: []`, or `seedData: false` on the profile
  fake to exercise empty states.
- Use `FakeResumeRepository.setStatus` to control parsing progress or failure.
- Application streams emit the initial snapshot and changes after withdrawal.
- Each provider scope owns fresh fake state and disposes stream resources.

These fakes provide synthetic screen-development data. They do not implement
database authorization or real document parsing. Resume selection and progress,
skill review, preferences, and the swipe deck are available in this local preview.

## Candidate skills, preferences, and swiping (C4 / C6)

After the resume preview, Review lets candidates add or rename skills through
taxonomy search, remove skills, adjust experience in half-year steps, and inspect
highlighted source evidence. Edits remain local until **Confirm skills** succeeds.
Revisiting a confirmed profile creates a new draft and preserves the previous
version used by existing applications. Custom skills are labeled as unscored.

Preferences support locations, work arrangement, role type, sponsorship, an
optional annual USD salary minimum, and lower-match roles. Saving filters the deck
without altering match scores. Remote roles ignore the location list; a salary
minimum excludes roles without a salary range. Onboarding advances only after a
successful save. Profile provides access to skills, preferences, and Resume.

The deck shows three stacked branded job cards. Swipe right to apply or left to
pass, or use the labeled buttons. Short drags spring back; committed gestures show
Apply/Pass stamps and fly out. Reduced motion uses short linear animations. Failed
actions restore the card, repeated actions are blocked, and applying requires
confirmed skills. Successful demo applications appear under Applications with the
profile version used when applying.

**This is in-memory demo behavior:** preferences, decisions, and applications reset
when the app restarts. No application is sent to an employer. Supabase onboarding
and live feed/application persistence remain C5 and C8 respectively. Device
performance profiling is still required to establish the 60 fps target.

## Deck controls and recovery (C7)

The labeled Pass, Details, and Apply controls share the swipe animations. Each
successful action offers a five-second Undo countdown based on its repository
receipt and clock offset. Undo restores the card with a reverse animation and
removes the application created by that demo swipe. Expired or failed undo
requests leave the existing decision intact.

After passing, optional Location, Salary, Tech stack, Seniority, and Company chips
appear for three seconds. Choosing a reason saves it against that swipe; the next
card stays interactive. Empty decks offer preferences, Resume, and a Show stretch
roles toggle that preserves the other filters. A failed page load offers Load more
jobs instead of incorrectly claiming there are no remaining jobs.

These actions currently use the local fake repositories. The live Supabase RPCs
and persistence are still part of C8.

## Resume upload and reading preview (C3)

Candidate repositories use local demo data in both entry points. The normal entry point retains Supabase authentication and recruiter repositories; main_fake uses fake repositories for both roles. Open Resume, choose a PDF or DOCX up to
5 MiB, then select Upload resume. The picker checks the extension and file header,
reads bounded bytes on mobile and web, and computes a SHA-256 content hash.

The progress screen follows repository statuses through uploading/reading,
experience extraction, and skill normalization, then opens Review automatically.
Failures and the 60-second deadline offer another file or a manual profile draft.
Motion pauses in the background and respects the system's reduced-motion setting.

**Reading is simulated:** the selected bytes remain in memory; nothing is sent to
Supabase or an AI service. Real storage and document parsing belong to C5. To drive
failure states in tests, use `FakeResumeRepository.setStatus`; turn off automatic
stages with `simulateParsing: false` in `fakeRepositoryOverrides`.

## Shared visual system (C2)

`lib/ui/theme/rr_theme.dart` defines the branded theme used by both roles.
Colors, spacing, radii, and motion tokens live in `rr_tokens.dart`; extra brand
colors are available through `context.rr`. Fonts are bundled in `assets/fonts/`
with their open-source licenses, so runtime font downloads are disabled.

Reusable, data-only components live in `lib/ui/components/`. The debug-only
`/dev/gallery` route previews score badges, application statuses, company badges,
rhombus variants, loading placeholders, and empty states. It is absent in release
builds. Preview pages retain existing navigation callbacks and make their prototype
status explicit; new button labels describe the action instead of task details.

Visual regression images are in `test/ui/goldens/`. Run `flutter test` for model,
navigation, component, layout, and golden checks. Intentionally changed visuals
can be regenerated with `flutter test --update-goldens test/ui`.
