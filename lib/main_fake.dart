import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'core/errors/app_failure.dart';
import 'app/fake_overrides.dart';

/// Runs the app on in-memory fakes, with no Supabase project needed:
/// `flutter run -t lib/main_fake.dart`.
void main() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  // Clean /r/jobs/... URLs on web instead of /#/r/jobs/... (RC-21). Static
  // hosts need an SPA fallback to index.html: see docs/HOSTING.md.
  usePathUrlStrategy();
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: fakeRepositoryOverrides(),
      child: const ResuRhombusApp(),
    ),
  );
}
