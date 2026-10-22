import '../../../core/models/candidate_models.dart';

extension PassReasonLabel on PassReason {
  String get label => switch (this) {
    PassReason.location => 'Location',
    PassReason.salary => 'Salary',
    PassReason.stack => 'Tech stack',
    PassReason.seniority => 'Seniority',
    PassReason.company => 'Company',
  };
}

/// Server time accompanies the receipt so device clock skew cannot extend undo.
class SwipeReceipt {
  const SwipeReceipt({
    required this.swipeId,
    required this.job,
    required this.direction,
    required this.committedAt,
    required this.serverNow,
    required this.receivedAt,
  });
  final String swipeId;
  final JobCard job;
  final SwipeDirection direction;
  final DateTime committedAt, serverNow, receivedAt;
  DateTime get undoDeadline =>
      receivedAt.add(committedAt.difference(serverNow));
}
