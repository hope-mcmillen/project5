import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project5/core/models/candidate_models.dart';
import 'package:project5/features/onboarding/data/supabase_resume_repository.dart';
import 'package:project5/features/profile/data/supabase_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final pdf = Uint8List.fromList('%PDF-1.7 demo'.codeUnits);

SupabaseClient client(MockClientStreamHandler handler) => SupabaseClient(
  'http://localhost:54321',
  'anon-key',
  // Responses carry their request, as real ones do (PostgREST reads it).
  httpClient: MockClient.streaming((request, body) async {
    final r = await handler(request, body);
    return http.StreamedResponse(
      r.stream,
      r.statusCode,
      headers: r.headers,
      request: request,
    );
  }),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

http.StreamedResponse sse(List<Map<String, Object?>> events) =>
    http.StreamedResponse(
      Stream.fromIterable([
        for (final e in events) utf8.encode('data: ${jsonEncode(e)}\n\n'),
      ]),
      200,
      headers: {'content-type': 'text/event-stream'},
    );

http.StreamedResponse jsonResponse(Object body, {int status = 200}) =>
    http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json'},
    );

/// Uploads and collects every status until the parse finishes.
Future<List<Resume>> parse(SupabaseResumeRepository repo) async {
  final resume = await repo.upload(filename: 'resume.pdf', bytes: pdf);
  final seen = <Resume>[];
  await for (final r in repo.watchStatus(resume.id)) {
    seen.add(r);
    if (r.status == ResumeStatus.ready || r.status == ResumeStatus.failed) {
      break;
    }
  }
  return seen;
}

