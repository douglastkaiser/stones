# Shared AI v3 upgrades — 2026-10-23

## 2026-10-29 release-policy change: manual strength studies

The owner requested removal of the slow adjacent-tier tournaments from push/PR
CI and deployment requirements. They now live in the manual-only AI Ordering
workflow. Unit/tactical regressions remain in the ordinary Flutter suite, and
all other source/artifact, build, browser, account, rules and hosted checks
remain required. This supersedes the automatic strength-gate requirements in
the dated investigation notes below. It does not change the engine or resolve
Expert/Hard ordering. See [qualification policy and retained failed evidence](AI_QUALIFICATION.md).

## 2026-10-29 Hard/Expert forced-result verification

[The duel search repair](AI_SEARCH_OVERHEAD.md) addresses an independently
refuted forced-win claim: a narrow reply beam cannot prove that every legal
reply loses. Hard/Expert v3 duels now widen purported forced-loss nodes until
all replies have been checked or one refutes the claim. Ordinary search and
forced horizon extensions share this rule. An interrupted iteration is discarded.
The existing immutable-stack and exact win-checking kernels also reduce overhead.
Evaluation, total thinking limits, root targets and every release gate remain
unchanged. Expert v3 duels use 3200 ms of their existing 5000 ms total for
strategic refinement, instead of stopping after 2200 ms while safety verification
can return early. Hard, saved engines and multiplayer retain their allocations.

The overhead-only and depth-ordering candidates failed required groups; the
original Expert widening schedule is restored. The new regression verifies the
actual false-mate counterexample against an independent exhaustive solver.
Completed-iteration diagnostics support replay analysis. Canonically equivalent
allocation-free single-stone material probes and an owned immutable board-map
view remove discarded move previews and a redundant map copy. Differential rules,
score and aliasing regressions verify equivalence; a 38-position native evaluation
benchmark measured 4.06× speedup with unchanged scores. This is cost evidence,
not strength qualification. Exact-source CI and hosted verification, rather than
earlier candidate results, qualify publication.

## 2026-10-28 targeted duel repair — selected native validation

[The tactical repair](AI_TACTICAL_REPAIR.md) preserves the original strategic
search, then verifies proposed Hard/Expert v3 duel moves against exact three-/
five-ply forced-loss objectives. Only a proved loss plus a verified defense can
replace a move. A completed near-term repair survives deeper timeout. Connectivity
orders proof attempts instead of changing every positional score. Total targets
are now 200/500/2000/5000 ms for this source candidate; saved v1/v2 and multiplayer
retain their original strategies and allowances. This is not a publication or a
claim of full playing-strength qualification. Required strength gates remain
unchanged. The broader full-width and unconditional evaluation changes below
remain off after their failed development and latency studies.

Fresh native confirmation passed over 50 distinct openings per board with swapped
seats at Hard and Expert: 226 wins, 161 losses and 13 draws against the frozen
original, all 400 games finished. The preregistered opening-stream-clustered sign
test gives p = 0.0002154. Independent replay verified all 203 actual replacements.
All six required representative adjacent-tier regression groups passed without
changing their gates. See [the confirmation evidence](qa/ai-fix/reference-study.json)
for profile intervals, starting-role controls, source hashes and qualification
limits. This establishes aggregate benefit for the tested native cohort; the
full size/player matrix, human Expert strength and browser/device responsiveness
remain open. No release was published.

## 2026-10-27 completed-duel and resilience experiments

[Completed duel search and road resilience](AI_DUEL_EXPERIMENTS.md) adds
independent opt-in search/evaluation experiments and frozen current-v3 R/S/E/SE
comparison tooling. Defaults remain unchanged pending strength and timing gates.
The [benefit audit](qa/ai-benefit-audit.json) confirmed a required Square-5 Easy
latency failure over 56 distinct opening clusters for search, evaluation and
combined variants. Those full-width and weighted-evaluation variants remain unqualified for
rollout. The targeted repair above has separate native confirmation evidence.
Full-width duels retain completed ply iterations within existing targets and
report emergency depth-zero fallbacks; multiplayer and saved engines keep their
current behavior. A bounded general blocker-sensitivity term distinguishes
redundant roads from bottlenecks without opening or capstone timing rules.

## 2026-10-26 strength investigation and CI

This follow-up is a source change, not a publication or a completed full strength
qualification. It affects **LEARN-01** and **PLAN-10**; saved v1/v2 strategies and
rating identities remain unchanged.

