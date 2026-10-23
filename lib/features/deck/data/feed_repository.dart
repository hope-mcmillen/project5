import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/swipe_receipt.dart';
import 'supabase_feed_repository.dart';

class FeedPage {
  FeedPage({required List<JobCard> cards, this.nextCursor})
    : cards = List.unmodifiable(cards);
  final List<JobCard> cards;
  final String? nextCursor;
  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
    cards: (json['cards'] as List)
        .map((v) => JobCard.fromJson(v as Map<String, dynamic>))
        .toList(),
    nextCursor: json['next_cursor'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'cards': cards.map((c) => c.toJson()).toList(),
    'next_cursor': nextCursor,
  };
}

abstract interface class FeedRepository {
  /// True for the in-memory demo deck, whose applications never reach a
  /// recruiter.
  bool get isDemo;
  Future<FeedPage> getFeed({int limit = 20, String? cursor});
  Future<JobCard> getJob(String jobId);
  Future<SwipeReceipt> swipe(String jobId, SwipeDirection direction);
  Future<void> undoSwipe(String swipeId);
  Future<void> setPassReason(String swipeId, PassReason reason);
}

/// The live deck; `main_fake.dart` and tests override it with the fake.
final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => SupabaseFeedRepository(
    SupabaseFeedSource(ref.watch(supabaseClientProvider)),
  ),
);
