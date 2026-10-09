import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/piece.dart';
import '../models/cosmetics.dart';
import '../theme/game_colors.dart';
import '../providers/cosmetics_provider.dart';
import '../widgets/procedural_painters.dart';
import 'hex_game.dart';

const hexSeatColors = [Color(0xFFFFE3A0), Color(0xFF607D8B), Color(0xFFE68B54)];
const hexSeatSymbols = ['I', 'Ch', 'Cu'];

/// Pointy-top axial geometry, shared by painting and hit-testing. Hex-shaped
/// hit areas avoid selecting a neighboring cell through a bounding-box corner.
class HexBoardGeometry {
  HexBoardGeometry(this.size, this.radius)
      : unit = math.min(size.width / (math.sqrt(3) * (2 * radius + 1) + 1),
            size.height / (3 * radius + 3));
  final Size size;
  final int radius;
  final double unit;
  Offset center(HexCell cell) => Offset(
      size.width / 2 + unit * math.sqrt(3) * (cell.q + cell.r / 2),
      size.height / 2 + unit * 1.5 * cell.r);
  Path polygon(HexCell cell) {
    final origin = center(cell);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * math.pi / 180;
      final point =
          origin + Offset(math.cos(angle), math.sin(angle)) * (unit * 0.94);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  HexCell? hit(Offset point, Iterable<HexCell> cells) {
    for (final cell in cells) {
      if (polygon(cell).contains(point)) return cell;
    }
    return null;
  }
}

class HexBoard extends ConsumerWidget {
  const HexBoard(
      {super.key,
      required this.game,
      this.turnSeat,
      this.preview = false,
      this.pieceStyles,
      this.boardTheme,
      this.selected,
      this.destinations = const {},
      this.road = const {},
      this.onCell});
  final HexGame game;
  final List<PieceStyle>? pieceStyles;
  final BoardTheme? boardTheme;
  final HexSeat? turnSeat;
  final bool preview;
  final HexCell? selected;
  final Set<HexCell> destinations;
  final Set<HexCell> road;
  final ValueChanged<HexCell>? onCell;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = HexBoardGeometry(size, game.radius);
        return Semantics(
          label:
              'Hex board${preview ? ' preview' : ''}, ${game.cells.length} cells. ${game.finished ? 'Finished.' : '${(turnSeat ?? game.current).label} to play.'}',
          child: Stack(children: [
            RepaintBoundary(
                child: CustomPaint(
                    size: size,
                    painter: _HexPainter(
                        game,
                        geometry,
                        selected,
                        destinations,
                        road,
                        boardTheme == null
                            ? ref.watch(currentBoardThemeProvider)
                            : BoardThemeData.forTheme(boardTheme!),
                        ref.watch(currentPieceStyleProvider),
                        pieceStyles))),
            for (final cell in game.cells)
              Positioned(
                left: geometry.center(cell).dx - geometry.unit,
                top: geometry.center(cell).dy - geometry.unit,
                width: geometry.unit * 2,
                height: geometry.unit * 2,
                child: ClipPath(
                  clipper: _CellClipper(geometry, cell),
                  child: Semantics(
                    label:
                        'Cell ${cell.q}, ${cell.r}, ${game.stackAt(cell).isEmpty ? 'empty' : '${game.stackAt(cell).last.seat.label} ${game.stackAt(cell).last.type.name}, ${game.stackAt(cell).length} pieces'}',
                    button: true,
                    enabled: onCell != null,
                    selected: selected == cell,
                    child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                            onTap: onCell == null ? null : () => onCell!(cell),
                            child: const SizedBox.expand())),
                  ),
                ),
              ),
          ]),
        );
      });
}

