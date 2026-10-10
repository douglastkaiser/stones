import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import '../models/cosmetics.dart';
import '../models/piece.dart';
import '../theme/game_colors.dart';
import 'procedural_painters.dart';

/// Visual data only: square and Hex retain their own rules and piece models.
class StackVisualPiece {
  const StackVisualPiece(
      {required this.type,
      required this.style,
      required this.colors,
      required this.owner,
      this.isLight = true,
      this.preview = false});
  final PieceType type;
  final PieceStyle style;
  final PieceColors colors;
  final String owner;
  final bool isLight;
  final bool preview;
  String get description => '$owner ${switch (type) {
        PieceType.flat => 'flat',
        PieceType.standing => 'wall',
        PieceType.capstone => 'capstone',
      }}${preview ? ' (preview)' : ''}';
  @override
  bool operator ==(Object other) =>
      other is StackVisualPiece &&
      type == other.type &&
      style == other.style &&
      owner == other.owner &&
      isLight == other.isLight &&
      preview == other.preview &&
      colors.primary == other.colors.primary &&
      colors.secondary == other.colors.secondary &&
      colors.border == other.colors.border;
  @override
  int get hashCode => Object.hash(type, style, owner, isLight, preview,
      colors.primary, colors.secondary, colors.border);

  double get aspect => switch (type) {
        PieceType.flat => .55,
        PieceType.standing => 1.0,
        PieceType.capstone => .85,
      };
}

/// One deterministic fit calculation for both renderers, including rectangular
/// cells and intermediate preview states. Layers retain bottom-to-top indices.
class StackLayerLayout {
  StackLayerLayout(Size size, List<StackVisualPiece> pieces,
      {required bool expanded}) {
    if (pieces.isEmpty ||
        size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }
    final side = math.min(size.width, size.height);
    final count = math.min(pieces.length, expanded ? 5 : 3);
    final start = pieces.length - count;
    final width = side * (expanded ? .62 : .7);
    final tallest =
        pieces.skip(start).map((p) => p.aspect * width).reduce(math.max);
    final spacing = count <= 1
        ? 0.0
        : math.min(width * (expanded ? .25 : .16),
            math.max(0, side * .88 - tallest) / (count - 1));
    final extent = List.generate(
            count, (i) => i * spacing + pieces[start + i].aspect * width)
        .reduce(math.max);
    final bottom = (size.height - extent) / 2;
    for (var i = 0; i < count; i++) {
      final height = pieces[start + i].aspect * width;
      layers.add((
        index: start + i,
        rect: Rect.fromLTWH(
            (size.width - width) / 2 +
                (expanded && count > 1
                    ? (i / (count - 1) - .5) * side * .12
                    : 0),
            size.height - bottom - i * spacing - height,
            width,
            height)
      ));
    }
  }
  final List<({int index, Rect rect})> layers = [];
}

/// Pieces are supplied bottom first. Geometry always fits inside the cell,
/// including a wall/cap on a tall stack and stacks containing preview stones.
class PieceStackView extends StatelessWidget {
  const PieceStackView(
      {super.key, required this.pieces, this.expanded = false});
  final List<StackVisualPiece> pieces;
  final bool expanded;

  static Widget stone(StackVisualPiece piece, double width) {
    final height = width * piece.aspect;
    return Opacity(
        opacity: piece.preview ? .5 : 1,
        child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
                painter: ThemedPiecePainter(
                    style: piece.style,
                    colors: piece.colors,
                    type: piece.type,
                    isLightPlayer: piece.isLight))));
  }

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(child: LayoutBuilder(builder: (context, bounds) {
      final side = math.min(bounds.maxWidth, bounds.maxHeight);
      final layout = StackLayerLayout(
          Size(bounds.maxWidth, bounds.maxHeight), pieces,
          expanded: expanded);
      return Stack(children: [
        for (final layer in layout.layers)
          AnimatedPositioned.fromRect(
              key: ValueKey((
                layer.index,
                pieces[layer.index].owner,
                pieces[layer.index].type,
                pieces[layer.index].preview
              )),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              rect: layer.rect,
              child: stone(pieces[layer.index], layer.rect.width)),
        if (pieces.length > 1)
          Positioned(
              bottom: side * .04,
              right: side * .05,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                      color: GameColors.stackBadge,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white54, width: .5)),
                  child: Text('${pieces.length}',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                          color: GameColors.stackBadgeText,
                          fontSize: (side * .17).clamp(9, 13),
                          fontWeight: FontWeight.bold)))),
      ]);
    }));
  }
}

