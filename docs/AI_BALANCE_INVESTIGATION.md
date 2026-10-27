# Hex initiative and AI ordering — 2026-10-26

Applies to **LEARN-01** and **PLAN-10**. The small Hex results reveal both an
opening/initiative effect and avoidable defensive mistakes. They do not establish
that the game is a forced first-player win. No rules or CI thresholds were changed
to accommodate these results.

## What the paired scores actually mean

The latest native deterministic radius-2 Hex samples used five opening seeds,
with the two difficulty assignments swapped for each seed:

| Matchup | Stronger wins–losses | Starter wins | Paired explanation |
| --- | --- | --- | --- |
| Hard / Medium | 5–5 | 8/10 | Four openings swept by the starter; one swept by the second seat |
| Expert / Hard | 5–5 | 10/10 | All five openings swept by the starter |

Thus the 5–5 scores are not alternating evidence that the tiers are equally
strong. Within each opening, the same seat wins after the levels swap. Giving
each tier the advantaged seat once mechanically produces equal totals. A stronger
AI has not demonstrated that it can overcome those positions under these budgets.
The required ordering tests correctly fail their strict per-board gate.

These are five openings, not ten independent samples of starting advantage.
Replaying the same deterministic opening also does not supply a new independent
trial. Default play uses no RNG, although wall-clock cutoffs can change which
iteration finishes and therefore the move chosen.

## Controls: starting role, opening and policy

Current Expert-versus-itself play covered three seeded openings, repeated with
both worker assignments. The starter won both repeats on seeds 0 and 2, while
the second seat won both on seed 1: four starter wins in six games, but only three
distinct openings. Expert self-play's seed-1 winner differs from the mixed-tier
sample. This implicates the interaction between opening and search policy,
rather than proving a fixed winning side for that opening under perfect play.

Reversing the starting color on seed 0 gave Charcoal both wins instead of Ivory.
One color-swapped replay was identical in coordinates and piece types; the other
diverged later under timed search but retained the starting-role winner. This
small control supports initiative rather than a hardcoded Ivory preference.
A regression also checks color/starter symmetry of legal transitions and static
evaluation on both geometries. Two repeats of the normal AI-controlled Hex
opening likewise went to the starter. These controls are exploratory, with no
confidence claim about the population of all openings.

## Why small Hex amplifies the problem

Radius-2 Hex has 19 cells, six neighbors per interior cell, and three opposing-edge
road axes. Square 5 has 25 cells, four neighbors, and two road axes. Both require
at least five road stones. On Hex, a well-connected protected capstone can support
several simultaneous routes on a smaller board.

The opening places opponents' flats. Afterwards, the starter can first own five
stones at the ninth individual move; the second seat reaches five at the tenth.
A pure placement race therefore gives the starter the first possible five-stone
road. Defense must interrupt that race before multiple winning continuations
appear. This is a structural reason to measure starting advantage, not a proof
that the starter wins: stacks, walls, captures and capstones permit defense.
The strategy-stealing result for conventional Hex does not directly apply to this
Tak variant.

## Exact counterfactual: a quick loss was avoidable

An independent bounded minimax tool enumerates legal replies, without the AI's
evaluator or selective beam. It reports `unknown` on resource exhaustion. Its
finite-horizon objective is whether Ivory can force a win by the recorded ninth
move; refuting that objective does not prove a draw or a Charcoal win eventually.

In a recorded nine-move loss, Ivory deployed a cap at `(0,1)` and later produced
two simultaneous road gaps. Once that double threat existed it was genuinely
too late. Earlier defenses changed the outcome of the exact bounded objective:

| Position / Charcoal move | Ivory can force that quick win? | Expanded nodes |
| --- | --- | --- |
| After five moves, the recorded flat at `(0,0)` | Proven yes, within the next three moves after it | 199 |
| Same position, a flat at `(1,0)` | Refuted | 127 |
| After three moves, cap at `(1,0)` | Refuted within the next five moves after it | 1,088 |

