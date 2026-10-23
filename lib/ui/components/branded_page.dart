import 'package:flutter/material.dart';

import '../../app/candidate_menu.dart';
import '../theme/rr_tokens.dart';
import 'rhombus_mark.dart';

/// Shared shell for real feature screens; supports the existing candidate menu.
class BrandedPage extends StatelessWidget {
  const BrandedPage({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.preferMenuButton = false,
    this.footer,
    this.actions = const [],
  });
  final String title, description;
  final Widget child;
  final bool preferMenuButton;
  final Widget? footer;

  /// Extra app bar actions, after the menu button.
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final menu = CandidateMenuScope.maybeOf(context);
    final showBack =
        Navigator.of(context).canPop() && !(preferMenuButton && menu != null);
    final menuButton = menu == null
        ? null
        : IconButton(
            tooltip: 'Open navigation menu',
            icon: const Icon(Icons.menu),
            onPressed: menu.openMenu,
          );
    final text = Theme.of(context).textTheme;
    return Scaffold(
      bottomNavigationBar: footer == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RRSpace.xl,
                  vertical: RRSpace.md,
                ),
                child: Align(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: RRSpace.pageWidth,
                    ),
                    child: SizedBox(width: double.infinity, child: footer),
                  ),
                ),
              ),
            ),
      appBar: AppBar(
        title: Text(title),
        leading: showBack ? null : menuButton,
        actions: [if (showBack && menuButton != null) menuButton, ...actions],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: RRSpace.pageWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RRSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const RhombusMark(size: RRSpace.xl),
                      const SizedBox(width: RRSpace.sm),
                      Expanded(
                        child: Text('RESURHOMBUS', style: text.labelLarge),
                      ),
                    ],
                  ),
                  const SizedBox(height: RRSpace.xxl),
                  Text(title, style: text.displaySmall),
                  const SizedBox(height: RRSpace.md),
                  Text(
                    description,
                    style: text.bodyLarge?.copyWith(color: RRColors.inkMuted),
                  ),
                  const SizedBox(height: RRSpace.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
