# Unified play expansion

Prepared 2026-10-10. Status: implementation plan; the deployed application still
uses the existing two-player square and three-player Hex engines. This document
supersedes the target menu hierarchy in PLAY_SELECTION.md, not its record of what
has already shipped. The user explicitly requests replacing the previous
square/Hex architectural isolation with a shared engine. Legacy rules and saved
rooms must remain interpretable throughout that replacement.

## Execution checkpoints

2026-10-10, foundation checkpoint:

- `lib/game/` now contains shared configuration, topology, immutable match state,
  atomic rules, a common move planner, reusable setup form, bounded AI search and
  a versioned mixed-seat room model. These are not routed from the deployed menu.
- The standard square adapter and seeded square/Hex comparisons verify legacy
  move application and Hex v1/v2 replay before replacing existing callers.
- Configuration coverage exercises 3,807 shape/size/control/starter combinations.
  Road fixtures cover every supported size, active seat and opposite-side pair.
- The full regression run passed 466 tests. The 25 focused setup/planner/rules
  tests and 29 additional AI/room tests passed. Strict analysis passed with no
  issues. These tests do not establish live online operation,
  tactical difficulty equivalence, frame timing or physical-device usability.
- Next: common board view/controller and persistence; then Firestore integration,
  menu replacement and progression. AI remains host-driven in the new room model;
  handoff leases are not implemented at this checkpoint. No backend rules changed.

## Product contract

Home has two primary play buttons: **Square** and **Hex**. Either opens the same
setup screen with that shape selected. Resume, Join room, Tutorials & Puzzles,
Settings and account actions remain easy to find. There is no separate Local /
Computer / Online mode selection: those are consequences of the seat choices.

Square starts with two player rows; Hex starts with three. Both support two,
three or four players. Add player is available below four; Remove player is
available above two, including on Hex. Removing a row does not silently change
another row's identity or settings. Changing shape preserves seat choices and
maps size to a valid size for the selected shape.

Each player row has one control selector: **Local human**, **Online human**,
**AI**. AI rows expose the same difficulty choices on either shape. Local humans
share this device; online humans join through an invitation. Multiple local seats
can belong to one authenticated device. All-AI games are watchable; hosts with
only online humans are observers. Start becomes Create room when a remote seat
is present. A summary describes the actual configuration before starting.

All combinations are valid: square with one local human and two AIs, square with
four online humans, Hex with two local humans, and mixed local/remote/AI seats.
There are 117 control combinations per shape across two to four seats, or 234
before multiplying by board sizes, AI difficulties and starting seats.

"Any size" initially means every currently supported size: square 3–8 and Hex
radius 2–4. No player-count restriction is attached to those sizes. Geometry and
configuration should be extensible; arbitrary enormous boards are not promised
before their supplies, layouts and search costs are evaluated. Small four-player
boards are playable variants, not a promise of balanced competition.

## Inspection findings

- Square Piece / PlayerColor / GameResult / GameState encode white and black,
  named reserves and one opponent. Adding enum entries alone will not work.
- HexGame rejects reserve counts other than three; turn rotation, opening,
  scoring, MaxN vectors, room seats and rendering enumerate HexSeat.values.
- Square GameSessionConfig chooses local/vsComputer/online before seats; Hex
  already selects control per seat. Both controllers schedule AI differently.
- BoardCellGestures and PieceStackView already share recognition/rendering.
  Square UIState and HexMoveSelection still implement different move planners.
- Square rooms use white/black fields and notation. Hex rooms use three indexed
  seat maps and versioned coordinate moves. Firestore policies fix both formats.
- AchievementNotifier.recordWin accepts coarse online/difficulty booleans and
  has no match-result identity; replaying completion can count it again.
- Square and Hex learning use independently verified catalogs. Their proofs
  must not be silently applied to another seat count or rules profile.

## Shared model and responsibilities

Use a small shared domain under lib/game/, with concrete value types rather than
parallel SquareGame and HexGame copies:

