import 'dart:math' as math;
import 'package:flutter/foundation.dart' show setEquals, listEquals;
import 'package:flutter/material.dart' hide Step;
import '../models/cosmetics.dart';
import '../widgets/board_cell_gestures.dart';
import '../widgets/piece_stack_view.dart';
import '../widgets/procedural_painters.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';
import 'match_rules.dart';
import 'stack_move_tray.dart';
import 'seat_appearance.dart';

/// All pixel geometry lives here; legality only sees BoardGeometry.
class BoardLayout {
  BoardLayout(this.size, this.geometry) {
    final hex = geometry is HexGeometry;
    unit = math.max(
        0,
        hex
            ? math.min(
                (size.width - 32) /
                    (math.sqrt(3) * (2 * geometry.size + 1) + 1),
                (size.height - 24) / (3 * geometry.size + 3))
            : math.min(size.width - 24, size.height - 24) / geometry.size / 2);
  }
  final Size size;
  final BoardGeometry geometry;
  late final double unit;
  Offset center(Cell cell) => geometry is HexGeometry
      ? Offset(size.width / 2 + unit * math.sqrt(3) * (cell.x + cell.y / 2),
          size.height / 2 + unit * 1.5 * cell.y)
      : Offset(size.width / 2 + unit * (2 * cell.x + 1 - geometry.size),
          size.height / 2 + unit * (2 * cell.y + 1 - geometry.size));
  Rect bounds(Cell cell) =>
      Rect.fromCenter(center: center(cell), width: unit * 2, height: unit * 2);
  Path polygon(Cell cell) {
    if (geometry is SquareGeometry) {
      return Path()..addRect(bounds(cell).deflate(unit * .04));
    }
    final path = Path();
    final origin = center(cell);
    for (var i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180;
      final point =
          origin + Offset(math.cos(angle), math.sin(angle)) * (unit * .94);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Step direction(Offset delta) {
    var best = geometry.directions.first;
    var score = double.negativeInfinity;
    for (final step in geometry.directions) {
      final vector = geometry is HexGeometry
          ? Offset(math.sqrt(3) * (step.x + step.y / 2), 1.5 * step.y)
          : Offset(step.x.toDouble(), step.y.toDouble());
      final projection =
          (delta.dx * vector.dx + delta.dy * vector.dy) / vector.distance;
      if (projection > score) {
        score = projection;
        best = step;
      }
    }
    return best;
  }
}

class BoardView extends StatefulWidget {
  const BoardView(
      {super.key,
      required this.game,
      this.original,
      this.selected,
      this.destinations = const {},
      this.road = const {},
      this.styles = const {},
      this.theme = BoardTheme.classicWood,
      this.onCell,
      this.onInspect,
      this.drops = const [],
      this.routeSource,
      this.routeDirection,
      this.carried = const [],
      this.handCell,
      this.onSwipe});
  final MatchState game;
  final MatchState? original;
  final Cell? selected;
  final Set<Cell> destinations;
  final Set<Cell> road;
  final Map<SeatId, PieceStyle> styles;
  final BoardTheme theme;
  final ValueChanged<Cell>? onCell;
  final void Function(Cell, Step)? onSwipe;

  final ValueChanged<Cell>? onInspect;
  final List<int> drops;
  final Cell? routeSource, handCell;
  final Step? routeDirection;
  final List<Stone> carried;
  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  MatchState get game => widget.game;
  MatchState? get original => widget.original;
  Cell? get selected => widget.selected;
  Set<Cell> get destinations => widget.destinations;
  Set<Cell> get road => widget.road;
  Map<SeatId, PieceStyle> get styles => widget.styles;
  BoardTheme get theme => widget.theme;
  ValueChanged<Cell>? get onCell => widget.onCell;
  void Function(Cell, Step)? get onSwipe => widget.onSwipe;
  Cell? _dragCell;
  Offset? _dragOffset;

  void _resetDrag() {
    if (!mounted || _dragCell == null) return;
    setState(() {
      _dragCell = null;
      _dragOffset = null;
    });
  }

  bool _canDrag(Cell cell) {
    final base = original ?? game;
    if (base.finished || base.opening) return false;
    if (widget.handCell != null) {
      return cell == widget.handCell && widget.carried.isNotEmpty;
    }
    return base.topAt(cell)?.seat == base.current;
  }

  Map<Cell, int> get _staged {
    final counts = <Cell, int>{};
    var cell = widget.routeSource;
    for (final drop in widget.drops) {
      cell = cell!.step(widget.routeDirection!);
      counts[cell] = drop;
    }
    return counts;
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.game, game) ||
        oldWidget.onSwipe != widget.onSwipe) {
      _dragCell = null;
      _dragOffset = null;
    }
  }

