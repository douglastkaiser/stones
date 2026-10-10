# Shared piece stacks

Updated 2026-10-10. This is an application interaction contract. Tak and Hex
retain their separate rules, move validation, ownership and carry limits.

## Audit questions and decisions

- Can Hex players see what lies beneath the controlling stone? Both boards now
  use `PieceStackView`, with up to three visible top layers and a total-height
  badge. The badge counts the entire stack, not the carry allowance.
- Does a captured stone retain its owner's theme? Each visual layer resolves
  its owner's style independently. Copper retains its distinctive palette.
  Online opponents' selected styles remain visible without unlocking them for
  the viewer. Board themes and room schemas are unaffected.
- Can hovering obscure adjacent cells or create giant stacks? Hover pauses for
  240 ms, then fans up to five top layers inside the cell. Piece type, spacing
  and height are considered together; walls and caps also fit. Inspection no
  longer rebuilds the whole square game screen or plays movement sounds.
- How do touch users inspect without their finger blocking the view? Holding
  opens the same scrollable bottom sheet as right-clicking. It remains open
  after release, has an explicit Close action, and lists every stone top first,
  with owner, type, preview status, level and controlling/buried/bottom labels.
- What if the game changes while that sheet is open? It explicitly describes
  a snapshot when opened. Inspection does not pause clocks or AI/remote turns;
  dismiss it to return to the current board. Hover renders current cell data.
- Can a selected square source still be inspected after Carry hides its top
  stones in the preview? Its full inspector shows the original stack, labelled
  "before move", even when the preview has lifted every stone. Destination
  inspectors show their on-cell preview, including half-opacity incoming stones.
- Can inspection silently place a piece or start a spread? Primary taps and
  square swipes retain their movement handlers. Pointer-down cancels the hover
  preview. Hold/right-click only inspect, including opponents' and finished
  stacks. Pending previews and the underlying board remain unchanged.
- Can quick pointer crossings or navigation leave a stale hover timer? Exit,
  pointer-down and disposal cancel it; changed stack contents reset expansion.
- Are tall stacks and large text accessible? Full lists scroll, including their
  explanatory text; geometry bounds compact/fanned layers even at tiny cell
  sizes. Count badges retain readable fixed scaling. Semantics expose an
  Inspect stack custom action and a hold/right-click hint. Shared layer
  animations respect reduced-motion settings.
- Does adding inspection break accessible cell selection? Hex merges the cell
  label, its actual tap action and explicit inspection actions into one target.
  The inspection gesture excludes its automatically generated semantics so it
  cannot mask the InkWell's tap handler. Decorative symbols do not create
  extra controls. A regression exercises semantics tap, pointer tap and hold,
  checking exact callback counts and inspector contents.
- Are tutorials/puzzles covered? They use the same board renderers. Square
  placement and spread ghosts use the same visual mapping, retaining half
  opacity and bottom-to-top order. Hex renders the supplied preview board.

## Architecture and regressions

`lib/widgets/piece_stack_view.dart` contains visual data, layer geometry and
inspection interaction. Square and Hex adapt their own pieces into visual
data. No rules or square player types were added to Hex.

`test/widgets/piece_stack_view_test.dart` covers mixed remote themes on all
three Hex radii at phone and desktop sizes with 150% text, inspection of
finished games, hover exit/click/disposal, and a 50-piece preview stack fitting
a 36px cell with full-list scrolling. Existing square gesture, online cosmetics
and Hex polygon/confirmation tests remain part of the verification.

Physical touch-device and novice-player evaluation remain useful: automated
gestures and simulated browser sizes cannot establish discoverability alone.

Release-browser trials built a real three-color Hex stack through opening
placements and covering moves, and a two-color square stack. Desktop and
390×844 checks confirmed visible buried layers, top-to-bottom inspection,
opponent-stack inspection, and returning to the same position. The square
trial inspected a source with its entire carry already lifted in preview,
closed the sheet, and successfully confirmed the existing spread.

Final verification: all 402 Flutter tests pass, strict
`flutter analyze --fatal-infos` reports no issues, and the release web build
succeeds. The corrected browser trial confirms that an occupied Hex cell has
one complete label, a single click selects Carry, spreads confirm normally,
and right-click opens inspection at phone and desktop sizes.

## Stable Hex match layout

The match screen reserves separate header and move-control docks. Their heights
are determined only by viewport width and text scale, never by selection, preview,
turn, pause, connection error or result. The board fills the remaining area, so
Carry, distribution choices and Confirm/Cancel cannot recenter or resize it.
Results, pause messages and connection errors live in the control dock. Each dock
scrolls independently when its content grows. Short screens and enlarged text
retain usable cells by scrolling the entire play surface; intentional scrolling
and window resizing can still move the board.

Widget regressions measure the same board rectangle during opening previews,
cancellation, legal turn transitions, mixed-stack selection, spread previews and
pause across all three radii, phone/desktop widths and 150% text on a small phone.

The 1280×720 desktop browser trial caught an extra 8-pixel automatic scroll from
an unnecessarily tall minimum play surface. The minimum board area is now 320
pixels, allowing standard 720-pixel desktop windows to fit without page scrolling.
Browser verification compares rendered center-cell bounds before and after a
placement preview; widget coverage includes this desktop height explicitly.

## Reliability improvements

Stack layout is calculated by `StackLayerLayout` independently of Flutter
animation and pointer state. Each visible layer contributes its own height;
rectangular cells and mixed preview orientations remain bounded. Animations key
layers by level, owner, type and preview status, preventing a replacement stone
from inheriting an unrelated layer's movement animation.

Visual pieces compare by value, including palette, theme and preview state.
Inspection keeps an immutable copy of the last displayed contents to detect
changes even when a caller mutates its list. A changed stack cancels pending hover
timers and starts a fresh dwell period; empty or single-piece stacks never fan.
Pointer tracking handles more than one active contact. An open inspector blocks
reentrant requests and hover timers; its full ordered contents are copied when
opened, independent of subsequent moves or caller mutations.

Hex match and learning boards now receive the original game alongside a move
preview. A lifted source remains inspectable even when visually empty, labelled
"before move". Destination changes are marked as preview stones with half opacity
and explicit preview descriptions, matching square preview behavior. These are
presentation changes; legal moves, ownership, turn progression and network
protocols retain their existing model validation.

New regressions cover bounded geometry over tiny/rectangular cells and 50-piece
stacks, palette changes during hover dwell, mutable-list clearing, repeated
inspection requests, stable snapshots and complete Hex source/destination preview
inspection. Movement and semantic tap/hold regressions remain required.

Reliability verification: all 418 Flutter tests pass, strict analysis is clean,
and the release web build succeeds. A 390×844 browser trial built a three-owner
stack, inspected its completely lifted source and its destination preview, then
confirmed the same move successfully. A 1280×720 trial verified the full inspector
with all three owners visible. Physical touch-device trials remain follow-up QA.
