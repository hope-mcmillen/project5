import 'package:flutter/material.dart';

/// ▲ Advance and ▼ Not a fit as two triangles in 48×48 hit areas (RC-13).
/// Shape and label carry the meaning as well as color.
class TriangleActions extends StatelessWidget {
  const TriangleActions({
    super.key,
    required this.handle,
    required this.onAdvance,
    required this.onReject,
  });

  final String handle;
  final VoidCallback? onAdvance;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TriangleButton(
          pointsUp: true,
          color: colors.primary,
          tooltip: 'Advance $handle',
          onPressed: onAdvance,
        ),
        const SizedBox(height: 4),
        _TriangleButton(
          pointsUp: false,
          color: colors.error,
          tooltip: 'Not a fit: $handle',
          onPressed: onReject,
        ),
      ],
    );
  }
}

class _TriangleButton extends StatelessWidget {
  const _TriangleButton({
    required this.pointsUp,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final bool pointsUp;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: 48,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: ClipPath(
                  clipper: _TriangleClipper(pointsUp: pointsUp),
                  child: Container(
                    width: 28,
                    height: 24,
                    color: onPressed == null
                        ? color.withValues(alpha: 0.38)
                        : color,
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

class _TriangleClipper extends CustomClipper<Path> {
  const _TriangleClipper({required this.pointsUp});

  final bool pointsUp;

  @override
  Path getClip(Size size) => pointsUp
      ? (Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close())
      : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width / 2, size.height)
          ..close());

  @override
  bool shouldReclip(_TriangleClipper old) => old.pointsUp != pointsUp;
}
