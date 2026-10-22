import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';
import '../domain/swipe_receipt.dart';

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
  Future<FeedPage> getFeed({int limit = 20, String? cursor});
  Future<JobCard> getJob(String jobId);
  Future<SwipeReceipt> swipe(String jobId, SwipeDirection direction);
  Future<void> undoSwipe(String swipeId);
  Future<void> setPassReason(String swipeId, PassReason reason);
}

final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) =>
      throw UnimplementedError('FeedRepository: use main_fake.dart until C8.'),
);
