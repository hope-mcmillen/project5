import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/features/profile/data/fake_profile_repository.dart';
import 'package:project5/features/onboarding/presentation/review_controller.dart';
import 'package:project5/features/onboarding/presentation/preferences_controller.dart';
import 'package:project5/features/deck/data/feed_repository.dart';
import 'package:project5/features/deck/data/fake_feed_repository.dart';
import 'package:project5/features/deck/presentation/feed_controller.dart';
import 'package:project5/features/pipeline/data/application_repository.dart';

void main() {
  late ProviderContainer container;
  setUp(
    () => container = ProviderContainer(
      overrides: fakeRepositoryOverrides(latency: Duration.zero),
    ),
  );
  tearDown(() => container.dispose());

  test('skill drafts preserve evidence and only persist on successful confirmation', () async {
    final sub = container.listen(reviewControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final initial = await container.read(reviewControllerProvider.future);
    final controller = container.read(reviewControllerProvider.notifier);
    final repo =
        container.read(profileRepositoryProvider) as FakeProfileRepository;
    final skill = initial.skills.single;
    controller.years(skill.id, 3.5);
    controller.choose(replacingId: skill.id, name: 'Flutter development');
    final edit = container
        .read(reviewControllerProvider)
        .requireValue
        .skills
        .single;
    expect(edit.years, 3.5);
    expect(edit.source, SkillSource.user);
    expect(edit.evidence, skill.evidence);
    expect(
      (await repo.latestVersion())!.candidateSkills.single.rawName,
      'Flutter',
    );
    controller.choose(name: 'Flutter development');
    expect(
      container.read(reviewControllerProvider).requireValue.error,
      isNotNull,
    );
    expect(
      container.read(reviewControllerProvider).requireValue.skills,
      hasLength(1),
    );
    controller.choose(
      name: 'Dart',
      skill: CandidateFixtures.taxonomy.firstWhere((s) => s.name == 'Dart'),
    );
    repo.failNext = const AppFailure('offline', 'Offline');
    expect(await controller.confirm(), isFalse);
    expect(
      container.read(reviewControllerProvider).requireValue.skills,
      hasLength(2),
    );
    expect((await repo.latestVersion())!.confirmed, isFalse);
    expect(await controller.confirm(), isTrue);
    final confirmed = (await repo.latestVersion())!;
    expect(confirmed.confirmed, isTrue);
    expect(confirmed.candidateSkills.first.rawName, 'Flutter development');
    container.invalidate(reviewControllerProvider);
    final next = await container.read(reviewControllerProvider.future);
    expect(next.version.id, isNot(confirmed.id));
    expect(next.skills, hasLength(2));
    final reopened = container.read(reviewControllerProvider.notifier);
    reopened.choose(name: 'Python');
    expect(
      container
          .read(reviewControllerProvider)
          .requireValue
          .skills
          .map((s) => s.id)
          .toSet(),
      hasLength(3),
    );
    reopened.remove(next.skills.first.id);
    expect(confirmed.candidateSkills, hasLength(2));
  });

  test('preferences save retains choices on failure and filters without changing scores', () async {
    final sub = container.listen(preferencesControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(preferencesControllerProvider.future);
    final controller = container.read(preferencesControllerProvider.notifier);
    final repo =
        container.read(profileRepositoryProvider) as FakeProfileRepository;
    expect(controller.addLocation(' Austin, TX '), isTrue);
    controller.addLocation('austin, tx');
    controller.toggle('remote', 'remote');
    controller.toggle('job_types', 'full_time');
    controller.set('needs_sponsorship', true);
    controller.set('salary_min', 130000);
    repo.failNext = const AppFailure('offline');
    expect(await controller.save(), isFalse);
    expect(
      container
          .read(preferencesControllerProvider)
          .requireValue
          .preferences
          .locations,
      ['Austin, TX'],
    );
    expect((await repo.preferences()).salaryMin, isNull);
    expect(await controller.save(), isTrue);
    final jobs = (await container.read(feedRepositoryProvider).getFeed()).cards;
    expect(jobs.map((j) => j.company.name), ['Northline Labs']);
    expect(jobs.single.matchScore, 84);
    expect((await repo.preferences()).salaryMin, 130000);
  });

  test('feed applies all eligibility filters and stretch choice', () async {
    var prefs = Preferences(
      locations: ['Baton Rouge, LA'],
      remote: [RemoteType.hybrid],
      jobTypes: [JobType.fullTime],
    );
    final repo = FakeFeedRepository(
      latency: Duration.zero,
      preferences: () async => prefs,
    );
    expect((await repo.getFeed()).cards.map((j) => j.company.name), [
      'Pelican Path Health',
    ]);
    prefs = Preferences(includeStretch: true);
    expect((await repo.getFeed()).cards, hasLength(5));
    prefs = Preferences(needsSponsorship: true);
    expect((await repo.getFeed()).cards.map((j) => j.company.name), [
      'Northline Labs',
    ]);
    prefs = Preferences(salaryMin: 200000);
    expect((await repo.getFeed()).cards, isEmpty);
  });

  test('failed and unconfirmed swipes retain cards; apply records one versioned application', () async {
    final initial = await container.read(feedControllerProvider.future);
    final controller = container.read(feedControllerProvider.notifier);
    final feed = container.read(feedRepositoryProvider) as FakeFeedRepository;
    final repo = container.read(profileRepositoryProvider);
    expect(await controller.commit(SwipeDirection.right), isFalse);
    expect(
      container.read(feedControllerProvider).requireValue.cards.first.jobId,
      initial.cards.first.jobId,
    );
    final draft = (await repo.latestVersion())!;
    await repo.confirm(draft.id, draft.candidateSkills);
    feed.failNext = const AppFailure('offline');
    expect(await controller.commit(SwipeDirection.left), isFalse);
    expect(feed.decisions, isEmpty);
    expect(await controller.commit(SwipeDirection.right), isTrue);
    final application =
        (await container.read(applicationRepositoryProvider).watchMine().first)
            .first;
    expect(application.jobId, initial.cards.first.jobId);
    expect(application.profileVersionId, draft.id);
    expect(application.status, ApplicationStatus.applied);
    await expectLater(
      feed.swipe(application.jobId, SwipeDirection.right),
      throwsA(isA<AppFailure>()),
    );
    expect(await controller.commit(SwipeDirection.left), isTrue);
    final after = await container
        .read(applicationRepositoryProvider)
        .watchMine()
        .first;
    expect(after.where((a) => a.id == application.id), hasLength(1));
    expect(after.any((a) => a.jobId == initial.cards[1].jobId), isFalse);
  });

  test(
    'pagination cursor remains stable after deciding a previous card',
    () async {
      final repo = FakeFeedRepository(latency: Duration.zero);
      final first = await repo.getFeed(limit: 2);
      await repo.swipe(first.cards.first.jobId, SwipeDirection.left);
      final second = await repo.getFeed(cursor: first.nextCursor);
      expect(second.cards.first.jobId, CandidateFixtures.deck[2].jobId);
      expect(
        (await repo.getFeed()).cards.any(
          (j) => j.jobId == first.cards.first.jobId,
        ),
        isFalse,
      );
    },
  );
}
