import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dev_session.dart';
import 'router.dart';
import '../ui/theme/rr_theme.dart';

class ResuRhombusApp extends StatefulWidget {
  const ResuRhombusApp({super.key, this.session});

  /// Injectable for tests. Defaults to the app-wide fake session.
  final DevSession? session;

  @override
  State<ResuRhombusApp> createState() => _ResuRhombusAppState();
}

class _ResuRhombusAppState extends State<ResuRhombusApp> {
  late final GoRouter _router = buildRouter(widget.session ?? devSession);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ResuRhombus',
      debugShowCheckedModeBanner: false,
      theme: buildRRTheme(),
      routerConfig: _router,
    );
  }
}
