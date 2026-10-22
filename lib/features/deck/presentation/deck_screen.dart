import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/candidate_models.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/empty_state.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/components/swipe_deck.dart';
import '../../../ui/theme/rr_tokens.dart';
import 'feed_controller.dart';

class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});
  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  final _deck = GlobalKey<SwipeDeckState>();
  bool _swiping = false;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider);
    final value = state.asData?.value;
    final active = value != null && value.cards.isNotEmpty;
    void details() {
      if (active) context.push(Routes.deepDiveFor(value.cards.first.jobId));
    }

    return BrandedPage(
      title: 'Your deck',
      description: 'Swipe right to apply or left to pass. Every gesture also has a button.',
      footer: !active
          ? null
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: RRSpace.md,
              runSpacing: RRSpace.sm,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RRColors.pass,
                    minimumSize: const Size(72, 56),
                  ),
                  onPressed: _swiping || value.busy
                      ? null
                      : () => _deck.currentState?.commit(SwipeDirection.left),
                  icon: const Icon(Icons.close),
                  label: const Text('Pass'),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(72, 56),
                  ),
                  onPressed: _swiping || value.busy ? null : details,
                  child: const Text('Details'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 56),
                  ),
                  onPressed: _swiping || value.busy
                      ? null
                      : () => _deck.currentState?.commit(SwipeDirection.right),
                  icon: const Icon(Icons.check),
                  label: const Text('Apply'),
                ),
              ],
            ),
      child: state.when(
        loading: () => const ShimmerShape(height: RRSpace.badgeLarge * 4),
        error: (_, _) => Column(
          children: [
            const ErrorBanner(message: 'We could not load your job deck.'),
            TextButton(
              onPressed: () => ref.invalidate(feedControllerProvider),
              child: const Text('Retry jobs'),
            ),
          ],
        ),
        data: (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.error != null) ...[
              ErrorBanner(message: value.error!),
              TextButton(
                onPressed: () => context.go(Routes.candidateReview),
                child: const Text('Review skills'),
              ),
              const SizedBox(height: RRSpace.lg),
            ],
            if (value.cards.isEmpty) ...[
              EmptyState(
                title: 'Your deck is all squared away',
                message: 'No more roles match your current preferences.',
                actionLabel: 'Edit job preferences',
                onAction: () => context.go(Routes.profilePreferences),
              ),
              OutlinedButton(
                onPressed: () => context.go(Routes.profileResume),
                child: const Text('Update resume'),
              ),
              TextButton(
                onPressed: () => ref.invalidate(feedControllerProvider),
                child: const Text('Refresh jobs'),
              ),
            ] else ...[
              Align(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SizedBox(
                    height: math.max(
                      440,
                      math.min(560, MediaQuery.sizeOf(context).height * .55),
                    ),
                    child: SwipeDeck(
                      key: _deck,
                      cards: value.cards,
                      onBusyChanged: (busy) {
                        if (mounted) setState(() => _swiping = busy);
                      },
                      onDetails: (job) =>
                          context.push(Routes.deepDiveFor(job.jobId)),
                      onCommit: (direction) async {
                        final title = value.cards.first.title;
                        final ok = await ref
                            .read(feedControllerProvider.notifier)
                            .commit(direction);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                direction == SwipeDirection.right
                                    ? 'Demo application saved for $title'
                                    : 'Passed on $title',
                              ),
                            ),
                          );
                        }
                        return ok;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: RRSpace.xxl),
            ],
            Text(
              'Demo jobs · Apply saves a local application. No applications are sent to employers.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: RRColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
