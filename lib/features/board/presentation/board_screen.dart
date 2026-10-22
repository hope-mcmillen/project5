import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../../jobs/data/job_repository.dart';
import '../domain/board_tile.dart';
import 'board_controller.dart';
import 'widgets/candidate_tile.dart';
import 'widgets/mosaic_grid.dart';

/// Applicants: a ranked grid of blind tiles with one-click advance and
/// reject (RC-12, RC-13, US-40 to US-45).
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardControllerProvider(jobId));
    final title = ref.watch(jobProvider(jobId)).value?.displayTitle;
    final controller = ref.read(boardControllerProvider(jobId).notifier);

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Applicants')),
      body: switch (board) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(count: value.tiles.length, more: value.hasMore),
              ),
              if (value.tiles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.grid_view,
                    title: 'No applicants yet',
                    message:
                        'When candidates swipe right on this job they appear '
                        'here, best match first.',
                  ),
                )
              else
                MosaicGrid(
                  tiles: value.tiles,
                  itemBuilder: (context, tile) =>
                      _Tile(jobId: jobId, tile: tile),
                ),
              if (value.hasMore)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: () =>
                            controller.loadMore().catchError((Object e) {
                              if (context.mounted) {
                                showMessage(context, messageOf(e));
                              }
                            }),
                        child: const Text('Load more'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(boardControllerProvider(jobId)),
        ),
        _ => const LoadingBlocks(count: 4, height: 180),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.more});

  final int count;
  final bool more;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$count${more ? '+' : ''} '
            '${count == 1 && !more ? 'applicant' : 'applicants'}',
            style: theme.textTheme.titleMedium,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Sorted by Match',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.jobId, required this.tile});

  final String jobId;
  final BoardTile tile;

  BoardController _controller(WidgetRef ref) =>
      ref.read(boardControllerProvider(jobId).notifier);

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    final note = await showAdvanceDialog(context, handle: tile.handle);
    if (note == null || !context.mounted) return;
    ref.read(selectedTileProvider.notifier).clear();
    try {
      await _controller(ref)
          .advance(tile.applicationId, note: note.isEmpty ? null : note);
      if (context.mounted) {
        showMessage(context, 'Interview requested for ${tile.handle}.');
      }
    } catch (error) {
      if (context.mounted) showMessage(context, messageOf(error));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = _controller(ref);
    ref.read(selectedTileProvider.notifier).clear();
    // Show Undo straight away; the reject request runs underneath.
    showMessage(
      context,
      'Not a fit · ${tile.handle}',
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () =>
            controller.undoReject(tile.applicationId).catchError((Object e) {
              if (context.mounted) showMessage(context, messageOf(e));
            }),
      ),
    );
    try {
      await controller.reject(tile.applicationId);
    } catch (error) {
      if (context.mounted) showMessage(context, messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTileProvider) == tile.applicationId;
    return CandidateTile(
      tile: tile,
      showActions: selected,
      onToggleActions: () =>
          ref.read(selectedTileProvider.notifier).toggle(tile.applicationId),
      onOpen: () =>
          context.push(Routes.candidateDetailFor(jobId, tile.applicationId)),
      onAdvance: () => _advance(context, ref),
      onReject: () => _reject(context, ref),
    );
  }
}

/// Asks for an optional interview note. Returns null when cancelled, or
/// the note ('' for none).
Future<String?> showAdvanceDialog(
  BuildContext context, {
  required String handle,
}) => showDialog<String>(
  context: context,
  builder: (_) => _AdvanceDialog(handle: handle),
);

class _AdvanceDialog extends StatefulWidget {
  const _AdvanceDialog({required this.handle});

  final String handle;

  @override
  State<_AdvanceDialog> createState() => _AdvanceDialogState();
}

class _AdvanceDialogState extends State<_AdvanceDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Advance ${widget.handle}?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'They\'ll see "Interview requested", and you\'ll see their '
              'name, email and resume.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              autofocus: true,
              maxLength: 2000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Note for the candidate (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _note.text.trim()),
          child: const Text('Advance'),
        ),
      ],
    );
  }
}
