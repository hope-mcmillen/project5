import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Upload your resume: Pick a PDF/DOCX (≤ 5 MB), upload to Storage, invoke parse-resume. Also used for re-upload from Profile.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-03, CA-07.
class UploadResumeScreen extends StatelessWidget {
  const UploadResumeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Upload your resume',
      preferMenuButton: true,
      description: 'Pick a PDF/DOCX (≤ 5 MB), upload to Storage, invoke parse-resume. Also used for re-upload from Profile.',
      tasks: const ['CA-03', 'CA-07'],
      stories: const ['US-07', 'US-13'],
      links: [
        PageLink('[Fake] Upload resume', Routes.parseProgress(DemoIds.resume)),
      ],
    );
  }
}
