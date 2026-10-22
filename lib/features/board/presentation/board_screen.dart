import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../../jobs/data/job_repository.dart';
import '../../jobs/domain/requirement.dart';
import '../domain/board_filters.dart';
import '../domain/board_tile.dart';
import 'board_controller.dart';
import 'widgets/candidate_tile.dart';
import 'widgets/mosaic_grid.dart';

/// The job's requirements, for the skill filter chips.
final boardRequirementsProvider =
    FutureProvider.family<List<RequirementDraft>, String>(
      (ref, jobId) => ref.watch(jobRepositoryProvider).requirements(jobId),
    );

/// Applicants: a ranked grid of blind tiles with one-click advance and
/// reject (RC-12, RC-13, US-40 to US-45), filters that keep the ranking
/// (RC-17) and keyboard triage (RC-19).
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key, required this.jobId, this.query = const {}});

  final String jobId;

  /// The route's query parameters, holding the filters.
  final Map<String, String> query;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _NextTile extends Intent {
  const _NextTile(this.step);
  final int step;
}

class _AdvanceTile extends Intent {
  const _AdvanceTile();
}

class _RejectTile extends Intent {
  const _RejectTile();
}

class _OpenTile extends Intent {
  const _OpenTile();
}

class _ShowHelp extends Intent {
  const _ShowHelp();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  final _focusNodes = <String, FocusNode>{};
  List<BoardTile> _visible = const [];

  String get _jobId => widget.jobId;

  @override
  void initState() {
    super.initState();
    _syncFiltersFromUrl();
  }

  @override
  void didUpdateWidget(BoardScreen old) {
    super.didUpdateWidget(old);
    _syncFiltersFromUrl();
  }

  /// The URL is the source of truth for filters (refresh-safe on web).
  void _syncFiltersFromUrl() {
    final fromUrl = BoardFilters.fromQuery(widget.query);
    if (fromUrl == ref.read(boardFiltersProvider(_jobId))) return;
    // Providers can't change while widgets build.
    Future.microtask(() {
      if (mounted) ref.read(boardFiltersProvider(_jobId).notifier).set(fromUrl);
    });
  }

