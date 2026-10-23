import 'package:flutter/material.dart';

import '../features/company/presentation/widgets/company_header.dart';
import '../ui/components/rhombus_mark.dart';
import '../ui/theme/rr_tokens.dart';

class EmployerMenuScope extends InheritedWidget {
  const EmployerMenuScope({
    super.key,
    required this.openMenu,
    required super.child,
  });

  final VoidCallback openMenu;

  static Widget? button(BuildContext context) {
    final menu = context
        .dependOnInheritedWidgetOfExactType<EmployerMenuScope>();
    return menu == null
        ? null
        : IconButton(
            tooltip: 'Open navigation menu',
            icon: const Icon(Icons.menu),
            onPressed: menu.openMenu,
          );
  }

  @override
  bool updateShouldNotify(EmployerMenuScope oldWidget) =>
      oldWidget.openMenu != openMenu;
}

class EmployerDrawer extends StatelessWidget {
  const EmployerDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Drawer(
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
          const Padding(
            padding: EdgeInsets.all(RRSpace.lg),
            child: CompanyHeader(),
          ),
          const Divider(),
          for (final tab in [
            (
              index: 1,
              icon: Icons.event_available_outlined,
              label: 'Interviews',
            ),
            (
              index: 2,
              icon: Icons.apartment_outlined,
              label: 'Company Profiles',
            ),
            (index: 0, icon: Icons.work_outline, label: 'Job Postings'),
          ])
            ListTile(
              leading: Icon(tab.icon),
              title: Text(tab.label),
              selected: selectedIndex == tab.index,
              onTap: () {
                Navigator.pop(context);
                onSelected(tab.index);
              },
            ),
        ],
      ),
    ),
  );
}
