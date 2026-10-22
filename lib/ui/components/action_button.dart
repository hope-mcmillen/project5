import 'package:flutter/material.dart';

/// One consistent, wrapping action button used across both role flows.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context) => primary
      ? FilledButton(
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        )
      : OutlinedButton(
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        );
}
