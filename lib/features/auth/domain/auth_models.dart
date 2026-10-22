import '../../../core/models/app_role.dart';

/// The signed-in Supabase user, reduced to what the app needs.
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is AuthUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

/// One change to the auth session.
class AuthEvent {
  const AuthEvent(this.user, {this.passwordRecovery = false});

  /// Null when signed out.
  final AuthUser? user;

  /// True when the user arrived through a password-reset link
  /// (`AuthChangeEvent.passwordRecovery`).
  final bool passwordRecovery;
}

/// Everything routing needs to know about the signed-in account: the
/// `profiles` row plus the two onboarding flags (PL-11).
class AccountProfile {
  const AccountProfile({
    required this.userId,
    this.role,
    this.displayName,
    this.termsAcceptedAt,
    this.candidateOnboarded = false,
    this.recruiterHasCompany = false,
  });

  final String userId;

  /// Null for Google users who haven't picked a role yet (US-02).
  final AppRole? role;
  final String? displayName;
  final DateTime? termsAcceptedAt;

  /// `candidates.active_version_id != null`.
  final bool candidateOnboarded;

  /// A `recruiters` row exists for this user.
  final bool recruiterHasCompany;

  factory AccountProfile.fromJson(
    Map<String, dynamic> json, {
    bool candidateOnboarded = false,
    bool recruiterHasCompany = false,
  }) {
    final role = json['role'] as String?;
    final terms = json['terms_accepted_at'] as String?;
    return AccountProfile(
      userId: json['id'] as String,
      role: role == null ? null : AppRole.values.byName(role),
      displayName: json['display_name'] as String?,
      termsAcceptedAt: terms == null ? null : DateTime.parse(terms),
      candidateOnboarded: candidateOnboarded,
      recruiterHasCompany: recruiterHasCompany,
    );
  }

  AccountProfile copyWith({
    AppRole? role,
    bool? candidateOnboarded,
    bool? recruiterHasCompany,
  }) => AccountProfile(
    userId: userId,
    role: role ?? this.role,
    displayName: displayName,
    termsAcceptedAt: termsAcceptedAt,
    candidateOnboarded: candidateOnboarded ?? this.candidateOnboarded,
    recruiterHasCompany: recruiterHasCompany ?? this.recruiterHasCompany,
  );
}
