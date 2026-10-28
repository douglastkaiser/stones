# Duel search and connectivity repair — 2026-10-27

Applies to **LEARN-01**, **PLAN-10** and adjacent **COMPAT-06**. Both experiments
are implemented but opt-in. Production defaults remain unchanged pending the
independent strength, timing and device gates. No publication or improved human
playing strength is claimed.

**Adoption result:** the tactical counterexample gate passed, but the timing and
same-tier pilots do not support enabling search-only or combined defaults.
Evaluation-only remains unqualified. The full matrix was not run after these
prerequisite failures; its thresholds remain unchanged.

## Repair after the failed first experiments

The original bottleneck was repeated whole-game tactical simulation. The revised
win detector joins owned road components for placements, checks transformed
spreads with the same component topology, and calls the shared flat adjudicator
for flat endings. It preserves candidate order and exact winning-move membership;
opening ownership still uses the original canonical path. The optimized detector
is restricted to the experimental full-width and exact safety-proof paths; the
normal strategic search retains its original detector. Saved engines and multiplayer keep
their original code path.

The revised connectivity feature enumerates **minimum empty-placement completion
sets of size one or two**, across every allowed road axis. Their intersection
identifies a common blocker: many paths through one gap count as fragile, while
independent completion sets do not. If no common gap exists, legal enemy
single-stone captures test whether a shared exposed flat remains vulnerable.
Caps remain immune to covering. The penalty is bounded by 40, zero without a
one-/two-placement continuation, and currently tested at weight 16. This is a
secondary structural estimate, not a proof of a fork or a complete vulnerability
analysis of every possible spread.

The revised full-width schedule establishes one ply, a complete two-ply static
round, a complete two-ply tactical round, then tactical rounds at four/six plies.
Only completed iterations replace the move. Baseline and tactical transpositions
have separate value keys, while principal moves and completed root scores order
later work. Internal principal moves can cause sound alpha-beta cutoffs before
other moves are generated. A proven win can end thinking early. Diagnostics
separate nominal depth from `completedTacticalDepth`.

The optional `duelThinkingLimit` applies only to v3 duels. The current development
allowances are 200/500/2000/5000 ms. R is unchanged; RT subclasses only its time
getter with those allowances. In the final repair builds F is the current strategic baseline with the safety
guard disabled (earlier F builds isolated the detector optimization). S adds
full-width search, E adds unconditional connectivity, SE combines those changes,
and G enables the targeted safety repair described in
[the repair contract](AI_TACTICAL_REPAIR.md). The build checks the *compiled*
worker settings, rather than trusting compiler flags (Dart AOT splits comma-valued
`-D` declarations). Binary/source sidecars remain immutable.

The stronger policy-certificate tool follows actual recorded AI replies and
independently checks **every legal attacker branch** through the chosen horizon.
A preliminary combined candidate records 27 defenses that prevent the known
ninth-move win. This strengthens the earlier root-admissibility evidence, but
still certifies only that finite-horizon recorded policy, not eventual strength.
Certificate tests reject missing/duplicate attacks and invented stopping claims.

Development trials are deliberately separate from confirmation. The initial
whole-round combined candidate scored 4–2 over three Hex-2 Hard openings, but its
search-only follow-up scored 2–4. Three paired openings cannot establish strength;
the search-only regression is a reason to exclude that component unless a new
repair independently passes. Increased node coverage alone is not the goal.
Fresh streams and acceptance criteria are registered in
[the repair validation protocol](qa/ai-fix/validation-protocol.json).

The sections below record the **superseded first implementation and its failed
gates**. Their timings and source hashes do not describe this repair.

## Benefit audit: required latency gate failed

[The benefit audit](qa/ai-benefit-audit.json) confirms that these implementations
do **not** yet deliver the agreed overall benefit. Reference/candidate sources,
weight 16 and thinking budgets were frozen throughout; no engine was tuned on
these results. Native measurements ran sequentially without builds or tests.

