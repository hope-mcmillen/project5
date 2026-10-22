import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_scope.dart';

void main() {
  testWidgets('sidebar reaches existing pages and keeps their actions', (
    tester,
  ) async {
    final session = DevSession()
      ..signIn(AppRole.candidate)
      ..completeCandidateOnboarding();
    addTearDown(session.dispose);
    await tester.pumpWidget(fakeScope(ResuRhombusApp(session: session)));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Your deck').first));

    Future<void> select(String label, String route) async {
      await tester.tap(find.byTooltip('Open navigation menu').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, label));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, route);
      expect(find.byType(Drawer).hitTestable(), findsNothing);
    }

    await select('Resume', Routes.profileResume);
    expect(find.text('Upload resume'), findsOneWidget);
    expect(find.byType(BackButton).hitTestable(), findsNothing);
    final resumeAppBar = tester.widget<AppBar>(
      find.byType(AppBar).hitTestable(),
    );
    expect(resumeAppBar.leading, isA<IconButton>());
    expect(
      (resumeAppBar.leading! as IconButton).tooltip,
      'Open navigation menu',
    );
    await select('Profile', Routes.candidateProfile);
    expect(find.text('Edit preferences'), findsOneWidget);
    expect(find.text('Update resume'), findsOneWidget);
    await tester.tap(find.text('Edit preferences'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.profilePreferences);
    expect(find.byType(BackButton).hitTestable(), findsOneWidget);
    await select('Profile', Routes.candidateProfile);
    await select('Applications', Routes.pipeline);
    expect(find.text('View application'), findsWidgets);
    await tester.tap(find.text('View application').first);
    await tester.pumpAndSettle();
    expect(
      router.state.uri.path,
      Routes.applicationDetailFor('50000000-0000-0000-0000-000000000001'),
    );
    await select('Job deck', Routes.deck);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar supports narrow screens and large text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = DevSession()
      ..signIn(AppRole.candidate)
      ..completeCandidateOnboarding();
    addTearDown(session.dispose);
    await tester.pumpWidget(fakeScope(ResuRhombusApp(session: session)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu').hitTestable());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Applications'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer).hitTestable(), findsNothing);
  });
}
