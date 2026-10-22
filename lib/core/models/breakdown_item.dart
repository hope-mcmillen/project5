import 'candidate_enums.dart';

/// Immutable breakdown item data for candidate and recruiter screens.
class BreakdownItem {
  BreakdownItem({
    required this.skillId,
    required this.name,
    required this.category,
    required this.required,
    required this.weight,
    required this.minYears,
    this.candidateYears,
    required this.matchedVia,
    required this.coverage,
    required this.depth,
    required this.score,
  });
  final String skillId;
  final String name;
  final String category;
  final bool required;
  final int weight;
  final double minYears;
  final double? candidateYears;
  final MatchedVia matchedVia;
  final double coverage;
  final double depth;
  final double score;
  factory BreakdownItem.fromJson(Map<String, dynamic> json) => BreakdownItem(
    skillId: json['skill_id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    required: json['required'] as bool,
    weight: (json['weight'] as num).toInt(),
    minYears: (json['min_years'] as num).toDouble(),
    candidateYears: json['candidate_years'] == null
        ? null
        : (json['candidate_years'] as num).toDouble(),
    matchedVia: MatchedVia.fromDb(json['matched_via'] as String),
    coverage: (json['coverage'] as num).toDouble(),
    depth: (json['depth'] as num).toDouble(),
    score: (json['score'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'skill_id': skillId,
    'name': name,
    'category': category,
    'required': required,
    'weight': weight,
    'min_years': minYears,
    'candidate_years': candidateYears,
    'matched_via': matchedVia.toDb(),
    'coverage': coverage,
    'depth': depth,
    'score': score,
  };
}
