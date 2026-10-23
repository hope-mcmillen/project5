import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/windows_golden.dart';

import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/models/app_role.dart';
import 'package:project5/core/models/application_status.dart';
import 'package:project5/ui/components/score_badge.dart';
import 'package:project5/ui/components/status_chip.dart';
import 'package:project5/ui/components/company_badge.dart';
import 'package:project5/ui/components/shimmer_shape.dart';
import 'package:project5/ui/components/empty_state.dart';
import 'package:project5/ui/theme/rr_theme.dart';
import 'package:project5/ui/theme/rr_tokens.dart';

import '../support/fake_scope.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'candidate review, preferences and deck at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final session = DevSession()
          ..signIn(AppRole.candidate)
          ..completeCandidateOnboarding();
        addTearDown(session.dispose);
        await tester.pumpWidget(fakeScope(ResuRhombusApp(session: session)));
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        for (final (name, route) in [
          ('review', Routes.candidateReview),
          ('preferences', Routes.candidatePreferences),
          ('deck', Routes.deck),
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectWindowsGolden(
            find.byType(MaterialApp),
            'goldens/${name}_${width.toInt()}.png',
          );
        }
      },
    );
    testWidgets('both role flows fit large text at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final role in AppRole.values) {
        final session = DevSession()..signIn(role);
        if (role == AppRole.candidate) {
          session.completeCandidateOnboarding();
        } else {
          session.completeCompanyOnboarding();
        }
        addTearDown(session.dispose);
        await tester.pumpWidget(
          fakeScope(ResuRhombusApp(key: UniqueKey(), session: session)),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        for (final route
            in role == AppRole.candidate
                ? [
                    Routes.candidateProfile,
                    Routes.profileResume,
                    Routes.pipeline,
                  ]
                : [Routes.jobs, Routes.interviews, Routes.companySettings]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$role at $route');
        }
      }
    });
  }
  setUpAll(() async {
    for (final (family, file) in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
      ('Poppins', 'Poppins-Black'),
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$file.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'score and status components have readable labels and stable visuals',
    (tester) async {
      tester.view.physicalSize = const Size(960, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRRTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('components'),
              child: Container(
                color: RRColors.canvas,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Wrap(
                      spacing: 32,
                      children: [
                        ScoreBadge(score: 92, size: ScoreBadgeSize.small),
                        ScoreBadge(score: 76),
                        ScoreBadge(score: 58),
                        ScoreBadge(score: 42),
                        ScoreBadge(score: 87, size: ScoreBadgeSize.large),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in ApplicationStatus.values)
                          StatusChip(status: status),
                        const CompanyBadge(verified: true),
                        const CompanyBadge(verified: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Match score 92 percent, Strong'),
        findsOneWidget,
      );
      expect(find.text('Not selected'), findsOneWidget);
      await expectWindowsGolden(
        find.byKey(const Key('components')),
        'goldens/score_and_status.png',
      );
    },
  );

  for (final width in [360.0, 1280.0]) {
    testWidgets('branded Resume page at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = DevSession()
        ..signIn(AppRole.candidate)
        ..completeCandidateOnboarding();
      addTearDown(session.dispose);
      await tester.pumpWidget(fakeScope(ResuRhombusApp(session: session)));
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go(Routes.profileResume);
      await tester.pumpAndSettle();
      expect(find.text('Upload resume'), findsOneWidget);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      expect(find.textContaining('Tasks:'), findsNothing);
      expect(tester.takeException(), isNull);
      await expectWindowsGolden(
        find.byType(MaterialApp),
        'goldens/resume_${width.toInt()}.png',
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced-motion loading and empty states work without timers', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildRRTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const ShimmerShape(),
                  EmptyState(
                    title: 'No applications yet',
                    message: 'Explore a role to get started.',
                    actionLabel: 'Explore roles',
                    onAction: () => actions++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    await tester.tap(find.text('Explore roles'));
    expect(actions, 1);
    expect(tester.takeException(), isNull);
  });
}
