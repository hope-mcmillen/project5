import 'package:flutter/material.dart';

import '../../app/account_menu.dart';
import '../../app/candidate_menu.dart';
import '../theme/rr_tokens.dart';
import 'collage.dart';

/// The collage headline for a title: "Your deck" becomes "your deck.".
String collageHeadline(String title) {
  final lower = title.toLowerCase();
  return RegExp(r'[.?!]$').hasMatch(lower) ? lower : '$lower.';
}

/// Text colour that stays AA on a decorative tile colour.
Color onTile(Color tile) =>
    tile == RRColors.violet || tile == RRColors.ink || tile == RRColors.pass
    ? RRColors.surface
    : RRColors.ink;

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
    this.headline,
    this.accent = RRColors.lemon,
    this.motif = TileMotif.asterisk,
  });
  final String title, description;
  final Widget child;
  final bool preferMenuButton;
  final Widget? footer;

  /// Extra app bar actions, after the menu button.
  final List<Widget> actions;

  /// Big lowercase headline on the header tile; defaults to the title.
  final String? headline;

  /// Header tile colour (decorative: lemon, pink, sky, violet).
  final Color accent;
  final TileMotif motif;

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
    final ink = onTile(accent);
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
        actions: [
          if (showBack && menuButton != null) menuButton,
          ...actions,
          const AccountMenuButton(),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: RRSpace.pageWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RRSpace.lg,
                RRSpace.sm,
                RRSpace.lg,
                RRSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeadlineTile(
                    headline: headline ?? collageHeadline(title),
                    message: description,
                    color: accent,
                    textColor: ink,
                    motif: motif,
                    motifColor: ink,
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
