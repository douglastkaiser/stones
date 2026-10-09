# Three-player Hex: variant contract and implementation

This is a Stones experiment, not an official Tak ruleset. Three-player Hex is
always selectable from the main menu; it no longer requires a Settings switch.
Local Game, Online Game, Vs Computer and square results retain their behavior.
The legacy enable flag is ignored for discovery so saved preferences cannot hide
this mode. Hex tutorials and puzzles are accessible from its setup screen and
from the main Tutorials & Puzzles chooser.

## Design decisions

Use a regular hexagon of hexagonal cells, with axial coordinates `(q,r)` and
`s=-q-r`. Adjacency is through six shared sides; a stack follows a single fixed
direction vector. The geometry follows the axial/cube construction documented
in [Red Blob Games' hex grid guide](https://www.redblobgames.com/grids/hexagons/).

There are three independent seats: Ivory, Charcoal, Copper. Each owns one pair
of opposite boundaries: `q=±R`, `r=±R`, and `s=±R`, respectively. All three have
the same edge length and crossing distance under 120-degree rotations. Cells at
corners belong to both incident boundaries. The board paints each assigned
boundary in its seat color. Giving seats fixed goals makes the third player's
objective visible and keeps geometry symmetric.

Turns cycle Ivory → Charcoal → Copper. Setup chooses the starting seat. There
are no teams, elimination, or automatic alliances. Kingmaking is possible in
any free-for-all with three independent competitors; the UI does not promise
that this prototype removes it. Rotate the starter across repeated games.

### Board and supplies

| Radius | Cells | Side length | Carry limit | Stones per seat | Caps per seat |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2 | 19 | 3 | 5 | 15 | 1 |
| 3 | 37 | 4 | 7 | 25 | 1 |
| 4 | 61 | 5 | 9 | 40 | 2 |

Each seat has the same reserve. Flat and standing orientations share its stone
reserve. Carry limit is the longest row, `2R+1`, not the number of adjacent
directions or the side length. These reserve counts are provisional balancing
choices, not publisher supplies. Playtesting should compare first-seat win rate,
wall congestion, reserve-ending frequency, match length, and the larger board's
two-cap dynamics before treating them as balanced.

## Complete rules contract

1. Begin with an empty board. On each of the first three individual turns, place
   one flat of the next seat in cyclic order, consuming that seat's reserve.
   Each player gives and receives exactly one opening piece. No opening walls,
   caps, or stack movement. Opening order is independent of the chosen starter.
2. Afterwards, place your own flat, wall, or cap on an empty cell, or move a stack
   whose exposed top belongs to you. Buried colors do not control it.
3. Pick any positive number of top pieces up to the carry limit. Stack height
   itself is unlimited. Preserve order, travel straight in one of six directions,
   and drop positive counts bottom-first at every visited cell. Stop on-board;
   there is no turning, jumping, branching, or skipping a cell.
4. Flats can be covered. Walls and caps cannot. A cap alone may flatten a wall
   of any color only at the spread's final step. The flattened stone keeps its
   color. A standing stone cannot otherwise be rotated flat. A cap atop other
   carried stones does not make the entire stack eligible to crush a wall.
5. Resolve roads only after the whole move. Connect your assigned opposite
   boundaries through adjacent exposed flats/caps of your color. Walls and
   buried pieces do not connect. An opponent road exposed by your move wins for
   that opponent.
6. General simultaneous-road policy: a mover with a road wins; if only one
   opponent has a road, that opponent wins; if both opponents have roads and
   the mover does not, draw. This avoids choosing an opponent by enum/seat order.
   Fixed crossing goals constrain simultaneous paths geometrically; this policy
   is defensive adjudication rather than a claim that every combination is
   reachable in ordinary play.
7. Without a road, a full board or any seat's exhausted total reserve ends the
   match. Count only exposed flat stones of each color. A unique highest count
   wins; ties for highest draw the entire match, including two-way ties with a
   third player below them. Caps still in reserve prevent exhaustion; caps on
   the board do not count as flats. There is no secondary reserve tie-break.
8. Finished matches reject further moves. No square-game rating, clock,
   achievement, or resignation/elimination protocol is applied to this variant.
   Return to setup to configure another match. There is no silent repetition or
   no-progress draw in this version.

## Match setup and online ownership

Each of three seats independently selects:

- **Human on this device:** controlled by the host device; several seats may
  share it for pass-and-play.
- **Human joining online:** initially empty, filled by another authenticated
  device using the room code. Each joining identity fills one seat. Rejoining
  keeps its existing seat rather than consuming another.
- **AI:** an independent seat. Its turns are driven by the host.

This supports three local humans; three networked humans; two local or remote
humans plus AI; one human plus two AIs; all-AI viewing; and mixtures of local and
remote humans. A host assigning every human seat to remote devices acts as an
observer/AI runner, not an extra participant. Three filled seats are still the
total number of players.

A match waits until every non-AI seat has an owner. AI slots are already filled.
Room codes begin with `H` and contain seven letters; regular rooms retain their
existing six-letter format. Returning to setup stops local bot scheduling and
subscriptions. Online seat reservations remain, allowing the same signed-in
device to reconnect with the code. The host must remain connected to drive AI
turns. This prototype does not silently transfer bot authority or recycle an
inactive human's seat.

## Isolation and code map

- `lib/hex/hex_game.dart`: separate cells, directions, colors, pieces, reserves,
  moves, game state, and rule authority. Only `PieceType` is shared with square
  play. `HexRules.play` validates atomically and adjudicates after the full move.
- `hex_ai.dart`: bounded three-ply MaxN search through both opponents' turns,
  with four candidates per node and one score per independent seat. Evaluation
  uses assigned-edge weighted path cost and exposed flats. Native computation
  uses an isolate; browser search yields between root candidates. This is an
  initial AI, not a claim of tournament strength.
- `hex_match_provider.dart`: local play, AI scheduling/cancellation, turn/input
  permissions, online acknowledgement, and subscriptions. Screen teardown
  cancels immediately and defers provider notification until after unmount.
- `hex_room.dart`: immutable, version-1 room format and strict whole-log replay.
  Moves carry explicit seat, coordinate, piece/direction, and drops. Invalid,
  out-of-turn, post-terminal, incomplete, or unsupported logs stop replay.
- `hex_room_store.dart`: atomic Firebase transactions for create/join/append.
  Submissions require the expected ply. An ownership race retries only after a
  newly observed server ownership revision. Successful submissions wait for a
  snapshot before unlocking input, preventing optimistic duplicate moves.
- `hex_screen.dart`: setup, colored boundary markers, polygon hit testing,
  carry selection, legal endpoint/drop-distribution choices, immutable preview,
  confirmation, room sharing, results, and rules help.
- Settings/main menu changes persist and expose the flag, without switching an
  active square game's state or replacing its matchmaking provider.

## Backend contract and deployment

Hex rooms use a separate `/hexGames` collection. Square gameplay authorization
is independent; its player validation also accepts known cosmetic names. The
Hex rules require authentication, fixed version/configuration/roles,
one vacant-seat join at a time, ownership/host authority for the current turn,
and exactly one new immutable log entry. Room enumeration is denied. A room code
acts as an invitation; authenticated callers knowing it can read that room.

Rules enforce record shape, bounds, positive drops, immutable prefixes and turn
authority. The Dart engine enforces full geometry, reserves, blockers and wins
on submission and on every client's replay. Firestore rules do not implement the
full game engine; a deliberately modified client could append a shape-valid but
illegal move and cause honest clients to stop replay. A server-authoritative
move function would be the next step for adversarial/rated online play. This
experimental mode does not enter the normal rated queue.

The new collection will remain denied by an older deployed ruleset. Review and
deploy the updated rules before testing online hex rooms on production:

```sh
firebase deploy --only firestore:rules --project stones-9a6a0
```

Do not assume checked-in rules match the previously deployed rules. Review the
deployed policy before replacing it, especially existing ratings access. This
Pushing this code does not deploy backend rules or publish a new browser build;
those are separate deployment steps.

## Verification

```sh
flutter test --concurrency=1
flutter analyze --fatal-infos
flutter build web --release --base-href /stones/
node tools/serve_web.mjs
```

Hex fixtures cover all sizes/axes, six directions, rotational symmetry,
three-turn exchange for each starter, blockers and crushing either opponent's
or your own wall, piece conservation, exposed scoring/ties, opponent-only roads,
terminal replay, settings persistence, and all 27 seat-kind combinations.
Controller tests cover two-client replay, stale input, snapshot acknowledgement,
corrupt logs, consecutive AI seats, and preservation of the square game.
Widget tests cover mobile/desktop confirmation, polygon hit testing, and setup.

Backend authorization tests use real HTTP requests against a loopback Firestore
emulator and unsigned emulator identities, with no production credentials or npm
dependencies. Node 20+ is sufficient for the runner. Start the emulator with the
checked-in rules (Java and Firebase CLI required), then run:

```sh
firebase emulators:exec --only firestore --project demo-stones-hex "node --test tools/hex_rules/hex_rules.test.mjs"
```

The runner refuses non-loopback emulator addresses and always uses a demo
project. It checks authentication, malformed creation, vacant seats, joins,
human/bot turn authority, immutable logs, concurrent join conflicts, and normal
square room creation/join. The ten backend tests passed on emulator 1.19.8.
The complete Flutter suite passed all 132 tests, and strict analysis reported no
issues. The web release built successfully. The existing web bootstrap and
secure-storage dependency still produce deprecation/Wasm dry-run warnings;
the JavaScript release succeeds. The local server opens at
`http://127.0.0.1:4173/stones/` and binds only to the loopback interface.

The initial opt-in release playtest verified the setting starts off, enabling it adds
the menu entry, two local humans can play with a third-seat AI, the AI completes
the opening exchange and returns control, and a stack spread previews and
confirms with correct turn rotation. Remote multiplayer was checked against the
emulator; production rules have not been deployed.

## Follow-up playtesting

Track balance rather than changing supplies opportunistically during a match.
Future changes to goals, opening, carry limit, reserves, or tie policy require a
new room rules version so old logs remain interpretable. Additional improvements
include bot-host handoff, a room cleanup policy, consensual draw/resignation
protocols, stronger tactical AI, and larger-board touch/keyboard accessibility.

## Hex learning and visuals

`hex_exercises.dart` defines four interactive tutorials (opening exchange, six
neighbors, assigned road edges, and a mixed stack spread ending in a capstone
crush) and three one-move puzzles for Ivory, Charcoal and Copper. Solutions and
failure paths use HexRules, with no separate teaching validator for legality.
Tutorial objectives restrict accepted moves; puzzles accept legal attempts and
award completion only for the learner's victory. Hint, Retry, preview/Confirm
and Finish lesson controls support exploration. Completion persists under
`hex_learning_completed_v1`; no square achievement or match state is changed.
These are constructed teaching positions with fresh reserves, not match replays.

The reusable `hex_board.dart` retains polygon hit areas and now uses the same
five board/piece painters as square play. Copper keeps an independent visible
palette; seat symbols and assigned boundary markers remain. See THEMES.md for
visual design and migration details. Native screen-reader/device validation and
human balance studies remain separate work.

Online rooms additionally carry optional `pieceStyles` metadata by seat. The
host chooses styles for local human and AI seats; remote humans publish theirs
when reserving a seat. Rejoins and appended moves preserve all choices. Metadata
is independent of the version-1 rules log; legacy rooms default to Classic. The
board renders each top stone using its owning seat's style, including previews,
while every viewer uses the host's board material. Theme labels show samples
and unlock requirements without granting rewards. Deploy the updated Firestore
rules before production clients create/join rooms with this metadata.
