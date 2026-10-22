import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Applications: Every application with StatusChip, live via Realtime.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-17.
class PipelineScreen extends StatelessWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Applications',
      description:
          'Follow your applications and see where each opportunity stands.',
      tasks: const ['CA-17'],
      stories: const ['US-25', 'US-26'],
      links: [
        PageLink(
          'View application',
          Routes.applicationDetailFor(DemoIds.application),
          mode: LinkMode.push,
        ),
      ],
    );
  }
}
