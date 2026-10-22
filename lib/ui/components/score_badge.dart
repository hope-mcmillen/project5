import 'package:flutter/material.dart';

import '../../core/models/candidate_enums.dart';
import '../theme/rr_tokens.dart';
import 'rhombus_mark.dart';

enum ScoreBadgeSize { small, medium, large }

class ScoreBadge extends StatelessWidget {
  const ScoreBadge({
    super.key,
    required this.score,
    this.size = ScoreBadgeSize.medium,
  }) : assert(score >= 0 && score <= 100);
  final int score;
  final ScoreBadgeSize size;
  @override
  Widget build(BuildContext context) {
    final band = ScoreBand.fromScore(score);
    final dimension = switch (size) {
      ScoreBadgeSize.small => RRSpace.badgeSmall,
      ScoreBadgeSize.medium => RRSpace.badgeMedium,
      ScoreBadgeSize.large => RRSpace.badgeLarge,
    };
    final color = switch (band) {
      ScoreBand.strong || ScoreBand.good => RRColors.matchStrong,
      _ => RRColors.inkMuted,
    };
    return Semantics(
      label: 'Match score $score percent, ${band.db}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              RhombusMark(
                size:
                    dimension * 1.6 * MediaQuery.textScalerOf(context).scale(1),
                color: color,
                variant: band == ScoreBand.strong
                    ? RhombusVariant.filled
                    : band == ScoreBand.stretch
                    ? RhombusVariant.dashed
                    : RhombusVariant.outlined,
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(
                  begin:
                      size == ScoreBadgeSize.large &&
                          !MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : score.toDouble(),
                  end: score.toDouble(),
                ),
                duration:
                    size == ScoreBadgeSize.large &&
                        !MediaQuery.disableAnimationsOf(context)
                    ? const Duration(milliseconds: 600)
                    : Duration.zero,
                builder: (context, value, child) => Text(
                  '${value.round()}%',
                  style:
                      (switch (size) {
                        ScoreBadgeSize.small => Theme.of(
                          context,
                        ).textTheme.labelLarge,
                        ScoreBadgeSize.medium => Theme.of(
                          context,
                        ).textTheme.titleLarge,
                        ScoreBadgeSize.large => Theme.of(
                          context,
                        ).textTheme.displaySmall,
                      })?.copyWith(
                        color: band == ScoreBand.strong
                            ? RRColors.surface
                            : color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RRSpace.xs),
          Text(
            band.db,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
