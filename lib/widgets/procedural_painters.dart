import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/cosmetics.dart';
import '../models/piece.dart';
import '../theme/game_colors.dart';

/// Scale-independent silhouettes shared by play, inspection and previews.
class ThemedPiecePainter extends CustomPainter {
  const ThemedPiecePainter(
      {required this.style,
      required this.colors,
      required this.type,
      this.identity = PieceIdentity.trapezoid});
  final PieceStyle style;
  final PieceColors colors;
  final PieceType type;
  final PieceIdentity identity;

  static Path identityPath(PieceIdentity identity) => switch (identity) {
        PieceIdentity.trapezoid => Path()
          ..moveTo(16, 8)
          ..lineTo(84, 8)
          ..lineTo(94, 82)
          ..lineTo(6, 82)
          ..close(),
        PieceIdentity.rounded => Path()
          ..moveTo(8, 82)
          ..lineTo(8, 45)
          ..cubicTo(8, -4, 92, -4, 92, 45)
          ..lineTo(92, 82)
          ..close(),
        PieceIdentity.diamond => Path()
          ..moveTo(50, 4)
          ..lineTo(96, 45)
          ..lineTo(50, 88)
          ..lineTo(4, 45)
          ..close(),
        PieceIdentity.hexagonal => Path()
          ..moveTo(26, 6)
          ..lineTo(74, 6)
          ..lineTo(96, 44)
          ..lineTo(74, 84)
          ..lineTo(26, 84)
          ..lineTo(4, 44)
          ..close(),
      };

  Path _cap() => switch (style) {
        PieceStyle.standard => Path()
          ..moveTo(19, 76)
          ..cubicTo(19, 30, 30, 10, 50, 8)
          ..cubicTo(70, 10, 81, 30, 81, 76)
          ..close(),
        PieceStyle.stone => Path()
          ..moveTo(20, 76)
          ..lineTo(26, 34)
          ..lineTo(37, 34)
          ..lineTo(37, 12)
          ..lineTo(63, 12)
          ..lineTo(63, 34)
          ..lineTo(74, 34)
          ..lineTo(80, 76)
          ..close(),
        PieceStyle.polishedMarble => Path()
          ..moveTo(18, 76)
          ..lineTo(24, 65)
          ..lineTo(33, 65)
          ..lineTo(33, 35)
          ..lineTo(22, 28)
          ..lineTo(18, 12)
          ..lineTo(82, 12)
          ..lineTo(78, 28)
          ..lineTo(67, 35)
          ..lineTo(67, 65)
          ..lineTo(76, 65)
          ..lineTo(82, 76)
          ..close(),
        PieceStyle.morocco => Path()
          ..moveTo(19, 76)
          ..lineTo(19, 49)
          ..cubicTo(19, 31, 40, 23, 50, 5)
          ..cubicTo(60, 23, 81, 31, 81, 49)
          ..lineTo(81, 76)
          ..close(),
        PieceStyle.kyoto => Path()
          ..moveTo(15, 76)
          ..lineTo(25, 58)
          ..lineTo(15, 58)
          ..lineTo(33, 37)
          ..lineTo(24, 37)
          ..lineTo(50, 8)
          ..lineTo(76, 37)
          ..lineTo(67, 37)
          ..lineTo(85, 58)
          ..lineTo(75, 58)
          ..lineTo(85, 76)
          ..close(),
        PieceStyle.celestial => Path()
          ..moveTo(15, 76)
          ..lineTo(15, 65)
          ..lineTo(27, 65)
          ..lineTo(27, 52)
          ..lineTo(39, 52)
          ..lineTo(39, 37)
          ..lineTo(45, 37)
          ..lineTo(45, 14)
          ..lineTo(50, 5)
          ..lineTo(55, 14)
          ..lineTo(55, 37)
          ..lineTo(61, 37)
          ..lineTo(61, 52)
          ..lineTo(73, 52)
          ..lineTo(73, 65)
          ..lineTo(85, 65)
          ..lineTo(85, 76)
          ..close(),
      };

