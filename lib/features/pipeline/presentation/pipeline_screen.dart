import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/components/status_chip.dart';
import '../../../ui/components/empty_state.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../../../core/models/application.dart';
import '../data/application_repository.dart';

final myApplicationsProvider = StreamProvider.autoDispose<List<Application>>(
  (ref) => ref.watch(applicationRepositoryProvider).watchMine(),
);

class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => BrandedPage(
    title: 'Applications',
    description: 'Follow the opportunities you have applied for. These applications are local demo data.',
    child: ref
        .watch(myApplicationsProvider)
        .when(
          loading: () => const ShimmerShape(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(myApplicationsProvider),
            child: const Text('Retry applications'),
          ),
          data: (applications) => applications.isEmpty
              ? EmptyState(
                  title: 'No applications yet',
                  message: 'Apply to a role from your job deck.',
                  actionLabel: 'Explore jobs',
                  onAction: () => context.go(Routes.deck),
                )
              : Column(
                  children: [
                    for (final application in applications)
                      Padding(
                        padding: const EdgeInsets.only(bottom: RRSpace.md),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(RRSpace.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  application.jobTitle ?? 'Job application',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: RRSpace.sm),
                                Text(application.companyName ?? 'Company'),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: StatusChip(status: application.status),
                                ),
                                TextButton(
                                  onPressed: () => context.push(
                                    Routes.applicationDetailFor(application.id),
                                  ),
                                  child: const Text('View application'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
