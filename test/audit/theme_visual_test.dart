import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/cosmetics_provider.dart';
import 'package:stones/widgets/procedural_painters.dart';
import 'package:stones/widgets/theme_gallery.dart';

void main() {
  test('exactly five sets preserve legacy saved indices and paired selection',
      () async {
    expect(BoardTheme.values.length, 5);
    expect(PieceStyle.values.length, 5);
    for (var i = 0; i < 5; i++) {
      SharedPreferences.setMockInitialValues(
          {CosmeticsKeys.boardTheme: i, CosmeticsKeys.pieceStyle: i});
      final notifier = CosmeticsNotifier();
      await notifier.load();
      expect(notifier.state.selectedBoardTheme.index, i);
      expect(notifier.state.selectedPieceStyle.index, i);
      await notifier.setTheme(BoardTheme.values[(i + 1) % 5]);
      final loaded = CosmeticsNotifier();
      await loaded.load();
      expect(loaded.state.selectedBoardTheme.index, (i + 1) % 5);
      expect(loaded.state.selectedPieceStyle.index, (i + 1) % 5);
      notifier.dispose();
      loaded.dispose();
    }
  });
  test('all silhouettes paint inside their bounds even at small sizes',
      () async {
    for (final style in PieceStyle.values) {
      final colors = PieceStyleData.forStyle(style);
      for (final light in [true, false]) {
        for (final type in PieceType.values) {
          for (final size in [const Size(8, 5), const Size(70, 90)]) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder)..translate(5, 5);
            ThemedPiecePainter(
                    style: style,
                    colors: colors.colorsForPlayer(light),
                    type: type,
                    isLightPlayer: light)
                .paint(canvas, size);
            final picture = recorder.endRecording();
            final image = await picture.toImage(
                size.width.toInt() + 10, size.height.toInt() + 10);
            final rgba = (await image.toByteData())!.buffer.asUint8List();
            for (var y = 0; y < image.height; y++) {
              for (var x = 0; x < image.width; x++) {
                if (x < 5 ||
                    y < 5 ||
                    x >= size.width + 5 ||
                    y >= size.height + 5) {
                  expect(rgba[(y * image.width + x) * 4 + 3], 0,
                      reason: '$style $type at $size');
                }
              }
            }
            image.dispose();
            picture.dispose();
          }
        }
      }
    }
  });
  test('paint invalidation compares every visible piece property', () {
    final colors =
        PieceStyleData.forStyle(PieceStyle.standard).lightPlayerColors;
    final first = ThemedPiecePainter(
        style: PieceStyle.standard, colors: colors, type: PieceType.flat);
    expect(
        ThemedPiecePainter(
                style: PieceStyle.standard,
                colors: colors,
                type: PieceType.flat)
            .shouldRepaint(first),
        isFalse);
    expect(
        ThemedPiecePainter(
                style: PieceStyle.morocco, colors: colors, type: PieceType.flat)
            .shouldRepaint(first),
        isTrue);
    expect(
        ThemedPiecePainter(
                style: PieceStyle.standard,
                colors: colors,
                type: PieceType.capstone)
            .shouldRepaint(first),
        isTrue);
    expect(
        ThemedPiecePainter(
                style: PieceStyle.standard,
                colors: colors,
                type: PieceType.flat,
                isLightPlayer: false)
            .shouldRepaint(first),
        isTrue);
  });
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets(
        'five real samples and locked previews fit $size with enlarged text',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!),
              home: const Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: ThemeGallery()))))));
      expect(find.byType(ThemeSample), findsNWidgets(5));
      for (final sample in find.byType(ThemeSample).evaluate()) {
        expect(tester.getSize(find.byWidget(sample.widget)).width,
            greaterThan(100));
      }
      await tester.ensureVisible(find.text('Preview Morocco'));
      await tester.tap(find.text('Preview Morocco'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final previewPaint = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate((widget) =>
              widget is CustomPaint && widget.painter is ThemeSamplePainter));
      final previewSize = tester.getSize(previewPaint);
      expect(previewSize.width / previewSize.height, closeTo(1.5, 0.01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('render a contact sheet of all five live theme painters', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFF171B23), BlendMode.src);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(20 + i * 240.0, 65);
      ThemeSamplePainter(BoardTheme.values[i])
          .paint(canvas, const Size(220, 200));
      canvas.restore();
      final text = TextPainter(
          text: TextSpan(
              text: BoardThemeData.forTheme(BoardTheme.values[i]).name,
              style: const TextStyle(color: Colors.white, fontSize: 22)),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, Offset(20 + i * 240.0, 20));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1220, 285);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('build/theme-contact-sheet.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
