import 'package:flutter/material.dart';

import '../../core/models/candidate_models.dart';
import '../theme/rr_tokens.dart';
import 'rhombus_mark.dart';
import 'status_chip.dart';

String applicationDate(BuildContext context, DateTime date) {
  final local = date.toLocal();
  return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${TimeOfDay.fromDateTime(local).format(context)}';
}

class PipelineTimeline extends StatelessWidget {
  const PipelineTimeline({
    super.key,
    required this.application,
    required this.events,
  });
  final Application application;
  final List<StatusEvent> events;
  @override
  Widget build(BuildContext context) {
    final ordered = [...events]
      ..sort((a, b) {
        final order = a.createdAt.compareTo(b.createdAt);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    if (!ordered.any((e) => e.toStatus == ApplicationStatus.applied)) {
      ordered.insert(
        0,
        StatusEvent(
          id: 0,
          applicationId: application.id,
          toStatus: ApplicationStatus.applied,
          createdAt: application.createdAt,
        ),
      );
    }
    // The current row can arrive before its history query catches up. Keep the
    // visible timeline consistent without inventing intermediate transitions.
    if (ordered.last.toStatus != application.status) {
      ordered.add(
        StatusEvent(
          id: -1,
          applicationId: application.id,
          toStatus: application.status,
          createdAt: application.updatedAt,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ordered.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: RRSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: RRSpace.sm,
                    right: RRSpace.md,
                  ),
                  child: Column(
                    children: [
                      RhombusMark(
                        size: RRSpace.lg,
                        color: i == ordered.length - 1
                            ? RRColors.matchStrong
                            : RRColors.inkMuted,
                      ),
                      if (i < ordered.length - 1)
                        const SizedBox(
                          height: RRSpace.xl,
                          child: VerticalDivider(color: RRColors.framework),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(status: ordered[i].toStatus),
                      const SizedBox(height: RRSpace.sm),
                      Text(
                        applicationDate(context, ordered[i].createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
