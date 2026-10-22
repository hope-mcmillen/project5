import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/candidate_detail.dart';

/// One spoke per requirement, scored 0–1, with a "Candidate" legend
/// (RC-15). Falls back to bars with fewer than 3 requirements, which a
/// radar can't draw.
///
/// TODO(C9): swap for C's shared `RadarDeepDive(legendLabel: 'Candidate')`
/// once it lands.
class MatchRadar extends StatelessWidget {
  const MatchRadar({super.key, required this.breakdown});

  final List<BreakdownEntry> breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final summary = breakdown
        .map((e) => '${e.name} ${(e.score * 100).round()}%')
        .join(', ');

    if (breakdown.length < 3) {
      return Semantics(
        label: 'Skill match: $summary',
        excludeSemantics: true,
        child: Column(
          children: [
            for (final entry in breakdown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 110, child: Text(entry.name)),
                    Expanded(
                      child: LinearProgressIndicator(value: entry.score),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    return Semantics(
      label: 'Skill match radar: $summary',
      excludeSemantics: true,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.2,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 4,
                ticksTextStyle: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                ),
                tickBorderData: BorderSide(color: colors.outlineVariant),
                gridBorderData: BorderSide(color: colors.outlineVariant),
                radarBorderData: BorderSide(color: colors.outline),
                titleTextStyle: theme.textTheme.labelSmall,
                titlePositionPercentageOffset: 0.12,
                getTitle: (index, angle) =>
                    RadarChartTitle(text: breakdown[index].name),
                radarTouchData: RadarTouchData(enabled: false),
                dataSets: [
                  // Invisible full-score set pins the scale to 0–1.
                  RadarDataSet(
                    dataEntries: [
                      for (final _ in breakdown) const RadarEntry(value: 1),
                    ],
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    entryRadius: 0,
                  ),
                  RadarDataSet(
                    dataEntries: [
                      for (final entry in breakdown)
                        RadarEntry(value: entry.score),
                    ],
                    fillColor: colors.primary.withValues(alpha: 0.25),
                    borderColor: colors.primary,
                    borderWidth: 2,
                    entryRadius: 3,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, color: colors.primary),
              const SizedBox(width: 6),
              Text('Candidate', style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}
