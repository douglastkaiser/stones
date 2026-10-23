# Stack inspection and movement

Introduced 2026-10-19 in the shared `lib/game/` play path for Square and Hex,
including shared learning screens; the current contract includes the 2026-10-23
piece-depth and control revision. This is an application interaction change;
Tak rules, Hex variant rules, room records, and confirmed-move storage are preserved.
The [research and proposal](STACK_INTERACTION_RESEARCH.md) records the precedents
and the problems found in the previous controls.

## Interaction contract

- Tap an owned stack to inspect it and select its maximum legal top portion.
  A repeated tap on the source takes one fewer stone, wrapping from one back
  to the maximum. Minus/plus and layer selection remain available alongside taps.
  Tap an opponent's stack to inspect it without beginning a move. Inspection also works when input is
  locked or the match is finished.
- The persistent tray lists stones top first, preserving their owner and piece
  theme. A continuous selection border identifies carried stones. Rows distinguish
  top/bottom, taking/carried, staged, and stays-here states. A separate next-drop
  row shows the bottom carried stone even when it is below the visible list.
- Select a layer to take it and everything above it. Minus/plus provides large,
  discrete controls. Carry selection respects the geometry's carry limit and is
  locked once drops begin; undo or remove the drops to change the pickup.
- Expand makes the ordered list taller; every stone remains scrollable. Inspection
  and expanded controls use their own scroll areas. The board's size and position
  do not depend on a selection, carry count, route, inspection, or expansion.
- Tap a highlighted neighbor to stage exactly one bottom stone. Tap the current
  cell to stage another there; tap the highlighted next cell to continue straight.
  Each staged cell displays its added count and actual resulting top owner.
- The preview source contains only the stones left behind. Carried stones live
  in the tray and a carrying-count marker, rather than appearing settled on the
  last destination. The next target is labeled “Drop 1” where cell size permits;
  its outline differs from the source selection.
- Current-drop minus/plus controls remain active alongside taps. Plus stages
  another bottom stone at the current destination; minus returns one to hand.
  Removing its final stone removes that destination and returns to the previous
  one, or to pickup selection if no drops remain. Completed drafts remain editable.
  Each adjustment uses the shared rule preview and can be undone, including the
  removal of the last destination. Changing pickup quantity clears old drop
  history so Undo cannot restore a spread made with a different hand.
- Drop remaining here stages the entire hand on the current destination. Undo
  reverses the last action, including a batch drop. Cancel restores the
  original board. Off-path and blocked taps preserve the draft and explain the
  straight-line, board-edge, wall, or capstone constraint.
- Inspect another stack temporarily routes the next board tap to inspection.
  Back to carried stones restores the source tray without changing the draft.
  Hold fans up to five top layers in place until release or cancellation,
  including the original source layers while stones are carried. Changes to
  displayed or original inspection layers reset expansion. Empty cells retain
  their existing tap recognition; hold expansion only registers for a stack.
  Holding a stack never changes the draft.
  Right-click and accessible Inspect stack open the persistent tray; legacy
  boards retain their existing modal fallback. Hover remains an optional bounded
  view of top layers.
- A drag shows an offset carried-stack ghost and target feedback while moving.
  Release stages one bottom stone on the adjacent cell in that direction. The
  remaining hand stays available for taps or another drag from the current cell.
  A release never submits a turn. Sustained multi-cell auto-dropping is deferred,
  as proposed, until the basic flow has been evaluated.
- Confirm move is available only when the hand is empty and the entire move is
  legal. Further taps never auto-submit a spread, including a one-stone spread.
  Placement retains its existing preview/second-tap confirmation behavior.
- A new match position clears stale selection, route, and inspection, even if its
  ply number is unchanged. Connection, seat ownership, clock, study, busy, and
  finished-state guards still gate movement and submission. Inspection does not
  pause the game or clocks.

## Architecture

