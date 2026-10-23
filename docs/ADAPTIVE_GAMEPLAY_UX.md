# Adaptive gameplay UX

This implements the mobile gameplay handoff's compact roster and move controls,
plus the selected landscape board/sidebar and overview/precision-zoom design.
Game rules, supported match configurations, saved games and network messages are
unchanged. This is engineering validation, not an A+ usability-study result.

## Layout and interaction contract

- Portrait keeps a safe-width board, capped at 760 logical pixels. Temporary
  controls never determine its size. Short screens can scroll.
- Landscape and desktop use a board beside the controls when the available
  space accommodates a 224-pixel board and a panel measured from scaled action
  text. Otherwise they use the portrait arrangement. Landscape deliberately
  fits the whole board to available height; precision zoom provides larger cells.
- Player tiles show reserves, clocks and a non-color current-player marker.
  Tapping a tile opens its details. Narrow app bars group secondary commands.
  During play, audio settings live in the toolbar/menu instead of floating over
  the move buttons; leaving the match restores the app-wide audio button.
- Confirm, Cancel and spread Undo stay outside the scrolling content. Undo also
  remains available after minus removes the last destination. Pickup/current-drop
  minus/plus, next-drop guidance and Drop remaining sit immediately above them. This compact
  section can scroll at large text sizes or with a keyboard; the expanded stack
  inspector stays in secondary content and uses the available height.
- A fit view provides an overview. Zoom in initially targets a 48-logical-pixel
  inscribed cell diameter, calculated from the actual square/hex polygons.
  Maximum zoom grows with board density; it is not tied to today's presets.
- Two fingers navigate; ordinary taps and controlled-stack drags play. Explicit
  Pan or Space-drag supports a mouse. Navigation cannot stage or confirm moves,
  including when a second finger joins an active stack drag. Fit and Return to
  play remain available in the app bar even when the board tools have scrolled.
- Web accessibility cell elements carry stable identifiers and use polygon clips
  matching `BoardLayout`. This prevents overflowing semantic label text from
  intercepting neighboring touches. Browser trials assert the topmost DOM hit
  target before tapping, as well as the resulting saved position.
- Rotation preserves the draft and normalized board focus. Keyboard cell focus
  reveals its cell at the current zoom. Starting a different match resets view.

`MatchTableLayout` adds optional move-dock, board-tools and height-aware controls
slots. `BoardViewportController` owns presentation-only zoom and focus state;
`BoardView` exposes a cell-focus callback. Existing engine contracts are retained.

The [2026-10-23 stack control revision](STACK_INTERACTION.md#piece-depth-and-simultaneous-controls-2026-10-23)
adds source-tap pickup cycling and temporary hold-to-expand inside the board,
while keeping the persistent tray and stable viewport. The measurements below
remain evidence for the original adaptive-layout revision, not new measurements
of these added interactions.

## Measured before/after

The same six-tap task selects a three-stone stack, stages a drop, undoes it,
stages again, drops the remainder and confirms. Measurements use both shapes,
two/four players and normal text. Baseline is commit `e6c2319`. Scroll counts
are test calls needed to reveal otherwise untappable controls, not measured
human gestures. Visible height is the board rectangle intersecting its viewport,
not the sum of playable polygon areas.

| Viewport / seats | Visible board height during carry, before → after | Task scrolls, before → after |
| --- | --- | --- |
| 320×568 / 2 | 296 → 312 | 3 → 0 |
| 320×568 / 4 | 250 → 264 | 3 → 0 |
| 390×844 / 2 or 4 | 390 → 390 | 1 → 0 |
| 844×390 / Square | 166 → 310 | 3 → 0 |
| 844×390 / Hex | 266 → 310 | 4 → 0 |
| 1366×900 / 2 or 4 | 760 → 760 | 0 → 0 |

Portrait board dimensions remain 320/390, and desktop remains 760. Landscape's
board side changes from 760 (mostly scrolled out) to a fully visible 310. Small
portrait screens can still require board scrolling, particularly with four
players or enlarged text; the improvement does not depend on shrinking them.

## Reproducing validation

Validation used Flutter 3.47.7 / Dart 3.13.5. The full suite passed 1,624 tests,
including the 571-case layout matrix. After visual review added the inline audio
command and web semantic-cell clips, all 45 affected interaction/audio tests
passed again. Strict analysis and the release web build passed. The 16 widget
capture trials passed for both the baseline and changed layouts.

All 16 release-browser journeys passed: Chromium 151.0.7922.34 with touch input
and Firefox 153.0 with mouse input, each covering both shapes at 320×568,
390×844, 844×390 and 1366×900. No page errors were recorded. These isolated
profiles serve the renderer files bundled with the build locally, avoiding
proxy certificate differences on the renderer CDN. Six web release-packaging
checks also passed. Safari/WebKit could not be run on this host because required
system libraries are unavailable.

The native Android debug APK also built successfully (470 Gradle tasks) using
Temurin JDK 21.0.12.1 and Android Build Tools 35.0.0. It is generated at
`build/app/outputs/apk/debug/app-debug.apk`. This host initially needed a full JDK,
SDK packages and the system proxy CA trust; the final build used two Gradle
workers and a 1536 MB heap. No Android device was attached, so this is compilation
and packaging evidence, not a native interaction trial. Validation logs are
retained under `build/qa/adaptive-validation/` in this workspace.

Use the project's Flutter SDK and dependencies, then run:

```sh
flutter analyze --fatal-infos
flutter test
flutter test test/game/adaptive_capture_test.dart --dart-define=STONES_CAPTURE_STACKS=true
flutter build web --release
node tools/serve_web.mjs
# In another terminal, with Playwright browsers installed:
STONES_BROWSERS=chromium,firefox python tools/adaptive_browser_probe.py
flutter build apk --debug
```

The layout suite covers every current board size, both shapes, two to four
players, 100/150/200% text, phones/tablets/landscape/desktop, and breakpoint
neighbors. Interaction regressions cover safe insets, keyboard appearance,
rotation during a draft, pinch/pan cancellation and returning to play. Synthetic
geometry tests include square sizes through 80 and hex radii through 20, without
adding these as playable match presets.

Capture PNGs and measured JSON are generated under `build/qa/stacks/`. Browser
journeys produce screenshots and versioned results under
`build/qa/adaptive-browser/`; they test placement, spread/Undo, zoom, rotation,
pinned confirmation and saved-game reload in isolated local contexts. They
block production backend requests. Generated evidence is not committed.
To reproduce the baseline comparison, copy `adaptive_capture_test.dart` into a
clean worktree at `e6c2319` and run the same capture command there.

## Release qualification still required

Run hands-on trials on physical Android Chrome and iPhone Safari, plus the native
Android app. Record device/OS/browser versions, browser toolbar collapse/expand,
notches and gesture navigation, rotation, keyboard appearance, and enlarged
text. Verify VoiceOver/TalkBack focus order and announcements. Desktop browser
viewport checks and an APK build do not qualify these behaviors.

Before assigning an A grade, have at least six players complete placement,
inspection, multi-cell spread, Undo/Cancel and recovery from a mistaken gesture
on both shapes. Record completion, accidental moves, assistance, scrolls/taps
and comments. Resolve observed blocking issues and repeat affected tasks.
