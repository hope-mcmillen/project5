import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/application_status.dart';
import '../domain/board_change.dart';
import '../domain/candidate_detail.dart';
import '../domain/board_tile.dart';
import 'board_repository.dart';

/// In-memory [BoardRepository] seeded from the API_CONTRACT §7.4 tile.
class FakeBoardRepository implements BoardRepository {
  FakeBoardRepository({
    this.latency = const Duration(milliseconds: 300),
    Map<String, List<BoardTile>>? boards,
  }) : _boards = boards ?? {demoJobId: List.of(demoTiles)};

  static const demoJobId = '40000000-0000-0000-0000-000000000001';

  static final demoTiles = [
    BoardTile.fromJson(const {
      'application_id': '50000000-0000-0000-0000-000000000001',
      'handle': '◆ 4F2A',
      'match_score': 87,
      'band': 'Strong',
      'total_years': 4.5,
      'top_skills': ['Flutter', 'Dart', 'Firebase'],
      'gaps': ['Kubernetes'],
      'status': 'APPLIED',
      'committed_at': '2026-10-22T14:00:05Z',
    }),
    BoardTile.fromJson(const {
      'application_id': '50000000-0000-0000-0000-000000000002',
      'handle': '◆ 9C1B',
      'match_score': 74,
      'band': 'Good',
      'total_years': 2,
      'top_skills': ['Dart', 'Flutter'],
      'gaps': ['Firebase', 'Kubernetes'],
      'status': 'UNDER_REVIEW',
      'committed_at': '2026-10-22T15:10:00Z',
    }),
    BoardTile.fromJson(const {
      'application_id': '50000000-0000-0000-0000-000000000003',
      'handle': '◆ 2D7E',
      'match_score': 58,
      'band': 'Stretch',
      'total_years': 1,
      'top_skills': ['Dart'],
      'gaps': ['Firebase', 'Flutter', 'Kubernetes'],
      'status': 'APPLIED',
      'committed_at': '2026-10-22T16:30:00Z',
    }),
  ];

  /// Statuses hidden from the default board.
  static const _hidden = {
    ApplicationStatus.notSelected,
    ApplicationStatus.withdrawn,
    ApplicationStatus.jobClosed,
  };

  final Duration latency;

  /// When set, the next call throws this failure instead of running.
  AppFailure? failNext;

  final Map<String, List<BoardTile>> _boards;
  final _changes = <String, StreamController<BoardChange>>{};

  StreamController<BoardChange> _channel(String jobId) =>
      _changes.putIfAbsent(jobId, StreamController<BoardChange>.broadcast);

  @override
  Stream<BoardChange> watchApplications(String jobId) => _channel(jobId).stream;

  /// Applications whose candidate only has a manual profile (no resume).
  final manualProfiles = <String>{};

  @override
  Future<void> openApplication(String applicationId) async {
    await _call();
    final status = _status(applicationId);
    if (status == ApplicationStatus.applied) {
      _set(applicationId, ApplicationStatus.underReview);
    } else if (status != ApplicationStatus.underReview) {
      throw const AppFailure('invalid_transition');
    }
  }

  @override
  Future<CandidateDetail> candidateDetail(String applicationId) async {
    await _call();
    final found = _find(applicationId);
    return _detail(found.board[found.index]);
  }

  CandidateDetail _detail(BoardTile tile) => CandidateDetail(
    tile: tile,
    breakdown: [
      for (final skill in tile.topSkills)
        BreakdownEntry(
          name: skill,
          required: true,
          weight: 2,
          minYears: 2,
          candidateYears: tile.totalYears,
          matchedVia: 'exact',
          score: (tile.totalYears / 2).clamp(0.6, 1.0),
        ),
      for (final gap in tile.gaps)
        BreakdownEntry(name: gap, required: false, score: 0),
    ],
    skills: [
      for (final skill in tile.topSkills)
        SkillEvidence(
          name: skill,
          years: tile.totalYears,
          evidence: 'Built production features with $skill.',
        ),
    ],
    identity: tile.status == ApplicationStatus.interviewRequested
        ? CandidateIdentity(
            displayName: 'Candidate ${tile.handle.substring(2)}',
            email:
                'candidate.${tile.handle.substring(2).toLowerCase()}@example.test',
          )
        : null,
  );

