import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/models/job_status.dart';
import '../data/job_repository.dart';
import '../domain/job.dart';
import '../domain/requirement.dart';
import '../domain/requirements_state.dart';
import 'requirements_controller.dart';
import 'widgets/description_panel.dart';
import 'widgets/skill_search_dialog.dart';

/// Requirements: review the skills parse-job extracted, mark each required
/// or preferred, set minimum years and weight, add or map skills, and save
/// with `save_requirements` (RC-09a/b, US-35). Table + description side by
/// side from 900 px, cards on phones.
class RequirementEditorScreen extends ConsumerWidget {
  const RequirementEditorScreen({super.key, required this.jobId});

  final String jobId;

  static const wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobProvider(jobId));
    final editor = ref.watch(requirementsControllerProvider(jobId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          job.value == null
              ? 'Requirements'
              : 'Requirements · ${job.value!.displayTitle}',
        ),
      ),
      body: switch ((job, editor)) {
        (AsyncValue(:final error?), _) ||
        (_, AsyncValue(:final error?)) => ErrorView(
          error: error,
          onRetry: () => ref
            ..invalidate(jobProvider(jobId))
            ..invalidate(requirementsControllerProvider(jobId)),
        ),
        (AsyncValue(value: final j?), AsyncValue(value: final s?)) => _Editor(
          job: j,
          state: s,
        ),
        _ => const LoadingBlocks(count: 5, height: 56),
      },
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.job, required this.state});

  final Job job;
  final RequirementsState state;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  bool _saving = false;

  RequirementsController get _controller =>
      ref.read(requirementsControllerProvider(widget.job.id).notifier);

  bool get _readOnly => widget.job.status == JobStatus.closed;

  Future<void> _addSkill() async {
    final skill = await showSkillSearch(
      context,
      exclude: {for (final r in widget.state.items) r.skill.id},
    );
    if (skill != null) _controller.add(skill);
  }

  Future<void> _mapUnmapped(int index) async {
    final raw = widget.state.unmapped[index];
    final skill = await showSkillSearch(
      context,
      title: 'Map "${raw.raw}" to…',
      initialQuery: raw.raw,
      exclude: {for (final r in widget.state.items) r.skill.id},
    );
    if (skill != null) _controller.mapUnmapped(index, skill);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _controller.save();
      if (!mounted) return;
      if (widget.job.status == JobStatus.draft) {
        context.push(Routes.jobDetailsFor(widget.job.id));
      } else {
        showMessage(context, 'Requirements saved. Scores are updating.');
      }
    } catch (error) {
      if (mounted) showMessage(context, messageOf(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showDescription() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: DescriptionPanel(
          text: widget.job.rawDescription,
          highlight: _selectedEvidence,
        ),
      ),
    ),
  );

  String? get _selectedEvidence {
    final i = widget.state.selected;
    return i == null || i >= widget.state.items.length
        ? null
        : widget.state.items[i].evidence;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final header = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Counter(
          label:
              '${state.requiredCount}/${RequirementsState.maxRequired} required',
          full: state.requiredFull,
        ),
        _Counter(
          label: '${state.total}/${RequirementsState.maxTotal} total',
          full: state.isFull,
        ),
        if (!_readOnly)
          Tooltip(
            message: state.addBlocked ?? 'Search the skill list',
            child: OutlinedButton.icon(
              onPressed: state.addBlocked == null ? _addSkill : null,
              icon: const Icon(Icons.add),
              label: const Text('Add skill'),
            ),
          ),
      ],
    );

    final body = <Widget>[
      if (_readOnly)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('This job is closed, so its requirements are final.'),
        ),
      header,
      const SizedBox(height: 16),
      if (state.items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: EmptyView(
            icon: Icons.checklist,
            title: 'No skills yet',
            message: 'Add the skills candidates will be matched on.',
          ),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 560
              ? _RequirementTable(
                  state: state,
                  readOnly: _readOnly,
                  controller: _controller,
                )
              : Column(
                  children: [
                    for (var i = 0; i < state.items.length; i++)
                      _RequirementCard(
                        index: i,
                        state: state,
                        readOnly: _readOnly,
                        controller: _controller,
                      ),
                  ],
                ),
        ),
      if (state.unmapped.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('Not in the skill list', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        const Text(
          'Only listed skills can be scored. Map each to the closest skill, '
          'or ignore it.',
        ),
        for (var i = 0; i < state.unmapped.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(state.unmapped[i].raw),
            subtitle: state.unmapped[i].evidence == null
                ? null
                : Text(
                    '"${state.unmapped[i].evidence}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Wrap(
              children: [
                TextButton(
                  onPressed: _readOnly || state.isFull
                      ? null
                      : () => _mapUnmapped(i),
                  child: const Text('Map to…'),
                ),
                TextButton(
                  onPressed: () => _controller.ignoreUnmapped(i),
                  child: const Text('Ignore'),
                ),
              ],
            ),
          ),
      ],
      if (state.trimmed.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(
          'Left out by the ${RequirementsState.maxTotal}-skill limit',
          style: theme.textTheme.titleSmall,
        ),
        for (var i = 0; i < state.trimmed.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.content_cut),
            title: Text(state.trimmed[i].skill.name),
            trailing: Tooltip(
              message: state.addBlocked ?? 'Add this skill back',
              child: TextButton(
                onPressed: _readOnly || state.isFull
                    ? null
                    : () => _controller.restoreTrimmed(i),
                child: const Text('Add back'),
              ),
            ),
          ),
      ],
      const SizedBox(height: 96),
    ];

    final saveBar = _readOnly
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    state.dirty ? 'Unsaved changes' : '',
                    style: theme.textTheme.bodySmall,
                  ),
                  FilledButton(
                    onPressed:
                        _saving ||
                            (state.items.isEmpty &&
                                widget.job.status != JobStatus.draft)
                        ? null
                        : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.job.status == JobStatus.draft
                                ? 'Save and continue'
                                : 'Save requirements',
                          ),
                  ),
                ],
              ),
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= RequirementEditorScreen.wideBreakpoint;
        final editor = ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!wide)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _showDescription,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(
                    state.selected == null
                        ? 'View description'
                        : 'Show where "${state.items[state.selected!].skill.name}" comes from',
                  ),
                ),
              ),
            ...body,
          ],
        );
        return Column(
          children: [
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth * 0.36,
                          child: Card(
                            margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: DescriptionPanel(
                                text: widget.job.rawDescription,
                                highlight: _selectedEvidence,
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: editor),
                      ],
                    )
                  : editor,
            ),
            ?saveBar,
          ],
        );
      },
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.full});

  final String label;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(full ? Icons.block : Icons.check, size: 16),
      label: Text(label),
      backgroundColor: full ? colors.secondaryContainer : null,
    );
  }
}

