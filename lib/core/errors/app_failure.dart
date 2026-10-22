import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_log.dart';

/// The one error type repositories throw. Screens show [message]; tests and
/// controllers switch on [code] (the RPC error code from API_CONTRACT §1).
class AppFailure implements Exception {
  const AppFailure(this.code, [String? message])
    : message = message ?? 'Something went wrong. Please try again.';

  final String code;
  final String message;

  /// Maps Supabase exceptions (and anything else) to a friendly failure,
  /// logging the raw error first since the mapping drops its details.
  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    final failure = _map(error);
    AppLog.error('failure', '→ AppFailure(${failure.code})', error);
    return failure;
  }

  static AppFailure _map(Object error) {
    if (error is PostgrestException) {
      // P0001 carries the contract code as its message.
      final code = error.code == 'P0001' ? error.message : (error.code ?? '');
      return AppFailure(code, _messages[code]);
    }
    if (error is AuthException) {
      final code = error.code ?? 'auth_error';
      return AppFailure(code, _messages[code] ?? error.message);
    }
    if (error is StorageException) {
      return AppFailure(
        'storage_error',
        'The upload failed. Please try again.',
      );
    }
    if (error is FunctionException) {
      final details = error.details;
      final code = details is Map && details['error'] is Map
          ? '${details['error']['code']}'
          : 'function_error';
      return AppFailure(code, _messages[code]);
    }
    return const AppFailure('unknown');
  }

  static const _messages = {
    // Auth
    'invalid_credentials': 'That email and password don\'t match.',
    'user_already_exists': 'An account with that email already exists.',
    'email_exists': 'An account with that email already exists.',
    'weak_password': 'Choose a stronger password (at least 8 characters).',
    'email_not_confirmed': 'Confirm your email first, then sign in.',
    'email_address_invalid':
        'That email address can\'t be used. Try a different one.',
    'email_address_not_authorized':
        'Sign-up emails can\'t be sent to that address yet.',
    'over_email_send_rate_limit':
        'Too many emails sent. Wait a minute and try again.',
    'google_not_configured': 'Google sign-in isn\'t set up for this build.',
    'not_authenticated': 'Your session ended. Please sign in again.',
    'role_already_set': 'Your account already has a role.',
    'invalid_role': 'Choose candidate or recruiter.',
    // Companies (API_CONTRACT §7.1)
    'not_recruiter': 'Only recruiter accounts can do that.',
    'already_in_company': 'You already belong to a company.',
    'invalid_company': 'Check the company name and website.',
    'invalid_invite': 'That invite code is invalid, expired, or used up.',
    'not_owner': 'Only the company owner can do that.',
    'invalid_expiry': 'Invites can last 1 to 30 days.',
    // Network / access
    '42501': 'You don\'t have access to that.',
  };

  @override
  String toString() => 'AppFailure($code): $message';
}

/// Riverpod retry policy for the app: never retry automatically. Contract
/// errors (`not_owner`, `invalid_invite`, …) won't change on retry, and
/// every data screen offers its own Retry button.
Duration? noAutomaticRetry(int retryCount, Object error) => null;
