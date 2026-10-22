import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'app_log.dart';

/// Logs providers that fail (a repository call that threw, a stream that
/// errored), tagged `provider`, with the page the user was on. Add to every
/// `ProviderScope` through [appProviderObservers].
final class ProviderLogger extends ProviderObserver {
  const ProviderLogger();

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLog.warn(
      'provider',
      '${describeProvider(context.provider)} failed on ${AppLog.page}',
      error,
    );
  }
}

/// `profileProvider`, or `resumeStatusProvider(parse-1)` for families.
String describeProvider(ProviderBase<Object?> provider) {
  final name = provider.name ?? provider.runtimeType.toString();
  final argument = provider.argument;
  return argument == null ? name : '$name($argument)';
}

const appProviderObservers = <ProviderObserver>[ProviderLogger()];

AppLifecycleListener? _lifecycle;

/// Logs app lifecycle changes (resumed, inactive, paused, …), tagged `app`.
/// Useful on phones, where the app is often backgrounded mid-flow.
void logAppLifecycle() {
  _lifecycle ??= AppLifecycleListener(
    onStateChange: (state) =>
        AppLog.info('app', 'lifecycle ${state.name} on ${AppLog.page}'),
  );
}