The first 50 seed streams contained only 46 distinct initial openings. A separate
60-stream run provided 56 distinct openings. The audit keeps the lowest seed for
each opening, including all three of its sampled positions: 168 positions. It
bootstraps whole opening clusters, never individual repeated positions. The
60-stream run supersedes the 50-stream run; they are not pooled as independent
evidence. The original raw 180-position p95 and deduplicated p95 agree:

| Square-5 Easy | p95 | Ratio to reference | 95% opening-cluster bootstrap ratio interval |
| --- | --- | --- | --- |
| Frozen reference | 43 ms | 1.00 | — |
| Search only | 201 ms | 4.67 | 3.47–6.09 |
| Evaluation only | 79 ms | 1.84 | 1.38–2.32 |
| Combined | 200 ms | 4.65 | 3.45–6.06 |

All three variants fail the unchanged no-worse-p95 criterion in this required
profile. Search/combined also returned emergency moves with no completed iteration
in 8/168 and 10/168 deduplicated position cases. This single required-profile
failure blocks adoption; it does not require pretending that the remaining
strength, multiplayer or device matrices have passed or failed.

The positive evidence remains narrow: independent bounded search verifies the
recorded quick-loss repair, while unit/oracle checks verify implementation
correctness. Neither proves improved game strength.
The solver's refutations certify that later defenses exist, not that the timed
AI will choose them on every continuation. Earlier shorthand about preventing
the loss must be read with this narrower scope. Evaluation's earlier 3–1
pilot contains one positive engine sweep and one tied opening pair. An exact
opening-pair sign test has one-sided improvement p=0.5, not evidence of a reliable
strength gain. The earlier two-opening bootstrap intervals are descriptive;
homogeneous tiny samples can produce degenerate intervals and cannot prove an
intrinsic starting advantage. Sign tests concern opening-pair tendencies, not
perfect-play balance.

Reproduce the audit after building the frozen arms above:

```sh
/tmp/stones-ai-duel-benchmark --binaries=/tmp/stones-ai-duel \
  --held-out --samples=60 --levels=easy --profile=square-5-2 \
  --output=/tmp/benefit-timing.jsonl
python3 scripts/ai_benefit_audit.py --timing=/tmp/benefit-timing.jsonl \
  --output=/tmp/benefit-audit.json
```

The audit exits **1** when a required latency comparison fails; this is the
expected rejection, not a test-suite failure. Its six unit checks pass. Engine
defaults remain false/zero. Optimization and fresh held-out qualification are
required before claiming the overall upgrade is beneficial.

## Implemented behavior

`MatchAI(fullWidthDuels: true)` replaces the v3 two-seat selective path with
full-width alpha-beta minimax. Iterations complete in individual plies, up to
2/4/4/6 plies under the existing 200/500/1200/2200 ms targets. Every legal placement
and spread is eligible. Principal moves, captures and local connectivity order
moves; beams and speculative pruning never exclude them. Ordering retains move
descriptors rather than all resulting boards. An immediate terminal victory can
end an iteration using its sound global score bound.

A deadline retains the last completed iteration. If none completes, a legal
deterministic emergency move reports depth zero and `emergencyFallback: true`.
There is no mandatory work after the deadline. Cancellation returns no move.
This timeout contract applies only to the opt-in duel path. Targets remain
cooperative deadlines: synchronous work and scheduling can overrun them.

Decision-local transpositions distinguish exact/lower/upper bounds and include
position, root perspective, remaining depth, tactical policy and extension
allowance. The existing 10,000 weighted-entry ceiling charges cached move lists.
Deeper heuristic horizons never substitute for shallower exact horizons.
Interrupted ancestors publish no values; completed descendants remain usable.
Repetition and experimental variation require exact alternative root scores.

Exact leaf checks include road and flat wins. Immediate rival threats extend all
safe defenses, including terminal draws, by at most two extra plies. Only a
completed enumeration can prove that no defense survives. Interrupted checks
abort the iteration. A final-leaf immediate-win proof can certify one terminal
move beyond that frontier; `completedDepth` reports nominal depth honestly.

`MatchAI(roadResilienceWeight: 16)` independently adds one structural road term:
the maximum increase in best road cost, across all permitted axes, after a
single empty-cell wall/cap blockage or legal one-stone capture of a supporting
flat. Actual capture boards preserve source exposure. Caps cannot be covered.
Only interventions hitting a canonical cheapest path need examination: otherwise
that path survives. Both geometries use the existing 0/1/3/6 road costs.

