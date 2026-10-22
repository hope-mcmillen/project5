import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/auth/presentation/forgot_password_screen.dart';
import 'package:project5/features/auth/presentation/reset_password_screen.dart';
import 'package:project5/features/auth/presentation/role_choice_screen.dart';
import 'package:project5/features/auth/presentation/sign_in_screen.dart';
import 'package:project5/features/auth/presentation/sign_up_screen.dart';
import 'package:project5/features/auth/presentation/welcome_screen.dart';

void main() {
  late FakeAuthRepository auth;
  late GoRouter router;

  setUp(() => auth = FakeAuthRepository(latency: Duration.zero));
  tearDown(() => auth.dispose());

  /// Shows [screen] at `/start`; every other route is a labelled stub.
  Future<void> pump(WidgetTester tester, Widget screen) async {
    Widget stub(String name) => Scaffold(body: Text('stub:$name'));
    router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => screen),
        GoRoute(path: '/', builder: (_, _) => stub('/')),
        for (final path in [
          Routes.signUp,
          Routes.signIn,
          Routes.welcome,
          Routes.forgotPassword,
        ])
          GoRoute(path: path, builder: (_, state) => stub('${state.uri}')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeRepositoryOverrides(auth: auth),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label).last);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String field, String text) =>
      tester.enterText(find.widgetWithText(TextFormField, field), text);

  group('Welcome', () {
    testWidgets('Continue is disabled until a role is picked', (tester) async {
      await pump(tester, const WelcomeScreen());
      final button = find.widgetWithText(FilledButton, 'Continue');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);

      await tap(tester, "I'm hiring");
      await tap(tester, 'Continue');
      expect(find.text('stub:/sign-up?role=recruiter'), findsOneWidget);
    });

    testWidgets('?role=recruiter preselects "I\'m hiring"', (tester) async {
      await pump(tester, const WelcomeScreen(preselectedRole: 'recruiter'));
      await tap(tester, 'Continue');
      expect(find.text('stub:/sign-up?role=recruiter'), findsOneWidget);
    });
  });

  group('Sign up', () {
    testWidgets('validates email, password length and Terms', (tester) async {
      await pump(tester, const SignUpScreen(role: 'candidate'));
      await type(tester, 'Email', 'not-an-email');
      await type(tester, 'Password', 'short');
      await tap(tester, 'Create account');

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text('Accept the Terms to continue.'), findsOneWidget);
      expect(auth.currentUser, isNull);
    });

    testWidgets('creates an account with the selected role', (tester) async {
      await pump(tester, const SignUpScreen(role: 'candidate'));
      await tap(tester, 'Recruiter');
      await type(tester, 'Email', 'hire@example.test');
      await type(tester, 'Password', 'password1');
      await tap(tester, 'I agree to the Terms of Service and Privacy Policy');
      await tap(tester, 'Create account');

      expect(auth.currentUser?.email, 'hire@example.test');
      expect((await auth.fetchProfile())?.role, AppRole.recruiter);
    });

    testWidgets('shows a duplicate-account error inline', (tester) async {
      await pump(tester, const SignUpScreen(role: 'candidate'));
      await type(tester, 'Email', FakeAuthRepository.demoCandidateEmail);
      await type(tester, 'Password', 'password1');
      await tap(tester, 'I agree to the Terms of Service and Privacy Policy');
      await tap(tester, 'Create account');
      expect(
        find.text('An account with that email already exists.'),
        findsOneWidget,
      );
    });
  });

  group('Sign in', () {
    testWidgets('wrong password shows an error', (tester) async {
      await pump(tester, const SignInScreen());
      await type(tester, 'Email', FakeAuthRepository.demoRecruiterEmail);
      await type(tester, 'Password', 'nope');
      await tap(tester, 'Sign in');
      expect(
        find.text('That email and password don\'t match.'),
        findsOneWidget,
      );
      expect(auth.currentUser, isNull);
    });

    testWidgets('demo recruiter signs in', (tester) async {
      await pump(tester, const SignInScreen());
      await type(tester, 'Email', FakeAuthRepository.demoRecruiterEmail);
      await type(tester, 'Password', FakeAuthRepository.demoPassword);
      await tap(tester, 'Sign in');
      expect(auth.currentUser?.email, FakeAuthRepository.demoRecruiterEmail);
    });

    testWidgets('Google sign-in starts a session with no role', (tester) async {
      await pump(tester, const SignInScreen());
      await tap(tester, 'Continue with Google');
      expect(auth.currentUser?.email, FakeAuthRepository.googleEmail);
      expect((await auth.fetchProfile())?.role, isNull);
    });
  });

  testWidgets('Role choice sets the role once', (tester) async {
    await auth.signInWithGoogle();
    await pump(tester, const RoleChoiceScreen());
    await tap(tester, "I'm looking for a job");
    await tap(tester, 'Continue');
    expect((await auth.fetchProfile())?.role, AppRole.candidate);
  });

  testWidgets('Forgot password confirms without revealing accounts', (
    tester,
  ) async {
    await pump(tester, const ForgotPasswordScreen());
    await type(tester, 'Email', 'nobody@example.test');
    await tap(tester, 'Send reset link');
    expect(find.text('Check your email'), findsOneWidget);
    expect(auth.sentResetEmails, ['nobody@example.test']);
  });

  testWidgets('Reset password requires matching passwords', (tester) async {
    auth.openResetLink(FakeAuthRepository.demoCandidateEmail);
    await pump(tester, const ResetPasswordScreen());
    await type(tester, 'New password', 'new-password');
    await type(tester, 'Confirm password', 'different');
    await tap(tester, 'Save password');
    expect(find.text('Passwords don\'t match.'), findsOneWidget);

    await type(tester, 'Confirm password', 'new-password');
    await tap(tester, 'Save password');
    expect(find.text('stub:/'), findsOneWidget);
  });
}