| Component | Responsibility |
| --- | --- |
| MatchConfig / SeatConfig | Shape, size, rules profile, ordered active seats, starter, seat control and AI difficulty |
| SeatId | Stable identity within a match; unrelated to Firebase UID or paint color |
| BoardGeometry | Valid cells, ordered directions, step, adjacency, opposite boundaries, carry limit |
| SquareGeometry / HexGeometry | Only topology and coordinate-to-screen/hit-test differences |
| Stone / Stack / Reserve | Seat ownership, piece kind, immutable bottom-first stack operations and supplies |
| MatchState / MatchResult | Board, ply, reserves by seat, active turn, terminal result and reason |
| RulesProfile / MatchRules | Versioned opening/supplies/end conditions; one atomic placement/spread validator and road/scoring resolver |
| MoveSelection | One carry/drop/continuation/revision preview state machine using MatchRules |
| MatchController | Confirm, history, turn authority, AI lifecycle, cancellation, recovery and result events |
| RoomRepository | Transactional create/join/append/resume with explicit revision and owner identities |
| MatchScreen / MatchSetupScreen | One set of controls, player rows, help, status, results and responsive layout |
| BoardView | Shared cell/stack composition with a geometry-specific layout and hit-test implementation |

Domain code must not depend on Flutter widgets, Firestore or account state.
Rendering consumes domain state; networking serializes moves; AI uses the same
validator and result resolver. Avoid abstracting every method into an interface:
geometry, rules profile and storage are the actual variation points.

Legacy adapters decode old square and Hex states/logs into a compatible shared
representation. Existing public APIs may temporarily forward to it while callers
migrate. They must not become another permanent engine. Delete replaced planners,
controllers and screens after parity gates pass. Keep legacy wire codecs as long
as saved rooms need them.

## Rules proposals to implement and evaluate

These are application variants. Only two-player square standard Tak follows the
publisher contract. New multiplayer square and variable-seat Hex use an explicit
versioned free-for-all profile; UI help identifies it as a Stones variant.

1. Turn order cycles the configured active seats from the selected starter.
   Opening lasts one individual turn per seat. Each places the next seat's flat,
   consuming that seat's reserve. Everyone gives and receives exactly one piece.
   With two seats this matches the normal opening exchange.
2. All colors can road across any pair of opposite boundaries. Square uses its
   two pairs; Hex uses its three. No diagonals on square and no assigned colors.
3. Placement, top ownership, positive bottom-first drops, straight movement,
   capstone blocking and lone-cap final-step wall crushing share one validator.
   Shape supplies directions and carry limit, not another movement algorithm.
4. Resolve after the complete move: mover road wins; otherwise one opponent road
   wins; multiple opponent roads without a mover road draw. Never select a winner
   by list order. Roads take priority over terminal flat scoring.
5. A full board or any exhausted total reserve ends a non-road match. Only exposed
   flats score. One highest count wins; any highest tie draws the match.
6. Begin with current per-seat supplies for each size, equally allocated to every
   seat. Keep standard two-player square counts exact. Treat multiplayer counts
   as provisional; record congestion, exhaustion, duration and starter advantage
   before changing them. A supply change creates a new rules profile/version.
7. No teams or elimination in this expansion. Do not silently interpret a seat
   removal during setup as in-game removal. Multiplayer resignation needs an
   explicit UI/result contract: initially terminate as an abandoned match without
   win rewards rather than arbitrarily choosing one of several opponents.
   Two-player resignation retains its established opponent-win meaning.
8. Coaching/takebacks remain explicit practice options. Online takebacks require
   participant agreement and an authoritative revision; never undo only locally.
   Clock expiry for multiplayer needs the same explicit termination contract.

Existing Hex v1 assigned goals and Hex v2 three-seat shared goals retain their
original semantics. New games do not reuse either version identifier for changed
seat counts, supplies or endings. Old square logs retain standard square meaning.

## Pieces, themes, achievements and identity

Use four stable seat appearances: Ivory, Charcoal, Copper and Jade. Names/colors
are presentation metadata, not ownership identifiers. Every one of the existing
five themes must render all four seats, all three piece kinds and buried layers.
Do not add more themes to accommodate another player. Preserve Classic's bought
game appearance for the first two seats. Jade needs a distinct symbol as well as
color, readable against every board material and in hover/hold previews.

The host still owns the board theme. Each human account owns its selected unlocked
piece theme, visible to all viewers regardless of their unlocks. Host selections
apply to AI and shared-device guest seats. Account progression belongs to the
signed-in identity, never automatically to every local seat on that device.

