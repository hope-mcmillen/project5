import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Join company: 8-character invite code → join_company RPC.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-07, PL-13, PL-15.
class JoinCompanyScreen extends StatelessWidget {
  const JoinCompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Join company',
      description: 'Use your company invitation to join the team.',
      tasks: const ['RC-07', 'PL-13', 'PL-15'],
      stories: const ['US-32'],
      links: [
        PageLink(
          'Join with code',
          Routes.jobs,
          onBefore: () => devSession.completeCompanyOnboarding(),
        ),
      ],
    );
  }
}
