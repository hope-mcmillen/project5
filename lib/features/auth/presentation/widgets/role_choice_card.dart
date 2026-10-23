import 'package:flutter/material.dart';

import '../../../../core/models/app_role.dart';
import '../../../../ui/components/collage.dart';
import '../../../../ui/theme/rr_tokens.dart';

/// One of the two large sign-up cards: "I'm looking for a job" or
/// "I'm hiring" (PRD §4). Selected cards get a 2 px border and a check.
class RoleChoiceCard extends StatelessWidget {
  const RoleChoiceCard({
    super.key,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final bool selected;
  final VoidCallback onTap;

  static String titleFor(AppRole role) => switch (role) {
    AppRole.candidate => 'I\'m looking for a job',
    AppRole.recruiter => 'I\'m hiring',
  };

  static String subtitleFor(AppRole role) => switch (role) {
    AppRole.candidate => 'Swipe through jobs that fit your skills.',
    AppRole.recruiter => 'Post jobs and triage ranked applicants.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = role == AppRole.candidate;
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.horizontal(
        left: RRRadius.sm,
        right: RRRadius.xl,
      ),
      side: BorderSide(
        color: selected ? RRColors.ink : Colors.transparent,
        width: 3,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Card(
        shape: shape,
        color: candidate ? RRColors.deck : RRColors.pink,
        margin: EdgeInsets.zero,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(RRSpace.lg),
            child: Row(
              children: [
                CollageTile(
                  color: candidate ? RRColors.lemon : RRColors.violet,
                  shape: candidate ? TileShape.circle : TileShape.halfRight,
                  width: RRSpace.xxxl + RRSpace.sm,
                  height: RRSpace.xxxl + RRSpace.sm,
                  padding: EdgeInsets.zero,
                  child: Icon(
                    candidate ? Icons.style_outlined : Icons.grid_view_outlined,
                    size: RRSpace.xxl,
                    color: candidate ? RRColors.ink : RRColors.surface,
                  ),
                ),
                const SizedBox(width: RRSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titleFor(role), style: theme.textTheme.titleLarge),
                      const SizedBox(height: RRSpace.xs),
                      Text(
                        subtitleFor(role),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: RRColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two [RoleChoiceCard]s, side by side when there is room.
class RoleChoicePicker extends StatelessWidget {
  const RoleChoicePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AppRole? selected;
  final ValueChanged<AppRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final role in AppRole.values)
        RoleChoiceCard(
          role: role,
          selected: selected == role,
          onTap: () => onChanged(role),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 600
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 16),
                Expanded(child: cards[1]),
              ],
            )
          : Column(children: [cards[0], const SizedBox(height: 16), cards[1]]),
    );
  }
}
