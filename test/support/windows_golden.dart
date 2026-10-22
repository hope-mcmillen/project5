import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Baselines are rendered on Windows with Flutter 3.47.1. Native font
/// rasterization differs on Linux even when the bundled fonts are identical.
/// Only the pixel assertion is platform-specific: the surrounding layout,
/// accessibility, interaction and timing assertions still run on every host.
/// The required Windows CI job runs the same tests with exact comparisons.
Future<void> expectWindowsGolden(Finder finder, String path) async {
  if (!Platform.isWindows) {
    debugPrint(
      'Pixel baseline $path is checked by the Windows visual-tests job.',
    );
    return;
  }
  await expectLater(finder, matchesGoldenFile(path));
}
