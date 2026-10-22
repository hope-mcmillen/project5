import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/models/job_status.dart';
import '../../jobs/data/job_repository.dart';
import '../data/board_repository.dart';
import '../domain/candidate_detail.dart';
import 'candidate_actions.dart';
import 'widgets/board_marks.dart';

/// One advanced candidate and the job they were advanced for.
class InterviewEntry {
  const InterviewEntry({
    required this.jobId,
    required this.jobTitle,
    required this.detail,
  });

  final String jobId;
  final String jobTitle;
  final CandidateDetail detail;
}

/// Advanced candidates across the company's jobs, or one job. Rows from
/// `get_interview_list` don't say which job they belong to, so it's asked
/// per job.
final interviewsProvider = FutureProvider.family<List<InterviewEntry>, String?>(
  (ref, jobId) async {
    final jobs = await ref.watch(jobsProvider.future);
    final board = ref.watch(boardRepositoryProvider);
    final targets = [
      for (final job in jobs)
        if (job.status != JobStatus.draft && (jobId == null || job.id == jobId))
          job,
    ];
    final lists = await Future.wait([
      for (final job in targets) board.interviewList(job.id),
    ]);
    final entries =
        [
          for (var i = 0; i < targets.length; i++)
            for (final detail in lists[i])
              InterviewEntry(
                jobId: targets[i].id,
                jobTitle: targets[i].title ?? 'Untitled job',
                detail: detail,
              ),
        ]..sort(
          (a, b) =>
              b.detail.tile.matchScore.compareTo(a.detail.tile.matchScore),
        );
    return entries;
  },
);

/// Interviews: everyone advanced, with Email and Resume, filterable by job
/// (RC-16, US-47).
class InterviewListScreen extends ConsumerStatefulWidget {
  const InterviewListScreen({super.key});

  @override
  ConsumerState<InterviewListScreen> createState() =>
      _InterviewListScreenState();
}

class _InterviewListScreenState extends ConsumerState<InterviewListScreen> {
  String? _jobId;

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(jobsProvider).value ?? const [];
    final interviews = ref.watch(interviewsProvider(_jobId));
    final published = [
      for (final job in jobs)
        if (job.status != JobStatus.draft) job,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Interviews')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: DropdownButtonFormField<String?>(
                  initialValue: _jobId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Job'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All jobs'),
                    ),
                    for (final job in published)
                      DropdownMenuItem(
                        value: job.id,
                        child: Text(
                          job.title ?? 'Untitled job',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) => setState(() => _jobId = id),
                ),
              ),
            ),
          ),
          Expanded(
            child: switch (interviews) {
              AsyncValue(:final value?) when value.isEmpty => const EmptyView(
                icon: Icons.event_available_outlined,
                title: 'No interviews yet',
                message: 'Advance a candidate to see them here.',
              ),
              AsyncValue(:final value?) => RefreshIndicator(
                onRefresh: () => ref.refresh(interviewsProvider(_jobId).future),
                child: LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 900
                      ? _Table(entries: value)
                      : _List(entries: value),
                ),
              ),
              AsyncValue(:final error?) => ErrorView(
                error: error,
                onRetry: () => ref
                  ..invalidate(jobsProvider)
                  ..invalidate(interviewsProvider(_jobId)),
              ),
              _ => const LoadingBlocks(),
            },
          ),
        ],
      ),
    );
  }
}

String _name(InterviewEntry e) =>
    e.detail.identity?.label ?? e.detail.tile.handle;

void _open(BuildContext context, InterviewEntry e) => context.push(
  Routes.candidateDetailFor(e.jobId, e.detail.tile.applicationId),
);

class _ContactButtons extends ConsumerWidget {
  const _ContactButtons({required this.entry});

  final InterviewEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = entry.detail.identity?.email;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: email == null
              ? null
              : () => emailCandidate(context, ref, email),
          icon: const Icon(Icons.email_outlined),
          label: const Text('Email'),
        ),
        TextButton.icon(
          onPressed: () =>
              openResume(context, ref, entry.detail.tile.applicationId),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Resume'),
        ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.entries});

  final List<InterviewEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final entry = entries[i];
        final tile = entry.detail.tile;
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context, entry),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name(entry),
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              entry.jobTitle,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      BoardScoreBadge(score: tile.matchScore, band: tile.band),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ContactButtons(entry: entry),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.entries});

  final List<InterviewEntry> entries;

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
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Job')),
              DataColumn(label: Text('Score')),
              DataColumn(label: Text('Contact')),
            ],
            rows: [
              for (final entry in entries)
                DataRow(
                  cells: [
                    DataCell(
                      Text(_name(entry)),
                      onTap: () => _open(context, entry),
                    ),
                    DataCell(Text(entry.jobTitle)),
                    DataCell(
                      BoardScoreBadge(
                        score: entry.detail.tile.matchScore,
                        band: entry.detail.tile.band,
                      ),
                    ),
                    DataCell(_ContactButtons(entry: entry)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