The production v3 engine does not draw random numbers. Easy retains its stable
position-based variation. The old v3 Medium policy deliberately selected a second
near-equal move every third round; after the new Square regression sample exposed
a 4–6 loss to Easy, that scripted handicap was removed. Medium now chooses its
best completed result, subject to repetition avoidance. Saved v1/v2 choices remain
unchanged. Search is nevertheless sensitive
to wall-clock cutoffs, runtime and device load. Its 200/500/1200/2200 ms limits
bound refinement, not total latency: a mandatory selective round can finish after
the deadline. Search returns a completed iteration, or its completed selective
baseline, rather than adopting an unfinished iteration.

Medium's duel target is now two rounds rather than one, within its existing
500 ms refinement budget. Its multiplayer target stays one round. Hard retains
broader search and its 1200 ms budget; Expert retains its three-round target and
2200 ms budget. The focused Square sample then separated Medium/Easy 10–0 and
Hard/Medium 6–4. These ten-game samples are regression evidence, not qualification.

The original native Square-5 pilot won both seeded seat rotations for Expert,
but the normal AI-controlled opening let the first seat win both rotations,
including Hard beating second-seat Expert. This reproduces the reported outcome
without establishing that Hard is stronger across openings. Most decisions in
that normal-opening pair completed only one round. Expert previously paid for
16 roots even in its shallow fallback and early refinements, versus Hard's 12.
In duels it now establishes the same root-width foundation as Hard before
widening its final refinement. Completed principal choices are searched first
in subsequent v3 duel iterations. Multiplayer search retains its prior widths
and root order; the full optional matrix checks those formats separately.
Neither change prescribes board moves or raises thinking budgets. Native mixed
playthrough tests supply the same confirmed-position history as the controller,
retaining their 150-move completion requirement.

Expert also retains a completed wider two-round result before attempting its
third round. A common narrower reply model for Hard/Expert was tested and rejected
after Expert lost 0–4 to the frozen richer model; their richer reply beams remain.
Exact material pruning now skips spreads that cannot possibly form a road while
retaining every potential winning placement. Possible flat endings bypass that
pruning, including a spread filling several empty cells. Differential legal-move
checks and a board-filling spread regression protect that bound.

The Hex probes also exposed a horizon error: the defensive extension returned
the same empty list for a quiet position and for an immediate rival threat with
no legal defense. The latter was then assigned a normal positional score. The
extension now distinguishes those states. In a duel, a completed enumeration
with no safe reply proves a rival win on its next move and receives a forced-loss
score. Terminal draws count as safe defenses. An interrupted enumeration still
aborts refinement rather than proving a loss; multiplayer does not infer a winner
from this duel-only argument. A legal 3×3 fork regression previously scored the
losing line at −124.345679 instead of a forced loss, and now detects it correctly.

The evaluator gives a deployed capstone five points and values its road-blocking
effect, while caps do not score as flats. A pilot credited the same five points
in reserve to remove the deployment incentive. That isolated change lost both
seat rotations against the original Expert on development seed 10000, so it was
rejected. This small sample does not establish an optimal material model, but
does not support discouraging early caps. The production evaluator retains its
board-value terms. There is no opening delay, capstone ban or deployment-turn
penalty. Worker diagnostics expose positional score terms, completed-root
alternatives, timeout stages and capstone deployment plies for further study.
On that same two-game development pilot, search-only and combined changes each
split 1–1 against the original Expert. Those exploratory games do not qualify
strength or latency; the smaller search-only change is retained for CI checks.

For one recorded first non-opening move, a cap and a flat on the same cell had
static utilities 95.0 and 94.576: identical road/development terms, with the cap's
five-point board bonus barely exceeding the flat's scoring value. The reserve
credit variant still chose an early cap in that opening. Early cap deployment
therefore cannot be attributed only to the small deployment bonus, or assumed
weak from its timing. Compare completed search values and outcomes as well.
Inspect both seats' score terms from a native JSONL replay with:

```sh
dart run tools/ai_explain.dart --replay=PATH --game=0 --ply=2
```

This explains the recorded move and its same-cell flat alternative when legal.
Its static utilities are not a substitute for the worker's completed-search
diagnostics; the tool explicitly identifies that limit in its output.

### Reproducible adjacent-tier checks

The manual-only **AI Ordering** workflow runs six independent native jobs:
three adjacent matchups on Square 5 and two-seat Hex radius 2.
Each uses five fixed opening seeds (0–4)
and both AI seat assignments: 60 games total. Every ten-game group must finish
all trials, complete at least eight games, have at least five decisive games and
give the stronger tier more wins than losses. Capped games remain unfinished.
Failure fails that manually requested study. Routine CI and Deploy Main do not
run or require it.
These small samples detect regressions; they do not establish universal ordering.

