import 'package:flutter_riverpod/misc.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/data/fake_company_repository.dart';
import '../features/jobs/data/job_repository.dart';
import '../features/jobs/data/fake_job_repository.dart';
import '../features/board/data/board_repository.dart';
import '../features/board/data/fake_board_repository.dart';

import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/fake_profile_repository.dart';
import '../features/deck/data/feed_repository.dart';
import '../features/deck/data/fake_feed_repository.dart';
import '../features/onboarding/data/resume_repository.dart';
import '../features/onboarding/data/fake_resume_repository.dart';
import '../features/pipeline/data/application_repository.dart';
import '../features/pipeline/data/fake_application_repository.dart';

/// Fresh repositories per provider scope. No backend initialization required.
List<Override> fakeRepositoryOverrides({
  Duration? latency,
  bool simulateParsing = true,
  FakeAuthRepository? auth,
  FakeCompanyRepository? companies,
  FakeJobRepository? jobs,
  FakeBoardRepository? board,
}) {
  final effectiveLatency =
      latency ?? auth?.latency ?? const Duration(milliseconds: 300);
  final fakeAuth = auth ?? FakeAuthRepository(latency: effectiveLatency);
  return [
    authRepositoryProvider.overrideWithValue(fakeAuth),
    companyRepositoryProvider.overrideWithValue(
      companies ??
          FakeCompanyRepository(auth: fakeAuth, latency: fakeAuth.latency),
    ),
    jobRepositoryProvider.overrideWithValue(
      jobs ?? FakeJobRepository(latency: fakeAuth.latency),
    ),
    boardRepositoryProvider.overrideWithValue(
      board ?? FakeBoardRepository(latency: fakeAuth.latency),
    ),
    ...candidateRepositoryOverrides(
      latency: effectiveLatency,
      simulateParsing: simulateParsing,
    ),
  ];
}

List<Override> candidateRepositoryOverrides({
  Duration latency = const Duration(milliseconds: 300),
  bool simulateParsing = true,
}) => [
  profileRepositoryProvider.overrideWith(
    (ref) => FakeProfileRepository(latency: latency),
  ),
  resumeRepositoryProvider.overrideWith((ref) {
    final repository = FakeResumeRepository(
      latency: latency,
      simulateParsing: simulateParsing,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }),
  resumeSimulationProvider.overrideWithValue(true),
  ...feedAndApplicationOverrides(latency: latency),
];

/// The deck and pipeline still run on fakes in the Supabase build: they have
/// no Supabase repositories yet. Resume parsing and profiles are real there.
List<Override> feedAndApplicationOverrides({
  Duration latency = const Duration(milliseconds: 300),
}) => [
  feedRepositoryProvider.overrideWith((ref) {
    final createdApplications = <String>{};
    return FakeFeedRepository(
      latency: latency,
      preferences: () => ref.read(profileRepositoryProvider).preferences(),
      confirmedProfile: () async =>
          (await ref.read(profileRepositoryProvider).latestVersion())
              ?.confirmed ==
          true,
      onApply: (job) async {
        final version = await ref
            .read(profileRepositoryProvider)
            .latestVersion();
        final applications = ref.read(applicationRepositoryProvider);
        if (version != null && applications is FakeApplicationRepository) {
          if (applications.recordApplication(job, version.id)) {
            createdApplications.add(job.jobId);
          }
        }
      },
      onUndoApply: (jobId) async {
        final applications = ref.read(applicationRepositoryProvider);
        if (applications is FakeApplicationRepository &&
            createdApplications.remove(jobId)) {
          applications.undoApplication(jobId);
        }
      },
    );
  }),
  applicationRepositoryProvider.overrideWith((ref) {
    final repository = FakeApplicationRepository(latency: latency);
    ref.onDispose(repository.dispose);
    return repository;
  }),
];
