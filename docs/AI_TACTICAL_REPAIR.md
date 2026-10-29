# Repairing avoidable v3 duel losses

Applies to LEARN-01 and PLAN-10; COMPAT-06 is an adjacent compatibility contract.
This repair follows [the original investigation](AI_BALANCE_INVESTIGATION.md)
and the rejected [full-width/evaluation experiments](AI_DUEL_EXPERIMENTS.md).
It does not establish perfect-play balance or human Expert strength.

Release-policy follow-up, 2026-10-29: the owner moved slow strength tournaments
out of automatic CI and deployment gating. References to required tournament
groups below describe the original repair protocol and evidence. The current
[qualification policy](AI_QUALIFICATION.md) preserves the studies for manual use.

## The problem and the smaller repair

A wider search can be worse when it replaces a completed selective result with a
shallow result before sufficient tactical work finishes. The first revised
full-width and evaluation-only Hard pilots each lost 2–4 over three Hex openings.
Neither component qualifies for adoption. More generated nodes are not an
acceptance criterion for playing strength.

The targeted candidate preserves the existing strategic search and its original
200/500/1200/2200 ms allocation. Hard/Expert v3 duels can spend the remaining
allowance, up to total targets of 200/500/2000/5000 ms, checking the proposed move
against an exact forced-win objective. First check three further plies, then
five. An alternative replaces the proposal only when the proposal allows a
proved forced loss and the alternative refutes that same bounded objective.

The earlier completed repair survives timeout or failure of the deeper check.
A proved loss within five plies must not erase a defense against a three-ply loss
merely because every move may eventually lose. Unknown results retain the last
verified choice. Terminal draws count as defenses. Cancellation returns no move.
The original strategic choice is retained when no forced loss is established.
These are cooperative time targets; the existing mandatory baseline and
synchronous work can overrun them.

Search enumerates every legal attack and every necessary defense. AND/OR
minimax short-circuits only on a proved attacking continuation or a refuting
defense. Exact cached results distinguish attacker, remaining horizon and full
decision position. Incomplete ancestors publish no proof. Material bounds include
buried stones, future attacker turns and possible flat endings; they can eliminate
impossible roads and spreads that cannot add enough stones.

## Connectivity has a narrow, testable role

Owned road components enumerate minimum one-/two-empty-placement completion sets
across all allowed axes. Their intersection detects a common bottleneck, rather
than counting several paths through the same gap as independent. Legal
single-stone enemy captures expose vulnerable supporting flats; caps resist
covering. This feature orders candidate defenses after a losing proposal is
proved. It does not change the normal positional evaluator or independently
veto a move. The rejected unconditional weighted-evaluation experiment stays off.
No opening coordinates, deployment schedules or capstone timing rules are used.

The proof uses the shared move transformer and flat adjudicator. An exact
component calculation speeds road-win checks. Search-local immutable positions
share unchanged stacks; ordinary game positions and saved engines retain their
original copying behavior. A sequential native transition microbenchmark measured
57,992 transitions per arm and a 1.23× speedup; that is a cost measurement, not
strength evidence. The first sharing implementation measured no benefit and was
replaced before further qualification.

## What constitutes validation

1. Compare win membership/order and every legal transition with the canonical
   rules on both shapes, several sizes and all seat counts. Compare the proof
   objective with an independent exhaustive solver; test horizon/cache isolation,
   interruption, flat endings, draws, immutability and compatibility.
2. Replay the actual candidate policy against every legal attacker continuation
   through move nine on the original counterexample. Separately audit measured
   transformed root decisions. Refuting one root's quick loss alone does not
   certify the AI's later decisions.
3. Independently re-solve every recorded replacement in game replays: the old
   move must have a proved forced loss at its recorded horizon and the chosen
   move must refute it. Reconstruct complete games with the shared rules.
4. Freeze source/settings before held-out comparisons; use identical openings
   and swapped seats, and an unchanged reference plus a compute-matched control.
   Report completion, draws, engine sweeps and starter sweeps separately. Bootstrap
   whole distinct-opening clusters. Starting-role sweeps do not prove an intrinsic
   forced first-player win. Full game-strength qualification and strict adjacent
   tier CI gates remain separate requirements; no threshold is weakened.
