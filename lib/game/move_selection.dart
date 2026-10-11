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
  List<MatchMove> choices = [];
  int pendingDrop = 1;

  void clear() {
    source = null;
    planned = null;
    choices = [];
    pendingDrop = 1;
  }

  static Cell end(MatchMove move) {
    var cell = move.from;
    for (final _ in move.drops) {
      cell = cell.step(move.direction!);
    }
    return cell;
  }

  List<MatchMove> spreads(MatchState game) => source == null
      ? []
      : MatchRules.spreads(game, source!, pickup: carry).toList();

  Set<Cell> destinations(MatchState game) {
    if (source == null) return {};
    if (planned?.direction != null) {
      final next = continuation(game);
      return next == null ? {} : {end(next)};
    }
    return {
      for (final direction in game.geometry.directions)
        if (MatchRules.play(
                game, MatchMove.spread(source!, direction, [carry])) !=
            null)
          source!.step(direction),
    };
  }

  void setCarry(int value) {
    carry = value;
    planned = null;
    choices = [];
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
        choices = [];
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
          adjacentOptions = MatchRules.play(game, next) == null ? [] : [next];
          break;
        }
      }
    }
    final options = adjacentOptions ??
        spreads(game).where((move) => end(move) == cell).toList();
    if (options.isNotEmpty) {
      choices = options;
      choose(options.first);
    } else if (!game.opening && game.topAt(cell)?.seat == game.current) {
      clear();
      source = cell;
      carry = math.min(game.geometry.carryLimit, game.stackAt(cell).length);
    } else if (game.stackAt(cell).isEmpty && source == null) {
      final placement =
          MatchMove.place(cell, game.opening ? PieceType.flat : type);
      if (MatchRules.play(game, placement) != null) {
        clear();
        planned = placement;
      }
    }
    return false;
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
    if (MatchRules.play(game, move) == null) return;
    clear();
    source = cell;
    carry = pickup;
    choices = [move];
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
    return MatchRules.play(game, next) == null ? null : next;
  }

  void continueMove(MatchState game) {
    final next = continuation(game);
    if (next != null) {
      choices = [next];
      choose(next);
    }
  }

  void backStep(MatchState game) {
    final move = planned;
    if (move?.direction == null) return;
    if (move!.drops.length == 1) {
      planned = null;
      choices = [];
      return;
    }
    final drops = move.drops.toList();
    final last = drops.removeLast();
    drops[drops.length - 1] += last;
    final previous = MatchMove.spread(move.from, move.direction!, drops);
    if (MatchRules.play(game, previous) != null) {
      choices = [previous];
      choose(previous);
    }
  }
}
