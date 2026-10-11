import 'dart:math' as math;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart' hide Step;
import '../models/cosmetics.dart';
import '../widgets/board_cell_gestures.dart';
import '../widgets/piece_stack_view.dart';
import '../widgets/procedural_painters.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';
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

class BoardView extends StatelessWidget {
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
                          layout, material, selected, destinations, road))),
              for (final cell in game.geometry.cells)
                Positioned.fromRect(
                    rect: layout.bounds(cell),
                    child: ClipPath(
                      clipper: _CellClipper(layout, cell),
                      child: MergeSemantics(
                          child: Semantics(
                        key: ValueKey('cell-${cell.x}-${cell.y}'),
                        label:
                            'Cell ${cell.x}, ${cell.y}, ${game.topAt(cell) == null ? 'empty' : '${game.topAt(cell)!.seat.label} ${game.topAt(cell)!.type.name}, ${game.stackAt(cell).length} pieces'}',
                        button: true,
                        enabled: onCell != null,
                        selected: selected == cell,
                        child: StackInspection(
                          label: 'Stack ${cell.x}, ${cell.y}',
                          pieces: _visuals(cell),
                          inspectionPieces: original != null && selected == cell
                              ? _visuals(cell, before: true)
                              : null,
                          builder: (expanded) => Material(
                              type: MaterialType.transparency,
                              child: BoardCellGestures(
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
                                      if (game.topAt(cell) != null)
                                        Positioned(
                                            top: layout.unit * .11,
                                            right: layout.unit * .12,
                                            child: ExcludeSemantics(
                                                child: Text(
                                                    game
                                                        .topAt(cell)!
                                                        .seat
                                                        .symbol,
                                                    textScaler:
                                                        TextScaler.noScaling,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            (layout.unit * .28)
                                                                .clamp(8, 13),
                                                        color: Colors.black,
                                                        backgroundColor:
                                                            SeatAppearance
                                                                .marker(game
                                                                    .topAt(
                                                                        cell)!
                                                                    .seat))))),
                                    ])),
                              )),
                        ),
                      )),
                    )),
            ]));
      });
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
  _BoardPainter(
      this.layout, this.theme, this.selected, this.destinations, this.road);
  final BoardLayout layout;
  final BoardThemeData theme;
  final Cell? selected;
  final Set<Cell> destinations;
  final Set<Cell> road;
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
                  : Colors.cyanAccent);
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      layout.size != old.layout.size ||
      layout.geometry != old.layout.geometry ||
      theme != old.theme ||
      selected != old.selected ||
      !setEquals(destinations, old.destinations) ||
      !setEquals(road, old.road);
}