The term is `-min(40, weight * maximumIncrease)` per seat. Independent routes
resist blockers, shared gaps create bottlenecks, and captures expose vulnerable
support. This is not a fork certificate: multi-drop captures and longer sequences
remain search work. Existing development and material terms remain. There are no
coordinate, opening, Hex-specific or capstone timing rules.

The development grid is 0/8/16/24. Sixteen is an experimental default, not a
qualified weight. Choose the smallest independently passing weight; production
weight remains zero until qualification.

## Reproducing separate comparisons

The frozen R reference is from `ec5d3dcef52d5e7c5d6f995819b7cd179b49b8fc`.
Its engine copy changes only imports and a provenance comment. Frozen dependency
hashes must match before rebuilding. The older `tools/ai_baseline` remains intact.

Build R (reference), S (search), E (evaluation) and SE (combined) in a **new**
directory. Sidecars record actual binary/source hashes, flags, settings and runtime:

```sh
python3 scripts/build_ai_duel_experiments.py \
  --dart=/workspace/.tools/flutter/bin/dart \
  --output-dir=/tmp/stones-ai-duel --weight=16
dart compile exe tools/ai_duel_benchmark.dart -o /tmp/stones-ai-duel-benchmark

# Six rotations and both starting colors of the known defensive counterexample.
/tmp/stones-ai-duel-benchmark --binaries=/tmp/stones-ai-duel \
  --counterexample-only --levels=hard,expert --output=/tmp/duel-defense.jsonl
dart run tools/ai_duel_defense_check.dart --input=/tmp/duel-defense.jsonl \
  --output=/tmp/duel-defense-proof.json

# Development opening/midgame/late samples plus the counterexample transforms.
/tmp/stones-ai-duel-benchmark --binaries=/tmp/stones-ai-duel \
  --samples=2 --output=/tmp/duel-development.jsonl

# Lock settings first; known counterexamples are excluded from held-out timing.
/tmp/stones-ai-duel-benchmark --binaries=/tmp/stones-ai-duel \
  --held-out --samples=50 --output=/tmp/duel-heldout.jsonl
```

Measurements run sequentially with balanced arm order, identical full replay and
history, legality/position checks and per-position flushing. Do not overlap native
timing runs with tests, builds or other benchmarks. Logs retain exhaustive depth,
nodes, generation, cutoffs, extensions, stage microseconds, caches and emergency
fallbacks. Stage times include cooperative pauses; they are not additive CPU times.
This duel profiler does not replace multiplayer/native/browser/device qualification.

The existing game runners accept these binaries. Run S–R, E–R, SE–R and SE–S on
Square 5 and Hex radius 2, Hard and Expert, with at least 50 independent held-out
openings and both seat assignments. For example:

```sh
dart compile exe tools/ai_strength.dart -o /tmp/stones-ai-strength
/tmp/stones-ai-strength --candidate=/tmp/stones-ai-duel/S \
  --opponent=/tmp/stones-ai-duel/R --shape=hex --size=2 --players=2 \
  --tier=1 --seed-start=100000 --seeds=50 --explore \
  --output=/tmp/duel-search-reference.jsonl
python3 scripts/ai_balance_report.py /tmp/duel-search-reference.jsonl \
  --output=/tmp/duel-search-balance.json

dart run tools/ai_qualification.dart --mode=regression --paired \
  --candidate=/tmp/stones-ai-duel/S --baseline=/tmp/stones-ai-duel/R \
  --output=/tmp/duel-search-regression.jsonl
```

`--explore` records a same-tier comparison; it cannot qualify a partial matrix.
Keep the six required CI jobs, all 81 full adjacent-tier groups, reference matrix
and completion gates unchanged. Aggregation rejects mixed compile-time settings.
Development seeds for the first experiment were 10000–10049; CI seeds 0–4; strength holdout 100000–100049;
timing holdout 200000–200049. Do not tune on a used holdout then reuse it for
acceptance. Register fresh confirmation seeds after any such tuning.