void main() {
  test(
    'sends the file once as multipart and streams each step to READY',
    () async {
      late http.BaseRequest sent;
      late String body;
      final repo = SupabaseResumeRepository(
        client((request, bodyStream) async {
          sent = request;
          body = latin1.decode(await bodyStream.toBytes());
          return sse([
            {'status': 'PARSING_LAYOUT'},
            {'status': 'EXTRACTING'},
            {'status': 'NORMALIZING'},
            {
              'status': 'READY',
              'profile_version_id': 'v-1',
              'version': 1,
              'skill_count': 4,
            },
          ]);
        }),
      );
      addTearDown(repo.dispose);
      final seen = await parse(repo);
      expect(sent.url.path, '/functions/v1/parse-resume');
      expect(sent.headers['Accept'], 'text/event-stream');
      expect(sent.headers['content-type'], startsWith('multipart/form-data'));
      expect(body, contains('filename="resume.pdf"'));
      expect(body, contains('%PDF-1.7 demo'));
      // Reading starts as the file is sent, so a listener's first status is
      // already PARSING_LAYOUT; the rest are the server's events.
      expect(seen.map((r) => r.status).toSet().toList(), [
        ResumeStatus.parsingLayout,
        ResumeStatus.extracting,
        ResumeStatus.normalizing,
        ResumeStatus.ready,
      ]);
      expect(seen.last.profileVersionId, 'v-1');
      expect(seen.last.storagePath, isNull);
    },
  );

  test('a FAILED event and a plain JSON result both end the parse', () async {
    final failed = SupabaseResumeRepository(
      client(
        (_, _) async => sse([
          {'status': 'EXTRACTING'},
          {'status': 'FAILED', 'failure_reason': 'unreadable_scan'},
        ]),
      ),
    );
    addTearDown(failed.dispose);
    final last = (await parse(failed)).last;
    expect(
      [last.status, last.failureReason],
      [ResumeStatus.failed, 'unreadable_scan'],
    );

    final ready = SupabaseResumeRepository(
      client(
        (_, _) async =>
            jsonResponse({'status': 'READY', 'profile_version_id': 'v-2'}),
      ),
    );
    addTearDown(ready.dispose);
    expect((await parse(ready)).last.profileVersionId, 'v-2');
  });

  test(
    'request errors and dropped connections become FAILED with a reason',
    () async {
      for (final (handler, reason) in <(MockClientStreamHandler, String)>[
        (
          (_, _) async => jsonResponse({
            'error': {'code': 'not_candidate', 'message': 'not_candidate'},
          }, status: 403),
          'not_candidate',
        ),
        (
          (_, _) async => jsonResponse({
            'error': {'code': 'invalid_file', 'message': 'invalid_file'},
          }, status: 400),
          'invalid_file',
        ),
        ((_, _) async => throw http.ClientException('offline'), 'network'),
        (
          (_, _) async => sse([
            {'status': 'EXTRACTING'},
          ]),
          'network',
        ),
      ]) {
        final repo = SupabaseResumeRepository(client(handler));
        addTearDown(repo.dispose);
        final last = (await parse(repo)).last;
        expect(
          [last.status, last.failureReason],
          [ResumeStatus.failed, reason],
        );
      }
    },
  );

  test('confirm sends only the fields confirm_profile accepts; drafts load experiences', () async {
    final requests = <http.BaseRequest>[];
    final bodies = <String>[];
    final repo = SupabaseProfileRepository(
      client((request, bodyStream) async {
        requests.add(request);
        bodies.add(utf8.decode(await bodyStream.toBytes()));
        return switch (request.url.path) {
          '/rest/v1/rpc/confirm_profile' => http.StreamedResponse(
            const Stream.empty(),
            204,
          ),
          '/rest/v1/rpc/create_review_draft' => jsonResponse({'id': 'v-3'}),
          _ => jsonResponse({
            'id': 'v-3',
            'candidate_id': 'c-1',
            'resume_id': null,
            'version': 3,
            'source': 'resume',
            'confirmed': false,
            'confirmed_at': null,
            'total_years': 2.5,
            'education': [
              {'level': 'BS', 'field': null},
            ],
            'created_at': '2026-10-22T12:00:00Z',
            'candidate_skills': [],
            'candidate_experiences': [
              {
                'id': 'e-2',
                'profile_version_id': 'v-3',
                'sort_order': 1,
                'kind': 'project',
                'title': 'Campus Map',
                'organization': null,
                'start_month': '2022',
                'end_month': null,
                'highlights': [],
                'skills_used': ['React'],
                'evidence': 'Built a React campus map.',
              },
              {
                'id': 'e-1',
                'profile_version_id': 'v-3',
                'sort_order': 0,
                'kind': 'job',
                'title': 'Android Developer',
                'organization': 'Jefferson Parish Digital',
                'start_month': '2023-01',
                'end_month': 'present',
                'highlights': ['Shipped a Kotlin app.'],
                'skills_used': ['Kotlin'],
                'evidence': 'Android Developer, Jefferson Parish Digital',
              },
            ],
          }),
        };
      }),
    );

    await repo.confirm('v-1', [
      CandidateSkill(
        id: 'local-1',
        profileVersionId: 'v-1',
        skillId: 'skill-kotlin',
        rawName: ' Kotlin ',
        years: 2,
        evidence: 'Shipped a Kotlin app.',
        source: SkillSource.ai,
      ),
    ]);
    expect(jsonDecode(bodies.single), {
      'p_version_id': 'v-1',
      'p_skills': [
        {
          'skill_id': 'skill-kotlin',
          'raw_name': 'Kotlin',
          'years': 2.0,
          'evidence': 'Shipped a Kotlin app.',
        },
      ],
    });

    final draft = await repo.createReviewDraft();
    expect(requests[1].url.path, '/rest/v1/rpc/create_review_draft');
    expect(requests[2].url.queryParameters['id'], 'eq.v-3');
    expect(
      requests[2].url.queryParameters['select'],
      contains('candidate_experiences(*)'),
    );
    expect(draft.experiences.map((e) => e.title), [
      'Android Developer',
      'Campus Map',
    ]);
    expect(draft.experiences.first.isCurrent, isTrue);
    expect(draft.education.single.field, isNull);
  });
}
