import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/board/data/fake_board_repository.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';

/// RC-20: every recruiter and auth page at 360 px and 1280 px, at 1.0× and
/// 2.0× text, with no overflow and with the tap-target, label and contrast
/// guidelines met.
void main() {
  const job = FakeBoardRepository.demoJobId;
  final application = FakeBoardRepository.demoTiles.first.applicationId;

  final recruiterPages = [
    Routes.jobs,
    Routes.newJob,
    Routes.jobRequirementsFor(job),
    Routes.jobDetailsFor(job),
    Routes.boardFor(job),
    Routes.candidateDetailFor(job, application),
    Routes.interviews,
    Routes.companySettings,
  ];
  final onboardingPages = [
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

  Future<void> check(
    WidgetTester tester,
    RouteSession session,
    String location, {
    required double width,
    required double textScale,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final auth = FakeAuthRepository(latency: Duration.zero);
    addTearDown(auth.dispose);
    await auth.signInWithEmail(
      email: FakeAuthRepository.demoRecruiterEmail,
      password: FakeAuthRepository.demoPassword,
    );
    final router = buildRouter(
      session: () => session,
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        retry: noAutomaticRetry,
        overrides: fakeRepositoryOverrides(
          auth: auth,
          jobs: FakeJobRepository(latency: Duration.zero),
          board: FakeBoardRepository(latency: Duration.zero),
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final where = '$location @ ${width.toInt()}px ×$textScale';
    expect(tester.takeException(), isNull, reason: where);
    await expectLater(
      tester,
      meetsGuideline(androidTapTargetGuideline),
      reason: where,
    );
    await expectLater(
      tester,
      meetsGuideline(labeledTapTargetGuideline),
      reason: where,
    );
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: where,
    );
  }

  for (final width in [360.0, 1280.0]) {
    for (final textScale in [1.0, 2.0]) {
      final label = '${width.toInt()}px ×$textScale';
      testWidgets('recruiter pages $label', (tester) async {
        for (final page in recruiterPages) {
          await check(
            tester,
            const RouteSession.recruiter(),
            page,
            width: width,
            textScale: textScale,
          );
        }
      });
      testWidgets('company onboarding $label', (tester) async {
        for (final page in onboardingPages) {
          await check(
            tester,
            const RouteSession.recruiter(hasCompany: false),
            page,
            width: width,
            textScale: textScale,
          );
        }
      });
      testWidgets('auth pages $label', (tester) async {
        for (final page in publicPages) {
          await check(
            tester,
            RouteSession.signedOut,
            page,
            width: width,
            textScale: textScale,
          );
        }
      });
    }
  }
}
