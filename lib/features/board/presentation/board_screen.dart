import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Applicants: MosaicGrid of blind CandidateTiles from get_board, TriangleActions, filters, shortcuts.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-12, RC-13, RC-14, RC-17, RC-19.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Applicants',
      description:
          'Review applicants by technical match and explore their skills.',
      tasks: const ['RC-12', 'RC-13', 'RC-14', 'RC-17', 'RC-19'],
      stories: const [
        'US-40',
        'US-41',
        'US-43',
        'US-44',
        'US-45',
        'US-46',
        'US-48',
      ],
      params: {'jobId': jobId},
      links: [
        PageLink(
          'View candidate',
          Routes.candidateDetailFor(jobId, DemoIds.application),
          mode: LinkMode.push,
        ),
        PageLink(
          'Edit job details',
          Routes.jobDetailsFor(jobId),
          mode: LinkMode.push,
        ),
      ],
    );
  }
}
