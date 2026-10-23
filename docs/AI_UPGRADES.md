# Shared AI v3 upgrades — 2026-10-23

Applies to **LEARN-01**, **PLAN-10** and **COMPAT-06**. These are search/evaluation
changes, not Tak rules or new draw conditions. The v3 engine is still unreleased.
Saved v1/v2 configurations keep their strategies; v3 continues the established
v2 AI rating identities. The actual engine remains recorded on each game and new
rating-history item. No rating reset, historical rewrite or deployment is included.

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
   without paying for exact alternative scores on every turn.
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
require their own evidence. Nothing has been published.

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
it is not a qualified strength or speed improvement and has not been deployed.
