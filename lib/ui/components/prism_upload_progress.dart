import 'package:flutter/material.dart';

import '../../core/models/candidate_enums.dart';
import '../theme/rr_tokens.dart';

/// Branded progress art. Animation repaints only the canvas, not the step list.
class PrismUploadProgress extends StatefulWidget {
  const PrismUploadProgress({super.key, required this.status});
  final ResumeStatus status;
  @override
  State<PrismUploadProgress> createState() => _PrismUploadProgressState();
}

class _PrismUploadProgressState extends State<PrismUploadProgress>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled ||
        widget.status == ResumeStatus.ready ||
        widget.status == ResumeStatus.failed ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      _motion.stop();
    } else {
      _motion.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PrismUploadProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: RRSpace.badgeLarge * 2,
        child: CustomPaint(painter: _PrismPainter(_motion)),
      ),
    ),
  );
}

class _PrismPainter extends CustomPainter {
  _PrismPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * .08, h * .5),
      Offset(w * .36, h * .5),
      paint..color = RRColors.framework,
    );
    final path = Path()
      ..moveTo(w * .36, h * .5)
      ..lineTo(w * .5, h * .18)
      ..lineTo(w * .64, h * .5)
      ..lineTo(w * .5, h * .82)
      ..close();
    canvas.drawPath(path, Paint()..color = RRColors.canvas);
    canvas.drawPath(
      path,
      Paint()
        ..color = RRColors.inkMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final colors = [RRColors.deck, RRColors.matchStrong, RRColors.framework];
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(w * .64, h * .5),
        Offset(w * .92, h * (.3 + i * .2)),
        paint..color = colors[i],
      );
    }
    canvas.drawLine(
      Offset(w * .36, h * .5),
      Offset(w * .64, h * .5),
      paint..color = RRColors.matchStrong,
    );
    canvas.drawCircle(
      Offset(w * (.08 + .28 * motion.value), h * .5),
      4,
      Paint()..color = RRColors.matchStrong,
    );
  }

  @override
  bool shouldRepaint(_PrismPainter old) => motion != old.motion;
}
