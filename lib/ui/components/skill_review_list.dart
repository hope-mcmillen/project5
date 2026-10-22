import 'package:flutter/material.dart';

import '../../core/models/candidate_models.dart';
import '../theme/rr_tokens.dart';

class SkillReviewList extends StatelessWidget {
  const SkillReviewList({
    super.key,
    required this.skills,
    required this.onRemove,
    required this.onRename,
    required this.onYears,
    required this.onEvidence,
    this.enabled = true,
  });
  final List<CandidateSkill> skills;
  final ValueChanged<String> onRemove, onRename;
  final void Function(String, double?) onYears;
  final ValueChanged<CandidateSkill> onEvidence;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final skill in skills)
        Padding(
          padding: const EdgeInsets.only(bottom: RRSpace.md),
          child: Dismissible(
            key: ValueKey(skill.id),
            direction: enabled
                ? DismissDirection.endToStart
                : DismissDirection.none,
            onDismissed: (_) => onRemove(skill.id),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(RRSpace.lg),
              color: RRColors.pass,
              child: const Icon(Icons.delete_outline, color: RRColors.surface),
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(RRSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            skill.rawName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename ${skill.rawName}',
                          onPressed: enabled ? () => onRename(skill.id) : null,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remove ${skill.rawName}',
                          onPressed: enabled ? () => onRemove(skill.id) : null,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (skill.source == SkillSource.user)
                      const Chip(
                        avatar: Icon(Icons.edit_outlined, size: RRSpace.lg),
                        label: Text('Edited'),
                      ),
                    if (skill.source == SkillSource.ai)
                      const Text('Suggested from resume'),
                    if (skill.skillId == null)
                      const Text('Custom skill · Not used for matching'),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: RRSpace.xs,
                      children: [
                        IconButton(
                          tooltip: 'Decrease ${skill.rawName} experience',
                          onPressed:
                              enabled && skill.years != null && skill.years! > 0
                              ? () => onYears(skill.id, skill.years! - .5)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          skill.years == null
                              ? 'Years not specified'
                              : '${skill.years!.toStringAsFixed(1)} years',
                        ),
                        IconButton(
                          tooltip: 'Increase ${skill.rawName} experience',
                          onPressed: enabled && (skill.years ?? 0) < 99.5
                              ? () => onYears(skill.id, (skill.years ?? 0) + .5)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        if (skill.years != null)
                          TextButton(
                            onPressed: enabled
                                ? () => onYears(skill.id, null)
                                : null,
                            child: const Text('Clear years'),
                          ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => onEvidence(skill),
                      icon: const Icon(Icons.format_quote),
                      label: const Text('View evidence'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
