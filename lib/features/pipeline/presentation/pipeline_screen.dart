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
      description: 'Every application with StatusChip, live via Realtime.',
      tasks: const ['CA-17'],
      stories: const ['US-25', 'US-26'],
      links: [
        PageLink(
          '[Fake] Open an application',
          Routes.applicationDetailFor(DemoIds.application),
          mode: LinkMode.push,
        ),
      ],
    );
  }
}
