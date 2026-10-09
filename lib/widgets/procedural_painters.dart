import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import '../models/piece.dart';
import '../theme/game_colors.dart';

/// Scale-independent silhouettes, shared by gameplay, inspection and previews.
/// All painting stays inside the supplied bounds, including shadows and strokes.
class ThemedPiecePainter extends CustomPainter {
  const ThemedPiecePainter(
      {required this.style,
      required this.colors,
      required this.type,
      this.isLightPlayer = true});
  final PieceStyle style;
  final PieceColors colors;
  final PieceType type;
  final bool isLightPlayer;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 100, size.height / 100);
    final path = Path();
    if (type == PieceType.flat) {
      if (isLightPlayer) {
        path.moveTo(16, 9);
        path.lineTo(84, 9);
        path.lineTo(94, 84);
        path.lineTo(6, 84);
        path.close();
      } else {
        path.moveTo(8, 84);
        path.lineTo(8, 48);
        path.cubicTo(8, -4, 92, -4, 92, 48);
        path.lineTo(92, 84);
        path.close();
      }
    } else if (type == PieceType.standing) {
      path.moveTo(22, 7);
      path.lineTo(71, 7);
      path.lineTo(84, 20);
      path.lineTo(84, 87);
      path.lineTo(22, 87);
      path.close();
    } else {
      switch (style) {
        case PieceStyle.standard:
        case PieceStyle.polishedMarble:
          path.moveTo(12, 85);
          path.cubicTo(12, 36, 27, 10, 50, 8);
          path.cubicTo(73, 10, 88, 36, 88, 85);
          path.close();
        case PieceStyle.stone:
          path.moveTo(12, 86);
          path.lineTo(21, 36);
          path.lineTo(50, 7);
          path.lineTo(79, 36);
          path.lineTo(88, 86);
          path.close();
        case PieceStyle.morocco:
          path.moveTo(14, 85);
          path.lineTo(14, 54);
          path.cubicTo(14, 34, 40, 23, 50, 6);
          path.cubicTo(60, 23, 86, 34, 86, 54);
          path.lineTo(86, 85);
          path.close();
        case PieceStyle.kyoto:
          path.moveTo(11, 85);
          path.lineTo(19, 61);
          path.lineTo(12, 61);
          path.lineTo(29, 39);
          path.lineTo(23, 39);
          path.lineTo(50, 9);
          path.lineTo(77, 39);
          path.lineTo(71, 39);
          path.lineTo(88, 61);
          path.lineTo(81, 61);
          path.lineTo(89, 85);
          path.close();
      }
    }
    canvas.drawPath(path.shift(const Offset(2, 5)),
        Paint()..color = Colors.black.withValues(alpha: .25));
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.primary, colors.secondary])
              .createShader(const Rect.fromLTWH(0, 0, 100, 100)));
    canvas.save();
    canvas.clipPath(path);
    final detail = Paint()
      ..color = colors.border.withValues(alpha: .32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    switch (style) {
      case PieceStyle.standard:
        for (var i = 0; i < 4; i++) {
          final y = 28.0 + i * 14;
          canvas.drawLine(Offset(0, y), Offset(100, y + 3), detail);
        }
      case PieceStyle.stone:
        for (var i = 0; i < 14; i++) {
          canvas.drawCircle(
              Offset(
                  10 + (i * 29 % 80).toDouble(), 12 + (i * 19 % 70).toDouble()),
              1.2,
              detail);
        }
        canvas.drawLine(const Offset(28, 8), const Offset(18, 84), detail);
        _ornament(canvas, BoardTheme.darkStone, type: type);
      case PieceStyle.polishedMarble:
        final vein = Path()
          ..moveTo(0, 33)
          ..cubicTo(35, 12, 43, 82, 100, 48);
        canvas.drawPath(vein, detail);
        canvas.drawPath(
            vein.shift(const Offset(4, 11)), detail..strokeWidth = .7);
        _ornament(canvas, BoardTheme.marble, type: type);
      case PieceStyle.morocco:
        _ornament(canvas, BoardTheme.morocco, type: type);
      case PieceStyle.kyoto:
        _ornament(canvas, BoardTheme.kyoto, type: type);
    }
    canvas.restore();
    canvas.drawPath(
        path,
        Paint()
          ..color = colors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawLine(
        const Offset(25, 17),
        const Offset(68, 17),
        Paint()
          ..color = Colors.white.withValues(alpha: .4)
          ..strokeWidth = 2);
    if (type == PieceType.standing) {
      canvas.drawLine(
          const Offset(71, 8),
          const Offset(71, 84),
          Paint()
            ..color = colors.border.withValues(alpha: .6)
            ..strokeWidth = 2);
    }
    canvas.restore();
    if (type == PieceType.capstone) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(10, 81, 80, 12), const Radius.circular(4)),
          Paint()..color = colors.secondary);
      canvas.drawLine(
          const Offset(12, 82),
          const Offset(88, 82),
          Paint()
            ..color = colors.border
            ..strokeWidth = 2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThemedPiecePainter old) =>
      style != old.style ||
      type != old.type ||
      isLightPlayer != old.isLightPlayer ||
      colors.primary != old.colors.primary ||
      colors.secondary != old.colors.secondary ||
      colors.border != old.colors.border;
}

