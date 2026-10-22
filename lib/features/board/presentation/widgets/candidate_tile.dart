import 'package:flutter/material.dart';

import '../../../../core/models/application_status.dart';
import '../../domain/board_tile.dart';
import 'board_marks.dart';
import 'triangle_actions.dart';

/// A blind applicant tile: rhombus avatar, handle, score, years, top 3
/// skills and up to 2 gaps. It has **no identity fields** (RC-12).
///
/// Actions: on web, hovering slides the triangles in over 150 ms and a
/// click opens the detail; on touch, a tap toggles the triangles and a long
/// press opens the detail (RC-13). Keyboard focus also shows them.
class CandidateTile extends StatefulWidget {
  const CandidateTile({
    super.key,
    required this.tile,
    required this.showActions,
    required this.onToggleActions,
    required this.onOpen,
    required this.onAdvance,
    required this.onReject,
    this.focusNode,
  });

  final BoardTile tile;

  /// Touch screens: whether this tile's triangles were toggled on.
  final bool showActions;
  final VoidCallback onToggleActions;
  final VoidCallback onOpen;
  final VoidCallback onAdvance;
  final VoidCallback onReject;
  final FocusNode? focusNode;

  @override
  State<CandidateTile> createState() => _CandidateTileState();
}

class _CandidateTileState extends State<CandidateTile> {
  bool _hovering = false;
  bool _focused = false;

  bool get _decided =>
      widget.tile.status == ApplicationStatus.interviewRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tile = widget.tile;
    final reveal = _hovering || _focused || widget.showActions;
    final years = tile.totalYears % 1 == 0
        ? tile.totalYears.toInt().toString()
        : tile.totalYears.toStringAsFixed(1);

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RhombusAvatar(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.handle,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$years ${years == '1' ? 'year' : 'years'}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              BoardScoreBadge(score: tile.matchScore, band: tile.band),
            ],
          ),
          const SizedBox(height: 10),
          // Clips instead of overflowing at large text sizes; the full
          // list is in the semantics label and the detail view.
          Expanded(
            child: ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in tile.topSkills.take(3))
                      _SkillChip(label: skill),
                    for (final gap in tile.gaps.take(2))
                      _SkillChip(label: gap, gap: true),
                  ],
                ),
              ),
            ),
          ),
          if (tile.status == ApplicationStatus.interviewRequested)
            _StatusLine(
              icon: Icons.change_history,
              text: 'Interview requested',
              color: colors.primary,
            )
          else if (tile.status == ApplicationStatus.underReview)
            _StatusLine(
              icon: Icons.visibility_outlined,
              text: 'Reviewed',
              color: colors.onSurfaceVariant,
            ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedPhysicalModel(
          duration: const Duration(milliseconds: 150),
          elevation: _hovering || _focused ? 6 : 1,
          color: colors.surface,
          shadowColor: colors.shadow,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused ? colors.primary : colors.outlineVariant,
                width: _focused ? 2 : 1,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                // The tile's Focus above is the single focus stop.
                canRequestFocus: false,
                borderRadius: BorderRadius.circular(12),
                // A mouse hovering means a pointer device: click opens.
                onTap: _hovering ? widget.onOpen : widget.onToggleActions,
                onLongPress: widget.onOpen,
                child: Semantics(
                  label:
                      'Applicant ${tile.handle}, match ${tile.matchScore} '
                      '${tile.band}, $years years. Skills: '
                      '${tile.topSkills.take(3).join(', ')}'
                      '${tile.gaps.isEmpty ? '' : '. Missing: ${tile.gaps.take(2).join(', ')}'}',
                  child: Stack(
                    children: [
                      Positioned.fill(child: content),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: _decided
                            ? const SizedBox.shrink()
                            : AnimatedSlide(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOut,
                                offset: reveal
                                    ? Offset.zero
                                    : const Offset(0.6, 0),
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 150),
                                  opacity: reveal ? 1 : 0,
                                  child: IgnorePointer(
                                    ignoring: !reveal,
                                    child: TriangleActions(
                                      handle: tile.handle,
                                      onAdvance: widget.onAdvance,
                                      onReject: widget.onReject,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, this.gap = false});

  final String label;
  final bool gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gap ? null : colors.surfaceContainerHighest,
        border: gap ? Border.all(color: colors.outline) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gap) ...[
            Icon(Icons.remove_circle_outline, size: 12, color: colors.error),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
              semanticsLabel: gap ? 'Missing $label' : label,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
