import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/application_status.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/board/data/fake_board_repository.dart';
import 'package:project5/features/board/domain/board_filters.dart';
import 'package:project5/features/board/presentation/widgets/candidate_tile.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';

void main() {
  const jobId = FakeBoardRepository.demoJobId;
  late FakeAuthRepository auth;
  late FakeBoardRepository board;

  setUp(() {
    auth = FakeAuthRepository(latency: Duration.zero);
    board = FakeBoardRepository(latency: Duration.zero);
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1280, 1400);
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
        overrides: fakeRepositoryOverrides(
          auth: auth,
          board: board,
          jobs: FakeJobRepository(latency: Duration.zero),
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  List<String> handles(WidgetTester tester) => [
    for (final tile in tester.widgetList<CandidateTile>(
      find.byType(CandidateTile),
    ))
      tile.tile.handle,
  ];

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('BoardFilters', () {
    test('round-trips the query string', () {
      const filters = BoardFilters(
        skills: {'Flutter', 'Dart'},
        minYears: 2,
        minScore: 70,
      );
      expect(filters.toQuery(), {
        'skills': 'Dart,Flutter',
        'years': '2',
        'score': '70',
      });
      expect(BoardFilters.fromQuery(filters.toQuery()), filters);
      expect(
        BoardFilters.fromQuery({'score': '500', 'years': 'x'}).isEmpty,
        isTrue,
      );
    });

    test('has-skill means "not a gap", and order is kept', () {
      final tiles = FakeBoardRepository.demoTiles;
      final kept = const BoardFilters(skills: {'Flutter'}).apply(tiles);
      expect(kept.map((t) => t.handle), ['◆ 4F2A', '◆ 9C1B']);
      final years = const BoardFilters(minYears: 2).apply(tiles);
      expect(years.map((t) => t.handle), ['◆ 4F2A', '◆ 9C1B']);
    });
  });

  testWidgets('skill chips filter without reordering and sync to the URL', (
    tester,
  ) async {
    final router = await pump(tester, Routes.boardFor(jobId));
    expect(handles(tester), ['◆ 4F2A', '◆ 9C1B', '◆ 2D7E']);

    await tap(tester, find.widgetWithText(FilterChip, 'Firebase'));
    expect(handles(tester), ['◆ 4F2A']);
    expect(find.text('1 of 3 applicants'), findsOneWidget);
    expect(router.state.uri.queryParameters['skills'], 'Firebase');

    await tap(tester, find.text('Clear filters'));
    expect(handles(tester), hasLength(3));
    expect(router.state.uri.queryParameters, isEmpty);
  });

  testWidgets('min score is applied by the server', (tester) async {
    final router = await pump(tester, Routes.boardFor(jobId));
    await tap(tester, find.byTooltip('Minimum match score'));
    await tap(tester, find.text('70+ match'));
    expect(handles(tester), ['◆ 4F2A', '◆ 9C1B']);
    expect(router.state.uri.queryParameters['score'], '70');
  });

  testWidgets('filters in the URL survive a reload', (tester) async {
    await pump(tester, '${Routes.boardFor(jobId)}?years=2&score=80');
    expect(handles(tester), ['◆ 4F2A']);
    expect(find.text('2+ years'), findsOneWidget);
    expect(find.text('80+ match'), findsOneWidget);
  });

  testWidgets('no matches offers Clear filters', (tester) async {
    await pump(tester, '${Routes.boardFor(jobId)}?years=10');
    expect(find.text('No applicants match these filters'), findsOneWidget);
    await tap(tester, find.widgetWithText(OutlinedButton, 'Clear filters'));
    expect(handles(tester), hasLength(3));
  });

  group('shortcuts', () {
    bool focused(WidgetTester tester, String handle) => tester
        .widget<CandidateTile>(
          find.byWidgetPredicate(
            (w) => w is CandidateTile && w.tile.handle == handle,
          ),
        )
        .focusNode!
        .hasFocus;

    testWidgets('J/K move focus; R rejects; A advances; Enter opens', (
      tester,
    ) async {
      final router = await pump(tester, Routes.boardFor(jobId));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(focused(tester, '◆ 4F2A'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.pumpAndSettle();
      expect(focused(tester, '◆ 9C1B'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(focused(tester, '◆ 4F2A'), isTrue);

      // R rejects the focused tile and keeps focus in the grid.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(handles(tester), ['◆ 9C1B', '◆ 2D7E']);
      expect(find.text('Not a fit · ◆ 4F2A'), findsOneWidget);
      expect(focused(tester, '◆ 9C1B'), isTrue);

      // A asks for a note, then advances.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();
      expect(find.text('Advance ◆ 9C1B?'), findsOneWidget);
      // Typing "r" in the note must not reject anything.
      await tester.enterText(find.byType(TextField), 'r');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tap(tester, find.widgetWithText(FilledButton, 'Advance'));
      expect(handles(tester), ['◆ 9C1B', '◆ 2D7E']);
      expect(
        (await board.getBoard(jobId)).first.status,
        ApplicationStatus.interviewRequested,
      );

      // Enter opens the focused tile.
      _nodeOf(tester, '◆ 2D7E').requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        router.state.uri.path,
        Routes.candidateDetailFor(
          jobId,
          FakeBoardRepository.demoTiles[2].applicationId,
        ),
      );
    });

    testWidgets('? shows the shortcut help', (tester) async {
      await pump(tester, Routes.boardFor(jobId));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsWidgets);
      expect(find.text('Next applicant'), findsOneWidget);
    });

    testWidgets('a refused keyboard reject puts the tile back', (tester) async {
      await pump(tester, Routes.boardFor(jobId));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      board.failNext = const AppFailure('invalid_transition');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pumpAndSettle();
      expect(handles(tester).first, '◆ 4F2A');
    });
  });
}

FocusNode _nodeOf(WidgetTester tester, String handle) => tester
    .widget<CandidateTile>(
      find.byWidgetPredicate(
        (w) => w is CandidateTile && w.tile.handle == handle,
      ),
    )
    .focusNode!;