void _star(Canvas canvas, Offset center, double radius, Paint paint) {
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final angle = i * math.pi / 8 - math.pi / 2;
    final r = radius * (i.isEven ? 1 : .48);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  canvas.drawPath(path..close(), paint);
}

/// Handcrafted inlays use normalized geometry and inherit the caller's clip.
/// Large motifs read at play size; fine engraving rewards closer inspection.
void _ornament(Canvas canvas, BoardTheme theme, {PieceType? type}) {
  final isBoard = type == null;
  final metal = switch (theme) {
    BoardTheme.morocco => const Color(0xFFB68B46),
    BoardTheme.kyoto => const Color(0xFFB89A62),
    BoardTheme.marble => const Color(0xFFAA9268),
    _ => const Color(0xFF9DBBC7),
  };
  final ink = Paint()
    ..color = metal.withValues(alpha: isBoard ? .55 : .85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = isBoard ? .8 : 1.15
    ..strokeJoin = StrokeJoin.round;
  final center = Offset(50, type == PieceType.capstone ? 53 : 46);
  final narrow = type == PieceType.standing;
  canvas.save();
  if (!isBoard) {
    // The wall's front face is narrower than the flat's engraved face.
    canvas.translate(center.dx, center.dy);
    canvas.scale(narrow ? .55 : .82, .82);
    canvas.translate(-center.dx, -center.dy);
  }
  switch (theme) {
    case BoardTheme.morocco:
      // Interlaced square geometry, a central eight-point rosette and petals.
      for (final radius in [isBoard ? 38.0 : 28.0, isBoard ? 32.0 : 23.0]) {
        for (final angle in [0.0, math.pi / 4]) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(angle);
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: radius * 1.42,
                  height: radius * 1.42),
              ink);
          canvas.restore();
        }
      }
      _star(canvas, center, isBoard ? 22 : 18, ink);
      _rosette(canvas, center, isBoard ? 15 : 12, 8, ink);
      canvas.drawCircle(center, 3, ink);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final p =
            center + Offset(math.cos(a), math.sin(a)) * (isBoard ? 40 : 31);
        canvas.drawCircle(p, 1.3, ink..style = PaintingStyle.fill);
      }
      ink.style = PaintingStyle.stroke;
    case BoardTheme.kyoto:
      // Seigaiha wave engraving beneath a five-petal blossom medallion.
      for (var row = 0; row < (isBoard ? 4 : 2); row++) {
        for (var col = -1; col < 5; col++) {
          final x = col * 24.0 + (row.isOdd ? 12 : 0);
          final y = (isBoard ? 24.0 : 65.0) + row * 14;
          for (final radius in [5.0, 8.0, 11.0]) {
            canvas.drawArc(
                Rect.fromCircle(center: Offset(x, y), radius: radius),
                math.pi,
                math.pi,
                false,
                Paint()
                  ..color = metal.withValues(alpha: .35)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = .65);
          }
        }
      }
      canvas.drawCircle(center, isBoard ? 19 : 18, ink);
      canvas.drawCircle(center, isBoard ? 22 : 21, ink);
      _rosette(canvas, center, 13, 5, ink);
      canvas.drawCircle(center, 2.3, ink);
      if (!isBoard && type == PieceType.capstone) {
        for (final y in [34.0, 60.0, 77.0]) {
          canvas.drawLine(Offset(18, y), Offset(82, y), ink);
        }
      }
    case BoardTheme.marble:
      // Classical oval cameo, laurel leaves and a turned pedestal.
      canvas.drawOval(
          Rect.fromCenter(center: center, width: 33, height: 42), ink);
      canvas.drawOval(
          Rect.fromCenter(center: center, width: 39, height: 48), ink);
      _rosette(canvas, center, 12, 6, ink);
      for (final side in [-1.0, 1.0]) {
        final stem = Path()
          ..moveTo(50 + side * 10, 76)
          ..quadraticBezierTo(50 + side * 41, 57, 50 + side * 25, 24);
        canvas.drawPath(stem, ink);
        for (var i = 0; i < 5; i++) {
          final y = 32.0 + i * 8;
          final x = 50 + side * (27 + math.sin(i * .6) * 4);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(side * .7);
          canvas.drawOval(const Rect.fromLTWH(-2, -5, 4, 10), ink);
          canvas.restore();
        }
      }
    case BoardTheme.darkStone:
      // Chiseled diamond medallion and angular, interwoven stone bands.
      for (final radius in [isBoard ? 32.0 : 25.0, isBoard ? 26.0 : 20.0]) {
        final diamond = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy)
          ..close();
        canvas.drawPath(diamond, ink);
      }
      final knot = Path()
        ..moveTo(38, 34)
        ..lineTo(62, 58)
        ..lineTo(62, 34)
        ..lineTo(38, 58)
        ..close();
      canvas.drawPath(knot, ink..strokeWidth = 2);
      for (final y in [isBoard ? 8.0 : 16.0, isBoard ? 92.0 : 76.0]) {
        final band = Path()..moveTo(0, y);
        for (var x = 0; x <= 100; x += 10) {
          band.lineTo(x.toDouble(), y + (x % 20 == 0 ? -3 : 3));
        }
        canvas.drawPath(band, ink..strokeWidth = 1);
      }
    case BoardTheme.classicWood:
      break;
  }
  if (isBoard && theme != BoardTheme.classicWood) {
    for (final inset in [4.0, 7.0]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(inset, inset, 100 - inset, 100 - inset),
              const Radius.circular(2)),
          ink..strokeWidth = .65);
    }
  }
  canvas.restore();
}

