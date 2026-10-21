import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../../ui/scaffold/placeholder_page.dart';

/// Company: Company info, verified badge, invite codes (generate / copy / revoke), sign out.
///
/// SCAFFOLD: placeholder body only. Replace it when implementing RC-18, PL-26.
class CompanySettingsScreen extends ConsumerWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaceholderPage(
      title: 'Company',
      description: 'Company info, verified badge, invite codes (generate / copy / revoke), sign out.',
      tasks: const ['RC-18', 'PL-26'],
      stories: const ['US-31', 'US-33'],
      links: [
        PageLink(
          'Sign out',
          Routes.welcome,
          onBefore: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }
}
