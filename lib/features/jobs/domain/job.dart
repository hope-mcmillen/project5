import '../../../core/models/job_status.dart';

/// Mirrors the Postgres `parse_status` enum.
enum ParseStatus {
  pending('PENDING'),
  ready('READY'),
  failed('FAILED');

  const ParseStatus(this.db);
  final String db;

  static ParseStatus fromDb(String value) =>
      values.firstWhere((s) => s.db == value);
}

/// Mirrors the Postgres `remote_type` enum.
enum RemoteType {
  onsite('On-site'),
  hybrid('Hybrid'),
  remote('Remote');

  const RemoteType(this.label);
  final String label;
}

/// Mirrors the Postgres `job_type` enum.
enum JobType {
  fullTime('full_time', 'Full-time'),
  partTime('part_time', 'Part-time'),
  contract('contract', 'Contract'),
  internship('internship', 'Internship');

  const JobType(this.db, this.label);
  final String db;
  final String label;

  static JobType fromDb(String value) =>
      values.firstWhere((t) => t.db == value);
}

/// A `jobs` row as the recruiter edits it (RC-08 to RC-11).
class Job {
  const Job({
    required this.id,
    required this.companyId,
    required this.status,
    required this.parseStatus,
    this.title,
    this.rawDescription = '',
    this.location,
    this.remote,
    this.jobType,
    this.sponsorship = false,
    this.salaryMin,
    this.salaryMax,
    this.publishedAt,
    this.expiresAt,
  });

  /// The columns repositories select (never the embedding).
  static const columns =
      'id, company_id, title, raw_description, parse_status, status, '
      'location, remote, job_type, sponsorship, salary_min, salary_max, '
      'published_at, expires_at';

  final String id;
  final String companyId;
  final String? title;
  final String rawDescription;
  final ParseStatus parseStatus;
  final JobStatus status;
  final String? location;
  final RemoteType? remote;
  final JobType? jobType;
  final bool sponsorship;
  final int? salaryMin;
  final int? salaryMax;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  String get displayTitle =>
      (title?.trim().isNotEmpty ?? false) ? title! : 'Untitled job';

  factory Job.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final value = json[key] as String?;
      return value == null ? null : DateTime.parse(value);
    }

    final remote = json['remote'] as String?;
    final jobType = json['job_type'] as String?;
    return Job(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      title: json['title'] as String?,
      rawDescription: json['raw_description'] as String? ?? '',
      parseStatus: ParseStatus.fromDb(json['parse_status'] as String),
      status: JobStatus.fromDb(json['status'] as String),
      location: json['location'] as String?,
      remote: remote == null ? null : RemoteType.values.byName(remote),
      jobType: jobType == null ? null : JobType.fromDb(jobType),
      sponsorship: json['sponsorship'] as bool? ?? false,
      salaryMin: (json['salary_min'] as num?)?.toInt(),
      salaryMax: (json['salary_max'] as num?)?.toInt(),
      publishedAt: date('published_at'),
      expiresAt: date('expires_at'),
    );
  }

  Job copyWith({
    JobStatus? status,
    ParseStatus? parseStatus,
    JobDetailsInput? details,
  }) => Job(
    id: id,
    companyId: companyId,
    title: details != null ? details.title : title,
    rawDescription: rawDescription,
    parseStatus: parseStatus ?? this.parseStatus,
    status: status ?? this.status,
    location: details != null ? details.location : location,
    remote: details != null ? details.remote : remote,
    jobType: details != null ? details.jobType : jobType,
    sponsorship: details?.sponsorship ?? sponsorship,
    salaryMin: details != null ? details.salaryMin : salaryMin,
    salaryMax: details != null ? details.salaryMax : salaryMax,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
  );
}

/// The editable job details (RC-10), written with a plain table update.
class JobDetailsInput {
  const JobDetailsInput({
    this.title,
    this.location,
    this.remote,
    this.jobType,
    this.sponsorship = false,
    this.salaryMin,
    this.salaryMax,
  });

  factory JobDetailsInput.from(Job job) => JobDetailsInput(
    title: job.title,
    location: job.location,
    remote: job.remote,
    jobType: job.jobType,
    sponsorship: job.sponsorship,
    salaryMin: job.salaryMin,
    salaryMax: job.salaryMax,
  );

  final String? title;
  final String? location;
  final RemoteType? remote;
  final JobType? jobType;
  final bool sponsorship;
  final int? salaryMin;
  final int? salaryMax;

  Map<String, dynamic> toJson() => {
    'title': title,
    'location': location,
    'remote': remote?.name,
    'job_type': jobType?.db,
    'sponsorship': sponsorship,
    'salary_min': salaryMin,
    'salary_max': salaryMax,
  };
}
