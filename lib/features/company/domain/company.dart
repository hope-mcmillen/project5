/// A recruiter workspace (`companies` row, API_CONTRACT §7.1).
class Company {
  const Company({
    required this.id,
    required this.name,
    this.website,
    this.logoPath,
    this.verified = false,
    this.createdBy,
  });

  final String id;
  final String name;
  final String? website;

  /// Path inside the public `company-logos` bucket, e.g. `{id}/logo.png`.
  final String? logoPath;
  final bool verified;
  final String? createdBy;

  factory Company.fromJson(Map<String, dynamic> json) => Company(
    id: json['id'] as String,
    name: json['name'] as String,
    website: json['website'] as String?,
    logoPath: json['logo_path'] as String?,
    verified: json['verified'] as bool? ?? false,
    createdBy: json['created_by'] as String?,
  );

  Company copyWith({String? logoPath}) => Company(
    id: id,
    name: name,
    website: website,
    logoPath: logoPath ?? this.logoPath,
    verified: verified,
    createdBy: createdBy,
  );
}

/// Mirrors the Postgres `company_role` enum.
enum CompanyRole { owner, member }

/// The caller's company and their role in it.
class CompanyMembership {
  const CompanyMembership({required this.company, required this.role});

  final Company company;
  final CompanyRole role;

  bool get isOwner => role == CompanyRole.owner;
}

/// A teammate invite code (`company_invites` row).
class CompanyInvite {
  const CompanyInvite({
    required this.code,
    required this.expiresAt,
    this.revokedAt,
    this.maxUses = 10,
    this.uses = 0,
  });

  final String code;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final int maxUses;
  final int uses;

  /// Usable right now: not revoked, not expired and not used up.
  bool isActive(DateTime now) =>
      revokedAt == null && expiresAt.isAfter(now) && uses < maxUses;

  factory CompanyInvite.fromJson(Map<String, dynamic> json) {
    final revoked = json['revoked_at'] as String?;
    return CompanyInvite(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      revokedAt: revoked == null ? null : DateTime.parse(revoked),
      maxUses: json['max_uses'] as int? ?? 10,
      uses: json['uses'] as int? ?? 0,
    );
  }
}
