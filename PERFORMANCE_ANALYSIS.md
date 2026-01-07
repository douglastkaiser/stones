# Performance Analysis Report - Stones (Tak Board Game)

**Date:** 2026-01-07 (Updated)
**Original Analysis:** 2025-12-13
**Analyzed by:** Claude Code
**Codebase:** Flutter-based Tak game with AI opponents

---

## Executive Summary

This analysis covers **Web Performance Metrics** (Lighthouse: LCP/CLS/INP) and **Mobile Performance** (frame render times, memory). Identified **10 major performance issues** across AI algorithms, state management, and UI rendering. The most critical issues cause **O(n⁴) complexity** in AI move evaluation and **exponential board state copying**.

**Status Update:** Performance optimizations have been implemented:
- ✅ Board analysis caching added (`lib/services/ai/board_analysis.dart`)
- ✅ Early termination in threat counting implemented
- ✅ GridView optimization - pre-computed flags, RepaintBoundary added
- ✅ Board state copying - copy-on-write O(n) per call
- ✅ Web: Preconnect hints, deferred Firebase, fade transition
- ✅ Granular provider selectors in main_menu_screen

Estimated performance improvement after all fixes: **2-10x on Hard AI difficulty**, with noticeable improvements during move evaluation and game rendering.

---

## Web Performance Metrics (Lighthouse Analysis)

### Largest Contentful Paint (LCP)

**Target:** < 2.5 seconds | **Current Estimate:** 3-5 seconds

**Hotspots:**
| Issue | File Location | Impact |
|-------|---------------|--------|
| Firebase SDK loading | `web/index.html:132-151` | External dependency blocks rendering |
| Google Fonts loading | `lib/main.dart:62,70` | Render-blocking font fetch |
| Large Flutter bundle | `build/web/main.dart.js` | ~2-4MB JavaScript bundle |
| No preconnect hints | `web/index.html` | DNS/connection latency |

**Proposed Fixes:**

1. **Add preconnect hints** - `web/index.html` (before line 59):
   ```html
   <link rel="preconnect" href="https://fonts.googleapis.com">
   <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
   <link rel="preconnect" href="https://www.gstatic.com" crossorigin>
   <link rel="preconnect" href="https://firebasestorage.googleapis.com">
   ```

2. **Defer Firebase Analytics** - `web/index.html:132-151`:
   - Move Firebase initialization to after `runApp()` completes
   - Use `requestIdleCallback` for non-critical analytics

3. **Font loading optimization** - `lib/main.dart:62,70`:
   - Consider using `font-display: swap` for Google Fonts
   - Or bundle a subset font with the app

### Cumulative Layout Shift (CLS)

**Target:** < 0.1 | **Current Estimate:** 0.05-0.15

**Hotspots:**
| Issue | File Location | Impact |
|-------|---------------|--------|
| Loading spinner removal | `web/index.html:89-91` | Abrupt content shift when app loads |
| Dynamic board sizing | `lib/main.dart:3051-3055` | Layout recalculation on LayoutBuilder |
| Player chip avatar | `lib/screens/main_menu_screen.dart:1063-1068` | Image load causes shift |

**Proposed Fixes:**

1. **Reserve space for loading transition** - `web/index.html`:
   - Add fade transition instead of abrupt `display: none`
   - Pre-reserve viewport height for Flutter canvas

2. **Fixed board dimensions** - `lib/main.dart:3051`:
   - Calculate board dimensions once and cache
   - Use `AspectRatio` widget to prevent recalculation

3. **Avatar placeholder** - `lib/screens/main_menu_screen.dart:1085-1094`:
   - Always show placeholder while avatar loads
   - Use fixed dimensions for CircleAvatar

### Interaction to Next Paint (INP)

**Target:** < 200ms | **Current Estimate:** 150-400ms

**Hotspots:**
| Issue | File Location | Impact |
|-------|---------------|--------|
| AI move computation | `lib/services/ai/lookahead_ai.dart:34-77` | Blocks main thread during search |
| GridView rebuild | `lib/main.dart:3089-3189` | All cells rebuild on state change |
| Procedural painters | `lib/widgets/procedural_painters.dart:112-161` | Heavy paint operations |

