import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Job details: Location, remote, job type, sponsorship, salary range; publish / pause / close (set_job_status).
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-10, RC-11.
class JobDetailsScreen extends StatelessWidget {
  const JobDetailsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Job details',
      description: 'Location, remote, job type, sponsorship, salary range; publish / pause / close (set_job_status).',
      tasks: const ['RC-10', 'RC-11'],
      stories: const ['US-36', 'US-37'],
      params: {'jobId': jobId},
      links: [
        PageLink('Edit requirements', Routes.jobRequirementsFor(jobId)),
        PageLink('[Fake] Publish → open board', Routes.boardFor(jobId)),
        PageLink('Save as draft', Routes.jobs),
      ],
    );
  }
}
