import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';

/// About 18k characters: well past the field's visible height, under the cap.
final _longDescription = List.generate(
  300,
  (i) => 'Line ${i + 1}: build Flutter features with Dart and REST APIs.',
).join('\n');

void main() {
  final cases = [
    (
      name: 'laptop 1280×720',
      size: const Size(1280, 720),
      scale: 1.0,
      keyboard: 0.0,
    ),
    (
      name: 'phone 390×700',
      size: const Size(390, 700),
      scale: 1.0,
      keyboard: 0.0,
    ),
    // Android phone with the on-screen keyboard open.
    (
      name: 'phone 360×800, keyboard up',
      size: const Size(360, 800),
      scale: 1.0,
      keyboard: 320.0,
    ),
    // Android phone with large text (accessibility setting).
    (
      name: 'phone 360×800, 2× text',
      size: const Size(360, 800),
      scale: 2.0,
      keyboard: 0.0,
    ),
  ];
  for (final c in cases) {
    testWidgets('a very long description keeps Read description visible and '
        'scrolls inside the box (${c.name})', (tester) async {
      tester.view.physicalSize = c.size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: c.keyboard);
      tester.platformDispatcher.textScaleFactorTestValue = c.scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = FakeAuthRepository(latency: Duration.zero);
      addTearDown(auth.dispose);
      final router = buildRouter(
        session: () => const RouteSession.recruiter(),
        initialLocation: Routes.newJob,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          retry: noAutomaticRetry,
          overrides: fakeRepositoryOverrides(
            auth: auth,
            jobs: FakeJobRepository(latency: Duration.zero),
          ),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // With large text on a narrow phone the heading can fill the screen;
      // the page scrolls to the box while the buttons stay pinned.
      await tester.scrollUntilVisible(
        find.byType(TextField),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(find.byType(TextField), _longDescription);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // no overflow

      // The button is on screen, above the keyboard, and enabled without
      // scrolling the page.
      final button = find.widgetWithText(FilledButton, 'Read description');
      final visible =
          Offset.zero & Size(c.size.width, c.size.height - c.keyboard);
      expect(visible.contains(tester.getRect(button).topLeft), isTrue);
      expect(
        visible.contains(
          tester.getRect(button).bottomRight - const Offset(1, 1),
        ),
        isTrue,
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(button.hitTestable(), findsOneWidget);

      // The mouse wheel over the box scrolls the description itself. After
      // a paste the caret (and view) is at the end, so scroll back up.
      final inner = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(Scrollable),
        ),
      );
      final start = inner.position.pixels;
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(find.byType(TextField))),
      );
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -400)));
      await tester.pumpAndSettle();
      expect(start, greaterThan(0));
      expect(inner.position.pixels, lessThan(start));
      expect(tester.takeException(), isNull);
    });
  }
}