  @override
  Future<List<CandidateDetail>> interviewList(String jobId) async {
    await _call();
    return [
      for (final tile in _boards[jobId] ?? const <BoardTile>[])
        if (tile.status == ApplicationStatus.interviewRequested) _detail(tile),
    ];
  }

  @override
  Future<Uri> resumeUrl(String applicationId) async {
    await _call();
    if (_status(applicationId) != ApplicationStatus.interviewRequested) {
      throw const AppFailure('not_owner');
    }
    if (manualProfiles.contains(applicationId)) {
      throw const AppFailure('resume_not_available');
    }
    return Uri.parse('https://example.test/resumes/$applicationId.pdf');
  }

  /// Simulates a candidate's right swipe arriving for [jobId]. With
  /// [notify], a Realtime insert is also emitted (recruiters usually don't
  /// get one, because the row is pending when inserted).
  void addApplicant(String jobId, BoardTile tile, {bool notify = true}) {
    (_boards[jobId] ??= []).add(tile);
    if (notify) {
      _channel(jobId)
          .add(BoardChange(isInsert: true, committedAt: tile.committedAt));
    }
  }

  /// Simulates a status change by someone else (e.g. a withdrawal).
  void changeStatus(String applicationId, ApplicationStatus status) {
    _set(applicationId, status);
    for (final entry in _boards.entries) {
      if (entry.value.any((t) => t.applicationId == applicationId)) {
        _channel(entry.key).add(const BoardChange(isInsert: false));
      }
    }
  }

  final _rejectedAt = <String, (ApplicationStatus previous, DateTime at)>{};

  Future<void> _call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<List<BoardTile>> getBoard(
    String jobId, {
    int limit = 50,
    int offset = 0,
    int? minScore,
  }) async {
    await _call();
    final tiles =
        (_boards[jobId] ?? const <BoardTile>[])
            .where((t) => !_hidden.contains(t.status))
            .where((t) => minScore == null || t.matchScore >= minScore)
            .toList()
          ..sort((a, b) {
            final byScore = b.matchScore.compareTo(a.matchScore);
            return byScore != 0
                ? byScore
                : a.committedAt.compareTo(b.committedAt);
          });
    return tiles.skip(offset).take(limit).toList();
  }

  ({List<BoardTile> board, int index}) _find(String applicationId) {
    for (final board in _boards.values) {
      final index = board.indexWhere((t) => t.applicationId == applicationId);
      if (index != -1) return (board: board, index: index);
    }
    throw const AppFailure('not_owner');
  }

  void _set(String applicationId, ApplicationStatus status) {
    final found = _find(applicationId);
    found.board[found.index] = found.board[found.index].copyWith(
      status: status,
    );
  }

  ApplicationStatus _status(String applicationId) {
    final found = _find(applicationId);
    return found.board[found.index].status;
  }

  @override
  Future<void> advance(String applicationId, {String? note}) async {
    await _call();
    final status = _status(applicationId);
    if (status != ApplicationStatus.applied &&
        status != ApplicationStatus.underReview) {
      throw const AppFailure('invalid_transition');
    }
    _set(applicationId, ApplicationStatus.interviewRequested);
  }

  @override
  Future<void> reject(String applicationId, {String? reason}) async {
    await _call();
    final status = _status(applicationId);
    if (status != ApplicationStatus.applied &&
        status != ApplicationStatus.underReview) {
      throw const AppFailure('invalid_transition');
    }
    _rejectedAt[applicationId] = (status, DateTime.now());
    _set(applicationId, ApplicationStatus.notSelected);
  }

  @override
  Future<void> undoReject(String applicationId) async {
    await _call();
    final rejected = _rejectedAt.remove(applicationId);
    if (rejected == null) throw const AppFailure('invalid_transition');
    if (DateTime.now().difference(rejected.$2) > const Duration(seconds: 10)) {
      throw const AppFailure('undo_window_expired');
    }
    _set(applicationId, rejected.$1);
  }
}
