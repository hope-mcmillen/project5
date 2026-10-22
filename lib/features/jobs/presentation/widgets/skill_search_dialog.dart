import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/widgets/state_views.dart';
import '../../data/job_repository.dart';
import '../../domain/requirement.dart';

/// Taxonomy search for "Add skill" and "Map to…". Returns the chosen skill.
Future<SkillRef?> showSkillSearch(
  BuildContext context, {
  String initialQuery = '',
  String title = 'Add a skill',
  Set<String> exclude = const {},
}) => showDialog<SkillRef>(
  context: context,
  builder: (_) => _SkillSearchDialog(
    initialQuery: initialQuery,
    title: title,
    exclude: exclude,
  ),
);

class _SkillSearchDialog extends ConsumerStatefulWidget {
  const _SkillSearchDialog({
    required this.initialQuery,
    required this.title,
    required this.exclude,
  });

  final String initialQuery;
  final String title;
  final Set<String> exclude;

  @override
  ConsumerState<_SkillSearchDialog> createState() => _SkillSearchDialogState();
}

class _SkillSearchDialogState extends ConsumerState<_SkillSearchDialog> {
  late final _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  AsyncValue<List<SkillRef>> _results = const AsyncData([]);
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(text));
  }

  Future<void> _search(String text) async {
    final request = ++_request;
    setState(() => _results = const AsyncLoading());
    final result = await AsyncValue.guard(
      () => ref.read(jobRepositoryProvider).searchSkills(text),
    );
    if (mounted && request == _request) setState(() => _results = result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search skills',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: switch (_results) {
                AsyncValue(isLoading: true) => const Center(
                  child: CircularProgressIndicator(),
                ),
                AsyncValue(:final error?) => Center(
                  child: Text(messageOf(error)),
                ),
                AsyncValue(:final value?) when value.isEmpty => Center(
                  child: Text(
                    _query.text.trim().isEmpty
                        ? 'Type a skill, like "Flutter".'
                        : 'No skills match "${_query.text.trim()}".',
                  ),
                ),
                AsyncValue(:final value?) => ListView(
                  children: [
                    for (final skill in value)
                      ListTile(
                        title: Text(skill.name),
                        subtitle: Text(skill.category),
                        enabled: !widget.exclude.contains(skill.id),
                        trailing: widget.exclude.contains(skill.id)
                            ? const Text('Added')
                            : null,
                        onTap: () => Navigator.pop(context, skill),
                      ),
                  ],
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
