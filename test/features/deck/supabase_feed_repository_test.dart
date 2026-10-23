import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/deck/data/feed_repository.dart';
import 'package:project5/features/deck/data/supabase_feed_repository.dart';
import 'package:project5/features/deck/presentation/deck_screen.dart';
import 'package:project5/ui/theme/rr_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_scope.dart';

/// Records RPC calls and answers with canned JSON or throws.
class _Source implements FeedSource {
  Map<String, dynamic> feed = {'cards': [], 'next_cursor': null};
  Object? failWith;
  int? undo = 7;
  bool undoFails = false;
  final calls = <String>[];

  void _maybeFail() {
    if (failWith case final error?) throw error;
  }

  @override
  Future<Map<String, dynamic>> getFeed(int limit, String? cursor) async {
    calls.add('get_feed($limit, $cursor)');
    _maybeFail();
    return feed;
  }

  @override
  Future<Map<String, dynamic>> swipe(String jobId, String direction) async {
    calls.add('swipe($jobId, $direction)');
    _maybeFail();
    return {
      'swipe_id': 'swipe-1',
      'application_id': direction == 'right' ? 'app-1' : null,
      'committed_at': '2026-10-22T12:00:07Z',
    };
  }

  @override
  Future<void> undoSwipe(String swipeId) async {
    calls.add('undo_swipe($swipeId)');
    _maybeFail();
  }

  @override
  Future<void> setPassReason(String swipeId, String reason) async {
    calls.add('set_pass_reason($swipeId, $reason)');
    _maybeFail();
  }

  @override
  Future<int?> undoSeconds() async {
    calls.add('undo_seconds');
    if (undoFails) throw Exception('offline');
    return undo;
  }
}

PostgrestException _rpcError(String code) =>
    PostgrestException(message: code, code: 'P0001');

void main() {
  final card = CandidateFixtures.deck.first;
  late _Source source;
  late SupabaseFeedRepository repository;
  final clock = DateTime.utc(2026, 10, 22, 12);

  setUp(() {
    source = _Source()
      ..feed = {
        'cards': [card.toJson()],
        'next_cursor': 'abc',
      };
    repository = SupabaseFeedRepository(source, now: () => clock);
  });

  test('is live, not demo', () => expect(repository.isDemo, isFalse));

  test('getFeed maps cards and the cursor and clamps the limit', () async {
    final page = await repository.getFeed(limit: 500, cursor: 'xyz');
    expect(source.calls, ['get_feed(50, xyz)']);
    expect(page.cards.single.jobId, card.jobId);
    expect(page.cards.single.matchScore, card.matchScore);
    expect(page.nextCursor, 'abc');
    expect((await repository.getJob(card.jobId)).title, card.title);
  });

  test('cards with no remote type, job type or title still load', () async {
    source.feed = {
      'cards': [
        card.toJson()
          ..['remote'] = null
          ..['job_type'] = null
          ..['title'] = null,
      ],
    };
    final loaded = (await repository.getFeed()).cards.single;
    expect(loaded.remote, isNull);
    expect(loaded.jobType, isNull);
    expect(loaded.title, 'Untitled role');
  });

  test(
    'a right swipe calls swipe and returns a bounded undo receipt',
    () async {
      await repository.getFeed();
      final receipt = await repository.swipe(card.jobId, SwipeDirection.right);
      expect(source.calls, [
        'get_feed(20, null)',
        'undo_seconds',
        'swipe(${card.jobId}, right)',
      ]);
      expect(receipt.swipeId, 'swipe-1');
      expect(receipt.job.jobId, card.jobId);
      expect(receipt.direction, SwipeDirection.right);
      // Counted from when the request started, using app_config.undo_seconds.
      expect(receipt.undoDeadline, clock.add(const Duration(seconds: 7)));

      await repository.swipe(card.jobId, SwipeDirection.left);
      expect(
        source.calls.where((c) => c == 'undo_seconds'),
        hasLength(1),
        reason: 'the undo window is read once',
      );
    },
  );

  test('an unreadable undo window falls back to the server default', () async {
    source.undoFails = true;
    await repository.getFeed();
    final receipt = await repository.swipe(card.jobId, SwipeDirection.left);
    expect(
      receipt.undoDeadline,
      clock.add(
        const Duration(seconds: SupabaseFeedRepository.defaultUndoSeconds),
      ),
    );
  });

  test('swiping a card that was never served is refused locally', () async {
    await expectLater(
      repository.swipe('missing', SwipeDirection.right),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', 'not_found')),
    );
    expect(source.calls, isEmpty);
  });

  test('undo and pass reasons call their RPCs', () async {
    await repository.undoSwipe('swipe-1');
    await repository.setPassReason('swipe-1', PassReason.stack);
    expect(source.calls, [
      'undo_swipe(swipe-1)',
      'set_pass_reason(swipe-1, stack)',
    ]);
  });

  for (final (code, message) in [
    ('daily_cap_reached', 'today\'s application limit'),
    ('profile_not_confirmed', 'confirm your skills'),
    ('job_not_open', 'no longer open'),
    ('already_swiped', 'already acted'),
  ]) {
    test('$code becomes a friendly AppFailure', () async {
      await repository.getFeed();
      source.failWith = _rpcError(code);
      await expectLater(
        repository.swipe(card.jobId, SwipeDirection.right),
        throwsA(
          isA<AppFailure>()
              .having((f) => f.code, 'code', code)
              .having((f) => f.message, 'message', contains(message)),
        ),
      );
    });
  }

  group('deck on live data', () {
    Future<void> pumpDeck(WidgetTester tester) async {
      await tester.pumpWidget(
        fakeScope(
          MaterialApp(theme: buildRRTheme(), home: const DeckScreen()),
          overrides: [feedRepositoryProvider.overrideWithValue(repository)],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows live cards without the demo note', (tester) async {
      await pumpDeck(tester);
      expect(find.text(card.title), findsWidgets);
      expect(find.textContaining('Demo jobs'), findsNothing);
    });

    testWidgets('an unconfirmed profile is sent to review its skills', (
      tester,
    ) async {
      source.failWith = _rpcError('profile_not_confirmed');
      await pumpDeck(tester);
      expect(find.text('Confirm your skills first'), findsOneWidget);
      expect(find.text('Review skills'), findsOneWidget);
    });
  });
}
