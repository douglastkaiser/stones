# Performance Analysis Report - Stones (Tak Board Game)

**Date:** 2025-12-13
**Analyzed by:** Claude Code
**Codebase:** Flutter-based Tak game with AI opponents

---

## Executive Summary

Identified **10 major performance issues** across AI algorithms, state management, and UI rendering. The most critical issues cause **O(n⁴) complexity** in AI move evaluation and **exponential board state copying**. Estimated performance improvement: **2-10x on Hard AI difficulty**, with noticeable improvements during move evaluation and game rendering.

---

## Critical Issues (Fix Immediately)

### 🔴 Issue #1: Exponential Board State Copying

**Severity:** CRITICAL
**Impact:** Every move evaluation triggers dozens to hundreds of full board copies
**Files affected:**
- `lib/models/board.dart:156-166` - `setStack()` method
- `lib/services/ai/move_generator.dart:126,144` - Called in simulation loops
- `lib/services/ai/hard_ai.dart:246` - Called in threat detection

**Problem:**
```dart
// board.dart:156-166
Board setStack(Position pos, PieceStack stack) {
  final newCells = [
    for (int r = 0; r < size; r++)     // O(n)
      [
        for (int c = 0; c < size; c++) // O(n)
          if (r == pos.row && c == pos.col) stack else cells[r][c]
      ]
  ];
  return Board._(size: size, cells: newCells);
}
```

Every call creates a complete O(n²) copy of the board grid. In AI evaluation:
- **move_generator.dart:144**: Called in `_simulateStackMove()` loop - up to 49+ times per stack move evaluation (once per drop)
- **hard_ai.dart:246**: Called inside `_countThreats()` double loop - up to n² times
- For 3-ply minimax on 6x6 board: **thousands** of board copies per AI move

**Complexity:** O(n²) per call → Compounds to O(n⁴) in `_countThreats()`

**Recommendation:**
1. **Short-term:** Implement copy-on-write semantics with shared cell arrays
2. **Medium-term:** Use persistent data structures (e.g., immutable collections)
3. **Long-term:** Switch to single 1D array with index calculations `cells[row * size + col]`

---

### 🔴 Issue #2: N+1 BFS Query Pattern in Road Detection

**Severity:** CRITICAL
**Impact:** 4 separate breadth-first searches per neighbor evaluation
**Files affected:**
- `lib/services/ai/hard_ai.dart:548-556` - `_evaluateChainExtension()`
- `lib/services/ai/hard_ai.dart:237-255` - Used in threat detection
- `lib/services/ai/medium_ai.dart:253-256` - Same pattern

**Problem:**
```dart
// hard_ai.dart:548-556
for (final neighbor in neighbors) {
  if (_controlsForRoad(state, neighbor, color)) {
    // BFS #1 - check left/top edges
    if (_canReachEdge(state, neighbor, color, (p) => p.col == 0 || p.row == 0)) {
      connectsToLeftOrTop = true;
    }
    // BFS #2 - check right/bottom edges
    if (_canReachEdge(state, neighbor, color, (p) => p.col == size - 1 || p.row == size - 1)) {
      connectsToRightOrBottom = true;
    }
  }
}
```

Each `_canReachEdge()` performs a complete BFS traversal (worst case O(n²)). For a position with 4 neighbors, this means **8 BFS traversals** when a single traversal could determine all edge connections.

**Complexity:** O(neighbors × n²) per evaluation

**Recommendation:**
1. Create `_canReachEdges()` that returns all reachable edges in single BFS
2. Cache road connectivity per board state (board hash → edge connections map)
3. Use early termination when both conditions met

---

### 🔴 Issue #3: Quadratic Threat Enumeration Without Caching

**Severity:** CRITICAL
**Impact:** Every threat check simulates placing pieces on ALL empty cells
**Files affected:**
- `lib/services/ai/hard_ai.dart:236-255` - `_countThreats()`
- Called at lines: 96, 144, 145, 204, 205, 209, 210, 265, 284

**Problem:**
```dart
// hard_ai.dart:236-255
int _countThreats(GameState state, PlayerColor color) {
  var threats = 0;
  final board = state.board;
  final size = state.boardSize;

  for (int r = 0; r < size; r++) {           // O(n)
    for (int c = 0; c < size; c++) {         // O(n)
      final pos = Position(r, c);
      if (board.stackAt(pos).isEmpty) {
        final newBoard = board.placePiece(pos, piece);  // O(n²) board copy!
        final testState = state.copyWith(board: newBoard);
        if (_hasRoad(testState, color)) {    // O(n²) BFS
          threats++;
        }
      }
    }
  }
  return threats;
}
```

**Complexity Analysis:**
- Outer loops: O(n²) for all positions
- Per iteration: O(n²) board copy + O(n²) BFS
- **Total: O(n² × (n² + n²)) = O(n⁴) per call**

