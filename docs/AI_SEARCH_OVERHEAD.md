# Hard/Expert duel search repair — 2026-10-29

Applies to LEARN-01 and PLAN-10; COMPAT-06 remains the adjacent saved-engine
contract. The release gates remain unchanged.

## The underlying false forced-result claim

Selective minimax searched only a small reply beam. If all sampled replies lost,
it could assign a forced-result score without examining an unsampled defense.
More depth or faster board transitions did not make that inference sound.

A reproducible legal 3×3 position exposed this directly: Hard assigned 199990
(a forced win) to a flat at `(2,1)`. An independent exhaustive solver refuted the
win objective over the following eight plies, expanding 6,209 nodes. The repaired
search completes the same four-ply iteration, chooses a spread and assigns a
normal positional value (8.4444 in the native diagnostic), without timing out.
The regression reconstructs the legal replay, checks the independent refutation,
and rejects the old forced-win claim after a completed search iteration.

Hard/Expert v3 duel search now examines remaining replies whenever its initial
beam says every examined choice loses for the mover. It stops widening once a
reply refutes that claim. This applies inside ordinary search and the forced
horizon extension. Winning alternatives still short-circuit normally, and
alpha-beta bounds remain bounds. A timeout abandons the incomplete iteration;
it cannot certify the missing replies. Quiet, non-forced search keeps its beam.
This is targeted result verification, not the rejected blanket full-width search.

## Preserve the existing search and release contracts

Strategic refinement also reuses the existing immutable-stack position and exact
component-based winning-move checker already used by the safety search. This
reduces copying and adjudication work within the existing time limits. The
three-/five-ply forced-loss veto, evaluator, root width/depth targets, Expert's
original widening schedule and total 200/500/2000/5000 ms targets remain.
Expert v3 duels assign 3200 ms of that 5000 ms total to strategic refinement
(previously 2200 ms), leaving the remaining time for safety verification. Hard
retains 1200 ms of its 2000 ms total. Explicit zero refinement, saved engines and
multiplayer retain their prior allocations.
Easy/Medium, multiplayer, saved v1/v2 and opt-in full-width strategies retain their
existing coverage. No game rules, opening seeds, rating identities, difficulty
handicaps, CI thresholds or deployment qualification requirements change.

The overhead-only candidate `df977a5` passed Hex Expert/Hard locally 7–3 and in
CI 6–4, but failed Square Expert/Hard 4–5 with one draw. A depth-before-width
experiment (`a99c5ba`) also failed required Hex groups and was reverted. Neither
candidate was published, and their results do not qualify the repaired source.
Worker diagnostics retain completed depth/width iterations and actual strategic/
total limits for replay analysis. On the forced-result candidate, both local Hex
matchups passed 6–4, but CI Expert/Hard tied 5–5. Their first differing decision
in the changed-outcome game was Expert at ply 39: native completed four plies,
CI only two, and CI returned after 2703 ms of its 5000 ms total. The strategic
allocation change addresses this lost completed iteration without increasing
the total thinking target. Those earlier runs do not qualify the revised source.

Correctness checks include canonical transitions/immutability, exact winning-move
membership, the independently refuted mate regression, cancellation, draw
responses and saved-engine behavior. Release still requires strict analysis, the
complete Flutter suite, all six representative adjacent-tier groups, browser and
account checks, rules qualification and two consecutive successful main CI
attempts. Native diagnostics do not replace those checks or qualify the full
size/player strength matrix. Hosted source, integrity and login are checked after
publication.
