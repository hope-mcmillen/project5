import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/testing/candidate_fixtures.dart';
import '../../../core/testing/fake_repository.dart';
import 'feed_repository.dart';
import '../domain/swipe_receipt.dart';

class FakeFeedRepository extends FakeRepository implements FeedRepository {
  FakeFeedRepository({
    super.latency,
    List<JobCard>? cards,
    this.preferences,
    this.confirmedProfile,
    this.onApply,
    this.onUndoApply,
    DateTime Function()? now,
  }) : _cards = List.of(cards ?? CandidateFixtures.deck),
       now = now ?? DateTime.now;
  final DateTime Function() now;
  final Future<void> Function(String jobId)? onUndoApply;
  final Map<String, SwipeReceipt> _receipts = {};
  final Map<String, PassReason> passReasons = {};
  int _sequence = 0;
  final Future<Preferences> Function()? preferences;
  final Future<bool> Function()? confirmedProfile;
  final Future<void> Function(JobCard)? onApply;
  final Map<String, SwipeDirection> decisions = {};
  final Set<String> _pending = {};
  final List<JobCard> _cards;
  @override
  Future<FeedPage> getFeed({int limit = 20, String? cursor}) async {
    await call();
    final prefs = await preferences?.call() ?? Preferences();
    final offset = cursor == null
        ? 0
        : cursor.startsWith('fake:')
        ? int.tryParse(cursor.substring(5))
        : null;
    if (offset == null || offset < 0 || offset > _cards.length) {
      throw const AppFailure('invalid_cursor');
    }
    var end = offset;
    final page = <JobCard>[];
    while (end < _cards.length && page.length < limit.clamp(1, 50)) {
      final card = _cards[end++];
      if (!decisions.containsKey(card.jobId) && _eligible(card, prefs)) {
        page.add(card);
      }
    }
    return FeedPage(
      cards: page,
      nextCursor: end < _cards.length ? 'fake:$end' : null,
    );
  }

  bool _eligible(JobCard card, Preferences prefs) =>
      ((prefs.locations?.isEmpty ?? true) ||
          card.remote == RemoteType.remote ||
          prefs.locations!.any(
            (v) =>
                v.trim().toLowerCase() == card.location?.trim().toLowerCase(),
          )) &&
      ((prefs.remote?.isEmpty ?? true) ||
          prefs.remote!.contains(card.remote)) &&
      ((prefs.jobTypes?.isEmpty ?? true) ||
          prefs.jobTypes!.contains(card.jobType)) &&
      (prefs.needsSponsorship != true || card.sponsorship) &&
      (prefs.salaryMin == null ||
          (card.salaryMax != null && card.salaryMax! >= prefs.salaryMin!)) &&
      (prefs.includeStretch == true || card.matchScore >= 50);

  @override
  Future<SwipeReceipt> swipe(String jobId, SwipeDirection direction) async {
    if (_pending.contains(jobId) || decisions.containsKey(jobId)) {
      throw const AppFailure(
        'already_swiped',
        'You have already acted on this role.',
      );
    }
    _pending.add(jobId);
    try {
      await call();
      final card = _cards.firstWhere(
        (j) => j.jobId == jobId,
        orElse: () => throw const AppFailure('not_found'),
      );
      if (direction == SwipeDirection.right) {
        if (confirmedProfile != null && !await confirmedProfile!()) {
          throw const AppFailure(
            'profile_not_confirmed',
            'Review and confirm your skills before applying.',
          );
        }
        await onApply?.call(card);
      }
      decisions[jobId] = direction;
      final time = now().toUtc();
      final receipt = SwipeReceipt(
        swipeId: 'demo-swipe-${++_sequence}',
        job: card,
        direction: direction,
        committedAt: time.add(const Duration(seconds: 5)),
        serverNow: time,
        receivedAt: time,
      );
      _receipts[receipt.swipeId] = receipt;
      return receipt;
    } finally {
      _pending.remove(jobId);
    }
  }

  @override
  Future<void> undoSwipe(String swipeId) async {
    await call();
    final receipt = _receipts[swipeId];
    if (receipt == null) {
      throw const AppFailure(
        'not_found',
        'This swipe has already been undone.',
      );
    }
    if (!now().toUtc().isBefore(receipt.committedAt)) {
      throw const AppFailure(
        'undo_window_expired',
        'The undo window has ended.',
      );
    }
    if (receipt.direction == SwipeDirection.right) {
      await onUndoApply?.call(receipt.job.jobId);
    }
    decisions.remove(receipt.job.jobId);
    passReasons.remove(swipeId);
    _receipts.remove(swipeId);
  }

  @override
  Future<void> setPassReason(String swipeId, PassReason reason) async {
    await call();
    final receipt = _receipts[swipeId];
    if (receipt == null || receipt.direction != SwipeDirection.left) {
      throw const AppFailure(
        'invalid_swipe',
        'Only passed roles can have a pass reason.',
      );
    }
    passReasons[swipeId] = reason;
  }

  @override
  Future<JobCard> getJob(String jobId) async {
    await call();
    return _cards.firstWhere(
      (c) => c.jobId == jobId,
      orElse: () => throw const AppFailure('not_found'),
    );
  }
}