void _rosette(
    Canvas canvas, Offset center, double radius, int petals, Paint ink) {
  for (var i = 0; i < petals; i++) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(i * math.pi * 2 / petals);
    final petal = Path()
      ..moveTo(0, 0)
      ..cubicTo(-radius * .5, -radius * .4, -radius * .35, -radius, 0, -radius)
      ..cubicTo(radius * .35, -radius, radius * .5, -radius * .4, 0, 0);
    canvas.drawPath(petal, ink);
    canvas.restore();
  }
}

CustomPainter getFlatPainter(
        {required PieceStyle style,
        required PieceColors colors,
        required bool isLightPlayer}) =>
    ThemedPiecePainter(
        style: style,
        colors: colors,
        type: PieceType.flat,
        isLightPlayer: isLightPlayer);
CustomPainter getWallPainter(
        {required PieceStyle style, required PieceColors colors}) =>
    ThemedPiecePainter(style: style, colors: colors, type: PieceType.standing);
CustomPainter getCapstonePainter(
        {required PieceStyle style, required PieceColors colors}) =>
    ThemedPiecePainter(style: style, colors: colors, type: PieceType.capstone);
CustomPainter getBoardTexturePainter(
        {required BoardThemeData theme, int seed = 42}) =>
    BoardSurfacePainter(theme: theme, seed: seed);