Called **8 times** in `_evaluateOffensive()` alone (lines 204-210):
```dart
final ourThreats = _countThreats(afterMove, state.currentPlayer);    // Call 1
final theirThreats = _countThreats(afterMove, state.opponent);       // Call 2
final currentOurThreats = _countThreats(state, state.currentPlayer); // Call 3
final currentTheirThreats = _countThreats(state, state.opponent);    // Call 4
```

**Recommendation:**
1. **Urgent:** Cache threat positions per board state (use board hash as key)
2. **High priority:** Incremental threat detection - only check positions near the last move
3. **Optimization:** Early termination when threat count >= 2 (for fork detection)
4. **Alternative:** Pre-compute "near-winning" patterns instead of exhaustive search

---

### 🔴 Issue #4: GridView Rebuilding All Cells on Every Animation

**Severity:** HIGH
**Impact:** All 25-64 cells rebuild on any state change
**Files affected:**
- `lib/main.dart:1900-2030` - `_BoardGridWidget.build()`
- `lib/main.dart:2007` - Cell key includes timestamp

**Problem:**
```dart
// main.dart:1910-1912 - Recalculated 25-64 times per build
final dropPath = uiState.getDropPath();                           // Called per cell!
final nextDropPos = uiState.getCurrentHandPosition();             // Called per cell!
final validMoveDestinations = uiState.getValidMoveDestinations(gameState); // Called per cell!

// main.dart:2007 - Key changes on EVERY animation frame
key: ValueKey('cell_${pos.row}_${pos.col}_..._${lastEvent?.timestamp.millisecondsSinceEpoch ?? 0}_...'),
```

**Impact:**
- `getDropPath()`, `getCurrentHandPosition()`, `getValidMoveDestinations()` are expensive O(n) operations called **once per cell** in every build
- For 5x5 board: **25× redundant calculations** per frame
- Timestamp in key causes Flutter to rebuild cell widgets even when cell content unchanged
- During AI move evaluation or animations: **dozens of rebuilds per second**

**Recommendation:**
1. **Move expensive calculations outside `itemBuilder`** - compute once before GridView.builder
2. **Fix cell keys** - remove timestamp, use only position and content hash
3. **Use `const` where possible** - BoxDecoration, TextStyle, etc.
4. **Consider RepaintBoundary** - wrap cells to limit rebuild scope

---

## High Priority Issues

### 🟠 Issue #5: Over-Broad Provider Dependencies

**Severity:** HIGH
**Impact:** Entire widget rebuilds when only specific fields needed
**Files affected:**
- `lib/main.dart:170` - HomeScreen watches entire `gameStateProvider`
- `lib/main.dart:396` - GameScreen watches entire `gameStateProvider`

**Problem:**
```dart
// main.dart:170 - HomeScreen
final gameState = ref.watch(gameStateProvider);
// Only uses: turnNumber, board.occupiedPositions.isEmpty

// Should be:
final hasGameInProgress = ref.watch(gameStateProvider.select(
  (s) => s.turnNumber > 1 || s.board.occupiedPositions.isNotEmpty
));
```

**Impact:** HomeScreen rebuilds on every game state change (every move, phase change, etc.) when it only cares about whether a game is in progress.

**Recommendation:**
1. Use `ref.watch(provider.select((s) => s.field))` for granular dependencies
2. Create separate providers for frequently-accessed derived state
3. Use `ref.listen()` for side effects instead of rebuilding entire widgets

---

### 🟠 Issue #6: Missing const Keywords on Expensive Widgets

**Severity:** MEDIUM-HIGH
**Impact:** Unnecessary widget allocations, GC pressure
**Files affected:**
- `lib/main.dart:1920-1943` - Container with BoxDecoration
- `lib/main.dart:2324-2348` - Cell BoxDecoration

**Problem:**
```dart
// main.dart:1927-1941 - BoxShadow list recreated every rebuild
boxShadow: [
  BoxShadow(
    color: GameColors.gridLineShadow.withValues(alpha: 0.6),
    blurRadius: 4,
    spreadRadius: 1,
    offset: const Offset(2, 2),
  ),
  BoxShadow(
    color: GameColors.gridLineHighlight.withValues(alpha: 0.3),
    blurRadius: 2,
    offset: const Offset(-1, -1),
  ),
],
```

**Impact:**
- New BoxShadow objects allocated on every rebuild
- For GridView: **multiple allocations per cell** × 25-64 cells
- Increased garbage collection pressure

**Recommendation:**
1. Extract to static const fields where possible
2. Create const BoxDecoration instances
3. Use const constructors for SizedBox, Text, Icon, etc.

---

## Medium Priority Issues

### 🟡 Issue #7: Duplicate Pathfinding Logic Across AI Classes

**Severity:** MEDIUM
**Impact:** Code maintenance burden, inconsistent optimizations
**Files affected:**
- `lib/services/ai/easy_ai.dart:157-215` - `_hasRoad()`, `_canReachEdge()`, etc.
- `lib/services/ai/medium_ai.dart:367-423` - Duplicate implementations
- `lib/services/ai/hard_ai.dart:397-452` - Duplicate implementations
- `lib/services/ai/move_generator.dart:111-149` - Another duplicate

