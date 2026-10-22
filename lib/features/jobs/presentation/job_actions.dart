import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/state_views.dart';
import '../../../core/models/job_status.dart';
import '../data/job_repository.dart';

/// Verb for moving a job to [status].
String actionLabel(JobStatus status) => switch (status) {
  JobStatus.open => 'Publish',
  JobStatus.paused => 'Pause',
  JobStatus.closed => 'Close',
  JobStatus.draft => 'Revert to draft',
};

/// Changes a job's status from the list or the details screen. Closing
/// asks for confirmation first, because it ends every open application.
/// Returns true on success.
Future<bool> changeJobStatus(
  BuildContext context,
  WidgetRef ref, {
  required String jobId,
  required String title,
  required JobStatus to,
}) async {
  if (to == JobStatus.closed) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close "$title"?'),
        content: const Text(
          'Closing is permanent. The job leaves the deck and every candidate '
          'still in progress is told the job has closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close job'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
  }
  try {
    await ref.read(jobRepositoryProvider).setStatus(jobId, to);
  } catch (error) {
    if (context.mounted) showMessage(context, messageOf(error));
    return false;
  }
  ref
    ..invalidate(jobsProvider)
    ..invalidate(jobProvider(jobId));
  if (context.mounted) {
    showMessage(context, switch (to) {
      JobStatus.open => '"$title" is live.',
      JobStatus.paused => '"$title" is paused.',
      JobStatus.closed => '"$title" is closed.',
      JobStatus.draft => '"$title" updated.',
    });
  }
  return true;
}
