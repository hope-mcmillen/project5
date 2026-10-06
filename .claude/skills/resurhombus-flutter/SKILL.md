---
name: resurhombus-flutter
description: Flutter app architecture conventions for ResuRhombus. Covers the feature-first folder structure, Riverpod providers, go_router with candidate/recruiter role guards, supabase_flutter repositories, models, error handling, offline swipe queue, and testing (unit, widget, golden). Use this skill whenever adding a feature, screen, provider, route, repository, or model to the Flutter app, wiring the app to Supabase, setting up project structure or dependencies, or writing Flutter tests, even if the user only says "add the pipeline screen" or "hook this up". Pair it with resurhombus-ui for visuals.
---

# ResuRhombus Flutter Architecture

There is one Flutter codebase for both roles. Candidate and recruiter UIs are separate route trees, selected by `profiles.role` (PRD §4). Android is the primary target, and the recruiter side also runs on Flutter Web. For visual design, use the **resurhombus-ui** skill. This skill covers the structure and data flow underneath.

## Folder structure (feature-first)

```
lib/
  main.dart                     # Supabase.initialize, ProviderScope, MaterialApp.router
  app/
    router.dart                 # go_router + role redirect
    env.dart                    # --dart-define values (SUPABASE_URL, SUPABASE_ANON_KEY)
  ui/                           # design system (owned by resurhombus-ui)
    theme/  components/
  core/
    supabase/                   # client provider, auth state provider
    errors/                     # AppFailure sealed class, mapping from PostgrestException etc.
    models/                     # shared enums: AppRole, ApplicationStatus, ScoreBand
  features/
    auth/                       # welcome, role choice, sign in/up
    onboarding/                 # upload, prism progress, review & confirm, preferences
    deck/                       # feed, swipe, undo, pass reasons
    deep_dive/                  # radar + gap list
    pipeline/                   # candidate applications
    company/                    # recruiter create/join company
    jobs/                       # recruiter JD paste, requirement editor, jobs list
    board/                      # mosaic grid, candidate detail, interview list
    <feature>/
      data/                     # <feature>_repository.dart (only place that calls Supabase)
      domain/                   # immutable models (freezed or plain), pure logic
      presentation/             # screens, feature widgets, controllers (Notifier/AsyncNotifier)
test/                           # mirrors lib/
```

**Why this layering:** Screens never call `Supabase.instance` directly. Repositories wrap every RPC and table call and return domain models or throw `AppFailure`. That way, RLS errors, network errors, and `daily_cap_reached` get mapped once to friendly messages, and tests can swap in a fake repository.

## Conventions

- **Config:** `--dart-define-from-file=env/dev.json` (gitignored, with a committed `env/example.json`). It holds only the Supabase URL and **anon key**. No LLM, Azure, or service-role keys ever go in the app, because they're server-side secrets (PRD §9.7).
- **State:** Riverpod. Use `@riverpod` code generation if `riverpod_generator` is set up, otherwise plain `Provider` / `NotifierProvider` / `AsyncNotifierProvider`. Pick one style per project and stick to it. Use `AsyncValue` for every remote load, so loading, error, and data map directly onto the four UI states.
- **Realtime:** Expose subscriptions as `StreamProvider`s in the repository layer (`watchResume(id)`, `watchApplications()`). Dispose with `ref.onDispose`.
- **Routing:**
  - `go_router`'s `redirect` reads an `authStateProvider` + `profileProvider`. Unauthenticated users go to `/welcome`. A logged-in user without a profile goes to `/welcome/role`. Candidates go to `/c/...` (deck, pipeline, profile). Recruiters go to `/r/...` (jobs, board, company).
  - Use `refreshListenable` with the auth stream.
  - A recruiter hitting `/c/*` (or the other way around) is redirected. RLS is the real enforcement, and the router check is for UX.
- **Models:** Immutable, with `fromJson` matching the Postgres column names (`snake_case` mapped through `@JsonKey` or manual mapping). Statuses are Dart enums that mirror the PRD §5.4 state machine exactly.
- **Offline swipes (C-SW-6):** Queue swipe intents locally (e.g., `shared_preferences` or `drift`) and flush them in order when the connection returns. The server is still the source of truth for the cap and the undo window.
- **Dependencies baseline:** `supabase_flutter`, `flutter_riverpod`, `go_router`, `fl_chart`, `google_fonts`, `file_picker`. Add more only with a reason. Run `flutter pub add <pkg>` rather than hand-editing versions.

## Adding a feature (checklist)

1. Find the PRD flow and requirement IDs. Note which RPC or table it uses (PRD §9.6).
2. Write the repository method plus the domain model, and a fake for tests.
3. Write the controller (`AsyncNotifier`) holding the screen's state and actions.
4. Build the screen and widgets following **resurhombus-ui**.
5. Add the route, with role guard placement.
6. Write tests:
   - Unit tests for pure logic
   - Widget tests covering loading, empty, error, and data, using a fake repository
   - A golden test for core visuals if goldens are enabled
7. Run `flutter analyze` and `flutter test`. CI (`.github/workflows`) runs `flutter test --coverage`, so keep it green.

## Running

- Android: `flutter run --dart-define-from-file=env/dev.json`
- Recruiter web: `flutter run -d chrome --dart-define-from-file=env/dev.json`
- Local backend: `supabase start`. Point `env/dev.json` at `http://10.0.2.2:54321` for the Android emulator (it can't reach `localhost` on the host) and at `http://localhost:54321` for web.
