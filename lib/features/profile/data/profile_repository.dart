import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';

abstract interface class ProfileRepository {
  Future<ProfileVersion?> latestVersion();
  Future<ProfileVersion> createManualProfile();
  Future<ProfileVersion> createReviewDraft();
  Future<void> confirm(String versionId, List<CandidateSkill> skills);
  Future<Preferences> preferences();
  Future<void> savePreferences(Preferences preferences);
  Future<List<Skill>> searchSkills(String query);
}

/// Real implementation will be supplied by C5. Fake mode overrides this.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw UnimplementedError(
    'ProfileRepository: use main_fake.dart until C5.',
  ),
);

final candidateProfileProvider = FutureProvider.autoDispose<ProfileVersion?>(
  (ref) => ref.watch(profileRepositoryProvider).latestVersion(),
);
