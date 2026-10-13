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
      description: 'Shown to signed-in users with no role yet (e.g. first Google sign-in). Calls set_initial_role.',
      tasks: const ['PL-10', 'PL-11'],
      stories: const ['US-02'],
      links: [
        PageLink(
          '[Fake] I\'m a candidate',
          Routes.deck,
          onBefore: () => devSession.signIn(AppRole.candidate),
        ),
        PageLink(
          '[Fake] I\'m a recruiter',
          Routes.jobs,
          onBefore: () => devSession.signIn(AppRole.recruiter),
        ),
      ],
    );
  }
}
