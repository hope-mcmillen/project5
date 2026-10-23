import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/windows_golden.dart';

import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/features/onboarding/data/fake_resume_repository.dart';
import 'package:project5/features/onboarding/data/resume_repository.dart';

import '../support/fake_scope.dart';

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Inter', 'assets/fonts/Inter.ttf'),
      ('Space Grotesk', 'assets/fonts/SpaceGrotesk.ttf'),
      ('Poppins', 'assets/fonts/Poppins-Black.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  for (final width in [360.0, 1280.0]) {
    testWidgets('resume progress is readable with reduced motion at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final repo = FakeResumeRepository(latency: Duration.zero);
      addTearDown(repo.dispose);
      final resume = await repo.upload(
        filename: 'resume.pdf',
        bytes: Uint8List.fromList('%PDF-1.7'.codeUnits),
      );
      repo.setStatus(resume.id, ResumeStatus.extracting);
      final session = DevSession()
        ..signIn(AppRole.candidate)
        ..completeCandidateOnboarding();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        fakeScope(
          ResuRhombusApp(session: session),
          overrides: [resumeRepositoryProvider.overrideWithValue(repo)],
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go(Routes.parseProgress(resume.id));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectWindowsGolden(
        find.byType(MaterialApp),
        'goldens/progress_${width.toInt()}.png',
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      repo.setStatus(
        resume.id,
        ResumeStatus.failed,
        failureReason: 'unreadable_scan',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add skills manually'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
