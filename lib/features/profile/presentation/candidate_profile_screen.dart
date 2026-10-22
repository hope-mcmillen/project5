import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Profile: Confirmed skills summary, links to preferences and resume re-upload, sign out, delete account.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-08, PL-09, PL-24.
class CandidateProfileScreen extends StatelessWidget {
  const CandidateProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Profile',
      description: 'Keep your experience up to date. Manage your preferences and update your resume here.',
      tasks: const ['CA-08', 'PL-09', 'PL-24'],
      stories: const ['US-04', 'US-13', 'US-50'],
      links: [
        PageLink(
          'Edit preferences',
          Routes.profilePreferences,
          mode: LinkMode.push,
        ),
        PageLink('Update resume', Routes.profileResume, mode: LinkMode.push),
        PageLink(
          'Sign out',
          Routes.welcome,
          onBefore: () => devSession.signOut(),
        ),
      ],
    );
  }
}
