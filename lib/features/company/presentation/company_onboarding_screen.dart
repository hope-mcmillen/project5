import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Set up your company: Recruiters must belong to one company: create a new workspace or join with an invite code.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-07.
class CompanyOnboardingScreen extends StatelessWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Set up your company',
      description: 'Create a workspace for your team or join an existing company with an invite code.',
      tasks: const ['RC-07'],
      stories: const ['US-30', 'US-32'],
      links: [
        PageLink('Create a company', Routes.createCompany, mode: LinkMode.push),
        PageLink(
          'Join with an invite code',
          Routes.joinCompany,
          mode: LinkMode.push,
        ),
      ],
    );
  }
}
