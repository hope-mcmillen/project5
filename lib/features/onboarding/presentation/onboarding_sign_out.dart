import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/account_menu.dart';

/// App bar "Sign out" for candidate onboarding.
///
/// The route guard keeps a signed-in candidate on onboarding until a profile
/// is confirmed, and the session survives restarts, so without this the app
/// reopens on onboarding every launch and Welcome is unreachable. Renders
/// nothing outside `/c/onboarding` (e.g. the Profile tab's resume page,
/// which already has Sign out on Profile).
class OnboardingSignOutAction extends ConsumerWidget {
  const OnboardingSignOutAction({super.key});

  static const _onboardingPrefix = '/c/onboarding';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!GoRouterState.of(context).uri.path.startsWith(_onboardingPrefix)) {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: () => signOutToWelcome(context, ref),
      child: const Text('Sign out'),
    );
  }
}
