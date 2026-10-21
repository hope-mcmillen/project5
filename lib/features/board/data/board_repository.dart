import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/board_tile.dart';
import 'fake_board_repository.dart';

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
}

/// TODO(RC-14): switch the default to `SupabaseBoardRepository`.
final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => FakeBoardRepository(),
);
