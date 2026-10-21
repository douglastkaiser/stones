# Mobile gameplay UX follow-up

Updated 2026-10-21. This is a handoff for a later environment, not a request to
implement these proposals as part of the current layout fix.

## Baseline to preserve

The current assessment is **B overall**, up from approximately **C−** before the
repair. This is an engineering/design judgment based on widget tests and browser
captures, not a measured usability-study score.

Square and Hex now share width-based portrait sizing (safe width, capped at 760
logical pixels, with the existing 12-pixel internal drawing margin). Primary
Confirm/Cancel and inspection actions remain outside the scrolling content and
above the bottom safe area. Desktop retains its board/sidebar arrangement.
Secondary controls use their natural height and scroll when needed.

Do not restore the old shape-specific sizing exception, guessed control-height
budget, or a requirement that every phone layout have zero scroll extent. Keep
board dimensions independent of transient controls. The user's chosen fallback
is full-width boards with pinned primary actions, accepting scrolling on short
screens. Any alternative that shrinks the board should be a deliberate product
decision, not a side effect of fitting controls.

## Priorities for the next iteration

1. **Reduce vertical overhead on small phones.** At 320×568, the full-width board
   cannot fit above the action area alongside the current player/status header.
   Investigate compact player/reserve/clock presentation and remove repetitive
   turn wording (for example, “Ivory’s turn · Ivory to play”). Preserve access to
   all players and essential game state. Compare how much of the board is visible
   before and after the change; do not achieve improvement by shrinking cells.
2. **Make stack moves require less scrolling.** Carry selection, drop guidance,
   Undo and Drop remaining currently live in scrollable secondary content while
   Confirm stays pinned. Prototype a compact move panel near the board or action
   area. Keep the carried count, next drop and draft status understandable, and
   make Undo easy to reach. Do not pin the entire expanded stack inspector and
   crowd out the board. Compare scrolls and taps needed to complete, undo and
   cancel a multi-cell spread.
3. **Improve grouping on taller phones.** There can be a large gap between the
   board/secondary controls and the bottom action row. Explore a clearer visual
   relationship between the pending move and its actions while preserving their
   predictable location and the full-size board. Avoid filling space with extra
   decoration or instructions solely to eliminate blank space.
4. **Qualify real mobile behavior and accessibility.** Test actual Android Chrome
   and iPhone Safari where available, plus the native Android app if in release
   scope. Cover browser toolbar expansion/collapse, notches, gesture navigation,
   orientation changes, keyboard appearance and increased text size. Exercise
   touch scrolling versus board dragging, focus order, screen-reader labels and
   announcements. Record actual devices, OS/browser versions and limitations.

These are investigation/prototype directions. The compact header and move-panel
interaction design still need to be chosen and assessed; this document does not
claim that a specific redesign has already been validated.

## Acceptance scenarios

- Both shapes, two to four players, and smallest/largest boards; local play,
  online waiting/reconnection, learning and completed matches.
- 320×568 and 390×844 phones, portrait tablet/browser, short landscape and desktop;
  100%, 150% and 200% text; bottom and side safe-area insets.
- Place a stone, change its type, confirm and cancel; inspect either player's
  stack; select a carry, stage multiple drops, undo, inspect during a draft,
  return to the draft, confirm and cancel; expand and scroll a tall stack.
- Primary actions remain fully visible and tappable without scrolling to them.
  Secondary controls remain reachable. No clipped controls, obscured targets,
  layout overflow, accidental moves caused by scrolling, or draft loss on resize.
- Verify board dimensions and rendered cell bounds, not just the absence of
  Flutter overflow exceptions. Preserve existing Hex geometry and gesture tests.
- For any usability improvement, record representative before/after captures and
  the interaction cost of the same tasks. Conduct hands-on task trials before
  claiming an A-grade experience.

## Starting points and existing evidence

Start with `lib/game/match_table_layout.dart`, `lib/game/match_screen.dart`, and
`lib/game/stack_move_tray.dart`. Review repository instructions and the shared
play contract before changing behavior. No game-rule, persistence or network
changes are needed for this UI follow-up.

The current regression matrix is in `test/game/community_layout_test.dart`;
stack interaction and learning tests live alongside it. The matrix passed 130
cases. Eight real Chromium viewport checks covered both shapes at 320×568,
390×844, 768×1024 and 1366×900, including tapping confirmation. Strict analysis
and the release web build passed. Full-suite findings and targeted rerun results
are recorded in `docs/COMMUNITY_AND_LAYOUT.md`.

Captures were generated under `build/qa/layout-browser/` in the implementation
environment. Build artifacts and temporary logs are not committed and may not be
available in another environment. Regenerate evidence there; do not treat
viewport emulation as physical-device qualification. Physical-device checks and
production deployment were not performed as part of this fix.
