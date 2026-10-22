/// A Realtime change to one of a job's applications.
class BoardChange {
  const BoardChange({required this.isInsert, this.committedAt});

  final bool isInsert;

  /// When the application becomes visible to recruiters (end of the
  /// candidate's 5 s undo window), if known.
  final DateTime? committedAt;
}
