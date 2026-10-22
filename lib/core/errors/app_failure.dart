/// Repository failure that screens can handle without backend SDK types.
class AppFailure implements Exception {
  const AppFailure(
    this.code, [
    this.message = 'Something went wrong. Please try again.',
  ]);
  final String code;
  final String message;
  @override
  String toString() => 'AppFailure($code): $message';
}
