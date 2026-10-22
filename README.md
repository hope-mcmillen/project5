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
database authorization or real document parsing. Candidate screen content is
still scaffolded; its UI is covered by later stories.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
