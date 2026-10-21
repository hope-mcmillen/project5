import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/auth/domain/auth_models.dart';

void main() {
  late FakeAuthRepository auth;
  setUp(() => auth = FakeAuthRepository(latency: Duration.zero));
  tearDown(() => auth.dispose());

  test('signs up with the chosen role and emits the new session', () async {
    final events = <AuthEvent>[];
    final sub = auth.authEvents().listen(events.add);
    await auth.signUpWithEmail(
      email: 'New@Example.test',
      password: 'password1',
      role: AppRole.recruiter,
    );
    await pumpEventQueue();

    final profile = await auth.fetchProfile();
    expect(profile?.role, AppRole.recruiter);
    expect(profile?.recruiterHasCompany, isFalse);
    expect(events.first.user, isNull);
    expect(events.last.user?.email, 'new@example.test');
    await sub.cancel();
  });

  test('rejects wrong passwords and duplicate sign-ups', () async {
    await expectLater(
      auth.signInWithEmail(
        email: FakeAuthRepository.demoCandidateEmail,
        password: 'wrong',
      ),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'invalid_credentials'),
      ),
    );
    await expectLater(
      auth.signUpWithEmail(
        email: FakeAuthRepository.demoCandidateEmail,
        password: 'password1',
        role: AppRole.candidate,
      ),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'user_already_exists'),
      ),
    );
  });

  test('demo accounts are already onboarded', () async {
    await auth.signInWithEmail(
      email: FakeAuthRepository.demoRecruiterEmail,
      password: FakeAuthRepository.demoPassword,
    );
    final profile = await auth.fetchProfile();
    expect(profile?.role, AppRole.recruiter);
    expect(profile?.recruiterHasCompany, isTrue);
  });

  test('Google users pick a role exactly once', () async {
    await auth.signInWithGoogle();
    expect((await auth.fetchProfile())?.role, isNull);

    await auth.setInitialRole(AppRole.candidate);
    expect((await auth.fetchProfile())?.role, AppRole.candidate);
    await expectLater(
      auth.setInitialRole(AppRole.recruiter),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'role_already_set'),
      ),
    );
  });

  test('reset link opens a recovery session that can set a password', () async {
    await auth.resetPassword(FakeAuthRepository.demoCandidateEmail);
    expect(auth.sentResetEmails, [FakeAuthRepository.demoCandidateEmail]);

    final recovery = auth.authEvents().firstWhere((e) => e.passwordRecovery);
    auth.openResetLink(FakeAuthRepository.demoCandidateEmail);
    expect((await recovery).user, isNotNull);

    await auth.updatePassword('a-new-password');
    await auth.signOut();
    await auth.signInWithEmail(
      email: FakeAuthRepository.demoCandidateEmail,
      password: 'a-new-password',
    );
    expect(auth.currentUser, isNotNull);
  });

  test('failNext makes exactly one call fail', () async {
    auth.failNext = const AppFailure('unknown');
    await expectLater(auth.fetchProfile(), throwsA(isA<AppFailure>()));
    expect(await auth.fetchProfile(), isNull);
  });
}
