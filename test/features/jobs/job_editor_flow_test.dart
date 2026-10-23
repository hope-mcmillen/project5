import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/job_status.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';
import 'package:project5/features/jobs/domain/job.dart';

const _description = '''Mobile Engineer (Flutter)
We need 2+ years building production apps with Flutter and Dart.
Experience consuming REST APIs. Firebase Auth is a plus.''';

void main() {
  late FakeAuthRepository auth;
  late FakeJobRepository jobs;

  setUp(() {
    auth = FakeAuthRepository(latency: Duration.zero);
    jobs = FakeJobRepository(latency: Duration.zero);
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(
      session: () => const RouteSession.recruiter(),
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: fakeRepositoryOverrides(auth: auth, jobs: jobs),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('paste → requirements → details → publish', (tester) async {
    final router = await pump(tester, Routes.newJob);
    final read = find.widgetWithText(FilledButton, 'Read description');
    expect(tester.widget<FilledButton>(read).onPressed, isNull);

    await tester.enterText(find.byType(TextField), _description);
    await tester.pump();
    expect(find.text('${_description.length} / 20,000'), findsOneWidget);
    await tap(tester, read);

    // parse-job finished: the editor shows what it found.
    expect(router.state.uri.path, endsWith('/requirements'));
    final jobId = router.state.uri.pathSegments[2];
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Dart'), findsOneWidget);
    expect(find.text('REST APIs'), findsOneWidget);
    expect(find.text('3/8 required'), findsOneWidget);
    expect(find.text('4/15 total'), findsOneWidget);
    expect(find.text('Auth'), findsOneWidget); // unmapped

    // Map the unmapped "Auth" to a real skill.
    await tap(tester, find.text('Map to…'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Kotlin',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tap(tester, find.widgetWithText(ListTile, 'Kotlin'));
    expect(find.text('5/15 total'), findsOneWidget);

    // Make Flutter heavier and require a year (0.5 per step).
    await tap(tester, find.byTooltip('More years for Flutter'));
    await tap(tester, find.byTooltip('More years for Flutter'));
    await tap(tester, find.byTooltip('Weight 3').first);

    await tap(tester, find.text('Save and continue'));
    expect(router.state.uri.path, Routes.jobDetailsFor(jobId));
    final saved = await jobs.requirements(jobId);
    final flutter = saved.firstWhere((r) => r.skill.name == 'Flutter');
    expect(flutter.minYears, 1);
    expect(flutter.weight, 3);
    expect(saved.map((r) => r.skill.name), contains('Kotlin'));

    // Details are pre-filled from the parse.
    expect(find.text('Mobile Engineer (Flutter)'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Location'),
      'Baton Rouge, LA',
    );
    await tap(tester, find.text('Hybrid'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Min'), '120000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Max'), '90000');
    await tap(tester, find.text('Save and publish'));
    expect(find.text('Max must be at least the min.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Max'), '140000');
    await tap(tester, find.text('Save and publish'));
    expect(router.state.uri.path, Routes.jobs);
    final job = await jobs.get(jobId);
    expect(job.status, JobStatus.open);
    expect(job.location, 'Baton Rouge, LA');
    expect(job.remote, RemoteType.hybrid);
    expect(job.salaryMax, 140000);
  });

  testWidgets('a failed parse offers retry or manual entry', (tester) async {
    jobs.failParseWith = 'budget_exceeded';
    final router = await pump(tester, Routes.newJob);
    await tester.enterText(find.byType(TextField), _description);
    await tap(tester, find.text('Read description'));
    expect(find.textContaining('AI budget'), findsOneWidget);

    await tap(tester, find.text('Try again'));
    expect(router.state.uri.path, endsWith('/requirements'));
  });

  testWidgets('wide layout shows the description beside the table and '
      'highlights evidence', (tester) async {
    final job = FakeJobRepository.demoJobs.first;
    await pump(tester, Routes.jobRequirementsFor(job.id), width: 1280);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);

    await tap(tester, find.text('Flutter').last);
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final highlighted = (text.textSpan!.children ?? const [])
        .cast<TextSpan>()
        .where((s) => s.style?.backgroundColor != null)
        .map((s) => s.text);
    expect(highlighted, [
      'We need 2+ years building production apps with Flutter.',
    ]);
  });

  testWidgets('published jobs save in place', (tester) async {
    final job = FakeJobRepository.demoJobs.first;
    final router = await pump(tester, Routes.jobRequirementsFor(job.id));
    await tap(tester, find.byTooltip('Remove Firebase'));
    await tap(tester, find.text('Save requirements'));
    expect(router.state.uri.path, Routes.jobRequirementsFor(job.id));
    expect(find.textContaining('Requirements saved'), findsOneWidget);
    expect((await jobs.requirements(job.id)).length, 3);
  });

  testWidgets('details screen pauses an open job', (tester) async {
    final job = FakeJobRepository.demoJobs.first;
    await pump(tester, Routes.jobDetailsFor(job.id));
    expect(find.text('Flutter Developer'), findsOneWidget);
    await tap(tester, find.text('Pause'));
    expect((await jobs.get(job.id)).status, JobStatus.paused);
  });

  testWidgets('an abandoned draft can be deleted from requirements', (
    tester,
  ) async {
    final id = await jobs.createDraft(_description);
    await jobs.parse(id);
    final router = await pump(tester, Routes.jobRequirementsFor(id));
    await tap(tester, find.byTooltip('Delete draft'));
    expect(find.text('Delete "Mobile Engineer (Flutter)"?'), findsOneWidget);
    await tap(tester, find.widgetWithText(FilledButton, 'Delete draft'));
    expect(router.state.uri.path, Routes.jobs);
    await expectLater(jobs.get(id), throwsA(isA<AppFailure>()));
  });

  testWidgets('published jobs offer no delete', (tester) async {
    final job = FakeJobRepository.demoJobs.first;
    await pump(tester, Routes.jobRequirementsFor(job.id));
    expect(find.byTooltip('Delete draft'), findsNothing);
  });
}
