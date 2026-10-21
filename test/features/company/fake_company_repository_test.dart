import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/company/data/fake_company_repository.dart';
import 'package:project5/features/company/domain/company.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeCompanyRepository companies;

  setUp(() async {
    auth = FakeAuthRepository(latency: Duration.zero);
    companies = FakeCompanyRepository(auth: auth, latency: Duration.zero);
    await auth.signUpWithEmail(
      email: 'recruiter@new.test',
      password: 'password1',
      role: AppRole.recruiter,
    );
  });
  tearDown(() => auth.dispose());

  Matcher failsWith(String code) =>
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', code));

  test('creating a company makes the caller its owner', () async {
    expect(await companies.myCompany(), isNull);
    final company = await companies.create(name: '  Prism Co  ');

    expect(company.name, 'Prism Co');
    final membership = await companies.myCompany();
    expect(membership?.company.id, company.id);
    expect(membership?.isOwner, isTrue);
    expect((await auth.fetchProfile())?.recruiterHasCompany, isTrue);
    await expectLater(
      companies.create(name: 'Again'),
      failsWith('already_in_company'),
    );
  });

  test('joining normalizes the code and makes the caller a member', () async {
    final company = await companies.join(' abcd2345 ');
    expect(company.id, FakeCompanyRepository.demoCompany.id);
    expect((await companies.myCompany())?.role, CompanyRole.member);
    expect((await auth.fetchProfile())?.recruiterHasCompany, isTrue);
  });

  test('bad codes fail with invalid_invite', () async {
    await expectLater(companies.join('ZZZZZZZZ'), failsWith('invalid_invite'));
  });

  test(
    'owners generate and revoke invites; revoked codes stop working',
    () async {
      await companies.create(name: 'Prism Co');
      final code = await companies.createInvite();
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{8}$')));

      final invites = await companies.invites();
      expect(invites.single.code, code);
      expect(invites.single.isActive(DateTime.now().toUtc()), isTrue);

      await companies.revokeInvite(code);
      expect(
        (await companies.invites()).single.isActive(DateTime.now().toUtc()),
        isFalse,
      );
      await expectLater(
        companies.createInvite(expiresInDays: 31),
        failsWith('invalid_expiry'),
      );
    },
  );

  test('members cannot manage invites', () async {
    await companies.join(FakeCompanyRepository.demoInviteCode);
    await expectLater(companies.invites(), failsWith('not_owner'));
    await expectLater(companies.createInvite(), failsWith('not_owner'));
  });
}