/// Hover previews never capture movement. Hold/right-click opens a persistent,
/// scrollable inspector, so fingers do not obscure the pieces being inspected.
class StackInspection extends StatefulWidget {
  const StackInspection(
      {super.key,
      required this.pieces,
      required this.label,
      required this.builder,
      this.inspectionPieces});
  final List<StackVisualPiece> pieces;
  final List<StackVisualPiece>? inspectionPieces;
  final String label;
  final Widget Function(bool expanded) builder;
  @override
  State<StackInspection> createState() => _StackInspectionState();
}

class _StackInspectionState extends State<StackInspection> {
  Timer? _timer;
  bool _expanded = false;
  bool _inside = false;
  final Set<int> _pointers = {};
  bool _inspecting = false;
  late List<StackVisualPiece> _contents;

  @override
  void initState() {
    super.initState();
    _contents = List.unmodifiable(widget.pieces);
  }

  void _expand(bool value) {
    _timer?.cancel();
    if (!mounted || value == _expanded) return;
    setState(() => _expanded = value);
  }

  void _schedule() {
    _timer?.cancel();
    if (!_inside ||
        _pointers.isNotEmpty ||
        _inspecting ||
        widget.pieces.length < 2) {
      return;
    }
    _timer = Timer(const Duration(milliseconds: 240), () {
      if (mounted &&
          _inside &&
          _pointers.isEmpty &&
          !_inspecting &&
          widget.pieces.length > 1) {
        _expand(true);
      }
    });
  }

  @override
  void didUpdateWidget(StackInspection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Value comparison includes cosmetics and preview state, even if callers
    // mutate or recreate their lists. Reset pending timers as well as expansion.
    if (!listEquals(_contents, widget.pieces)) {
      _timer?.cancel();
      _contents = List.unmodifiable(widget.pieces);
      _expanded = false;
      _schedule();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _inspect() async {
    final contents = widget.inspectionPieces ?? widget.pieces;
    if (contents.isEmpty || _inspecting) return;
    _inspecting = true;
    _expand(false);
    final pieces = List<StackVisualPiece>.of(contents.reversed);
    final label = widget.label;
    try {
      await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .65,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '$label · ${pieces.length} ${pieces.length == 1 ? 'piece' : 'pieces'}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium)),
                          IconButton(
                              tooltip: 'Close stack inspection',
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context))
                        ])),
                    Expanded(
                        child: ListView.builder(
                            itemCount: pieces.length + 1,
                            itemBuilder: (context, row) {
                              if (row == 0) {
                                return const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(
                                        'Top → bottom · snapshot when opened. Carry from top; drop from bottom.'));
                              }
                              final index = row - 1;
                              return ListTile(
                                  leading: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                          child: PieceStackView.stone(
                                              pieces[index], 40))),
                                  title: Text(pieces[index].description),
                                  subtitle: Text(index == 0
                                      ? 'Top · controls this stack'
                                      : index == pieces.length - 1
                                          ? 'Bottom'
                                          : 'Buried'),
                                  trailing: Text('${pieces.length - index}'));
                            })),
                  ]))));
    } finally {
      _inspecting = false;
      if (mounted) _schedule();
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
      onLongPress:
          (widget.inspectionPieces ?? widget.pieces).isEmpty ? null : _inspect,
      hint: (widget.inspectionPieces ?? widget.pieces).isEmpty
          ? null
          : 'Hold or right-click to inspect the stack',
      customSemanticsActions: (widget.inspectionPieces ?? widget.pieces).isEmpty
          ? null
          : {const CustomSemanticsAction(label: 'Inspect stack'): _inspect},
      child: MouseRegion(
          onEnter: (_) {
            _inside = true;
            _schedule();
          },
          onExit: (_) {
            _inside = false;
            _expand(false);
          },
          child: Listener(
              onPointerDown: (event) {
                _pointers.add(event.pointer);
                _expand(false);
              },
              onPointerUp: (event) => _pointers.remove(event.pointer),
              onPointerCancel: (event) => _pointers.remove(event.pointer),
              child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onLongPress:
                      (widget.inspectionPieces ?? widget.pieces).isEmpty
                          ? null
                          : _inspect,
                  onSecondaryTap:
                      (widget.inspectionPieces ?? widget.pieces).isEmpty
                          ? null
                          : _inspect,
                  child: widget.builder(_expanded)))));
}
