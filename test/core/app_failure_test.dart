import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/logging/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('P0001 RPC errors use the contract code', () {
    final failure = AppFailure.from(
      const PostgrestException(message: 'invalid_invite', code: 'P0001'),
    );
    expect(failure.code, 'invalid_invite');
    expect(failure.message, contains('invite code'));
  });

  test('auth errors keep their code', () {
    final failure = AppFailure.from(
      const AuthException('Invalid login', code: 'invalid_credentials'),
    );
    expect(failure.code, 'invalid_credentials');
    expect(failure.message, 'That email and password don\'t match.');
  });

  test('rejected sign-up emails get a friendly message', () {
    final failure = AppFailure.from(
      const AuthApiException(
        'Email address "john_why@email.com" is invalid',
        statusCode: '400',
        code: 'email_address_invalid',
      ),
    );
    expect(failure.code, 'email_address_invalid');
    expect(failure.message, contains('different one'));
  });

  test('log masking hides the local part of an email', () {
    expect(AppLog.maskEmail('john_why@email.com'), 'j***@email.com');
    expect(AppLog.maskEmail('not-an-email'), '***');
  });

  test('anything else becomes a generic failure', () {
    final failure = AppFailure.from(StateError('boom'));
    expect(failure.code, 'unknown');
    expect(failure.message, isNotEmpty);
  });
}
