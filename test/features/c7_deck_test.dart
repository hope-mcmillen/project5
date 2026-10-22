import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/deck/data/feed_repository.dart';
import 'package:project5/features/deck/data/fake_feed_repository.dart';
import 'package:project5/features/deck/domain/swipe_receipt.dart';
import 'package:project5/features/deck/presentation/feed_controller.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/features/pipeline/data/application_repository.dart';

void main() {
  test('undo removes application, restores exact card, and supports applying again', () async {
    final c = ProviderContainer(
      overrides: fakeRepositoryOverrides(latency: Duration.zero),
    );
    addTearDown(c.dispose);
    final profile = c.read(profileRepositoryProvider);
    final draft = (await profile.latestVersion())!;
    await profile.confirm(draft.id, draft.candidateSkills);
    final initial = await c.read(feedControllerProvider.future);
    final controller = c.read(feedControllerProvider.notifier);
    final apps = c.read(applicationRepositoryProvider);
    final count = (await apps.watchMine().first).length;
    expect(await controller.commit(SwipeDirection.right), isTrue);
    final receipt = c.read(feedControllerProvider).requireValue.lastSwipe!;
    expect((await apps.watchMine().first), hasLength(count + 1));
    final repo = c.read(feedRepositoryProvider) as FakeFeedRepository;
    repo.failNext = const AppFailure('offline');
    expect(await controller.undo(receipt.swipeId), isFalse);
    expect(
      c.read(feedControllerProvider).requireValue.cards.first.jobId,
      isNot(initial.cards.first.jobId),
    );
    expect((await apps.watchMine().first), hasLength(count + 1));
    expect(await controller.undo(receipt.swipeId), isTrue);
    expect(
      c.read(feedControllerProvider).requireValue.cards.first.jobId,
      initial.cards.first.jobId,
    );
    expect((await apps.watchMine().first), hasLength(count));
    expect(await controller.commit(SwipeDirection.right), isTrue);
    expect((await apps.watchMine().first), hasLength(count + 1));
  });

  test('pass reasons are optional, scoped to passes and removed on undo; deadline is enforced', () async {
    var now = DateTime.utc(2026, 10, 22);
    final repo = FakeFeedRepository(latency: Duration.zero, now: () => now);
    final receipt = await repo.swipe(
      CandidateFixtures.deck.first.jobId,
      SwipeDirection.left,
    );
    expect(repo.passReasons, isEmpty);
    await repo.setPassReason(receipt.swipeId, PassReason.salary);
    expect(repo.passReasons[receipt.swipeId], PassReason.salary);
    await repo.undoSwipe(receipt.swipeId);
    expect(repo.passReasons, isEmpty);
    expect(repo.decisions, isEmpty);
    final apply = await repo.swipe(
      CandidateFixtures.deck.first.jobId,
      SwipeDirection.right,
    );
    await expectLater(
      repo.setPassReason(apply.swipeId, PassReason.stack),
      throwsA(isA<AppFailure>()),
    );
    now = now.add(const Duration(seconds: 5));
    await expectLater(
      repo.undoSwipe(apply.swipeId),
      throwsA(isA<AppFailure>()),
    );
    expect(repo.decisions, hasLength(1));
  });

  test('server clock offset determines the local undo deadline', () {
    final server = DateTime.utc(2026, 10, 22, 12);
    final client = server.add(const Duration(hours: 3));
    final receipt = SwipeReceipt(
      swipeId: '1',
      job: CandidateFixtures.job,
      direction: SwipeDirection.right,
      committedAt: server.add(const Duration(seconds: 2)),
      serverNow: server,
      receivedAt: client,
    );
    expect(receipt.undoDeadline, client.add(const Duration(seconds: 2)));
  });
}
