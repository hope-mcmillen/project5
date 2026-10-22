import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/fake_overrides.dart';
import 'core/errors/app_failure.dart';
import 'core/logging/app_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logUncaughtErrors();

  // On web, keep the address bar in sync with push() too, so recruiters can
  // bookmark / share board and candidate URLs.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  // Clean /r/jobs/... URLs on web instead of /#/r/jobs/... (RC-21). Static
  // hosts need an SPA fallback to index.html: see docs/HOSTING.md.
  usePathUrlStrategy();

  AppLog.info(
    'startup',
    'supabase url=${Env.supabaseUrl.isEmpty ? '(missing)' : Env.supabaseUrl} '
        'key=${Env.anonKey.isEmpty ? '(missing)' : 'set'}',
  );
  if (!Env.isConfigured) {
    AppLog.warn('startup', 'not configured; pass --dart-define-from-file');
    runApp(const MissingConfigApp());
    return;
  }

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.anonKey);
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: candidateRepositoryOverrides(includeApplications: false),
      child: const ResuRhombusApp(),
    ),
  );
}

/// Sends framework and async errors that nothing caught to the log too.
void _logUncaughtErrors() {
  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    AppLog.error('flutter', 'uncaught', details.exception, details.stack);
    presentError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLog.error('async', 'uncaught', error, stack);
    return false;
  };
}

/// Shown when the app was started without `--dart-define-from-file`.
class MissingConfigApp extends StatelessWidget {
  const MissingConfigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Supabase isn\'t configured.\n\n'
              'Copy env/example.json to env/dev.json, fill in your URL and '
              'anon key, then run:\n'
              'flutter run --dart-define-from-file=env/dev.json\n\n'
              'Or run on fake data: flutter run -t lib/main_fake.dart',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
