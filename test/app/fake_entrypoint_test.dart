import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project5/main_fake.dart' as fake;
import 'package:project5/features/auth/presentation/welcome_screen.dart';
import 'package:project5/features/deck/data/feed_repository.dart';
import 'package:project5/features/deck/data/fake_feed_repository.dart';

void main() {
  testWidgets('fake entry point starts without backend configuration', (
    tester,
  ) async {
    fake.main();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WelcomeScreen)),
    );
    expect(container.read(feedRepositoryProvider), isA<FakeFeedRepository>());
    expect(tester.takeException(), isNull);
  });
}
