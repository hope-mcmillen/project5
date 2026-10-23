import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/job_status.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';
import 'package:project5/features/jobs/presentation/jobs_list_screen.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeJobRepository jobs;

  setUp(() async {
    auth = FakeAuthRepository(latency: Duration.zero);
    jobs = FakeJobRepository(latency: Duration.zero);
    await auth.signInWithEmail(
      email: FakeAuthRepository.demoRecruiterEmail,
      password: FakeAuthRepository.demoPassword,
    );
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget stub(String name) => Scaffold(body: Text('stub:$name'));
    final router = GoRouter(
      initialLocation: Routes.jobs,
      routes: [
        GoRoute(
          path: Routes.jobs,
          builder: (_, _) => const JobsListScreen(),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => stub('new')),
            GoRoute(
              path: ':id/board',
              builder: (_, s) => stub('board:${s.pathParameters['id']}'),
            ),
            GoRoute(
              path: ':id/requirements',
              builder: (_, s) => stub('requirements:${s.pathParameters['id']}'),
            ),
          ],
        ),
      ],
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

  final openJob = FakeJobRepository.demoJobs.first;
  final draftJob = FakeJobRepository.demoJobs.last;

  testWidgets('lists jobs with status and applicant counts', (tester) async {
    await pump(tester);
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('Backend Engineer'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('3 new'), findsOneWidget);
    expect(find.text('5 total'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('wide layouts use a table', (tester) async {
    await pump(tester, width: 1280);
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Flutter Developer'), findsOneWidget);
  });

  testWidgets('tapping opens the board, or requirements for drafts', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Flutter Developer'));
    await tester.pumpAndSettle();
    expect(find.text('stub:board:${openJob.id}'), findsOneWidget);
  });

  testWidgets('draft jobs open their requirements', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Backend Engineer'));
    await tester.pumpAndSettle();
    expect(find.text('stub:requirements:${draftJob.id}'), findsOneWidget);
  });

  testWidgets('pause, then close with confirmation', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Actions for Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();
    expect((await jobs.get(openJob.id)).status, JobStatus.paused);
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.byTooltip('Actions for Flutter Developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Close "Flutter Developer"?'), findsOneWidget);
    await tester.tap(find.text('Close job'));
    await tester.pumpAndSettle();
    expect((await jobs.get(openJob.id)).status, JobStatus.closed);
  });

  testWidgets('publishing an unready draft explains why', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Actions for Backend Engineer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Add a title and at least one saved requirement before publishing.',
      ),
      findsOneWidget,
    );
    expect((await jobs.get(draftJob.id)).status, JobStatus.draft);
  });

  testWidgets('only drafts offer Delete draft', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Actions for Flutter Developer'));
    await tester.pumpAndSettle();
    expect(find.text('Delete draft'), findsNothing);
  });

  testWidgets('deleting a draft asks first, then removes the row', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Actions for Backend Engineer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Backend Engineer"?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Engineer'), findsOneWidget);
    expect((await jobs.get(draftJob.id)).status, JobStatus.draft);

    await tester.tap(find.byTooltip('Actions for Backend Engineer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete draft'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Engineer'), findsNothing);
    expect(find.text('"Backend Engineer" deleted.'), findsOneWidget);
    expect(find.text('Flutter Developer'), findsOneWidget);
  });

  testWidgets('wide table offers Delete draft too', (tester) async {
    await pump(tester, width: 1280);
    await tester.tap(find.byTooltip('Actions for Backend Engineer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete draft'));
    await tester.pumpAndSettle();
    expect(find.text('Backend Engineer'), findsNothing);
  });

  testWidgets('empty state offers New job', (tester) async {
    jobs = FakeJobRepository(latency: Duration.zero, seedDemoJobs: false);
    final router = await pump(tester);
    expect(find.text('Post your first job'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'New job').last);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, Routes.newJob);
  });

  testWidgets('errors offer Retry', (tester) async {
    jobs.failNext = const AppFailure('unknown');
    await pump(tester);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Flutter Developer'), findsOneWidget);
  });
}
