import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(RRSpace.lg),
      decoration: BoxDecoration(
        color: RRColors.pass.withValues(alpha: .06),
        borderRadius: const BorderRadius.all(RRRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: RRColors.pass),
          const SizedBox(width: RRSpace.sm),
          Expanded(
            child: Text(message, style: const TextStyle(color: RRColors.pass)),
          ),
        ],
      ),
    ),
  );
}
