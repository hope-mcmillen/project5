import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_role.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';

/// SCAFFOLD ONLY: lets a placeholder page "finish" onboarding.
///
/// On fake data it flips the fake account's flag; on Supabase it only
/// reloads the profile, so the router moves on once the real data says so
/// (e.g. `confirm_profile` set `active_version_id`). Delete each call when
/// the screen that really completes onboarding lands.
void finishOnboardingForScaffold(WidgetRef ref, AppRole role) {
  final auth = ref.read(authRepositoryProvider);
  if (auth is FakeAuthRepository) {
    switch (role) {
      case AppRole.candidate:
        auth.markCandidateOnboarded();
      case AppRole.recruiter:
        auth.markRecruiterHasCompany();
    }
  }
  ref.invalidate(profileProvider);
}