class _CellClipper extends CustomClipper<Path> {
  const _CellClipper(this.geometry, this.cell);
  final HexBoardGeometry geometry;
  final HexCell cell;
  @override
  Path getClip(Size size) => geometry
      .polygon(cell)
      .shift(-geometry.center(cell) + Offset(geometry.unit, geometry.unit));
  @override
  bool shouldReclip(_CellClipper oldClipper) =>
      oldClipper.geometry.size != geometry.size ||
      oldClipper.geometry.radius != geometry.radius ||
      oldClipper.cell != cell;
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.game, this.geometry, this.selected, this.destinations,
      this.road, this.theme, this.pieces, this.pieceStyles);
  final BoardThemeData theme;
  final PieceStyleData pieces;
  final List<PieceStyle>? pieceStyles;
  final HexGame game;
  final HexBoardGeometry geometry;
  final HexCell? selected;
  final Set<HexCell> destinations;
  final Set<HexCell> road;
  void _text(
      Canvas canvas, String value, Offset position, double size, Color color) {
    final text = TextPainter(
        text: TextSpan(
            text: value,
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.bold, color: color)),
        textDirection: TextDirection.ltr)
      ..layout();
    text.paint(canvas, position - Offset(text.width / 2, text.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = geometry.unit;
    for (final cell in game.cells) {
      final center = geometry.center(cell);
      final polygon = geometry.polygon(cell);
      canvas.save();
      canvas.clipPath(polygon);
      canvas.translate(center.dx - unit, center.dy - unit);
      getBoardTexturePainter(theme: theme, seed: cell.q * 7 + cell.r)
          .paint(canvas, Size(unit * 2, unit * 2));
      canvas.restore();
      canvas.drawPath(
          polygon,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = theme.gridLine);
      for (final direction in HexDirection.values) {
        final neighbor = cell.step(direction);
        if (neighbor.inside(game.radius)) continue;
        final sides = HexSeat.values
            .where((seat) => seat.axis(neighbor).abs() > game.radius)
            .toList();
        final angle = -direction.index * math.pi / 3;
        final a = center +
            Offset(math.cos(angle - math.pi / 6),
                    math.sin(angle - math.pi / 6)) *
                (unit * 0.94);
        final b = center +
            Offset(math.cos(angle + math.pi / 6),
                    math.sin(angle + math.pi / 6)) *
                (unit * 0.94);
        for (var i = 0; i < sides.length; i++) {
          canvas.drawLine(
              Offset.lerp(a, b, i / sides.length)!,
              Offset.lerp(a, b, (i + 1) / sides.length)!,
              Paint()
                ..strokeWidth = math.max(3, unit * 0.12)
                ..color = hexSeatColors[sides[i].index]);
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
      final stack = game.stackAt(cell);
      if (stack.isNotEmpty) {
        final top = stack.last;
        final style = pieceStyles == null
            ? pieces
            : PieceStyleData.forStyle(pieceStyles![top.seat.index]);
        final colors = top.seat == HexSeat.copper
            ? const PieceColors(
                primary: Color(0xFFE8A568),
                secondary: Color(0xFFB76832),
                border: Color(0xFF593418))
            : style.colorsForPlayer(top.seat == HexSeat.ivory);
        final width = unit * (top.type == PieceType.standing ? .48 : 1.05);
        final height = unit * (top.type == PieceType.flat ? .65 : 1.2);
        canvas.save();
        canvas.translate(center.dx - width / 2, center.dy - height / 2);
        ThemedPiecePainter(
                style: style.style,
                colors: colors,
                type: top.type,
                isLightPlayer: top.seat != HexSeat.charcoal)
            .paint(canvas, Size(width, height));
        canvas.restore();
        _text(
            canvas,
            hexSeatSymbols[top.seat.index],
            center + Offset(unit * .48, -unit * .53),
            unit * .28,
            top.seat == HexSeat.charcoal ? Colors.white : Colors.black);
        if (stack.length > 1) {
          _text(canvas, '${stack.length}', center + Offset(0, unit * 0.62),
              unit * 0.25, Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) =>
      game != old.game ||
      geometry.size != old.geometry.size ||
      selected != old.selected ||
      !setEquals(destinations, old.destinations) ||
      !setEquals(road, old.road) ||
      theme != old.theme ||
      pieces != old.pieces ||
      !listEquals(pieceStyles, old.pieceStyles);
}
