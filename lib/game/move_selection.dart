import 'dart:math' as math;
import '../models/piece.dart';
import 'board_geometry.dart';
import 'match_state.dart';
import 'match_rules.dart';

/// Local, reversible draft. Only an empty hand exposes a committable spread.
class MoveSelection {
  Cell? source;
  Cell? inspected;
  int carry = 1;
  int _maximum = 1;
  PieceType type = PieceType.flat;
  Step? direction;
  MatchMove? _placement;
  final List<int> _drops = [];
  final List<(List<int>, Step?)> _history = [];
  String? feedback;

  List<int> get drops => List.unmodifiable(_drops);
  int get dropped => _drops.fold(0, (sum, value) => sum + value);
  int get remaining => source == null ? 0 : carry - dropped;
  bool get started => _drops.isNotEmpty;
  bool get canUndoDrop => _history.isNotEmpty;
  Cell? get current {
    var cell = source;
    for (final _ in _drops) {
      cell = cell!.step(direction!);
    }
    return cell;
  }

  MatchMove? get planned => source != null && started && remaining == 0
      ? MatchMove.spread(source!, direction!, _drops)
      : _placement;

  void clear() {
    source = null;
    inspected = null;
    direction = null;
    _placement = null;
    _drops.clear();
    _history.clear();
    feedback = null;
  }

  static Cell end(MatchMove move) => move.end;

  MatchState? preview(MatchState game) => source != null
      ? MatchRules.previewSpread(game, source!, carry, direction, _drops)
          .position
      : _placement == null
          ? null
          : MatchRules.apply(game, _placement!);

  List<Stone> hand(MatchState game) => source == null
      ? const []
      : MatchRules.previewSpread(game, source!, carry, direction, _drops).hand;

  void inspect(MatchState game, Cell cell) {
    if (game.stackAt(cell).isNotEmpty) inspected = cell;
  }

  Set<Cell> destinations(MatchState game) {
    if (source == null || remaining == 0) return {};
    if (started) {
      final next = current!.step(direction!);
      return _candidate(game, next, 1).$1.position == null ? {} : {next};
    }
    return {
      for (final step in game.geometry.directions)
        if (_candidate(game, source!.step(step), 1).$1.position != null)
          source!.step(step),
    };
  }

  void setCarry(int value) {
    if (started || value < 1 || value > _maximum) return;
    // A changed pickup starts a new draft history; old drops used a different
    // hand and must never be restored by Undo after returning to pickup.
    if (carry != value) _history.clear();
    carry = value;
    feedback = null;
  }

  /// Used for a complete, rule-checked coaching suggestion.
  void choose(MatchMove move) {
    clear();
    if (move.type != null) {
      _placement = move;
      return;
    }
    source = inspected = move.from;
    carry = _maximum = move.carry;
    direction = move.direction;
    for (final drop in move.drops) {
      for (var i = 0; i < drop; i++) {
        _history.add((List.of(_drops), direction));
        if (i == 0) {
          _drops.add(1);
        } else {
          _drops[_drops.length - 1]++;
        }
      }
    }
  }

  void _select(MatchState game, Cell cell) {
    clear();
    source = inspected = cell;
    carry = _maximum =
        math.min(game.geometry.carryLimit, game.stackAt(cell).length);
  }

  /// Placement retains tap-to-confirm. Stack drops always require Confirm move.
  bool tap(MatchState game, Cell cell) {
    if (game.finished) {
      inspect(game, cell);
      return false;
    }
    if (source != null) {
      if (cell == source && !started) {
        inspected = source;
        setCarry(carry == 1 ? _maximum : carry - 1);
        return false;
      }
      stage(game, cell);
      return false;
    }
    if (_placement?.from == cell) return true;
    if (game.stackAt(cell).isNotEmpty) {
      if (!game.opening && game.topAt(cell)?.seat == game.current) {
        _select(game, cell);
      } else {
        _placement = null;
        inspect(game, cell);
      }
    } else {
      final placement =
          MatchMove.place(cell, game.opening ? PieceType.flat : type);
      if (MatchRules.apply(game, placement) != null) {
        clear();
        _placement = placement;
      }
    }
    return false;
  }

  (SpreadPreview, List<int>, Step?) _candidate(
      MatchState game, Cell target, int count) {
    var step = direction;
    final nextDrops = List<int>.of(_drops);
    if (!started) {
      for (final value in game.geometry.directions) {
        if (source!.step(value) == target) step = value;
      }
      if (step == null) {
        return (
          const SpreadPreview.blocked('Choose a highlighted neighbor.'),
          nextDrops,
          step
        );
      }
      nextDrops.add(count);
    } else if (target == current) {
      nextDrops[nextDrops.length - 1] += count;
    } else if (target == current!.step(direction!)) {
      nextDrops.add(count);
    } else {
      return (
        const SpreadPreview.blocked(
            'Continue straight, or undo the last drop.'),
        nextDrops,
        step
      );
    }
    return (
      MatchRules.previewSpread(game, source!, carry, step, nextDrops),
      nextDrops,
      step
    );
  }

  void stage(MatchState game, Cell target, {int count = 1}) {
    if (source == null) return;
    if (remaining == 0) {
      feedback = 'All stones are staged. Confirm the move or undo a drop.';
      return;
    }
    final (candidate, nextDrops, step) = _candidate(game, target, count);
    if (candidate.position == null) {
      feedback = candidate.error;
      return;
    }
    _history.add((List.of(_drops), direction));
    _drops
      ..clear()
      ..addAll(nextDrops);
    direction = step;
    inspected = source;
    feedback = null;
  }

  /// Whether changing the current destination preserves a legal spread prefix.
  bool canAdjustDrop(MatchState game, int delta) {
    if (!started || (delta != -1 && delta != 1)) return false;
    final next = List<int>.of(_drops);
    next[next.length - 1] += delta;
    if (next.last == 0) next.removeLast();
    return MatchRules.previewSpread(
          game,
          source!,
          carry,
          next.isEmpty ? null : direction,
          next,
        ).position !=
        null;
  }

  void adjustDrop(MatchState game, int delta) {
    if (!canAdjustDrop(game, delta)) return;
    _history.add((List.of(_drops), direction));
    _drops[_drops.length - 1] += delta;
    if (_drops.last == 0) _drops.removeLast();
    if (!started) direction = null;
    inspected = source;
    feedback = null;
  }

  void dropRemaining(MatchState game) {
    if (started && remaining > 0) stage(game, current!, count: remaining);
  }

  void undoDrop() {
    if (_history.isEmpty) return;
    final (drops, previousDirection) = _history.removeLast();
    _drops
      ..clear()
      ..addAll(drops);
    direction = started ? previousDirection : null;
    inspected = source;
    feedback = null;
  }

  void swipe(MatchState game, Cell cell, Step step) {
    if (game.finished ||
        game.opening ||
        !game.geometry.directions.contains(step)) {
      return;
    }
    if (source == null) {
      if (game.topAt(cell)?.seat != game.current) return;
      _select(game, cell);
    }
    if (cell == current && (direction == null || direction == step)) {
      stage(game, cell.step(step));
    } else {
      feedback = 'Continue straight from the carried stack.';
    }
  }
}
