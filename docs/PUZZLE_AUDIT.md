# Puzzle contract and authoring audit

## Findings and repairs (2026-10-09)

The previous square library had six mostly 5×5 puzzles. Hidden guided-move
restrictions prevented exploring legal alternatives, and completion still
accepted a non-winning guided step when there were no scripted responses.
The longer puzzles demonstrated one authored sequence; that did not establish
a forced win against other defenses. The three Hex puzzles were all radius 2,
one duplicated an edge-connection tutorial, and deployed pieces were not deducted
from reserves. Neither library provided meaningful size/phase coverage.

The replacement library has **10 square and 7 Hex original composed studies**.
They are legal-inventory tactical positions, not claimed tournament positions
or reconstructed historical games. No publisher puzzle diagram or answer has
been copied. Historical reachability has not been established by replay witnesses.

The publisher's [Tak Companion Book](https://crabfragmentlabs.com/s/TakCompanionBookPDF.pdf),
printed pages 43–47, provides useful examples of short tactical objectives and
branched defenses. Square puzzles here use ordinary Tak adjudication. Hex studies
use only the experimental contract in [HEX_MODE.md](HEX_MODE.md); they are not
official Tak puzzles.

## What a win-in-N promise means

- Count the learner's completed legal moves, not previews or opponent turns.
- A terminal learner victory must occur within the limit. Draws, losses,
  exhausting the budget, and following a hint without winning do not complete it.
- Accept every legal attempt and every genuine alternative solution. A puzzle
  does not secretly enforce the move printed in its hint.
- A winning first move is proved against **every legal opponent reply**.
  Square is existential/universal search. In Hex, both intervening seats are
  universal: the promise survives any pair of defenses, even coordinated ones.
  This conservative puzzle contract does not change competitive Hex AI or rules.
- Multi-move studies have no immediate win, so their advertised second move
  is necessary. The current runtime certificates support one- and two-move
  studies; adding deeper studies requires a policy for every later decision.
- Incorrect first moves receive a proven refutation. Correct first moves receive
  a representative defense selected to reduce immediate finishing threats.
  Final learner moves are adjudicated normally, rather than checked against a
  preselected answer string.
- An exhausted proof resource limit is **unknown**, not success. Missing or
  illegal runtime responses stop the attempt with retry feedback; ordinary
  heuristic AI cannot silently replace a certified defense.

Search uses `GameRules`/the complete square move generator and `HexRules`.
It includes all available piece types, pickups, directions, drop distributions,
captures, crushes, road priority, reserve exhaustion and flat endings. This is
exhaustive within the stated horizon, not a claim of perfect long-game play.
The proof depends on the shared legality implementation; independent gameplay
provider replay tests check square adjudication agreement as an additional guard.

No exhaustive search runs during puzzle interaction. Checked-in certificates
contain every legal initial move's response, all winning roots, and a sample line.
Normal tests recompute and compare those certificates without rewriting files.

## Progression and coverage

Difficulty labels are editorial estimates, not measured human solve ratings.
Size alone is not difficulty: precision, concealed layers, competing outcomes,
and the number of defensive turns matter. Studies remain freely selectable;
numbers and ordering recommend a path without preventing revisits.

| Square | Size | Phase | Moves | Winning first moves / legal | Main challenge |
|---|---:|---|---:|---:|---|
| 1. A short connection | 3 | Early | 1 | 1 / 15 | Read opposite edges |
| 2. Around the corner | 4 | Middle | 1 | 1 / 35 | Capture and retain source |
| 3. The buried connection | 5 | Middle | 1 | 1 / 85 | Pickup depth and crush |
| 4. A move before the win | 3 | Early | 2 | 2 / 18 | Independent threats |
| 5. Four in hand | 6 | Middle | 1 | 1 / 159 | Mixed colors; precise drops |
| 6. Two directions | 4 | Middle | 2 | 2 / 37 | Capture creates a fork |
| 7. Both roads | 4 | Middle | 1 | 1 / 39 | Black learner; simultaneous roads |
| 8. Through resistance | 5 | Middle | 2 | 1 / 55 | Crush preserves both threats |
| 9. A wider crossing | 7 | Middle | 2 | 1 / 149 | Extra capstone defenses |
| 10. The final count | 8 | Endgame | 1 | 1 / 37 | Fill board, retain a scoring top |

| Hex | Radius | Learner | Phase | Moves | Winning / legal | Main challenge |
|---|---:|---|---|---:|---:|---|
| 1. A winding route | 2 | Ivory | Early | 1 | 4 / 67 | Bending capture routes; alternatives |
| 2. A guarded passage | 2 | Charcoal | Middle | 1 | 1 / 44 | Crush the blocked crossing |
| 3. Layers of copper | 3 | Copper | Middle | 1 | 1 / 180 | Buried color and drop order |
| 4. Across the court | 4 | Ivory | Middle | 1 | 1 / 384 | Four-piece mixed spread |
| 5. After both opponents | 2 | Charcoal | Early | 2 | 7 / 58 | Shared-pair threats survive two replies |
| 6. Three ways through | 3 | Copper | Middle | 2 | 1 / 106 | Crush into three threats |
| 7. One last distribution | 4 | Ivory | Endgame | 1 | 1 / 43 | Three-seat flat count |

