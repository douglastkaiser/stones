import 'package:flutter/material.dart';

/// Shared touch/mouse recognition; board geometry decides the direction.
/// Deliberate slow drags and quick swipes both work without double-tap latency.
class BoardCellGestures extends StatefulWidget {
  const BoardCellGestures(
      {super.key,
      required this.child,
      this.onTap,
      this.onDrag,
      this.onDragUpdate,
      this.onDragCancel});
  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onDrag;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragCancel;
  @override
  State<BoardCellGestures> createState() => _BoardCellGesturesState();
}

class _BoardCellGesturesState extends State<BoardCellGestures> {
  Offset _displacement = Offset.zero;
  Offset _origin = Offset.zero;
  @override
  Widget build(BuildContext context) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onPanDown: widget.onDrag == null
          ? null
          : (details) => _origin = details.localPosition,
      onPanStart: widget.onDrag == null
          ? null
          : (details) {
              _displacement = details.localPosition - _origin;
              widget.onDragUpdate?.call(_displacement);
            },
      onPanUpdate: widget.onDrag == null
          ? null
          : (details) {
              _displacement += details.delta;
              widget.onDragUpdate?.call(_displacement);
            },
      onPanEnd: widget.onDrag == null
          ? null
          : (details) {
              widget.onDragCancel?.call();
              final velocity = details.velocity.pixelsPerSecond;
              if (_displacement.distance >= 24) {
                widget.onDrag!(_displacement);
              } else if (velocity.dx.abs() >= 100 || velocity.dy.abs() >= 100) {
                widget.onDrag!(velocity);
              }
            },
      onPanCancel: widget.onDrag == null ? null : widget.onDragCancel,
      child: widget.child);
}
