import 'package:flutter/material.dart';

import '../../../../core/models/job_status.dart';

/// A job's status as an icon + label chip (never color alone).
///
/// TODO(RC-02): swap for C2's shared `StatusChip` once it lands.
class JobStatusChip extends StatelessWidget {
  const JobStatusChip({super.key, required this.status});

  final JobStatus status;

  static String labelOf(JobStatus status) => switch (status) {
    JobStatus.draft => 'Draft',
    JobStatus.open => 'Open',
    JobStatus.paused => 'Paused',
    JobStatus.closed => 'Closed',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (status) {
      JobStatus.draft => (
        Icons.edit_note,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      JobStatus.open => (
        Icons.check_circle_outline,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      JobStatus.paused => (
        Icons.pause_circle_outline,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      JobStatus.closed => (
        Icons.lock_outline,
        colors.surfaceContainerHigh,
        colors.onSurfaceVariant,
      ),
    };
    return Semantics(
      label: 'Status: ${labelOf(status)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              labelOf(status),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// "3 new" / "5 total" counters.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    required this.label,
    this.highlight = false,
  });

  final int count;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: highlight && count > 0
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count $label',
        style: theme.textTheme.labelMedium?.copyWith(
          color: highlight && count > 0
              ? colors.onTertiaryContainer
              : colors.onSurfaceVariant,
          fontWeight: highlight && count > 0 ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}
