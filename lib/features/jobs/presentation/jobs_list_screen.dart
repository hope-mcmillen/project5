import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/models/job_status.dart';
import '../../company/presentation/widgets/company_header.dart';
import '../../../app/shells.dart';
import '../data/job_repository.dart';
import '../domain/job_summary.dart';
import 'job_actions.dart';
import 'widgets/job_status_chip.dart';

/// Jobs: every job in the company with new/total applicant counts, and
/// publish / pause / close actions (RC-06, US-37, US-38). A list on phones,
/// a table from 900 px.
class JobsListScreen extends ConsumerWidget {
  const JobsListScreen({super.key});

  static const tableBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    Future<void> refresh() => ref.refresh(jobsProvider.future);

    return Scaffold(
      appBar: AppBar(
        // On phones there's no rail, so the company shows under the title.
        title: MediaQuery.sizeOf(context).width < RecruiterShell.railBreakpoint
            ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('Jobs'), CompanySubtitle()],
              )
            : const Text('Jobs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.newJob),
              icon: const Icon(Icons.add),
              label: const Text('New job'),
            ),
          ),
        ],
      ),
      body: switch (jobs) {
        AsyncValue(:final value?) when value.isEmpty => RefreshIndicator(
          onRefresh: refresh,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: constraints.maxHeight,
                child: EmptyView(
                  icon: Icons.work_outline,
                  title: 'Post your first job',
                  message:
                      'Paste a job description and we\'ll pull out the '
                      'skills to match on.',
                  action: FilledButton(
                    onPressed: () => context.push(Routes.newJob),
                    child: const Text('New job'),
                  ),
                ),
              ),
            ),
          ),
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: refresh,
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= tableBreakpoint
                ? _JobsTable(jobs: value)
                : _JobsList(jobs: value),
          ),
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(jobsProvider),
        ),
        _ => const LoadingBlocks(),
      },
    );
  }
}

/// Where tapping a job goes: drafts to their requirements, others to the
/// board.
void _open(BuildContext context, JobSummary job) => context.push(
  job.status == JobStatus.draft
      ? Routes.jobRequirementsFor(job.id)
      : Routes.boardFor(job.id),
);

String _title(JobSummary job) =>
    (job.title?.trim().isNotEmpty ?? false) ? job.title! : 'Untitled job';

class _JobsList extends StatelessWidget {
  const _JobsList({required this.jobs});

  final List<JobSummary> jobs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final job = jobs[i];
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context, job),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(job),
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            JobStatusChip(status: job.status),
                            CountBadge(
                              count: job.newCount,
                              label: 'new',
                              highlight: true,
                            ),
                            CountBadge(count: job.totalCount, label: 'total'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _JobMenu(job: job),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JobsTable extends StatelessWidget {
  const _JobsTable({required this.jobs});

  final List<JobSummary> jobs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('New'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final job in jobs)
                DataRow(
                  cells: [
                    DataCell(
                      Text(_title(job)),
                      onTap: () => _open(context, job),
                    ),
                    DataCell(JobStatusChip(status: job.status)),
                    DataCell(
                      CountBadge(
                        count: job.newCount,
                        label: 'new',
                        highlight: true,
                      ),
                    ),
                    DataCell(Text('${job.totalCount}')),
                    DataCell(_JobMenu(job: job)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { board, requirements, details, status }

class _JobMenu extends ConsumerWidget {
  const _JobMenu({required this.job});

  final JobSummary job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transitions = allowedTransitions(job.status).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return PopupMenuButton<(_MenuAction, JobStatus?)>(
      tooltip: 'Actions for ${_title(job)}',
      onSelected: (choice) async {
        switch (choice) {
          case (_MenuAction.board, _):
            context.push(Routes.boardFor(job.id));
          case (_MenuAction.requirements, _):
            context.push(Routes.jobRequirementsFor(job.id));
          case (_MenuAction.details, _):
            context.push(Routes.jobDetailsFor(job.id));
          case (_MenuAction.status, final status?):
            await changeJobStatus(
              context,
              ref,
              jobId: job.id,
              title: _title(job),
              to: status,
            );
          case (_MenuAction.status, null):
            break;
        }
      },
      itemBuilder: (context) => [
        if (job.status != JobStatus.draft)
          const PopupMenuItem(
            value: (_MenuAction.board, null),
            child: Text('View applicants'),
          ),
        if (job.status != JobStatus.closed) ...[
          const PopupMenuItem(
            value: (_MenuAction.requirements, null),
            child: Text('Edit requirements'),
          ),
          const PopupMenuItem(
            value: (_MenuAction.details, null),
            child: Text('Edit details'),
          ),
        ],
        if (transitions.isNotEmpty) const PopupMenuDivider(),
        for (final status in transitions)
          PopupMenuItem(
            value: (_MenuAction.status, status),
            child: Text(actionLabel(status)),
          ),
      ],
    );
  }
}
