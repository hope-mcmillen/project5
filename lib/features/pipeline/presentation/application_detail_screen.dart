import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Application: PipelineTimeline from status_events, Withdraw action, recruiter contact when Interview Requested.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-17, CA-18.
class ApplicationDetailScreen extends StatelessWidget {
  const ApplicationDetailScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Application',
      description: 'Review this application and follow its progress.',
      tasks: const ['CA-17', 'CA-18'],
      stories: const ['US-28', 'US-29'],
      params: {'applicationId': applicationId},
      links: [PageLink('Back to applications', Routes.pipeline)],
    );
  }
}
