import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Company: Company info, verified badge, invite codes (generate / copy / revoke), sign out.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-18, PL-26.
class CompanySettingsScreen extends StatelessWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Company',
      description: 'Manage your company workspace and team access.',
      tasks: const ['RC-18', 'PL-26'],
      stories: const ['US-31', 'US-33'],
      links: [
        PageLink(
          'Sign out',
          Routes.welcome,
          onBefore: () => devSession.signOut(),
        ),
      ],
    );
  }
}
