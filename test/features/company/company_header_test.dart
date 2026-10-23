import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/company/data/fake_company_repository.dart';
import 'package:project5/features/company/presentation/widgets/company_header.dart';

/// RC-22: recruiters see whether their company is verified.
void main() {
  late FakeAuthRepository auth;
  late FakeCompanyRepository companies;

  setUp(() async {
    auth = FakeAuthRepository(latency: Duration.zero);
    companies = FakeCompanyRepository(auth: auth, latency: Duration.zero);
    await auth.signInWithEmail(
      email: FakeAuthRepository.demoRecruiterEmail,
      password: FakeAuthRepository.demoPassword,
    );
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(
      session: () => const RouteSession.recruiter(),
      initialLocation: Routes.jobs,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        retry: noAutomaticRetry,
        overrides: fakeRepositoryOverrides(auth: auth, companies: companies),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the employer drawer shows the company and its status', (
    tester,
  ) async {
    await pump(tester, 1280);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanyHeader), findsOneWidget);
    expect(find.text('Rhombus Labs'), findsWidgets);
    expect(find.text('Unverified'), findsWidgets);
  });

  testWidgets('verified companies say so', (tester) async {
    companies.setVerified(FakeCompanyRepository.demoCompany.id, verified: true);
    await pump(tester, 1280);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
  });

  testWidgets('the drawer keeps company status at medium widths', (
    tester,
  ) async {
    await pump(tester, 1000);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(CompanyHeader), findsOneWidget);
    expect(find.text('Unverified'), findsWidgets);
  });

  testWidgets('phones show it under the Jobs title', (tester) async {
    await pump(tester, 360);
    expect(find.byType(CompanySubtitle), findsOneWidget);
    expect(find.text('Rhombus Labs'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
  });

  testWidgets('a failed company load hides the header quietly', (tester) async {
    companies.failNext = const AppFailure('unknown');
    await pump(tester, 1280);
    expect(find.text('Rhombus Labs'), findsNothing);
    expect(find.text('Jobs'), findsWidgets);
  });
}
