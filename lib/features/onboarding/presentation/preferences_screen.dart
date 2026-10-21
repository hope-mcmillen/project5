import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/scaffold_hooks.dart';
import '../../../core/models/app_role.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Preferences: location, remote, job type, work authorization, salary floor
/// (the deck's hard filters). Used in onboarding and from the Profile tab.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-06, CA-08.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key, this.editing = false});

  /// false = onboarding step (finishes onboarding), true = edit from Profile.
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceholderPage(
      title: 'Job preferences',
      description:
          'Location, remote, job type, work authorization and an optional salary floor '
          '→ save_preferences RPC. These become hard filters in get_feed.',
      tasks: const ['CA-06', 'CA-08'],
      stories: const ['US-12'],
      params: {'Mode': editing ? 'edit (from Profile)' : 'onboarding'},
      links: [
        if (editing)
          const PageLink('Save', Routes.candidateProfile)
        else
          PageLink(
            'Start swiping',
            Routes.deck,
            onBefore: () => finishOnboardingForScaffold(ref, AppRole.candidate),
          ),
      ],
    );
  }
}
