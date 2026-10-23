import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_log.dart';

/// Logs each tap the user makes, tagged `tap`:
///
///     [tap] FilledButton "Read description" on /r/jobs/new
///
/// It doesn't change any widget: it watches pointer events at the root,
/// hit-tests the tap position, and walks up from the widget under the finger
/// to the control that handles it. Debug builds only, since it relies on
/// each render object's `debugCreator`.
class TapLogger extends StatefulWidget {
  const TapLogger({super.key, required this.child});

  final Widget child;

  @override
  State<TapLogger> createState() => _TapLoggerState();
}

class _TapLoggerState extends State<TapLogger> {
  final _downs = <int, ({Offset position, Duration time})>{};

  /// Further than this between down and up is a drag or scroll, not a tap.
  static const _slop = 18.0;
  static const _longPress = Duration(milliseconds: 800);

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !AppLog.enabled('INFO')) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) =>
          _downs[e.pointer] = (position: e.position, time: e.timeStamp),
      onPointerCancel: (e) => _downs.remove(e.pointer),
      onPointerUp: (e) {
        final down = _downs.remove(e.pointer);
        if (down == null || (e.position - down.position).distance > _slop) {
          return;
        }
        final long = e.timeStamp - down.time > _longPress;
        final target = describeTapTarget(e.position, e.viewId);
        if (target == null) return;
        AppLog.info(
          'tap',
          '${long ? 'long-press ' : ''}$target on ${AppLog.page}',
        );
      },
      child: widget.child,
    );
  }
}

/// `FilledButton "Save"`, `IconButton "Open navigation menu"`,
/// `TextField "Email"`, … for the control at [position], or null when the
/// tap landed on nothing interactive.
@visibleForTesting
String? describeTapTarget(Offset position, int viewId) {
  try {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, position, viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject) continue;
      final creator = target.debugCreator;
      if (creator is! DebugCreator) continue;
      final described = _describe(creator.element);
      if (described != null) return described;
    }
  } catch (_) {
    // Logging must never break input handling.
  }
  return null;
}

String? _describe(Element start) {
  Element? control;
  var steps = 0;
  bool visit(Element e) {
    if (++steps > 80) return false;
    final widget = e.widget;
    if (_isNamedControl(widget)) {
      control = e;
      return false;
    }
    // A bare InkWell / GestureDetector counts only if nothing named is above
    // it nearby (a FilledButton contains an InkWell, for example).
    if (control == null && _isGenericTap(widget)) control = e;
    return true;
  }

  if (visit(start)) start.visitAncestorElements(visit);
  final found = control;
  if (found == null) return null;
  var target = found;
  // Some controls wrap a private one (IconButton builds _IconButtonM3, a
  // ButtonStyleButton): prefer the public control just above.
  if (target.widget.runtimeType.toString().startsWith('_')) {
    Element? outer;
    var above = 0;
    target.visitAncestorElements((e) {
      if (_isNamedControl(e.widget)) {
        outer = e;
        return false;
      }
      return ++above < 8;
    });
    if (outer != null) target = outer!;
  }
  final label = _label(target);
  final type = target.widget.runtimeType.toString().replaceAll(
    RegExp('^_'),
    '',
  );
  return label == null ? type : '$type "$label"';
}

bool _isNamedControl(Widget w) =>
    w is ButtonStyleButton ||
    w is IconButton ||
    w is FloatingActionButton ||
    w is ListTile ||
    w is CheckboxListTile ||
    w is SwitchListTile ||
    w is RadioListTile ||
    w is Checkbox ||
    w is Switch ||
    w is Radio ||
    w is RawChip ||
    w is ActionChip ||
    w is FilterChip ||
    w is ChoiceChip ||
    w is InputChip ||
    w is PopupMenuItem ||
    w is PopupMenuButton ||
    w is DropdownButton ||
    w is DropdownMenuItem ||
    w is SegmentedButton ||
    w is NavigationDestination ||
    w is Tab ||
    w is TextField;

bool _isGenericTap(Widget w) =>
    (w is InkResponse && (w.onTap != null || w.onLongPress != null)) ||
    (w is GestureDetector && (w.onTap != null || w.onLongPress != null));

String? _label(Element element) {
  final widget = element.widget;
  if (widget is TextField) {
    return widget.decoration?.labelText ?? widget.decoration?.hintText;
  }
  if (widget is IconButton && widget.tooltip != null) return widget.tooltip;
  final tooltip = _tooltipAbove(element);
  final texts = <String>[];
  var visited = 0;
  void collect(Element e) {
    if (texts.length >= 3 || ++visited > 300) return;
    final w = e.widget;
    if (w is Text) {
      final value = w.data ?? w.textSpan?.toPlainText();
      if (value != null && value.trim().isNotEmpty) texts.add(value.trim());
      return;
    }
    if (w is RichText) {
      final value = w.text.toPlainText().trim();
      if (value.isNotEmpty) texts.add(value);
      return;
    }
    if (w is Icon) {
      // An icon renders its glyph as text; only its label is meaningful.
      if (w.semanticLabel != null) texts.add(w.semanticLabel!);
      return;
    }
    // A nested control (a row's trailing button) labels itself.
    if (e != element && _isNamedControl(w)) return;
    e.visitChildren(collect);
  }

  element.visitChildren(collect);
  final text = texts.join(' · ');
  final label = text.isNotEmpty ? text : tooltip;
  if (label == null || label.trim().isEmpty) return null;
  return label.length > 80 ? '${label.substring(0, 80)}…' : label;
}

String? _tooltipAbove(Element element) {
  String? message;
  var steps = 0;
  element.visitAncestorElements((e) {
    final w = e.widget;
    if (w is Tooltip) {
      message = w.message;
      return false;
    }
    return ++steps < 6;
  });
  return message;
}
