import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board_geometry.dart';
import 'board_view.dart';

/// Local presentation state. It survives reparenting and never enters a save.
class BoardViewportController extends ChangeNotifier {
  double zoom = 1;
  Offset center = const Offset(.5, .5);
  Size size = Size.zero;
  double precisionZoom = 1;
  bool panMode = false;
  bool navigating = false;
  bool get blocksMoves => panMode || navigating;
  double get maxZoom => math.max(4, precisionZoom);

  void configure(Size value, BoardGeometry geometry) {
    size = value;
    final layout = BoardLayout(value, geometry);
    final diameter = geometry is HexGeometry
        ? math.sqrt(3) * layout.unit * .94
        : 2 * layout.unit * .96;
    precisionZoom = diameter <= 0 ? 1 : math.max(1, 48 / diameter);
    zoom = zoom.clamp(1, maxZoom);
    _clamp();
  }

  Offset get translation =>
      Offset(size.width / 2, size.height / 2) -
      Offset(center.dx * size.width, center.dy * size.height) * zoom;
  Matrix4 get matrix => Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1)
    ..scaleByDouble(zoom, zoom, 1, 1);

  void _clamp() {
    final edge = .5 / zoom;
    center = Offset(
      center.dx.clamp(edge, 1 - edge),
      center.dy.clamp(edge, 1 - edge),
    );
  }

  void transform(double scale, Offset focal, Offset sceneAnchor) {
    if (size.isEmpty) return;
    zoom = scale.clamp(1, maxZoom);
    final origin = focal - sceneAnchor * zoom;
    center = Offset(
      (size.width / 2 - origin.dx) / (zoom * size.width),
      (size.height / 2 - origin.dy) / (zoom * size.height),
    );
    _clamp();
    notifyListeners();
  }

  void magnify(bool increase) {
    final focal = Offset(size.width / 2, size.height / 2);
    transform(
      increase
          ? (zoom == 1 ? math.max(1.25, precisionZoom) : zoom * 1.25)
          : zoom / 1.25,
      focal,
      (focal - translation) / zoom,
    );
  }

  void fit({bool notify = true}) {
    zoom = 1;
    center = const Offset(.5, .5);
    panMode = false;
    navigating = false;
    if (notify) notifyListeners();
  }

  void beginNavigation() {
    navigating = true;
    notifyListeners();
  }

  void endNavigation() {
    if (!navigating) return;
    navigating = false;
    notifyListeners();
  }

  void togglePan() {
    panMode = !panMode;
    notifyListeners();
  }

  void reveal(Cell cell, BoardGeometry geometry) {
    if (size.isEmpty || zoom == 1) return;
    final point = BoardLayout(size, geometry).center(cell);
    center = Offset(point.dx / size.width, point.dy / size.height);
    _clamp();
    notifyListeners();
  }
}

class BoardViewportTools extends StatelessWidget {
  const BoardViewportTools({super.key, required this.controller});
  final BoardViewportController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              onPressed:
                  controller.zoom <= 1 ? null : () => controller.magnify(false),
              icon: const Icon(Icons.zoom_out),
            ),
            Text(
              '${(controller.zoom * 100).round()}%',
              semanticsLabel:
                  'Board zoom ${(controller.zoom * 100).round()} percent',
            ),
            IconButton(
              tooltip: 'Zoom in for precise play',
              onPressed: controller.zoom >= controller.maxZoom
                  ? null
                  : () => controller.magnify(true),
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: 'Fit board',
              onPressed: controller.fit,
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              tooltip: controller.panMode ? 'Return to play' : 'Pan board',
              isSelected: controller.panMode,
              onPressed: controller.togglePan,
              icon: const Icon(Icons.pan_tool_outlined),
              selectedIcon: const Icon(Icons.pan_tool),
            ),
          ],
        ),
      );
}

/// Owns navigation gestures above cell hit testing; the board retains its geometry.
class BoardViewport extends StatefulWidget {
  const BoardViewport({
    super.key,
    required this.controller,
    required this.geometry,
    required this.child,
  });
  final BoardViewportController controller;
  final BoardGeometry geometry;
  final Widget child;
  @override
  State<BoardViewport> createState() => _BoardViewportState();
}

class _BoardViewportState extends State<BoardViewport> {
  final _pointers = <int>{};
  ScrollHoldController? _scrollHold;
  Offset _anchor = Offset.zero;
  double _initialZoom = 1, _initialSpan = 1;
  BoardViewportController get controller => widget.controller;