**Problem:**
```bash
$ grep -c "_hasRoad\|_canReachEdge\|_controlsForRoad" lib/services/ai/*.dart
easy_ai.dart:14
medium_ai.dart:27
hard_ai.dart:18
```

59 total occurrences across 3 files, with nearly identical implementations of:
- `_hasRoad()` - Check if player has winning road
- `_canReachEdge()` - BFS to check edge connectivity
- `_controlsForRoad()` - Check if position contributes to road

**Impact:**
- Violates DRY principle
- Bug fixes/optimizations must be applied 3-4 times
- Cannot globally optimize pathfinding without touching all files

**Recommendation:**
1. Extract to shared utilities in `move_generator.dart` or new `board_analysis.dart`
2. Make methods static/top-level functions
3. Consider creating `RoadDetector` class with caching

---

### 🟡 Issue #8: Redundant Road Checks Without Early Returns

**Severity:** MEDIUM
**Impact:** Multiple expensive BFS calls per evaluation
**Files affected:**
- `lib/services/ai/hard_ai.dart:91-92, 105, 133, 301, 312`

**Problem:**
```dart
// hard_ai.dart:86-108
if (_hasRoad(afterOurMove, state.currentPlayer)) {  // BFS for player 1
  return 1000;
}
// ... later ...
for (final oppMove in opponentMoves) {
  if (_hasRoad(afterOpp, state.opponent)) {  // BFS for player 2
    return -500;
  }
}
```

Could combine into single method that checks both players in one traversal.

**Recommendation:**
1. Create `_getRoadWinner(state)` that returns winner in single pass
2. Use early returns aggressively
3. Cache road detection results per board hash

---

### 🟡 Issue #9: Inefficient List Creation in IntroAI

**Severity:** LOW
**Impact:** Minor memory allocation overhead
**Files affected:**
- `lib/services/ai/intro_ai.dart:15-16`

**Problem:**
```dart
final placements = moves.whereType<AIPlacementMove>().toList();
final stackMoves = moves.whereType<AIStackMove>().toList();
```

Creates two intermediate lists when only need one or can check types on-demand.

**Recommendation:**
Use lazy iteration or check counts first before materializing lists.

---

### 🟡 Issue #10: No Memoization or Caching Anywhere

**Severity:** MEDIUM
**Impact:** Repeated expensive calculations
**Files affected:** All AI files

**Problem:**
No caching infrastructure exists. Every `_hasRoad()`, `_countThreats()`, board evaluation is recalculated from scratch even for identical board states.

**Recommendation:**
1. Implement board state hashing (based on cell contents)
2. Add LRU cache for:
   - Road detection results
   - Threat counts
   - Board evaluations
3. Consider using `package:memoize` or manual Map-based caching

---

## Performance Metrics Estimate

### Current Performance (Estimated)
- **Hard AI move time (6x6 board, mid-game):** 2-5 seconds
- **Threat counting complexity:** O(n⁴) per call
- **Board copies per 3-ply evaluation:** 500-2000+
- **GridView rebuilds per animation:** 25-64 cells

### After Fixes (Estimated)
- **Hard AI move time:** 0.2-1 second (**5-10x faster**)
- **Threat counting complexity:** O(n²) with caching
- **Board copies:** 50-200 (structural sharing)
- **GridView rebuilds:** 1-5 cells (only changed cells)

---

## Recommended Fix Priority

1. **Week 1 (Critical):**
   - Fix #3: Add caching to `_countThreats()` and early termination
   - Fix #4: Move GridView calculations outside itemBuilder, fix keys

2. **Week 2 (High):**
   - Fix #2: Combine multiple BFS calls into single traversal
   - Fix #1: Implement copy-on-write for board state
   - Fix #5: Add `.select()` to provider watches

3. **Week 3 (Medium):**
   - Fix #7: Extract duplicate pathfinding logic
   - Fix #10: Add LRU cache infrastructure
   - Fix #6: Add const to static widgets

4. **Week 4 (Polish):**
   - Fix #8: Optimize redundant road checks
   - Fix #9: Minor allocation optimizations
   - Performance testing and profiling

---

## Testing Recommendations

After each fix, measure:
1. **AI move time** - Use Stopwatch in AI classes
2. **Frame rate** - Enable Flutter performance overlay
3. **Memory usage** - Check DevTools memory profiler
4. **Build counts** - Add debug prints to widget builds

Target metrics:
- Hard AI < 1 second per move on 6x6 board
- 60 FPS during animations
- < 50MB memory usage
- < 10 widget rebuilds per user action

---

## Conclusion

The codebase has excellent architecture and clean code, but suffers from classic performance anti-patterns:
- **Excessive copying** instead of structural sharing
- **No caching** of expensive computations
- **N+1 queries** in pathfinding
- **Over-broad reactivity** in state management

These are all **fixable** with targeted optimizations. The most impactful fixes (#1-#5) could be completed in 1-2 weeks and would dramatically improve AI responsiveness and UI smoothness.
