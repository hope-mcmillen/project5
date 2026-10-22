import 'package:flutter/material.dart';

import '../../core/models/application_status.dart';
import '../theme/rr_tokens.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final ApplicationStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      ApplicationStatus.applied => ('Applied', Icons.check_circle_outline),
      ApplicationStatus.underReview => (
        'Under review',
        Icons.visibility_outlined,
      ),
      ApplicationStatus.interviewRequested => (
        'Interview requested',
        Icons.event_available_outlined,
      ),
      ApplicationStatus.notSelected => (
        'Not selected',
        Icons.remove_circle_outline,
      ),
      ApplicationStatus.withdrawn => ('Withdrawn', Icons.undo),
      ApplicationStatus.jobClosed => ('Job closed', Icons.lock_outline),
    };
    return Semantics(
      label: 'Application status: $label',
      excludeSemantics: true,
      child: Chip(
        avatar: Icon(icon, color: RRColors.inkMuted, size: RRSpace.lg),
        label: Text(label),
        backgroundColor: RRColors.canvas,
      ),
    );
  }
}
