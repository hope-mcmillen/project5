import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/application_status.dart';
import 'package:project5/features/board/data/fake_board_repository.dart';

void main() {
  const jobId = FakeBoardRepository.demoJobId;
  late FakeBoardRepository board;
  setUp(() => board = FakeBoardRepository(latency: Duration.zero));

  test('returns blind tiles sorted by score', () async {
    final tiles = await board.getBoard(jobId);
    expect(tiles.map((t) => t.matchScore), [87, 74, 58]);
    expect(tiles.first.handle, '◆ 4F2A');
    expect(tiles.first.status, ApplicationStatus.applied);
    expect(await board.getBoard(jobId, limit: 1, offset: 1), hasLength(1));
  });

  test('reject hides the tile and undo brings it back', () async {
    final id = FakeBoardRepository.demoTiles.first.applicationId;
    await board.reject(id);
    expect(
      (await board.getBoard(jobId)).map((t) => t.applicationId),
      isNot(contains(id)),
    );

    await board.undoReject(id);
    expect((await board.getBoard(jobId)).first.applicationId, id);
  });

  test('advanced candidates cannot be advanced again', () async {
    final id = FakeBoardRepository.demoTiles.first.applicationId;
    await board.advance(id, note: 'Phone screen Monday');
    expect(
      (await board.getBoard(jobId)).first.status,
      ApplicationStatus.interviewRequested,
    );
    await expectLater(
      board.advance(id),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'invalid_transition'),
      ),
    );
  });

  test('application statuses round-trip their Postgres values', () {
    for (final status in ApplicationStatus.values) {
      expect(ApplicationStatus.fromDb(status.toDb()), status);
    }
  });
}