Publish a terminal MatchCompleted event with stable match ID, result revision,
winner, rules profile, shape, seats, participants, human control and assistance
flags. Reward processing must be idempotent across resume, replay and duplicate
snapshots. Preserve existing unlocks and scenario completion IDs. General win
rewards may accept supported variants; specialist rewards must check their actual
conditions. An all-AI result, observer session, draw or assisted practice cannot
grant a human competitive win. Existing AI-difficulty awards retain their earned
meaning; do not equate the current weaker Hex search with Expert square strength.
Define new multiplayer AI award eligibility explicitly and test mixed difficulties.

Standard two-player square ratings remain separate until a multiplayer rating
model is designed. The room's existence alone does not imply a rated match.
Catalog-wide learning rewards must use versioned collections, so adding lessons
does not revoke an already earned unlock or falsely complete a new catalog.

## Networking and recovery

New unified rooms use a new versioned format/collection rather than rewriting
existing /games or /hexGames documents. Store immutable configuration, stable
seat IDs, host, kinds/owners/styles, rules version, move revision and result.
The same protocol supports either shape and two to four seats.

Join is transactional: claim one vacant online seat; rejoin recovers an existing
seat; a shared-device owner can control several configured local seats. Move
append requires the expected revision and current-seat owner or AI authority.
Reject stale, duplicate, illegal and post-terminal submissions. Resume validates
the log through the same engine and retains the last valid prefix on corruption.
Apply only appended moves on ordinary updates; reconstruct once on cold recovery.

Use one room recovery route, one invite/join UI and one saved-room list. Persist
local matches too, including mixed/all-AI configurations. A closed browser must
not destroy a room. Disconnect shows retained board plus clear authority status;
cached state must not imply that an online move was accepted. Firestore
transactions fail offline: confirmation needs a visible failed/retry state.

AI host handoff is explicit lease/revision work: only one runner may publish each
AI move. Prefer a participant lease that can be reclaimed after host disconnect,
with cancellation of the previous runner. An observer-only host with no connected
replacement still leaves AI paused and the room recoverable. Do not claim fully
server-authoritative legality: client replay and access rules cannot enforce the
entire game engine against a modified client.

Emulator tests precede publishing new Firestore rules. Preserve user/achievement
permissions and old room access. Backend release and client release are separate
steps; deploy backward-compatible backend support before new clients create rooms.

## Ordered implementation milestones

Each milestone is a reviewable change; do not expose combinations before their
engine, controller, rendering and storage are actually ready.

1. **Baseline and contracts.** Capture current standard/legacy fixtures, setup
   defaults, measured gesture/search timings and saved progress. Record accepted
   variant rules, seat identities and codec versions. Completion: replay fixtures
   and acceptance matrix committed, with current behavior passing.
2. **Shared configuration and setup.** Introduce shape/seat configuration and the
   reusable seat-row form with add/remove, starter and per-AI difficulty. Test
   two/four limits, shape switches, mobile layout and all 234 kind combinations.
   Route existing supported configurations through adapters during migration;
   do not ship inert Add player buttons. Completion: one form, no mode-specific
   setup dialogs, and every exposed start action produces a valid configuration.
3. **Shared engine.** Implement topology and seat-based immutable state, common
   rules, supplies and terminal adjudication. Differentially replay standard
   square and legacy Hex against old engines. Exercise all sizes, directions,
   starters and seat counts plus conservation and rotational/reflection checks.
   Completion: standard parity and independently checked multiplayer results.
4. **Shared planner and rendering.** Migrate gestures, legal adjacent highlights,
   carry/drop preview, Confirm/Cancel/Back step, inspection and keyboard input to
   one implementation. Add Jade to all five themes and player summaries. Keep
   board position stable through status/planner changes. Completion: the same
   widget regressions run for both geometries and two to four players.
5. **Shared local controller and AI.** Move history, saving, cancellation,
   turn locks and result events into one controller. Use minimax for two players
   and seat-vector MaxN for three/four within one search framework; share move
   generation, evaluation features and budgets. Validate every difficulty on
   either shape, consecutive bots, all-AI pause/resume and navigation disposal.
   Completion: all local configurations playable and recoverable without jank.
