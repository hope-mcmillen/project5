import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/ui/scaffold/placeholder_page.dart';

void main() {
  group('resolveRedirect', () {
    late DevSession session;
    setUp(() => session = DevSession());
    String? go(String location) =>
        resolveRedirect(session, Uri.parse(location));

    test('signed-out users only see public pages', () {
      expect(go(Routes.welcome), isNull);
      expect(go(Routes.signIn), isNull);
      expect(go(Routes.deck), Routes.welcome);
      expect(go(Routes.jobs), Routes.welcome);
      expect(go(Routes.recruiterAlias), '${Routes.welcome}?role=recruiter');
    });

    test('new candidate is sent to onboarding, then the deck', () {
      session.signIn(AppRole.candidate);
      expect(go(Routes.signIn), Routes.candidateConsent);
      expect(go(Routes.deck), Routes.candidateConsent);
      expect(go(Routes.candidateUpload), isNull);

      session.completeCandidateOnboarding();
      expect(go(Routes.signIn), Routes.deck);
      expect(go(Routes.deck), isNull);
    });

    test('new recruiter is sent to company onboarding, then jobs', () {
      session.signIn(AppRole.recruiter);
      expect(go(Routes.jobs), Routes.companyOnboarding);
      expect(go(Routes.createCompany), isNull);

      session.completeCompanyOnboarding();
      expect(go(Routes.welcome), Routes.jobs);
      expect(go(Routes.boardFor(DemoIds.job)), isNull);
    });

    test('roles cannot enter each other\'s area', () {
      session
        ..signIn(AppRole.candidate)
        ..completeCandidateOnboarding();
      expect(go(Routes.jobs), Routes.deck);

      session
        ..signOut()
        ..signIn(AppRole.recruiter)
        ..completeCompanyOnboarding();
      expect(go(Routes.deck), Routes.jobs);
    });
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
      Routes.companyOnboarding,
      Routes.createCompany,
      Routes.joinCompany,
      Routes.jobs,
      Routes.newJob,
      Routes.jobRequirementsFor(DemoIds.job),
      Routes.jobDetailsFor(DemoIds.job),
      Routes.boardFor(DemoIds.job),
      Routes.candidateDetailFor(DemoIds.job, DemoIds.application),
      Routes.interviews,
      Routes.companySettings,
    ];
    final publicPages = [
      Routes.welcome,
      Routes.roleChoice,
      Routes.signIn,
      Routes.signUp,
      Routes.forgotPassword,
      Routes.resetPassword,
    ];

    Future<void> expectPage(
      WidgetTester tester,
      DevSession session,
      String location,
    ) async {
      final router = buildRouter(session);
      await tester.pumpWidget(
        ProviderScope(
          overrides: fakeRepositoryOverrides(
            auth: FakeAuthRepository(latency: Duration.zero),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.go(location);
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
        await expectPage(tester, DevSession(), location);
      }
    });

    testWidgets('candidate pages', (tester) async {
      final session = DevSession()
        ..signIn(AppRole.candidate)
        ..completeCandidateOnboarding();
      for (final location in candidatePages) {
        await expectPage(tester, session, location);
      }
    });

    testWidgets('recruiter pages', (tester) async {
      final session = DevSession()
        ..signIn(AppRole.recruiter)
        ..completeCompanyOnboarding();
      for (final location in recruiterPages) {
        await expectPage(tester, session, location);
      }
    });
  });

  testWidgets('click-through: candidate sign-up to deck', (tester) async {
    addTearDown(devSession.signOut);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(
          auth: FakeAuthRepository(latency: Duration.zero),
        ),
        child: const ResuRhombusApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ResuRhombus'), findsOneWidget);

    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await tap("I'm looking for a job");
    await tap('Continue');
    expect(find.text('Create your account'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'new.candidate@example.test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password1',
    );
    await tap('I agree to the Terms of Service and Privacy Policy');
    await tap('Create account');
    expect(
      find.text('Before we start'),
      findsWidgets,
    ); // redirected to onboarding
    await tap('Agree and continue');
    await tap('[Fake] Upload resume');
    await tap('[Fake] Parsing finished');
    await tap('Looks right, continue');
    await tap('Start swiping');
    expect(find.text('Your deck'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);

    final router = GoRouter.of(
      tester.element(find.byType(PlaceholderPage).first),
    );
    expect(router.state.uri.path, Routes.deck);
  });
}