Early play means development **after** the opening exchange. The exchange itself
remains an interactive tutorial. We do not claim there is a uniquely correct
opening placement without a proved objective. Initial supplies account for
every buried and exposed stone, with no artificial zero-reserve overrides.

## UX questions and current answers

1. Can I tell my seat, edges, goal and budget before moving? The objective names
   the learner, counts only their moves, and displays used/allowed moves.
2. Does the title give away the exact answer? Titles identify studies; concrete
   coordinates and distributions appear only in optional hints.
3. Can I investigate a plausible wrong move? Yes. Legal moves apply; the opponent
   refutes the objective rather than a hidden guide rejecting the input.
4. Does a second valid solution work? Yes; all roots and final legal wins count.
5. Does “in two” survive a competent opponent? All legal defenses are proved,
   including both Hex turns. The visible response targets finishing threats.
6. Is an apparently good move actually a draw or opponent win? Adjudication,
   mover priority and flat counts are included, and only learner wins complete.
7. Does the puzzle penalize time spent thinking? No. Square learning is untimed
   even when the saved match-clock preference is enabled.
8. Can I learn without immediately spoiling the move? Hints reveal an idea first,
   then a concrete direction. Revealing the next hint is a separate action.
9. Can I restart safely? Retry clears the board, budget, response and move history.
   Puzzle undo is disabled to prevent history/budget disagreement.
10. Can I see what both Hex opponents did? Their move descriptions appear after
    the automatic replies; only human decisions consume the budget.
11. Is failure clear and recoverable? Terminal failures and exhausted budgets
    stop input, show an explanation and leave Retry available.
12. Does completion explain the tactic? Every study has a post-solve explanation.
13. Is progress honest after replacing old content? New study IDs do not inherit
    old solves. Stored achievements/old IDs are preserved; current puzzle counts
    intersect the current catalog so old IDs cannot inflate the denominator.
14. Are small screens and large text supported? Widget coverage includes 320px
    phones, desktop layouts, scrolling controls and enlarged Hex text.
15. Is the library genuinely progressively harder for humans? Mechanically it
    increases tactical demands. Human solve times, hint use and frustration still
    need playtesting; no fabricated difficulty calibration is presented.

## Maintaining quality

Verification on 2026-10-09: all 342 Flutter tests passed, including exhaustive
proofs for all 17 studies, contract checks, and 18 phone/desktop puzzle widget
tests. Strict analysis reported no issues and the JavaScript release built.
The release browser accepted square study 4's alternate first move and actual
road win. Hex study 5 played both defensive replies, accepted the remaining
finish, showed progressive hints, and reset correctly with Retry. At 320×568,
the Hex board and completion controls fit and remain reachable by scrolling.
Square preview controls fit at the same phone size; confirmed moves and Retry
reset the board and counted budget correctly in the release browser.
Physical-device timings and human difficulty calibration remain unverified.

`square_studies.dart` and `hex_studies.dart` are the authored source of truth.
`test/audit/puzzle_authoring_test.dart` is the exhaustive verifier and opt-in
certificate generator. To change a position, regenerate the **entire** catalog:

```powershell
$env:STONES_AUTHOR_PUZZLES='1'
flutter test --concurrency=1 test/audit/puzzle_authoring_test.dart
Remove-Item Env:STONES_AUTHOR_PUZZLES
dart format lib/puzzles/certificates.dart
flutter test
flutter analyze --fatal-infos
```

Run without that environment variable to verify checked-in certificates.
Generation refuses a filtered or failed run; the complete catalog must pass
before the certificate file is replaced.
Model tests check inventory, initial nonterminal positions, phase/size/seat
coverage, minimum forced depth, refutations and certificate freshness. Sample
lines also run through gameplay. Widget tests exercise real preview/confirm,
alternate roots, legal wrong attempts, untimed play, retry, hints and progress.

Further quality work: human calibration, deeper full decision-tree policies,
replay-backed match puzzles, a visual line viewer, and more diverse defensive
motifs. Add fewer verified studies rather than padding the library with variations
whose tactical claim has not been established.

## Shared Hex goals, 2026-10-09

All seven Hex studies were exhaustively re-proved with every color eligible for
all three opposite-side pairs. Two-move studies still have no one-move solution
and survive every legal reply from both opponents. Study 5 now has seven valid
roots instead of two; the regenerated certificates accept them all. Other counts
remain as listed above. New `hex_v2_study_*` IDs keep legacy completions separate.
The square studies and their proof results are unchanged.