/// Required / Preferred toggle, disabled with an explanation at the limit.
class _RequiredToggle extends StatelessWidget {
  const _RequiredToggle({
    required this.index,
    required this.state,
    required this.readOnly,
    required this.controller,
  });

  final int index;
  final RequirementsState state;
  final bool readOnly;
  final RequirementsController controller;

  @override
  Widget build(BuildContext context) {
    final blocked = state.requiredToggleBlocked(index);
    final required = state.items[index].required;
    final onChanged = readOnly || blocked != null
        ? null
        : () => controller.toggleRequired(index);
    // A segmented button can't wrap; at large text sizes use chips.
    if (MediaQuery.textScalerOf(context).scale(14) > 20) {
      final chips = Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          ChoiceChip(
            label: const Text('Required'),
            selected: required,
            onSelected: onChanged == null || required
                ? null
                : (_) => onChanged(),
          ),
          ChoiceChip(
            label: const Text('Preferred'),
            selected: !required,
            onSelected: onChanged == null || !required
                ? null
                : (_) => onChanged(),
          ),
        ],
      );
      return blocked == null ? chips : Tooltip(message: blocked, child: chips);
    }
    final toggle = SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: true, label: Text('Required')),
        ButtonSegment(value: false, label: Text('Preferred')),
      ],
      selected: {state.items[index].required},
      onSelectionChanged: readOnly || blocked != null
          ? null
          : (_) => controller.toggleRequired(index),
    );
    return blocked == null ? toggle : Tooltip(message: blocked, child: toggle);
  }
}

class _YearsStepper extends StatelessWidget {
  const _YearsStepper({
    required this.index,
    required this.item,
    required this.readOnly,
    required this.controller,
  });

