import 'package:flutter/material.dart';

/// The pasted job description with one evidence quote highlighted
/// (RC-09b: selecting a requirement shows where it came from).
class DescriptionPanel extends StatelessWidget {
  const DescriptionPanel({super.key, required this.text, this.highlight});

  final String text;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = highlight?.trim() ?? '';
    final at = quote.isEmpty
        ? -1
        : text.toLowerCase().indexOf(quote.toLowerCase());
    final style = theme.textTheme.bodyMedium;
    return SelectableText.rich(
      at == -1
          ? TextSpan(text: text, style: style)
          : TextSpan(
              style: style,
              children: [
                TextSpan(text: text.substring(0, at)),
                TextSpan(
                  text: text.substring(at, at + quote.length),
                  style: TextStyle(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: text.substring(at + quote.length)),
              ],
            ),
    );
  }
}
