import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Candidate: Blind detail: RadarDeepDive + skill evidence; opening sets Under Review. Advance / reject actions.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-15.
class CandidateDetailScreen extends StatelessWidget {
  const CandidateDetailScreen({
    super.key,
    required this.jobId,
    required this.applicationId,
  });

  final String jobId;
  final String applicationId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Candidate',
      description: 'Blind detail: RadarDeepDive + skill evidence; opening sets Under Review. Advance / reject actions.',
      tasks: const ['RC-15'],
      stories: const ['US-42', 'US-43', 'US-44'],
      params: {'jobId': jobId, 'applicationId': applicationId},
      links: [
        PageLink('[Fake] Advance → interviews', Routes.interviews),
        PageLink('Back to board', Routes.boardFor(jobId)),
      ],
    );
  }
}
