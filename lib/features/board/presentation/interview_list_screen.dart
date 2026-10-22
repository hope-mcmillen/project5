import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Interviews: Advanced candidates with identity, email and signed resume link (resume-url function).
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-16, PL-23.
class InterviewListScreen extends StatelessWidget {
  const InterviewListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Interviews',
      description: 'Keep track of candidates you want to meet.',
      tasks: const ['RC-16', 'PL-23'],
      stories: const ['US-47', 'US-49'],
      links: [
        PageLink(
          'View candidate',
          Routes.candidateDetailFor(DemoIds.job, DemoIds.application),
        ),
      ],
    );
  }
}
