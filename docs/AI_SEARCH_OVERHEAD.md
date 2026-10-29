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

## Remove discarded move applications from evaluation

Material evaluation previously applied a one-stone spread in each direction,
allocated the preview board and discarded it after checking whether it was null.
Hard/Expert v3 duels now use `MatchRules.canSpreadOne`, a legality-only query for
that exact one-top-stone/one-final-drop case. Other profiles keep their existing
probe path. The move transformer and adjudicator are unchanged. Differential
checks compare the query and every material score with canonical application
across both geometries, every supported size, two-to-four seats, opening/terminal
states and wall/capstone rules.

Search-local positions also wrap their freshly created private map without a
second map copy. Changed stacks remain immutable copies, and an alias regression
verifies that mutating the caller's supplied map/list cannot alter the position.

A sequential native benchmark covered 38 Square-5/Hex-2 replay positions and
7,600 complete static/material evaluations per arm. Canonical probes took
404,559 microseconds and allocation-free probes 99,708 (4.06×), with identical
checksums. The transition microbenchmark checked 57,992 transitions per arm with
matching checksums. These measure evaluator/transition cost, not playing strength
or production latency; exact-source release gates still qualify publication.

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
the total thinking target. That candidate (`1a44217`) passed locally 7–3 but
again tied 5–5 in CI: its changed-outcome games first diverged at Expert ply 23
(four completed plies locally, two in CI) and ply 7 (six locally, four in CI).
These traces motivated the allocation-free evaluation work above. Those earlier
runs do not qualify the revised source.

Correctness checks include canonical transitions/immutability, exact winning-move
membership, the independently refuted mate regression, cancellation, draw
responses and saved-engine behavior. Release still requires strict analysis, the
complete Flutter suite, all six representative adjacent-tier groups, browser and
account checks, rules qualification and two consecutive successful main CI
attempts. Native diagnostics do not replace those checks or qualify the full
size/player strength matrix. Hosted source, integrity and login are checked after
publication.

## Duel reply breadth calibration candidate

The optimized source passed all five other representative groups, but Square
Expert/Hard tied 5–5 in both the first optimized run and `d781e35`; all other
sixteen jobs passed on the latter. No release was published and that failed run
was not retried. Repeating the depth-before-width experiment after optimization
was also rejected locally: one win, four losses and one draw in six games left
no possible required majority, even if all remaining games won.

An Expert four-reply candidate (`9589308`) was rejected after Hex Expert/Hard
again tied 5–5 in CI. Its local Square trial stopped at two wins and four losses
in six games after that required CI failure; the incomplete local run is not a
qualification result. That candidate was never promoted to main.

The current candidate fits Hard's interior beam to its shorter strategic
allowance: two replies instead of three. Expert retains its original three.
Hard still targets twelve roots and four plies, Expert sixteen roots and six
plies, with the original Expert widening schedule and 2000/5000 ms total targets.
Exact forced-result widening and the three-/five-ply safety checks remain. This
changes ordinary selective coverage only in Hard v3 duels; saved engines,
multiplayer and other tiers retain their prior reply widths. Full adjacent-tier
gates must establish both Hard/Medium and Expert/Hard ordering before this
calibration is adopted. Strength qualification is pending.

## Preserve frozen benchmark controls while production evolves

The first optimized source correctly triggered the reference dependency guard:
its frozen engine still imported live production material/rule modules. The
reference engines, workers and protocol remain untouched. Their original library
bytes are now archived and materialized into a reference-only package. Historical
hash values remain unchanged; no expected hash is refreshed to the optimization.
Original canonical rule APIs and shared game-contract modules retain byte checks.
New release-tool tests compare every archive with its original Git object, verify
the compiler package alias and reject tampered materialized files or rule APIs.
All 74 release-tool tests, strict analysis, and complete R/RT/F/S/E/SE/G builder
integration passed locally. These checks repair the build safeguard without
waiving any strength or publication gate.