  void _setFilters(BoardFilters filters) {
    ref.read(boardFiltersProvider(_jobId).notifier).set(filters);
    context.replace(
      Uri(
        path: Routes.boardFor(_jobId),
        queryParameters: filters.isEmpty ? null : filters.toQuery(),
      ).toString(),
    );
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _nodeFor(String id) =>
      _focusNodes.putIfAbsent(id, () => FocusNode(debugLabel: 'tile $id'));

  int get _focusedIndex => _visible.indexWhere(
    (t) => _focusNodes[t.applicationId]?.hasFocus ?? false,
  );

  BoardTile? get _focused {
    final i = _focusedIndex;
    return i == -1 ? null : _visible[i];
  }

  void _move(int step) {
    if (_visible.isEmpty) return;
    final i = _focusedIndex;
    final next = i == -1 ? 0 : (i + step).clamp(0, _visible.length - 1);
    _nodeFor(_visible[next].applicationId).requestFocus();
  }

  /// After a tile leaves (reject), keep focus near where it was.
  void _focusAfterRemoval(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _visible.isEmpty) return;
      final next = index.clamp(0, _visible.length - 1);
      _nodeFor(_visible[next].applicationId).requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardControllerProvider(_jobId));
    final filters = ref.watch(boardFiltersProvider(_jobId));
    final title = ref.watch(jobProvider(_jobId)).value?.displayTitle;
    final controller = ref.read(boardControllerProvider(_jobId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Applicants'),
        actions: [
          IconButton(
            tooltip: 'Keyboard shortcuts',
            icon: const Icon(Icons.keyboard_outlined),
            onPressed: () => showShortcutHelp(context),
          ),
        ],
      ),
      body: switch (board) {
        AsyncValue(:final value?) => _content(value, filters, controller),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(boardControllerProvider(_jobId)),
        ),
        _ => const LoadingBlocks(count: 4, height: 180),
      },
    );
  }

  Widget _content(
    BoardState value,
    BoardFilters filters,
    BoardController controller,
  ) {
    _visible = filters.apply(value.tiles);
    final grid = RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              shown: _visible.length,
              total: value.tiles.length,
              more: value.hasMore,
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterBar(
              jobId: _jobId,
              filters: filters,
              onChanged: _setFilters,
            ),
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
          else if (_visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(
                icon: Icons.filter_alt_off_outlined,
                title: 'No applicants match these filters',
                message: 'Loosen a filter to see more of the ranking.',
                action: OutlinedButton(
                  onPressed: () => _setFilters(BoardFilters.empty),
                  child: const Text('Clear filters'),
                ),
              ),
            )
          else
            MosaicGrid(
              tiles: _visible,
              itemBuilder: (context, tile) => _Tile(
                jobId: _jobId,
                tile: tile,
                focusNode: _nodeFor(tile.applicationId),
                onRemoved: () => _focusAfterRemoval(
                  _visible.indexWhere(
                    (t) => t.applicationId == tile.applicationId,
                  ),
                ),
              ),
            ),
          if (value.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () =>
                        controller.loadMore().catchError((Object e) {
                          if (mounted) showMessage(context, messageOf(e));
                        }),
                    child: const Text('Load more'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // RC-19 shortcuts. They only fire while focus is on the board; typing
    // in a dialog's text field never reaches them.
    return Shortcuts(
      shortcuts: const {
        CharacterActivator('j'): _NextTile(1),
        CharacterActivator('k'): _NextTile(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _NextTile(1),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _NextTile(-1),
        CharacterActivator('a'): _AdvanceTile(),
        CharacterActivator('r'): _RejectTile(),
        SingleActivator(LogicalKeyboardKey.enter): _OpenTile(),
        CharacterActivator('?'): _ShowHelp(),
      },
      child: Actions(
        actions: {
          _NextTile: CallbackAction<_NextTile>(
            onInvoke: (intent) => _move(intent.step),
          ),
          _AdvanceTile: CallbackAction<_AdvanceTile>(
            onInvoke: (_) {
              final tile = _focused;
              if (tile != null) advanceTile(context, ref, _jobId, tile);
              return null;
            },
          ),
          _RejectTile: CallbackAction<_RejectTile>(
            onInvoke: (_) {
              final tile = _focused;
              if (tile == null) return null;
              final index = _focusedIndex;
              rejectTile(context, ref, _jobId, tile);
              _focusAfterRemoval(index);
              return null;
            },
          ),
          _OpenTile: CallbackAction<_OpenTile>(
            onInvoke: (_) {
              final tile = _focused;
              if (tile != null) {
                context.push(
                  Routes.candidateDetailFor(_jobId, tile.applicationId),
                );
              }
              return null;
            },
          ),
          _ShowHelp: CallbackAction<_ShowHelp>(
            onInvoke: (_) => showShortcutHelp(context),
          ),
        },
        child: FocusTraversalGroup(child: Focus(autofocus: true, child: grid)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.shown, required this.total, required this.more});

  final int shown;
  final int total;
  final bool more;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = shown == total
        ? '$total${more ? '+' : ''} '
              '${total == 1 && !more ? 'applicant' : 'applicants'}'
        : '$shown of $total${more ? '+' : ''} applicants';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(count, style: theme.textTheme.titleMedium),
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

/// Skill chips from the job's requirements, plus min years and min score.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.jobId,
    required this.filters,
    required this.onChanged,
  });

  final String jobId;
  final BoardFilters filters;
  final ValueChanged<BoardFilters> onChanged;

  static const _years = [1.0, 2.0, 3.0, 5.0];
  static const _scores = [50, 70, 85];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills =
        ref.watch(boardRequirementsProvider(jobId)).value ?? const [];
    String yrs(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final r in skills)
            FilterChip(
              label: Text(r.skill.name),
              selected: filters.skills.contains(r.skill.name),
              onSelected: (_) => onChanged(filters.toggleSkill(r.skill.name)),
            ),
          PopupMenuButton<double?>(
            tooltip: 'Minimum years',
            onSelected: (v) => onChanged(filters.withMinYears(v)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Any experience')),
              for (final y in _years)
                PopupMenuItem(value: y, child: Text('${yrs(y)}+ years')),
            ],
            child: IgnorePointer(
              child: FilterChip(
                label: Text(
                  filters.minYears == null
                      ? 'Years'
                      : '${yrs(filters.minYears!)}+ years',
                ),
                selected: filters.minYears != null,
                onSelected: (_) {},
              ),
            ),
          ),
          PopupMenuButton<int?>(
            tooltip: 'Minimum match score',
            onSelected: (v) => onChanged(filters.withMinScore(v)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Any score')),
              for (final s in _scores)
                PopupMenuItem(value: s, child: Text('$s+ match')),
            ],
            child: IgnorePointer(
              child: FilterChip(
                label: Text(
                  filters.minScore == null
                      ? 'Score'
                      : '${filters.minScore}+ match',
                ),
                selected: filters.minScore != null,
                onSelected: (_) {},
              ),
            ),
          ),
          if (!filters.isEmpty)
            TextButton(
              onPressed: () => onChanged(BoardFilters.empty),
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.jobId,
    required this.tile,
    required this.focusNode,
    required this.onRemoved,
  });

  final String jobId;
  final BoardTile tile;
  final FocusNode focusNode;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedTileProvider) == tile.applicationId;
    return CandidateTile(
      tile: tile,
      focusNode: focusNode,
      showActions: selected,
      onToggleActions: () =>
          ref.read(selectedTileProvider.notifier).toggle(tile.applicationId),
      onOpen: () =>
          context.push(Routes.candidateDetailFor(jobId, tile.applicationId)),
      onAdvance: () => advanceTile(context, ref, jobId, tile),
      onReject: () {
        rejectTile(context, ref, jobId, tile);
        onRemoved();
      },
    );
  }
}

