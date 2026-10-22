import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/candidate_models.dart';
import '../../../ui/theme/rr_tokens.dart';
import '../domain/swipe_receipt.dart';

class UndoToast extends StatefulWidget {
  const UndoToast({
    super.key,
    required this.receipt,
    required this.onUndo,
    this.busy = false,
    this.now,
  });
  final SwipeReceipt receipt;
  final VoidCallback onUndo;
  final bool busy;
  final DateTime Function()? now;
  @override
  State<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<UndoToast> {
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_now.isBefore(widget.receipt.undoDeadline)) {
        _timer?.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.receipt.undoDeadline.difference(_now).inMilliseconds;
    if (left <= 0) return const SizedBox.shrink();
    final total = widget.receipt.committedAt
        .difference(widget.receipt.serverNow)
        .inMilliseconds;
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(RRSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.receipt.direction == SwipeDirection.right
                        ? 'Demo application saved for ${widget.receipt.job.title}'
                        : 'Passed on ${widget.receipt.job.title}',
                  ),
                  TextButton(
                    onPressed: widget.busy ? null : widget.onUndo,
                    child: Text('Undo (${(left / 1000).ceil()}s)'),
                  ),
                ],
              ),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: total <= 0 ? 0 : (left / total).clamp(0.0, 1.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PassReasonChips extends StatefulWidget {
  const PassReasonChips({
    super.key,
    required this.receipt,
    required this.onReason,
    this.busy = false,
  });
  final SwipeReceipt receipt;
  final ValueChanged<PassReason> onReason;
  final bool busy;
  @override
  State<PassReasonChips> createState() => _PassReasonChipsState();
}

class _PassReasonChipsState extends State<PassReasonChips> {
  Timer? _timer;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    final left = widget.receipt.receivedAt
        .add(const Duration(seconds: 3))
        .difference(DateTime.now());
    _expired = left <= Duration.zero;
    if (!_expired) {
      _timer = Timer(left, () {
        if (mounted) setState(() => _expired = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _expired
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why pass? Optional'),
            Wrap(
              spacing: RRSpace.sm,
              runSpacing: RRSpace.xs,
              children: [
                for (final reason in PassReason.values)
                  ActionChip(
                    label: Text(reason.label),
                    onPressed: widget.busy
                        ? null
                        : () => widget.onReason(reason),
                  ),
              ],
            ),
          ],
        );
}
