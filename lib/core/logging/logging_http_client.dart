import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_log.dart';

/// Logs every request the Supabase client makes (PostgREST, Auth, Edge
/// Functions, Storage), tagged `http`:
///
///     → #12 POST /rest/v1/rpc/confirm_profile {"p_version_id":"…",…}
///     ← #12 204 in 183ms (0 B)
///
/// What is logged, and what never is:
/// - the data sent: JSON bodies and form fields after [AppLog.redact]
///   (passwords, tokens and keys hidden, emails masked), and for uploads
///   only each file's name and size, never its contents;
/// - no headers, so the JWT and API key never appear;
/// - responses: status, time and size; the body for errors (WARN), and for
///   everything else at debug level; streamed responses (`parse-resume`
///   progress) are logged event by event without being buffered.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;
  int _sequence = 0;

  /// Larger responses pass through unbuffered, with only status and size.
  static const _maxBufferedBytes = 512 * 1024;
  static const _secretQuery = {
    'apikey',
    'access_token',
    'refresh_token',
    'token',
    'code',
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final id = ++_sequence;
    final label = '#$id ${request.method} ${_url(request.url)}';
    final sent = _requestData(request);
    AppLog.event('http', '→ $label', sent);
    final watch = Stopwatch()..start();
    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (error) {
      AppLog.warn(
        'http',
        '✗ $label failed after ${watch.elapsedMilliseconds}ms',
        error,
      );
      rethrow;
    }
    final type = response.headers['content-type'] ?? '';
    if (type.startsWith('text/event-stream')) {
      AppLog.info('http', '← $label ${response.statusCode} streaming');
      return _copy(response, _logEvents(response.stream, label, watch));
    }
    final length = response.contentLength;
    if (length != null && length > _maxBufferedBytes) {
      AppLog.info(
        'http',
        '← $label ${response.statusCode} in ${watch.elapsedMilliseconds}ms '
            '(${_size(length)}, not logged)',
      );
      return response;
    }
    final bytes = await response.stream.toBytes();
    final summary =
        '← $label ${response.statusCode} in ${watch.elapsedMilliseconds}ms '
        '(${_size(bytes.length)})';
    if (response.statusCode >= 400) {
      AppLog.warn('http', '$summary ${_body(bytes, type)}');
    } else {
      AppLog.info('http', summary);
      if (bytes.isNotEmpty && AppLog.enabled('DEBUG')) {
        AppLog.debug('http', '  #$id body ${_body(bytes, type)}');
      }
    }
    return _copy(response, Stream.value(bytes));
  }

  @override
  void close() => _inner.close();

  static http.StreamedResponse _copy(
    http.StreamedResponse response,
    Stream<List<int>> body,
  ) => http.StreamedResponse(
    http.ByteStream(body),
    response.statusCode,
    contentLength: response.contentLength,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );

  /// Passes the bytes through untouched and logs each `data:` line.
  static Stream<List<int>> _logEvents(
    Stream<List<int>> source,
    String label,
    Stopwatch watch,
  ) {
    var pending = '';
    return source.transform(
      StreamTransformer.fromHandlers(
        handleData: (chunk, sink) {
          sink.add(chunk);
          pending += utf8.decode(chunk, allowMalformed: true);
          final lines = pending.split('\n');
          pending = lines.removeLast();
          for (final line in lines) {
            if (line.startsWith('data:')) {
              AppLog.event(
                'http',
                '  $label event',
                _decode(line.substring(5).trim()),
              );
            }
          }
        },
        handleDone: (sink) {
          AppLog.info(
            'http',
            '← $label stream closed after ${watch.elapsedMilliseconds}ms',
          );
          sink.close();
        },
      ),
    );
  }

  /// Path and query relative to the Supabase project, secrets removed.
  static String _url(Uri url) {
    if (url.queryParameters.isEmpty) return url.path;
    final query = {
      for (final entry in url.queryParameters.entries)
        entry.key: _secretQuery.contains(entry.key.toLowerCase())
            ? '[redacted]'
            : entry.value,
    };
    return '${url.path}?${Uri(queryParameters: query).query}';
  }

  static Object? _requestData(http.BaseRequest request) {
    if (request is http.MultipartRequest) {
      return {
        if (request.fields.isNotEmpty) 'fields': request.fields,
        'files': [
          for (final file in request.files)
            {
              'field': file.field,
              'filename': file.filename,
              'size': _size(file.length),
            },
        ],
      };
    }
    if (request is http.Request) {
      if (request.bodyBytes.isEmpty) return null;
      return _decode(
        utf8.decode(request.bodyBytes, allowMalformed: true),
        binaryLength:
            request.headers['content-type']?.contains('octet-stream') == true
            ? request.bodyBytes.length
            : null,
      );
    }
    return '(streamed body)';
  }

  static String _body(List<int> bytes, String contentType) {
    if (bytes.isEmpty) return '(empty)';
    if (!contentType.contains('json') && !contentType.startsWith('text/')) {
      return '($contentType, ${_size(bytes.length)})';
    }
    return AppLog.describe(_decode(utf8.decode(bytes, allowMalformed: true)));
  }

  static Object? _decode(String text, {int? binaryLength}) {
    if (binaryLength != null) return '(binary, ${_size(binaryLength)})';
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  static String _size(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