/// Advance with an optional note (RC-13). Shared by the triangle and "A".
Future<void> advanceTile(
  BuildContext context,
  WidgetRef ref,
  String jobId,
  BoardTile tile,
) async {
  final controller = ref.read(boardControllerProvider(jobId).notifier);
  final note = await showAdvanceDialog(context, handle: tile.handle);
  if (note == null || !context.mounted) return;
  ref.read(selectedTileProvider.notifier).clear();
  try {
    await controller.advance(
      tile.applicationId,
      note: note.isEmpty ? null : note,
    );
    if (context.mounted) {
      showMessage(context, 'Interview requested for ${tile.handle}.');
    }
  } catch (error) {
    if (context.mounted) showMessage(context, messageOf(error));
  }
}

/// Reject with a 10 s Undo (RC-13). Shared by the triangle and "R".
Future<void> rejectTile(
  BuildContext context,
  WidgetRef ref,
  String jobId,
  BoardTile tile,
) async {
  final controller = ref.read(boardControllerProvider(jobId).notifier);
  final messenger = ScaffoldMessenger.of(context);
  ref.read(selectedTileProvider.notifier).clear();
  // Show Undo straight away; the reject request runs underneath.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('Not a fit · ${tile.handle}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              controller.undoReject(tile.applicationId).catchError((Object e) {
                messenger.showSnackBar(SnackBar(content: Text(messageOf(e))));
              }),
        ),
      ),
    );
  try {
    await controller.reject(tile.applicationId);
  } catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(messageOf(error))));
  }
}

/// The "?" help dialog listing the board shortcuts.
Future<void> showShortcutHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Keyboard shortcuts'),
    content: const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShortcutRow(keys: 'J / →', action: 'Next applicant'),
        _ShortcutRow(keys: 'K / ←', action: 'Previous applicant'),
        _ShortcutRow(keys: 'A', action: 'Advance'),
        _ShortcutRow(keys: 'R', action: 'Not a fit'),
        _ShortcutRow(keys: 'Enter', action: 'Open details'),
        _ShortcutRow(keys: '?', action: 'Show this help'),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(keys, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(action)),
        ],
      ),
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