class BoardSurfacePainter extends CustomPainter {
  const BoardSurfacePainter({required this.theme, this.seed = 42});
  final BoardThemeData theme;
  final int seed;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = theme.cellBackground);
    final detail = Paint()
      ..color = theme.woodGrainAccent.withValues(alpha: .3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.5, size.width / 180);
    switch (theme.theme) {
      case BoardTheme.classicWood:
      case BoardTheme.kyoto:
        for (var i = 0; i < 9; i++) {
          final y = size.height * (i + .5) / 9;
          final bend = size.height * (.012 + (seed % 5) * .004);
          final line = Path()
            ..moveTo(0, y)
            ..cubicTo(size.width * .25, y + bend, size.width * .7, y - bend,
                size.width, y);
          canvas.drawPath(line, detail);
        }
      case BoardTheme.darkStone:
        for (var i = 0; i < 28; i++) {
          canvas.drawCircle(
              Offset(size.width * ((i * 37 + seed) % 100) / 100,
                  size.height * ((i * 23 + seed) % 100) / 100),
              size.shortestSide / 140,
              detail);
        }
      case BoardTheme.marble:
        for (var i = 0; i < 3; i++) {
          final y = size.height * (i + .2) / 3;
          final vein = Path()
            ..moveTo(0, y)
            ..cubicTo(size.width * .3, y - size.height * .2, size.width * .65,
                y + size.height * .3, size.width, y + size.height * .12);
          canvas.drawPath(vein, detail);
        }
      case BoardTheme.morocco:
        final center = Offset(size.width / 2, size.height / 2);
        _star(canvas, center, size.shortestSide * .36, detail);
        canvas.drawRect(
            Rect.fromCenter(
                center: center,
                width: size.width * .75,
                height: size.height * .75),
            detail);
    }
    if (theme.theme != BoardTheme.classicWood) {
      canvas.save();
      canvas.scale(size.width / 100, size.height / 100);
      _ornament(canvas, theme.theme);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardSurfacePainter old) =>
      theme != old.theme || seed != old.seed;
}

class BoardDecorationPainter extends CustomPainter {
  const BoardDecorationPainter(
      {required this.boardSize,
      required this.spacing,
      required this.padding,
      required this.cellSize,
      required this.theme,
      required this.decorColor});
  final int boardSize;
  final double spacing;
  final double padding;
  final double cellSize;
  final BoardTheme theme;
  final Color decorColor;
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || cellSize <= 0) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = decorColor.withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.7, spacing / 4);
    final end = padding + boardSize * cellSize + (boardSize - 1) * spacing;
    for (final point in [
      Offset(padding, padding),
      Offset(end, padding),
      Offset(padding, end),
      Offset(end, end)
    ]) {
      if (theme == BoardTheme.morocco) {
        _star(canvas, point, math.min(padding, 7), paint);
      } else {
        canvas.drawCircle(point, math.min(padding * .5, 4), paint);
      }
    }
    // Ornament stays in the grout, never across a playing square.
    for (var row = 1; row < boardSize; row++) {
      for (var col = 1; col < boardSize; col++) {
        final point = Offset(padding + col * (cellSize + spacing) - spacing / 2,
            padding + row * (cellSize + spacing) - spacing / 2);
        canvas.drawCircle(point, math.max(.5, spacing * .18), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardDecorationPainter old) =>
      boardSize != old.boardSize ||
      spacing != old.spacing ||
      padding != old.padding ||
      cellSize != old.cellSize ||
      theme != old.theme ||
      decorColor != old.decorColor;
}
