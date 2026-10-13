import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Set a new password: Opened from the reset email (AuthChangeEvent.passwordRecovery). Calls updateUser.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing PL-09, PL-10.
class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Set a new password',
      description: 'Opened from the reset email (AuthChangeEvent.passwordRecovery). Calls updateUser.',
      tasks: const ['PL-09', 'PL-10'],
      stories: const ['US-05'],
      links: [PageLink('Save and sign in', Routes.signIn)],
    );
  }
}
