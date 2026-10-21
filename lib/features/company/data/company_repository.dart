import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../domain/company.dart';
import 'fake_company_repository.dart';

/// Company workspace calls (PL-15, API_CONTRACT §7.1).
abstract interface class CompanyRepository {
  /// `rpc('create_company')`, then an optional logo upload to
  /// `company-logos/{id}/logo.png`. The caller becomes the owner.
  Future<Company> create({
    required String name,
    String? website,
    Uint8List? logo,
  });

  /// `rpc('join_company')`. Throws `invalid_invite` or `already_in_company`.
  Future<Company> join(String code);

  /// The caller's company and role, or null before onboarding.
  Future<CompanyMembership?> myCompany();

  /// The company's invite codes, newest first (owner only).
  Future<List<CompanyInvite>> invites();

  /// `rpc('create_invite')`: returns the new 8-character code.
  Future<String> createInvite({int expiresInDays = 7});

  /// `rpc('revoke_invite')`.
  Future<void> revokeInvite(String code);

  /// Public URL for a `logo_path` in the `company-logos` bucket.
  String? logoUrl(String? logoPath);
}

/// TODO(PL-15): switch the default to `SupabaseCompanyRepository`.
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return FakeCompanyRepository(auth: auth is FakeAuthRepository ? auth : null);
});
