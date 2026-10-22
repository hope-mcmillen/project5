import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/features/profile/data/fake_profile_repository.dart';

import '../support/fake_scope.dart';

void main() {
  testWidgets(
    'onboarding stays on preferences after failed save, then filters the deck',
    (tester) async {
      final session = DevSession()..signIn(AppRole.candidate);
      addTearDown(session.dispose);
      final repo = FakeProfileRepository(latency: Duration.zero);
      await tester.pumpWidget(
        fakeScope(
          ResuRhombusApp(session: session),
          overrides: [profileRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go(Routes.candidatePreferences);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Remote'));
      await tester.pumpAndSettle();
      repo.failNext = const AppFailure(
        'offline',
        'Could not save preferences.',
      );
      await tester.tap(find.text('Start swiping'));
      await tester.pumpAndSettle();
      expect(session.candidateOnboarded, isFalse);
      expect(router.state.uri.path, Routes.candidatePreferences);
      expect(find.text('Could not save preferences.'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Remote'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Start swiping'));
      await tester.pumpAndSettle();
      expect(session.candidateOnboarded, isTrue);
      expect(router.state.uri.path, Routes.deck);
      expect(find.text('Northline Labs'), findsOneWidget);
      expect(find.text('Pelican Path Health'), findsNothing);
    },
  );

  testWidgets(
    'review evidence, years, taxonomy search and large-text preferences work',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session = DevSession()..signIn(AppRole.candidate);
      addTearDown(session.dispose);
      await tester.pumpWidget(fakeScope(ResuRhombusApp(session: session)));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go(Routes.candidateReview);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View evidence'));
      await tester.tap(find.text('View evidence'));
      await tester.pumpAndSettle();
      expect(find.text('Evidence for Flutter'), findsOneWidget);
      expect(
        find.text('Built Flutter applications.', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Close evidence'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Increase Flutter experience'));
      await tester.tap(find.byTooltip('Increase Flutter experience'));
      await tester.pumpAndSettle();
      expect(find.text('3.5 years'), findsOneWidget);
      expect(find.text('Edited'), findsOneWidget);
      await tester.ensureVisible(find.text('Add skill'));
      await tester.tap(find.text('Add skill'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'py');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Python'));
      await tester.tap(find.widgetWithText(ListTile, 'Python'));
      await tester.pumpAndSettle();
      expect(find.text('Python'), findsOneWidget);
      await tester.tap(find.text('Confirm skills'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.candidatePreferences);
      await tester.enterText(find.byType(TextField), 'Austin, TX');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Austin, TX'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
