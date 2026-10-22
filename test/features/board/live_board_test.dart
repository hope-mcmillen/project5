import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/fake_overrides.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/application_status.dart';
import 'package:project5/features/auth/data/fake_auth_repository.dart';
import 'package:project5/features/board/data/board_repository.dart';
import 'package:project5/features/board/data/fake_board_repository.dart';
import 'package:project5/features/board/domain/board_tile.dart';
import 'package:project5/features/board/presentation/widgets/candidate_tile.dart';

BoardTile applicant(String id, int score, {DateTime? committedAt}) => BoardTile(
  applicationId: id,
  handle: '◆ $id',
  matchScore: score,
  band: score >= 85 ? 'Strong' : 'Good',
  status: ApplicationStatus.applied,
  committedAt: committedAt ?? DateTime.now().toUtc(),
  topSkills: const ['Flutter'],
);

void main() {
  const jobId = FakeBoardRepository.demoJobId;
  late FakeAuthRepository auth;
  late FakeBoardRepository board;

  setUp(() {
    auth = FakeAuthRepository(latency: Duration.zero);
    board = FakeBoardRepository(latency: Duration.zero);
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = buildRouter(
      session: () => const RouteSession.recruiter(),
      initialLocation: Routes.boardFor(jobId),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          ...fakeRepositoryOverrides(auth: auth, board: board),
          boardPollIntervalProvider.overrideWithValue(
            const Duration(seconds: 20),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> handles(WidgetTester tester) => [
    for (final tile in tester.widgetList<CandidateTile>(
      find.byType(CandidateTile),
    ))
      tile.tile.handle,
  ];

  testWidgets('a Realtime insert appears in score order once committed', (
    tester,
  ) async {
    await pump(tester);
    expect(handles(tester), ['◆ 4F2A', '◆ 9C1B', '◆ 2D7E']);

    final commit = DateTime.now().toUtc().add(const Duration(seconds: 5));
    board.addApplicant(jobId, applicant('NEW1', 80, committedAt: commit));
    await tester.pump(const Duration(seconds: 1));
    expect(handles(tester), isNot(contains('◆ NEW1')));

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(handles(tester), ['◆ 4F2A', '◆ NEW1', '◆ 9C1B', '◆ 2D7E']);
  });

  testWidgets('without an insert event, the poll still finds new applicants', (
    tester,
  ) async {
    await pump(tester);
    board.addApplicant(jobId, applicant('TOP1', 95), notify: false);
    await tester.pump(const Duration(seconds: 5));
    expect(handles(tester), isNot(contains('◆ TOP1')));

    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(handles(tester).first, '◆ TOP1');
  });

  testWidgets('someone else\'s status change updates the board', (
    tester,
  ) async {
    await pump(tester);
    board.changeStatus(
      FakeBoardRepository.demoTiles[1].applicationId,
      ApplicationStatus.withdrawn,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(handles(tester), ['◆ 4F2A', '◆ 2D7E']);
  });

  testWidgets('a failed background refresh keeps the tiles', (tester) async {
    await pump(tester);
    board.failNext = const AppFailure('unknown');
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(handles(tester), hasLength(3));
    expect(find.text('Retry'), findsNothing);
  });
}
