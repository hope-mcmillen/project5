import 'package:flutter/material.dart';
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
import 'package:project5/features/board/presentation/widgets/candidate_tile.dart';

void main() {
  const jobId = FakeBoardRepository.demoJobId;
  final first = FakeBoardRepository.demoTiles.first;
  late FakeAuthRepository auth;
  late FakeBoardRepository board;

  setUp(() {
    auth = FakeAuthRepository(latency: Duration.zero);
    board = FakeBoardRepository(latency: Duration.zero);
  });
  tearDown(() => auth.dispose());

  Future<GoRouter> pump(WidgetTester tester, {double width = 400}) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(
      session: () => const RouteSession.recruiter(),
      initialLocation: Routes.boardFor(jobId),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        retry: noAutomaticRetry,
        overrides: fakeRepositoryOverrides(auth: auth, board: board),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  List<String> handles(WidgetTester tester) => [
    for (final tile in tester.widgetList<CandidateTile>(
      find.byType(CandidateTile),
    ))
      tile.tile.handle,
  ];

  testWidgets('shows blind tiles in score order with the header', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Flutter Developer'), findsOneWidget);
    expect(find.text('3 applicants'), findsOneWidget);
    expect(find.text('Sorted by Match'), findsOneWidget);
    expect(handles(tester), ['◆ 4F2A', '◆ 9C1B', '◆ 2D7E']);
    expect(find.text('87'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('Kubernetes'), findsWidgets); // a gap
    // Nothing identifying is on a tile.
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('columns follow the width: 1 on phones, more on laptops', (
    tester,
  ) async {
    double left(int i) =>
        tester.getTopLeft(find.byType(CandidateTile).at(i)).dx;

    await pump(tester, width: 360);
    expect(left(0), left(1));

    await pump(tester, width: 1280);
    expect(left(1), greaterThan(left(0)));
    expect(left(2), greaterThan(left(1)));
  });

  testWidgets('tap toggles the triangles; reject offers Undo', (tester) async {
    await pump(tester);
    await tap(tester, find.text('◆ 4F2A'));
    await tap(tester, find.byTooltip('Not a fit: ◆ 4F2A'));
    expect(handles(tester), isNot(contains('◆ 4F2A')));
    expect(find.text('Not a fit · ◆ 4F2A'), findsOneWidget);
    final hidden = await board.getBoard(jobId);
    expect(
      hidden.map((t) => t.applicationId),
      isNot(contains(first.applicationId)),
    );

    await tap(tester, find.text('Undo'));
    expect(handles(tester).first, '◆ 4F2A');
    expect(
      (await board.getBoard(jobId)).first.applicationId,
      first.applicationId,
    );
  });

  testWidgets('advance asks for an optional note', (tester) async {
    await pump(tester);
    await tap(tester, find.text('◆ 4F2A'));
    await tap(tester, find.byTooltip('Advance ◆ 4F2A'));
    expect(find.text('Advance ◆ 4F2A?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Phone screen Monday');
    await tap(tester, find.widgetWithText(FilledButton, 'Advance'));

    expect(find.text('Interview requested'), findsOneWidget);
    expect(
      (await board.getBoard(jobId)).first.status,
      ApplicationStatus.interviewRequested,
    );
  });

  testWidgets('a refused decision rolls back', (tester) async {
    await pump(tester);
    board.failNext = const AppFailure('invalid_transition');
    await tap(tester, find.text('◆ 4F2A'));
    await tap(tester, find.byTooltip('Not a fit: ◆ 4F2A'));
    expect(handles(tester).first, '◆ 4F2A');
    expect(
      find.text('That status change isn\'t allowed right now.'),
      findsOneWidget,
    );
  });

  testWidgets('long press opens the candidate detail', (tester) async {
    final router = await pump(tester);
    await tester.longPress(find.text('◆ 9C1B'));
    await tester.pumpAndSettle();
    expect(
      router.state.uri.path,
      Routes.candidateDetailFor(
        jobId,
        FakeBoardRepository.demoTiles[1].applicationId,
      ),
    );
  });

  testWidgets('empty and error states', (tester) async {
    board = FakeBoardRepository(latency: Duration.zero, boards: {});
    await pump(tester);
    expect(find.text('No applicants yet'), findsOneWidget);

    board = FakeBoardRepository(latency: Duration.zero)
      ..failNext = const AppFailure('not_owner');
    await pump(tester);
    expect(find.text('Only the company owner can do that.'), findsOneWidget);
    await tap(tester, find.text('Retry'));
    expect(handles(tester), hasLength(3));
  });
}
