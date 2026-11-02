import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/board_geometry.dart';
import 'package:stones/game/board_view.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/widgets/procedural_painters.dart';
import 'package:stones/widgets/theme_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('StonesSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
  });

  test('crafted frames stay inside existing Square and Hex board bounds',
      () async {
    for (final side in [240.0, 800.0]) {
      for (final shape in BoardShape.values) {
        final geometry =
            shape == BoardShape.square ? SquareGeometry(8) : HexGeometry(4);
        final size = Size.square(side);
        final layout = BoardLayout(size, geometry);
        for (final city in BoardTheme.values) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder)..translate(8, 8);
          paintCityBoardFrame(canvas, geometry.cells.map(layout.polygon),
              BoardThemeData.forTheme(city), layout.unit);
          final picture = recorder.endRecording();
          final image =
              await picture.toImage(side.toInt() + 16, side.toInt() + 16);
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          var visible = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final alpha = bytes[(y * image.width + x) * 4 + 3];
              if (x < 8 || y < 8 || x >= side + 8 || y >= side + 8) {
                expect(alpha, 0,
                    reason: '$city $shape at $side must fit existing bounds');
              } else if (alpha > 0) {
                visible++;
              }
            }
          }
          expect(visible, greaterThan(side * side * .25),
              reason: '$city $shape needs a visible material frame');
          image.dispose();
          picture.dispose();
        }
      }
    }
  });

  for (final shape in BoardShape.values) {
    test('capture all 36 mixed board/piece finishes on ${shape.name}',
        () async {
      const step = 210.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFF4EFE6), BlendMode.src);
      void label(String value, Offset point, {double width = 200}) {
        final text = TextPainter(
            text: TextSpan(
                text: value,
                style: const TextStyle(
                    fontFamily: 'StonesSans',
                    fontSize: 17,
                    color: Color(0xFF302B25))),
            textDirection: TextDirection.ltr)
          ..layout(maxWidth: width);
        text.paint(canvas, point);
      }

      label('Columns: pieces / Rows: boards', const Offset(112, 12),
          width: 600);
      for (final style in PieceStyle.values) {
        label(PieceStyleData.forStyle(style).name,
            Offset(120 + style.index * step, 46));
      }
      for (final city in BoardTheme.values) {
        label(BoardThemeData.forTheme(city).name,
            Offset(8, 170 + city.index * step),
            width: 100);
        for (final style in PieceStyle.values) {
          canvas.save();
          canvas.translate(112 + style.index * step, 76 + city.index * step);
          ThemeSamplePainter(city, style: style, shape: shape)
              .paint(canvas, const Size(200, 200));
          canvas.restore();
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(1380, 1344);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final file =
          File('build/qa/cities/craftsmanship/mixed-${shape.name}.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
  }
}
