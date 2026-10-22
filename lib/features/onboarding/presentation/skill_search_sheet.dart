import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/skill.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../../profile/data/profile_repository.dart';

class SkillChoice {
  const SkillChoice(this.name, [this.skill]);
  final String name;
  final Skill? skill;
}

final skillSearchProvider = FutureProvider.autoDispose
    .family<List<Skill>, String>(
      (ref, query) async =>
          (await ref.watch(profileRepositoryProvider).searchSkills(query))
              .take(20)
              .toList(),
    );

class SkillSearchSheet extends ConsumerStatefulWidget {
  const SkillSearchSheet({super.key, this.initialName = ''});
  final String initialName;
  @override
  ConsumerState<SkillSearchSheet> createState() => _SkillSearchSheetState();
}

class _SkillSearchSheetState extends ConsumerState<SkillSearchSheet> {
  late final _query = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final results = ref.watch(skillSearchProvider(query));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: .85,
          child: ListView(
            padding: const EdgeInsets.all(RRSpace.xl),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initialName.isEmpty
                          ? 'Add a skill'
                          : 'Rename skill',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close skill search',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: RRSpace.md),
              TextField(
                controller: _query,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Search skills',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(skillSearchProvider(query)),
                    child: const Text('Retry skill search'),
                  ),
                ),
                data: (skills) => Column(
                  children: [
                    if (skills.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(RRSpace.lg),
                        child: Text(
                          'No matching skills. You can add a custom skill below.',
                        ),
                      ),
                    for (final skill in skills)
                      ListTile(
                        title: Text(skill.name),
                        subtitle: Text(skill.category),
                        trailing: const Icon(Icons.add),
                        onTap: () => Navigator.pop(
                          context,
                          SkillChoice(skill.name, skill),
                        ),
                      ),
                  ],
                ),
              ),
              if (query.isNotEmpty)
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, SkillChoice(query)),
                  child: Text(
                    'Use custom skill: $query',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: RRSpace.sm),
              const Text(
                'Choose a listed skill for matching. Custom skills stay on your profile but are not scored.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
