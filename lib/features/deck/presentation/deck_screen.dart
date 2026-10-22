import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Your deck: SwipeDeck of JobCards from get_feed, DeckActionBar, UndoToast, PassReasonChips, empty state.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-10, CA-11, CA-12, CA-13, CA-14, CA-15, CA-19.
class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Your deck',
      description: 'Explore opportunities that fit your experience. Open a role to see your match in more detail.',
      tasks: const [
        'CA-10',
        'CA-11',
        'CA-12',
        'CA-13',
        'CA-14',
        'CA-15',
        'CA-19',
      ],
      stories: const [
        'US-14',
        'US-15',
        'US-16',
        'US-17',
        'US-18',
        'US-19',
        'US-20',
        'US-21',
      ],
      links: [
        PageLink(
          'View match details',
          Routes.deepDiveFor(DemoIds.job),
          mode: LinkMode.push,
        ),
        PageLink('Edit job preferences', Routes.profilePreferences),
        PageLink('Update resume', Routes.profileResume),
      ],
    );
  }
}
