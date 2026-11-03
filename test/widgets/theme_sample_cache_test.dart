import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stones/game/match_config.dart';
import 'package:stones/models/cosmetics.dart';
import 'package:stones/widgets/theme_gallery.dart';

Widget sample({
  BoardTheme theme = BoardTheme.classicWood,
  PieceStyle style = PieceStyle.standard,
  BoardShape shape = BoardShape.square,
  double ratio = 2,
  double side = 64,
  int count = 1,
}) =>
    Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
            data: MediaQueryData(devicePixelRatio: ratio),
            child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                    width: side,
                    height: side,
                    child:
                        ThemeSample(theme: theme, style: style, shape: shape)),
            ]))));

Future<void> waitForImages(List<ui.Image> images, int count) async {
  for (var i = 0; i < 300 && images.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(images.length, count);
}

void main() {
  final created = <ui.Image>[];
  final disposed = <ui.Image>[];
  setUp(() {
    created.clear();
    disposed.clear();
    ui.Image.onCreate = created.add;
    ui.Image.onDispose = disposed.add;
  });
  tearDown(() {
    ui.Image.onCreate = null;
    ui.Image.onDispose = null;
  });

  testWidgets('preview caches exact device pixels and invalidates every input',
      (tester) async {
    await tester.pumpWidget(sample());
    await tester.runAsync(() => waitForImages(created, 1));
    await tester.pump();
    final first = created.single;
    expect(first.width, 128);
    expect(first.height, 128);
    await tester.runAsync(() async {
      // Compare the actual cached pixels with the original shared painter.
      ui.Image.onCreate = null;
      final recorder = ui.PictureRecorder();
      const ThemeSamplePainter(BoardTheme.classicWood,
              style: PieceStyle.standard)
          .paint(Canvas(recorder)..scale(2), const Size(64, 64));
      final picture = recorder.endRecording();
      final reference = await picture.toImage(128, 128);
      expect((await first.toByteData())!.buffer.asUint8List(),
          (await reference.toByteData())!.buffer.asUint8List());
      reference.dispose();
      picture.dispose();
      ui.Image.onCreate = created.add;
    });
    for (final update in [
      sample(theme: BoardTheme.kyoto),
      sample(theme: BoardTheme.kyoto, style: PieceStyle.morocco),
      sample(
          theme: BoardTheme.kyoto,
          style: PieceStyle.morocco,
          shape: BoardShape.hex),
      sample(ratio: 2.75, side: 96),
    ]) {
      final previous = created.last;
      final count = created.length;
      await tester.pumpWidget(update);
      await tester.runAsync(() => waitForImages(created, count + 1));
      await tester.pump();
      expect(disposed, contains(previous));
    }
    expect(created.last.width, 264);
    await tester.pumpWidget(const SizedBox());
    expect(disposed, containsAll(created));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'preview image budget includes pending work and survives disposal',
      (tester) async {
    // Each exact-resolution image reserves 16 MiB; only two fit the 32 MiB
    // budget. A third preview retains the original vector painter and semantics.
    await tester.pumpWidget(sample(ratio: 32, count: 3));
    await tester.runAsync(() => waitForImages(created, 2));
    await tester.pump();
    expect(created.every((image) => image.width == 2048), isTrue);
    expect(find.byType(ThemeSample), findsNWidgets(3));
    await tester
        .pumpWidget(sample(ratio: 32, count: 3, style: PieceStyle.kyoto));
    // Dispose while the next generation's rasterization is still pending.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => waitForImages(created, 4));
    expect(disposed, containsAll(created));
    await tester.pumpWidget(sample());
    await tester.runAsync(() => waitForImages(created, 5));
    await tester.pump();
    expect(created.last.width, 128);
    await tester.pumpWidget(const SizedBox());
    expect(disposed, containsAll(created));
    expect(tester.takeException(), isNull);
  });
}
