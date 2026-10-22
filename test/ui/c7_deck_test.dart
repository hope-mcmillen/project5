import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/windows_golden.dart';

import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/deck/data/feed_repository.dart';
import 'package:project5/features/deck/data/fake_feed_repository.dart';
import 'package:project5/features/deck/presentation/swipe_feedback.dart';
import 'package:project5/features/deck/domain/swipe_receipt.dart';
import 'package:project5/ui/theme/rr_theme.dart';
import 'package:project5/ui/components/deck_action_bar.dart';
import 'package:project5/features/profile/data/profile_repository.dart';
import 'package:project5/features/profile/data/fake_profile_repository.dart';

import '../support/fake_scope.dart';

void main() {
  setUpAll(() async {
    for (final (family, file) in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('feedback countdown expires and reasons dismiss automatically', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = DateTime.now();
    final receipt = SwipeReceipt(
      swipeId: 'test',
      job: CandidateFixtures.job,
      direction: SwipeDirection.left,
      serverNow: now,
      receivedAt: now,
      committedAt: now.add(const Duration(seconds: 5)),
    );
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildRRTheme(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                PassReasonChips(receipt: receipt, onReason: (_) {}),
                UndoToast(receipt: receipt, now: () => now, onUndo: () {}),
                DeckActionBar(onPass: () {}, onDetails: () {}, onApply: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Undo (5s)'), findsOneWidget);
    await expectWindowsGolden(
      find.byType(MaterialApp),
      'goldens/deck_feedback_360.png',
    );
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Undo (3s)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Why pass? Optional'), findsNothing);
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Undo ('), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pass reasons leave next card interactive; undo restores the passed card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = DevSession()
        ..signIn(AppRole.candidate)
        ..completeCandidateOnboarding();
      addTearDown(session.dispose);
      final feed = FakeFeedRepository(latency: Duration.zero);
      await tester.pumpWidget(
        fakeScope(
          ResuRhombusApp(session: session),
          overrides: [feedRepositoryProvider.overrideWithValue(feed)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pass'));
      await tester.pumpAndSettle();
      expect(find.byType(PassReasonChips), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Salary'));
      await tester.pumpAndSettle();
      expect(feed.passReasons.values, [PassReason.salary]);
      expect(find.byType(PassReasonChips), findsNothing);
      await tester.tap(find.textContaining('Undo ('));
      await tester.pumpAndSettle();
      expect(feed.decisions, isEmpty);
      expect(find.text('Pelican Path Health'), findsOneWidget);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pass'));
      await tester.tap(find.text('Pass'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'last card can be undone; empty state saves stretch without dropping filters',
    (tester) async {
      final session = DevSession()
        ..signIn(AppRole.candidate)
        ..completeCandidateOnboarding();
      addTearDown(session.dispose);
      final profile = FakeProfileRepository(latency: Duration.zero);
      await profile.savePreferences(
        Preferences(locations: ['Baton Rouge, LA']),
      );
      final feed = FakeFeedRepository(
        latency: Duration.zero,
        cards: [CandidateFixtures.deck.last],
        preferences: profile.preferences,
      );
      await tester.pumpWidget(
        fakeScope(
          ResuRhombusApp(session: session),
          overrides: [
            profileRepositoryProvider.overrideWithValue(profile),
            feedRepositoryProvider.overrideWithValue(feed),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your deck is all squared away'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect((await profile.preferences()).locations, ['Baton Rouge, LA']);
      expect((await profile.preferences()).includeStretch, isTrue);
      await tester.tap(find.text('Pass'));
      await tester.pumpAndSettle();
      expect(find.text('Your deck is all squared away'), findsOneWidget);
      await tester.tap(find.textContaining('Undo ('));
      await tester.pumpAndSettle();
      expect(find.text('Software Engineering Intern'), findsOneWidget);
      expect(find.text('Pass'), findsOneWidget);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      await tester.tap(find.text('Pass'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Update resume'));
      await tester.tap(find.text('Update resume'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, Routes.profileResume);
      expect(tester.takeException(), isNull);
    },
  );
}
