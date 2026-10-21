import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../app/env.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/app_role.dart';
import '../domain/auth_models.dart';
import 'auth_repository.dart';

/// [AuthRepository] backed by Supabase Auth and the `profiles` table (PL-09).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  bool _usedNativeGoogle = false;

  /// Deep link registered in AndroidManifest.xml and Supabase's redirect URLs.
  static const mobileRedirect = 'io.resurhombus.app://login-callback';

  GoTrueClient get _auth => _client.auth;

  /// Web returns to the page origin; Supabase reads the session from the URL.
  String get _redirect => kIsWeb ? Uri.base.origin : mobileRedirect;

  static AuthUser? _user(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  AuthUser? get currentUser => _user(_auth.currentUser);

  @override
  Stream<AuthEvent> authEvents() {
    StreamSubscription<AuthState>? changes;
    late final StreamController<AuthEvent> controller;
    controller = StreamController<AuthEvent>(
      onListen: () {
        controller.add(AuthEvent(currentUser));
        changes = _auth.onAuthStateChange.listen(
          (state) => controller.add(
            AuthEvent(
              _user(state.session?.user),
              passwordRecovery: state.event == AuthChangeEvent.passwordRecovery,
            ),
          ),
          onError: controller.addError,
        );
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required AppRole role,
  }) => _guard(() async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      // handle_new_user() copies `role` into profiles.role.
      data: {'role': role.name, 'terms_accepted': true},
      emailRedirectTo: _redirect,
    );
    // Null session: email confirmation is on and a link was sent.
    if (response.session == null) return false;
    await _stampTerms(response.user!.id);
    return true;
  });

  Future<void> _stampTerms(String userId) => _client
      .from('profiles')
      .update({'terms_accepted_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', userId);

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithPassword(email: email.trim(), password: password),
  );

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final native =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        Env.googleWebClientId.isNotEmpty;
    if (!native) {
      // Web, or Android without a configured client id: browser OAuth.
      await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirect,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      return;
    }
    final google = GoogleSignIn.instance;
    await google.initialize(serverClientId: Env.googleWebClientId);
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AppFailure('cancelled', 'Google sign-in was cancelled.');
      }
      rethrow;
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AppFailure('google_not_configured');
    _usedNativeGoogle = true;
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  });

  @override
  Future<void> signOut() => _guard(() async {
    if (_usedNativeGoogle) {
      await GoogleSignIn.instance.signOut();
      _usedNativeGoogle = false;
    }
    await _auth.signOut();
  });

  @override
  Future<void> resetPassword(String email) => _guard(
    () => _auth.resetPasswordForEmail(email.trim(), redirectTo: _redirect),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<void> setInitialRole(AppRole role) => _guard(
    () => _client.rpc<void>('set_initial_role', params: {'p_role': role.name}),
  );

  @override
  Future<AccountProfile?> fetchProfile() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('profiles')
        .select('id, role, display_name, terms_accepted_at')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return AccountProfile(userId: user.id);

    // Accounts confirmed by email get their Terms timestamp on first load.
    if (row['terms_accepted_at'] == null &&
        user.userMetadata?['terms_accepted'] == true) {
      await _stampTerms(user.id);
    }

    final profile = AccountProfile.fromJson(row);
    switch (profile.role) {
      case AppRole.candidate:
        final candidate = await _client
            .from('candidates')
            .select('active_version_id')
            .eq('profile_id', user.id)
            .maybeSingle();
        return profile.copyWith(
          candidateOnboarded: candidate?['active_version_id'] != null,
        );
      case AppRole.recruiter:
        final recruiter = await _client
            .from('recruiters')
            .select('profile_id')
            .eq('profile_id', user.id)
            .maybeSingle();
        return profile.copyWith(recruiterHasCompany: recruiter != null);
      case null:
        return profile;
    }
  });
}
