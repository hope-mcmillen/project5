import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../profile/data/profile_repository.dart';

class ReviewState {
  ReviewState({
    required this.version,
    required List<CandidateSkill> skills,
    this.saving = false,
    this.error,
  }) : skills = List.unmodifiable(skills);
  final ProfileVersion version;
  final List<CandidateSkill> skills;
  final bool saving;
  final String? error;
}

final reviewControllerProvider =
    AsyncNotifierProvider.autoDispose<ReviewController, ReviewState>(
      ReviewController.new,
    );

class ReviewController extends AsyncNotifier<ReviewState> {
  int _sequence = 0;
  @override
  Future<ReviewState> build() async {
    final repo = ref.watch(profileRepositoryProvider);
    var version = await repo.latestVersion();
    if (version == null) {
      version = await repo.createManualProfile();
    } else if (version.confirmed) {
      version = await repo.createReviewDraft();
    }
    return ReviewState(version: version, skills: version.candidateSkills);
  }

  void _change(List<CandidateSkill> Function(ReviewState) update) {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    state = AsyncData(
      ReviewState(version: current.version, skills: update(current)),
    );
  }

  void remove(String id) =>
      _change((s) => s.skills.where((v) => v.id != id).toList());
  void years(String id, double? value) => _change(
    (s) => [
      for (final skill in s.skills)
        if (skill.id == id)
          CandidateSkill.fromJson({
            ...skill.toJson(),
            'years': value?.clamp(0, 99.5),
            'source': 'user',
          })
        else
          skill,
    ],
  );
  void choose({String? replacingId, Skill? skill, required String name}) {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    final trimmed = name.trim();
    final duplicate = current.skills.any(
      (v) =>
          v.id != replacingId &&
          ((skill != null && v.skillId == skill.id) ||
              v.rawName.toLowerCase() == trimmed.toLowerCase()),
    );
    if (duplicate ||
        trimmed.isEmpty ||
        trimmed.length > 120 ||
        (replacingId == null && current.skills.length >= 100)) {
      state = AsyncData(
        ReviewState(
          version: current.version,
          skills: current.skills,
          error: duplicate ? 'That skill is already on your profile.' : 'Use a skill name up to 120 characters, with no more than 100 skills.',
        ),
      );
      return;
    }
    CandidateSkill? old;
    for (final candidate in current.skills) {
      if (candidate.id == replacingId) old = candidate;
    }
    while (current.skills.any((v) => v.id == 'user-skill-${_sequence + 1}')) {
      _sequence++;
    }
    final updated = CandidateSkill(
      id: old?.id ?? 'user-skill-${++_sequence}',
      profileVersionId: current.version.id,
      skillId: skill?.id,
      rawName: trimmed,
      years: old?.years,
      evidence: old?.evidence,
      source: SkillSource.user,
    );
    _change(
      (s) => [
        for (final item in s.skills)
          if (item.id == replacingId) updated else item,
        if (replacingId == null) updated,
      ],
    );
  }

  Future<bool> confirm() async {
    final current = state.asData?.value;
    if (current == null || current.saving) return false;
    state = AsyncData(
      ReviewState(
        version: current.version,
        skills: current.skills,
        saving: true,
      ),
    );
    try {
      await ref
          .read(profileRepositoryProvider)
          .confirm(current.version.id, current.skills);
      if (ref.mounted) {
        ref.invalidate(candidateProfileProvider);
        state = AsyncData(
          ReviewState(version: current.version, skills: current.skills),
        );
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        ref.invalidate(candidateProfileProvider);
        state = AsyncData(
          ReviewState(
            version: current.version,
            skills: current.skills,
            error: error is AppFailure
                ? error.message
                : 'Your skills could not be confirmed. Please try again.',
          ),
        );
      }
      return false;
    }
  }
}
