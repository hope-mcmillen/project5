import 'candidate_enums.dart';
import 'application_status.dart';

/// Immutable candidate tile data for candidate and recruiter screens.
class CandidateTile {
  CandidateTile({
    required this.applicationId,
    required this.handle,
    required this.matchScore,
    required this.band,
    this.totalYears = 0,
    List<String> topSkills = const [],
    List<String> gaps = const [],
    required this.status,
    required this.committedAt,
  }) : topSkills = List.unmodifiable(topSkills),
       gaps = List.unmodifiable(gaps);
  final String applicationId;
  final String handle;
  final int matchScore;
  final ScoreBand band;
  final double totalYears;
  final List<String> topSkills;
  final List<String> gaps;
  final ApplicationStatus status;
  final DateTime committedAt;
  CandidateTile copyWith({ApplicationStatus? status}) => CandidateTile(
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
  factory CandidateTile.fromJson(Map<String, dynamic> json) => CandidateTile(
    applicationId: json['application_id'] as String,
    handle: json['handle'] as String,
    matchScore: (json['match_score'] as num).toInt(),
    band: ScoreBand.fromDb(json['band'] as String),
    totalYears: (json['total_years'] as num).toDouble(),
    topSkills: (json['top_skills'] as List? ?? const [])
        .map((v) => v as String)
        .toList(),
    gaps: (json['gaps'] as List? ?? const []).map((v) => v as String).toList(),
    status: ApplicationStatus.fromDb(json['status'] as String),
    committedAt: DateTime.parse(json['committed_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'application_id': applicationId,
    'handle': handle,
    'match_score': matchScore,
    'band': band.toDb(),
    'total_years': totalYears,
    'top_skills': topSkills.map((v) => v).toList(),
    'gaps': gaps.map((v) => v).toList(),
    'status': status.toDb(),
    'committed_at': committedAt.toIso8601String(),
  };
}
