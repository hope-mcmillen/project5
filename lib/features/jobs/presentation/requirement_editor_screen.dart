import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Requirements: RequirementEditor: Required/Preferred, min years, 15/8 limits, JD evidence → save_requirements.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-09a, RC-09b, AI-18.
class RequirementEditorScreen extends StatelessWidget {
  const RequirementEditorScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Requirements',
      description: 'RequirementEditor: Required/Preferred, min years, 15/8 limits, JD evidence → save_requirements.',
      tasks: const ['RC-09a', 'RC-09b', 'AI-18'],
      stories: const ['US-35', 'US-39'],
      params: {'jobId': jobId},
      links: [PageLink('Next: job details', Routes.jobDetailsFor(jobId))],
    );
  }
}
