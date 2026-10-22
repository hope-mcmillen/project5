import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/application_status.dart';
import '../data/board_repository.dart';
import '../domain/board_change.dart';
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

  /// Decisions in flight; background refreshes wait for them so an
  /// optimistic change isn't briefly undone by stale data.
  int _inFlight = 0;
  Timer? _debounce;
  final _commitTimers = <Timer>{};

  @override
  Future<BoardState> build() async {
    final repo = ref.watch(boardRepositoryProvider);
    // RC-14: Realtime for status changes (and any inserts that do reach a
    // recruiter), plus a periodic refetch for new applicants, whose
    // pending inserts RLS hides from recruiters.
    final changes = repo
        .watchApplications(jobId)
        .listen(_onChange, onError: (Object _) {});
    final poll = Timer.periodic(
      ref.watch(boardPollIntervalProvider),
      (_) => _quietRefresh(),
    );
    ref.onDispose(() {
      changes.cancel();
      poll.cancel();
      _debounce?.cancel();
      for (final timer in _commitTimers) {
        timer.cancel();
      }
    });
    final tiles = await repo.getBoard(jobId, limit: pageSize);
    return BoardState(tiles: tiles, hasMore: tiles.length == pageSize);
  }

  void _onChange(BoardChange change) {
    final committedAt = change.committedAt;
    final wait = committedAt?.difference(DateTime.now());
    if (change.isInsert && wait != null && wait > Duration.zero) {
      // Visible to recruiters only once the candidate's undo window ends.
      late final Timer timer;
      timer = Timer(wait + const Duration(milliseconds: 300), () {
        _commitTimers.remove(timer);
        _quietRefresh();
      });
      _commitTimers.add(timer);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _quietRefresh);
  }

  /// Refetches in the background; failures keep the current tiles.
  Future<void> _quietRefresh() async {
    if (_inFlight > 0 || !state.hasValue) return;
    try {
      await refresh();
    } catch (_) {
      // Offline or similar: the next change or poll tries again.
    }
  }

  Future<T> _decide<T>(Future<T> Function() body) async {
    _inFlight++;
    try {
      return await body();
    } finally {
      _inFlight--;
    }
  }

  BoardState get _current => state.value ?? const BoardState();

  void _set(List<BoardTile> tiles) =>
      state = AsyncData(_current.copyWith(tiles: tiles));

  /// Reloads every page loaded so far, keeping the grid in place.
  Future<void> refresh() async {
    final count = _current.tiles.length;
    final limit = count <= pageSize ? pageSize : count.clamp(1, 100);
    final tiles = await _repo.getBoard(jobId, limit: limit);
    // Keep tiles rejected in this session out while their Undo is open.
    tiles.removeWhere((t) => _rejected.containsKey(t.applicationId));
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

  /// Updates one tile's status locally (e.g. after the detail view opened
  /// it), without refetching.
  void markStatus(String applicationId, ApplicationStatus status) => _set([
    for (final t in _current.tiles)
      t.applicationId == applicationId ? t.copyWith(status: status) : t,
  ]);

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
      await _decide(() => _repo.advance(applicationId, note: note));
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
      await _decide(() => _repo.reject(applicationId));
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
      await _decide(() => _repo.undoReject(applicationId));
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