  double get _sheen => switch (style) {
        PieceStyle.standard => .025,
        PieceStyle.stone => 0,
        PieceStyle.polishedMarble => .075,
        PieceStyle.morocco => .12,
        PieceStyle.kyoto => .085,
        PieceStyle.celestial => .055,
      };

  void _solid(Canvas canvas, Path path, {double depth = 5}) {
    const faceBounds = Rect.fromLTWH(0, 0, 100, 100);
    canvas.drawPath(
        path.shift(Offset(1, depth + 1.5)),
        Paint()
          ..color = Colors.black.withValues(alpha: .22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2));
    final side = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(colors.secondary, colors.border, .3)!,
          Color.lerp(colors.border, Colors.black, .12)!
        ],
      ).createShader(faceBounds);
    for (var d = depth; d > 0; d--) {
      canvas.drawPath(path.shift(Offset(d * .35, d)), side);
    }
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.primary, Colors.white, _sheen * .3)!,
              colors.primary,
              colors.secondary
            ],
            stops: const [0, .42, 1],
          ).createShader(faceBounds));
    canvas.save();
    canvas.clipPath(path);
    // A narrow light edge helps dark-on-dark combinations; a darker outline
    // below separates pale pieces from pale boards without changing palettes.
    final rim = colors.primary.computeLuminance() < .12
        ? .36
        : style == PieceStyle.stone
            ? .14
            : .20;
    canvas.drawPath(
        path.shift(const Offset(1.3, 1.7)),
        Paint()
          ..color = Colors.white.withValues(alpha: rim)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.7);
    canvas.drawPath(
        path.shift(const Offset(-1, -1.5)),
        Paint()
          ..color = colors.border.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);
    canvas.restore();
    canvas.drawPath(
        path,
        Paint()
          ..color = Color.lerp(colors.border, Colors.black, .12)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7);
  }

  void _materialFinish(Canvas canvas, Size size) {
    if (_sheen > 0 && size.shortestSide >= 18) {
      // One static, broad reflection. Lacquer is tighter; marble is diffuse.
      final spread = style == PieceStyle.kyoto ? .10 : .23;
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: _sheen),
                Colors.transparent
              ],
              stops: [.3 - spread, .3, .3 + spread],
            ).createShader(const Rect.fromLTWH(0, 0, 100, 100)));
    }
    if (style == PieceStyle.stone && size.shortestSide >= 38) {
      final chisel = Paint()
        ..color = colors.border.withValues(alpha: .22)
        ..strokeWidth = .7;
      for (final x in [20.0, 72.0]) {
        canvas.drawLine(Offset(x, 18), Offset(x + 5, 22), chisel);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 100, size.height / 100);
    // Upright pieces occupy their own silhouette, without a flat-shaped base.
    if (type != PieceType.flat) canvas.scale(1, 1.12);
    Path face;
    if (type == PieceType.flat) {
      face = identityPath(identity);
    } else {
      face = type == PieceType.capstone
          ? _cap()
          : (Path()
            // Parallel upright edges, a broad front and a thick top distinguish
            // a standing slab from the low, outward-tapering flat silhouette.
            ..moveTo(20, 12)
            ..lineTo(68, 4)
            ..lineTo(80, 14)
            ..lineTo(80, 74)
            ..lineTo(32, 82)
            ..lineTo(20, 72)
            ..close());
    }
    _solid(canvas, face, depth: type == PieceType.flat ? 7 : 4);
    canvas.save();
    canvas.clipPath(face);
    _materialFinish(canvas, size);
    final detail = Paint()
      ..color = colors.border.withValues(alpha: .24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    switch (style) {
      case PieceStyle.standard:
        for (var i = 0; i < 4; i++) {
          final y = 26.0 + i * 14;
          canvas.drawPath(
              Path()
                ..moveTo(0, y)
                ..cubicTo(24, y - 3, 58, y + 5, 100, y + 2),
              detail..strokeWidth = .8);
        }
      case PieceStyle.stone:
        for (var i = 0; i < 12; i++) {
          canvas.drawCircle(
              Offset(
                  10 + (i * 29 % 80).toDouble(), 12 + (i * 19 % 70).toDouble()),
              1,
              detail);
        }
      case PieceStyle.polishedMarble:
        final vein = Path()
          ..moveTo(0, 33)
          ..cubicTo(35, 12, 43, 82, 100, 48);
        canvas.drawPath(vein, detail);
        canvas.drawPath(
            vein.shift(const Offset(4, 11)), detail..strokeWidth = .7);
      case PieceStyle.morocco:
      case PieceStyle.kyoto:
      case PieceStyle.celestial:
        break;
    }
    // Tiny pieces keep material and silhouette; fine engraving is expendable.
    if (size.shortestSide >= 18) {
      _ornament(canvas, boardForPieces(style),
          type: type,
          engraving: Color.lerp(colors.border, const Color(0xFFC1A46C),
              colors.primary.computeLuminance() > .4 ? .15 : .8),
          detailOpacity: ((size.shortestSide - 12) / 48).clamp(.35, .68));
    }
    if (type == PieceType.standing) {
      final top = Path()
        ..moveTo(20, 12)
        ..lineTo(68, 4)
        ..lineTo(80, 14)
        ..lineTo(32, 22)
        ..close();
      final side = Path()
        ..moveTo(20, 12)
        ..lineTo(32, 22)
        ..lineTo(32, 82)
        ..lineTo(20, 72)
        ..close();
      canvas.drawPath(
          side, Paint()..color = colors.border.withValues(alpha: .38));
      canvas.drawPath(
          top, Paint()..color = Color.lerp(colors.primary, Colors.white, .3)!);
      canvas.drawLine(const Offset(32, 22), const Offset(32, 82),
          detail..strokeWidth = 1.7);
      canvas.drawLine(const Offset(32, 22), const Offset(80, 14), detail);
    }
    if (type == PieceType.capstone && style == PieceStyle.polishedMarble) {
      for (final x in [39.0, 50.0, 61.0]) {
        canvas.drawLine(Offset(x, 37), Offset(x, 64), detail);
      }
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThemedPiecePainter old) =>
      style != old.style ||
      type != old.type ||
      identity != old.identity ||
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
void _ornament(Canvas canvas, BoardTheme theme,
    {PieceType? type, Color? engraving, double detailOpacity = .68}) {
  final isBoard = type == null;
  final metal = switch (theme) {
    BoardTheme.morocco => const Color(0xFFB68B46),
    BoardTheme.kyoto => const Color(0xFFB89A62),
    BoardTheme.marble => const Color(0xFFAA9268),
    _ => const Color(0xFF9DBBC7),
  };
  final ink = Paint()
    ..color =
        (engraving ?? metal).withValues(alpha: isBoard ? .3 : detailOpacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = isBoard ? .8 : 1.15
    ..strokeJoin = StrokeJoin.round;
  final center = Offset(50, type == PieceType.capstone ? 53 : 46);
  final narrow = type == PieceType.standing;
  canvas.save();
  if (!isBoard) {
    // The wall's front face is narrower than the flat's engraved face.
    canvas.translate(narrow ? 56 : center.dx, center.dy);
    canvas.scale(narrow ? .48 : .82, .82);
    canvas.translate(-center.dx, -center.dy);
  }
  switch (theme) {
    case BoardTheme.celestial:
      canvas.drawCircle(center, 31, ink);
      canvas.drawOval(
          Rect.fromCenter(center: center, width: 76, height: 28), ink);
      _star(canvas, center, 15, ink);
      for (var i = 0; i < 9; i++) {
        final angle = i * 2.399;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * (20 + i * 2.2);
        canvas.drawCircle(
            point, i.isEven ? 1.5 : .9, ink..style = PaintingStyle.fill);
      }
      ink.style = PaintingStyle.stroke;
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
      // Florentine lily: three petals, curved outer leaves and a cross band.
      final lily = Path()
        ..moveTo(50, 71)
        ..lineTo(50, 27)
        ..cubicTo(32, 40, 35, 51, 50, 53)
        ..cubicTo(65, 51, 68, 40, 50, 27)
        ..moveTo(45, 59)
        ..cubicTo(18, 63, 22, 33, 38, 43)
        ..cubicTo(28, 47, 34, 58, 45, 59)
        ..moveTo(55, 59)
        ..cubicTo(82, 63, 78, 33, 62, 43)
        ..cubicTo(72, 47, 66, 58, 55, 59)
        ..moveTo(36, 63)
        ..lineTo(64, 63);
      canvas.drawPath(lily, ink..strokeWidth = 2);
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
      // A restrained compass and cooperage bands, cut into the wood.
      canvas.drawCircle(center, 13, ink);
      canvas.drawLine(
          center + const Offset(0, -19), center + const Offset(0, 19), ink);
      canvas.drawLine(
          center + const Offset(-19, 0), center + const Offset(19, 0), ink);
      for (final y in [18.0, 76.0]) {
        canvas.drawLine(Offset(0, y), Offset(100, y), ink);
      }
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
        PieceIdentity identity = PieceIdentity.trapezoid}) =>
    ThemedPiecePainter(
        style: style, colors: colors, type: PieceType.flat, identity: identity);
CustomPainter getWallPainter(
        {required PieceStyle style,
        required PieceColors colors,
        PieceIdentity identity = PieceIdentity.trapezoid}) =>
    ThemedPiecePainter(
        style: style,
        colors: colors,
        type: PieceType.standing,
        identity: identity);
CustomPainter getCapstonePainter(
        {required PieceStyle style,
        required PieceColors colors,
        PieceIdentity identity = PieceIdentity.trapezoid}) =>
    ThemedPiecePainter(
        style: style,
        colors: colors,
        type: PieceType.capstone,
        identity: identity);
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
      case BoardTheme.celestial:
        final glow = Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFF6861AA).withValues(alpha: .4),
            const Color(0x00101632)
          ]).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, glow);
        for (var i = 0; i < (size.shortestSide < 48 ? 3 : 8); i++) {
          final point = Offset(size.width * ((i * 37 + seed * 13) % 100) / 100,
              size.height * ((i * 61 + seed * 7) % 100) / 100);
          canvas.drawCircle(point, size.shortestSide / (i.isEven ? 100 : 170),
              Paint()..color = theme.woodGrainAccent.withValues(alpha: .6));
        }
      case BoardTheme.classicWood:
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
        _paintEdinburghStone(canvas, size, theme, seed);
      case BoardTheme.marble:
        _paintFlorentineMarble(canvas, size, theme, seed);
      case BoardTheme.kyoto:
        _paintKyotoWaves(canvas, size, theme);
      case BoardTheme.morocco:
        final center = Offset(size.width / 2, size.height / 2);
        _star(canvas, center, size.shortestSide * .36, detail);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardSurfacePainter old) =>
      theme != old.theme || seed != old.seed;
}

