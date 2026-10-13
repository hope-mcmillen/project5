import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// How a scaffold link navigates.
enum LinkMode {
  /// `context.go`: replaces the location (switching sections/tabs).
  go,

  /// `context.push`: stacks on top so the back button returns here.
  push,
}

/// A navigation connection shown on a placeholder page.
class PageLink {
  const PageLink(
    this.label,
    this.location, {
    this.mode = LinkMode.go,
    this.onBefore,
  });

  final String label;
  final String location;
  final LinkMode mode;

  /// Optional side effect before navigating (e.g. fake sign-in).
  final VoidCallback? onBefore;
}

/// SCAFFOLD ONLY: the filler body every page uses until its task replaces it.
///
/// Shows the page's purpose, the TEAM_PLAN tasks and user stories that will
/// implement it, and buttons for each navigation connection it will have.
/// Delete the `PlaceholderPage` usage when you build the real screen.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    this.tasks = const [],
    this.stories = const [],
    this.links = const [],
    this.params = const {},
    this.showAppBar = true,
  });

  final String title;
  final String description;
  final List<String> tasks;
  final List<String> stories;
  final List<PageLink> links;
  final Map<String, String> params;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                _Meta(label: 'Route', value: location),
                for (final entry in params.entries)
                  _Meta(label: entry.key, value: entry.value),
                if (tasks.isNotEmpty)
                  _Meta(label: 'Tasks', value: tasks.join(', ')),
                if (stories.isNotEmpty)
                  _Meta(label: 'Stories', value: stories.join(', ')),
              ],
            ),
          ),
        ),
        if (links.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Connections', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () {
                  link.onBefore?.call();
                  switch (link.mode) {
                    case LinkMode.go:
                      context.go(link.location);
                    case LinkMode.push:
                      context.push(link.location);
                  }
                },
                child: Text(link.label),
              ),
            ),
        ],
      ],
    );

    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
