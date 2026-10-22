import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/theme/rr_theme.dart';
import 'dev_session.dart';
import 'route_session.dart';
import 'router.dart';
import 'routes.dart';

class ResuRhombusApp extends ConsumerStatefulWidget {
  const ResuRhombusApp({super.key, this.session});

  /// Isolated routing for component previews and existing candidate tests.
  /// Normal and fake entry points use the auth-driven router.
  final DevSession? session;
  @override
  ConsumerState<ResuRhombusApp> createState() => _ResuRhombusAppState();
}

class _ResuRhombusAppState extends ConsumerState<ResuRhombusApp> {
  GoRouter? _previewRouter;
  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _previewRouter = buildRouter(
        session: () => RouteSession(
          status: session.isSignedIn
              ? SessionStatus.signedIn
              : SessionStatus.signedOut,
          role: session.role,
          candidateOnboarded: session.candidateOnboarded,
          recruiterHasCompany: session.recruiterHasCompany,
        ),
        refreshListenable: session,
        initialLocation: Routes.welcome,
      );
    }
  }

  @override
  void dispose() {
    _previewRouter?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp.router(
      title: 'ResuRhombus',
      debugShowCheckedModeBanner: false,
      theme: buildRRTheme(),
      routerConfig: _previewRouter ?? ref.watch(routerProvider),
    );
    return widget.session == null
        ? app
        : DevSessionScope(session: widget.session!, child: app);
  }
}