**Proposed Fixes:**

1. **Isolate AI computation** - `lib/services/ai/lookahead_ai.dart:34`:
   ```dart
   // Move AI computation to isolate
   Future<AIMove?> selectMove(GameState state) async {
     return compute(_selectMoveIsolate, state);
   }
   ```

2. **Optimize GridView** - `lib/main.dart:3089`:
   - Extract expensive calculations before `itemBuilder` (see Issue #4)
   - Use `const` cell keys without timestamps

3. **Cache procedural painters** - `lib/widgets/procedural_painters.dart`:
   - Render textures once to `ui.Image` and reuse
   - Use `RepaintBoundary` around painted widgets

---

## Mobile Performance Profiling (Frame Render Times & Memory)

### Frame Render Times

**Target:** < 16.67ms (60 FPS) | **Current Estimate:** 20-80ms during interactions

**Profiling Commands:**
```bash
# Enable performance overlay
flutter run --profile --trace-skia

# Capture timeline
flutter screenshot --type=skia
flutter drive --profile --trace-startup --trace-skia

# DevTools profiling
flutter run --profile
# Open DevTools Performance tab
```

**Hotspots:**
| Issue | File Location | Frame Impact |
|-------|---------------|--------------|
| GridView.builder rebuilds | `lib/main.dart:3089-3189` | 25-64 cell rebuilds = 30-50ms |
| CustomPainter repaints | `lib/widgets/procedural_painters.dart` | 5-20ms per texture |
| Animation state changes | `lib/main.dart:3113-3127` | Triggers full tree rebuild |
| Provider state mutations | `lib/providers/*.dart` | Over-broad dependency tracking |

**Proposed Fixes:**

1. **RepaintBoundary usage** - Wrap expensive widgets:
   ```dart
   // lib/main.dart - around _BoardCell
   RepaintBoundary(
     child: _BoardCell(...),
   )
   ```

2. **Memoize cell widgets** - `lib/main.dart:3154-3188`:
   - Create cell widgets outside `itemBuilder`
   - Store in `List<Widget>` and index by position

3. **Batch animation updates**:
   - Use `TickerProviderStateMixin` for coordinated animations
   - Avoid per-cell animation controllers

### Memory Usage

**Target:** < 100MB | **Current Estimate:** 80-200MB

**Profiling Commands:**
```bash
# Memory snapshot
flutter run --profile
# DevTools Memory tab → "Take Heap Snapshot"

# Track allocations
flutter run --profile --observe-all

# Leak detection
flutter pub run leak_tracker
```

**Hotspots:**
| Issue | File Location | Memory Impact |
|-------|---------------|---------------|
| Board state copying | `lib/models/board.dart:156-166` | n² objects per copy |
| AI move evaluation | `lib/services/ai/lookahead_ai.dart` | 500-2000 GameState copies |
| Procedural textures | `lib/widgets/procedural_painters.dart` | Uncached paint operations |
| Sound manager pools | `lib/services/sound_manager.dart` | Audio buffer retention |

**Proposed Fixes:**

1. **Structural sharing for Board** - `lib/models/board.dart:156`:
   - Replace `setStack()` with persistent data structure
   - Only copy modified rows, not entire grid

2. **Object pooling for AI** - `lib/services/ai/`:
   - Pool `GameState` and `Board` objects
   - Reset and reuse instead of creating new

3. **Texture caching** - `lib/widgets/procedural_painters.dart`:
   ```dart
   // Cache rendered texture as ui.Image
   static final Map<String, ui.Image> _textureCache = {};
   ```

4. **Dispose sound buffers** - `lib/services/sound_manager.dart`:
   - Release unused audio pools after inactivity
   - Implement LRU eviction for sounds

---

## Flutter-Specific Profiling Setup

### Enable Performance Metrics

Add to `lib/main.dart` for debugging:
```dart
import 'dart:developer' as developer;

void main() {
  // Enable frame timing
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      if (timing.totalSpan.inMilliseconds > 16) {
        developer.log(
          'Slow frame: ${timing.totalSpan.inMilliseconds}ms '
          '(build: ${timing.buildDuration.inMilliseconds}ms, '
          'raster: ${timing.rasterDuration.inMilliseconds}ms)',
        );
      }
    }
  });

  runApp(const ProviderScope(child: StonesApp()));
}
```

### Widget Rebuild Tracking

Add rebuild counters for debugging:
```dart
class _GameBoardState extends State<_GameBoard> {
  static int _buildCount = 0;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    developer.log('_GameBoard.build() #$_buildCount');
    // ... rest of build
  }
}
```

### Memory Profiling Markers

Add allocation tracking:
```dart
// In board.dart
Board setStack(Position pos, PieceStack stack) {
  developer.Timeline.startSync('Board.setStack');
  try {
    // ... implementation
  } finally {
    developer.Timeline.finishSync();
  }
}
```

---

## Critical Issues (Fix Immediately)

### 🟢 Issue #1: Exponential Board State Copying

**Severity:** CRITICAL | **Status:** ✅ FIXED - Copy-on-write implemented
**Impact:** Every move evaluation triggers dozens to hundreds of full board copies
**Files affected:**
- `lib/models/board.dart:156-172` - `setStack()` now uses copy-on-write
- `lib/services/ai/move_generator.dart` - Called in simulation loops
- `lib/services/ai/lookahead_ai.dart:278,296` - Called in `_applyStackMove()`

**Fix implemented:** Copy-on-write semantics - only copies the modified row, shares unchanged rows. Reduces O(n²) to O(n) per modification.

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

**Severity:** CRITICAL | **Status:** ✅ Partially Fixed
**Impact:** 4 separate breadth-first searches per neighbor evaluation
**Files affected:**
- `lib/services/ai/board_analysis.dart:118-148` - `getReachableEdges()` now combines BFS
- `lib/services/ai/board_analysis.dart:195-232` - `evaluateChainExtension()` uses single BFS

**Improvement:** The `BoardAnalysis` class now includes `getReachableEdges()` which finds all reachable edges in a single BFS traversal, and caching has been added for road detection results.

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

**Severity:** CRITICAL | **Status:** ✅ Improved with Caching & Early Termination
**Impact:** Every threat check simulates placing pieces on ALL empty cells
**Files affected:**
- `lib/services/ai/board_analysis.dart:164-191` - `countThreats()` with early termination
- `lib/services/ai/lookahead_ai.dart:144-146` - Uses `maxCount: 3` for early exit

**Improvement:** The `BoardAnalysis.countThreats()` now has:
- Road detection caching (reduces redundant BFS)
- Early termination via `maxCount` parameter (stops after finding N threats)
- The AI uses `maxCount: 3` which is sufficient for fork detection

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

### 🟢 Issue #4: GridView Rebuilding All Cells on Every Animation

**Severity:** HIGH | **Status:** ✅ FIXED - Pre-computed flags + RepaintBoundary
**Impact:** All 25-64 cells rebuild on any state change
**Files affected:**
- `lib/main.dart:3046-3067` - Pre-computed animation flags
- `lib/main.dart:3165` - RepaintBoundary wraps each cell

**Fix implemented:**
- Animation state flags pre-computed before itemBuilder (lines 3046-3067)
- Each cell wrapped in RepaintBoundary to isolate repaints
- Calculations now O(1) per cell instead of repeated per cell

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

### Completed ✅
- Fix #2: Single BFS traversal in `BoardAnalysis.getReachableEdges()`
- Fix #3: Caching + early termination in `BoardAnalysis.countThreats()`
- Fix #7: Extracted pathfinding to shared `BoardAnalysis` class
- Fix #10: Road cache infrastructure added

### Priority 1 (High Impact - Next Steps)
| Fix | File | Estimated Effort |
|-----|------|------------------|
| #4: Move GridView calculations outside itemBuilder | `lib/main.dart:3033-3044` | 2-4 hours |
| #1: Copy-on-write Board state | `lib/models/board.dart:156` | 4-8 hours |
| Web: Add preconnect hints | `web/index.html` | 30 minutes |

### Priority 2 (Medium Impact)
| Fix | File | Estimated Effort |
|-----|------|------------------|
| #5: Granular provider selectors | `lib/main.dart`, `lib/screens/*.dart` | 2-4 hours |
| Web: Defer Firebase analytics | `web/index.html:132-151` | 1-2 hours |
| Mobile: Add RepaintBoundary | `lib/main.dart:3154` | 1-2 hours |

### Priority 3 (Polish)
| Fix | File | Estimated Effort |
|-----|------|------------------|
| #6: Add const to widgets | Throughout codebase | 2-3 hours |
| #8: Redundant road checks | `lib/services/ai/lookahead_ai.dart` | 1-2 hours |
| Web: Loading transition | `web/index.html:89-91` | 1 hour |
| Mobile: Texture caching | `lib/widgets/procedural_painters.dart` | 2-4 hours |

---

## Testing Recommendations

### Web (Lighthouse)
```bash
# Build for production
flutter build web --release

# Serve locally
cd build/web && python -m http.server 8080

# Run Lighthouse CLI
npx lighthouse http://localhost:8080 --output=html --output-path=./lighthouse-report.html

# Key metrics to track
# - LCP: Target < 2.5s
# - CLS: Target < 0.1
# - INP: Target < 200ms
# - Total Blocking Time: Target < 300ms
```

### Mobile (Flutter Profiling)
```bash
# Run with profiling
flutter run --profile

# Capture performance trace
flutter screenshot --type=skia --observatory-uri=<uri>

# In DevTools:
# 1. Open Performance tab
# 2. Click "Record" then perform actions
# 3. Review flame chart for slow frames

# Target metrics
# - Frame build time: < 8ms
# - Frame raster time: < 8ms
# - Total frame time: < 16.67ms (60 FPS)
```

### After Each Fix, Measure:
1. **AI move time** - Use Stopwatch in AI classes
2. **Frame rate** - Enable Flutter performance overlay
3. **Memory usage** - Check DevTools memory profiler
4. **Build counts** - Add debug prints to widget builds

### Target Metrics:
| Metric | Target | Current Estimate |
|--------|--------|------------------|
| Hard AI move time (6x6) | < 1 second | 1-3 seconds |
| Frame rate | 60 FPS | 30-50 FPS during interactions |
| Memory usage | < 100MB | 80-200MB |
| Widget rebuilds/action | < 10 | 25-64 cells |
| LCP (web) | < 2.5s | 3-5s |
| CLS (web) | < 0.1 | 0.05-0.15 |
| INP (web) | < 200ms | 150-400ms |

---

## Conclusion

The codebase has excellent architecture and clean code. Several performance improvements have already been implemented:

### Completed Improvements ✅
- **Road detection caching** - `BoardAnalysis._roadCache` eliminates redundant BFS
- **Single BFS traversal** - `getReachableEdges()` replaces multiple `_canReachEdge()` calls
- **Early termination** - `countThreats(maxCount: 3)` stops searching after finding enough threats
- **Shared utilities** - `BoardAnalysis` class consolidates pathfinding logic

### Remaining Issues ⚠️
- **Excessive copying** - Board state still copies O(n²) per modification
- **GridView rebuilds** - Calculations still inside `itemBuilder`
- **Over-broad reactivity** - Provider watches trigger unnecessary rebuilds
- **Web loading** - Missing preconnect hints and deferred analytics

### Expected Impact
After implementing remaining Priority 1 fixes:
- **AI performance:** 2-5x faster on Hard/Expert difficulty
- **UI smoothness:** 60 FPS consistently during animations
- **Web LCP:** Reduced to < 2.5 seconds
- **Memory usage:** Reduced by 30-50%

The most impactful remaining fixes (#1 Board copying, #4 GridView optimization) could be completed in 1-2 days and would dramatically improve both AI responsiveness and UI smoothness.
