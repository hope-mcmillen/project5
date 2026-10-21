import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'core/errors/app_failure.dart';
import 'app/fake_overrides.dart';

/// Runs the app on in-memory fakes, with no Supabase project needed:
/// `flutter run -t lib/main_fake.dart`.
void main() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: fakeRepositoryOverrides(),
      child: const ResuRhombusApp(),
    ),
  );
}
