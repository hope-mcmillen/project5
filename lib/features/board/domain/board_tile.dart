import '../../../core/models/application_status.dart';

/// A blind applicant tile from `get_board` (API_CONTRACT §7.4).
///
/// The key set is exactly the contract's: no names, emails or profile ids.
class BoardTile {
  const BoardTile({
    required this.applicationId,
    required this.handle,
    required this.matchScore,
    required this.band,
    required this.status,
    required this.committedAt,
    this.totalYears = 0,
    this.topSkills = const [],
    this.gaps = const [],
  });

  final String applicationId;

  /// Anonymous handle, e.g. "◆ 4F2A".
  final String handle;
  final int matchScore;
  final String band;
  final double totalYears;
  final List<String> topSkills;
  final List<String> gaps;
  final ApplicationStatus status;
  final DateTime committedAt;

  factory BoardTile.fromJson(Map<String, dynamic> json) => BoardTile(
    applicationId: json['application_id'] as String,
    handle: json['handle'] as String,
    matchScore: (json['match_score'] as num).toInt(),
    band: json['band'] as String,
    totalYears: (json['total_years'] as num?)?.toDouble() ?? 0,
    topSkills: List<String>.from(json['top_skills'] as List? ?? const []),
    gaps: List<String>.from(json['gaps'] as List? ?? const []),
    status: ApplicationStatus.fromDb(json['status'] as String),
    committedAt: DateTime.parse(json['committed_at'] as String),
  );

  BoardTile copyWith({ApplicationStatus? status}) => BoardTile(
    applicationId: applicationId,
    handle: handle,
    matchScore: matchScore,
    band: band,
    totalYears: totalYears,
    topSkills: topSkills,
    gaps: gaps,
    status: status ?? this.status,
    committedAt: committedAt,
  );
}
