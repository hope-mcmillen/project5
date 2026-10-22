import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/state_views.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/application_status.dart';
import '../data/board_repository.dart';
import '../domain/candidate_detail.dart';
import 'board_controller.dart';
import 'board_screen.dart';
import 'candidate_actions.dart';
import 'widgets/board_marks.dart';
import 'widgets/match_radar.dart';

/// Opening marks the application Under Review (`open_application`), then
/// loads `get_candidate_detail`.
final candidateDetailProvider = FutureProvider.family<CandidateDetail, String>((
  ref,
  applicationId,
) async {
  final repo = ref.watch(boardRepositoryProvider);
  try {
    await repo.openApplication(applicationId);
  } on AppFailure catch (e) {
    // Already advanced (or decided): nothing to open.
    if (e.code != 'invalid_transition') rethrow;
  }
  return repo.candidateDetail(applicationId);
});

/// Candidate detail: score, radar, requirement-by-requirement breakdown and
/// skill evidence, with Advance and Not a fit. Identity and the resume
/// appear only after advancing (RC-15, US-42).
class CandidateDetailScreen extends ConsumerWidget {
  const CandidateDetailScreen({
    super.key,
    required this.jobId,
    required this.applicationId,
  });

  final String jobId;
  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(candidateDetailProvider(applicationId));
    // Keep an open board in step with what the server now says.
    ref.listen(candidateDetailProvider(applicationId), (_, next) {
      final value = next.value;
      if (value != null && ref.exists(boardControllerProvider(jobId))) {
        ref
            .read(boardControllerProvider(jobId).notifier)
            .markStatus(applicationId, value.tile.status);
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.value?.identity?.label ??
              detail.value?.tile.handle ??
              'Applicant',
        ),
      ),
      body: switch (detail) {
        AsyncValue(:final value?) => _Body(jobId: jobId, detail: value),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(candidateDetailProvider(applicationId)),
        ),
        _ => const LoadingBlocks(count: 4, height: 120),
      },
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.jobId, required this.detail});

  final String jobId;
  final CandidateDetail detail;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  String get _id => widget.detail.tile.applicationId;

  bool get _boardOpen => ref.exists(boardControllerProvider(widget.jobId));

  BoardController get _board =>
      ref.read(boardControllerProvider(widget.jobId).notifier);

  Future<void> _advance() async {
    final note = await showAdvanceDialog(
      context,
      handle: widget.detail.tile.handle,
    );
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final text = note.isEmpty ? null : note;
      if (_boardOpen) {
        await _board.advance(_id, note: text);
      } else {
        await ref.read(boardRepositoryProvider).advance(_id, note: text);
      }
      ref.invalidate(candidateDetailProvider(_id));
      if (mounted) showMessage(context, 'Interview requested.');
    } catch (error) {
      if (mounted) showMessage(context, messageOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final handle = widget.detail.tile.handle;
    final repo = ref.read(boardRepositoryProvider);
    final board = _boardOpen ? _board : null;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (board != null) {
        await board.reject(_id);
      } else {
        await repo.reject(_id);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, messageOf(error));
      }
      return;
    }
    ref.invalidate(candidateDetailProvider(_id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('Not a fit · $handle'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                (board != null ? board.undoReject(_id) : repo.undoReject(_id))
                    .catchError((Object e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(messageOf(e))),
                      );
                    }),
          ),
        ),
      );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final tile = detail.tile;
    final theme = Theme.of(context);
    final decidable =
        tile.status == ApplicationStatus.applied ||
        tile.status == ApplicationStatus.underReview;
    final years = tile.totalYears % 1 == 0
        ? '${tile.totalYears.toInt()}'
        : tile.totalYears.toStringAsFixed(1);

    final header = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const RhombusAvatar(size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.identity?.label ?? tile.handle,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text('$years years of experience'),
                      Text(
                        _statusLabel(tile.status),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                BoardScoreBadge(score: tile.matchScore, band: tile.band),
              ],
            ),
            if (detail.identity != null) ...[
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        emailCandidate(context, ref, detail.identity!.email),
                    icon: const Icon(Icons.email_outlined),
                    label: Text(detail.identity!.email),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => openResume(context, ref, _id),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Resume'),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Name, email and resume unlock when you advance.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (decidable) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _advance,
                    icon: const Icon(Icons.change_history),
                    label: const Text('Advance'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: _busy ? null : _reject,
                    icon: const Icon(Icons.details),
                    label: const Text('Not a fit'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final radar = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: detail.breakdown.isEmpty
            ? const Text('No requirement breakdown for this application.')
            : MatchRadar(breakdown: detail.breakdown),
      ),
    );

    final breakdown = _Section(
      title: 'Requirements',
      children: [
        for (final entry in detail.breakdown) _BreakdownRow(entry: entry),
      ],
    );

    final evidence = _Section(
      title: 'Skill evidence',
      children: [
        if (detail.skills.isEmpty)
          const Text('No reviewed skills shared.')
        else
          for (final skill in detail.skills)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(skill.name),
              subtitle: skill.evidence == null ? null : Text(skill.evidence!),
              trailing: skill.years == null
                  ? null
                  : Text(
                      '${skill.years! % 1 == 0 ? skill.years!.toInt() : skill.years} yrs',
                    ),
            ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [header, const SizedBox(height: 16), radar],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [breakdown, const SizedBox(height: 16), evidence],
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            header,
            const SizedBox(height: 16),
            radar,
            const SizedBox(height: 16),
            breakdown,
            const SizedBox(height: 16),
            evidence,
          ],
        );
      },
    );
  }
}

String _statusLabel(ApplicationStatus status) => switch (status) {
  ApplicationStatus.applied => 'New applicant',
  ApplicationStatus.underReview => 'Under review',
  ApplicationStatus.interviewRequested => 'Interview requested',
  ApplicationStatus.notSelected => 'Not a fit',
  ApplicationStatus.withdrawn => 'Withdrawn',
  ApplicationStatus.jobClosed => 'Job closed',
};

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.entry});

  final BreakdownEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    String yrs(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';
    final how = switch (entry.matchedVia) {
      'exact' => 'Has it',
      'related' => 'Related skill',
      _ => 'Missing',
    };
    final years = entry.minYears > 0
        ? ' · needs ${yrs(entry.minYears)} yrs, has '
              '${entry.candidateYears == null ? 'unknown' : yrs(entry.candidateYears!)}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            entry.isGap ? Icons.remove_circle_outline : Icons.check_circle,
            size: 20,
            color: entry.isGap ? colors.error : colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.name}${entry.required ? '' : ' (preferred)'}',
                  style: theme.textTheme.bodyLarge,
                ),
                Text('$how$years', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            child: LinearProgressIndicator(
              value: entry.score,
              semanticsLabel: '${entry.name} match',
              semanticsValue: '${(entry.score * 100).round()}%',
            ),
          ),
        ],
      ),
    );
  }
}
