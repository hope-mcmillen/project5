import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_role.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/auth_models.dart';
import 'supabase_auth_repository.dart';

/// Sign-up, sign-in and the account's profile (PL-09). The only auth code
/// that talks to Supabase; screens go through this.
abstract interface class AuthRepository {
  /// Emits the current session first, then every change.
  Stream<AuthEvent> authEvents();

  AuthUser? get currentUser;

  /// Creates an account with [role] in the sign-up metadata, which the
  /// `handle_new_user()` trigger copies into `profiles.role`.
  ///
  /// Returns true when signed in right away, false when a confirmation
  /// email was sent instead.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required AppRole role,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Google sign-in. New Google users have no role until [setInitialRole].
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Emails a password-reset link.
  Future<void> resetPassword(String email);

  /// Sets a new password for the signed-in (or recovering) user.
  Future<void> updatePassword(String newPassword);

  /// `rpc('set_initial_role')`: only works while the role is still null.
  Future<void> setInitialRole(AppRole role);

  /// The signed-in user's profile and onboarding flags, or null when
  /// signed out.
  Future<AccountProfile?> fetchProfile();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// The auth session: the current user first, then every change.
final authStateProvider = StreamProvider<AuthEvent>(
  (ref) => ref.watch(authRepositoryProvider).authEvents(),
);

/// The signed-in user's id, or null when signed out. User-scoped providers
/// watch this so they reset on sign-out and account switches.
final currentUserIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(authStateProvider.selectAsync((e) => e.user?.id)),
);

/// The signed-in account's profile and onboarding flags (null when signed
/// out). Invalidate it after anything that changes role or onboarding.
final profileProvider = FutureProvider<AccountProfile?>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile();
});
