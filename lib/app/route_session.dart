import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/app_role.dart';
import '../features/auth/data/auth_repository.dart';

enum SessionStatus {
  /// The session or profile is still loading.
  loading,

  /// The profile couldn't be loaded (e.g. offline).
  error,
  signedOut,
  signedIn,
}

/// What the route guard needs to know, read from the auth providers (PL-11).
class RouteSession {
  const RouteSession({
    required this.status,
    this.role,
    this.candidateOnboarded = false,
    this.recruiterHasCompany = false,
    this.passwordRecovery = false,
  });

  static const loading = RouteSession(status: SessionStatus.loading);
  static const signedOut = RouteSession(status: SessionStatus.signedOut);

  const RouteSession.candidate({bool onboarded = true})
    : this(
        status: SessionStatus.signedIn,
        role: AppRole.candidate,
        candidateOnboarded: onboarded,
      );

  const RouteSession.recruiter({bool hasCompany = true})
    : this(
        status: SessionStatus.signedIn,
        role: AppRole.recruiter,
        recruiterHasCompany: hasCompany,
      );

  final SessionStatus status;

  /// Null while signed in means the user still has to pick a role.
  final AppRole? role;

  /// `candidates.active_version_id != null`.
  final bool candidateOnboarded;

  /// A `recruiters` row exists.
  final bool recruiterHasCompany;

  /// Opened through a password-reset link and hasn't set a password yet.
  final bool passwordRecovery;

  bool get isSignedIn => status == SessionStatus.signedIn;

  /// For route logs: `signedIn candidate onboarded=false`.
  @override
  String toString() => [
    status.name,
    if (role != null) role!.name,
    if (role == AppRole.candidate) 'onboarded=$candidateOnboarded',
    if (role == AppRole.recruiter) 'hasCompany=$recruiterHasCompany',
    if (passwordRecovery) 'passwordRecovery',
  ].join(' ');

  /// Builds the snapshot from the current provider values.
  static RouteSession read(Ref ref) {
    final auth = ref.read(authStateProvider);
    if (!auth.hasValue) {
      return auth.hasError ? signedOut : loading;
    }
    final user = auth.requireValue.user;
    if (user == null) return signedOut;

    final profile = ref.read(profileProvider);
    final value = profile.value;
    // Keep showing the last profile while it refreshes, unless it belongs to
    // a different (previous) user.
    if (value == null || value.userId != user.id) {
      if (profile.isLoading) return loading;
      if (profile.hasError) {
        return const RouteSession(status: SessionStatus.error);
      }
      if (value == null) return signedOut;
      return loading;
    }
    return RouteSession(
      status: SessionStatus.signedIn,
      role: value.role,
      candidateOnboarded: value.candidateOnboarded,
      recruiterHasCompany: value.recruiterHasCompany,
      passwordRecovery: ref.read(passwordRecoveryProvider),
    );
  }
}
