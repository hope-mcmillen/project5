import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/features/profile/data/fake_profile_repository.dart';
import 'package:project5/features/deck/data/feed_repository.dart';
import 'package:project5/features/deck/data/fake_feed_repository.dart';
import 'package:project5/features/onboarding/data/resume_repository.dart';
import 'package:project5/features/onboarding/data/fake_resume_repository.dart';
import 'package:project5/features/pipeline/data/application_repository.dart';
import 'package:project5/features/pipeline/data/fake_application_repository.dart';

void main() {
  test('profile fake can start without a draft', () async {
    final repo = FakeProfileRepository(latency: Duration.zero, seedData: false);
    expect(await repo.latestVersion(), isNull);
    expect((await repo.createManualProfile()).version, 1);
  });
  test('fake mode overrides every candidate repository without Supabase', () {
    final container = ProviderContainer(overrides: fakeRepositoryOverrides());
    addTearDown(container.dispose);
    expect(
      container.read(profileRepositoryProvider),
      isA<FakeProfileRepository>(),
    );
    expect(container.read(feedRepositoryProvider), isA<FakeFeedRepository>());
    expect(
      container.read(resumeRepositoryProvider),
      isA<FakeResumeRepository>(),
    );
    expect(
      container.read(applicationRepositoryProvider),
      isA<FakeApplicationRepository>(),
    );
  });
  test(
    'profile edits, confirmation, preferences, and errors stay in memory',
    () async {
      final repo = FakeProfileRepository(latency: Duration.zero);
      expect(await repo.searchSkills('FLUTTER SDK'), hasLength(1));
      final draft = await repo.latestVersion();
      await repo.confirm(draft!.id, draft.candidateSkills);
      expect((await repo.latestVersion())!.confirmed, isTrue);
      await expectLater(repo.confirm(draft.id, []), throwsA(isA<AppFailure>()));
      final next = await repo.createManualProfile();
      expect(next.version, 2);
      expect(next.confirmed, isFalse);
      await repo.savePreferences(Preferences(salaryMin: 70000));
      expect((await repo.preferences()).salaryMin, 70000);
      repo.failNext = const AppFailure('offline');
      await expectLater(repo.latestVersion(), throwsA(isA<AppFailure>()));
      expect(await repo.latestVersion(), isNotNull);
    },
  );
  test('feed supports pagination, empty data, and invalid cursor', () async {
    final jobs = List.generate(
      3,
      (i) => JobCard.fromJson({
        ...CandidateFixtures.job.toJson(),
        'job_id': 'job-$i',
      }),
    );
    final repo = FakeFeedRepository(latency: Duration.zero, cards: jobs);
    final first = await repo.getFeed(limit: 2);
    final second = await repo.getFeed(limit: 2, cursor: first.nextCursor);
    expect(
      [...first.cards, ...second.cards].map((j) => j.jobId).toSet(),
      hasLength(3),
    );
    expect(second.nextCursor, isNull);
    expect(
      (await FakeFeedRepository(
        latency: Duration.zero,
        cards: [],
      ).getFeed()).cards,
      isEmpty,
    );
    await expectLater(repo.getFeed(cursor: 'bad'), throwsA(isA<AppFailure>()));
  });
  test('resume streams every parse status and rejects invalid files', () async {
    final repo = FakeResumeRepository(latency: Duration.zero);
    addTearDown(repo.dispose);
    final resume = await repo.upload(
      filename: 'demo.pdf',
      bytes: Uint8List.fromList([1]),
    );
    final seen = <ResumeStatus>[];
    final subscription = repo
        .watchStatus(resume.id)
        .listen((r) => seen.add(r.status));
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    for (final status in ResumeStatus.values.skip(1)) {
      repo.setStatus(resume.id, status);
    }
    await Future<void>.delayed(Duration.zero);
    expect(seen, ResumeStatus.values);
    await expectLater(
      repo.upload(filename: 'bad.txt', bytes: Uint8List(1)),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'pipeline includes all states and withdrawal emits a timeline event',
    () async {
      final repo = FakeApplicationRepository(latency: Duration.zero);
      addTearDown(repo.dispose);
      final seen = <List<Application>>[];
      final subscription = repo.watchMine().listen(seen.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.single.map((a) => a.status).toSet(),
        ApplicationStatus.values.toSet(),
      );
      final id = seen.single
          .firstWhere((a) => a.status == ApplicationStatus.applied)
          .id;
      await repo.withdraw(id);
      await Future<void>.delayed(Duration.zero);
      expect(
        seen.last.firstWhere((a) => a.id == id).status,
        ApplicationStatus.withdrawn,
      );
      expect(
        (await repo.statusEvents(id)).single.toStatus,
        ApplicationStatus.withdrawn,
      );
      await expectLater(repo.withdraw(id), throwsA(isA<AppFailure>()));
    },
  );
}
