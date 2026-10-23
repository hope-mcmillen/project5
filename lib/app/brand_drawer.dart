import 'package:flutter/material.dart';

import '../ui/components/collage.dart';
import '../ui/theme/rr_tokens.dart';
import 'account_menu.dart';

/// Shared slide-out menu for both roles: collage header, the role's
/// destinations, and Sign out pinned at the bottom.
class BrandDrawer extends StatelessWidget {
  const BrandDrawer({super.key, required this.children, this.headline});

  final List<Widget> children;

  /// Role word shown on the header tile, e.g. "swipe." or "hire.".
  final String? headline;

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(RRSpace.md),
              children: [
                Row(
                  children: [
                    const Expanded(child: CollageWordmark()),
                    IconButton(
                      tooltip: 'Close menu',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: RRSpace.md),
                TileMosaic(
                  cell: RRSpace.xxxl,
                  rows: [
                    [
                      TileSpec(
                        color: RRColors.violet,
                        flex: 3,
                        label: headline,
                        labelColor: RRColors.surface,
                      ),
                      const TileSpec(
                        color: RRColors.deck,
                        shape: TileShape.halfRight,
                        motif: TileMotif.triangle,
                      ),
                      const TileSpec(
                        color: RRColors.lemon,
                        shape: TileShape.circle,
                        motif: TileMotif.rhombus,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: RRSpace.md),
                ...children,
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: RRSpace.md),
            child: DrawerSignOutTile(),
          ),
        ],
      ),
    ),
  );
}

/// A drawer destination with the lemon "selected" pill.
class BrandDrawerTile extends StatelessWidget {
  const BrandDrawerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RRSpace.xs),
    child: ListTile(
      shape: const StadiumBorder(),
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    ),
  );
}
