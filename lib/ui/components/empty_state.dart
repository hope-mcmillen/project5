import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';
import 'collage.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(RRSpace.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TileCluster(),
        const SizedBox(height: RRSpace.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: RRSpace.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: RRSpace.lg),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
