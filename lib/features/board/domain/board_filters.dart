import 'board_tile.dart';

/// Board filters (RC-17). Min score goes to `get_board` as
/// `p_filters.min_score`; skills and min years are applied to the tiles,
/// because `get_board` accepts only `statuses` and `min_score`. A tile's
/// `gaps` lists every requirement the candidate lacks, so "has skill X"
/// is exactly "X is not a gap". Filtering never reorders.
class BoardFilters {
  const BoardFilters({this.skills = const {}, this.minYears, this.minScore});

  static const empty = BoardFilters();

  /// Requirement names the candidate must have.
  final Set<String> skills;
  final double? minYears;
  final int? minScore;

  bool get isEmpty => skills.isEmpty && minYears == null && minScore == null;

  bool matches(BoardTile tile) =>
      skills.every((s) => !tile.gaps.contains(s)) &&
      (minYears == null || tile.totalYears >= minYears!) &&
      (minScore == null || tile.matchScore >= minScore!);

  List<BoardTile> apply(List<BoardTile> tiles) =>
      isEmpty ? tiles : tiles.where(matches).toList();

  /// From `?skills=Flutter,Dart&years=2&score=70` (survives a web refresh).
  factory BoardFilters.fromQuery(Map<String, String> query) {
    final skills = query['skills'];
    final years = double.tryParse(query['years'] ?? '');
    final score = int.tryParse(query['score'] ?? '');
    return BoardFilters(
      skills: {
        for (final s in (skills ?? '').split(','))
          if (s.trim().isNotEmpty) s.trim(),
      },
      minYears: years != null && years > 0 ? years : null,
      minScore: score != null && score > 0 && score <= 100 ? score : null,
    );
  }

  Map<String, String> toQuery() => {
    if (skills.isNotEmpty) 'skills': (skills.toList()..sort()).join(','),
    if (minYears != null)
      'years': minYears! % 1 == 0 ? '${minYears!.toInt()}' : '$minYears',
    if (minScore != null) 'score': '$minScore',
  };

  BoardFilters toggleSkill(String skill) => BoardFilters(
    skills: skills.contains(skill)
        ? ({...skills}..remove(skill))
        : {...skills, skill},
    minYears: minYears,
    minScore: minScore,
  );

  BoardFilters withMinYears(double? years) =>
      BoardFilters(skills: skills, minYears: years, minScore: minScore);

  BoardFilters withMinScore(int? score) =>
      BoardFilters(skills: skills, minYears: minYears, minScore: score);

  @override
  bool operator ==(Object other) =>
      other is BoardFilters &&
      other.minYears == minYears &&
      other.minScore == minScore &&
      other.skills.length == skills.length &&
      other.skills.containsAll(skills);

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(skills), minYears, minScore);
}
