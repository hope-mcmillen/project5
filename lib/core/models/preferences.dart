import 'candidate_enums.dart';

/// Immutable preferences data for candidate and recruiter screens.
class Preferences {
  Preferences({
    List<String>? locations,
    List<RemoteType>? remote,
    List<JobType>? jobTypes,
    this.needsSponsorship,
    this.salaryMin,
    this.includeStretch,
  }) : locations = locations == null ? null : List.unmodifiable(locations),
       remote = remote == null ? null : List.unmodifiable(remote),
       jobTypes = jobTypes == null ? null : List.unmodifiable(jobTypes);
  final List<String>? locations;
  final List<RemoteType>? remote;
  final List<JobType>? jobTypes;
  final bool? needsSponsorship;
  final int? salaryMin;
  final bool? includeStretch;
  factory Preferences.fromJson(Map<String, dynamic> json) => Preferences(
    locations: json['locations'] == null
        ? null
        : (json['locations'] as List? ?? const [])
              .map((v) => v as String)
              .toList(),
    remote: json['remote'] == null
        ? null
        : (json['remote'] as List? ?? const [])
              .map((v) => RemoteType.fromDb(v as String))
              .toList(),
    jobTypes: json['job_types'] == null
        ? null
        : (json['job_types'] as List? ?? const [])
              .map((v) => JobType.fromDb(v as String))
              .toList(),
    needsSponsorship: json['needs_sponsorship'] == null
        ? null
        : json['needs_sponsorship'] as bool,
    salaryMin: json['salary_min'] == null
        ? null
        : (json['salary_min'] as num).toInt(),
    includeStretch: json['include_stretch'] == null
        ? null
        : json['include_stretch'] as bool,
  );
  Map<String, dynamic> toJson() => {
    if (locations != null) 'locations': locations?.map((v) => v).toList(),
    if (remote != null) 'remote': remote?.map((v) => v.toDb()).toList(),
    if (jobTypes != null) 'job_types': jobTypes?.map((v) => v.toDb()).toList(),
    if (needsSponsorship != null) 'needs_sponsorship': needsSponsorship,
    if (salaryMin != null) 'salary_min': salaryMin,
    if (includeStretch != null) 'include_stretch': includeStretch,
  };
}
