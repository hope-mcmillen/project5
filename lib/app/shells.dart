import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/company/presentation/widgets/company_header.dart';

/// Bottom navigation for the candidate tabs: Deck · Applications · Profile.
///
/// SCAFFOLD: basic NavigationBar. Styling comes later (resurhombus-ui skill).
class CandidateShell extends StatelessWidget {
  const CandidateShell({super.key, required this.navigationShell});

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
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            label: 'Deck',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            label: 'Applications',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Navigation for the recruiter tabs: Jobs · Interviews · Company (RC-05).
///
/// A bottom [NavigationBar] on phones, a [NavigationRail] from
/// [railBreakpoint] (extended with labels from [extendedBreakpoint]), so the
/// portal feels native on Android and on laptop web.
class RecruiterShell extends StatelessWidget {
  const RecruiterShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const railBreakpoint = 900.0;
  static const extendedBreakpoint = 1200.0;

  static const _tabs = [
    (icon: Icons.work_outline, selected: Icons.work, label: 'Jobs'),
    (
      icon: Icons.event_available_outlined,
      selected: Icons.event_available,
      label: 'Interviews',
    ),
    (
      icon: Icons.apartment_outlined,
      selected: Icons.apartment,
      label: 'Company',
    ),
  ];

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the current tab again returns to its first page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < railBreakpoint) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selected),
                    label: tab.label,
                  ),
              ],
            ),
          );
        }
        final extended = width >= extendedBreakpoint;
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _select,
                extended: extended,
                // RC-22: the company and its verified status.
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: extended
                      ? const SizedBox(width: 224, child: CompanyHeader())
                      : const CompanyHeader(compact: true),
                ),
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final tab in _tabs)
                    NavigationRailDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.selected),
                      label: Text(tab.label),
                      // Extended M3 rows are 44 px tall; keep 48 px targets.
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                ],
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
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
