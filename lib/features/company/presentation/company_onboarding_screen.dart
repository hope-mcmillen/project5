import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../auth/presentation/widgets/auth_layout.dart';
import '../../../app/account_menu.dart';

/// Set up your company: every recruiter belongs to exactly one company, so
/// they create a workspace or join one with an invite code (US-30, US-32).
class CompanyOnboardingScreen extends ConsumerWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = [
      _OptionCard(
        icon: Icons.add_business_outlined,
        title: 'Create a company',
        subtitle: 'Start a new workspace. You\'ll be its owner.',
        onTap: () => context.push(Routes.createCompany),
      ),
      _OptionCard(
        icon: Icons.group_add_outlined,
        title: 'Join with an invite code',
        subtitle: 'A teammate sent you an 8-character code.',
        onTap: () => context.push(Routes.joinCompany),
      ),
    ];
    return AuthLayout(
      accountMenu: true,
      title: 'Set up your company',
      subtitle:
          'You\'ll post jobs and review applicants from one shared workspace.',
      showBack: false,
      maxWidth: 720,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 600
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: options[0]),
                    const SizedBox(width: 16),
                    Expanded(child: options[1]),
                  ],
                )
              : Column(
                  children: [
                    options[0],
                    const SizedBox(height: 16),
                    options[1],
                  ],
                ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => signOutToWelcome(context, ref),
            child: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
