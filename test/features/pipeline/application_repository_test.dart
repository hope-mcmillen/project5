import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/core/testing/candidate_fixtures.dart';
import 'package:project5/features/pipeline/data/supabase_application_repository.dart';
import 'package:project5/features/pipeline/data/fake_application_repository.dart';
import 'package:project5/features/pipeline/presentation/pipeline_providers.dart';

Map<String, dynamic> row({
  String id = 'application-1',
  String status = 'APPLIED',
  int day = 1,
}) => {
  ...CandidateFixtures.applications.first.toJson(),
  'id': id,
  'status': status,
  'updated_at': DateTime.utc(2026, 10, day).toIso8601String(),
}..remove('scoring_version'); // my_applications intentionally omits this field.

class Source implements ApplicationSource {
  List<Map<String, dynamic>> rows = [row()];
  final updates = StreamController<void>.broadcast(sync: true);
  Future<List<Map<String, dynamic>>> Function()? load;
  int canceled = 0, reads = 0;
  String? withdrawn;
  Object? contactError;
  @override
  Stream<void> changes() => Stream.multi((sink) {
    final sub = updates.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.add(null);
    sink.onCancel = () {
      canceled++;
      return sub.cancel();
    };
  });
  @override
  Future<List<Map<String, dynamic>>> applications() async {
    reads++;
    return load == null ? rows : await load!();
  }

  @override
  Future<List<Map<String, dynamic>>> events(String id) async => [
    StatusEvent(
      id: 1,
      applicationId: id,
      toStatus: ApplicationStatus.underReview,
      createdAt: DateTime.utc(2026, 10, 2),
    ).toJson(),
  ];
  @override
  Future<Map<String, dynamic>> contact(String id) async {
    if (contactError != null) throw contactError!;
    return {
      'name': 'Alex Recruiter',
      'email': 'alex@example.test',
      'note': 'Send your availability.',
    };
  }

  @override
  Future<void> withdraw(String id) async {
    withdrawn = id;
  }
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('initial view data, status changes, errors and reconnect refresh are streamed in order', () async {
    final source = Source()
      ..rows = [row(id: 'older'), row(id: 'newer', day: 3)];
    addTearDown(source.updates.close);
    final repo = SupabaseApplicationRepository(source);
    final seen = <List<Application>>[], errors = <Object>[];
    final sub = repo.watchMine().listen(seen.add, onError: errors.add);
    await flush();
    expect(seen.single.map((a) => a.id), ['newer', 'older']);
    expect(seen.single.first.scoringVersion, 'unknown');
    source.rows = [row(status: 'INTERVIEW_REQUESTED', day: 4)];
    source.updates.add(null);
    await flush();
    expect(seen.last.single.status, ApplicationStatus.interviewRequested);
    source.load = () async => throw const AppFailure('offline');
    source.updates.add(null);
    await flush();
    expect(errors.single, isA<AppFailure>());
    source.load = null;
    source.updates.add(null); // Reconnected table snapshot.
    await flush();
    expect(seen, hasLength(3));
    expect(
      (await repo.statusEvents('application-1')).single.toStatus,
      ApplicationStatus.underReview,
    );
    expect((await repo.contact('application-1')).email, 'alex@example.test');
    await repo.withdraw('application-1');
    expect(source.withdrawn, 'application-1');
    await sub.cancel();
    expect(source.canceled, 1);
  });

  test('canceling a pending refresh promptly removes its subscription and ignores the response', () async {
    final source = Source();
    addTearDown(source.updates.close);
    final pending = Completer<List<Map<String, dynamic>>>();
    source.load = () => pending.future;
    final seen = <List<Application>>[];
    final sub = SupabaseApplicationRepository(source)
        .watchMine()
        .listen(seen.add);
    await flush();
    await sub.cancel();
    expect(source.canceled, 1);
    pending.complete([row()]);
    await flush();
    expect(seen, isEmpty);
  });

  test('a change during a refresh triggers a fresh read instead of losing the update', () async {
    final source = Source();
    addTearDown(source.updates.close);
    final pending = Completer<List<Map<String, dynamic>>>();
    source.load = () => pending.future;
    final seen = <List<Application>>[];
    final sub = SupabaseApplicationRepository(source)
        .watchMine()
        .listen(seen.add);
    addTearDown(sub.cancel);
    await flush();
    source.rows = [row(status: 'WITHDRAWN', day: 5)];
    source.load = null;
    source.updates.add(null);
    pending.complete([row()]);
    await flush();
    expect(source.reads, 2);
    expect(seen.last.single.status, ApplicationStatus.withdrawn);
  });

  test('contact RPC failures are mapped and fake contacts are only revealed at interview status', () async {
    final source = Source()
      ..contactError = const PostgrestException(
        message: 'contact_not_available',
        code: 'P0001',
      );
    addTearDown(source.updates.close);
    await expectLater(
      SupabaseApplicationRepository(source).contact('1'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.code,
          'code',
          'contact_not_available',
        ),
      ),
    );
    final fake = FakeApplicationRepository(
      latency: Duration.zero,
      applications: [CandidateFixtures.applications.first],
    );
    addTearDown(fake.dispose);
    final id = CandidateFixtures.applications.first.id;
    await expectLater(fake.contact(id), throwsA(isA<AppFailure>()));
    fake.setStatus(id, ApplicationStatus.interviewRequested);
    expect((await fake.contact(id)).email, isNotEmpty);
    fake.setStatus(id, ApplicationStatus.notSelected);
    await expectLater(fake.contact(id), throwsA(isA<AppFailure>()));
  });

  test('no-response hint begins at 21 days only before recruiter action; terminal states cannot withdraw', () {
    final original = CandidateFixtures.applications.first;
    final deadline = original.createdAt.add(const Duration(days: 21));
    expect(
      hasNoResponse(original, deadline.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(hasNoResponse(original, deadline), isTrue);
    final reviewed = Application.fromJson({
      ...original.toJson(),
      'status': 'UNDER_REVIEW',
    });
    expect(hasNoResponse(reviewed, deadline), isFalse);
    for (final application in CandidateFixtures.applications) {
      expect(
        canWithdraw(application),
        application.status.index <= ApplicationStatus.interviewRequested.index,
      );
    }
  });
}
