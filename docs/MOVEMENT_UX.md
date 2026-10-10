# Movement interaction review

This is an application interaction contract, not a change to Tak or Hex rules.
Read TAK_RULES.md and HEX_MODE.md for legality. Square preview, gameplay and AI
continue to share GameRules; Hex remains isolated in HexRules.

## Questions for each iteration

- Can a first-time player identify which stack they control and what is buried?
- Do they understand that Carry takes the top pieces, but drops the bottom first?
- Can they choose a count directly without discovering repeated taps?
- Does a highlighted cell describe what will happen on the next action?
- Can a deliberate slow drag work without a fast release?
- Can holding to inspect coexist with dragging and scrolling on a short screen?
- Is the direction fixed and understandable after the first step?
- Can they tell how many stones remain and which square receives the next drop?
- Can they finish on the current square without tapping through every count?
- Can they revise one step or cancel without changing the real board or clock turn?
- Will a stray tap silently erase the plan or unexpectedly place a stone?
- Is Confirm always discoverable, and enabled only for a legal whole move?
- Do wall crushing, board edges and blocked paths offer a clear next action?
- Can keyboard and screen-reader users operate the same visible controls?
- Do controls stay reachable at 320px, in landscape, and with enlarged text?
- Do tutorial constraints, AI turns and remote ownership still gate submissions?
- Does three-player Hex explain its six directions and distribution choices?

## First square revision

1. Tap an owned stack. Carry minus/plus selects top stones within its height and
   the board carry limit. Repeated source taps remain a shortcut.
2. Tap a highlighted adjacent square, or drag toward it. The first action opens
   a preview. Direction highlights show first steps rather than distant endpoints.
3. Drop minus/plus chooses the count on the hand square. All here selects the
   remaining stones. Drop & next advances exactly one square when a legal full
   continuation exists. Tapping the hand or next square remains a shortcut.
4. Confirm is visible throughout planning and enabled for a legal full spread
   when all remaining stones are selected. Single-stone tap-to-confirm remains
   available, alongside the explicit button.
5. Back step restores the previous drop; at the first square it returns to Carry
   selection. Cancel discards the preview. Off-path taps preserve it. Tapping an
   earlier path square can still revise that step.

The immutable board changes only when a complete move is submitted. Planning
does not pause the clock. Pointer displacement supports slow releases; holding
opens a scrollable inspection sheet, which is intentional. Hover fans bounded
layers in both modes; see [the stack display contract](STACK_DISPLAY.md). Wrap layouts and
scrollable controls keep actions available on narrow screens and large text.

## Further work to evaluate

- Show the actual carried colors/types in bottom-first order, particularly for
   mixed stacks; count labels alone do not explain every tactical consequence.
- Replace generic blocked-state feedback with specific wall/cap/edge reasons
   derived from the rules authority, not duplicated UI legality logic.
- Consider directional buttons for players who cannot accurately select small
   squares, and an optional assisted spread workflow. Measure before expanding
   the primary controls further.
- Hex currently selects an endpoint and a complete numeric drop distribution,
   rather than a square-by-square hand. Evaluate a six-direction step planner
   separately; do not transplant square direction or player state into Hex.
- Evaluate novice sessions for mis-taps, time to first spread, cancellations,
   mistaken drop order, and wall-crush comprehension. Automated coverage and
   developer trials cannot establish novice intuition.

## Regression coverage

Rendered widget tests exercise count buttons, intermediate drops, Back step,
stray taps, cancellation, piece order and atomic confirmation at mobile/desktop
sizes with 150% text. Pointer tests cover stationary slow releases horizontally
and vertically, quick swipes, blocked walls and a final capstone crush. Model
tests check actionable highlights and legal multi-step continuations.

Release-browser trials used a real local match to build a mixed-color stack,
change Carry, plan a 2 → 1 spread, revise it with Back step and confirm. The
result preserved bottom-first order and advanced the turn once. Preview controls
were visually checked at 390×844, 320×568 and 1366×768. These are simulated
viewports, not physical-device or novice-user acceptance tests.

Verification: all 244 tests passed, strict `flutter analyze --fatal-infos`
reported no issues, and the release web build succeeded. A temporary compiler
copy failed when disk space ran out; removing this session's generated caches
allowed the full verification to complete. No Firebase configuration changed.
