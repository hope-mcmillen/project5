import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/board_change.dart';
import '../domain/board_tile.dart';
import 'board_repository.dart';

/// [BoardRepository] backed by the A8 board RPCs and Realtime (RC-14).
class SupabaseBoardRepository implements BoardRepository {
  SupabaseBoardRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<BoardTile>> getBoard(
    String jobId, {
    int limit = 50,
    int offset = 0,
  }) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_board',
      params: {
        'p_job_id': jobId,
        'p_filters': <String, dynamic>{},
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return [
      for (final row in rows)
        BoardTile.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  });

  @override
  Future<void> advance(String applicationId, {String? note}) => _guard(
    () => _client.rpc<void>(
      'advance',
      params: {'p_application_id': applicationId, 'p_note': note},
    ),
  );

  @override
  Future<void> reject(String applicationId, {String? reason}) => _guard(
    () => _client.rpc<void>(
      'reject',
      params: {'p_application_id': applicationId, 'p_reason': reason},
    ),
  );

  @override
  Future<void> undoReject(String applicationId) => _guard(
    () => _client.rpc<void>(
      'undo_reject',
      params: {'p_application_id': applicationId},
    ),
  );

  @override
  Stream<BoardChange> watchApplications(String jobId) {
    RealtimeChannel? channel;
    var subscribedOnce = false;
    late final StreamController<BoardChange> controller;
    controller = StreamController<BoardChange>(
      onListen: () {
        channel = _client
            .channel('board:$jobId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'applications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'job_id',
                value: jobId,
              ),
              callback: (payload) {
                final committed = payload.newRecord['committed_at'];
                controller.add(
                  BoardChange(
                    isInsert: payload.eventType == PostgresChangeEvent.insert,
                    committedAt: committed is String
                        ? DateTime.tryParse(committed)
                        : null,
                  ),
                );
              },
            )
            .subscribe((status, error) {
              if (status != RealtimeSubscribeStatus.subscribed) return;
              // A re-subscribe means we were disconnected: catch up.
              if (subscribedOnce) {
                controller.add(const BoardChange(isInsert: false));
              }
              subscribedOnce = true;
            });
      },
      onCancel: () async {
        final current = channel;
        if (current != null) await _client.removeChannel(current);
      },
    );
    return controller.stream;
  }
}