  List<StackVisualPiece> _visuals(Cell cell, {bool before = false}) {
    final stones = (before ? original ?? game : game).stackAt(cell);
    final previous = original?.stackAt(cell);
    var prefix = 0;
    if (!before && previous != null) {
      while (prefix < previous.length &&
          prefix < stones.length &&
          previous[prefix] == stones[prefix]) {
        prefix++;
      }
    }
    return [
      for (var i = 0; i < stones.length; i++)
        StackVisualPiece(
            type: stones[i].type,
            style: styles[stones[i].seat] ?? PieceStyle.standard,
            colors: SeatAppearance.colors(
                stones[i].seat, styles[stones[i].seat] ?? PieceStyle.standard),
            owner: stones[i].seat.label,
            isLight: stones[i].seat != SeatId.charcoal,
            preview: !before && previous != null && i >= prefix),
    ];
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final layout = BoardLayout(
            Size(constraints.maxWidth, constraints.maxHeight), game.geometry);
        final material = BoardThemeData.forTheme(theme);
        return Semantics(
            label:
                '${game.config.shape.name} board. Every player shares opposite-side goals.',
            child: Stack(children: [
              RepaintBoundary(
                  child: CustomPaint(
                      size: layout.size,
                      painter: _BoardPainter(
                          layout,
                          material,
                          selected,
                          destinations,
                          road,
                          widget.routeSource,
                          widget.routeDirection,
                          widget.drops))),
              for (final cell in game.geometry.cells)
                Positioned.fromRect(
                    rect: layout.bounds(cell),
                    child: ClipPath(
                      clipper: _CellClipper(layout, cell),
                      child: MergeSemantics(
                          child: Semantics(
                        key: ValueKey('cell-${cell.x}-${cell.y}'),
                        label:
                            'Cell ${cell.x}, ${cell.y}, ${game.topAt(cell) == null ? 'empty' : '${game.topAt(cell)!.seat.label} ${game.topAt(cell)!.type.name}, ${game.stackAt(cell).length} pieces'}${_staged[cell] == null ? '' : ', ${_staged[cell]} staged'}${widget.handCell == cell && widget.carried.isNotEmpty ? ', ${widget.carried.length} carried' : ''}${destinations.contains(cell) ? ', drop one bottom stone' : ''}',
                        button: true,
                        enabled: onCell != null,
                        selected: selected == cell,
                        child: StackInspection(
                          label: 'Stack ${cell.x}, ${cell.y}',
                          onInspect: widget.onInspect == null
                              ? null
                              : () => widget.onInspect!(cell),
                          pieces: _visuals(cell),
                          inspectionPieces: original != null && selected == cell
                              ? _visuals(cell, before: true)
                              : null,
                          builder: (expanded) => Material(
                              type: MaterialType.transparency,
                              child: BoardCellGestures(
                                onDragUpdate: onSwipe == null
                                    ? null
                                    : (delta) {
                                        if (_canDrag(cell)) {
                                          setState(() {
                                            _dragCell = cell;
                                            _dragOffset = delta;
                                          });
                                        }
                                      },
                                onDragCancel: _resetDrag,
                                onDrag: onSwipe == null
                                    ? null
                                    : (delta) =>
                                        onSwipe!(cell, layout.direction(delta)),
                                child: InkWell(
                                    onTap: onCell == null
                                        ? null
                                        : () => onCell!(cell),
                                    child: Stack(children: [
                                      Positioned.fill(
                                          child: RepaintBoundary(
                                              child: PieceStackView(
                                                  pieces: _visuals(cell),
                                                  expanded: expanded))),
                                      ..._cellBadges(context, layout, cell),
                                    ])),
                              )),
                        ),
                      )),
                    )),
              if (_dragCell != null && _dragOffset != null)
                ..._dragFeedback(context, layout),
            ]));
      });
  List<Widget> _cellBadges(
      BuildContext context, BoardLayout layout, Cell cell) {
    final palette = Theme.of(context).colorScheme;
    final top = game.topAt(cell);
    final staged = _staged[cell];
    final hex = game.geometry is HexGeometry;
    Widget badge(
        String id, String text, Alignment alignment, Color color, Color ink,
        {double fontSize = 9}) {
      final centered = alignment.x == 0;
      final below = alignment.y > 0;
      final inset = hex ? layout.unit * .5 : math.max(3.0, layout.unit * .06);
      return Align(
          alignment: alignment,
          child: Padding(
              padding: EdgeInsets.only(
                  top: below ? 0 : inset,
                  bottom: below ? inset : 0,
                  left: centered
                      ? 0
                      : hex
                          ? layout.unit * .4
                          : inset,
                  right: centered
                      ? 0
                      : hex
                          ? layout.unit * .4
                          : inset),
              child: ExcludeSemantics(
                  child: Container(
                      key: ValueKey('$id-$cell'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                          color: color, borderRadius: BorderRadius.circular(3)),
                      child: Text(text,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: ink))))));
    }

    return [
      if (destinations.contains(cell) && layout.unit >= 20)
        badge(
            'drop-target',
            'Drop 1',
            hex ? Alignment.topCenter : Alignment.topLeft,
            const Color(0xFF275C51),
            Colors.white),
      if (staged != null)
        badge(
            'staged-count',
            '+$staged${layout.unit < 20 ? '' : ' ${top?.seat.symbol ?? ''}'}',
            Alignment.topCenter,
            palette.primaryContainer,
            palette.onPrimaryContainer,
            fontSize: layout.unit < 20 ? 7 : 9)
      else if (top != null && !destinations.contains(cell))
        badge('stack-owner', top.seat.symbol, Alignment.topRight,
            SeatAppearance.marker(top.seat), Colors.black,
            fontSize: (layout.unit * .28).clamp(8, 13)),
      if (widget.handCell == cell &&
          widget.carried.isNotEmpty &&
          layout.unit >= 20)
        badge(
            'carry-count',
            '${widget.carried.length} held',
            hex ? Alignment.bottomCenter : Alignment.bottomLeft,
            palette.surface,
            palette.onSurface),
    ];
  }

  List<Widget> _dragFeedback(BuildContext context, BoardLayout layout) {
    final cell = _dragCell!;
    final target = cell.step(layout.direction(_dragOffset!));
    final base = original ?? game;
    final stack = base.stackAt(cell);
    final carried = widget.carried.isNotEmpty
        ? widget.carried
        : stack
            .skip(math.max(0, stack.length - base.geometry.carryLimit))
            .toList();
    final legal = widget.handCell != null
        ? destinations.contains(target)
        : MatchRules.previewSpread(base, cell, carried.length,
                layout.direction(_dragOffset!), [1]).position !=
            null;
    final side = layout.unit * 1.5;
    final origin =
        layout.center(cell) + _dragOffset! - Offset(side / 2, side * 1.25);
    return [
      if (base.geometry.contains(target))
        Positioned.fromRect(
            rect: layout.bounds(target).deflate(3),
            child: IgnorePointer(
                child: DecoratedBox(
                    key: const ValueKey('drag-target'),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: legal
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                            width: 3),
                        borderRadius: BorderRadius.circular(8))))),
      Positioned(
          left: origin.dx.clamp(0, math.max(0, layout.size.width - side)),
          top: origin.dy.clamp(0, math.max(0, layout.size.height - side)),
          width: side,
          height: side,
          child: IgnorePointer(
              child: Opacity(
                  opacity: .85,
                  child: PieceStackView(
                      key: const ValueKey('carried-drag-ghost'),
                      pieces: carried
                          .map((stone) => StackMoveTray.visual(stone, styles))
                          .toList(),
                      expanded: true)))),
    ];
  }
}

