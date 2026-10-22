import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Match details: Job summary, RadarDeepDive (shared widget) and the plain-language gap list. Apply/Pass from here too.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing CA-16.
class DeepDiveScreen extends StatelessWidget {
  const DeepDiveScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Match details',
      description: 'See how your experience lines up with this role and where you can grow.',
      tasks: const ['CA-16'],
      stories: const ['US-23', 'US-24'],
      params: {'jobId': jobId},
      links: [PageLink('Back to deck', Routes.deck)],
    );
  }
}
