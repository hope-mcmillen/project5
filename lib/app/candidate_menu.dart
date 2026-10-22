import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';
import '../ui/components/rhombus_mark.dart';
import '../ui/theme/rr_tokens.dart';

/// Lets each existing page open the shell's drawer without a second app bar.
class CandidateMenuScope extends InheritedWidget {
  const CandidateMenuScope({
    super.key,
    required this.openMenu,
    required super.child,
  });

  final VoidCallback openMenu;

  static CandidateMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CandidateMenuScope>();

  @override
  bool updateShouldNotify(CandidateMenuScope oldWidget) =>
      oldWidget.openMenu != openMenu;
}

class CandidateDrawer extends StatelessWidget {
  const CandidateDrawer({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final isResume = location == Routes.profileResume;
    final destinations = [
      (
        label: 'Resume',
        icon: Icons.description_outlined,
        route: Routes.profileResume,
        selected: isResume,
      ),
      (
        label: 'Profile',
        icon: Icons.person_outline,
        route: Routes.candidateProfile,
        selected: !isResume && location.startsWith(Routes.candidateProfile),
      ),
      (
        label: 'Applications',
        icon: Icons.timeline_outlined,
        route: Routes.pipeline,
        selected: location.startsWith(Routes.pipeline),
      ),
      (
        label: 'Job deck',
        icon: Icons.style_outlined,
        route: Routes.deck,
        selected: location.startsWith(Routes.deck),
      ),
    ];
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: const RhombusMark(size: RRSpace.xl),
              title: Text(
                'ResuRhombus',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: IconButton(
                tooltip: 'Close menu',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Divider(),
            for (final destination in destinations)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected: destination.selected,
                onTap: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  if (location != destination.route) {
                    router.go(destination.route);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
