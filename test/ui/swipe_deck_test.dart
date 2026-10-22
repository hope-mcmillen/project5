import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/windows_golden.dart';

import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/ui/components/swipe_deck.dart';
import 'package:project5/ui/components/job_card_view.dart';
import 'package:project5/ui/theme/rr_theme.dart';

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

  Future<void> mount(
    WidgetTester tester,
    GlobalKey<SwipeDeckState> key,
    Future<bool> Function(SwipeDirection) commit, {
    bool reduced = false,
    VoidCallback? onDetails,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRRTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            disableAnimations: reduced,
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 600,
                child: SwipeDeck(
                  key: key,
                  cards: CandidateFixtures.deck,
                  onCommit: commit,
                  onDetails: (_) => onDetails?.call(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'short drag settles; threshold right and left swipes commit once',
    (tester) async {
      final decisions = <SwipeDirection>[];
      final key = GlobalKey<SwipeDeckState>();
      var details = 0;
      await mount(tester, key, (direction) async {
        decisions.add(direction);
        return true;
      }, onDetails: () => details++);
      var gesture = await tester.startGesture(const Offset(200, 380));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(
        const Offset(60, 0),
        timeStamp: const Duration(seconds: 1),
      );
      await tester.pump();
      await gesture.up(timeStamp: const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(decisions, isEmpty);
      await tester.tap(find.text('View match details').last);
      await tester.pumpAndSettle();
      expect(details, 1);
      for (final dx in [180.0, -180.0]) {
        gesture = await tester.startGesture(const Offset(200, 380));
        await gesture.moveBy(Offset(dx.sign * 20, 0));
        await gesture.moveBy(
          Offset(dx, 0),
          timeStamp: const Duration(seconds: 1),
        );
        await tester.pump();
        expect(
          tester
              .widget<SwipeStamp>(find.byType(SwipeStamp).last)
              .progress
              .abs(),
          greaterThan(.5),
        );
        await gesture.up(timeStamp: const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }
      expect(decisions, [SwipeDirection.right, SwipeDirection.left]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fast fling commits and reduced-motion public action blocks duplicates',
    (tester) async {
      final key = GlobalKey<SwipeDeckState>();
      final decisions = <SwipeDirection>[];
      final result = Completer<bool>();
      await mount(tester, key, (direction) {
        decisions.add(direction);
        return result.future;
      }, reduced: true);
      await tester.flingFrom(const Offset(170, 380), const Offset(90, 0), 1500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(decisions, [SwipeDirection.right]);
      await key.currentState!.commit(SwipeDirection.left);
      expect(decisions, hasLength(1));
      result.complete(false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwipeStamp>(find.byType(SwipeStamp).last).progress,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('public button action and deck visuals', (tester) async {
    final key = GlobalKey<SwipeDeckState>();
    final decisions = <SwipeDirection>[];
    await mount(tester, key, (direction) async {
      decisions.add(direction);
      return true;
    });
    await expectWindowsGolden(
      find.byType(Scaffold),
      'goldens/swipe_deck_400.png',
    );
    final action = key.currentState!.commit(SwipeDirection.left);
    await tester.pumpAndSettle();
    await action;
    expect(decisions, [SwipeDirection.left]);
  });
}
