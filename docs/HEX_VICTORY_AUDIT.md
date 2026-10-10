# Hex victory and shared-goals audit

Reviewed 2026-10-09 after `21532.jpg` and the user's decision to make all colors'
objectives symmetric. This is an application variant, not official Tak.

## Reported position and decision

The radius-2 screenshot shows a continuous Ivory road from `(0,-2)` around
the left to `(-2,2)`. Those cells reach both `r=+/-2` boundaries. **This is an
Ivory win under the new shared-goals rule**, regardless of which side pair it uses.
The old version-1 rules only allowed Ivory to cross `q=+/-2`, so the original
client did not award it a road win. That contract failed the user's expected
Tak-like symmetry; new games now use version 2.

Every color may connect A to A (q), B to B (r), or C to C (s). Roads use only
adjacent exposed flats and caps of a single color. A corner touches both
incident sides; adjacent sides alone are insufficient. No road is assembled
from disconnected groups touching different boundaries.

The screenshot fixture reconstructs all visible tops, heights and reserves.
Buried colors are unreadable and use an inventory-consistent assignment.
Road detection depends only on exposed tops, so that uncertainty does not
affect the win diagnosis. Exposed flat counts are 7-6-4, but roads take priority.

## Implementation and UX

- HexRules checks every eligible axis; gameplay, previews, replay and both AI
  execution paths share its complete-move adjudication.
- AI path evaluation minimizes cost across all permitted pairs.
- Shared A/A, B/B, C/C boundary markers use a palette independent of seat
  colors. A persistent caption explains that any color can use any pair.
- Existing online rooms retain their immutable version-1 goals, colored seat
  markers, a Legacy room caption, and matching help text. Joining, appending,
  serialization and incremental replay preserve/check that version.
- New online rooms use version 2. The published Firestore rules accept versions
  1 and 2 while retaining authentication, seat ownership and immutable metadata.
- Tutorials teach shared goals. All seven Hex puzzles have fresh IDs and
  regenerated exhaustive certificates; both two-move puzzles remain genuinely
  two-move problems against every legal defense by both opponents.
- Roads precede flat scoring. A mover with a road wins a simultaneous result;
  a sole opponent road wins for that opponent; two opponent roads without the
  mover draw. Parallel roads are possible under shared goals.
- Board labels reserve space and do not intercept cell input. The short-phone
  layout scrolls rather than squeezing the board below its required height.

## Verification

The screenshot is a road-win regression. Tests cover every color on each pair
at radii 2-4, caps, walls and buried pieces, simultaneous parallel roads,
controller termination before bots, and legacy room compatibility. An independent
connected-components oracle uses cube-distance adjacency and explicit coordinates
rather than the road finder's traversal. It checks 1,800 varied positions across
all board radii. Native and responsive AI tests take wins on every shared pair.
Full Flutter tests, strict analysis and release build results are recorded in
the task report; mobile and desktop views are inspected on the rebuilt browser.

## Further playtesting

Shared goals intentionally change tactics. First-seat advantage, parallel-road
frequency, two-opponent kingmaking and larger-board wall congestion still need
human playtests; the implementation does not claim balanced competitive play.
Firestore validates room authority and move shape, not a server-side board
simulation. Ratings/history remain separate from this experimental variant.

Final automated verification: 392 Flutter tests passed, including exhaustive
proofs for all 17 square/Hex studies; `flutter analyze --fatal-infos` reported
no issues. The AI cost regression compares 432 seat/position evaluations with
an independent relaxation algorithm under both rule versions. All-AI trials
finished at radii 2, 3 and 4. The bucket optimization reduced the same radius-3
trial from roughly 59 seconds to 23 seconds on this machine, with the same
31 plies and Ivory winner. These timings are development-machine observations,
not mobile performance guarantees.

Release JavaScript web build succeeded. Browser play reproduced a top-to-bottom
Ivory victory through 13 legal placements, previews and confirmations. All
board inputs disabled after the win. The result outlines the winning seat
instead of the next player; 12 focused widget checks and strict analysis passed
after that final visual fix. Responsive inspection covered 390x844, 320x568
(with scrolling to the entire board), and 1366x768. Proof is saved under
`build/hex-shared-road-phone.png`; generated artifacts are not committed.
