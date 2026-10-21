import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';

/// Shown while the session and profile load, and when the profile can't be
/// loaded (with Retry and Sign out).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: profile.hasError && !profile.isLoading
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We couldn\'t load your account.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text('Check your connection and try again.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(profileProvider),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(authRepositoryProvider).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(
                  semanticsLabel: 'Loading your account',
                ),
        ),
      ),
    );
  }
}
