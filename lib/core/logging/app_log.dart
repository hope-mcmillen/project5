import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Debug console logging. Every line is tagged, so `flutter run` output can
/// be filtered, e.g. `flutter run ... | grep '\[http\]'`. Release builds
/// print nothing.
///
/// Tags used across the app:
/// - `page`: the page the user is on (every navigation)
/// - `route`: route-guard redirects and why
/// - `tap`: what the user tapped, with its label and the page
/// - `http`: every Supabase request: method, path, data sent (redacted),
///   status, time, and the response (bodies at debug level)
/// - `provider`: providers that failed
/// - `app`: startup and lifecycle (resumed, paused, …)
/// - feature tags such as `auth` and `resume`
///
/// Pick how much to see with `--dart-define=LOG_LEVEL=debug|info|warn|error|off`
/// (default `debug`, the most detail).
abstract final class AppLog {
  static const _levels = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'OFF'];
  static final int _minLevel = () {
    const name = String.fromEnvironment('LOG_LEVEL', defaultValue: 'debug');
    final index = _levels.indexOf(name.toUpperCase());
    return index < 0 ? 0 : index;
  }();

  /// Where lines go. Tests replace it to capture output.
  @visibleForTesting
  static void Function(String line) output = debugPrint;

  /// The page the user is on, kept current by the router (for `tap` lines).
  static String page = '-';

  static bool enabled(String level) =>
      kDebugMode && _levels.indexOf(level) >= _minLevel;

  static void debug(String tag, String message) =>
      _write('DEBUG', tag, message);

  static void info(String tag, String message) => _write('INFO', tag, message);

  static void warn(String tag, String message, [Object? error]) =>
      _write('WARN', tag, message, error);

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _write('ERROR', tag, message, error, stack);

  /// An INFO line with structured [data], redacted and shortened.
  static void event(String tag, String message, [Object? data]) {
    if (!enabled('INFO')) return;
    _write('INFO', tag, data == null ? message : '$message ${describe(data)}');
  }

  /// `john_why@email.com` → `j***@email.com`, so logs that get pasted into
  /// chats or issues don't carry full addresses.
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at < 1) return '***';
    return '${email[0]}***${email.substring(at)}';
  }

  /// Compact JSON of [data] after [redact].
  static String describe(Object? data) {
    final clean = redact(data);
    if (clean is String) return clean;
    try {
      return jsonEncode(clean);
    } catch (_) {
      return '$clean';
    }
  }

  static const _maxString = 300;
  static const _maxItems = 20;
  static const _maxDepth = 6;
  static final _secretKey = RegExp(
    r'password|passwd|token|secret|authorization|api_?key|refresh|code_verifier|nonce|(^|_)otp($|_)',
    caseSensitive: false,
  );
  static final _jwt = RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+');
  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');

  /// A copy of [value] that is safe to log: secrets (passwords, tokens,
  /// keys) are replaced, emails masked, JWTs removed, and long strings and
  /// lists shortened.
  static Object? redact(Object? value, [int depth = 0]) {
    if (depth > _maxDepth) return '…';
    if (value is Map) {
      return {
        for (final entry in value.entries)
          '${entry.key}': _secretKey.hasMatch('${entry.key}')
              ? '[redacted]'
              : redact(entry.value, depth + 1),
      };
    }
    if (value is Iterable) {
      final items = value.toList();
      return [
        for (final item in items.take(_maxItems)) redact(item, depth + 1),
        if (items.length > _maxItems) '…(+${items.length - _maxItems} more)',
      ];
    }
    if (value is String) {
      final masked = value
          .replaceAll(_jwt, '[jwt]')
          .replaceAllMapped(_email, (m) => maskEmail(m[0]!));
      return masked.length <= _maxString
          ? masked
          : '${masked.substring(0, _maxString)}…(${masked.length} chars)';
    }
    if (value == null || value is num || value is bool) return value;
    return redact('$value', depth);
  }

  static void _write(
    String level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (!enabled(level)) return;
    final time = DateTime.now().toIso8601String().substring(11, 23);
    output('$time $level [$tag] $message');
    if (error != null) output('    ↳ ${error.runtimeType}: $error');
    if (stack != null) output('$stack');
  }
}
