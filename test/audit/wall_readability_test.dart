import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/widgets/piece_stack_view.dart';
import 'package:stones/widgets/procedural_painters.dart';

StackVisualPiece visual(PieceStyle city, PieceIdentity owner, PieceType type) =>
    StackVisualPiece(
        type: type,
        style: city,
        colors: PieceStyleData.forStyle(city).colorsForIdentity(owner),
        owner: owner.name,
        identity: owner);

void paintStone(Canvas canvas, Size cell, StackVisualPiece piece) {
  final rect =
      StackLayerLayout(cell, [piece], expanded: false).layers.single.rect;
  canvas.save();
  canvas.translate(rect.left, rect.top);
  ThemedPiecePainter(
          style: piece.style,
          colors: piece.colors,
          type: piece.type,
          identity: piece.identity)
      .paint(canvas, rect.size);
  canvas.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('StonesSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
  });

  test('small walls read upright and flats read low without relying on color',
      () async {
    for (final city in PieceStyle.values) {
      for (final owner in PieceIdentity.values) {
        for (final side in [24, 40]) {
          for (final type in [PieceType.flat, PieceType.standing]) {
            final recorder = ui.PictureRecorder();
            paintStone(Canvas(recorder), Size.square(side.toDouble()),
                visual(city, owner, type));
            final picture = recorder.endRecording();
            final image = await picture.toImage(side, side);
            final bytes = (await image.toByteData())!.buffer.asUint8List();
            var left = side, right = -1, top = side, bottom = -1;
            for (var y = 0; y < side; y++) {
              for (var x = 0; x < side; x++) {
                // Ignore the soft contact shadow; measure the opaque silhouette.
                if (bytes[(y * side + x) * 4 + 3] < 180) continue;
                if (x < left) left = x;
                if (x > right) right = x;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
              }
            }
            expect(right, greaterThan(left));
            final ratio = (bottom - top + 1) / (right - left + 1);
            expect(ratio,
                type == PieceType.standing ? greaterThan(1.25) : lessThan(.75),
                reason: '$city $owner $type in a $side-pixel cell');
            image.dispose();
            picture.dispose();
          }
        }
      }
    }
  });

  test(
      'capture small flat, wall and capstone silhouettes for every city and owner',
      () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFF4EFE6), BlendMode.src);
    void label(String value, Offset point) {
      final text = TextPainter(
          text: TextSpan(
              text: value,
              style: const TextStyle(
                  fontFamily: 'StonesSans',
                  fontSize: 14,
                  color: Colors.black87)),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, point);
    }

    for (final city in PieceStyle.values) {
      final row = city.index * 140.0;
      label(PieceStyleData.forStyle(city).name, Offset(8, row + 8));
      for (final side in [24.0, 40.0]) {
        final y = row + (side == 24 ? 32 : 76);
        label('${side.toInt()}px cells', Offset(8, y + 8));
        for (final owner in PieceIdentity.values) {
          for (final type in PieceType.values) {
            canvas.save();
            canvas.translate(112 + owner.index * 144 + type.index * 44.0, y);
            paintStone(canvas, Size.square(side), visual(city, owner, type));
            canvas.restore();
          }
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(700, 840);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('build/qa/cities/final/small-pieces.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