Current Hex Hard/Medium and Expert/Hard samples still fail at 5–5. Every opening
was swept by the same seat after swapping difficulties; the starter won 8/10 and
10/10 respectively. Equal-Expert controls and exhaustive bounded counterfactuals
show both opening/initiative effects and avoidable defensive errors. The strict
gates remain unchanged. See the [balance investigation](AI_BALANCE_INVESTIGATION.md)
and its provenance-backed evidence for the controls and limits. Each duel CI
artifact includes a report separating tier sweeps from opening/seat sweeps.

**Full AI Strength** is manual only. With no filters it covers 81 groups: every
supported Square/Hex size, 2/3/4 seats and every adjacent matchup. Fifty opening
seeds (100000–100049, separate from the required regression seeds), with one
stronger AI rotated through every seat, total 12,150 games.
Five-seed shards retain complete replays and source/runtime/binary provenance.
Aggregation rejects missing or duplicate trials, mixed source/policy provenance
and incorrect seat outcomes. Each group must meet the existing 80% completion,
50% decisive-game and >60% normalized stronger-tier share gates. Filters produce
explicitly partial coverage. This workflow does not replace paired-reference
latency qualification or physical-device acceptance.

```sh
dart compile exe tools/ai_worker.dart -o /tmp/stones-ai-candidate
python3 scripts/ai_strength_ci.py provenance --binary=/tmp/stones-ai-candidate
dart compile exe tools/ai_strength.dart -o /tmp/stones-ai-strength
/tmp/stones-ai-strength --shape=square --size=5 --players=2 --tier=2 \
  --seeds=5 --output=/tmp/hard-expert.jsonl
```

Each output must be new; interrupted/partial shards fail aggregation and can be
rerun with a new output. The older qualification runner retains its resumable
matrix. `--natural-opening --seeds=1 --explore` investigates normal AI-controlled
openings. `--opponent=PATH --explore` compares the candidate against a frozen
same-tier executable (tier 1 selects Hard, tier 2 Expert). Each binary needs a
provenance sidecar captured when built; `provenance --source-ref=SHA` can describe
an executable frozen from that exact revision. Do not relabel an existing binary
with a different source.

### Organic final-choice experiments

Production remains deterministic. Optional `AiMoveVariation.ties` and `weighted`
policies are available through shared dispatch, native workers and the manual
workflow. The default policy does not consume randomness. The ties policy samples
equal scores; weighted samples within four points of the best remaining eligible
move after repetition filtering, favoring better scores with weight
`1 / (1 + score deficit)`. Both preserve forced-result priority
and the existing least-repeated-position filter. They replace Easy/Medium's
deterministic alternatives only when explicitly selected.

Refinement alternatives are compared using full root windows: alpha-beta bounds
are not treated as exact alternative scores. Random choice uses only a completed
iteration. Easy may vary over its completed selective round after tactical
filtering; a deadline fallback remains deterministic. If verification cannot
complete, search retains the previous completed choice. This extra exact scoring
can cost depth and must be measured, not assumed harmless.

Use independent fixed decision seeds for comparisons; workers record each seed,
selected move and alternatives. Shared dispatch accepts the same optional seed
on web/native. An unseeded explicit experiment uses a fresh RNG; replayed games
already retain their actual moves. To compare a policy against deterministic
same-tier play with the same binary:

```sh
/tmp/stones-ai-strength --tier=2 --policy=ties --reference --seeds=5 \
  --explore --output=/tmp/expert-ties-pilot.jsonl
```

No randomized policy is enabled by this change. Enabling one requires held-out
same-tier no-regression evidence, passing adjacent-tier gates, useful diversity
and acceptable timing/depth. Seeded selection is reproducible when the same
iteration completes; wall-clock search remains runtime dependent.

