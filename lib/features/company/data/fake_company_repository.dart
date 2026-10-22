import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';
import '../../auth/data/fake_auth_repository.dart';
import '../domain/company.dart';
import 'company_repository.dart';

/// In-memory [CompanyRepository] seeded from the API_CONTRACT §7.1 example.
///
/// When given the [FakeAuthRepository], creating or joining a company also
/// flips that account's "has company" flag, like the real `recruiters` row.
class FakeCompanyRepository implements CompanyRepository {
  FakeCompanyRepository({
    this.auth,
    this.latency = const Duration(milliseconds: 300),
    bool seedDemoCompany = true,
  }) {
    if (seedDemoCompany) {
      _companies[demoCompany.id] = demoCompany;
      _members['10000000-0000-0000-0000-000000000003'] = (
        demoCompany.id,
        CompanyRole.owner,
      );
      _invites[demoCompany.id] = [
        CompanyInvite(
          code: demoInviteCode,
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
        ),
      ];
    }
  }

  static const demoCompany = Company(
    id: '20000000-0000-0000-0000-000000000001',
    name: 'Rhombus Labs',
    website: 'https://rhombus.example.test',
    createdBy: '10000000-0000-0000-0000-000000000003',
  );
  static const demoInviteCode = 'ABCD2345';

  final FakeAuthRepository? auth;
  final Duration latency;

  /// When set, the next call throws this failure instead of running.
  AppFailure? failNext;

  final _companies = <String, Company>{};
  final _members = <String, (String companyId, CompanyRole role)>{};
  final _invites = <String, List<CompanyInvite>>{};
  int _nextCompany = 100;
  int _nextCode = 0;

  String get _userId => auth?.currentUser?.id ?? 'fake-user';

  Future<void> _call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  void _requireNoCompany() {
    if (_members.containsKey(_userId)) {
      throw const AppFailure(
        'already_in_company',
        'You already belong to a company.',
      );
    }
  }

  String _requireOwner() {
    final member = _members[_userId];
    if (member == null || member.$2 != CompanyRole.owner) {
      throw const AppFailure(
        'not_owner',
        'Only the company owner can do that.',
      );
    }
    return member.$1;
  }

  @override
  Future<Company> create({
    required String name,
    String? website,
    Uint8List? logo,
  }) async {
    await _call();
    _requireNoCompany();
    final id =
        '20000000-0000-0000-0000-${(_nextCompany++).toString().padLeft(12, '0')}';
    final company = Company(
      id: id,
      name: name.trim(),
      website: website,
      logoPath: logo == null ? null : '$id/logo.png',
      createdBy: _userId,
    );
    _companies[id] = company;
    _members[_userId] = (id, CompanyRole.owner);
    auth?.markRecruiterHasCompany();
    return company;
  }

  @override
  Future<Company> join(String code) async {
    await _call();
    _requireNoCompany();
    final normalized = code.trim().toUpperCase();
    final now = DateTime.now().toUtc();
    for (final entry in _invites.entries) {
      final invites = entry.value;
      final index = invites.indexWhere(
        (i) => i.code == normalized && i.isActive(now),
      );
      if (index == -1) continue;
      final invite = invites[index];
      invites[index] = CompanyInvite(
        code: invite.code,
        expiresAt: invite.expiresAt,
        maxUses: invite.maxUses,
        uses: invite.uses + 1,
      );
      _members[_userId] = (entry.key, CompanyRole.member);
      auth?.markRecruiterHasCompany();
      return _companies[entry.key]!;
    }
    throw const AppFailure(
      'invalid_invite',
      'That invite code is invalid, expired, or used up.',
    );
  }

  @override
  Future<CompanyMembership?> myCompany() async {
    await _call();
    final member = _members[_userId];
    if (member == null) return null;
    return CompanyMembership(company: _companies[member.$1]!, role: member.$2);
  }

  @override
  Future<List<CompanyInvite>> invites() async {
    await _call();
    final companyId = _requireOwner();
    return (_invites[companyId] ?? const <CompanyInvite>[]).reversed.toList();
  }

  @override
  Future<String> createInvite({int expiresInDays = 7}) async {
    await _call();
    final companyId = _requireOwner();
    if (expiresInDays < 1 || expiresInDays > 30) {
      throw const AppFailure(
        'invalid_expiry',
        'Invites can last 1 to 30 days.',
      );
    }
    final code = _code(_nextCode++);
    (_invites[companyId] ??= []).add(
      CompanyInvite(
        code: code,
        expiresAt: DateTime.now().toUtc().add(Duration(days: expiresInDays)),
      ),
    );
    return code;
  }

  @override
  Future<void> revokeInvite(String code) async {
    await _call();
    final companyId = _requireOwner();
    final invites = _invites[companyId] ?? [];
    final normalized = code.trim().toUpperCase();
    final index = invites.indexWhere((i) => i.code == normalized);
    if (index == -1) {
      throw const AppFailure(
        'invalid_invite',
        'That invite code is invalid, expired, or used up.',
      );
    }
    final invite = invites[index];
    invites[index] = CompanyInvite(
      code: invite.code,
      expiresAt: invite.expiresAt,
      revokedAt: DateTime.now().toUtc(),
      maxUses: invite.maxUses,
      uses: invite.uses,
    );
  }

  @override
  String? logoUrl(String? logoPath) => null;

  /// Test hook: what A10's domain verification would set.
  void setVerified(String companyId, {required bool verified}) {
    final company = _companies[companyId]!;
    _companies[companyId] = Company(
      id: company.id,
      name: company.name,
      website: company.website,
      logoPath: company.logoPath,
      verified: verified,
      createdBy: company.createdBy,
    );
  }

  /// Deterministic codes from the unambiguous alphabet (no I, L, O, 0, 1).
  static String _code(int seed) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer('FAKE');
    var n = seed;
    for (var i = 0; i < 4; i++) {
      buffer.write(alphabet[n % alphabet.length]);
      n ~/= alphabet.length;
    }
    return buffer.toString();
  }
}
