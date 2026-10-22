import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/application_status.dart';
import '../data/board_repository.dart';
import '../domain/board_tile.dart';

/// One job's board: tiles in score order, plus pagination state.
class BoardState {
  const BoardState({this.tiles = const [], this.hasMore = false});

  final List<BoardTile> tiles;

  /// The last page was full, so there may be more.
  final bool hasMore;

  BoardState copyWith({List<BoardTile>? tiles, bool? hasMore}) =>
      BoardState(tiles: tiles ?? this.tiles, hasMore: hasMore ?? this.hasMore);
}

/// Loads `get_board` 50 tiles at a time and applies advance / reject /
/// undo optimistically, rolling back if the server refuses (RC-13, RC-14).
final boardControllerProvider =
    AsyncNotifierProvider.family<BoardController, BoardState, String>(
      BoardController.new,
    );

class BoardController extends AsyncNotifier<BoardState> {
  BoardController(this.jobId);

  final String jobId;

  static const pageSize = 50;

  /// Rejected tiles and where they were, so Undo can put them back.
  final _rejected = <String, (BoardTile tile, int index)>{};

  BoardRepository get _repo => ref.read(boardRepositoryProvider);

  @override
  Future<BoardState> build() async {
    final tiles = await ref
        .watch(boardRepositoryProvider)
        .getBoard(jobId, limit: pageSize);
    return BoardState(tiles: tiles, hasMore: tiles.length == pageSize);
  }

  BoardState get _current => state.value ?? const BoardState();

  void _set(List<BoardTile> tiles) =>
      state = AsyncData(_current.copyWith(tiles: tiles));

  /// Reloads every page loaded so far, keeping the grid in place.
  Future<void> refresh() async {
    final count = _current.tiles.length;
    final limit = count <= pageSize ? pageSize : count.clamp(1, 100);
    final tiles = await _repo.getBoard(jobId, limit: limit);
    state = AsyncData(BoardState(tiles: tiles, hasMore: tiles.length == limit));
  }

  Future<void> loadMore() async {
    final current = _current;
    if (!current.hasMore) return;
    final page = await _repo.getBoard(
      jobId,
      limit: pageSize,
      offset: current.tiles.length,
    );
    final known = {for (final t in current.tiles) t.applicationId};
    state = AsyncData(
      BoardState(
        tiles: [
          ...current.tiles,
          for (final t in page)
            if (!known.contains(t.applicationId)) t,
        ],
        hasMore: page.length == pageSize,
      ),
    );
  }

  /// Advances to INTERVIEW_REQUESTED. Throws (after rolling back) on error.
  Future<void> advance(String applicationId, {String? note}) async {
    final before = _current.tiles;
    _set([
      for (final t in before)
        t.applicationId == applicationId
            ? t.copyWith(status: ApplicationStatus.interviewRequested)
            : t,
    ]);
    try {
      await _repo.advance(applicationId, note: note);
    } catch (_) {
      _set(before);
      rethrow;
    }
  }

  /// Rejects: the tile leaves the grid at once. Throws (after putting it
  /// back) on error.
  Future<void> reject(String applicationId) async {
    final before = _current.tiles;
    final index = before.indexWhere((t) => t.applicationId == applicationId);
    if (index == -1) return;
    _rejected[applicationId] = (before[index], index);
    _set([...before]..removeAt(index));
    try {
      await _repo.reject(applicationId);
    } catch (_) {
      _rejected.remove(applicationId);
      _set(before);
      rethrow;
    }
  }

  /// Undoes a reject within 10 s. Throws on error (e.g.
  /// `undo_window_expired`), leaving the tile out.
  Future<void> undoReject(String applicationId) async {
    final rejected = _rejected.remove(applicationId);
    if (rejected == null) return;
    final (tile, index) = rejected;
    final before = _current.tiles;
    _set([...before]..insert(index.clamp(0, before.length), tile));
    try {
      await _repo.undoReject(applicationId);
    } catch (_) {
      _set(before);
      rethrow;
    }
  }
}

/// The tile whose triangle actions are showing on touch screens (one at a
/// time).
final selectedTileProvider = NotifierProvider<SelectedTile, String?>(
  SelectedTile.new,
);

class SelectedTile extends Notifier<String?> {
  @override
  String? build() => null;

  void toggle(String applicationId) =>
      state = state == applicationId ? null : applicationId;

  void clear() => state = null;
}
