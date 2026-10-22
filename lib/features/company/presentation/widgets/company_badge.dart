import 'package:flutter/material.dart';

/// Verified / Unverified company badge (resurhombus-ui CompanyBadge).
///
/// TODO(RC-02): swap for C2's shared `CompanyBadge` in lib/ui/components/.
class CompanyBadge extends StatelessWidget {
  const CompanyBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified : Icons.help_outline,
          size: 16,
          color: verified ? colors.primary : colors.outline,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            verified ? 'Verified' : 'Unverified',
            style: theme.textTheme.labelMedium?.copyWith(
              color: verified ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    if (verified) return badge;
    return Tooltip(
      message:
          'We haven\'t confirmed this company yet. Verification checks that '
          'the recruiter\'s email domain matches the company website.',
      child: badge,
    );
  }
}

/// The company logo, or its initial when there is none.
class CompanyLogo extends StatelessWidget {
  const CompanyLogo({super.key, required this.name, this.url, this.size = 56});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w600,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: colors.primaryContainer,
        child: url == null
            ? initial
            : Image.network(
                url!,
                fit: BoxFit.cover,
                semanticLabel: '$name logo',
                errorBuilder: (_, _, _) => initial,
              ),
      ),
    );
  }
}
