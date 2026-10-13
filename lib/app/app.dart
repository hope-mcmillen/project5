import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dev_session.dart';
import 'router.dart';

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
      // TODO(RC-01): replace with buildRRTheme() from lib/ui/theme/.
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4E8098),
        scaffoldBackgroundColor: const Color(0xFFFCF7F8),
      ),
      routerConfig: _router,
    );
  }
}
