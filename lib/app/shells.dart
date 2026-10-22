import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'candidate_menu.dart';

/// Shared candidate navigation; existing pages and their routes are preserved.
class CandidateShell extends StatelessWidget {
  const CandidateShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CandidateDrawer(location: GoRouterState.of(context).uri.path),
      body: Builder(
        builder: (context) => CandidateMenuScope(
          openMenu: () => Scaffold.of(context).openDrawer(),
          child: navigationShell,
        ),
      ),
    );
  }
}

/// Navigation for the recruiter tabs: Jobs · Interviews · Company.
///
/// TODO(RC-05): NavigationRail on wide screens (≥ 900 px), bottom bar on phones.
class RecruiterShell extends StatelessWidget {
  const RecruiterShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            label: 'Interviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            label: 'Company',
          ),
        ],
      ),
    );
  }
}

/// Shown for unknown routes.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No page at $uri'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
