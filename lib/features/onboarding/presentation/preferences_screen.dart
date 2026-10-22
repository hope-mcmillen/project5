import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Preferences: location, remote, job type, work authorization, salary floor
/// (the deck's hard filters). Used in onboarding and from the Profile tab.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-06, CA-08.
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key, this.editing = false});

  /// false = onboarding step (finishes onboarding), true = edit from Profile.
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Job preferences',
      description: 'Choose the locations, work arrangements, and roles that fit your next move.',
      tasks: const ['CA-06', 'CA-08'],
      stories: const ['US-12'],
      params: {'Mode': editing ? 'edit (from Profile)' : 'onboarding'},
      links: [
        if (editing)
          const PageLink('Save preferences', Routes.candidateProfile)
        else
          PageLink(
            'Start swiping',
            Routes.deck,
            onBefore: devSession.completeCandidateOnboarding,
          ),
      ],
    );
  }
}
