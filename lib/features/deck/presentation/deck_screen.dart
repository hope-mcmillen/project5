import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/models/candidate_models.dart';
import '../../../ui/components/branded_page.dart';
import '../../../ui/components/collage.dart';
import '../../../ui/components/empty_state.dart';
import '../../../ui/components/error_banner.dart';
import '../../../ui/components/shimmer_shape.dart';
import '../../../ui/components/swipe_deck.dart';
import '../../../ui/theme/rr_tokens.dart';
import 'feed_controller.dart';
import 'swipe_feedback.dart';
import '../domain/swipe_receipt.dart';
import '../../../ui/components/deck_action_bar.dart';
import '../../onboarding/presentation/preferences_controller.dart';

class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});
  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  final _deck = GlobalKey<SwipeDeckState>();
  bool _swiping = false;
  String? _restoreToken;
  SwipeDirection? _restoreDirection;
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
      headline: 'swipe.',
      accent: RRColors.violet,
      motif: TileMotif.ring,
      description: 'Swipe right to apply or left to pass. Every gesture also has a button.',
      footer: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .45,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value?.lastSwipe case final SwipeReceipt receipt) ...[
                if (receipt.direction == SwipeDirection.left &&
                    !value!.reasonSaved)
                  PassReasonChips(
                    key: ValueKey('reason-${receipt.swipeId}'),
                    receipt: receipt,
                    busy: value.busy || value.reasonSaving,
                    onReason: (reason) => ref
                        .read(feedControllerProvider.notifier)
                        .setReason(receipt.swipeId, reason),
                  ),
                UndoToast(
                  key: ValueKey('undo-${receipt.swipeId}'),
                  receipt: receipt,
                  busy: value!.busy || value.reasonSaving || _swiping,
                  onUndo: () async {
                    final ok = await ref
                        .read(feedControllerProvider.notifier)
                        .undo(receipt.swipeId);
                    if (ok && mounted) {
                      setState(() {
                        _restoreToken = receipt.swipeId;
                        _restoreDirection = receipt.direction;
                      });
                    }
                  },
                ),
              ],
              if (active)
                DeckActionBar(
                  onPass: _swiping || value.busy
                      ? null
                      : () => _deck.currentState?.commit(SwipeDirection.left),
                  onDetails: _swiping || value.busy ? null : details,
                  onApply: _swiping || value.busy
                      ? null
                      : () => _deck.currentState?.commit(SwipeDirection.right),
                ),
            ],
          ),
        ),
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
            if (value.cards.isEmpty && value.cursor != null) ...[
              TextButton(
                onPressed: value.busy
                    ? null
                    : () =>
                          ref.read(feedControllerProvider.notifier).loadMore(),
                child: Text(value.busy ? 'Loading jobs…' : 'Load more jobs'),
              ),
            ] else if (value.cards.isEmpty) ...[
              const _StretchRoles(),
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
                      restoreToken: _restoreToken,
                      restoreDirection: _restoreDirection,
                      cards: value.cards,
                      onBusyChanged: (busy) {
                        if (mounted) setState(() => _swiping = busy);
                      },
                      onDetails: (job) =>
                          context.push(Routes.deepDiveFor(job.jobId)),
                      onCommit: (direction) async {
                        setState(() => _restoreToken = null);
                        final ok = await ref
                            .read(feedControllerProvider.notifier)
                            .commit(direction);
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

class _StretchRoles extends ConsumerWidget {
  const _StretchRoles();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(preferencesControllerProvider);
    return state.when(
      loading: () => const ShimmerShape(height: 56),
      error: (_, _) => TextButton(
        onPressed: () => ref.invalidate(preferencesControllerProvider),
        child: const Text('Retry preferences'),
      ),
      data: (value) => Column(
        children: [
          if (value.error != null) ErrorBanner(message: value.error!),
          SwitchListTile(
            title: const Text('Show stretch roles'),
            subtitle: const Text(
              'Include roles below a 50% match. Your other preferences still apply.',
            ),
            value: value.preferences.includeStretch ?? false,
            onChanged: value.saving
                ? null
                : (include) => ref
                      .read(preferencesControllerProvider.notifier)
                      .setStretch(include),
          ),
        ],
      ),
    );
  }
}
