import 'board_tile.dart';

/// One `breakdown` entry: a requirement and how the candidate covers it
/// (API_CONTRACT §4).
class BreakdownEntry {
  const BreakdownEntry({
    required this.name,
    required this.required,
    required this.score,
    this.category = '',
    this.weight = 1,
    this.minYears = 0,
    this.candidateYears,
    this.matchedVia = 'none',
  });

  final String name;
  final String category;
  final bool required;
  final int weight;
  final double minYears;

  /// Null when listed but not evidenced, or not matched.
  final double? candidateYears;

  /// `exact`, `related` or `none`.
  final String matchedVia;

  /// 0–1: one radar spoke.
  final double score;

  bool get isGap => matchedVia == 'none';

  factory BreakdownEntry.fromJson(Map<String, dynamic> json) => BreakdownEntry(
    name: json['name'] as String,
    category: json['category'] as String? ?? '',
    required: json['required'] as bool? ?? false,
    weight: (json['weight'] as num?)?.toInt() ?? 1,
    minYears: (json['min_years'] as num?)?.toDouble() ?? 0,
    candidateYears: (json['candidate_years'] as num?)?.toDouble(),
    matchedVia: json['matched_via'] as String? ?? 'none',
    score: (json['score'] as num?)?.toDouble() ?? 0,
  );
}

/// A reviewed skill with its (redacted before advancing) evidence.
class SkillEvidence {
  const SkillEvidence({required this.name, this.years, this.evidence});

  final String name;
  final double? years;
  final String? evidence;

  factory SkillEvidence.fromJson(Map<String, dynamic> json) => SkillEvidence(
    name: json['name'] as String,
    years: (json['years'] as num?)?.toDouble(),
    evidence: json['evidence'] as String?,
  );
}

/// Name and email, present only from INTERVIEW_REQUESTED on.
class CandidateIdentity {
  const CandidateIdentity({required this.email, this.displayName});

  final String? displayName;
  final String email;

  String get label =>
      (displayName?.trim().isNotEmpty ?? false) ? displayName! : email;

  factory CandidateIdentity.fromJson(Map<String, dynamic> json) =>
      CandidateIdentity(
        displayName: json['display_name'] as String?,
        email: json['email'] as String,
      );
}

/// `get_candidate_detail` / `get_interview_list` item (API_CONTRACT §7.4).
class CandidateDetail {
  const CandidateDetail({
    required this.tile,
    this.breakdown = const [],
    this.skills = const [],
    this.identity,
  });

  final BoardTile tile;
  final List<BreakdownEntry> breakdown;
  final List<SkillEvidence> skills;
  final CandidateIdentity? identity;

  factory CandidateDetail.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) => [
      for (final item in json[key] as List? ?? const [])
        Map<String, dynamic>.from(item as Map),
    ];
    final identity = json['identity'];
    return CandidateDetail(
      tile: BoardTile.fromJson(json),
      breakdown: list('breakdown').map(BreakdownEntry.fromJson).toList(),
      skills: list('skills').map(SkillEvidence.fromJson).toList(),
      identity: identity is Map
          ? CandidateIdentity.fromJson(Map<String, dynamic>.from(identity))
          : null,
    );
  }
}