5. Complete full Flutter tests, strict analysis and a release web build. Browser
   and physical-device responsiveness require platform-specific measurements.

The registered fresh confirmation streams are in
[the validation protocol](qa/ai-fix/validation-protocol.json). Development trials
and historical binaries cannot be pooled as confirmation evidence. Source bytes,
binary hashes, build settings and raw replays are retained under
`build/qa/ai-fix/`; the final evidence record must identify the exact build used.

## Current evidence and remaining decision

The frozen G12 source passes all six required representative adjacent-tier
regression groups on native Linux. Each group uses five openings with swapped
seats and unchanged strict gates; all 60 games finished.

| Board | Medium/Easy | Hard/Medium | Expert/Hard |
| --- | --- | --- | --- |
| Hex radius 2 | 6–4 | 6–4 | 6–4 |
| Square 5 | 10–0 | 8–2 | 7–1, two draws |

Independent replay verified all 60 games and all 26 recorded move replacements:
every original proposal permits the stated bounded forced loss, and every
replacement refutes it. These reused regression openings establish the required
ordering check and actual tactical repairs, not a held-out strength estimate. A partially completed Square Hard/Medium run was
preserved separately after an environment interruption; the table uses one
complete restarted group, without any intervening engine change.

On nine selected later development positions, independent bounded solving finds
quick losses in 8/9 Hard and 6/9 Expert original-reference decisions. Giving the
reference the larger allowance still leaves 8/9 Hard and 1/9 Expert quick losses.
The candidate has none in either tier. This demonstrates tactical benefit beyond
extra time on those positions, not eventual wins or a population win-rate gain.
The actual recorded candidate policy also survives every legal attacking branch
through move nine on the original counterexample. The original Hard policy does
not; the longer-time reference does on that original example.

Fresh native confirmation is complete: 50 distinct openings per board, both
seats, Hard and Expert. All 400 games finished. The frozen candidate scored
226 wins, 161 losses and 13 draws against the original reference at the explicitly
increased allowances.

| Native profile | Candidate wins | Reference wins | Draws |
| --- | --- | --- | --- |
| Square 5 Hard | 59 | 37 | 4 |
| Square 5 Expert | 55 | 39 | 6 |
| Hex radius 2 Hard | 57 | 43 | 0 |
| Hex radius 2 Expert | 55 | 42 | 3 |

The preregistered global sign test clusters repeated boards/levels by their
shared opening seed: 54 clusters, 32 positive, nine negative and 13 tied,
one-sided improvement p = 0.0002154. Every profile meets its necessary reference
gates. Per-profile intervals remain wide; the supported superiority claim
applies to the aggregate tested cohort. The full
[reference study](qa/ai-fix/reference-study.json) includes those intervals and
starting-role results.

Independent replay verified all 400 games and all 203 tactical replacements.
For each replacement, the original move permits the recorded bounded forced loss
and the chosen move refutes it. One old-move proof exceeded the independent
verifier's initial 30-second allowance. The unchanged solver proved the same
five-ply objective in 125 seconds with a larger offline allowance; no game,
engine budget or acceptance predicate changed. The original audit and its
explicit resolution are retained.

Starting-role wins remain common (243/387 decisive games). This is evidence about
these policies and openings, not a perfect-play first-player-win theorem. The
counterfactual proofs establish that the identified quick losses were avoidable.
The aggregate strength result includes the allowed extra thinking time; the
compute-matched RT regression comparisons above establish bounded tactical
benefit on selected positions, not a separate population win-rate claim over RT.

Sequential native CI search p95 was 2000 ms for Hard and 5000 ms for Expert;
observed maxima were 2002 and 5001 ms. These are search measurements, not browser
or physical-device end-to-end responsiveness. All 1894 Flutter tests, 71 Python
tests, strict analysis and release web compilation passed. Saved v1/v2 and
three-/four-seat search retain their prior paths and budgets. Full size/player
strength qualification, human Expert strength and publication remain open.

The opening list was selected before outcomes; committed games were retained
across interruptions. The coordinator rejected mixed sources/binaries and never
qualified a partial run. Exact source hashes, proof reports and verification logs
are recorded in [the verification record](qa/ai-fix/verification.json).
