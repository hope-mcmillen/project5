import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/company.dart';
import '../domain/logo_image.dart';
import 'company_repository.dart';

/// [CompanyRepository] backed by the A4 RPCs and the public
/// `company-logos` bucket (PL-15).
class SupabaseCompanyRepository implements CompanyRepository {
  SupabaseCompanyRepository(this._client);

  final SupabaseClient _client;

  static const _logos = 'company-logos';

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppFailure('not_authenticated');
    return id;
  }

  @override
  Future<Company> create({
    required String name,
    String? website,
    Uint8List? logo,
  }) => _guard(() async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'create_company',
      params: {'p_name': name.trim(), 'p_website': website?.trim()},
    );
    final company = Company.fromJson(row);
    if (logo == null) return company;

    // The company exists now, so a failed logo upload must not fail the
    // whole step (a retry would hit already_in_company).
    try {
      final path = '${company.id}/logo.png';
      await _client.storage
          .from(_logos)
          .uploadBinary(
            path,
            logo,
            fileOptions: FileOptions(
              contentType: LogoImage.contentTypeOf(logo),
              upsert: true,
            ),
          );
      await _client
          .from('companies')
          .update({'logo_path': path})
          .eq('id', company.id);
      return company.copyWith(logoPath: path);
    } catch (error) {
      debugPrint('Company logo upload failed: $error');
      return company;
    }
  });

  @override
  Future<Company> join(String code) => _guard(() async {
    final row = await _client.rpc<Map<String, dynamic>>(
      'join_company',
      params: {'p_code': code.trim().toUpperCase()},
    );
    return Company.fromJson(row);
  });

  @override
  Future<CompanyMembership?> myCompany() => _guard(() async {
    final row = await _client
        .from('recruiters')
        .select('company_role, companies(*)')
        .eq('profile_id', _userId)
        .maybeSingle();
    if (row == null) return null;
    return CompanyMembership(
      company: Company.fromJson(row['companies'] as Map<String, dynamic>),
      role: CompanyRole.values.byName(row['company_role'] as String),
    );
  });

  @override
  Future<List<CompanyInvite>> invites() => _guard(() async {
    // RLS limits this to the owner's own company.
    final rows = await _client
        .from('company_invites')
        .select('code, expires_at, revoked_at, max_uses, uses')
        .order('created_at', ascending: false);
    return rows.map(CompanyInvite.fromJson).toList();
  });

  @override
  Future<String> createInvite({int expiresInDays = 7}) => _guard(
    () => _client.rpc<String>(
      'create_invite',
      params: {'p_expires_in_days': expiresInDays},
    ),
  );

  @override
  Future<void> revokeInvite(String code) => _guard(
    () => _client.rpc<void>(
      'revoke_invite',
      params: {'p_code': code.trim().toUpperCase()},
    ),
  );

  @override
  String? logoUrl(String? logoPath) => logoPath == null
      ? null
      : _client.storage.from(_logos).getPublicUrl(logoPath);
}