  void _begin(Offset focal, double span) {
    controller.beginNavigation();
    _scrollHold ??=
        Scrollable.maybeOf(context)?.position.hold(() => _scrollHold = null);
    _anchor = (focal - controller.translation) / controller.zoom;
    _initialZoom = controller.zoom;
    _initialSpan = span;
  }

  @override
  void dispose() {
    _scrollHold?.cancel();
    controller.navigating = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, bounds) {
          controller.configure(bounds.biggest, widget.geometry);
          return FocusTraversalGroup(
            child: Focus(
              onKeyEvent: (_, event) =>
                  event.logicalKey == LogicalKeyboardKey.space
                      ? KeyEventResult.handled
                      : KeyEventResult.ignored,
              child: Listener(
                onPointerDown: (event) {
                  _pointers.add(event.pointer);
                  if (_pointers.length > 1) controller.navigating = true;
                },
                onPointerUp: _release,
                onPointerCancel: _release,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    _ViewportGesture:
                        GestureRecognizerFactoryWithHandlers<_ViewportGesture>(
                      _ViewportGesture.new,
                      (recognizer) {
                        recognizer.pan = () =>
                            controller.panMode ||
                            HardwareKeyboard.instance.isLogicalKeyPressed(
                              LogicalKeyboardKey.space,
                            );
                        recognizer.begin = _begin;
                        recognizer.update =
                            (focal, span) => controller.transform(
                                  _initialZoom * span / _initialSpan,
                                  focal,
                                  _anchor,
                                );
                      },
                    ),
                  },
                  child: ClipRect(
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => Transform(
                        transform: controller.matrix,
                        child: IgnorePointer(
                          ignoring: controller.panMode,
                          child: widget.child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  void _release(PointerEvent event) {
    _pointers.remove(event.pointer);
    // Keep the guard until recognizers have processed this same pointer-up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pointers.isEmpty) {
        controller.endNavigation();
        _scrollHold?.cancel();
        _scrollHold = null;
      }
    });
  }
}

/// One finger belongs to gameplay unless Pan/Space is explicit. Two fingers
/// claim navigation and cancel child taps/drags through the gesture arena.
class _ViewportGesture extends OneSequenceGestureRecognizer {
  final _points = <int, Offset>{};
  bool _active = false;
  late bool Function() pan;
  late void Function(Offset, double) begin, update;
  Offset get _focal =>
      _points.values.reduce((a, b) => a + b) / _points.length.toDouble();
  double get _span => _points.length < 2
      ? 1
      : math.max(1, (_points.values.first - _points.values.last).distance);
  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _points[event.pointer] = event.localPosition;
    if (_points.length > 1 || pan()) {
      _active = true;
      resolve(GestureDisposition.accepted);
      begin(_focal, _span);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _points.containsKey(event.pointer)) {
      _points[event.pointer] = event.localPosition;
      if (_active) update(_focal, _span);
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _points.remove(event.pointer);
      if (_active && _points.isNotEmpty) begin(_focal, _span);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {}
  @override
  void rejectGesture(int pointer) {
    // Continue tracking without acting: a later second finger can claim its
    // own arena and convert an in-progress stack drag into navigation.
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (!_active) resolve(GestureDisposition.rejected);
    _active = false;
    _points.clear();
  }

  @override
  String get debugDescription => 'board viewport navigation';
}

/// Navigation remains reachable even when a zoomed board fills a short screen.
class BoardViewportMenu extends StatelessWidget {
  const BoardViewportMenu({super.key, required this.controller});
  final BoardViewportController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => PopupMenuButton<String>(
          tooltip: 'Board view',
          icon: Icon(controller.panMode ? Icons.pan_tool : Icons.zoom_in_map,
              color: controller.panMode
                  ? Theme.of(context).colorScheme.primary
                  : null),
          onSelected: (value) {
            switch (value) {
              case 'in':
                controller.magnify(true);
              case 'out':
                controller.magnify(false);
              case 'fit':
                controller.fit();
              case 'pan':
                controller.togglePan();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'in',
                enabled: controller.zoom < controller.maxZoom,
                child: const Text('Zoom in for precise play')),
            PopupMenuItem(
                value: 'out',
                enabled: controller.zoom > 1,
                child: const Text('Zoom out')),
            const PopupMenuItem(value: 'fit', child: Text('Fit board')),
            CheckedPopupMenuItem(
                value: 'pan',
                checked: controller.panMode,
                child:
                    Text(controller.panMode ? 'Return to play' : 'Pan board')),
          ],
        ),
      );
}
