import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project5/app/route_session.dart';
import 'package:project5/app/router.dart';
import 'package:project5/app/routes.dart';
import 'package:project5/core/logging/app_log.dart';
import 'package:project5/core/logging/logging_http_client.dart';
import 'package:project5/core/logging/tap_logger.dart';

void main() {
  late List<String> lines;
  setUp(() {
    lines = [];
    AppLog.output = lines.add;
  });
  tearDown(() => AppLog.output = debugPrint);

  String logs() => lines.join('\n');

  group('redact', () {
    test('hides secrets, masks emails, keeps ordinary fields', () {
      final clean = AppLog.redact({
        'email': 'jane.doe@example.com',
        'password': 'hunter2',
        'refresh_token': 'abc',
        'gotrue_meta_security': {'captcha_token': 'x'},
        'pass_reason': 'salary',
        'note': 'contact jane.doe@example.com, token eyJhbGc.eyJzdWIi.c2ln',
        'years': 2.5,
      });
      expect(clean, {
        'email': 'j***@example.com',
        'password': '[redacted]',
        'refresh_token': '[redacted]',
        'gotrue_meta_security': {'captcha_token': '[redacted]'},
        'pass_reason': 'salary',
        'note': 'contact j***@example.com, token [jwt]',
        'years': 2.5,
      });
    });

    test('shortens long strings and lists', () {
      final clean = AppLog.redact({
        'text': 'x' * 1000,
        'items': List.generate(30, (i) => i),
      }) as Map;
      expect(clean['text'], endsWith('…(1000 chars)'));
      expect((clean['text'] as String).length, lessThan(330));
      expect(clean['items'], hasLength(21));
      expect((clean['items'] as List).last, '…(+10 more)');
    });
  });

  group('LoggingHttpClient', () {
    http.StreamedResponse respond(
      http.BaseRequest request,
      int status,
      String body, {
      String type = 'application/json',
    }) => http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: {'content-type': type},
      request: request,
    );

    test('logs the data sent without secrets, and passes the response '
        'through unchanged', () async {
      final client = LoggingHttpClient(
        MockClient.streaming((request, _) async {
          return respond(
            request,
            200,
            '{"access_token":"eyJa.eyJb.c2ln","ok":true}',
          );
        }),
      );
      final response = await client.post(
        Uri.parse(
          'https://x.supabase.co/auth/v1/token?grant_type=password&apikey=k',
        ),
        headers: {'Authorization': 'Bearer secret-jwt'},
        body: jsonEncode({'email': 'jane@example.com', 'password': 'hunter2'}),
      );
      expect(jsonDecode(response.body), {
        'access_token': 'eyJa.eyJb.c2ln',
        'ok': true,
      });
      final out = logs();
      expect(
        out,
        contains(
          '[http] → #1 POST /auth/v1/token?grant_type=password&apikey=%5Bredacted%5D '
          '{"email":"j***@example.com","password":"[redacted]"}',
        ),
      );
      expect(out, contains('[http] ← #1 POST /auth/v1/token'));
      expect(out, contains('200 in '));
      expect(out, contains('"access_token":"[redacted]"'));
      for (final secret in [
        'hunter2',
        'secret-jwt',
        'eyJa.eyJb.c2ln',
        'jane@',
      ]) {
        expect(out, isNot(contains(secret)));
      }
    });

    test('errors are logged with their response body as WARN', () async {
      final client = LoggingHttpClient(
        MockClient.streaming(
          (request, _) async => respond(
            request,
            404,
            '{"code":"NOT_FOUND","message":"Requested function was not found"}',
          ),
        ),
      );
      final response = await client.post(
        Uri.parse('https://x.supabase.co/functions/v1/parse-job'),
      );
      expect(response.statusCode, 404);
      expect(
        logs(),
        contains('WARN [http] ← #1 POST /functions/v1/parse-job 404'),
      );
      expect(logs(), contains('Requested function was not found'));
    });

    test('uploads log file names and sizes, never contents', () async {
      final client = LoggingHttpClient(
        MockClient.streaming((request, body) async {
          await body.drain<void>();
          return respond(request, 200, '{}');
        }),
      );
      final request =
          http.MultipartRequest(
              'POST',
              Uri.parse('https://x.supabase.co/functions/v1/parse-resume'),
            )
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                utf8.encode('%PDF secret resume text'),
                filename: 'resume.pdf',
              ),
            );
      await client.send(request);
      expect(logs(), contains('"filename":"resume.pdf","size":"23 B"'));
      expect(logs(), isNot(contains('secret resume text')));
    });

    test('streamed responses pass through untouched and log each event', () async {
      const events =
          'data: {"status":"EXTRACTING"}\n\ndata: {"status":"READY","version":2}\n\n';
      final client = LoggingHttpClient(
        MockClient.streaming(
          (request, _) async => http.StreamedResponse(
            Stream.fromIterable([
              utf8.encode(events.substring(0, 20)),
              utf8.encode(events.substring(20)),
            ]),
            200,
            headers: {'content-type': 'text/event-stream'},
            request: request,
          ),
        ),
      );
      final response = await client.send(
        http.Request(
          'POST',
          Uri.parse('https://x.supabase.co/functions/v1/parse-resume'),
        ),
      );
      expect(await response.stream.bytesToString(), events);
      final out = logs();
      expect(out, contains('streaming'));
      expect(out, contains('event {"status":"EXTRACTING"}'));
      expect(out, contains('event {"status":"READY","version":2}'));
      expect(out, contains('stream closed'));
    });
  });

  testWidgets('taps are logged with the control and its label', (tester) async {
    AppLog.page = '/test';
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => TapLogger(child: child!),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Open menu',
                icon: const Icon(Icons.menu),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              FilledButton(
                onPressed: () {},
                child: const Text('Read description'),
              ),
              const TextField(decoration: InputDecoration(labelText: 'Email')),
              ListTile(
                title: const Text('Flutter Developer'),
                onTap: () {},
                trailing: IconButton(
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                ),
              ),
              const Text('Just text'),
            ],
          ),
        ),
      ),
    );
    for (final label in [
      'Read description',
      'Email',
      'Flutter Developer',
      'Just text',
    ]) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pump();
    await tester.tap(find.byTooltip('More actions'));
    await tester.pump();
    final taps = lines.where((l) => l.contains('[tap]')).toList();
    expect(taps, hasLength(5)); // plain text isn't interactive
    expect(taps[0], endsWith('[tap] FilledButton "Read description" on /test'));
    expect(taps[1], endsWith('[tap] TextField "Email" on /test'));
    expect(taps[2], endsWith('[tap] ListTile "Flutter Developer" on /test'));
    expect(taps[3], endsWith('[tap] IconButton "Open menu" on /test'));
    // A button inside a list row is reported as the button, not the row.
    expect(taps[4], endsWith('[tap] IconButton "More actions" on /test'));
  });

  testWidgets('pages and route-guard redirects are logged', (tester) async {
    final router = buildRouter(
      session: () => RouteSession.signedOut,
      initialLocation: Routes.deck,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(
      lines.where(
        (l) => l.contains('[route] redirect /c/deck → /welcome (signedOut)'),
      ),
      hasLength(1),
    );
    expect(logs(), contains('[page] /welcome'));
    expect(AppLog.page, '/welcome');
    router.go(Routes.signIn);
    await tester.pumpAndSettle();
    expect(logs(), contains('[page] /sign-in'));
  });
}
