import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../theme/rr_tokens.dart';
import '../components/rhombus_mark.dart';
import '../components/action_button.dart';

import 'package:go_router/go_router.dart';

import '../../app/candidate_menu.dart';

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
    this.preferMenuButton = false,
  });

  final String title;
  final String description;
  final List<String> tasks;
  final List<String> stories;
  final List<PageLink> links;
  final Map<String, String> params;
  final bool showAppBar;
  final bool preferMenuButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();

    final body = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: RRSpace.pageWidth),
          child: ListView(
            padding: const EdgeInsets.all(RRSpace.xl),
            children: [
              Row(
                children: [
                  const RhombusMark(size: RRSpace.xl),
                  const SizedBox(width: RRSpace.sm),
                  Expanded(
                    child: Text(
                      'RESURHOMBUS',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RRSpace.xxl),
              Text(title, style: theme.textTheme.displaySmall),
              const SizedBox(height: RRSpace.md),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: RRColors.inkMuted,
                ),
              ),
              const SizedBox(height: RRSpace.xl),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RRSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Your next step', style: theme.textTheme.titleLarge),
                      const SizedBox(height: RRSpace.lg),
                      for (final (index, link) in links.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: RRSpace.md),
                          child: ActionButton(
                            label: link.label,
                            primary: index == 0,
                            onPressed: () {
                              link.onBefore?.call();
                              switch (link.mode) {
                                case LinkMode.go:
                                  context.go(link.location);
                                case LinkMode.push:
                                  context.push(link.location);
                              }
                            },
                          ),
                        ),
                      Text(
                        'Prototype preview · Actions demonstrate the flow.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: RRColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: RRSpace.xl),
                ExpansionTile(
                  title: const Text('Development details'),
                  childrenPadding: const EdgeInsets.all(RRSpace.lg),
                  children: [
                    _Meta(label: 'Route', value: location),
                    for (final entry in params.entries)
                      _Meta(label: entry.key, value: entry.value),
                    if (tasks.isNotEmpty)
                      _Meta(label: 'Tasks', value: tasks.join(', ')),
                    if (stories.isNotEmpty)
                      _Meta(label: 'Stories', value: stories.join(', ')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!showAppBar) return body;
    final menu = CandidateMenuScope.maybeOf(context);
    final canPop = Navigator.of(context).canPop();
    final showBackButton = canPop && !(preferMenuButton && menu != null);
    final menuButton = menu == null
        ? null
        : IconButton(
            tooltip: 'Open navigation menu',
            icon: const Icon(Icons.menu),
            onPressed: menu.openMenu,
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: showBackButton ? null : menuButton,
        actions: [if (showBackButton && menuButton != null) menuButton],
      ),
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