  final int index;
  final RequirementDraft item;
  final bool readOnly;
  final RequirementsController controller;

  @override
  Widget build(BuildContext context) {
    final years = item.minYears;
    final label = years == 0
        ? 'Any'
        : '${years % 1 == 0 ? years.toInt() : years}+ yrs';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Fewer years for ${item.skill.name}',
          icon: const Icon(Icons.remove),
          onPressed: readOnly || years <= 0
              ? null
              : () => controller.setMinYears(index, years - 0.5),
        ),
        SizedBox(
          width: 56,
          child: Text(
            label,
            textAlign: TextAlign.center,
            semanticsLabel: years == 0
                ? 'No minimum years'
                : 'At least $years years',
          ),
        ),
        IconButton(
          tooltip: 'More years for ${item.skill.name}',
          icon: const Icon(Icons.add),
          onPressed: readOnly || years >= 99.5
              ? null
              : () => controller.setMinYears(index, years + 0.5),
        ),
      ],
    );
  }
}

/// Weight 1–3 as three rhombus pips.
class _WeightPips extends StatelessWidget {
  const _WeightPips({
    required this.index,
    required this.item,
    required this.readOnly,
    required this.controller,
  });

  final int index;
  final RequirementDraft item;
  final bool readOnly;
  final RequirementsController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Weight ${item.weight} of 3 for ${item.skill.name}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var w = 1; w <= 3; w++)
            IconButton(
              tooltip: 'Weight $w',
              onPressed: readOnly ? null : () => controller.setWeight(index, w),
              icon: Icon(
                w <= item.weight ? Icons.diamond : Icons.diamond_outlined,
                color: w <= item.weight ? colors.primary : colors.outline,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _SkillLabel extends StatelessWidget {
  const _SkillLabel({required this.item});

  final RequirementDraft item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.skill.name, style: theme.textTheme.titleSmall),
        if (item.eitherOfGroup != null)
          Text(
            'One of group ${item.eitherOfGroup}',
            style: theme.textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _RequirementTable extends StatelessWidget {
  const _RequirementTable({
    required this.state,
    required this.readOnly,
    required this.controller,
  });

  final RequirementsState state;
  final bool readOnly;
  final RequirementsController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        columnSpacing: 16,
        dataRowMaxHeight: 64,
        columns: const [
          DataColumn(label: Text('Skill')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Min. years')),
          DataColumn(label: Text('Weight')),
          DataColumn(label: Text('')),
        ],
        rows: [
          for (var i = 0; i < state.items.length; i++)
            DataRow(
              selected: state.selected == i,
              cells: [
                DataCell(
                  _SkillLabel(item: state.items[i]),
                  onTap: () => controller.select(i),
                ),
                DataCell(
                  _RequiredToggle(
                    index: i,
                    state: state,
                    readOnly: readOnly,
                    controller: controller,
                  ),
                ),
                DataCell(
                  _YearsStepper(
                    index: i,
                    item: state.items[i],
                    readOnly: readOnly,
                    controller: controller,
                  ),
                ),
                DataCell(
                  _WeightPips(
                    index: i,
                    item: state.items[i],
                    readOnly: readOnly,
                    controller: controller,
                  ),
                ),
                DataCell(
                  IconButton(
                    tooltip: 'Remove ${state.items[i].skill.name}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: readOnly ? null : () => controller.remove(i),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    required this.index,
    required this.state,
    required this.readOnly,
    required this.controller,
  });

  final int index;
  final RequirementsState state;
  final bool readOnly;
  final RequirementsController controller;

  @override
  Widget build(BuildContext context) {
    final item = state.items[index];
    final selected = state.selected == index;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? colors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.select(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _SkillLabel(item: item)),
                  IconButton(
                    tooltip: 'Remove ${item.skill.name}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: readOnly ? null : () => controller.remove(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _RequiredToggle(
                index: index,
                state: state,
                readOnly: readOnly,
                controller: controller,
              ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _YearsStepper(
                    index: index,
                    item: item,
                    readOnly: readOnly,
                    controller: controller,
                  ),
                  _WeightPips(
                    index: index,
                    item: item,
                    readOnly: readOnly,
                    controller: controller,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