6. **Shared online protocol.** Add codecs, transactional rooms and compatible
   access rules. Test concurrent joins/appends, mixed ownership, themes, cold
   recovery, missing host, stale AI lease and terminal replay. Trial two to four
   independent clients against emulator, then an isolated live room. Completion:
   no duplicate moves, no lost room and no unauthorized seat control.
7. **Progression and learning.** Migrate result-driven achievements idempotently;
   preserve existing cosmetics/progress. Port catalogs through legacy adapters,
   add variable-seat tutorials and prove new multiplayer puzzle studies against
   all opponent responses. Completion: no automatic win farming, duplicate
   rewards or invalid puzzle certificates under changed rules.
8. **Replace old routes and remove duplication.** Home becomes Square / Hex;
   tutorials use the same match shell. Remove superseded GameMode branching,
   setup widgets, planners/controllers and duplicated rule/search code. Retain
   only versioned compatibility codecs/profile behavior needed for saved games.
   Completion: changing seat count adds no new gameplay screen or mode provider.
9. **Playability/performance release gate.** Run full Flutter tests and fatal-info
   analysis, emulator policy tests, release web and signed Android builds.
   Verify phones, desktop, enlarged text, low-end hardware, friends' join/resume
   journey and standard-game parity. Release backend, web and closed-test app in
   that order; check deployed versions and preserve rollback compatibility.

Dependencies: 1 precedes all work; 2 and 3 define the common contract; 4 and 5
require 3; 6 requires stable engine/controller; 7 requires result events; 8 requires
playable replacement paths; 9 gates shipping. This is a substantial engine and
protocol migration, not a dropdown-only patch.

## UX and performance acceptance questions

Second execution checkpoint: the shared board and controller are implemented for
both shapes and two through four seats. Widget checks cover mobile/desktop board
stability, enlarged text, stack themes, and placement gestures. Local moves are
saved before appearing on the board; room moves wait for server acknowledgement.
Unified room bookmarks use the existing recovery list and account guard. The
new `/matches` security policy is a draft, with a CI emulator suite covering all
178 online seat configurations; it has not been published to production. Main
menu replacement, AI host handoff, progression, learning, and release gates are
still pending.

Third execution checkpoint: all 178 online mixes and exclusive, server-timed AI
leases pass the real Firestore emulator policy suite. Home now opens one seat
editor from its Square and Hex buttons; new play and both learning catalogs use
the shared match board/controller/planner. Court hints, explanations and durable
takebacks work on both shapes. All 17 existing puzzle certificates were
independently re-proved using the shared engine, and their sample lines pass the
new learning controller. Six opening-cycle lessons cover both shapes with two,
three and four seats. Competitive win counting has a single-write ledger and
stable result identity to prevent repeat awards after restart; shared-device
guests, observers and assisted practice are excluded. Specialist AI unlocks are
temporarily withheld for new matches pending search-strength parity validation.
Existing unlocks and legacy learning completion IDs are retained. Clock parity,
new multiplayer tactical studies, compatibility cleanup, live backend publishing
and the performance/release gate remain pending. No new production rules or
web/app deployment has happened in this migration yet.

Clock checkpoint: both shapes and two through four seats now share clock banks.
Local clocks pause on leaving and checkpoint remaining time; terminal time results
survive cold resume. Online clocks debit a completed run from its two acknowledged
server timestamps when that seat next starts, rather than trusting a client's
estimate of the current request time. Rules require server timestamps and enforce
the active seat's deadline; any participant may claim a real timeout. A two-seat
timeout awards the opponent; a multiplayer timeout abandons the match without win
rewards. The clock label ticks independently of the board. Model/controller checks
pass; the expanded timed-room emulator checks are still pending.

Recovery checkpoint: the timed-room emulator suite passes after replacing
repeated per-seat initial-clock checks with equivalent map key/value checks,
avoiding Firestore's 1,000-expression ceiling for four-seat creation. Shared AI
tactical regressions pass for every difficulty/shape/seat count and for the
standard three-by-three forced fork. Web searches now receive cancellation from
the controller. Timed local/room recovery rejects missing or mismatched clocks.
Online submissions reconcile with a server read if the listener misses their
acknowledgement; uncertain writes lock input until explicit reconnect. The shared
screen exposes reconnect and resignation. Two-player resignation awards the
opponent; multiplayer resignation abandons without a winner. These endings are
durable across restart. The 51 focused controller/clock/screen checks and strict
analysis pass. Broader search-strength, performance, compatibility cleanup and
production release gates remain open.

