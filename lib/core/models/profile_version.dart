import 'candidate_enums.dart';
import 'education.dart';
import 'candidate_skill.dart';

/// Immutable profile version data for candidate and recruiter screens.
class ProfileVersion {
  ProfileVersion({
    required this.id,
    required this.candidateId,
    this.resumeId,
    required this.version,
    required this.source,
    required this.confirmed,
    this.confirmedAt,
    this.totalYears,
    List<Education> education = const [],
    required this.createdAt,
    List<CandidateSkill> candidateSkills = const [],
  }) : education = List.unmodifiable(education),
       candidateSkills = List.unmodifiable(candidateSkills);
  final String id;
  final String candidateId;
  final String? resumeId;
  final int version;
  final ProfileSource source;
  final bool confirmed;
  final DateTime? confirmedAt;
  final double? totalYears;
  final List<Education> education;
  final DateTime createdAt;
  final List<CandidateSkill> candidateSkills;
  factory ProfileVersion.fromJson(Map<String, dynamic> json) => ProfileVersion(
    id: json['id'] as String,
    candidateId: json['candidate_id'] as String,
    resumeId: json['resume_id'] == null ? null : json['resume_id'] as String,
    version: (json['version'] as num).toInt(),
    source: ProfileSource.fromDb(json['source'] as String),
    confirmed: json['confirmed'] as bool,
    confirmedAt: json['confirmed_at'] == null
        ? null
        : DateTime.parse(json['confirmed_at'] as String),
    totalYears: json['total_years'] == null
        ? null
        : (json['total_years'] as num).toDouble(),
    education: (json['education'] as List? ?? const [])
        .map((v) => Education.fromJson(v as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
    candidateSkills: (json['candidate_skills'] as List? ?? const [])
        .map((v) => CandidateSkill.fromJson(v as Map<String, dynamic>))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'candidate_id': candidateId,
    'resume_id': resumeId,
    'version': version,
    'source': source.toDb(),
    'confirmed': confirmed,
    'confirmed_at': confirmedAt?.toIso8601String(),
    'total_years': totalYears,
    'education': education.map((v) => v.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'candidate_skills': candidateSkills.map((v) => v.toJson()).toList(),
  };
}
