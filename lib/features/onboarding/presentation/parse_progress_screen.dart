import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Reading your resume: PrismUploadProgress driven by the resumes.status Realtime stream. Failure state offers manual skills.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-04, CA-07, CA-09.
class ParseProgressScreen extends StatelessWidget {
  const ParseProgressScreen({super.key, required this.resumeId});

  final String resumeId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Reading your resume',
      description: 'PrismUploadProgress driven by the resumes.status Realtime stream. Failure state offers manual skills.',
      tasks: const ['CA-04', 'CA-07', 'CA-09'],
      stories: const ['US-08', 'US-11'],
      params: {'resumeId': resumeId},
      links: [
        PageLink('[Fake] Parsing finished', Routes.candidateReview),
        PageLink(
          '[Fake] Parsing failed → add skills manually',
          Routes.candidateReview,
        ),
        PageLink('Try another file', Routes.candidateUpload),
      ],
    );
  }
}
