import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/models/piece.dart';
import 'package:stones/providers/cosmetics_provider.dart';
import 'package:stones/widgets/procedural_painters.dart';
import 'package:stones/widgets/theme_gallery.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('StonesSans')
          ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf')))
        .load();
  });
  test('six city sets preserve legacy saved indices', () async {
    expect(BoardTheme.values.length, 6);
    expect(PieceStyle.values.length, 6);
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
      for (final identity in PieceIdentity.values) {
        for (final type in PieceType.values) {
          for (final size in [const Size(8, 5), const Size(70, 90)]) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder)..translate(5, 5);
            ThemedPiecePainter(
                    style: style,
                    colors: colors.colorsForIdentity(identity),
                    type: type,
                    identity: identity)
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
                identity: PieceIdentity.rounded)
            .shouldRepaint(first),
        isTrue);
  });
  for (final size in [const Size(320, 568), const Size(1366, 768)]) {
    testWidgets(
        'six real board samples and locked previews fit $size with enlarged text',
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
      expect(find.byType(ThemeSample), findsNWidgets(6));
      for (final sample in find.byType(ThemeSample).evaluate()) {
        expect(tester.getSize(find.byWidget(sample.widget)).width,
            greaterThan(100));
      }
      await tester.ensureVisible(find.text('Preview Marrakesh'));
      await tester.tap(find.text('Preview Marrakesh'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final previewPaint = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate((widget) =>
              widget is CustomPaint && widget.painter is ThemeSamplePainter));
      final previewSize = tester.getSize(previewPaint.first);
      expect(previewSize.width / previewSize.height, closeTo(1, 0.01));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test('render six city Square and Hex contact sheets', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFF3EBDC), BlendMode.src);
    for (var i = 0; i < 6; i++) {
      final city = BoardTheme.values[i];
      final x = 20 + (i % 2) * 640.0;
      final y = 20 + (i ~/ 2) * 350.0;
      final text = TextPainter(
          text: TextSpan(
              text: BoardThemeData.forTheme(city).name,
              style: const TextStyle(
                  color: Colors.black, fontSize: 26, fontFamily: 'StonesSans')),
          textDirection: TextDirection.ltr)
        ..layout();
      text.paint(canvas, Offset(x + 12, y));
      for (final shape in BoardShape.values) {
        canvas.save();
        canvas.translate(x + shape.index * 310, y + 35);
        ThemeSamplePainter(city, shape: shape)
            .paint(canvas, const Size(300, 300));
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1300, 1070);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('build/qa/cities/boards.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(png.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
