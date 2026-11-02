import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cosmetics.dart';
import '../models/piece.dart';
import '../providers/cosmetics_provider.dart';
import '../game/board_geometry.dart';
import '../game/board_view.dart';
import '../game/match_config.dart';
import 'piece_stack_view.dart';
import 'procedural_painters.dart';

/// Board and Pieces have independent selections, previews and persistence.
class ThemeGallery extends ConsumerStatefulWidget {
  const ThemeGallery({super.key});
  @override
  ConsumerState<ThemeGallery> createState() => _ThemeGalleryState();
}

class _ThemeGalleryState extends ConsumerState<ThemeGallery> {
  bool _pieces = false;
  @override
  Widget build(BuildContext context) {
    final currentBoard = ref.watch(currentBoardThemeProvider).theme;
    final currentPieces = ref.watch(currentPieceStyleProvider).style;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
              value: false, label: Text('Board'), icon: Icon(Icons.grid_on)),
          ButtonSegment(
              value: true,
              label: Text('Pieces'),
              icon: Icon(Icons.category_outlined)),
        ],
        selected: {_pieces},
        onSelectionChanged: (value) => setState(() => _pieces = value.single),
      ),
      const SizedBox(height: 12),
      Text(
          'Board: ${BoardThemeData.forTheme(currentBoard).name} · Pieces: ${PieceStyleData.forStyle(currentPieces).name}',
          key: const ValueKey('current-cosmetics')),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns =
            (constraints.maxWidth / (210 * scale)).floor().clamp(1, 3);
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final city in BoardTheme.values)
            SizedBox(
                width: width,
                child: Builder(builder: (context) {
                  final data = BoardThemeData.forTheme(city);
                  final style = piecesForBoard(city);
                  final unlocked =
                      ref.watch(isBoardThemeUnlockedProvider(city));
                  final active = unlocked &&
                      (_pieces ? currentPieces == style : currentBoard == city);
                  final sampleBoard = _pieces ? currentBoard : city;
                  final samplePieces = _pieces ? style : currentPieces;
                  void preview() => showCityPreview(context,
                      theme: sampleBoard, style: samplePieces, city: city);
                  return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                              width: active ? 2 : 1)),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            ThemeSample(
                                theme: sampleBoard, style: samplePieces),
                            const SizedBox(height: 8),
                            Text(data.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                _pieces
                                    ? PieceStyleData.forStyle(style).description
                                    : data.description,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Wrap(
                                spacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  TextButton(
                                      onPressed: preview,
                                      child: Text('Preview ${data.name}')),
                                  FilledButton.tonal(
                                      onPressed: !unlocked || active
                                          ? null
                                          : () {
                                              final notifier = ref.read(
                                                  cosmeticsProvider.notifier);
                                              if (_pieces) {
                                                notifier.setPieceStyle(style);
                                              } else {
                                                notifier.setBoardTheme(city);
                                              }
                                            },
                                      child: Text(active
                                          ? 'Selected'
                                          : !unlocked
                                              ? 'Locked'
                                              : _pieces
                                                  ? 'Use pieces'
                                                  : 'Use board')),
                                ]),
                          ])));
                })),
        ]);
      }),
    ]);
  }
}

void showCityPreview(BuildContext context,
    {required BoardTheme theme,
    required PieceStyle style,
    required BoardTheme city}) {
  showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
            title: Text(BoardThemeData.forTheme(city).name),
            content: SizedBox(
                width: 640,
                height:
                    (MediaQuery.sizeOf(context).height * .65).clamp(160, 720),
                child: SingleChildScrollView(
                    child: CityPreviewContent(
                        theme: theme, style: style, city: city))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'))
            ],
          ));
}

