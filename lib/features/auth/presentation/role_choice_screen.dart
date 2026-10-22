import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../core/models/app_role.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Choose your role: Shown to signed-in users with no role yet (e.g. first Google sign-in). Calls set_initial_role.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing PL-10, PL-11.
class RoleChoiceScreen extends StatelessWidget {
  const RoleChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Choose your role',
      description: 'Choose the workspace that matches what you want to do.',
      tasks: const ['PL-10', 'PL-11'],
      stories: const ['US-02'],
      links: [
        PageLink(
          'Continue as candidate',
          Routes.deck,
          onBefore: () => devSession.signIn(AppRole.candidate),
        ),
        PageLink(
          'Continue as recruiter',
          Routes.jobs,
          onBefore: () => devSession.signIn(AppRole.recruiter),
        ),
      ],
    );
  }
}
