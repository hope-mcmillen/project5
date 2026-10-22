import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Forgot password: Email field that sends a reset link (resetPasswordForEmail).
///
/// SCAFFOLD: placeholder body only. Replace it when implementing PL-09, PL-10.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Forgot password',
      description: 'Recover access to your account and choose a new password.',
      tasks: const ['PL-09', 'PL-10'],
      stories: const ['US-05'],
      links: [
        PageLink('Reset password', Routes.resetPassword),
        PageLink('Back to sign in', Routes.signIn),
      ],
    );
  }
}
