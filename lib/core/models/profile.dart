import 'app_role.dart';

/// Immutable profile data for candidate and recruiter screens.
class Profile {
  Profile({
    required this.id,
    this.role,
    this.displayName,
    this.termsAcceptedAt,
  });
  final String id;
  final AppRole? role;
  final String? displayName;
  final DateTime? termsAcceptedAt;
  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    role: json['role'] == null ? null : AppRole.fromDb(json['role'] as String),
    displayName: json['display_name'] == null
        ? null
        : json['display_name'] as String,
    termsAcceptedAt: json['terms_accepted_at'] == null
        ? null
        : DateTime.parse(json['terms_accepted_at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role?.toDb(),
    'display_name': displayName,
    'terms_accepted_at': termsAcceptedAt?.toIso8601String(),
  };
}