`MatchRules.previewSpread` lifts an explicit top portion and applies a prefix of
bottom-first drops, returning the staged position, remaining hand, or a specific
failure reason. `MatchRules.apply` uses this same transformer for complete spreads.
Neither path advances the turn or resolves roads; `play` still does that once,
when a complete move is committed. A draft requires no enumeration of complete
spread distributions and introduces no separate UI wall/cap legality rules.

`MoveSelection` owns the source, carry, fixed direction, drop prefix, revision
history, inspection target, and feedback. Its `planned` getter exposes placements
or complete spreads only. `preview` renders an incomplete draft without depositing
an implicit remainder. Coaching suggestions use `choose` to load a complete,
revisable draft.

`StackMoveTray` adapts the real seat/theme painters to the ordered tray.
`BoardView` renders staged counts, source/target distinctions, the route and live
pointer feedback. `BoardCellGestures` reports displacement during a drag as well
as at release, preserving the previous slow-drag and fling recognition thresholds.
`StackInspection` can delegate to the nonmodal tray while preserving legacy callers.
`MatchScreen` keeps the next-drop stone, draft actions and confirmation outside
the independently scrolling stack contents. Responsive docks reserve their height
from the viewport before a stack is selected, keeping the board stationary.
The isolated design sample uses the same planner, renderer and stack tray.

## Verification and evaluation

`test/game/move_selection_test.dart` covers both shapes and two to four seats:
actual carried/staged colors, 2 → 1 distribution, individual and batch revision,
source reselection, carry limits, all movement directions, inspection, stray taps,
blocked walls/caps/edges, final lone-cap crushing, placement, and coaching drafts.

`test/game/stack_interaction_test.dart` exercises the actual match screen on phone
and desktop in light/dark themes. It covers layer selection, count controls,
inspection during a spread, exact previews, undo, batch drop, explicit confirmation,
live ghost movement in four/six directions, semantics taps, hold, cancellation,
connection loss, same-ply position replacement, completed-game inspection, and
30-piece stack scrolling on a 320px screen at 200% text. Hit-test misses are fatal
in this suite. Board bounds are compared across normal draft/inspection changes.
`test/game/stack_badges_test.dart` also checks that owner, staged-count, next-target
and carried-count labels fit completely inside clipped cells on tiny/large
Square boards (3/5/8) and Hex boards (radius 2/3/4), using the actual bundled font.
Existing shared match, stack inspector, legacy gesture, study and rule tests remain
part of the full suite.

Capture the actual screen fixtures with:

```sh
flutter test --dart-define=STONES_CAPTURE_STACKS=true test/game/stack_interaction_test.dart
```

Images are written under `build/qa/stacks/` and are local QA artifacts.
Automated gesture checks and simulated viewports do not establish novice
comprehension or physical-device performance. The research note's uncoached
mixed-stack, pickup-boundary, spread-revision, and cap-crush tasks remain the
acceptance questions for real players.

## Execution evidence (2026-10-19)

- The shared rules/planner changes passed the full 926-test suite.
- The final dock, responsive layouts, inspector and clip-safe badges passed 88
  focused widget checks. A final 22-test gesture/capture run also passed after
  the guidance copy was made explicit.
- Strict `flutter analyze --fatal-infos` is clean. The release web build succeeds
  with the repository-pinned Flutter 3.47.7.
- The compiled real application passed four isolated browser trials: Square and
  Hex at 390×844 with touch and 1366×900 with keyboard activation. Each replayed
  a legal local history, staged a 2 → 1 spread without saving partial drops,
  confirmed exactly one move, reloaded it, and inspected an opponent's stack.
  These trials produced no page errors. Runtime assets were allowed and backend
  requests were blocked; this is local-play evidence, not new online qualification.
- `build/qa/stacks/` contains phone/desktop, light/dark, pickup/carry/spread and
  enlarged-text captures, the repeatable browser probe, logs and a source-hashed
  `verification.json`. These generated artifacts stay outside version control.