An ordinary flat suffices in the second comparison. The lesson is earlier
recognition of opposing connectivity and defensive tempo, rather than delaying
capstones or prescribing a particular opening. The current engine still uses
selective root/reply sets: more depth can miss a quiet preventive defense that
falls outside those sets. Exact late-threat detection alone cannot repair every
earlier selection mistake.

The static terms explain why this quiet defense is easy to undervalue. Both flats
receive identical road scores for both players: `−160` for Ivory and `−160` for
Charcoal. They also have identical flat/material terms. The recorded central
move receives ten more development points, producing utility `6.9889` versus
`−3.0111` for the defensive flat. The evaluator sees the same shortest-road cost
but misses the difference in surviving opposing continuations demonstrated by
the exact proof. A general measure of road redundancy or vulnerability is a
better next evaluation experiment than a capstone deployment penalty. Its weight
still needs game-based validation; removing connected-development value outright
would discard a useful fundamental without that evidence.

An isolated replay of this exact position with the current native Hard retained
the defensive flat among its twelve roots. It nevertheless timed out after the
mandatory one-round baseline and returned the recorded greedy move. The baseline
assigned utilities `−197.6667` and `−118.1111` respectively. This instance therefore
also exposes insufficient completed planning, rather than demonstrating that the
defensive root itself was discarded. These selective-baseline numbers are not
exact minimax values; the independent bounded proof supplies the tactical result.

## Changes supported by the investigation

The engine now distinguishes a quiet horizon from a proven undefendable threat,
and preserves terminal draws as defenses. Exact stone-count pruning removes
impossible winning spreads while retaining every possible winning move, helping
the richer reply model complete more search. Its flat-ending bound also accounts
for spreads filling several empty cells. Expert establishes completed narrow
iterations before widening; Medium uses its existing budget for a second duel
round instead of a scripted weaker alternative.

On one recorded defensive position the optimized Hard completed two rounds where
the earlier implementation completed one. The current Expert won 4–0 against a
frozen earlier Expert over two development seeds and both seats. These are small
exploratory checks, not held-out strength or timing qualification. A competing
optimization that narrowed all duel reply beams lost 0–4 and was rejected.

Early caps themselves have not been shown to be a weakness. The static deployed
cap bonus is five points, but removing that deployment incentive with reserve
credit lost 0–2 in an isolated pilot; the variant still deployed early. There is
no capstone timing rule in the implementation. Better evaluation and search
coverage of competing routes is the appropriate next experiment.

## What remains open

Keep measuring starter/second-seat outcomes per opening alongside tier outcomes.
The CI artifacts now include those reports; the full manual suite retains its
held-out seeds and stricter gates. Neither weakening a gate nor adding randomness
would establish the missing tier separation. Experimental randomness remains
opt-in pending separate diversity, timing and no-regression evidence.

Before changing game balance, expand equal-strength self-play across independent
openings, starting colors and search budgets, and compare against a less selective
reference. If an initiative bias survives stronger defense, opening restrictions
or a swap mechanism could be evaluated as separate rules experiments. Flat-score
komi would not directly address the road wins observed here. No such rules
change is included.

[Evidence record](qa/ai-balance-investigation.json) retains binary/source/runtime
provenance, replay hashes, per-game outcomes, exact proof reports and the short
proof replay. Full local replays are under `build/qa/ai-strength/`; CI uploads its
own replays. Reproduce a bounded counterfactual with:

```sh
dart run tools/ai_balance_proof.dart \
  --replay=docs/qa/ai-balance-hex-counterexample.jsonl --game=0 --ply=5 \
  --plies=4 --after=1,0:flat --attacker=ivory
python3 scripts/ai_balance_report.py PATH --output=/tmp/balance.json
dart run tools/ai_explain.dart \
  --replay=docs/qa/ai-balance-hex-counterexample.jsonl --game=0 --ply=5 \
  --compare=1,0:flat
```

The proof tool is diagnostic, not part of production decision making.
