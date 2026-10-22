import 'package:flutter_test/flutter_test.dart';
import 'package:project5/app/env.dart';

void main() {
  test('startup accepts publishable and legacy anon settings', () {
    const publishable = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    const legacy = String.fromEnvironment('SUPABASE_ANON_KEY');
    const url = String.fromEnvironment('SUPABASE_URL');
    expect(Env.anonKey, publishable.isNotEmpty ? publishable : legacy);
    expect(Env.isConfigured, url.isNotEmpty && Env.anonKey.isNotEmpty);
  });
}
