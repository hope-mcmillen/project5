import 'package:flutter/material.dart';

import '../theme/rr_tokens.dart';

class CompanyBadge extends StatelessWidget {
  const CompanyBadge({super.key, required this.verified});
  final bool verified;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: verified
        ? 'Company email domain matches its website.'
        : 'Company domain has not been verified.',
    child: Chip(
      avatar: Icon(
        verified ? Icons.verified_outlined : Icons.info_outline,
        size: RRSpace.lg,
        color: RRColors.inkMuted,
      ),
      label: Text(verified ? 'Verified company' : 'Unverified company'),
    ),
  );
}
