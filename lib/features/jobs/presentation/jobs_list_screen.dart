import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Jobs: Company jobs with status and new/total applicant counts (company_jobs_overview).
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-06, RC-11.
class JobsListScreen extends StatelessWidget {
  const JobsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Jobs',
      description:
          'Manage your job posts and review the people who have applied.',
      tasks: const ['RC-06', 'RC-11'],
      stories: const ['US-37', 'US-38'],
      links: [
        PageLink('New job', Routes.newJob, mode: LinkMode.push),
        PageLink(
          'View applicants',
          Routes.boardFor(DemoIds.job),
          mode: LinkMode.push,
        ),
        PageLink(
          'Edit job details',
          Routes.jobDetailsFor(DemoIds.job),
          mode: LinkMode.push,
        ),
      ],
    );
  }
}
