import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';

class ShimmerShape extends StatefulWidget {
  const ShimmerShape({super.key, this.height = RRSpace.badgeLarge});
  final double height;
  @override
  State<ShimmerShape> createState() => _ShimmerShapeState();
}

class _ShimmerShapeState extends State<ShimmerShape>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _animation.stop();
    } else if (mounted &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      _animation.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _animation.stop();
    } else {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(RRRadius.lg),
            color: MediaQuery.disableAnimationsOf(context)
                ? RRColors.framework
                : null,
            gradient: MediaQuery.disableAnimationsOf(context)
                ? null
                : LinearGradient(
                    begin: Alignment(-3 + 6 * _animation.value, -1),
                    end: Alignment(-1 + 6 * _animation.value, 1),
                    colors: const [
                      RRColors.framework,
                      RRColors.canvas,
                      RRColors.framework,
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}
