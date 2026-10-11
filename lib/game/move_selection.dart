import 'dart:math' as math;
import '../models/piece.dart';
import 'board_geometry.dart';
import 'match_state.dart';
import 'match_rules.dart';

/// Shared planner; previews are complete legal moves against the original board.
class MoveSelection {
  Cell? source;
  int carry = 1;
  PieceType type = PieceType.flat;
  MatchMove? planned;
  int pendingDrop = 1;

  void clear() {
    source = null;
    planned = null;
    pendingDrop = 1;
  }

  static Cell end(MatchMove move) {
    var cell = move.from;
    for (final _ in move.drops) {
      cell = cell.step(move.direction!);
    }
    return cell;
  }

  Set<Cell> destinations(MatchState game) {
    if (source == null) return {};
    if (planned?.direction != null) {
      final next = continuation(game);
      return next == null ? {} : {end(next)};
    }
    return {
      for (final direction in game.geometry.directions)
        if (MatchRules.apply(
                game, MatchMove.spread(source!, direction, [carry])) !=
            null)
          source!.step(direction),
    };
  }

  void setCarry(int value) {
    carry = value;
    planned = null;
    pendingDrop = 1;
  }

  void choose(MatchMove move) {
    planned = move;
    pendingDrop = 1;
  }

  /// True requests confirmation of an already-visible placement/single stone.
  bool tap(MatchState game, Cell cell) {
    if (game.finished) return false;
    final move = planned;
    if (move?.type != null && move!.from == cell) return true;
    if (move?.direction != null && end(move!) == cell) {
      if (carry == 1) return true;
      pendingDrop = pendingDrop >= move.drops.last ? 1 : pendingDrop + 1;
      return false;
    }
    if (move?.direction != null) {
      if (cell == source) {
        planned = null;
      } else if (cell == end(move!).step(move.direction!)) {
        continueMove(game);
      }
      return false; // Stray taps preserve the preview.
    }
    if (cell == source) {
      final max = math.min(game.geometry.carryLimit, game.stackAt(cell).length);
      setCarry(carry <= 1 ? max : carry - 1);
      return false;
    }
    // The primary neighbor interaction has exactly one complete distribution.
    // Avoid enumerating every long spread (thousands at carry nine) for a tap.
    List<MatchMove>? adjacentOptions;
    if (source != null) {
      for (final direction in game.geometry.directions) {
        if (source!.step(direction) == cell) {
          final next = MatchMove.spread(source!, direction, [carry]);
          adjacentOptions = MatchRules.apply(game, next) == null ? [] : [next];
          break;
        }
      }
    }
    // A distant tap has a predictable preview: one bottom stone per crossed
    // cell, with the remainder at the destination. Checking at most the carry
    // limit avoids enumerating exponentially many distributions in a gesture.
    final options = adjacentOptions ?? _distantPreview(game, cell);
    if (options.isNotEmpty) {
      choose(options.first);
    } else if (!game.opening && game.topAt(cell)?.seat == game.current) {
      clear();
      source = cell;
      carry = math.min(game.geometry.carryLimit, game.stackAt(cell).length);
    } else if (game.stackAt(cell).isEmpty && source == null) {
      final placement =
          MatchMove.place(cell, game.opening ? PieceType.flat : type);
      if (MatchRules.apply(game, placement) != null) {
        clear();
        planned = placement;
      }
    }
    return false;
  }

  List<MatchMove> _distantPreview(MatchState game, Cell destination) {
    if (source == null) return [];
    for (final direction in game.geometry.directions) {
      var cell = source!;
      for (var distance = 1; distance <= carry; distance++) {
        cell = cell.step(direction);
        if (!game.geometry.contains(cell)) break;
        if (cell != destination) continue;
        final move = MatchMove.spread(source!, direction,
            [for (var i = 1; i < distance; i++) 1, carry - distance + 1]);
        return MatchRules.apply(game, move) == null ? [] : [move];
      }
    }
    return [];
  }

  void swipe(MatchState game, Cell cell, Step direction) {
    if (game.finished || game.opening) return;
    if (planned?.direction != null) {
      if (cell == end(planned!) && direction == planned!.direction) {
        continueMove(game);
      }
      return;
    }
    if (game.topAt(cell)?.seat != game.current) return;
    final pickup = source == cell
        ? carry
        : math.min(game.geometry.carryLimit, game.stackAt(cell).length);
    final move = MatchMove.spread(cell, direction, [pickup]);
    if (MatchRules.apply(game, move) == null) return;
    clear();
    source = cell;
    carry = pickup;
    choose(move);
  }

  MatchMove? continuation(MatchState game) {
    final move = planned;
    if (move?.direction == null || pendingDrop >= move!.drops.last) return null;
    final next = MatchMove.spread(move.from, move.direction!, [
      ...move.drops.take(move.drops.length - 1),
      pendingDrop,
      move.drops.last - pendingDrop,
    ]);
    return MatchRules.apply(game, next) == null ? null : next;
  }

  void continueMove(MatchState game) {
    final next = continuation(game);
    if (next != null) {
      choose(next);
    }
  }

  void backStep(MatchState game) {
    final move = planned;
    if (move?.direction == null) return;
    if (move!.drops.length == 1) {
      planned = null;
      return;
    }
    final drops = move.drops.toList();
    final last = drops.removeLast();
    drops[drops.length - 1] += last;
    final previous = MatchMove.spread(move.from, move.direction!, drops);
    if (MatchRules.apply(game, previous) != null) {
      choose(previous);
    }
  }
}
