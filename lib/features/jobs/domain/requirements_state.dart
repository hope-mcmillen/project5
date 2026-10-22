import 'requirement.dart';

/// The requirement editor's state and the R-JOB-2 limits (RC-09).
///
/// Pure and immutable so the limits are easy to test; the controller wraps
/// it for the screen.
class RequirementsState {
  const RequirementsState({
    this.items = const [],
    this.unmapped = const [],
    this.trimmed = const [],
    this.selected,
    this.dirty = false,
  });

  static const maxRequired = 8;
  static const maxTotal = 15;

  final List<RequirementDraft> items;

  /// Skills parse-job found outside the taxonomy.
  final List<UnmappedSkill> unmapped;

  /// Mapped skills parse-job cut to stay under [maxTotal].
  final List<RequirementDraft> trimmed;

  /// The row whose evidence is highlighted in the description.
  final int? selected;

  /// Changed since load or the last save.
  final bool dirty;

  int get requiredCount => items.where((r) => r.required).length;
  int get total => items.length;
  bool get isFull => total >= maxTotal;
  bool get requiredFull => requiredCount >= maxRequired;

  /// Why row [index]'s Required/Preferred toggle is disabled, or null.
  String? requiredToggleBlocked(int index) =>
      !items[index].required && requiredFull
      ? 'Up to $maxRequired skills can be required. Make another one '
            'preferred first.'
      : null;

  /// Why skills can't be added right now, or null.
  String? get addBlocked => isFull
      ? 'Up to $maxTotal skills per job. Remove one to add another.'
      : null;

  bool contains(String skillId) => items.any((r) => r.skill.id == skillId);

  RequirementsState _with({
    List<RequirementDraft>? items,
    List<UnmappedSkill>? unmapped,
    List<RequirementDraft>? trimmed,
    int? selected,
    bool clearSelected = false,
    bool dirty = true,
  }) => RequirementsState(
    items: items ?? this.items,
    unmapped: unmapped ?? this.unmapped,
    trimmed: trimmed ?? this.trimmed,
    selected: clearSelected ? null : (selected ?? this.selected),
    dirty: dirty,
  );

  RequirementsState _replace(int index, RequirementDraft item) =>
      _with(items: [...items]..[index] = item);

  RequirementsState toggleRequired(int index) {
    final item = items[index];
    if (requiredToggleBlocked(index) != null) return this;
    final makeRequired = !item.required;
    // Keep the default weights (required 2, preferred 1) in step.
    final weight = makeRequired
        ? (item.weight == 1 ? 2 : item.weight)
        : (item.weight == 2 ? 1 : item.weight);
    return _replace(
      index,
      item.copyWith(required: makeRequired, weight: weight),
    );
  }

  RequirementsState setMinYears(int index, double years) {
    final clamped = (years.clamp(0, 99.9) * 10).round() / 10;
    return _replace(index, items[index].copyWith(minYears: clamped));
  }

  RequirementsState setWeight(int index, int weight) =>
      _replace(index, items[index].copyWith(weight: weight.clamp(1, 3)));

  RequirementsState remove(int index) {
    final next = [...items]..removeAt(index);
    final sel = selected;
    return _with(
      items: next,
      clearSelected: sel == null || sel == index,
      selected: sel != null && sel > index ? sel - 1 : sel,
    );
  }

  /// Adds [skill]; required while there's room, else preferred. No-op when
  /// full or already present.
  RequirementsState add(
    SkillRef skill, {
    bool? required,
    double minYears = 0,
    String? evidence,
  }) {
    if (isFull || contains(skill.id)) return this;
    final isRequired = (required ?? true) && !requiredFull;
    return _with(
      items: [
        ...items,
        RequirementDraft(
          skill: skill,
          required: isRequired,
          weight: isRequired ? 2 : 1,
          minYears: minYears,
          evidence: evidence,
        ),
      ],
    );
  }

  /// Maps unmapped skill [index] to the taxonomy [skill].
  RequirementsState mapUnmapped(int index, SkillRef skill) {
    final raw = unmapped[index];
    final added = add(
      skill,
      required: raw.required,
      minYears: raw.minYears ?? 0,
      evidence: raw.evidence,
    );
    if (identical(added, this)) return this;
    return added._with(unmapped: [...unmapped]..removeAt(index));
  }

  RequirementsState ignoreUnmapped(int index) =>
      _with(unmapped: [...unmapped]..removeAt(index), dirty: dirty);

  /// Moves trimmed skill [index] back into the list if there's room.
  RequirementsState restoreTrimmed(int index) {
    final item = trimmed[index];
    final added = add(
      item.skill,
      required: item.required,
      minYears: item.minYears,
      evidence: item.evidence,
    );
    if (identical(added, this)) return this;
    return added._with(trimmed: [...trimmed]..removeAt(index));
  }

  RequirementsState select(int? index) => _with(
    selected: index,
    clearSelected: index == null || index == selected,
    dirty: dirty,
  );

  RequirementsState saved() => _with(dirty: false);
}
