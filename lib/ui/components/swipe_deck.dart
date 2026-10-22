import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';

import '../../core/models/candidate_models.dart';
import '../theme/rr_tokens.dart';
import 'job_card_view.dart';

class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.cards,
    required this.onCommit,
    required this.onDetails,
    this.onBusyChanged,
    this.restoreToken,
    this.restoreDirection,
  });
  final List<JobCard> cards;
  final Future<bool> Function(SwipeDirection) onCommit;
  final ValueChanged<JobCard> onDetails;
  final ValueChanged<bool>? onBusyChanged;
  final String? restoreToken;
  final SwipeDirection? restoreDirection;
  @override
  State<SwipeDeck> createState() => SwipeDeckState();
}

class SwipeDeckState extends State<SwipeDeck>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: RRMotion.medium,
  );
  final _drag = ValueNotifier<Offset>(Offset.zero);
  Animation<Offset>? _travel;
  bool _busy = false, _crossed = false;
  List<Widget> _cards = [];
  @override
  void initState() {
    super.initState();
    _cache();
    _animation.addListener(_tick);
  }

  void _tick() {
    if (_travel != null) _drag.value = _travel!.value;
  }

  void _cache() {
    _cards = [
      for (final job in widget.cards.take(3))
        RepaintBoundary(
          child: JobCardView(job: job, onDetails: () => widget.onDetails(job)),
        ),
    ];
  }

  @override
  void didUpdateWidget(SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cache();
    if (widget.restoreToken != oldWidget.restoreToken &&
        widget.restoreToken != null) {
      _restore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restorationStarted && widget.restoreToken != null) _restore();
  }

  bool _restorationStarted = false;
  void _restore() {
    _restorationStarted = true;
    _busy = true;
    _drag.value = Offset(
      MediaQuery.sizeOf(context).width *
          1.5 *
          (widget.restoreDirection == SwipeDirection.left ? -1 : 1),
      0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      widget.onBusyChanged?.call(true);
      try {
        await _move(Offset.zero, cancel: false);
      } on TickerCanceled {
        /* disposed */
      } finally {
        if (mounted) {
          setState(() => _busy = false);
          widget.onBusyChanged?.call(false);
        }
      }
    });
  }

  Future<void> _move(Offset target, {required bool cancel}) async {
    final reduced = MediaQuery.disableAnimationsOf(context);
    _animation.duration = reduced
        ? const Duration(milliseconds: 100)
        : cancel
        ? RRMotion.slow
        : RRMotion.medium;
    _travel = Tween(begin: _drag.value, end: target)
        .chain(
          CurveTween(
            curve: reduced
                ? Curves.linear
                : cancel
                ? RRMotion.settle
                : RRMotion.emphasized,
          ),
        )
        .animate(_animation);
    await _animation.forward(from: 0).orCancel;
  }

  Future<void> commit(SwipeDirection direction) async {
    if (_busy || widget.cards.isEmpty) return;
    _busy = true;
    widget.onBusyChanged?.call(true);
    HapticFeedback.mediumImpact();
    try {
      await _move(
        Offset(
          MediaQuery.sizeOf(context).width *
              1.5 *
              (direction == SwipeDirection.right ? 1 : -1),
          0,
        ),
        cancel: false,
      );
      if (!mounted) return;
      final saved = await widget.onCommit(direction);
      if (!mounted) return;
      if (!saved) await _move(Offset.zero, cancel: true);
    } on TickerCanceled {
      /* route was disposed while flying out */
    } finally {
      if (mounted) {
        _drag.value = Offset.zero;
        setState(() {
          _busy = false;
          _crossed = false;
        });
        widget.onBusyChanged?.call(false);
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    _busy = true;
    widget.onBusyChanged?.call(true);
    try {
      await _move(Offset.zero, cancel: true);
    } on TickerCanceled {
      /* disposed */
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _crossed = false;
        });
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final job = widget.cards.first;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = _cards.length - 1; i > 0; i--)
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: Transform.translate(
                  offset: Offset(0, i * 10.0),
                  child: Transform.rotate(
                    angle: (i == 1 ? -3 : 2) * math.pi / 180,
                    child: Transform.scale(
                      scale: i == 1 ? 0.94 : 0.88,
                      child: _cards[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: ValueListenableBuilder<Offset>(
            valueListenable: _drag,
            child: _cards.first,
            builder: (context, offset, child) => Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: (offset.dx / width * 15).clamp(-15, 15) * math.pi / 180,
                alignment: Alignment.bottomCenter,
                child: Semantics(
                  container: true,
                  label:
                      '${job.title} at ${job.company.name}, match ${job.matchScore} percent ${job.band.db}',
                  customSemanticsActions: _busy
                      ? {}
                      : {
                          const CustomSemanticsAction(label: 'Apply'): () =>
                              commit(SwipeDirection.right),
                          const CustomSemanticsAction(label: 'Pass'): () =>
                              commit(SwipeDirection.left),
                          const CustomSemanticsAction(
                            label: 'View details',
                          ): () =>
                              widget.onDetails(job),
                        },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      if (_busy) return;
                      _drag.value += Offset(details.delta.dx, 0);
                      final crossed = _drag.value.dx.abs() > width * .35;
                      if (crossed && !_crossed) HapticFeedback.lightImpact();
                      _crossed = crossed;
                    },
                    onHorizontalDragCancel: _cancel,
                    onHorizontalDragEnd: (details) {
                      if (_busy) return;
                      final velocity = details.primaryVelocity ?? 0;
                      if (_drag.value.dx.abs() > width * .35 ||
                          velocity.abs() > 800) {
                        final sign = velocity.abs() > 800
                            ? velocity
                            : _drag.value.dx;
                        commit(
                          sign >= 0
                              ? SwipeDirection.right
                              : SwipeDirection.left,
                        );
                      } else {
                        _cancel();
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(ignoring: _busy, child: child!),
                        ExcludeSemantics(
                          child: IgnorePointer(
                            child: SwipeStamp(
                              progress: (offset.dx / (width * .35)).clamp(
                                -1.0,
                                1.0,
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
      ],
    );
  }
}
