import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/account_menu.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';

/// Sign out must be one tap from every signed-in screen, for both roles,
/// and always land on Welcome.
void main() {
  late FakeAuthRepository auth;
  setUp(() => auth = FakeAuthRepository(latency: Duration.zero));
  tearDown(() => auth.dispose());

  const demoJob = '40000000-0000-0000-0000-000000000001';
  const demoApplication = '50000000-0000-0000-0000-000000000001';

  Future<GoRouter> pumpApp(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: fakeRepositoryOverrides(auth: auth, latency: Duration.zero),
        child: const ResuRhombusApp(),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(Scaffold).first));
  }

  Future<void> signIn(String email) => auth.signInWithEmail(
    email: email,
    password: FakeAuthRepository.demoPassword,
  );

  Future<void> signOutFromAccountMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Account').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.byKey(AccountMenuButton.signOutKey), findsOneWidget);
    await tester.tap(find.byKey(AccountMenuButton.signOutKey));
    await tester.pumpAndSettle();
  }

  void expectWelcome(GoRouter router) {
    expect(router.state.uri.path, Routes.welcome);
    expect(auth.currentUser, isNull);
    expect(find.text('Welcome to ResuRhombus'), findsOneWidget);
  }

  testWidgets('every candidate screen has the account menu', (tester) async {
    await signIn(FakeAuthRepository.demoCandidateEmail);
    final router = await pumpApp(tester);
    for (final route in [
      Routes.deck,
      Routes.pipeline,
      Routes.applicationDetailFor(demoApplication),
      Routes.candidateProfile,
      Routes.profilePreferences,
      Routes.profileResume,
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, route);
      expect(
        find.byTooltip('Account').hitTestable(),
        findsOneWidget,
        reason: route,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('every recruiter screen has the account menu', (tester) async {
    await signIn(FakeAuthRepository.demoRecruiterEmail);
    final router = await pumpApp(tester, width: 1280);
    for (final route in [
      Routes.jobs,
      Routes.newJob,
      Routes.jobRequirementsFor(demoJob),
      Routes.jobDetailsFor(demoJob),
      Routes.boardFor(demoJob),
      Routes.interviews,
      Routes.companySettings,
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, route);
      expect(
        find.byTooltip('Account').hitTestable(),
        findsOneWidget,
        reason: route,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('candidate signs out from the deck account menu', (
    tester,
  ) async {
    await signIn(FakeAuthRepository.demoCandidateEmail);
    final router = await pumpApp(tester);
    expect(router.state.uri.path, Routes.deck);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text(FakeAuthRepository.demoCandidateEmail), findsOneWidget);
    expect(find.text('Profile'), findsWidgets);
    await tester.tap(find.byKey(AccountMenuButton.signOutKey));
    await tester.pumpAndSettle();
    expectWelcome(router);
  });

  testWidgets('recruiter signs out from a pushed board screen', (
    tester,
  ) async {
    await signIn(FakeAuthRepository.demoRecruiterEmail);
    final router = await pumpApp(tester);
    router.push(Routes.boardFor(demoJob));
    await tester.pumpAndSettle();
    await signOutFromAccountMenu(tester);
    expectWelcome(router);
  });

  testWidgets('account menu opens Company for recruiters', (tester) async {
    await signIn(FakeAuthRepository.demoRecruiterEmail);
    final router = await pumpApp(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Company'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.companySettings);
  });

  for (final (role, email) in [
    (AppRole.candidate, FakeAuthRepository.demoCandidateEmail),
    (AppRole.recruiter, FakeAuthRepository.demoRecruiterEmail),
  ]) {
    testWidgets('${role.name} signs out from the navigation drawer', (
      tester,
    ) async {
      await signIn(email);
      final router = await pumpApp(tester);
      await tester.tap(find.byTooltip('Open navigation menu').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Sign out'));
      await tester.pumpAndSettle();
      expectWelcome(router);
    });
  }

  testWidgets('a recruiter without a company can sign out from the menu', (
    tester,
  ) async {
    await auth.signUpWithEmail(
      email: 'new.recruiter@example.test',
      password: 'password1',
      role: AppRole.recruiter,
    );
    final router = await pumpApp(tester);
    expect(router.state.uri.path, Routes.companyOnboarding);
    await signOutFromAccountMenu(tester);
    expectWelcome(router);
  });

  testWidgets('a candidate in onboarding can sign out from the menu', (
    tester,
  ) async {
    await auth.signUpWithEmail(
      email: 'new.candidate@example.test',
      password: 'password1',
      role: AppRole.candidate,
    );
    final router = await pumpApp(tester);
    expect(router.state.uri.path, Routes.candidateConsent);
    router.go(Routes.candidateUpload);
    await tester.pumpAndSettle();
    await signOutFromAccountMenu(tester);
    expectWelcome(router);
  });

  testWidgets('the account menu fits a 360 px phone at 2x text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await signIn(FakeAuthRepository.demoCandidateEmail);
    await pumpApp(tester, width: 360);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.byKey(AccountMenuButton.signOutKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
