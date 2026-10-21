import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_role.dart';
import '../domain/auth_models.dart';
import 'fake_auth_repository.dart';

/// Sign-up, sign-in and the account's profile (PL-09). The only auth code
/// that talks to Supabase; screens go through this.
abstract interface class AuthRepository {
  /// Emits the current session first, then every change.
  Stream<AuthEvent> authEvents();

  AuthUser? get currentUser;

  /// Creates an account with [role] in the sign-up metadata, which the
  /// `handle_new_user()` trigger copies into `profiles.role`.
  Future<void> signUpWithEmail({
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

/// TODO(PL-09): switch the default to `SupabaseAuthRepository`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(),
);
