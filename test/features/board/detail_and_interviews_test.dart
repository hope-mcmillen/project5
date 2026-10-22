import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/app/url_opener.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/application_status.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/board/data/fake_board_repository.dart';
import 'package:project5/features/board/presentation/widgets/match_radar.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';

void main() {
  const jobId = FakeBoardRepository.demoJobId;
  final first = FakeBoardRepository.demoTiles.first;
  final second = FakeBoardRepository.demoTiles[1];
  late FakeAuthRepository auth;
  late FakeBoardRepository board;
  late List<Uri> opened;

  setUp(() async {
    auth = FakeAuthRepository(latency: Duration.zero);
    await auth.signInWithEmail(
      email: FakeAuthRepository.demoRecruiterEmail,
      password: FakeAuthRepository.demoPassword,
    );
    board = FakeBoardRepository(latency: Duration.zero);
    opened = [];
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    double width = 400,
  }) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(
      session: () => const RouteSession.recruiter(),
      initialLocation: location,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        retry: noAutomaticRetry,
        overrides: [
          ...fakeRepositoryOverrides(
            auth: auth,
            board: board,
            jobs: FakeJobRepository(latency: Duration.zero),
          ),
          urlOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
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

  group('candidate detail', () {
    testWidgets('opening marks Under Review and stays blind', (tester) async {
      await pump(tester, Routes.candidateDetailFor(jobId, first.applicationId));
      expect(
        (await board.getBoard(jobId)).first.status,
        ApplicationStatus.underReview,
      );
      expect(find.text('◆ 4F2A'), findsWidgets);
      expect(find.text('Under review'), findsOneWidget);
      expect(find.byType(MatchRadar), findsOneWidget);
      expect(find.text('Candidate'), findsOneWidget); // radar legend
      expect(find.text('Kubernetes (preferred)'), findsOneWidget);
      expect(
        find.text('Built production features with Flutter.'),
        findsOneWidget,
      );
      expect(find.textContaining('@'), findsNothing);
      expect(find.text('Resume'), findsNothing);
    });

    testWidgets('advancing reveals name, email and resume', (tester) async {
      await pump(tester, Routes.candidateDetailFor(jobId, first.applicationId));
      await tap(tester, find.widgetWithText(FilledButton, 'Advance'));
      await tap(tester, find.widgetWithText(FilledButton, 'Advance').last);

      expect(find.text('Candidate 4F2A'), findsWidgets);
      await tap(tester, find.text('candidate.4f2a@example.test'));
      expect(opened.last, Uri.parse('mailto:candidate.4f2a@example.test'));
      await tap(tester, find.text('Resume'));
      expect(opened.last.path, endsWith('${first.applicationId}.pdf'));
    });

    testWidgets('Not a fit goes back to the board with Undo', (tester) async {
      final router = await pump(tester, Routes.boardFor(jobId));
      await tester.longPress(find.text('◆ 9C1B'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Not a fit'));

      expect(router.state.uri.path, Routes.boardFor(jobId));
      expect(find.text('◆ 9C1B'), findsNothing);
      expect(find.text('Not a fit · ◆ 9C1B'), findsOneWidget);
      await tap(tester, find.text('Undo'));
      expect(find.text('◆ 9C1B'), findsOneWidget);
      expect(
        (await board.getBoard(jobId)).map((t) => t.applicationId),
        contains(second.applicationId),
      );
    });

    testWidgets('wide layout puts the radar beside the breakdown', (
      tester,
    ) async {
      await pump(
        tester,
        Routes.candidateDetailFor(jobId, first.applicationId),
        width: 1280,
      );
      final radar = tester.getTopLeft(find.byType(MatchRadar));
      final requirements = tester.getTopLeft(find.text('Requirements'));
      expect(requirements.dx, greaterThan(radar.dx));
    });
  });

  group('interview list', () {
    testWidgets('shows advanced candidates with Email and Resume', (
      tester,
    ) async {
      await board.advance(first.applicationId);
      await pump(tester, Routes.interviews);
      expect(find.text('Candidate 4F2A'), findsOneWidget);
      expect(find.text('Flutter Developer'), findsWidgets);
      expect(find.text('◆ 9C1B'), findsNothing);

      await tap(tester, find.text('Email'));
      expect(opened.last.scheme, 'mailto');
      await tap(tester, find.text('Resume'));
      expect(opened.last.scheme, 'https');
    });

    testWidgets('manual-only profiles explain the missing resume', (
      tester,
    ) async {
      await board.advance(first.applicationId);
      board.manualProfiles.add(first.applicationId);
      await pump(tester, Routes.interviews);
      await tap(tester, find.text('Resume'));
      expect(
        find.text('No resume is available for this candidate.'),
        findsOneWidget,
      );
      expect(opened, isEmpty);
    });

    testWidgets('filters by job and has an empty state', (tester) async {
      await pump(tester, Routes.interviews);
      expect(find.text('No interviews yet'), findsOneWidget);

      await board.advance(first.applicationId);
      await pump(tester, Routes.interviews, width: 1280);
      expect(find.byType(DataTable), findsOneWidget);
      await tap(tester, find.text('All jobs'));
      await tap(tester, find.text('Flutter Developer').last);
      expect(find.text('Candidate 4F2A'), findsOneWidget);
    });

    testWidgets('errors offer Retry', (tester) async {
      board.failNext = const AppFailure('not_recruiter');
      await pump(tester, Routes.interviews);
      expect(find.text('Only recruiter accounts can do that.'), findsOneWidget);
      await tap(tester, find.text('Retry'));
      expect(find.text('No interviews yet'), findsOneWidget);
    });
  });
}
