import 'application_status.dart';
import 'breakdown_item.dart';

/// Immutable application data for candidate and recruiter screens.
class Application {
  Application({
    required this.id,
    required this.jobId,
    this.candidateId,
    this.profileVersionId,
    required this.status,
    required this.matchScore,
    List<BreakdownItem> breakdown = const [],
    required this.scoringVersion,
    required this.committedAt,
    required this.createdAt,
    required this.updatedAt,
    this.jobTitle,
    this.companyName,
    this.companyVerified,
  }) : breakdown = List.unmodifiable(breakdown);
  final String id;
  final String jobId;
  final String? candidateId;
  final String? profileVersionId;
  final ApplicationStatus status;
  final int matchScore;
  final List<BreakdownItem> breakdown;
  final String scoringVersion;
  final DateTime committedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? jobTitle;
  final String? companyName;
  final bool? companyVerified;
  factory Application.fromJson(Map<String, dynamic> json) => Application(
    id: json['id'] as String,
    jobId: json['job_id'] as String,
    candidateId: json['candidate_id'] == null
        ? null
        : json['candidate_id'] as String,
    profileVersionId: json['profile_version_id'] == null
        ? null
        : json['profile_version_id'] as String,
    status: ApplicationStatus.fromDb(json['status'] as String),
    matchScore: (json['match_score'] as num).toInt(),
    breakdown: (json['breakdown'] as List? ?? const [])
        .map((v) => BreakdownItem.fromJson(v as Map<String, dynamic>))
        .toList(),
    scoringVersion: json['scoring_version'] as String,
    committedAt: DateTime.parse(json['committed_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    jobTitle: json['job_title'] == null ? null : json['job_title'] as String,
    companyName: json['company_name'] == null
        ? null
        : json['company_name'] as String,
    companyVerified: json['company_verified'] == null
        ? null
        : json['company_verified'] as bool,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'job_id': jobId,
    'candidate_id': candidateId,
    'profile_version_id': profileVersionId,
    'status': status.toDb(),
    'match_score': matchScore,
    'breakdown': breakdown.map((v) => v.toJson()).toList(),
    'scoring_version': scoringVersion,
    'committed_at': committedAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'job_title': jobTitle,
    'company_name': companyName,
    'company_verified': companyVerified,
  };
}
