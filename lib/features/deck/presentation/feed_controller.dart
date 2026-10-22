import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../data/feed_repository.dart';
import '../domain/swipe_receipt.dart';

class FeedState {
  FeedState({
    required List<JobCard> cards,
    this.cursor,
    this.busy = false,
    this.error,
    this.lastSwipe,
    this.reasonSaved = false,
    this.reasonSaving = false,
  }) : cards = List.unmodifiable(cards);
  final List<JobCard> cards;
  final String? cursor, error;
  final bool busy;
  final SwipeReceipt? lastSwipe;
  final bool reasonSaved, reasonSaving;
  FeedState copy({
    List<JobCard>? cards,
    bool? busy,
    String? error,
    SwipeReceipt? lastSwipe,
    bool clearSwipe = false,
    bool? reasonSaved,
    bool? reasonSaving,
  }) => FeedState(
    cards: cards ?? this.cards,
    cursor: cursor,
    busy: busy ?? this.busy,
    error: error,
    lastSwipe: clearSwipe ? null : lastSwipe ?? this.lastSwipe,
    reasonSaved: reasonSaved ?? this.reasonSaved,
    reasonSaving: reasonSaving ?? this.reasonSaving,
  );
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

class FeedController extends AsyncNotifier<FeedState> {
  int _epoch = 0;
  @override
  Future<FeedState> build() async {
    _epoch++;
    final page = await ref.watch(feedRepositoryProvider).getFeed();
    return FeedState(cards: page.cards, cursor: page.nextCursor);
  }

  Future<bool> commit(SwipeDirection direction) async {
    final current = state.asData?.value;
    if (current == null || current.busy || current.cards.isEmpty) return false;
    final epoch = _epoch;
    final job = current.cards.first;
    state = AsyncData(current.copy(busy: true));
    try {
      final receipt = await ref
          .read(feedRepositoryProvider)
          .swipe(job.jobId, direction);
      if (!ref.mounted || epoch != _epoch) return true;
      var cards = current.cards.skip(1).toList();
      var cursor = current.cursor;
      // Cursor pages are optional; do not turn a successful application into an
      // error merely because prefetch fails. Keep the cursor for an explicit retry.
      if (cards.length <= 5 && cursor != null) {
        try {
          final page = await ref
              .read(feedRepositoryProvider)
              .getFeed(cursor: cursor);
          final ids = cards.map((c) => c.jobId).toSet();
          cards = [...cards, ...page.cards.where((c) => ids.add(c.jobId))];
          cursor = page.nextCursor;
        } catch (_) {
          /* next refresh can fetch remaining jobs */
        }
      }
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          FeedState(cards: cards, cursor: cursor, lastSwipe: receipt),
        );
      }
      return true;
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        final latest = state.asData?.value ?? current;
        state = AsyncData(
          latest.copy(
            busy: false,
            error: error is AppFailure
                ? error.message
                : 'That action could not be saved. Please try again.',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> undo(String swipeId) async {
    final current = state.asData?.value;
    if (current == null ||
        current.busy ||
        current.reasonSaving ||
        current.lastSwipe?.swipeId != swipeId) {
      return false;
    }
    final receipt = current.lastSwipe!;
    final epoch = _epoch;
    state = AsyncData(current.copy(busy: true));
    try {
      await ref.read(feedRepositoryProvider).undoSwipe(swipeId);
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          current.copy(
            cards: [
              receipt.job,
              ...current.cards.where((j) => j.jobId != receipt.job.jobId),
            ],
            busy: false,
            clearSwipe: true,
          ),
        );
      }
      return true;
    } catch (error) {
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          current.copy(
            busy: false,
            error: error is AppFailure
                ? error.message
                : 'Could not undo. Please try again.',
          ),
        );
      }
      return false;
    }
  }

  Future<void> setReason(String swipeId, PassReason reason) async {
    final current = state.asData?.value;
    if (current == null ||
        current.busy ||
        current.reasonSaving ||
        current.reasonSaved ||
        current.lastSwipe?.swipeId != swipeId) {
      return;
    }
    final epoch = _epoch;
    state = AsyncData(current.copy(reasonSaving: true));
    try {
      await ref.read(feedRepositoryProvider).setPassReason(swipeId, reason);
      final latest = state.asData?.value;
      if (ref.mounted &&
          epoch == _epoch &&
          latest?.lastSwipe?.swipeId == swipeId) {
        state = AsyncData(latest!.copy(reasonSaving: false, reasonSaved: true));
      }
    } catch (error) {
      final latest = state.asData?.value;
      if (ref.mounted &&
          epoch == _epoch &&
          latest?.lastSwipe?.swipeId == swipeId) {
        state = AsyncData(
          latest!.copy(
            reasonSaving: false,
            error: error is AppFailure
                ? error.message
                : 'Could not save the reason. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.busy || current.cursor == null) return;
    final epoch = _epoch;
    state = AsyncData(current.copy(busy: true));
    try {
      final page = await ref
          .read(feedRepositoryProvider)
          .getFeed(cursor: current.cursor);
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          FeedState(
            cards: [...current.cards, ...page.cards],
            cursor: page.nextCursor,
            lastSwipe: current.lastSwipe,
          ),
        );
      }
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = AsyncData(
          current.copy(
            busy: false,
            error: 'Could not load more jobs. Please try again.',
          ),
        );
      }
    }
  }
}