Physical devices and uncoached new players remain the next usability evaluation.

## Piece depth and simultaneous controls (2026-10-23)

Shared painters now give every theme bounded side faces, beveled face lighting
and contact shadows. Existing ornaments, owner colors and piece identities remain.
The interaction updates above apply to shared Square/Hex matches and learning;
legacy hold inspectors retain their existing behavior. No room/save migration or
rule change is required. Source-tap cycling intentionally replaces the previous
repeated-source no-op contract.

Regression requirements: PLAY-02–05 and PREF-04–05; mixed board/button pickup and
drop, zero-drop removal and undo, cap-crush restoration, hold/release/cancel,
legacy inspection, unchanged board bounds, reduced motion and enlarged text.
Initial implementation verification on Linux with Flutter 3.47.7 / Dart 3.13.5,
before the pre-commit audit repairs below:

- All 1,778 tests pass with `flutter test --no-pub`, including the new hold,
  pickup/drop adjustment and history regressions, legacy inspectors, shared
  studies, rule previews, enlarged-text layouts and connection/position guards.
- `flutter analyze --no-pub --fatal-infos` reports no issues; the production
  `flutter build web --no-pub` succeeds. The build still reports existing
  secure-storage Wasm incompatibility and Cupertino font warnings; this check
  qualifies the default JavaScript web build, not Wasm.
- A focused capture run passed 61 planner/interaction checks and generated 26
  phone/desktop, light/dark and enlarged-text images in `build/qa/stacks/`.
  The theme visual suite also generated `build/theme-contact-sheet.png`; the
  all-theme rendering and representative game captures were visually reviewed.
  Artifacts are local QA output, not tracked source or deployed release evidence.
- No new browser-runtime, online multi-client, physical-device, screen-reader,
  performance or unfamiliar-player acceptance was performed for this revision.
  Reduced-motion behavior retains the existing shared layer animation guard;
  bounded painting and hover/inspection compatibility are covered by widget tests.

### Pre-commit documentation and regression audit (2026-10-23)

Reviewed the final diff, current feature list, AGENTS.md/CLAUDE.md, development
and handoff instructions, current help, theme/viewport contracts and historical
movement proposals. Current summaries now precede historical control records;
the current handoff and release record distinguish this audited source revision
from prior AI work and publication authorization.

An added failing widget regression reproduced stale hold expansion when original
inspection layers changed while a lifted source preview stayed empty. The reset
now compares both layer lists. Additional checks exercise removing every drop,
restarting in another direction and undoing back to the original route, plus
holding/moving/releasing and right-click inspection during a staged draft.

A second failing regression proved that hold-end/cancel callbacks on empty cells
consumed their existing long-held taps. All hold callbacks now share the same
nonempty-stack guard, preserving empty-cell placement recognition. The earlier
in-progress full run was stopped after this finding; the final full run validates
both fixes together.

Final checks on the unchanged candidate pass: all **1,784** tests with
`flutter test --no-pub --concurrency=2`; all **99** focused planner, gesture,
viewport, legacy-inspector and visual checks; strict analysis with no issues;
and the default JavaScript production web build. Dart formatting and diff
whitespace checks are clean. The earlier 1,778-test result above qualifies the
initial revision, not these follow-up repairs.

The [source-bound audit record](qa/stack-controls-verification.json) stores the
base commit, hashes of all eight changed Dart files, commands/results, expected
before-fix failures, log digests and web artifact digest. Local logs are under
`build/qa/stack-controls-audit/`; generated artifacts remain outside version control.
The documentation audit checked current feature/instruction contracts and local
link targets, while retaining historical reports as dated evidence. The same
browser/device/performance acceptance limits listed above remain open. At
qualification time, no commit, push, publication or new Android release had been
performed. The owner subsequently authorized committing and pushing the audited
source to main; hosted CI and deployment remain separate qualification stages.
