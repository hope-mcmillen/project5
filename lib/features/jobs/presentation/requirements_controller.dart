import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/job_repository.dart';
import '../domain/requirement.dart';
import '../domain/requirements_state.dart';

/// The latest `parse-job` result per job, kept for the editor's unmapped
/// and trimmed lists (they aren't stored in the database).
final parseResultsProvider =
    NotifierProvider<ParseResults, Map<String, ParseJobResult>>(
      ParseResults.new,
    );

class ParseResults extends Notifier<Map<String, ParseJobResult>> {
  @override
  Map<String, ParseJobResult> build() => const {};

  void put(String jobId, ParseJobResult result) =>
      state = {...state, jobId: result};
}

/// Holds one job's requirement edits (RC-09a/b).
final requirementsControllerProvider =
    AsyncNotifierProvider.family<
      RequirementsController,
      RequirementsState,
      String
    >(RequirementsController.new);

class RequirementsController extends AsyncNotifier<RequirementsState> {
  RequirementsController(this.jobId);

  final String jobId;

  @override
  Future<RequirementsState> build() async {
    // The parse result can land after the editor opens (Realtime reported
    // READY first): merge its lists in without dropping edits.
    ref.listen(parseResultsProvider.select((all) => all[jobId]), (_, parsed) {
      final current = state.value;
      if (parsed == null || current == null) return;
      state = AsyncData(
        RequirementsState(
          items: current.items.isEmpty ? parsed.requirements : current.items,
          unmapped: parsed.unmapped,
          trimmed: [
            for (final t in parsed.trimmed)
              if (!current.contains(t.skill.id)) t,
          ],
          selected: current.selected,
          dirty: current.dirty,
        ),
      );
    });
    final items = await ref.watch(jobRepositoryProvider).requirements(jobId);
    final parsed = ref.read(parseResultsProvider)[jobId];
    return RequirementsState(
      items: items.isEmpty && parsed != null ? parsed.requirements : items,
      unmapped: [
        for (final u in parsed?.unmapped ?? const <UnmappedSkill>[]) u,
      ],
      trimmed: [
        for (final t in parsed?.trimmed ?? const <RequirementDraft>[])
          if (!items.any((i) => i.skill.id == t.skill.id)) t,
      ],
    );
  }

  void _update(RequirementsState Function(RequirementsState) change) {
    final current = state.value;
    if (current != null) state = AsyncData(change(current));
  }

  void toggleRequired(int i) => _update((s) => s.toggleRequired(i));
  void setMinYears(int i, double years) =>
      _update((s) => s.setMinYears(i, years));
  void setWeight(int i, int weight) => _update((s) => s.setWeight(i, weight));
  void remove(int i) => _update((s) => s.remove(i));
  void add(SkillRef skill) => _update((s) => s.add(skill));
  void mapUnmapped(int i, SkillRef skill) =>
      _update((s) => s.mapUnmapped(i, skill));
  void ignoreUnmapped(int i) => _update((s) => s.ignoreUnmapped(i));
  void restoreTrimmed(int i) => _update((s) => s.restoreTrimmed(i));
  void select(int? i) => _update((s) => s.select(i));

  /// Saves through `save_requirements`. Throws on failure.
  Future<void> save() async {
    final current = state.requireValue;
    await ref
        .read(jobRepositoryProvider)
        .saveRequirements(jobId, current.items);
    _update((s) => s.saved());
    ref.invalidate(jobsProvider);
  }
}
