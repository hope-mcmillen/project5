import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../domain/swipe_receipt.dart';
import 'feed_repository.dart';

/// The RPC boundary, kept separate so the mapping and errors can be tested
/// offline (same split as `ApplicationSource`).
abstract interface class FeedSource {
  /// `get_feed` (API_CONTRACT §6): `{cards: [...], next_cursor}`.
  Future<Map<String, dynamic>> getFeed(int limit, String? cursor);

  /// `swipe` (A7): `{swipe_id, application_id, committed_at}`.
  Future<Map<String, dynamic>> swipe(String jobId, String direction);
  Future<void> undoSwipe(String swipeId);
  Future<void> setPassReason(String swipeId, String reason);

  /// `app_config.undo_seconds`, or null when it can't be read.
  Future<int?> undoSeconds();
}

class SupabaseFeedSource implements FeedSource {
  SupabaseFeedSource(this.client);
  final SupabaseClient client;

  @override
  Future<Map<String, dynamic>> getFeed(int limit, String? cursor) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'get_feed',
          params: {'p_limit': limit, 'p_cursor': cursor},
        ) as Map,
      );

  @override
  Future<Map<String, dynamic>> swipe(String jobId, String direction) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'swipe',
          params: {'p_job_id': jobId, 'p_direction': direction},
        ) as Map,
      );

  @override
  Future<void> undoSwipe(String swipeId) async =>
      await client.rpc('undo_swipe', params: {'p_swipe_id': swipeId});

  @override
  Future<void> setPassReason(String swipeId, String reason) async =>
      await client.rpc(
        'set_pass_reason',
        params: {'p_swipe_id': swipeId, 'p_reason': reason},
      );

  @override
  Future<int?> undoSeconds() async {
    final row = await client
        .from('app_config')
        .select('undo_seconds')
        .maybeSingle();
    return (row?['undo_seconds'] as num?)?.toInt();
  }
}

/// The live deck (C8): ranked jobs from `get_feed`, and swipes that become
/// real applications on the recruiter's board.
class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository(this.source, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  final FeedSource source;
  final DateTime Function() now;

  /// Server default, used until `app_config` has been read.
  static const defaultUndoSeconds = 5;

  /// Every card served this session, so a receipt and the deep dive can be
  /// built without another round trip.
  final Map<String, JobCard> _served = {};
  int? _undoSeconds;

  @override
  bool get isDemo => false;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      final failure = AppFailure.from(error);
      final message = _messages[failure.code];
      throw message == null ? failure : AppFailure(failure.code, message);
    }
  }

  static const _messages = {
    'not_candidate': 'Sign in with a candidate account to see jobs.',
    'profile_not_confirmed':
        'Review and confirm your skills to see matching jobs.',
    'job_not_open': 'This role is no longer open.',
    'already_swiped': 'You have already acted on this role.',
    'daily_cap_reached':
        'You\'ve reached today\'s application limit. Come back tomorrow.',
    'invalid_cursor': 'Your deck changed. Refresh to load more jobs.',
    'not_owner': 'That decision is no longer available.',
    'not_left_swipe': 'Only passed roles can have a pass reason.',
  };

  @override
  Future<FeedPage> getFeed({int limit = 20, String? cursor}) =>
      _guard(() async {
        final page = FeedPage.fromJson(
          await source.getFeed(limit.clamp(1, 50), cursor),
        );
        for (final card in page.cards) {
          _served[card.jobId] = card;
        }
        return page;
      });

  @override
  Future<JobCard> getJob(String jobId) async {
    final card = _served[jobId];
    if (card == null) {
      throw const AppFailure(
        'not_found',
        'This role is no longer in your deck.',
      );
    }
    return card;
  }

  @override
  Future<SwipeReceipt> swipe(String jobId, SwipeDirection direction) =>
      _guard(() async {
        final job = await getJob(jobId);
        final window = Duration(seconds: await _undoWindow());
        // The server's deadline starts when it inserts the swipe, which is
        // after this request starts: counting from here never overstates it,
        // whatever the device clock says.
        final startedAt = now().toUtc();
        final result = await source.swipe(jobId, direction.toDb());
        final receivedAt = now().toUtc();
        return SwipeReceipt(
          swipeId: result['swipe_id'] as String,
          job: job,
          direction: direction,
          committedAt: startedAt.add(window),
          serverNow: receivedAt,
          receivedAt: receivedAt,
        );
      });

  Future<int> _undoWindow() async {
    if (_undoSeconds case final seconds?) return seconds;
    try {
      _undoSeconds = await source.undoSeconds() ?? defaultUndoSeconds;
    } catch (_) {
      return defaultUndoSeconds; // try again on the next swipe
    }
    return _undoSeconds!;
  }

  @override
  Future<void> undoSwipe(String swipeId) =>
      _guard(() => source.undoSwipe(swipeId));

  @override
  Future<void> setPassReason(String swipeId, PassReason reason) =>
      _guard(() => source.setPassReason(swipeId, reason.toDb()));
}
