import 'candidate_enums.dart';

/// Immutable candidate skill data for candidate and recruiter screens.
class CandidateSkill {
  CandidateSkill({
    required this.id,
    required this.profileVersionId,
    this.skillId,
    required this.rawName,
    this.years,
    this.evidence,
    required this.source,
  });
  final String id;
  final String profileVersionId;
  final String? skillId;
  final String rawName;
  final double? years;
  final String? evidence;
  final SkillSource source;
  factory CandidateSkill.fromJson(Map<String, dynamic> json) => CandidateSkill(
    id: json['id'] as String,
    profileVersionId: json['profile_version_id'] as String,
    skillId: json['skill_id'] == null ? null : json['skill_id'] as String,
    rawName: json['raw_name'] as String,
    years: json['years'] == null ? null : (json['years'] as num).toDouble(),
    evidence: json['evidence'] == null ? null : json['evidence'] as String,
    source: SkillSource.fromDb(json['source'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_version_id': profileVersionId,
    'skill_id': skillId,
    'raw_name': rawName,
    'years': years,
    'evidence': evidence,
    'source': source.toDb(),
  };
}
