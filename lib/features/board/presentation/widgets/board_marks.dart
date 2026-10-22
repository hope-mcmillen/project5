import 'package:flutter/material.dart';

/// A rhombus avatar for anonymous candidates (resurhombus-ui: the rhombus
/// means identity and score).
///
/// TODO(RC-02): swap for C2's shared `RhombusMark` once it lands.
class RhombusAvatar extends StatelessWidget {
  const RhombusAvatar({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Theme.of(context).colorScheme.primaryContainer;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _RhombusPainter(fill, Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _RhombusPainter extends CustomPainter {
  _RhombusPainter(this.fill, this.stroke);

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_RhombusPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// Match score with its band label, never one without the other (PRD §3.3).
///
/// TODO(RC-02): swap for C2's shared `ScoreBadge` once it lands.
class BoardScoreBadge extends StatelessWidget {
  const BoardScoreBadge({super.key, required this.score, required this.band});

  final int score;
  final String band;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (background, foreground) = switch (band) {
      'Strong' => (colors.primary, colors.onPrimary),
      'Good' => (colors.primaryContainer, colors.onPrimaryContainer),
      'Stretch' => (colors.secondaryContainer, colors.onSecondaryContainer),
      _ => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return Semantics(
      label: 'Match $score, $band',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$score',
              style: theme.textTheme.titleLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            Text(
              band,
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
