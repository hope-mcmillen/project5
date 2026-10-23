import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';

/// Tile silhouettes from the collage language. Half shapes are "D"s whose
/// round side faces the named direction; [leaf] rounds two opposite corners.
enum TileShape {
  square,
  circle,
  pill,
  halfLeft,
  halfRight,
  halfTop,
  halfBottom,
  leaf,
}

/// Small painted accents placed on tiles. Rhombus and triangle keep the
/// ResuRhombus grammar (identity/score and decisive actions).
enum TileMotif { none, rhombus, triangle, asterisk, arrow, ring, squiggle }

ShapeBorder tileBorder(TileShape shape) {
  const full = Radius.circular(9999);
  return switch (shape) {
    TileShape.square => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(RRRadius.sm),
    ),
    TileShape.circle => const CircleBorder(),
    TileShape.pill => const StadiumBorder(),
    TileShape.halfLeft => const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(left: full, right: RRRadius.sm),
    ),
    TileShape.halfRight => const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(left: RRRadius.sm, right: full),
    ),
    TileShape.halfTop => const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: full, bottom: RRRadius.sm),
    ),
    TileShape.halfBottom => const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: RRRadius.sm, bottom: full),
    ),
    TileShape.leaf => const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: full,
        bottomRight: full,
        topRight: RRRadius.sm,
        bottomLeft: RRRadius.sm,
      ),
    ),
  };
}

/// A flat colour tile with an optional motif and child. Decorative unless it
/// has a child, so screen readers skip empty tiles.
class CollageTile extends StatelessWidget {
  const CollageTile({
    super.key,
    required this.color,
    this.shape = TileShape.square,
    this.motif = TileMotif.none,
    this.motifColor = RRColors.ink,
    this.child,
    this.padding = const EdgeInsets.all(RRSpace.lg),
    this.width,
    this.height,
  });

  final Color color;
  final TileShape shape;
  final TileMotif motif;
  final Color motifColor;
  final Widget? child;
  final EdgeInsets padding;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(color: color, shape: tileBorder(shape)),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (motif != TileMotif.none)
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: MotifPainter(motif, motifColor)),
              ),
            ),
          if (child != null) Padding(padding: padding, child: child),
        ],
      ),
    );
    return child == null ? ExcludeSemantics(child: tile) : tile;
  }
}

/// Paints a [TileMotif] centred in its box, sized to the shorter side.
class MotifPainter extends CustomPainter {
  const MotifPainter(this.motif, this.color);
  final TileMotif motif;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final c = size.center(Offset.zero);
    final r = side * .3;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(3, side * .1);
    final fill = Paint()..color = color;
    switch (motif) {
      case TileMotif.none:
        return;
      case TileMotif.rhombus:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r * .8, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r * .8, c.dy)
            ..close(),
          fill,
        );
      case TileMotif.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy + r * .75)
            ..lineTo(c.dx - r, c.dy + r * .75)
            ..close(),
          fill,
        );
      case TileMotif.asterisk:
        final arm = Paint()
          ..color = color
          ..strokeCap = StrokeCap.round
          ..strokeWidth = side * .16;
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 4;
          final d = Offset(math.cos(a), math.sin(a)) * r * 1.1;
          canvas.drawLine(c - d, c + d, arm);
        }
      case TileMotif.arrow:
        final tip = c + Offset(-r, -r);
        canvas.drawLine(c + Offset(r * .8, r * .8), tip, stroke);
        canvas.drawLine(tip, tip + Offset(r * 1.1, 0), stroke);
        canvas.drawLine(tip, tip + Offset(0, r * 1.1), stroke);
      case TileMotif.ring:
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          math.pi * .35,
          math.pi * 1.6,
          false,
          stroke..strokeWidth = side * .14,
        );
        canvas.drawCircle(c, side * .08, fill);
      case TileMotif.squiggle:
        final path = Path()..moveTo(0, size.height * .62);
        const loops = 3;
        final step = size.width / loops;
        for (var i = 0; i < loops; i++) {
          final x = step * i;
          path
            ..cubicTo(
              x + step * .55,
              size.height * .62,
              x + step * .85,
              size.height * .2,
              x + step * .55,
              size.height * .3,
            )
            ..cubicTo(
              x + step * .25,
              size.height * .42,
              x + step * .55,
              size.height * .7,
              x + step,
              size.height * .62,
            );
        }
        canvas.drawPath(path, stroke..strokeWidth = math.max(4, side * .07));
    }
  }

  @override
  bool shouldRepaint(MotifPainter old) =>
      old.motif != motif || old.color != color;
}

/// Thick rounded ribbons (navy, pink, lemon) that thread behind a screen.
/// Background only: keep it on welcome/auth pages so working screens stay
/// calm.
class RibbonBackdrop extends StatelessWidget {
  const RibbonBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: ExcludeSemantics(
          child: RepaintBoundary(child: CustomPaint(painter: _RibbonPainter())),
        ),
      ),
      child,
    ],
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final thick = math.max(18.0, math.min(w, h) * .05);
    Paint ribbon(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = thick;

    // Pink arc across the top-left corner.
    canvas.drawPath(
      Path()
        ..moveTo(-thick, h * .16)
        ..cubicTo(w * .12, h * .02, w * .22, h * .14, w * .34, -thick),
      ribbon(RRColors.pink),
    );
    // Lemon ribbon dipping in from the top-right.
    canvas.drawPath(
      Path()
        ..moveTo(w * .7, -thick)
        ..cubicTo(w * .78, h * .08, w * .9, h * .02, w + thick, h * .1),
      ribbon(RRColors.lemon),
    );
    // Navy ribbon looping up from the bottom-left and out the bottom.
    canvas.drawPath(
      Path()
        ..moveTo(-thick, h * .7)
        ..cubicTo(w * .05, h * .72, w * .04, h * .88, -thick * .2, h * .93)
        ..cubicTo(-w * .02, h * .99, w * .3, h * 1.01, w * .55, h + thick),
      ribbon(RRColors.ink),
    );
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => false;
}

