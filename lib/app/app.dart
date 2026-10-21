import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class ResuRhombusApp extends ConsumerWidget {
  const ResuRhombusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ResuRhombus',
      debugShowCheckedModeBanner: false,
      // TODO(RC-01): replace with buildRRTheme() from lib/ui/theme/.
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4E8098),
        scaffoldBackgroundColor: const Color(0xFFFCF7F8),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
