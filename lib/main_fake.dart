import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'app/fake_overrides.dart';

/// Start candidate screen development with no credentials or backend.
void main() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(
    ProviderScope(
      overrides: fakeRepositoryOverrides(),
      child: const ResuRhombusApp(),
    ),
  );
}
