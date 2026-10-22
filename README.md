# project5

A new Flutter project.

## Candidate development without a backend (C1)

Run `flutter run -t lib/main_fake.dart`. This entry point starts the existing
navigation scaffold inside Riverpod with all four candidate repositories
overridden. No Supabase configuration or AI credentials are required.

Shared immutable models are exported by
`lib/core/models/candidate_models.dart`. They include profile versions, skills,
preferences, job cards, score breakdowns, applications, status events, and blind
candidate tiles. JSON uses the database's snake_case field names.

Screens can use `profileRepositoryProvider`, `resumeRepositoryProvider`,
`feedRepositoryProvider`, and `applicationRepositoryProvider`. Real implementations
are separate future tasks; outside fake mode these providers fail explicitly.

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

## Resume upload and reading preview (C3)

Both `flutter run` and `flutter run -t lib/main_fake.dart` currently use local
repositories in this navigation scaffold. Open Resume, choose a PDF or DOCX up to
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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
