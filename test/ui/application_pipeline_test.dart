import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/app.dart';
import 'package:project5/app/dev_session.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/app/url_opener.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/pipeline/data/application_repository.dart';
import 'package:project5/features/pipeline/data/fake_application_repository.dart';
import 'package:project5/features/pipeline/domain/interview_contact.dart';
import 'package:project5/ui/components/status_chip.dart';

import '../support/fake_scope.dart';
import '../support/windows_golden.dart';

class Applications extends FakeApplicationRepository {
  Applications({super.applications}) : super(latency: Duration.zero);
  int contactCalls = 0;
  bool failContact = false;
  Completer<InterviewContact>? pendingContact;
  @override
  Future<InterviewContact> contact(String id) async {
    contactCalls++;
    if (failContact) throw const AppFailure('offline');
    return pendingContact == null
        ? await super.contact(id)
        : await pendingContact!.future;
  }
}

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

  Future<GoRouter> mount(
    WidgetTester tester,
    Applications repo, {
    String? id,
    Future<bool> Function(Uri)? opener,
  }) async {
    final session = DevSession()
      ..signIn(AppRole.candidate)
      ..completeCandidateOnboarding();
    addTearDown(session.dispose);
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      fakeScope(
        ResuRhombusApp(session: session),
        overrides: [
          applicationRepositoryProvider.overrideWithValue(repo),
          if (opener != null) urlOpenerProvider.overrideWithValue(opener),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go(id == null ? Routes.pipeline : Routes.applicationDetailFor(id));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'live interview status shows contact and timeline; copy and email work; terminal status removes contact',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final app = CandidateFixtures.applications.first;
      final repo = Applications(applications: [app]);
      Uri? opened;
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await mount(
        tester,
        repo,
        id: app.id,
        opener: (uri) async {
          opened = uri;
          return true;
        },
      );
      expect(repo.contactCalls, 0);
      repo.setStatus(app.id, ApplicationStatus.interviewRequested);
      await tester.pumpAndSettle();
      expect(repo.contactCalls, 1);
      expect(find.text('Interview contact'), findsOneWidget);
      expect(
        find.text('Please email a few times that work for an interview.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('Application status: Interview requested'),
        ),
        findsWidgets,
      );
      await tester.ensureVisible(find.text('Copy email'));
      await tester.tap(find.text('Copy email'));
      await tester.pumpAndSettle();
      expect(copied, 'recruiter@rhombus.example.test');
      await tester.tap(find.text('Email recruiter'));
      await tester.pumpAndSettle();
      expect(opened?.scheme, 'mailto');
      expect(opened?.path, copied);
      repo.setStatus(app.id, ApplicationStatus.notSelected);
      await tester.pumpAndSettle();
      expect(find.text('Interview contact'), findsNothing);
      expect(find.text('Withdraw application'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'withdrawal requires confirmation; failure retains the application; successful withdrawal updates the timeline',
    (tester) async {
      final app = CandidateFixtures.applications.first;
      final repo = Applications(applications: [app]);
      await mount(tester, repo, id: app.id);
      await tester.tap(find.text('Withdraw application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep application'));
      await tester.pumpAndSettle();
      expect((await repo.get(app.id)).status, ApplicationStatus.applied);
      repo.failNext = const AppFailure('offline', 'Could not withdraw.');
      await tester.tap(find.text('Withdraw application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      expect(find.text('Could not withdraw.'), findsOneWidget);
      expect((await repo.get(app.id)).status, ApplicationStatus.applied);
      await tester.tap(find.text('Withdraw application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();
      expect((await repo.get(app.id)).status, ApplicationStatus.withdrawn);
      expect(
        tester
            .widgetList<StatusChip>(find.byType(StatusChip))
            .map((w) => w.status),
        contains(ApplicationStatus.withdrawn),
      );
      expect(find.text('Withdraw application'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty/error states recover, and 21-day hints only apply before review',
    (tester) async {
      final app = Application.fromJson({
        ...CandidateFixtures.applications.first.toJson(),
        'created_at': DateTime.now()
            .subtract(const Duration(days: 22))
            .toUtc()
            .toIso8601String(),
      });
      final repo = Applications(applications: [app])
        ..failNext = const AppFailure('offline');
      await mount(tester, repo);
      expect(find.text('Retry applications'), findsOneWidget);
      await tester.tap(find.text('Retry applications'));
      await tester.pumpAndSettle();
      expect(find.text('No response yet'), findsOneWidget);
      repo.setStatus(app.id, ApplicationStatus.underReview);
      await tester.pumpAndSettle();
      expect(find.text('No response yet'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester, Applications(applications: []));
      expect(find.text('No applications yet'), findsOneWidget);
      expect(find.text('Explore jobs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late contact responses never reappear after a status change', (
    tester,
  ) async {
    final app = CandidateFixtures.applications.first;
    final repo = Applications(applications: [app]);
    await mount(tester, repo, id: app.id);
    repo.pendingContact = Completer<InterviewContact>();
    repo.setStatus(app.id, ApplicationStatus.interviewRequested);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.contactCalls, 1);
    repo.setStatus(app.id, ApplicationStatus.withdrawn);
    await tester.pumpAndSettle();
    repo.pendingContact!.complete(
      const InterviewContact(name: 'Late contact', email: 'late@example.test'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Late contact'), findsNothing);
    expect(find.text('Email recruiter'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('interview detail is readable at $width and large text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final localDate = DateTime(2026, 10, 22, 14).toUtc().toIso8601String();
      final app = Application.fromJson({
        ...CandidateFixtures.applications[2].toJson(),
        'created_at': localDate,
        'updated_at': localDate,
      });
      final repo = Applications(applications: [app])..failContact = true;
      await mount(tester, repo, id: app.id, opener: (_) async => false);
      expect(find.text('Retry contact details'), findsOneWidget);
      repo.failContact = false;
      await tester.tap(find.text('Retry contact details'));
      await tester.pumpAndSettle();
      await expectWindowsGolden(
        find.byType(MaterialApp),
        'goldens/interview_application_${width.toInt()}.png',
      );
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Email recruiter'));
      await tester.tap(find.text('Email recruiter'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open an email app. Copy the address instead.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
