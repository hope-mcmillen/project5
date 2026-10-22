import 'package:flutter/foundation.dart';

/// Debug console logging. Every line is tagged, so `flutter run` output can
/// be filtered, e.g. `flutter run ... | grep '\[auth\]'`. Release builds
/// print nothing.
abstract final class AppLog {
  static void info(String tag, String message) => _write('INFO', tag, message);

  static void warn(String tag, String message, [Object? error]) =>
      _write('WARN', tag, message, error);

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _write('ERROR', tag, message, error, stack);

  /// `john_why@email.com` → `j***@email.com`, so logs that get pasted into
  /// chats or issues don't carry full addresses.
  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at < 1) return '***';
    return '${email[0]}***${email.substring(at)}';
  }

  static void _write(
    String level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (!kDebugMode) return;
    final time = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('$time $level [$tag] $message');
    if (error != null) debugPrint('    ↳ ${error.runtimeType}: $error');
    if (stack != null) debugPrint('$stack');
  }
}
