import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';

class DeckActionBar extends StatelessWidget {
  const DeckActionBar({
    super.key,
    required this.onPass,
    required this.onDetails,
    required this.onApply,
  });
  final VoidCallback? onPass, onDetails, onApply;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: RRSpace.md,
    runSpacing: RRSpace.sm,
    children: [
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: RRColors.pass,
          minimumSize: const Size(72, 56),
        ),
        onPressed: onPass,
        icon: const Icon(Icons.close),
        label: const Text('Pass'),
      ),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(72, 56)),
        onPressed: onDetails,
        child: const Text('Details'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size(72, 56)),
        onPressed: onApply,
        icon: const Icon(Icons.check),
        label: const Text('Apply'),
      ),
    ],
  );
}