## Acceptance and initiative controls

1. Oracle, cache/window/eviction, interruption, terminal, independent tactical
   proof and symmetry checks pass. The recorded losing line remains proven and
   its defense refuted only within the stated horizon.
2. S–R and E–R separately show no required profile/lineup below parity and
   aggregate improvement. SE–R also passes; SE–S establishes incremental benefit.
   Exclude a failing component instead of hiding it in the combined result.
3. Full adjacent qualification retains ≥80% completion, ≥50% decisive games and
   >60% normalized stronger-tier share. Same-tier groups require ≥50% normalized
   share and aggregate improvement. Paired p95 latency is no worse than reference
   per profile/tier. Partial trials never qualify.
4. Normal-budget Hard/Expert avoid the proven quick loss on the known position
   and transformed equivalents. If search/feature cost prevents this, retain the
   reference and record the failed feasibility gate.
5. R/R, S/S and SE/SE controls use independent openings, reversed starting colors
   and swapped workers. Report starter/second-seat wins, engine/seat sweeps,
   draws and unfinished games. Confidence intervals bootstrap whole opening
   clusters, retaining paired seats/repeats together; fewer than two openings get
   no interval. Larger equal budgets are diagnostic only. No perfect-play balance
   claim or rules change follows from these empirical results.
6. Full Flutter tests, strict analysis, release web build and existing completion
   checks remain required. Device responsiveness and human strength require their
   own evidence. No CI gate is relaxed.

## Compatibility and evidence

Both options default to false/zero and affect shared v3 duels only. Saved v1/v2
strategies, multiplayer MaxN/mandatory rounds, controller/history reconstruction,
save/room formats, leases and ratings remain unchanged. Native/browser dispatch
carries identical optional settings; no experiment fields enter saved matches.
Randomness remains experimental with deterministic production defaults.

[Verification evidence](qa/ai-duel-verification.json) records actual checks and
pilot results, independently of outstanding qualification and rollout gates.

The full Flutter run passed 1,864 checks during implementation; 28 final focused
checks passed after subsequent root-window/cancellation refinements and added
fixtures. All 60 Python checks, strict analysis and the release web build passed.
Frozen dependencies and the measured candidate source hashes were verified again.

All 72 S/E/SE Hard/Expert decisions on the six rotations/two colors of the known
counterexample refuted the recorded quick win. Reference Hard allowed that quick
loss on four of its twelve transforms. These are transforms of one position, not
independent strength openings, and refuting the quick win does not prove an
eventual defender win.

The held-out timing pilot used seed 200000, four default/maximum duel profiles,
three positions each, all tiers and all four arms: 48 decision cases/192 arm
decisions. It exposed regressions (Square-5 Hard S/R descriptive p95: 1200/399 ms;
Easy: 200/22 ms). S and SE completed no iteration on one late maximum-Hex position
at Easy/Medium. Three correlated positions per group cannot qualify p95 latency.

The fixed-setting Hard/Hex-radius-2 game pilots used seeds 100000–100001 with both
seat assignments:

| Comparison | Candidate wins–losses | Draws |
| --- | --- | --- |
| Search / reference | 1–3 | 0 |
| Evaluation / reference | 3–1 | 0 |
| Combined / reference | 0–3 | 1 |
| Combined / search | 1–2 | 1 |

Equal-policy controls added both starting colors and swapped workers for R/R,
S/S and SE/SE: starters won 8/8, 5/8 and 6/8 games respectively. All 40 pilot games
finished legally. Every comparison/control reuses the same **two** underlying
openings; neither 40 games nor the color/worker repeats are independent opening
samples. Both attacking and defending policy change in self-play, so these rates
do not establish intrinsic starting advantage or stronger defense by themselves.
Timed cutoffs can also produce differing outcomes between identical worker policies.

The evaluation-only 3–1 result does not establish a strength improvement or an
optimal weight. Its full weight grid, 50-opening reference comparisons, adjacent
tiers, Expert game trials, all-size/multiplayer timing, browser/device and human
acceptance remain open. Keep defaults false/zero; no rules or CI gates changed.
