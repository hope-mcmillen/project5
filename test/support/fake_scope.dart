import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:project5/app/fake_overrides.dart';

Widget fakeScope(
  Widget child, {
  List<Override> overrides = const [],
  bool simulateParsing = false,
}) => ProviderScope(
  overrides: {
    for (final override in [
      ...fakeRepositoryOverrides(
        latency: Duration.zero,
        simulateParsing: simulateParsing,
      ),
      ...overrides,
    ])
      override.origin: override,
  }.values.toList(),
  child: child,
);
