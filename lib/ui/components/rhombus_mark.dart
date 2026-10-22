import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';

enum RhombusVariant { filled, outlined, dashed }

class RhombusMark extends StatelessWidget {
  const RhombusMark({
    super.key,
    this.size = RRSpace.markSize,
    this.variant = RhombusVariant.outlined,
    this.color,
  });
  final double size;
  final RhombusVariant variant;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(size, size * .8),
      painter: _RhombusPainter(
        color ?? Theme.of(context).colorScheme.onSurface,
        variant,
      ),
    ),
  );
}

class _RhombusPainter extends CustomPainter {
  _RhombusPainter(this.color, this.variant);
  final Color color;
  final RhombusVariant variant;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 1)
      ..lineTo(size.width - 1, size.height / 2)
      ..lineTo(size.width / 2, size.height - 1)
      ..lineTo(1, size.height / 2)
      ..close();
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = variant == RhombusVariant.filled
          ? PaintingStyle.fill
          : PaintingStyle.stroke;
    if (variant != RhombusVariant.dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 4).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RhombusPainter old) =>
      color != old.color || variant != old.variant;
}
