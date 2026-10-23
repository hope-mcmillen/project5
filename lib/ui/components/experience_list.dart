import 'package:flutter/material.dart';

import '../../core/models/candidate_models.dart';
import '../theme/rr_tokens.dart';

/// Read-only list of the experience entries read from a resume.
class ExperienceList extends StatelessWidget {
  const ExperienceList({super.key, required this.experiences});
  final List<CandidateExperience> experiences;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "Mar 2022", "2022", "Present", or null.
  static String? month(String? value) {
    if (value == null) return null;
    if (value == 'present') return 'Present';
    final parts = value.split('-');
    if (parts.length != 2) return value;
    final index = int.tryParse(parts[1]);
    return index == null || index < 1 || index > 12
        ? value
        : '${_months[index - 1]} ${parts[0]}';
  }

  static String? dates(CandidateExperience e) {
    final start = month(e.startMonth), end = month(e.endMonth);
    if (start == null && end == null) return null;
    return [start ?? '?', end ?? '?'].join(' – ');
  }

  static String kindLabel(ExperienceKind kind) => switch (kind) {
    ExperienceKind.job => 'Job',
    ExperienceKind.internship => 'Internship',
    ExperienceKind.research => 'Research',
    ExperienceKind.project => 'Project',
    ExperienceKind.volunteer => 'Volunteer',
    ExperienceKind.other => 'Experience',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: RRColors.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in experiences)
          Padding(
            padding: const EdgeInsets.only(bottom: RRSpace.md),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(RRSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: text.titleMedium),
                    const SizedBox(height: RRSpace.xs),
                    Text(
                      [
                        kindLabel(e.kind),
                        ?e.organization,
                        ?dates(e),
                      ].join(' · '),
                      style: muted,
                    ),
                    for (final highlight in e.highlights) ...[
                      const SizedBox(height: RRSpace.sm),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: RRSpace.sm),
                            child: Icon(
                              Icons.change_history,
                              size: 12,
                              color: RRColors.match,
                            ),
                          ),
                          Expanded(child: Text(highlight)),
                        ],
                      ),
                    ],
                    if (e.skillsUsed.isNotEmpty) ...[
                      const SizedBox(height: RRSpace.sm),
                      Text('Skills: ${e.skillsUsed.join(', ')}', style: muted),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
