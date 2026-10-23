import 'candidate_enums.dart';
import 'job_company.dart';
import 'breakdown_item.dart';

/// Immutable job card data for candidate and recruiter screens.
class JobCard {
  JobCard({
    required this.jobId,
    required this.title,
    required this.company,
    this.location,
    this.remote,
    this.jobType,
    required this.sponsorship,
    this.salaryMin,
    this.salaryMax,
    this.publishedAt,
    required this.matchScore,
    required this.band,
    List<String> topMatches = const [],
    List<String> gaps = const [],
    List<String> requiredGaps = const [],
    List<BreakdownItem> breakdown = const [],
  }) : topMatches = List.unmodifiable(topMatches),
       gaps = List.unmodifiable(gaps),
       requiredGaps = List.unmodifiable(requiredGaps),
       breakdown = List.unmodifiable(breakdown);
  final String jobId;
  final String title;
  final JobCompany company;
  final String? location;

  /// Null when the recruiter left it unset (the feed lets unknowns through).
  final RemoteType? remote;
  final JobType? jobType;
  final bool sponsorship;
  final int? salaryMin;
  final int? salaryMax;
  final DateTime? publishedAt;
  final int matchScore;
  final ScoreBand band;
  final List<String> topMatches;
  final List<String> gaps;
  final List<String> requiredGaps;
  final List<BreakdownItem> breakdown;
  factory JobCard.fromJson(Map<String, dynamic> json) => JobCard(
    jobId: json['job_id'] as String,
    title: json['title'] as String? ?? 'Untitled role',
    company: JobCompany.fromJson(json['company'] as Map<String, dynamic>),
    location: json['location'] == null ? null : json['location'] as String,
    remote: json['remote'] == null
        ? null
        : RemoteType.fromDb(json['remote'] as String),
    jobType: json['job_type'] == null
        ? null
        : JobType.fromDb(json['job_type'] as String),
    sponsorship: json['sponsorship'] as bool,
    salaryMin: json['salary_min'] == null
        ? null
        : (json['salary_min'] as num).toInt(),
    salaryMax: json['salary_max'] == null
        ? null
        : (json['salary_max'] as num).toInt(),
    publishedAt: json['published_at'] == null
        ? null
        : DateTime.parse(json['published_at'] as String),
    matchScore: (json['match_score'] as num).toInt(),
    band: ScoreBand.fromDb(json['band'] as String),
    topMatches: (json['top_matches'] as List? ?? const [])
        .map((v) => v as String)
        .toList(),
    gaps: (json['gaps'] as List? ?? const []).map((v) => v as String).toList(),
    requiredGaps: (json['required_gaps'] as List? ?? const [])
        .map((v) => v as String)
        .toList(),
    breakdown: (json['breakdown'] as List? ?? const [])
        .map((v) => BreakdownItem.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'job_id': jobId,
    'title': title,
    'company': company.toJson(),
    'location': location,
    'remote': remote?.toDb(),
    'job_type': jobType?.toDb(),
    'sponsorship': sponsorship,
    'salary_min': salaryMin,
    'salary_max': salaryMax,
    'published_at': publishedAt?.toIso8601String(),
    'match_score': matchScore,
    'band': band.toDb(),
    'top_matches': topMatches.map((v) => v).toList(),
    'gaps': gaps.map((v) => v).toList(),
    'required_gaps': requiredGaps.map((v) => v).toList(),
    'breakdown': breakdown.map((v) => v.toJson()).toList(),
  };
}
