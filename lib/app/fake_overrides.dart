import 'package:flutter_riverpod/misc.dart';

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
  Duration latency = const Duration(milliseconds: 300),
  bool simulateParsing = true,
}) => [
  profileRepositoryProvider.overrideWith(
    (ref) => FakeProfileRepository(latency: latency),
  ),
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
  resumeRepositoryProvider.overrideWith((ref) {
    final repository = FakeResumeRepository(
      latency: latency,
      simulateParsing: simulateParsing,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }),
  resumeSimulationProvider.overrideWithValue(true),
  applicationRepositoryProvider.overrideWith((ref) {
    final repository = FakeApplicationRepository(latency: latency);
    ref.onDispose(repository.dispose);
    return repository;
  }),
];
