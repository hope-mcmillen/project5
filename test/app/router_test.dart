import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/app/shells.dart';
import 'package:project5/core/models/app_role.dart';

import 'dart:typed_data';

import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/features/onboarding/data/resume_picker.dart';
import 'package:project5/features/onboarding/domain/resume_file.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';

void main() {
  group('resolveRedirect', () {
    String? go(RouteSession session, String location) =>
        resolveRedirect(session, Uri.parse(location));

    test('signed-out users only see public pages', () {
      const s = RouteSession.signedOut;
      expect(go(s, Routes.welcome), isNull);
      expect(go(s, Routes.signIn), isNull);
      expect(go(s, Routes.deck), Routes.welcome);
      expect(go(s, Routes.jobs), Routes.welcome);
      expect(go(s, Routes.roleChoice), Routes.welcome);
      expect(go(s, Routes.recruiterAlias), '${Routes.welcome}?role=recruiter');
    });

    test('loading holds on the splash, then continues where it was going', () {
      final held = go(RouteSession.loading, Routes.boardFor(DemoIds.job))!;
      expect(Uri.parse(held).path, Routes.splash);
      expect(go(RouteSession.loading, held), isNull);

      const recruiter = RouteSession.recruiter();
      expect(go(recruiter, held), Routes.boardFor(DemoIds.job));
      expect(go(RouteSession.signedOut, held), Routes.welcome);
      expect(go(recruiter, Routes.splash), Routes.jobs);
    });

    test('a profile error also holds on the splash', () {
      const s = RouteSession(status: SessionStatus.error);
      expect(Uri.parse(go(s, Routes.jobs)!).path, Routes.splash);
    });

    test('signed in without a role goes to role choice only', () {
      const s = RouteSession(status: SessionStatus.signedIn);
      expect(go(s, Routes.roleChoice), isNull);
      expect(go(s, Routes.welcome), Routes.roleChoice);
      expect(go(s, Routes.deck), Routes.roleChoice);
      expect(go(s, Routes.jobs), Routes.roleChoice);
    });

    test('a password-reset session stays on the reset page', () {
      const s = RouteSession(
        status: SessionStatus.signedIn,
        role: AppRole.candidate,
        candidateOnboarded: true,
        passwordRecovery: true,
      );
      expect(go(s, Routes.resetPassword), isNull);
      expect(go(s, Routes.deck), Routes.resetPassword);
    });

    test('new candidate can skip onboarding and use candidate navigation', () {
      const fresh = RouteSession.candidate(onboarded: false);
      expect(go(fresh, Routes.signIn), Routes.candidateConsent);
      expect(go(fresh, Routes.deck), isNull);
      expect(go(fresh, Routes.candidateProfile), isNull);
      expect(go(fresh, Routes.profileResume), isNull);
      expect(go(fresh, Routes.pipeline), isNull);
      expect(go(fresh, Routes.candidateUpload), isNull);

      const done = RouteSession.candidate();
      expect(go(done, Routes.signIn), Routes.deck);
      expect(go(done, Routes.deck), isNull);
    });

    test('new recruiter is sent to company onboarding, then jobs', () {
      const fresh = RouteSession.recruiter(hasCompany: false);
      expect(go(fresh, Routes.jobs), Routes.companyOnboarding);
      expect(go(fresh, Routes.createCompany), isNull);

      const done = RouteSession.recruiter();
      expect(go(done, Routes.welcome), Routes.jobs);
      expect(go(done, Routes.createCompany), Routes.jobs);
      expect(go(done, Routes.boardFor(DemoIds.job)), isNull);
    });

    test('roles cannot enter each other\'s area', () {
      expect(go(const RouteSession.candidate(), Routes.jobs), Routes.deck);
      expect(go(const RouteSession.recruiter(), Routes.deck), Routes.jobs);
      expect(
        go(const RouteSession.recruiter(), Routes.candidateUpload),
        Routes.jobs,
      );
    });
  });

  testWidgets('new candidate can leave consent through the sidebar', (
    tester,
  ) async {
    final router = buildRouter(
      session: () => const RouteSession.candidate(onboarded: false),
      initialLocation: Routes.candidateConsent,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(latency: Duration.zero),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Applications'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.pipeline);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('every route builds a page', () {
    // All concrete locations, with demo ids filled in.
    final candidatePages = [
      Routes.candidateConsent,
      Routes.candidateUpload,
      Routes.parseProgress(DemoIds.resume),
      Routes.candidateReview,
      Routes.candidatePreferences,
      Routes.deck,
      Routes.deepDiveFor(DemoIds.job),
      Routes.pipeline,
      Routes.applicationDetailFor(DemoIds.application),
      Routes.candidateProfile,
      Routes.profilePreferences,
      Routes.profileResume,
    ];
    final recruiterPages = [
      Routes.jobs,
      Routes.newJob,
      Routes.jobRequirementsFor(DemoIds.job),
      Routes.jobDetailsFor(DemoIds.job),
      Routes.boardFor(DemoIds.job),
      Routes.candidateDetailFor(DemoIds.job, DemoIds.application),
      Routes.interviews,
      Routes.companySettings,
    ];
    final recruiterOnboardingPages = [
      Routes.companyOnboarding,
      Routes.createCompany,
      Routes.joinCompany,
    ];
    final publicPages = [
      Routes.welcome,
      Routes.signIn,
      Routes.signUp,
      Routes.forgotPassword,
      Routes.resetPassword,
    ];

    Future<void> expectPage(
      WidgetTester tester,
      RouteSession session,
      String location,
    ) async {
      final router = buildRouter(
        session: () => session,
        initialLocation: location,
      );
      await tester.pumpWidget(
        ProviderScope(
          // A fresh container per page, so fakes don't carry over.
          key: UniqueKey(),
          retry: noAutomaticRetry,
          overrides: fakeRepositoryOverrides(
            auth: FakeAuthRepository(latency: Duration.zero),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.state.uri.toString(),
        location,
        reason: 'redirected away from $location',
      );
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: 'no page for $location',
      );
      router.dispose();
    }

    testWidgets('public pages', (tester) async {
      for (final location in publicPages) {
        await expectPage(tester, RouteSession.signedOut, location);
      }
      await expectPage(
        tester,
        const RouteSession(status: SessionStatus.signedIn),
        Routes.roleChoice,
      );
    });

    testWidgets('candidate pages', (tester) async {
      for (final location in candidatePages) {
        await expectPage(tester, const RouteSession.candidate(), location);
      }
    });

    testWidgets('recruiter pages', (tester) async {
      for (final location in recruiterPages) {
        await expectPage(tester, const RouteSession.recruiter(), location);
      }
      for (final location in recruiterOnboardingPages) {
        await expectPage(
          tester,
          const RouteSession.recruiter(hasCompany: false),
          location,
        );
      }
    });
  });

  group('app routing on fake auth', () {
    late FakeAuthRepository auth;
    setUp(() => auth = FakeAuthRepository(latency: Duration.zero));
    tearDown(() => auth.dispose());

    Future<GoRouter> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: [
            ...fakeRepositoryOverrides(auth: auth, latency: Duration.zero),
            resumePickerProvider.overrideWithValue(
              () async => ResumeFile.fromBytes(
                name: 'resume.pdf',
                bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
              ),
            ),
          ],
          child: const ResuRhombusApp(),
        ),
      );
      await tester.pumpAndSettle();
      return GoRouter.of(tester.element(find.byType(Scaffold).first));
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('candidate sign-up to deck', (tester) async {
      await pumpApp(tester);
      expect(find.text('Welcome to ResuRhombus'), findsOneWidget);

      await tap(tester, "I'm looking for a job");
      await tap(tester, 'Continue');
      expect(find.text('Create your account'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'new.candidate@example.test',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password1',
      );
      await tap(tester, 'I agree to the Terms of Service and Privacy Policy');
      await tap(tester, 'Create account');
      expect(find.text('Before we start'), findsWidgets); // onboarding
      await tap(tester, 'Agree and continue');
      await tap(tester, 'Choose file');
      await tap(tester, 'Upload resume');
      await tap(tester, 'Confirm skills');
      await tap(tester, 'Start swiping');
      expect(find.text('Your deck'), findsWidgets);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);

      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      expect(router.state.uri.path, Routes.deck);
    });

    testWidgets('a stored session lands on its own home', (tester) async {
      await auth.signInWithEmail(
        email: FakeAuthRepository.demoRecruiterEmail,
        password: FakeAuthRepository.demoPassword,
      );
      final router = await pumpApp(tester);
      expect(router.state.uri.path, Routes.jobs);

      router.go(Routes.deck);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.jobs);
    });

    testWidgets('signing out returns to welcome', (tester) async {
      await auth.signInWithEmail(
        email: FakeAuthRepository.demoCandidateEmail,
        password: FakeAuthRepository.demoPassword,
      );
      final router = await pumpApp(tester);
      expect(router.state.uri.path, Routes.deck);

      await auth.signOut();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.welcome);
    });

    testWidgets(
      'a stored session stuck in onboarding can sign out back to Welcome',
      (tester) async {
        await auth.signUpWithEmail(
          email: 'unfinished@example.test',
          password: 'password1',
          role: AppRole.candidate,
        );
        final router = await pumpApp(tester);
        expect(router.state.uri.path, Routes.candidateConsent);
        expect(find.text('Sign out'), findsOneWidget);

        await tap(tester, 'Agree and continue');
        expect(router.state.uri.path, Routes.candidateUpload);
        await tap(tester, 'Sign out');
        expect(router.state.uri.path, Routes.welcome);
        expect(find.text("I'm looking for a job"), findsOneWidget);
        expect(find.text("I'm hiring"), findsOneWidget);
      },
    );

    testWidgets('Google sign-in without a role goes to role choice', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await auth.signInWithGoogle();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.roleChoice);

      await tap(tester, "I'm hiring");
      await tap(tester, 'Continue');
      expect(router.state.uri.path, Routes.companyOnboarding);
    });

    testWidgets('a reset link opens the reset page', (tester) async {
      final router = await pumpApp(tester);
      auth.openResetLink(FakeAuthRepository.demoCandidateEmail);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.resetPassword);

      router.go(Routes.deck);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.resetPassword);

      for (final field in ['New password', 'Confirm password']) {
        await tester.enterText(
          find.widgetWithText(TextFormField, field),
          'brand-new-pass',
        );
      }
      await tap(tester, 'Save password');
      expect(router.state.uri.path, Routes.deck);
    });
  });

  group('recruiter shell', () {
    Future<void> pumpAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = buildRouter(
        session: () => const RouteSession.recruiter(),
        initialLocation: Routes.jobs,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: fakeRepositoryOverrides(
            auth: FakeAuthRepository(latency: Duration.zero),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('phones get a bottom bar', (tester) async {
      await pumpAt(tester, 360);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('laptops get a rail, extended from 1200 px', (tester) async {
      await pumpAt(tester, 1000);
      expect(find.byType(NavigationBar), findsNothing);
      var rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);

      await pumpAt(tester, 1280);
      rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
    });

    testWidgets('selecting a tab keeps the rail in sync', (tester) async {
      await pumpAt(tester, 1280);
      await tester.tap(find.text('Company'));
      await tester.pumpAndSettle();
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, 2);
      expect(find.byType(RecruiterShell), findsOneWidget);
    });
  });
}
