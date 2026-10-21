import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/app_role.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_models.dart';
import 'dev_session.dart';
import 'router.dart';
import 'routes.dart';

class ResuRhombusApp extends ConsumerStatefulWidget {
  const ResuRhombusApp({super.key, this.session});

  /// Injectable for tests. Defaults to the app-wide fake session.
  final DevSession? session;

  @override
  ConsumerState<ResuRhombusApp> createState() => _ResuRhombusAppState();
}

class _ResuRhombusAppState extends ConsumerState<ResuRhombusApp> {
  late final DevSession _session = widget.session ?? devSession;
  late final GoRouter _router = buildRouter(_session);

  /// TEMPORARY (until PL-11): mirrors the real auth profile into the
  /// scaffold's [DevSession] so the existing redirect rules route signed-in
  /// users. D3 replaces this with a router that reads the providers.
  void _syncSession(AccountProfile? profile) {
    final role = profile?.role;
    if (role == null) {
      if (_session.isSignedIn) _session.signOut();
      // Signed in without a role (first Google sign-in): pick one.
      if (profile != null) _router.go(Routes.roleChoice);
      return;
    }
    if (_session.role != role) _session.signIn(role);
    if (role == AppRole.candidate && profile!.candidateOnboarded) {
      _session.completeCandidateOnboarding();
    }
    if (role == AppRole.recruiter && profile!.recruiterHasCompany) {
      _session.completeCompanyOnboarding();
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (_, next) {
      if (next case AsyncData(:final value)) _syncSession(value);
    });
    return MaterialApp.router(
      title: 'ResuRhombus',
      debugShowCheckedModeBanner: false,
      // TODO(RC-01): replace with buildRRTheme() from lib/ui/theme/.
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4E8098),
        scaffoldBackgroundColor: const Color(0xFFFCF7F8),
      ),
      routerConfig: _router,
    );
  }
}
