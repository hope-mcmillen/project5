import '../../../core/models/job_status.dart';

/// One row of the `company_jobs_overview` view (RC-06).
class JobSummary {
  const JobSummary({
    required this.id,
    required this.companyId,
    required this.status,
    this.title,
    this.publishedAt,
    this.expiresAt,
    this.newCount = 0,
    this.totalCount = 0,
  });

  final String id;
  final String companyId;

  /// Null until `parse-job` fills it in.
  final String? title;
  final JobStatus status;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  /// Committed applicants still in APPLIED.
  final int newCount;

  /// Committed applicants, excluding WITHDRAWN and JOB_CLOSED.
  final int totalCount;

  factory JobSummary.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    return JobSummary(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String?,
      status: JobStatus.fromDb(json['status'] as String),
      publishedAt: date('published_at'),
      expiresAt: date('expires_at'),
      newCount: (json['new_count'] as num?)?.toInt() ?? 0,
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }

  JobSummary copyWith({JobStatus? status}) => JobSummary(
    id: id,
    companyId: companyId,
    title: title,
    status: status ?? this.status,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    newCount: newCount,
    totalCount: totalCount,
  );
}
