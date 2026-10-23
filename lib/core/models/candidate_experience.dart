import 'candidate_enums.dart';

/// One experience entry read from a resume (`candidate_experiences`).
///
/// Dates are `YYYY-MM` or `YYYY`; [endMonth] can also be `present`.
class CandidateExperience {
  CandidateExperience({
    required this.id,
    required this.profileVersionId,
    required this.sortOrder,
    required this.kind,
    required this.title,
    this.organization,
    this.startMonth,
    this.endMonth,
    List<String> highlights = const [],
    List<String> skillsUsed = const [],
    required this.evidence,
  }) : highlights = List.unmodifiable(highlights),
       skillsUsed = List.unmodifiable(skillsUsed);
  final String id;
  final String profileVersionId;
  final int sortOrder;
  final ExperienceKind kind;
  final String title;
  final String? organization;
  final String? startMonth;
  final String? endMonth;
  final List<String> highlights;
  final List<String> skillsUsed;
  final String evidence;

  bool get isCurrent => endMonth == 'present';

  factory CandidateExperience.fromJson(Map<String, dynamic> json) =>
      CandidateExperience(
        id: json['id'] as String,
        profileVersionId: json['profile_version_id'] as String,
        sortOrder: (json['sort_order'] as num).toInt(),
        kind: ExperienceKind.fromDb(json['kind'] as String),
        title: json['title'] as String,
        organization: json['organization'] as String?,
        startMonth: json['start_month'] as String?,
        endMonth: json['end_month'] as String?,
        highlights: (json['highlights'] as List? ?? const [])
            .map((v) => v as String)
            .toList(),
        skillsUsed: (json['skills_used'] as List? ?? const [])
            .map((v) => v as String)
            .toList(),
        evidence: json['evidence'] as String,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'profile_version_id': profileVersionId,
    'sort_order': sortOrder,
    'kind': kind.toDb(),
    'title': title,
    'organization': organization,
    'start_month': startMonth,
    'end_month': endMonth,
    'highlights': highlights,
    'skills_used': skillsUsed,
    'evidence': evidence,
  };
}