/// Coursed, hand-cut stone and an engraved interlace, rather than street cobbles.
void _paintEdinburghStone(
    Canvas canvas, Size size, BoardThemeData theme, int seed) {
  canvas.save();
  canvas.scale(size.width / 100, size.height / 100);
  final joint = Paint()
    ..color = theme.gridLine.withValues(alpha: .27)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;
  for (var row = -1; row < 4; row++) {
    final offset = row.isOdd ? 22.0 : -10.0;
    for (var col = -1; col < 3; col++) {
      final left = offset + col * 48;
      final top = 2 + row * 34.0;
      final cut = 1.5 + ((seed + row + col) % 3);
      final stone = Path()
        ..moveTo(left + cut, top)
        ..lineTo(left + 45, top + .6)
        ..lineTo(left + 47, top + 3)
        ..lineTo(left + 46, top + 30)
        ..lineTo(left + 43, top + 32)
        ..lineTo(left + 1, top + 31)
        ..lineTo(left, top + cut)
        ..close();
      canvas.drawPath(
          stone,
          Paint()
            ..color = (row + col).isEven
                ? const Color(0x10F4E9CD)
                : const Color(0x0D24363B));
      canvas.drawPath(stone, joint);
      canvas.drawLine(
          Offset(left + 4, top + 2),
          Offset(left + 43, top + 2.4),
          Paint()
            ..color = const Color(0x38F2EDDA)
            ..strokeWidth = .8);
    }
  }
  // Recessed diamond interlace, cut into each stone panel.
  final knot = Path()
    ..moveTo(50, 16)
    ..lineTo(78, 44)
    ..quadraticBezierTo(84, 50, 78, 56)
    ..lineTo(56, 78)
    ..quadraticBezierTo(50, 84, 44, 78)
    ..lineTo(22, 56)
    ..quadraticBezierTo(16, 50, 22, 44)
    ..lineTo(44, 22)
    ..quadraticBezierTo(50, 16, 56, 22)
    ..lineTo(72, 38)
    ..quadraticBezierTo(78, 44, 72, 50)
    ..lineTo(50, 72)
    ..lineTo(28, 50)
    ..lineTo(50, 28)
    ..lineTo(72, 50);
  canvas.drawPath(
      knot.shift(const Offset(.8, .9)),
      Paint()
        ..color = const Color(0x60E9E4D2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1);
  canvas.drawPath(
      knot,
      joint
        ..color = theme.gridLine.withValues(alpha: .36)
        ..strokeWidth = 1.7);
  canvas.restore();
}

/// Polychrome marble lozenges recall the Duomo's green-and-cream facade.
void _paintFlorentineMarble(
    Canvas canvas, Size size, BoardThemeData theme, int seed) {
  canvas.save();
  canvas.scale(size.width / 100, size.height / 100);
  const green = Color(0xFF386657);
  const rose = Color(0xFFB58378);
  for (var corner = 0; corner < 4; corner++) {
    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(corner * math.pi / 2);
    final inlay = Path()
      ..moveTo(-50, -50)
      ..lineTo(-20, -50)
      ..lineTo(-50, -20)
      ..close();
    canvas.drawPath(inlay,
        Paint()..color = (corner.isEven ? green : rose).withValues(alpha: .13));
    canvas.restore();
  }
  final inlay = Paint()
    ..color = green.withValues(alpha: .33)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.miter;
  for (final radius in [38.0, 32.0]) {
    final diamond = Path()
      ..moveTo(50, 50 - radius)
      ..lineTo(50 + radius, 50)
      ..lineTo(50, 50 + radius)
      ..lineTo(50 - radius, 50)
      ..close();
    canvas.drawPath(diamond, inlay..strokeWidth = radius == 38 ? 3.1 : 1.1);
  }
  final cameo = Path();
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4 + math.pi / 8;
    final point = Offset(50 + math.cos(angle) * 12, 50 + math.sin(angle) * 12);
    if (i == 0) {
      cameo.moveTo(point.dx, point.dy);
    } else {
      cameo.lineTo(point.dx, point.dy);
    }
  }
  canvas.drawPath(
      cameo..close(),
      inlay
        ..color = rose.withValues(alpha: .3)
        ..strokeWidth = 1.4);
  final vein = Paint()
    ..color = theme.woodGrainAccent.withValues(alpha: .24)
    ..style = PaintingStyle.stroke
    ..strokeWidth = .65;
  for (var i = 0; i < (size.shortestSide < 48 ? 1 : 3); i++) {
    final y = 16.0 + i * 32 + seed % 7;
    canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..cubicTo(28, y - 14, 62, y + 18, 100, y + 6),
        vein);
  }
  canvas.restore();
}

