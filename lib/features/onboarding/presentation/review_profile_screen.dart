import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Review your skills: SkillReviewList: edit years, remove, add from taxonomy, view evidence. Confirms via confirm_profile.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-05a, CA-05b, CA-08.
class ReviewProfileScreen extends StatelessWidget {
  const ReviewProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Review your skills',
      description: 'Check your skills and experience before continuing to your job preferences.',
      tasks: const ['CA-05a', 'CA-05b', 'CA-08'],
      stories: const ['US-09', 'US-10', 'US-11'],
      links: [PageLink('Confirm skills', Routes.candidatePreferences)],
    );
  }
}
