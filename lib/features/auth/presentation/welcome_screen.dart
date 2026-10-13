import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Welcome: Role choice: "I'm looking for a job" / "I'm hiring" as two RoleChoiceCards (PRD §4).
///
/// SCAFFOLD: placeholder body only. Replace it when implementing PL-10.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.preselectedRole});

  final String? preselectedRole;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Welcome',
      description: 'Role choice: "I\'m looking for a job" / "I\'m hiring" as two RoleChoiceCards (PRD §4).',
      tasks: const ['PL-10'],
      stories: const ['US-01'],
      params: {'Pre-selected role': preselectedRole ?? 'none'},
      links: [
        PageLink(
          'I\'m looking for a job → Sign up',
          '${Routes.signUp}?role=candidate',
        ),
        PageLink('I\'m hiring → Sign up', '${Routes.signUp}?role=recruiter'),
        PageLink(
          'I already have an account → Sign in',
          Routes.signIn,
          mode: LinkMode.push,
        ),
      ],
    );
  }
}
