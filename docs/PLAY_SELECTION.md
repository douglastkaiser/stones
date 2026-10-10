# Common play selection and controls

Updated 2026-10-10. These are application features, not changes to game legality.

The home screen asks **Choose your board** (Square / Hex), followed by
**How do you want to play?** (Vs Computer / Local Game / Online Game).
Tutorials & Puzzles follows the selected board. Square is the default. Returning
from setup preserves the board choice for that menu session. Continue Game and
saved online rooms remain independent resume shortcuts.

This replaces the inconsistent hierarchy where square opponent buttons sat
alongside one Hex button opening a different opponent selector. Each mode now
has one name and position regardless of shape. Setup remains progressive: the
home screen chooses intent; setup supplies size, seats/difficulty and the options
supported by that ruleset.

## UX questions and decisions

- What is the first meaningful choice? Board/ruleset, before opponents. Labels
  explain two versus three players and briefly describe the variant.
- Can switching shape accidentally replace a game? No. Chips only select setup
  routes. Existing square replacement prompts still apply.
- Can users find each mode without learning a second hierarchy? The same three
  cards and learning entry appear in the same order for both shapes.
- What does Vs Computer mean for Hex? One local human and two AIs. Local defaults
  to three local humans; Online to host plus two joining humans. Each seat remains
  editable, including AI/local/remote mixtures and observers.
- Where do friends join? Online opens host/join setup. Joining no longer clutters
  offline Hex presets; adding remote seats still permits hosting from any preset.
- Are unsupported features promised? Difficulty and Court Mode appear only in
  square descriptions; Hex describes independent seats and its variant.
- Do lessons match the selected board? Yes. Each board opens its own learning
  catalog and retains its existing progress storage.
- Does this fit mobile, desktop and enlarged text? Chips wrap, forms scroll, the
  logo scales down and the version/privacy footer wraps. Tests navigate the three
  Hex presets at 320px and 1366px with 150% text.
- Is this proven intuitive? This is a design judgment with regression coverage,
  not a novice study. Observe friends' time to start, mistaken board/opponent
  choices, host/join confusion and discovery of mixed human/AI rooms.

## Shared controls

Square and Hex use `BoardCellGestures`: taps without double-tap delay, a drag of
24 logical pixels (including initial recognition distance), or release velocity
of 100 pixels/second on either axis. Square maps to four directions; Hex projects
onto its six painted neighbor vectors. StackInspection still handles hold,
right-click and hover. Slow drags and swipes are optional shortcuts.

Hex matches and exercises now share `HexMoveSelection` and `HexMoveControls`:

1. Tap empty cell to preview; tap it again to place. Changing the empty cell
   moves the preview. Opening still exchanges flats and forbids stack movement.
2. Tap your stack to choose Carry, or swipe toward a neighbor to begin its preview.
   Source taps cycle Carry; minus/plus chooses it directly. Highlights show legal
   neighboring first steps rather than distant endpoints.
3. Drop minus/plus or repeated hand taps chooses the pending count. Swipe the
   hand forward, tap its highlighted next cell, or press Drop & next to leave
   those bottom pieces and continue straight. All here selects the remainder.
4. Confirm ends the spread, leaving all remaining pieces on the current hand
   cell, matching square. A single-stone move can also confirm with a second
   destination tap. Multi-stone swipes never auto-submit.
5. Back step merges the last step into its predecessor; tapping the source
   returns to direction selection. Cancel discards the preview; stray taps retain
   it. Every complete preview and continuation is checked by HexRules.

Complete endpoint distributions remain an advanced Hex shortcut; the visible
path is step by step. Hex seats, directions, rule versions and online protocol
remain independent. Turn/ownership/busy/finished guards apply before gesture
selection and confirmation. Fixed match controls height keeps the board anchored;
short-screen and enlarged-text layouts allow intentional scrolling.
Neighbor highlights and primary taps validate only the intended one-step moves,
avoiding exhaustive spread enumeration during routine interaction with tall stacks.

New regressions cover all six rendered quick/slow directions, preview-only moves,
two-tap placement, turn advancement and mixed-color order/revision/final crushing.
Existing tests cover square gestures, inspection and anchored Hex geometry.
Hex cells retain keyboard focus/activation, and lessons use the same Flat, Wall
and Capstone labels and reserve availability as matches.

Verification: the full 450-test suite passed serially. After adding three further
turn-lock/lesson regressions and retaining native keyboard focus, all 109 focused
interaction/layout/learning tests passed. Strict Flutter analysis reported no
issues. Release-web phone and desktop trials covered the selector, two-tap opening,
drag preview, bottom-first spread continuation, Back step and Cancel. These are
browser viewports rather than physical Android-device or novice acceptance tests.
After the neighbor-tap optimization, all 33 focused Hex controls/learning tests
passed again. Existing Play build 385 does not include this local iteration;
shipping these controls requires a subsequent signed app release.

## Design references

[Xbox guideline 112](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/112)
supports clear, consistent navigation across menus.
[Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/ensure-controls-are-as-simple-as-possible-or-provide-a-simpler-alternative/)
supports simple controls and alternatives to complex interactions. This layout
and the gesture shortcuts are our application of those principles, not a claim
that these sources mandate a particular menu arrangement.
