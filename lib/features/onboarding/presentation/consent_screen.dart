import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';
import 'onboarding_sign_out.dart';

/// Before we start: Consent to resume processing and data use (PRD §5.1, A-6).
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-03.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Before we start',
      description: 'Review how your resume will be used to build your skills profile before continuing.',
      tasks: const ['CA-03'],
      stories: const ['US-07'],
      links: [PageLink('Agree and continue', Routes.candidateUpload)],
      actions: const [OnboardingSignOutAction()],
    );
  }
}
