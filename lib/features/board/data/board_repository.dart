import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/board_change.dart';
import '../domain/board_tile.dart';
import 'supabase_board_repository.dart';

/// The blind applicant board for one job (RC-14, API_CONTRACT §7.4).
abstract interface class BoardRepository {
  /// `rpc('get_board')`: sorted by match score, highest first.
  Future<List<BoardTile>> getBoard(
    String jobId, {
    int limit = 50,
    int offset = 0,
  });

  Future<void> advance(String applicationId, {String? note});

  Future<void> reject(String applicationId, {String? reason});

  /// Only works within 10 s of [reject].
  Future<void> undoReject(String applicationId);

  /// Realtime changes to [jobId]'s applications. Also emits a
  /// non-insert change after a reconnect, so the board can catch up.
  Stream<BoardChange> watchApplications(String jobId);
}

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => SupabaseBoardRepository(ref.watch(supabaseClientProvider)),
);

/// How often an open board refetches as a fallback. Pending applications
/// are hidden from recruiters by RLS, so their insert never reaches the
/// recruiter's Realtime socket (API_CONTRACT §7.5).
final boardPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);