/// The "resurhombus." wordmark: a filled rhombus plus the lowercase name in
/// the display font, scaled down rather than overflowing narrow drawers.
class CollageWordmark extends StatelessWidget {
  const CollageWordmark({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ResuRhombus',
    excludeSemantics: true,
    child: Row(
      children: [
        const SizedBox.square(
          dimension: RRSpace.xl,
          child: CustomPaint(
            painter: MotifPainter(TileMotif.rhombus, RRColors.violet),
          ),
        ),
        const SizedBox(width: RRSpace.xs),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'resurhombus.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// One cell in a [TileMosaic] row.
class TileSpec {
  const TileSpec({
    required this.color,
    this.shape = TileShape.square,
    this.motif = TileMotif.none,
    this.motifColor = RRColors.ink,
    this.flex = 1,
    this.label,
    this.labelColor = RRColors.ink,
  });
  final Color color;
  final TileShape shape;
  final TileMotif motif;
  final Color motifColor;
  final int flex;

  /// Short headline such as "grow."; drawn bottom-left in the display font.
  final String? label;
  final Color labelColor;
}

/// Rows of butting tiles, like the reference collage. Each row is [cell]
/// tall; tiles in a row share its width by [TileSpec.flex].
class TileMosaic extends StatelessWidget {
  const TileMosaic({super.key, required this.rows, this.cell = 72});
  final List<List<TileSpec>> rows;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          SizedBox(
            height: cell,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final spec in row)
                  Expanded(
                    flex: spec.flex,
                    child: CollageTile(
                      color: spec.color,
                      shape: spec.shape,
                      motif: spec.motif,
                      motifColor: spec.motifColor,
                      padding: const EdgeInsets.all(RRSpace.md),
                      child: spec.label == null
                          ? null
                          : Align(
                              alignment: Alignment.bottomLeft,
                              child: FittedBox(
                                child: Text(
                                  spec.label!,
                                  style: style?.copyWith(
                                    color: spec.labelColor,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A coloured headline tile for page tops: big lowercase word with a period,
/// one line of context and a motif on the right.
class HeadlineTile extends StatelessWidget {
  const HeadlineTile({
    super.key,
    required this.headline,
    this.message,
    this.color = RRColors.lemon,
    this.textColor = RRColors.ink,
    this.motif = TileMotif.asterisk,
    this.motifColor = RRColors.ink,
    this.trailing,
    this.body,
  });

  final String headline;
  final String? message;

  /// Extra content under the headline, e.g. counts on the recruiter board.
  final Widget? body;
  final Color color, textColor, motifColor;
  final TileMotif motif;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: ShapeDecoration(
        color: color,
        shape: tileBorder(TileShape.halfRight),
      ),
      padding: const EdgeInsets.fromLTRB(
        RRSpace.xl,
        RRSpace.lg,
        RRSpace.lg,
        RRSpace.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style:
                      (MediaQuery.sizeOf(context).width >= 600
                              ? text.displaySmall
                              : text.headlineMedium)
                          ?.copyWith(color: textColor),
                ),
                if (message != null) ...[
                  const SizedBox(height: RRSpace.xs),
                  Text(
                    message!,
                    style: text.bodyLarge?.copyWith(color: textColor),
                  ),
                ],
                if (body != null) ...[
                  const SizedBox(height: RRSpace.xs),
                  body!,
                ],
              ],
            ),
          ),
          ?trailing,
          if (motif != TileMotif.none)
            SizedBox.square(
              dimension: RRSpace.xxxl + RRSpace.sm,
              child: ExcludeSemantics(
                child: CustomPaint(painter: MotifPainter(motif, motifColor)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small tile cluster for empty states: the "geometric illustration" with
/// an optional icon on the lemon circle.
class TileCluster extends StatelessWidget {
  const TileCluster({super.key, this.icon, this.cell = RRSpace.xxxl});

  final IconData? icon;
  final double cell;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: cell * 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CollageTile(
                color: RRColors.lemon,
                shape: TileShape.circle,
                motif: icon == null ? TileMotif.rhombus : TileMotif.none,
                width: cell,
                height: cell,
                padding: EdgeInsets.zero,
                child: icon == null
                    ? null
                    : Icon(icon, color: RRColors.ink, size: cell * .5),
              ),
              CollageTile(
                color: RRColors.violet,
                shape: TileShape.halfRight,
                motif: TileMotif.ring,
                motifColor: RRColors.lemon,
                width: cell,
                height: cell,
              ),
              CollageTile(
                color: RRColors.deck,
                motif: TileMotif.triangle,
                width: cell,
                height: cell,
              ),
            ],
          ),
          Row(
            children: [
              CollageTile(
                color: RRColors.pink,
                shape: TileShape.pill,
                motif: TileMotif.squiggle,
                width: cell * 2,
                height: cell,
              ),
              CollageTile(
                color: RRColors.canvas,
                motif: TileMotif.asterisk,
                motifColor: RRColors.violet,
                width: cell,
                height: cell,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
