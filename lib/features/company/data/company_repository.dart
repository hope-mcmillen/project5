import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/company.dart';
import 'supabase_company_repository.dart';

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

final companyRepositoryProvider = Provider<CompanyRepository>(
  (ref) => SupabaseCompanyRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in recruiter's company and role (null before onboarding).
final myCompanyProvider = FutureProvider<CompanyMembership?>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(companyRepositoryProvider).myCompany();
});

/// The company's invite codes, newest first. Owners only.
final invitesProvider = FutureProvider<List<CompanyInvite>>((ref) async {
  final membership = await ref.watch(myCompanyProvider.future);
  if (membership == null || !membership.isOwner) return const [];
  return ref.watch(companyRepositoryProvider).invites();
});
