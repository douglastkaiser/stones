import '../models/piece.dart';
import 'board_geometry.dart';
import 'match_config.dart';
import 'match_state.dart';

/// Owned road components and the minimal empty-cell completion sets of size
/// one or two. This is exact for placement roads, not a spread/fork certificate.
class AiRoadConnections {
  AiRoadConnections(MatchState game, SeatId seat, {bool placements = true}) {
    _graph = _graphs[game.geometry] ??= _Topology(game.geometry);
    _goals = game.config.profile == RulesProfile.legacyHex
        ? [3 << (seat.index * 2)]
        : [
            for (var axis = 0; axis < game.geometry.axisCount; axis++)
              3 << (axis * 2)
          ];
    final labels = List<int>.filled(_graph.cells.length, -1);
    final owned = [
      for (final c in _graph.cells)
        game.topAt(c)?.seat == seat && game.topAt(c)?.type != PieceType.standing
    ];
    final components = <int>[];
    for (var i = 0; i < owned.length; i++) {
      if (!owned[i] || labels[i] >= 0) continue;
      final component = components.length;
      final queue = <int>[i];
      labels[i] = component;
      var flags = 0;
      for (var j = 0; j < queue.length; j++) {
        final cell = queue[j];
        flags |= _graph.boundaries[cell];
        for (final neighbor in _graph.neighbors[cell]) {
          if (owned[neighbor] && labels[neighbor] < 0) {
            labels[neighbor] = component;
            queue.add(neighbor);
          }
        }
      }
      components.add(flags);
      if (_connects(flags)) hasRoad = true;
    }
    if (!placements) return;
    for (var i = 0; i < _graph.cells.length; i++) {
      if (game.topAt(_graph.cells[i]) != null) continue;
      final adjacent = <int>{
        for (final n in _graph.neighbors[i])
          if (labels[n] >= 0) labels[n]
      };
      var flags = _graph.boundaries[i];
      for (final label in adjacent) {
        flags |= components[label];
      }
      _empties.add((i, flags, adjacent));
      if (_connects(flags)) winningCells.add(_graph.cells[i]);
    }
  }

  static final _graphs = Expando<_Topology>();
  late final _Topology _graph;
  late final List<int> _goals;
  final _empties = <(int, int, Set<int>)>[];
  final winningCells = <Cell>{};
  bool hasRoad = false;
  bool _connects(int flags) => _goals.any((mask) => (flags & mask) == mask);

  /// How many distinct second placements complete a road after each first
  /// placement. Several partners identify a fork candidate, not a fork proof:
  /// legal captures may still defend it.
  Map<Cell, int> get pairContinuations {
    if (hasRoad || winningCells.isNotEmpty) return {};
    final counts = <Cell, int>{};
    for (var i = 0; i < _empties.length; i++) {
      final a = _empties[i];
      for (var j = i + 1; j < _empties.length; j++) {
        final b = _empties[j];
        if (!_connects(a.$2 | b.$2) ||
            (!_graph.neighbors[a.$1].contains(b.$1) &&
                !a.$3.any(b.$3.contains))) {
          continue;
        }
        for (final index in [a.$1, b.$1]) {
          counts.update(_graph.cells[index], (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
    return counts;
  }

  /// Three means no road completion using at most two empty placements.
  /// criticalCells is the intersection of all minimum completion sets. Thus
  /// counting different paths through one common gap cannot invent redundancy.
  ({int gaps, Set<Cell> criticalCells}) get continuations {
    if (hasRoad) return (gaps: 0, criticalCells: <Cell>{});
    if (winningCells.isNotEmpty) {
      return (
        gaps: 1,
        criticalCells:
            winningCells.length == 1 ? winningCells.toSet() : <Cell>{}
      );
    }
    Set<Cell>? intersection;
    for (var i = 0; i < _empties.length; i++) {
      final a = _empties[i];
      for (var j = i + 1; j < _empties.length; j++) {
        final b = _empties[j];
        if (!_connects(a.$2 | b.$2)) continue;
        if (!_graph.neighbors[a.$1].contains(b.$1) &&
            !a.$3.any(b.$3.contains)) {
          continue;
        }
        final pair = {_graph.cells[a.$1], _graph.cells[b.$1]};
        intersection =
            intersection == null ? pair : intersection.intersection(pair);
        if (intersection.isEmpty) return (gaps: 2, criticalCells: <Cell>{});
      }
    }
    return intersection == null
        ? (gaps: 3, criticalCells: <Cell>{})
        : (gaps: 2, criticalCells: intersection);
  }
}

class _Topology {
  _Topology(BoardGeometry geometry) : cells = geometry.cells {
    final indices = {for (var i = 0; i < cells.length; i++) cells[i]: i};
    neighbors = [
      for (final c in cells)
        [
          for (final direction in geometry.directions)
            if (indices[c.step(direction)] case final int index) index
        ]
    ];
    boundaries = [for (final c in cells) _flags(geometry, c)];
  }
  static int _flags(BoardGeometry geometry, Cell cell) {
    var flags = 0;
    for (var axis = 0; axis < geometry.axisCount; axis++) {
      if (geometry.boundary(cell, axis, false)) flags |= 1 << (axis * 2);
      if (geometry.boundary(cell, axis, true)) flags |= 2 << (axis * 2);
    }
    return flags;
  }

  final List<Cell> cells;
  late final List<List<int>> neighbors;
  late final List<int> boundaries;
}
