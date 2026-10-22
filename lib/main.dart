import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/fake_overrides.dart';

void main() {
  // On web, keep the address bar in sync with push() too, so recruiters can
  // bookmark / share board and candidate URLs.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // C3 uses local repositories until the real C5 integration lands.
  runApp(
    ProviderScope(
      overrides: fakeRepositoryOverrides(),
      child: const ResuRhombusApp(),
    ),
  );
}
