import 'package:flutter/material.dart';

import '../../domain/board_tile.dart';

/// A responsive grid of tiles (max 320 px each, so 1–5 columns by width)
/// that animates tiles in and out by application id (RC-12).
class MosaicGrid extends StatefulWidget {
  const MosaicGrid({
    super.key,
    required this.tiles,
    required this.itemBuilder,
    this.tileHeight = 184,
  });

  static const maxTileWidth = 320.0;

  final List<BoardTile> tiles;
  final Widget Function(BuildContext context, BoardTile tile) itemBuilder;

  /// Unscaled tile height; grows with the text scale.
  final double tileHeight;

  @override
  State<MosaicGrid> createState() => _MosaicGridState();
}

class _MosaicGridState extends State<MosaicGrid> {
  var _gridKey = GlobalKey<SliverAnimatedGridState>();
  late List<BoardTile> _items = List.of(widget.tiles);

  static const _duration = Duration(milliseconds: 250);

  @override
  void didUpdateWidget(MosaicGrid old) {
    super.didUpdateWidget(old);
    final next = widget.tiles;
    final grid = _gridKey.currentState;
    if (grid == null) {
      _items = List.of(next);
      return;
    }
    final nextIds = {for (final t in next) t.applicationId};

    // Animate removals, last first so indexes stay valid.
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!nextIds.contains(_items[i].applicationId)) {
        final removed = _items.removeAt(i);
        grid.removeItem(
          i,
          (context, animation) => _transition(animation, removed),
          duration: _duration,
        );
      }
    }
    // Animate insertions at their sorted positions.
    for (var i = 0; i < next.length; i++) {
      final id = next[i].applicationId;
      if (i < _items.length && _items[i].applicationId == id) {
        _items[i] = next[i];
        continue;
      }
      if (_items.any((t) => t.applicationId == id)) break;
      _items.insert(i, next[i]);
      grid.insertItem(i, duration: _duration);
    }
    // Anything else (a reorder) rebuilds the grid without animation.
    final inOrder =
        _items.length == next.length &&
        [
          for (var i = 0; i < next.length; i++)
            _items[i].applicationId == next[i].applicationId,
        ].every((same) => same);
    if (!inOrder) {
      _items = List.of(next);
      _gridKey = GlobalKey<SliverAnimatedGridState>();
    } else {
      _items = List.of(next);
    }
  }

  Widget _transition(Animation<double> animation, BoardTile tile) =>
      FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(animation),
          child: IgnorePointer(child: widget.itemBuilder(context, tile)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(widget.tileHeight);
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverAnimatedGrid(
        key: _gridKey,
        initialItemCount: _items.length,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: MosaicGrid.maxTileWidth,
          mainAxisExtent: height,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemBuilder: (context, index, animation) => FadeTransition(
          opacity: animation,
          child: KeyedSubtree(
            key: ValueKey(_items[index].applicationId),
            child: widget.itemBuilder(context, _items[index]),
          ),
        ),
      ),
    );
  }
}
