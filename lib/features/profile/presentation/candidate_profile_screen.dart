import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/dev_session.dart';
import '../../auth/data/auth_repository.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../data/profile_repository.dart';

class CandidateProfileScreen extends ConsumerWidget {
  const CandidateProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => BrandedPage(
    title: 'Profile',
    description:
        'Your skills and preferences, ready for your next opportunity.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ref
            .watch(candidateProfileProvider)
            .when(
              loading: () => const ShimmerShape(),
              error: (_, _) => TextButton(
                onPressed: () => ref.invalidate(candidateProfileProvider),
                child: const Text('Retry profile'),
              ),
              data: (version) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(RRSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        version?.confirmed == true
                            ? 'Confirmed skills'
                            : 'Skills to review',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: RRSpace.md),
                      if (version == null || version.candidateSkills.isEmpty)
                        const Text(
                          'Add your skills to start finding matching roles.',
                        ),
                      for (final skill in version?.candidateSkills ?? [])
                        Padding(
                          padding: const EdgeInsets.only(bottom: RRSpace.sm),
                          child: Text(
                            '${skill.rawName} · ${skill.years == null ? 'Years not specified' : '${skill.years!.toStringAsFixed(1)} years'}',
                          ),
                        ),
                      const SizedBox(height: RRSpace.md),
                      FilledButton(
                        onPressed: () => context.go(Routes.candidateReview),
                        child: const Text('Review skills'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: RRSpace.lg),
        OutlinedButton(
          onPressed: () => context.push(Routes.profilePreferences),
          child: const Text('Edit preferences'),
        ),
        const SizedBox(height: RRSpace.md),
        OutlinedButton(
          onPressed: () => context.push(Routes.profileResume),
          child: const Text('Update resume'),
        ),
        const SizedBox(height: RRSpace.md),
        TextButton(
          onPressed: () async {
            await ref.read(authRepositoryProvider).signOut();
            if (context.mounted) {
              DevSessionScope.maybeOf(context)?.signOut();
              context.go(Routes.welcome);
            }
          },
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
}
