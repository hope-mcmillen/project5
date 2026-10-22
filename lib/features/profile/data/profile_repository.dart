import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/candidate_models.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'supabase_profile_repository.dart';

abstract interface class ProfileRepository {
  Future<ProfileVersion?> latestVersion();
  Future<ProfileVersion> createManualProfile();
  Future<ProfileVersion> createReviewDraft();
  Future<void> confirm(String versionId, List<CandidateSkill> skills);
  Future<Preferences> preferences();
  Future<void> savePreferences(Preferences preferences);
  Future<List<Skill>> searchSkills(String query);
}

/// Fake mode overrides this.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

final candidateProfileProvider = FutureProvider.autoDispose<ProfileVersion?>(
  (ref) => ref.watch(profileRepositoryProvider).latestVersion(),
);