Applies to **LEARN-01**, **PLAN-10** and **COMPAT-06**. These are search/evaluation
changes, not Tak rules or new draw conditions. V3 is now published in web
application `58a1f56` (2026-10-24); see the
[release record](RELEASE_READINESS.md#published-web-and-firebase-release-2026-10-24).
Saved v1/v2 configurations keep their strategies; v3 continues the established
v2 AI rating identities. The actual engine remains recorded on each game and new
rating-history item. Publication preserves ratings and historical records.
The dated qualification notes below retain their strength/timing limits.

## Implemented behavior

1. **Decision-local search reuse.** Static scores, complete ranked move groups,
   immediate-win checks, principal moves and transpositions share a weighted FIFO
   cache capped at 10,000 entries/retained children. All caches are discarded after
   each decision. Duel entries distinguish exact/lower/upper bounds; multiplayer
   entries hold complete seat vectors. Interrupted computations are not cached as
   complete results. Previous principal moves reorder only the already selected
   beam. Compact decision keys retain ordered stacks, reserves, outcome and
   absolute ply within a fixed configuration; repetition keeps its separate
   canonical identity. Root duel values use full windows whenever repetition or
   Medium variation can select a near-equal alternative. Best-move-only choices
   retain alpha-beta pruning. This prevents treating upper bounds as exact scores
   without paying for exact alternative scores on every turn. The current
   follow-up replaces Medium's periodic alternative with its best completed
   choice; explicit variation and repetition still require exact alternatives.
2. **Exact tactics and bounded extensions.** V3 horizon win checks enumerate legal
   placements and spreads without the old path-distance gate. This covers winning
   multi-drop spreads whose initial road distance exceeds one. A sound total-stone
   lower bound (including buried stones) skips impossible early road threats;
   potential flat endings always bypass it. Defensive forcing
   sequences may extend a refinement by one table round, under its existing
   deadline. Legal captures/recaptures get a small ordering preference. A fork is
   promoted to a forced win only after all joint defenses, in actual seat order,
   fail. Deadline/node exhaustion returns unknown, never a proven fork. Fork proof
   is opportunistic on two leading roots with at most 128 visited positions.
3. **Bounded material evaluation.** Legal probes from `MatchRules` measure cap
   mobility/crushes, exposed ownership and accessible/trapped friendly material.
   Features are normalized and the aggregate is limited to ±40 per seat, below a
   road-distance unit (80). Current conservative weights are **0/4/4/4** for
   mobility/crush/exposure/access. A sparse Square-8 pilot showed mobility weight 4
   changed Expert's connected central extension into a disconnected edge move;
   weight 0 preserved the baseline extension with caches both enabled and disabled.
   Mobility is therefore implemented but disabled by default. These weights have
   **not** passed the full game-based 0/4/8/12 pilot grid or held-out strength gates.
4. **Repetition avoidance without changing adjudication.** Position identity includes
   ordered full stacks, reserves, configuration, opening phase and side to move;
   it excludes absolute ply. The controller rebuilds the last 64 confirmed
   positions on load, reconnect and takeback, and clears them on leaving/new games.
   The same optional context reaches browser search and the native isolate.
   At the root only, near-equal candidates (within 24) prefer the least repeated
   resulting position. Proven wins and retained necessary defenses take precedence.
   No repetition draw is introduced, and search values are history independent.
5. **Reproducible qualification infrastructure.** The pre-upgrade source and native
   executable were frozen before production-engine edits. The reference source is
   `tools/ai_baseline/engine.dart`; `docs/qa/ai-upgrade-baseline.json` records hashes.
   A dependency hash manifest prevents silently rebuilding a changed reference.
   Persistent NDJSON workers receive identical complete replays, including the
   opening and confirmed-history context, and use normal thinking budgets.

Soft refinement targets remain **200/500/1200/2200 ms**. The mandatory selective
first round can exceed them so even Easy considers every seat before its next
turn. The first round samples 48 candidate replies per opponent; it is not an
exhaustive game tree. Timing targets are not hard latency guarantees.

## Running the qualification

Use the repository Dart SDK; binaries and long-running logs go outside tracked
source. Run timing comparisons without tests/builds or other benchmark jobs on the
same machine. The reference engine is intentionally frozen; do not tune it.

```sh
DART_BIN=/workspace/.tools/flutter/bin/dart tools/build_ai_benchmarks.sh

# Native, paired same-position latency; 50 held-out seeds per profile.
/workspace/.tools/flutter/bin/dart run tools/ai_latency.dart \
  --output=/tmp/stones-ai-latency.json

# Full adjacent-tier matrix; paired decisions also enforce native timing gates.
/workspace/.tools/flutter/bin/dart run tools/ai_qualification.dart \
  --mode=adjacent --paired --output=/tmp/stones-ai-adjacent.jsonl

# Hard/Expert candidate against the frozen same-tier engine, both minority and
# majority multiplayer lineups, all seat rotations.
/workspace/.tools/flutter/bin/dart run tools/ai_qualification.dart \
  --mode=regression --paired --output=/tmp/stones-ai-regression.jsonl

# Single-feature pilot grid; uses pilot seeds, never held-out qualification seeds.
DART_BIN=/workspace/.tools/flutter/bin/dart python3 tools/tune_ai_material.py
```

The matrix is default Square 5/two seats, default Hex radius 2/three seats, and
maximum Square 8 and Hex radius 4 at two, three and four seats. Each adjacent tier
needs at least 50 held-out seeds and all seat rotations, ≥80% completion, ≥50%
decisive games and >60% normalized stronger-tier per-seat win share. Regression
requires no profile/lineup below parity and aggregate improvement. A strength
claim also requires paired p95 latency no worse than the reference. Native, JIT
and browser timing results are separate; no native result qualifies mobile web.

The full adjacent matrix contains 3,450 games and the reference-engine regression
matrix contains 4,000 games, before the material pilot grid.

The game limit is `max(160, 2 * sum(initial reserves))`. Unfinished games remain
unfinished, never draws. JSONL records contain full replay/configuration,
seed/rotation, engine binary hashes via the manifest, final identity, repetition
counts, decision times, completed depths/rounds, cache statistics and timeouts.
Records flush after each complete game. Full replays stay on disk; the runner
streams them on resume and retains only gate inputs in memory. A partial trailing
write is discarded; malformed complete records fail. Re-running the same command
resumes completed games; a changed engine/settings/runner manifest is rejected.
An output-file lock rejects concurrent writers. An interrupted in-progress game
restarts. `--max-games`, `--profile`, `--tier`, `--seeds` and
`--pilot` support exploration; partial matrices cannot qualify.

The older `tools/ai_calibration.dart` remains available, now with full openings,
confirmed repetition context and reserve-scaled game limits. It does not replace
the paired reference-engine matrix.

## Verification and remaining acceptance

New regressions cover exact position identity, history rebuilding/truncation,
cache eviction and completed duel/MaxN equivalence, multi-drop road wins,
multiplayer joint fork defenses, legal crush/exposure/trapped-material probes,
repetition preference and winning-move priority. Existing all-tier maximum-board
wins/blocks, full-round interference and saved v1/v2 compatibility remain required.

The full 50-seed matrix and the human Expert-strength target remain **unqualified**.
Exploratory runs must not be described as demonstrated tier separation or improved
human playing strength. Browser responsiveness and physical-device acceptance
require their own evidence. Those source measurements did not establish
publication; the release record above now documents publication separately.

## Recorded evidence

[Verification record](qa/ai-upgrade-verification.json) contains the current source
and binary hashes and separates these checks from qualification:

- A 1,765-test full Flutter run passed before the final performance-only changes.
  After those changes, all 216 affected AI checks passed, including six complete
  mixed-difficulty games, maximum-board tactics and full-round interference.
  Twenty focused cache/key/history/material/qualification checks also passed after
  the final memory/recovery fixes. Strict analysis and the release emulator web
  build passed. Chromium phone-viewport journeys passed again after the performance
  changes. All 146 Firestore rule checks passed, including continued AI priors and
  actual game-engine history.
- The native maximum-Hex Medium/Hard/Expert trial applied 252 legal moves, including
  156 opposing-top captures and 58 multi-drop spreads. It had zero repeated
  positions in the tracked window, but **remained unfinished** at the fixed cap.
  It overlapped regression work and predates the final key/probe optimization;
  its full [replay and metrics](qa/ai-upgrade-max-hex-smoke.json) are exploratory.
- The [initial native timing pilot](qa/ai-upgrade-latency-pilot.json) exposed slower
  decisions on early positions. Compact keys, memoized move serialization, skipped
  irrelevant cap probes and conditional exact root windows reduced overhead.
  The [subsequent Square-5 pilot](qa/ai-upgrade-latency-square-optimized-pilot.json)
  completed Hard's two rounds and Expert's three within the existing budgets,
  but remained slower than the reference on several positions. Each group had
  only two measurements: **the timing gate has not passed**.
- The [runner smoke](qa/ai-upgrade-runner-smoke.json) completed both Square-5
  Easy/Medium seat rotations (15 and 37 plies), resumed without duplicating games,
  and rejected a changed source manifest. Its normalized stronger-tier share was
  0.5 over two games; it does not establish tier separation.

The full material pilot grid, 50-seed matrices, no-regression timing acceptance and
human/device strength acceptance remain open. The implementation is reviewable;
it is not a qualified strength or speed improvement. Publication is documented
separately in the release record above.
