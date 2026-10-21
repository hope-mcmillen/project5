import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/app_role.dart';
import '../domain/auth_models.dart';
import 'auth_repository.dart';

/// In-memory [AuthRepository] for tests and `main_fake.dart` (RC-03).
///
/// Seeded with the two local demo accounts from the README. Every call
/// waits [latency]; set [failNext] to make the next call throw.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.latency = const Duration(milliseconds: 300),
    bool seedDemoAccounts = true,
  }) {
    if (seedDemoAccounts) {
      _accounts[demoCandidateEmail] = _FakeAccount(
        id: '10000000-0000-0000-0000-000000000001',
        password: demoPassword,
        profile: const AccountProfile(
          userId: '10000000-0000-0000-0000-000000000001',
          role: AppRole.candidate,
          candidateOnboarded: true,
        ),
      );
      _accounts[demoRecruiterEmail] = _FakeAccount(
        id: '10000000-0000-0000-0000-000000000003',
        password: demoPassword,
        profile: const AccountProfile(
          userId: '10000000-0000-0000-0000-000000000003',
          role: AppRole.recruiter,
          recruiterHasCompany: true,
        ),
      );
    }
  }

  static const demoCandidateEmail = 'candidate@demo.resurhombus.test';
  static const demoRecruiterEmail = 'recruiter@demo.resurhombus.test';
  static const demoPassword = 'LocalDemo-4330!';

  /// Email used by [signInWithGoogle]; that account starts with no role.
  static const googleEmail = 'google.user@example.test';

  final Duration latency;

  /// When set, the next call throws this failure instead of running.
  AppFailure? failNext;

  final _accounts = <String, _FakeAccount>{};
  final _events = StreamController<AuthEvent>.broadcast();
  String? _signedInEmail;
  int _nextId = 100;

  /// Every reset link "sent" so far, for tests.
  final sentResetEmails = <String>[];

  _FakeAccount? get _current =>
      _signedInEmail == null ? null : _accounts[_signedInEmail];

  @override
  AuthUser? get currentUser {
    final account = _current;
    return account == null
        ? null
        : AuthUser(id: account.id, email: _signedInEmail);
  }

  @override
  Stream<AuthEvent> authEvents() {
    // Subscribe to changes on listen, so nothing emitted after the first
    // event is lost.
    StreamSubscription<AuthEvent>? changes;
    late final StreamController<AuthEvent> controller;
    controller = StreamController<AuthEvent>(
      onListen: () {
        controller.add(AuthEvent(currentUser));
        changes = _events.stream.listen(
          controller.add,
          onDone: controller.close,
        );
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  Future<void> _call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  void _emit({bool passwordRecovery = false}) =>
      _events.add(AuthEvent(currentUser, passwordRecovery: passwordRecovery));

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required AppRole role,
  }) async {
    await _call();
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AppFailure(
        'user_already_exists',
        'An account with that email already exists.',
      );
    }
    final id = _newId();
    _accounts[key] = _FakeAccount(
      id: id,
      password: password,
      profile: AccountProfile(
        userId: id,
        role: role,
        termsAcceptedAt: DateTime.now().toUtc(),
      ),
    );
    _signedInEmail = key;
    _emit();
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _call();
    final key = email.trim().toLowerCase();
    final account = _accounts[key];
    if (account == null || account.password != password) {
      throw const AppFailure(
        'invalid_credentials',
        'That email and password don\'t match.',
      );
    }
    _signedInEmail = key;
    _emit();
  }

  @override
  Future<void> signInWithGoogle() async {
    await _call();
    _accounts.putIfAbsent(googleEmail, () {
      final id = _newId();
      return _FakeAccount(
        id: id,
        password: null,
        profile: AccountProfile(userId: id),
      );
    });
    _signedInEmail = googleEmail;
    _emit();
  }

  @override
  Future<void> signOut() async {
    await _call();
    _signedInEmail = null;
    _emit();
  }

  @override
  Future<void> resetPassword(String email) async {
    await _call();
    // Like Supabase, never reveal whether the account exists.
    sentResetEmails.add(email.trim().toLowerCase());
  }

  /// Simulates opening the reset link from [email]'s inbox.
  void openResetLink(String email) {
    _signedInEmail = email.trim().toLowerCase();
    _emit(passwordRecovery: true);
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _call();
    final account = _current;
    if (account == null) throw const AppFailure('not_authenticated');
    account.password = newPassword;
    _emit();
  }

  @override
  Future<void> setInitialRole(AppRole role) async {
    await _call();
    final account = _current;
    if (account == null) throw const AppFailure('not_authenticated');
    if (account.profile.role != null) {
      throw const AppFailure(
        'role_already_set',
        'Your account already has a role.',
      );
    }
    account.profile = account.profile.copyWith(role: role);
  }

  @override
  Future<AccountProfile?> fetchProfile() async {
    await _call();
    return _current?.profile;
  }

  /// Test and fake-backend hooks for flags other repositories own.
  void markRecruiterHasCompany() =>
      _update((p) => p.copyWith(recruiterHasCompany: true));

  void markCandidateOnboarded() =>
      _update((p) => p.copyWith(candidateOnboarded: true));

  void _update(AccountProfile Function(AccountProfile) change) {
    final account = _current;
    if (account != null) account.profile = change(account.profile);
  }

  String _newId() =>
      '10000000-0000-0000-0000-${(_nextId++).toString().padLeft(12, '0')}';

  void dispose() => _events.close();
}

class _FakeAccount {
  _FakeAccount({
    required this.id,
    required this.password,
    required this.profile,
  });

  final String id;
  String? password;
  AccountProfile profile;
}