Learning/interaction checkpoint: the shared AI now screens actual legal immediate
wins by the next seat before pruning root moves, avoiding a MaxN positional move
that permits an immediate loss. All 50 road-win/block/fork checks pass. Eight new
three/four-seat cap-delivery studies span Square 5/6 and Hex radius 2/3; exhaustive
one-move proofs establish one winning spread per position, verify piece supplies,
and reject incorrect shortcuts in the learning controller. They have separate
versioned progress IDs. Existing 17 certificates still prove unchanged. Learning
opens with the objective visible and offers an objective toolbar action. Setup
uses saved board/clock preferences and asks before replacing an unfinished local
save. Shared gameplay restores themed move/flatten/result sounds. Distant taps
use a bounded straight-path preview rather than enumerating all distributions;
interactive drop revision still provides other distributions. Tall-stack planner,
settings/replacement, responsive screen and strict analysis checks pass. No
production deployment has occurred yet.

Compatibility checkpoint: old square `GameRules` and Hex `HexRules` are now
facades over the shared validator, move generator and scoring. The old square
provider consumes shared road/flat results, removing its separate BFS. Adapters
retain old colors, supplies, turn conventions, result labels and Hex v1 assigned
goals. The previous independently implemented differential checks passed before
this replacement; their current form verifies compatibility conversion rather
than independence. Invitation entry and saved-room recovery use one dispatcher,
including old six-letter Square and seven-letter H-prefixed Hex invitations.
Legacy screens/controllers are retained for old online documents until their
wire lifecycle can be fully adapted; new configurations never route through them.
Focused official-rule/compatibility/certification and win/recovery checks pass.

Release-mode browser evidence at 7e83417: four-player Hex setup, preview,
repeat-tap placement and page-reload recovery retain the board, next turn and
reserves. The board DOM rectangle remained x=173/y=198/498×498 through preview
and acknowledgement. The browser's viewport override did not change its measured
844×884 viewport, so those observations do not establish phone-browser layout;
320/390-pixel and enlarged-text layouts have widget-test evidence. Release web
build passed. Physical-device timings, live independent clients, final full
regressions and production publishing are still pending.

- Can someone start the requested mix without knowing an internal mode name?
- Is board shape the main choice, with clear size and total player count?
- Can they tell which humans share a device and which need an invitation?
- Is all-AI/observer play explained, and are filled seats visible before start?
- Do seat removal and shape switching preserve deliberate setup choices?
- Are all four colors identifiable without color vision or theme knowledge?
- Are turn, waiting, saving, offline, AI thinking and result states distinct?
- Do tapping, repeated tapping, slow dragging, swiping, hold/hover and keyboard
  behave identically on either shape, including puzzles and online games?
- Does the board stay anchored when player labels, explanations or controls grow?
- Can a host or guest close the page, return and recover exactly the same state?
- Can stale clients or two AI runners accidentally submit the same turn?
- Are retries/takebacks explicit, and can a pending move be duplicated?
- Are earned unlocks preserved and new awards attributed to the right account?
- Does a new rules version invalidate neither old rooms nor verified studies?

Profile release/profile builds, not debug timings. Target smooth 60 Hz interaction
(about 16.7 ms per frame), with no synchronous AI search or exhaustive spread
enumeration in build/tap handlers. Measure p95 gesture-to-preview latency with a
target under 50 ms on representative devices; report actual measurements before
claiming it. Benchmark all supported sizes with two/three/four seats and tall
mixed stacks. Keep AI cancellable and time-budgeted, using isolates on native and
cooperative yielding on web. Repaint/rebuild only affected cells and relevant
status; cache geometry and small derived data by board revision. Avoid adding a
framework or dependency solely to achieve reuse. Monitor web bundle, startup,
memory and recovery time against the baseline.

UI matrix includes 320/390 px phones, short landscape, tablet/desktop, 150/200%
text, touch/mouse/keyboard, long player names and four-seat waiting rooms. Physical
Android and independent live clients are separate evidence from viewport tests.

References: [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)
supports keeping costly repeated work out of build; [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
documents retries and offline failure. Architecture and numerical performance
targets above are project design choices, not requirements from those sources.
