# Tak rules and implementation audit

Reviewed 2026-10-08 against the complete publisher rulebooks, not just a rules
summary. This document records the implementation contract and remaining work;
it is not a reproduction of either rulebook.

## Sources and scope

- [University Edition rules](https://crabfragmentlabs.com/s/UniversityRules.pdf),
  all six pages: setup, pieces, victory, movement examples, strategy, match
  scoring, and the optional University gambling variant.
- [Tak Companion Book core rules](https://crabfragmentlabs.com/s/TakCoreRules.pdf),
  all eight PDF pages: the fuller explanations and worked movement examples.
- [US Tak Association rules](https://ustak.org/play-beautiful-game-tak/), including
  its board-size table, and [terminology](https://ustak.org/tak-terminology/).

The publisher texts agree on core play. University pages 2–4 specify:
an empty board; two opening placements of opposing flats; subsequent placement
only on empty squares; ownership determined by a stack's top; straight,
orthogonal movement; a carry limit equal to board width; preserved piece order
with positive bottom-first drops; unlimited stack height; and a lone capstone
flattening either color's wall at the final step. Walls otherwise remain upright.
Capstones cannot be covered.

The Companion Book's victory section (printed page 4) specifies roads joining
opposite edges, with top flats and capstones participating. Walls and diagonal
connections do not participate. Check the completed move: simultaneous roads
award victory to its mover, while an opponent-only road awards the opponent
victory. Without a road, a full board or either exhausted total reserve ends play.
Only exposed flats score; equal scores draw. Caps, walls, and buried pieces do
not score. Remaining caps therefore prevent an otherwise empty stone reserve
from ending play.

### Supplies per player

| Board | Ordinary stones (flat or standing) | Capstones |
| --- | ---: | ---: |
| 3×3 | 10 | 0 |
| 4×4 | 15 | 0 |
| 5×5 | 21 | 1 |
| 6×6 | 30 | 1 |
| 7×7 | 40 | 2 |
| 8×8 | 50 | 2 |

The publisher tables omit 7×7 and explicitly say it has no standard in those
editions. Stones follows the USTA's 40-stone/two-cap convention for that size.
Ordinary stones share one reserve irrespective of orientation.

### Customs and optional modes

University pages 2 and 5 recommend choosing the first person randomly, then
alternating starters. Calling “Tak” is courtesy, not compulsory. Optional match
scoring awards a winner the board area plus their unplayed pieces; it is separate
from a game's flat count. Page 6's wagering system is explicitly a variant and
is outside Stones' current scope. Physical portability and strategy advice add
no move-validation requirements.

Stones uses White as the first seat. That convention works when the starter is
assigned that seat, but repeated games should alternate people. There is no
base-rule requirement here for komi, a move clock, automatic repetition draws,
or a no-progress counter. If introduced, expose these as explicit variants or
match settings rather than silently changing default results. Undo, Elo ratings,
AI difficulty, puzzles, cosmetics, and achievements are application features.

## Implementation and evidence

The changes from this audit address disagreements between the app's separate
validators. The authoritative move transformer is now `GameRules`; it returns
an immutable state before turn advancement and victory evaluation, or null for
an invalid move. The notifier applies history and side effects only after success.

| Area | Implementation | Regression evidence |
| --- | --- | --- |
| Supplies/opening | `GameState.initial`, `GameRules.tryPlacePiece` | Every supported size; opposing colors/reserves; rejected opening walls, caps, movement |
| Normal placement | `GameRules.tryPlacePiece` | Empty-square/bounds checks; shared wall reserve; last ordinary stone with a cap remaining |
| Stack movement | `GameRules.tryMoveStack` | Carry bound, ownership, positive drops, order, tall stacks, bounds, blockers, unchanged reserves/history on failure |
| Wall flattening | Shared transformer and preview | Both wall colors, multi-step lone-cap finish, blocked multi-piece arrival, wall as endpoint |
| Road outcome | `GameStateNotifier._checkWinCondition`, `BoardAnalysis.getRoadWinner` | Both colors' double roads; opponent-only road; road priority on reserve exhaustion |
| Flat outcome | `GameRules.flatResult`, notifier and AI | Board-fill/reserve triggers; ties; top flats only; finished AI returns no move |
| AI legality | `MoveGenerator`, lookahead application | Generated moves accepted by gameplay on opening and representative/scenario boards |
| Gesture planning | `UIState` and `GameScreen` | Rendered illegal adjacent-wall swipe and legal spread continuation from an empty hand square |

Relevant tests: `test/models/game_rules_test.dart`,
`test/providers/win_detection_test.dart`, `test/providers/ui_state_test.dart`,
and `test/widgets/stack_gesture_test.dart`.

The new examples reproduce the publisher's five-piece spread and the capstone
spread that leaves the opponent controlling the intermediate stack. Those cases
test piece order and exposed control, rather than only checking move acceptance.

### Corrections made

- AI opening simulation now places the opposing color and consumes that reserve.
- Gameplay, generated spreads, and preview destinations use the same legality
  rules. A capstone above other carried pieces cannot flatten an adjacent wall
  until it is alone; previews no longer depict that illegal flattening.
- Illegal/out-of-bounds/finished-state moves leave history and state unchanged.
- Continuing a preview swipe works when its hand square was originally empty
  or controlled by the opponent.
- The opening tutorial says the exchange reduces first-player advantage rather
  than claiming it eliminates that advantage.
- Rendered tests exposed a disposed Riverpod reference and insufficient control
  height. The screen retains its notifier for cleanup, and the controls have
  enough vertical space for the tested move planner.

The preceding win-detection upgrade also corrected mover priority for double
roads and flat draws in gameplay and AI evaluation.

## Remaining audit findings

Core move and result behavior has regression coverage. This is not a claim that
online matches, all puzzle journeys, or AI tactical strength are fully verified.
The following are code-inspection findings requiring follow-up work.

### Online correctness — high priority

`lib/providers/online_game_provider.dart` and `lib/main.dart`:

1. `_applyNotation` does not validate the recorded player against the current
   turn or the notation pickup prefix against the sum of drops. Shared rules
   reject illegal geometry, but replay needs its own record-integrity checks.
2. `_syncMovesWithLocalGame` advances its applied count to the entire remote log
   even after a failed replay. It should retain the last successfully applied
   prefix and report the failure. Test malformed moves followed by valid moves.
3. Online undo is offered before an opponent replies, but the screen's undo
   path changes local state without updating the remote log. Implement a
   coordinated takeback protocol or remove that action from online play.
4. Remote resignation/result status is not projected into the local game result
   by move replay. Check input locking and result display on both clients.
5. Rematch resets to waiting while retaining occupied seats. Check both clients'
   restart transitions and alternate the starting person across rematches.
6. Clocks use local timers, and timeout/result propagation needs a server-backed
   reconciliation design. Verify delayed clients, reconnects, and simultaneous
   timeout/move delivery.

Use a Firebase emulator or an isolated test project and two clients. Do not
declare these resolved based on the local model tests.

### Puzzle completion — high priority

The screen's achievement/completion paths accept any finished game as completion,
as well as completion of a guided step. A puzzle loss or draw needs evaluation
against that scenario's actual objective before unlocking progress. Existing
scenario tests inspect metadata and generated moves; they do not replay every
scripted sequence through its completion and failure paths.

### AI strength and ratings — separate application work

- The 2026-10-09 [playability audit](PLAYABILITY_AUDIT.md) corrected the AI search
  convention: fixed-perspective minimax and ordering for the side to move.
  Hard/Expert forced-fork fixtures and seeded full matches cover this correction.
  Blocking by affected-square overlap remains a heuristic, not proof that a
  threat was prevented. Legal-move tests do not establish tactical quality.
- Rating updates can originate from both clients and lack match-based
  idempotency. The checked-in Firestore rules do not allow the ratings collection;
  deployed rules were not inspected. Verify one rating update per completed match
  and authenticated access using emulator tests.

### Maintenance

Road traversal remains in both the provider and AI analysis. Keep their outcome
tests aligned, or consolidate traversal in a later change. Optional multi-game
scoring is not implemented; Elo is not a substitute for that scoring system.

## Validation record

See `docs/DEVELOPMENT.md` for commands and architecture. The audit adds model,
provider, and rendered gesture regressions. Final verification results are
recorded there. No live Firebase session or Android device was used for this audit.
