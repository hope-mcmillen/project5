import 'package:flutter/material.dart';

import '../../../app/dev_session.dart';
import '../../../app/routes.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Create company: Name, website, logo → create_company RPC. Caller becomes owner; verified badge computed.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-07, PL-13, PL-15.
class CreateCompanyScreen extends StatelessWidget {
  const CreateCompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Create company',
      description: 'Name, website, logo → create_company RPC. Caller becomes owner; verified badge computed.',
      tasks: const ['RC-07', 'PL-13', 'PL-15'],
      stories: const ['US-30', 'US-33'],
      links: [
        PageLink(
          '[Fake] Create company',
          Routes.jobs,
          onBefore: () => devSession.completeCompanyOnboarding(),
        ),
      ],
    );
  }
}