/// Also used by read-only opponent inspection. No equip side effects.
class CityPreviewContent extends ConsumerWidget {
  const CityPreviewContent(
      {super.key,
      required this.theme,
      required this.style,
      required this.city});
  final BoardTheme theme, city;
  final PieceStyle style;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(isBoardThemeUnlockedProvider(city));
    final pieces = PieceStyleData.forStyle(style);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              city == BoardTheme.classicWood
                  ? 'Available to everyone.'
                  : unlocked
                      ? 'Unlocked'
                      : 'Locked',
              style: Theme.of(context).textTheme.titleSmall),
          if (city != BoardTheme.classicWood) Text(cityUnlockRequirement(city)),
          const SizedBox(height: 12),
          Text(
              'Board: ${BoardThemeData.forTheme(theme).name} · Pieces: ${pieces.name}'),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, bounds) {
            Widget sample(BoardShape shape) =>
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(shape == BoardShape.square ? 'Square' : 'Hex',
                      style: Theme.of(context).textTheme.titleSmall),
                  ThemeSample(theme: theme, style: style, shape: shape),
                ]);
            return bounds.maxWidth >= 440
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: sample(BoardShape.square)),
                    Expanded(child: sample(BoardShape.hex))
                  ])
                : Column(children: [
                    sample(BoardShape.square),
                    sample(BoardShape.hex)
                  ]);
          }),
          const SizedBox(height: 12),
          const Text('Four players · flats, upright walls and capstones'),
          for (final identity in PieceIdentity.values)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${pieces.palettes[identity.index].name} · ${identity.label} flat'),
                      Row(children: [
                        for (final type in PieceType.values)
                          Expanded(
                              child: Semantics(
                                  label:
                                      '${pieces.palettes[identity.index].name} ${type == PieceType.standing ? 'wall' : type.name}',
                                  child: SizedBox(
                                      height: 64,
                                      child: Center(
                                          child: PieceStackView.stone(
                                              StackVisualPiece(
                                                  type: type,
                                                  style: style,
                                                  colors:
                                                      pieces.colorsForIdentity(
                                                          identity),
                                                  owner: pieces
                                                      .palettes[identity.index]
                                                      .name,
                                                  identity: identity),
                                              56))))),
                      ]),
                    ])),
          const SizedBox(height: 8),
          const Text(
              'Players bring their own pieces. Online matches use the host’s board theme.'),
        ]);
  }
}

class ThemeSample extends StatelessWidget {
  const ThemeSample(
      {super.key,
      required this.theme,
      this.style,
      this.shape = BoardShape.square});
  final BoardTheme theme;
  final PieceStyle? style;
  final BoardShape shape;
  @override
  Widget build(BuildContext context) => Semantics(
      label:
          '${BoardThemeData.forTheme(theme).name} ${shape.name} board with all four players’ flats, walls and capstones',
      image: true,
      child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
              painter: ThemeSamplePainter(theme, style: style, shape: shape))));
}

/// Same geometry, grid, textures, layer proportions and pieces as live play.
class ThemeSamplePainter extends CustomPainter {
  const ThemeSamplePainter(this.theme,
      {this.style, this.shape = BoardShape.square});
  final BoardTheme theme;
  final PieceStyle? style;
  final BoardShape shape;
  @override
  void paint(Canvas canvas, Size size) {
    final data = BoardThemeData.forTheme(theme);
    final pieces = PieceStyleData.forStyle(style ?? piecesForBoard(theme));
    final geometry =
        shape == BoardShape.square ? SquareGeometry(4) : HexGeometry(2);
    final layout = BoardLayout(size, geometry);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Row-major ordering keeps four square columns aligned with player order.
    final cells = geometry.cells.toList()
      ..sort((a, b) => a.y == b.y ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    paintCityBoardFrame(canvas, cells.map(layout.polygon), data, layout.unit);
    for (var i = 0; i < cells.length; i++) {
      final cell = cells[i];
      final polygon = layout.polygon(cell);
      final bounds = layout.bounds(cell);
      canvas.save();
      canvas.clipPath(polygon);
      canvas.translate(bounds.left, bounds.top);
      getBoardTexturePainter(theme: data, seed: cell.x * 7 + cell.y)
          .paint(canvas, bounds.size);
      canvas.restore();
      paintCityGrid(canvas, polygon, data, layout.unit);
      if (i < 12) {
        final identity = PieceIdentity.values[i % 4];
        final type = PieceType.values[i ~/ 4];
        final visual = StackVisualPiece(
            type: type,
            style: pieces.style,
            colors: pieces.colorsForIdentity(identity),
            identity: identity,
            owner: pieces.palettes[identity.index].name);
        final width = layout.unit * 1.4;
        final height = width * visual.aspect;
        canvas.save();
        canvas.translate(
            bounds.center.dx - width / 2, bounds.center.dy - height / 2);
        ThemedPiecePainter(
                style: pieces.style,
                colors: visual.colors,
                type: type,
                identity: identity)
            .paint(canvas, Size(width, height));
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ThemeSamplePainter old) =>
      theme != old.theme || style != old.style || shape != old.shape;
}
