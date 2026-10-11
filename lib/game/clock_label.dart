import 'dart:async';
import 'package:flutter/material.dart';
import 'match_clock.dart';
import 'match_config.dart';

/// Only the timer label rebuilds on clock ticks; the board stays untouched.
class ClockLabel extends StatefulWidget {
  const ClockLabel(
      {super.key,
      required this.clock,
      required this.seat,
      this.finished = false});
  final MatchClock clock;
  final SeatId seat;
  final bool finished;
  @override
  State<ClockLabel> createState() => _ClockLabelState();
}

class _ClockLabelState extends State<ClockLabel> {
  Timer? _timer;
  DateTime? _endedAt;
  @override
  void initState() {
    super.initState();
    _update();
  }

  void _update() {
    _timer?.cancel();
    _endedAt = widget.finished ? DateTime.now() : null;
    if (!widget.finished) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(ClockLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.finished != widget.finished ||
        oldWidget.seat != widget.seat) {
      _update();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds =
        (widget.clock.remaining(widget.seat, _endedAt ?? DateTime.now()) / 1000)
            .ceil();
    return Text('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
        semanticsLabel:
            '${widget.seat.label} clock: ${seconds ~/ 60} minutes ${seconds % 60} seconds');
  }
}
