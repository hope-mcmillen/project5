/// A taxonomy skill (`skills` row).
class SkillRef {
  const SkillRef({required this.id, required this.name, this.category = ''});

  final String id;
  final String name;
  final String category;

  factory SkillRef.fromJson(Map<String, dynamic> json) => SkillRef(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String? ?? '',
  );
}

/// One requirement row in the editor (RC-09), saved by `save_requirements`.
class RequirementDraft {
  const RequirementDraft({
    required this.skill,
    this.required = true,
    this.minYears = 0,
    this.weight = 2,
    this.evidence,
    this.eitherOfGroup,
  });

  final SkillRef skill;
  final bool required;

  /// 0 means no minimum. 0–99.9, one decimal.
  final double minYears;

  /// 1–3.
  final int weight;

  /// The quote from the job description this came from.
  final String? evidence;

  /// Same number = "one of" alternatives from parse-job. Display only.
  final int? eitherOfGroup;

  /// Parses a `parse-job` requirement or a `job_requirements` row joined
  /// with `skills(name, category)`.
  factory RequirementDraft.fromJson(Map<String, dynamic> json) {
    final skill = json['skills'] as Map<String, dynamic>?;
    return RequirementDraft(
      skill: SkillRef(
        id: json['skill_id'] as String,
        name: (skill?['name'] ?? json['name']) as String,
        category: (skill?['category'] ?? json['category'] ?? '') as String,
      ),
      required: json['required'] as bool? ?? true,
      minYears: (json['min_years'] as num?)?.toDouble() ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 2,
      evidence: json['evidence'] as String?,
      eitherOfGroup: (json['either_of_group'] as num?)?.toInt(),
    );
  }

  /// The `p_requirements` element shape (API_CONTRACT §7.4).
  Map<String, dynamic> toRpc() => {
    'skill_id': skill.id,
    'required': required,
    'min_years': minYears,
    'weight': weight,
    'evidence': evidence,
  };

  RequirementDraft copyWith({bool? required, double? minYears, int? weight}) =>
      RequirementDraft(
        skill: skill,
        required: required ?? this.required,
        minYears: minYears ?? this.minYears,
        weight: weight ?? this.weight,
        evidence: evidence,
        eitherOfGroup: eitherOfGroup,
      );
}

/// A skill parse-job found that isn't in the taxonomy (not saved).
class UnmappedSkill {
  const UnmappedSkill({
    required this.raw,
    this.required = false,
    this.minYears,
    this.evidence,
  });

  final String raw;
  final bool required;
  final double? minYears;
  final String? evidence;

  factory UnmappedSkill.fromJson(Map<String, dynamic> json) => UnmappedSkill(
    raw: json['raw'] as String,
    required: json['required_hint'] == 'required',
    minYears: (json['min_years'] as num?)?.toDouble(),
    evidence: json['evidence'] as String?,
  );
}

/// The `parse-job` response (API_CONTRACT §3).
class ParseJobResult {
  const ParseJobResult({
    required this.ready,
    this.failureReason,
    this.requirements = const [],
    this.unmapped = const [],
    this.trimmed = const [],
  });

  final bool ready;

  /// `timeout`, `budget_exceeded` or `internal` when not [ready].
  final String? failureReason;
  final List<RequirementDraft> requirements;
  final List<UnmappedSkill> unmapped;

  /// Mapped requirements cut by the 15-requirement cap.
  final List<RequirementDraft> trimmed;

  factory ParseJobResult.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        List<Map<String, dynamic>>.from(json[key] as List? ?? const []);
    return ParseJobResult(
      ready: json['parse_status'] == 'READY',
      failureReason: json['failure_reason'] as String?,
      requirements: list('requirements')
          .map(RequirementDraft.fromJson)
          .toList(),
      unmapped: list('unmapped').map(UnmappedSkill.fromJson).toList(),
      trimmed: list('trimmed').map(RequirementDraft.fromJson).toList(),
    );
  }
}
