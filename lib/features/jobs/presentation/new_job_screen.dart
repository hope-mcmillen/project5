import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// New job: Paste the raw job description; creates a DRAFT job and invokes parse-job.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-08.
class NewJobScreen extends StatelessWidget {
  const NewJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'New job',
      description: 'Start with a job description, then review the skills your team needs.',
      tasks: const ['RC-08'],
      stories: const ['US-34'],
      links: [
        PageLink('Review requirements', Routes.jobRequirementsFor(DemoIds.job)),
      ],
    );
  }
}