class _CellClipper extends CustomClipper<Path> {
  const _CellClipper(this.layout, this.cell);
  final BoardLayout layout;
  final Cell cell;
  @override
  Path getClip(Size size) =>
      layout.polygon(cell).shift(-layout.bounds(cell).topLeft);
  @override
  bool shouldReclip(_CellClipper old) =>
      layout.size != old.layout.size ||
      layout.geometry.size != old.layout.geometry.size ||
      layout.geometry.runtimeType != old.layout.geometry.runtimeType ||
      cell != old.cell;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.layout, this.theme, this.selected, this.destinations,
      this.road, this.routeSource, this.routeDirection, this.drops);
  final BoardLayout layout;
  final BoardThemeData theme;
  final Cell? selected;
  final Set<Cell> destinations;
  final Set<Cell> road;
  final Cell? routeSource;
  final Step? routeDirection;
  final List<int> drops;
  static const pairColors = [
    Color(0xFFDED3BA),
    Color(0xFFB8C8BE),
    Color(0xFFC7BED5)
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (final cell in layout.geometry.cells) {
      final polygon = layout.polygon(cell);
      final bounds = layout.bounds(cell);
      canvas.save();
      canvas.clipPath(polygon);
      canvas.translate(bounds.left, bounds.top);
      getBoardTexturePainter(theme: theme, seed: cell.x * 7 + cell.y)
          .paint(canvas, bounds.size);
      canvas.restore();
      canvas.drawPath(
          polygon,
          Paint()
            ..color = theme.gridLine
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      for (var axis = 0; axis < layout.geometry.axisCount; axis++) {
        for (final positive in [false, true]) {
          if (!layout.geometry.boundary(cell, axis, positive)) continue;
          final center = layout.center(cell);
          final vector = layout.geometry is SquareGeometry
              ? axis == 0
                  ? Offset(positive ? 1 : -1, 0)
                  : Offset(0, positive ? 1 : -1)
              : switch (axis) {
                  0 => Offset(positive ? .866 : -.866, positive ? -.5 : .5),
                  1 => Offset(0, positive ? 1 : -1),
                  _ => Offset(positive ? -.866 : .866, positive ? -.5 : .5),
                };
          final anchor = center + vector * layout.unit * .82;
          final tangent = Offset(-vector.dy, vector.dx) * layout.unit * .26;
          canvas.drawLine(
              anchor - tangent,
              anchor + tangent,
              Paint()
                ..color = pairColors[axis]
                ..strokeWidth = math.max(2, layout.unit * .09));
        }
      }
      if (destinations.contains(cell)) {
        canvas.drawPath(polygon, Paint()..color = const Color(0x22275C51));
      }
      if (selected == cell ||
          destinations.contains(cell) ||
          road.contains(cell)) {
        canvas.drawPath(
            polygon,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = road.contains(cell)
                  ? Colors.yellowAccent
                  : selected == cell
                      ? const Color(0xFFB9632F)
                      : const Color(0xFF275C51));
      }
    }
    if (routeSource != null && routeDirection != null && drops.isNotEmpty) {
      var cell = routeSource!;
      final path = Path()
        ..moveTo(layout.center(cell).dx, layout.center(cell).dy);
      for (final _ in drops) {
        cell = cell.step(routeDirection!);
        path.lineTo(layout.center(cell).dx, layout.center(cell).dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = theme.gridLine.withValues(alpha: .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      layout.size != old.layout.size ||
      layout.geometry != old.layout.geometry ||
      theme != old.theme ||
      selected != old.selected ||
      routeSource != old.routeSource ||
      routeDirection != old.routeDirection ||
      !listEquals(drops, old.drops) ||
      !setEquals(destinations, old.destinations) ||
      !setEquals(road, old.road);
}
