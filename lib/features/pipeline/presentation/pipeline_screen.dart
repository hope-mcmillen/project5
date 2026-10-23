import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/collage.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/components/status_chip.dart';
import '../../../ui/components/empty_state.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../data/application_repository.dart';
import 'pipeline_providers.dart';
import '../../../ui/components/pipeline_timeline.dart';

class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => BrandedPage(
    title: 'Applications',
    headline: 'track.',
    accent: RRColors.pink,
    motif: TileMotif.arrow,
    description: ref.watch(applicationRepositoryProvider).isDemo
        ? 'Follow your applications. This preview uses local demo data.'
        : 'Follow your applications as recruiters review them.',
    child: ref
        .watch(myApplicationsProvider)
        .when(
          loading: () => const ShimmerShape(),
          error: (_, _) => Column(
            children: [
              const Text(
                'We could not refresh your applications. Check your connection and try again.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(myApplicationsProvider),
                child: const Text('Retry applications'),
              ),
            ],
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
                    for (final (index, application) in applications.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: RRSpace.md),
                        child: Card(
                          key: ValueKey(application.id),
                          child: Padding(
                            padding: const EdgeInsets.all(RRSpace.lg),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ApplicationTile(index: index),
                                const SizedBox(width: RRSpace.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        application.jobTitle ??
                                            'Job application',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: RRSpace.sm),
                                      Text(
                                        application.companyName ?? 'Company',
                                      ),
                                      Semantics(
                                        liveRegion: true,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: StatusChip(
                                            status: application.status,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: RRSpace.sm),
                                      Text(
                                        'Updated ${applicationDate(context, application.updatedAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      if (hasNoResponse(
                                        application,
                                        DateTime.now(),
                                      ))
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            top: RRSpace.sm,
                                          ),
                                          child: Text('No response yet'),
                                        ),
                                      TextButton(
                                        onPressed: () => context.push(
                                          Routes.applicationDetailFor(
                                            application.id,
                                          ),
                                        ),
                                        child: const Text('View application'),
                                      ),
                                    ],
                                  ),
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

/// A small decorative tile that varies down the list, like the collage.
class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.index});
  final int index;

  static const _tiles = [
    (RRColors.lemon, TileShape.circle, TileMotif.rhombus, RRColors.ink),
    (RRColors.violet, TileShape.halfRight, TileMotif.ring, RRColors.lemon),
    (RRColors.deck, TileShape.square, TileMotif.triangle, RRColors.ink),
    (RRColors.pink, TileShape.leaf, TileMotif.asterisk, RRColors.ink),
  ];

  @override
  Widget build(BuildContext context) {
    final (color, shape, motif, motifColor) = _tiles[index % _tiles.length];
    return CollageTile(
      color: color,
      shape: shape,
      motif: motif,
      motifColor: motifColor,
      width: RRSpace.xxxl,
      height: RRSpace.xxxl,
    );
  }
}
