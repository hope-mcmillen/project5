import '../errors/app_failure.dart';

/// Controls shared by screen-development fakes. No network or paid AI calls.
abstract class FakeRepository {
  FakeRepository({this.latency = const Duration(milliseconds: 300)});
  final Duration latency;
  AppFailure? failNext;

  Future<void> call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
  }
}