/// Indigo seigaiha fans on warm bamboo; broad waves survive small Hex cells.
void _paintKyotoWaves(Canvas canvas, Size size, BoardThemeData theme) {
  canvas.save();
  canvas.scale(size.width / 100, size.height / 100);
  final ink = Paint()
    ..color = const Color(0xFF264866).withValues(alpha: .23)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.25;
  final radii =
      size.shortestSide < 48 ? const [9.0, 15.0] : const [5.0, 10.0, 15.0];
  for (var row = 0; row < 5; row++) {
    for (var col = -1; col < 4; col++) {
      final center = Offset(col * 32.0 + (row.isOdd ? 16 : 0), 13 + row * 22.0);
      for (final radius in radii) {
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), math.pi,
            math.pi, false, ink);
      }
    }
  }
  // Bamboo fibers sit behind the indigo pattern, unlike Porto's wood seams.
  final fiber = Paint()
    ..color = theme.woodGrainAccent.withValues(alpha: .13)
    ..strokeWidth = .6;
  for (final x in [18.0, 48.0, 78.0]) {
    canvas.drawLine(Offset(x, 0), Offset(x + 2, 100), fiber);
  }
  canvas.restore();
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

/// Grid decoration follows the real cell boundary, including Hex polygons.
void paintCityGrid(
    Canvas canvas, Path polygon, BoardThemeData theme, double unit) {
  final bounds = polygon.getBounds();
  canvas.save();
  canvas.clipPath(polygon);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final width = math.max(.8, unit * .025);
  canvas.drawPath(
      polygon,
      stroke
        ..color = theme.gridLineShadow
        ..strokeWidth = width * 4);
  canvas.drawPath(
      polygon,
      stroke
        ..color = theme.gridLine
        ..strokeWidth = width * 2.5);
  if (theme.theme == BoardTheme.darkStone ||
      theme.theme == BoardTheme.marble ||
      theme.theme == BoardTheme.kyoto) {
    _paintArchitecturalBorder(canvas, polygon, theme, unit, width);
  }
  if (unit >= 12) {
    final center = bounds.center;
    final inset = polygon
        .shift(-center)
        .transform(Matrix4.diagonal3Values(.91, .91, 1).storage)
        .shift(center);
    canvas.drawPath(
        inset,
        stroke
          ..color = theme.gridLineHighlight.withValues(alpha: .65)
          ..strokeWidth = width * .6);
    if (unit >= 18) {
      final sides =
          polygon.contains(bounds.topLeft + const Offset(.1, .1)) ? 4 : 6;
      for (final metric in polygon.computeMetrics()) {
        for (var edge = 0; edge < sides; edge++) {
          final tangent =
              metric.getTangentForOffset(metric.length * (edge + .5) / sides)!;
          final point = Offset.lerp(tangent.position, center, .08)!;
          final inward = (center - point) / (center - point).distance;
          canvas.save();
          canvas.translate(point.dx, point.dy);
          canvas.rotate(math.atan2(tangent.vector.dy, tangent.vector.dx));
          final mark = Paint()
            ..color = theme.gridLineHighlight.withValues(alpha: .7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(.5, width * .6);
          final length = math.max(1.4, width * 2);
          switch (theme.theme) {
            case BoardTheme.classicWood:
              // Cooperage pins and a single incised seam.
              canvas.drawCircle(
                  Offset.zero, width * .65, mark..style = PaintingStyle.fill);
            case BoardTheme.darkStone:
              canvas.drawLine(Offset(0, -length), Offset(0, length), mark);
              canvas.drawLine(Offset(-length, 0), Offset(length, 0), mark);
            case BoardTheme.marble:
              final diamond = Path()
                ..moveTo(-length, 0)
                ..lineTo(0, -length * .6)
                ..lineTo(length, 0)
                ..lineTo(0, length * .6)
                ..close();
              canvas.drawPath(diamond, mark);
            case BoardTheme.morocco:
              _star(canvas, Offset.zero, length * 1.3, mark);
            case BoardTheme.kyoto:
              for (final x in [-length, length]) {
                canvas.drawLine(Offset(x, -length), Offset(x, length), mark);
              }
            case BoardTheme.celestial:
              canvas.drawCircle(Offset.zero, length, mark);
              canvas.drawLine(
                  Offset(-length * 1.5, 0), Offset(length * 1.5, 0), mark);
          }
          canvas.restore();
          if (theme.theme == BoardTheme.celestial) {
            canvas.drawCircle(point + inward * unit * .1, width * .5,
                Paint()..color = theme.gridLineHighlight);
          }
        }
      }
    }
  }
  canvas.restore();
}

void _paintArchitecturalBorder(Canvas canvas, Path polygon,
    BoardThemeData theme, double unit, double width) {
  final center = polygon.getBounds().center;
  Path inset(double scale) => polygon
      .shift(-center)
      .transform(Matrix4.diagonal3Values(scale, scale, 1).storage)
      .shift(center);
  final band = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  switch (theme.theme) {
    case BoardTheme.darkStone:
      canvas.drawPath(
          inset(.94),
          band
            ..color = theme.gridLineHighlight.withValues(alpha: .5)
            ..strokeWidth = width * 1.6);
    case BoardTheme.marble:
      canvas.drawPath(
          inset(.95),
          band
            ..color = const Color(0xFF386657).withValues(alpha: .8)
            ..strokeWidth = width * 2.1);
      canvas.drawPath(
          inset(.86),
          band
            ..color = const Color(0xFFB58378).withValues(alpha: .55)
            ..strokeWidth = width * .65);
    case BoardTheme.kyoto:
      canvas.drawPath(
          inset(.95),
          band
            ..color = const Color(0xFFC9A16A)
            ..strokeWidth = width * 2.6);
      canvas.drawPath(
          inset(.86),
          band
            ..color = const Color(0xFF294562).withValues(alpha: .65)
            ..strokeWidth = width * .7);
    default:
      return;
  }
  if (unit < 18) return;
  for (final metric in inset(.94).computeMetrics()) {
    final step = math.max(5.0, unit * .24);
    final stitches = Path();
    for (var distance = 0.0; distance <= metric.length; distance += step) {
      final tangent =
          metric.getTangentForOffset(math.min(distance, metric.length))!;
      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      final depth = theme.theme == BoardTheme.darkStone ? width * 1.35 : width;
      final point = tangent.position +
          normal * ((distance / step).round().isEven ? depth : -depth);
      if (distance == 0) {
        stitches.moveTo(point.dx, point.dy);
      } else {
        stitches.lineTo(point.dx, point.dy);
      }
      if (theme.theme == BoardTheme.kyoto &&
          (distance / step).round() % 3 == 0) {
        canvas.drawLine(
            tangent.position - normal * width * 1.7,
            tangent.position + normal * width * 1.7,
            band
              ..color = const Color(0xFF775A38).withValues(alpha: .75)
              ..strokeWidth = width * .8);
      }
    }
    if (theme.theme == BoardTheme.darkStone) {
      canvas.drawPath(
          stitches,
          band
            ..color = theme.gridLine.withValues(alpha: .8)
            ..strokeWidth = width * .8);
    }
  }
}

/// Compatibility square cells share the same city edge treatment.
class CitySquareGridPainter extends CustomPainter {
  const CitySquareGridPainter(this.theme);
  final BoardThemeData theme;
  @override
  void paint(Canvas canvas, Size size) => paintCityGrid(canvas,
      Path()..addRect(Offset.zero & size), theme, size.shortestSide / 2);
  @override
  bool shouldRepaint(covariant CitySquareGridPainter old) => theme != old.theme;
}

/// Continuous, low-profile material rim. It stays within the existing board
/// padding, so cell geometry, hit targets and viewport dimensions do not change.
void paintCityBoardFrame(
    Canvas canvas, Iterable<Path> cells, BoardThemeData theme, double unit) {
  final points = <Offset>[];
  final cellsOutline = Path();
  for (final cell in cells) {
    cellsOutline.addPath(cell, Offset.zero);
    final bounds = cell.getBounds();
    final sides = cell.contains(bounds.topLeft + const Offset(.1, .1)) ? 4 : 6;
    for (final metric in cell.computeMetrics()) {
      for (var i = 0; i < sides; i++) {
        final tangent = metric.getTangentForOffset(metric.length * i / sides);
        if (tangent != null) points.add(tangent.position);
      }
    }
  }
  final vertices = _frameHull(points);
  if (vertices.length < 3) return;
  final frame = Path()..addPolygon(vertices, true);
  final rim = (unit * .14).clamp(2.0, 4.5);
  final accent = theme.theme == BoardTheme.celestial
      ? theme.gridLineHighlight
      : theme.frameInner;
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  canvas.save();
  canvas.drawPath(
      frame.shift(const Offset(0, .8)),
      Paint()
        ..color = Colors.black.withValues(alpha: .12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .8));
  canvas.drawPath(frame, Paint()..color = theme.frameOuter);
  canvas.drawPath(
      frame,
      edge
        ..color = theme.frameOuter
        ..strokeWidth = rim * 2);
  canvas.drawPath(
      frame,
      edge
        ..color = Color.lerp(theme.frameOuter, accent, .52)!
        ..strokeWidth = rim * 1.25);
  canvas.drawPath(
      frame,
      edge
        ..color = Color.lerp(accent, Colors.white, .12)!.withValues(alpha: .5)
        ..strokeWidth = .7);
  // Retain the existing cell grout independently of the outer frame.
  canvas.drawPath(
      cellsOutline,
      Paint()
        ..color = theme.frameOuter
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(2, unit * .16));
  if (unit >= 18) {
    final center = frame.getBounds().center;
    final stride = vertices.length > 6 ? 2 : 1;
    for (var i = 0; i < vertices.length; i += stride) {
      final outward = vertices[i] - center;
      if (outward.distance == 0) continue;
      final direction = outward / outward.distance;
      final point = vertices[i] + direction * rim * .48;
      final join = Paint()
        ..color = accent.withValues(alpha: .65)
        ..strokeWidth = .7;
      if (theme.theme == BoardTheme.morocco ||
          theme.theme == BoardTheme.celestial) {
        canvas.drawCircle(point, math.min(.8, rim * .2), join);
      } else {
        canvas.drawLine(
            point - direction * rim * .38, point + direction * rim * .38, join);
      }
    }
  }
  canvas.restore();
}

/// Convex material outline around the playing cells, including chamfered Hex outlines.
List<Offset> _frameHull(List<Offset> points) {
  if (points.length < 3) return points;
  points.sort(
      (a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx));
  double turn(Offset a, Offset b, Offset c) =>
      (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  final lower = <Offset>[];
  final upper = <Offset>[];
  for (final point in points) {
    while (lower.length >= 2 &&
        turn(lower[lower.length - 2], lower.last, point) <= .001) {
      lower.removeLast();
    }
    lower.add(point);
  }
  for (final point in points.reversed) {
    while (upper.length >= 2 &&
        turn(upper[upper.length - 2], upper.last, point) <= .001) {
      upper.removeLast();
    }
    upper.add(point);
  }
  return [...lower.take(lower.length - 1), ...upper.take(upper.length - 1)];
}
