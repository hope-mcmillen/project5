import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';

void main() {
  // On web, keep the address bar in sync with push() too, so recruiters can
  // bookmark / share board and candidate URLs.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // TODO(PL-02): Supabase.initialize(url, anonKey) from --dart-define values.
  // TODO(PL-02): wrap in ProviderScope once Riverpod is added.
  runApp(const ResuRhombusApp());
}
