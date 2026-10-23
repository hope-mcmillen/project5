import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'employer_menu.dart';
import 'candidate_menu.dart';

/// Shared navigation for candidate pages, including resume onboarding.
class CandidateNavigation extends StatelessWidget {
  const CandidateNavigation({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: CandidateDrawer(location: GoRouterState.of(context).uri.path),
    body: Builder(
      builder: (context) => CandidateMenuScope(
        openMenu: () => Scaffold.of(context).openDrawer(),
        child: child,
      ),
    ),
  );
}

/// Keeps each candidate tab's navigation state while sharing the sidebar.
class CandidateShell extends StatelessWidget {
  const CandidateShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return CandidateNavigation(child: navigationShell);
  }
}

/// Employer sections share the same slide-out navigation as candidate pages.
class RecruiterShell extends StatelessWidget {
  const RecruiterShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: EmployerDrawer(
      selectedIndex: navigationShell.currentIndex,
      onSelected: (index) => navigationShell.goBranch(index),
    ),
    body: Builder(
      builder: (context) => EmployerMenuScope(
        openMenu: () => Scaffold.of(context).openDrawer(),
        child: navigationShell,
      ),
    ),
  );
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
