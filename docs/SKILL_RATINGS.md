# Overall and format skill ratings (version 3)

New unified configurations use ratingVersion 3. Each eligible game contributes
once to Overall and once to its exact format (shape, size, seat count, rules
profile and clock category). Overall is calculated directly from game outcomes,
not by averaging a player's format ratings. Learning, Court, anonymous users,
unowned/shared human seats, abandonment and legacy Hex
remain unrated. Existing replay, identity binding and opening-length checks
continue to apply. Game AI runs on participants' devices; Firebase remains Spark.

## Outcomes and multiplayer UX

A decisive game has one winner and unordered losses for everyone else. Exposed
flats still adjudicate a flat victory but do not rank the other seats. Result
sharing says Won/Lost, with no second/third-place awards or claims that losers
beat/drew one another. An adjudicated draw counts as a draw for every seat.
This keeps players focused on contesting the win rather than accumulating flats
for a consolation placement. Core Tak road priority and flat adjudication are
unchanged; this is an application rating/result policy.

Only winner-versus-loser comparisons inform a decisive rating update. There are
no inferred draw observations between losing seats. Each comparison carries
weight 1/(seat count - 1). An equal-strength winner receives a duel's worth of
evidence; an individual loss in a larger game has proportionally less impact.
Different prior strengths and uncertainties can produce different loss amounts.

## Mathematics and display

The model is a weighted Glicko-1 adaptation, not Microsoft TrueSkill/TrueSkill 2.
See [Glickman's specification](https://www.glicko.net/glicko/glicko.pdf).
All estimates start at mean 1200 and rating deviation (RD) 350. A game's
observations use only pre-transaction estimates. For an observation with score
s, opponent mean rj, RDj, weight w, and own mean r/RD:

```
q = ln(10) / 400
g = 1 / sqrt(1 + 3*q*q*RDj*RDj / (pi*pi))
E = 1 / (1 + 10^(-g*(r-rj)/400))
gradient = sum(w*g*(s-E))
information = sum(w*g*g*E*(1-E))
variance = 1 / (1/(RD*RD) + q*q*information)
new mean = r + q*variance*gradient
new RD = max(50, sqrt(variance))
```

Scores are 1/0 for an observed win/loss and 0.5 for a genuine drawn game.
The numerical implementation matches the published 1500/200 reference example
(1464.106 mean, 151.399 RD). RD has a floor of 50 to retain responsiveness.
There is no passive inactivity aging or scheduled background rewriting: displayed
intervals describe the estimate at its last rated result. No performance-stat,
flat-margin or mode-transfer learning is claimed.

Public ratings are rounded means. Leaderboards sort by that rating, with
competition rank for equal established human ratings; rank counts established
human records, including those outside the visible top 50. AI remain interleaved
by rating but neither receive nor consume human rank numbers. Home, standings,
player labels and human profiles use the same human-only policy. Provisional status lasts
at least ten distinct matches and until RD is at most 150. Provisional entries
remain visible with a question mark but have no official rank. The approximate
95% skill interval is mean +/- 1.96*RD; profiles and leaderboard rows show it,
and history charts shade its evolution. It is a skill interval, not a confidence
interval for leaderboard position. All/Humans/AI filters affect presentation.
The default Overall selector reveals the existing format controls when By format
is chosen. The leaderboard subscribes to top-player and shared-AI snapshots;
account/scope changes and screen disposal cancel old listeners.

## Shared AI identities

Humans and AI use exactly the same model and eligibility/calibration thresholds.
Current AI rating IDs remain ai_shared-search-v2_<difficulty>, shared across
all users and devices. The v3 engine continues those existing ratings, game counts
and uncertainty rather than starting new profiles; subsequent results adjust
strength over time. Historical v1 profiles remain separate. Saved games and
immutable result receipts retain their actual v1/v2/v3 engine configuration.
New skill-history entries also store aiEngine, and AI profiles label the engine
used for each result. Older entries lacking that field stay unlabelled; no engine
is guessed and no historical receipt is rewritten. Every eligible human/AI or
mixed game changes these shared profiles in both scopes; no ten-game human
anchor or daily sampling gate applies to version-3 skill ratings.

The rating-continuity policy explicitly follows the owner's 2026-10-23 direction:
update the AI and let ratings settle while retaining per-game engine versions.
It supersedes the earlier policy of creating a rating identity for every strategy
change. Game engine versions remain distinct; v2/v3 rating identities are shared.

If an AI occupies multiple seats, average its seat evidence and skip comparisons
against its own identity. Write one posterior and count one match, with one
whole-identity W/L/D result: win if one of its seats won, draw for a drawn game,
otherwise loss. History records the number of appearances. This avoids treating
several copies as independent calibration matches or manufacturing confidence
from self-play.

AI-only games use this same version 3 model in Overall and the exact format.
The signed-in player who started the local game is its reporter, bound by the
saved session UID and immutable source pointer; the reporter is not a competing
seat and receives no rating or achievement. Only actual AI identities appear in
the participant list. Two-to-four-seat games, timed outcomes and genuine draws
use the normal settlement policy. Anonymous games and older rating protocols
retain their existing eligibility. A match containing only copies of one shared
AI still records one match for that identity, with no self-comparison or change
in mean/uncertainty. Replaying or reopening the same source cannot rate it twice.

Authorization must permit the original reporter to read/finish both scope
receipts without granting another observer access. Tests cover eligible replays,
identity mismatch, altered moves, duplicate and partial settlement, both scopes,
forged identities/counters, unrelated reporters and anonymous writes.

## Confirmation, atomicity and recovery

The immutable /ratingResults/{randomKey} source has kind skill/version 3. It
binds configuration, participants, outcome, aliases, ply and source identity.
Online participants each cast their own v3 vote; all independent human owners
must agree before the source and room pointer can be frozen. A local AI source
is bound to the signed-in reporter and its immutable /aiResultKeys source pointer.
Rules validate local configuration at that pointer write; online configuration
is bound to the already validated room. Keep these complementary checks.

Each scope settles in a separate transaction:

- /skillSettlements/{randomKey}/scopes/{scope}: immutable before/after mean/RD,
  source, scope and server timestamp.
- /skillPools/{scope}/players/{identity}: current mean/RD, rounded rating,
  counters, calibration, alias and last-result pointer.
- The profile's /history/{gameNumber}: exact rounded before/after/delta, mean/RD,
  score and appearance metadata.

Each scope transaction reads current profiles before computing anything and
updates every distinct participant, its history and the scope receipt atomically.
Rules distribute checks across source, profile, history and receipt writes to
stay within Spark expression/document-access limits. They independently check
math (within 1e-6), uncertainty, counters, identities, exact allowed scopes and
complete writes. Histories/receipts cannot be rewritten; a source cannot settle
twice in one scope. Concurrent games retry against fresh shared AI/human records.

Overall and format are independently durable, so a connection failure may leave
one pending. The UI retains confirmed deltas and explicitly marks the other
pending. Reopening the result/room retries; it reads any existing receipt without
awarding again. There is no cloud worker to finish when all clients close.
Result text/PNG uses the match's immutable deltas, never differences between
live profile values. Source/evidence and scope receipts are participant-private;
public profiles/history contain random receipt keys, not invitation codes.

The existing community trust boundary remains: clients replay legal histories,
online humans agree, and rules enforce protocol/arithmetic. Rules cannot attest
on-device AI execution or independently replay arbitrary board games. Modified
local clients or colluding accounts can fabricate reports. No server-verified
competition or bot execution claim is made.

## Compatibility and rollout

Missing ratingVersion still decodes to version 1; explicit version 2 preserves
placement Elo and result wording. Their settlement code and /ratingPools data
remain intact. Already issued receipts/history are immutable and are not
reinterpreted or replayed. Version 3 uses a fresh /skillPools namespace for both
humans and AI, with broad initial uncertainty; no legacy Elo is imported as
established skill. Old clients continue using their old protocol. The current
Competition UI reads v3 skill ladders; legacy data remains in its original
namespace and is not mixed into the new graphs.

Deploy qualified firestore.rules and firestore.indexes.json before the new
client. Required players indexes include established ASC/rating ASC and DESC.
Use the existing Firebase project/configuration; no billing upgrade, Cloud
Functions, hosted AI or new rating service is part of this change. Source changes
and local emulator checks do not publish production policy or clients.

Verification commands:

```
flutter analyze --fatal-infos
flutter test
flutter build web --release --base-href /stones/
npx --yes firebase-tools@15.33.0 emulators:exec --only firestore \
  --project demo-stones-hex \
  'node --test --test-concurrency=1 tools/hex_rules/*.test.mjs'
```

Tests cover the published numerical example, unordered losses, genuine draws,
seat permutation, repeated AI, uncertainty floors/serialization, v1/v2 decoding,
live updates and scope switching, phone/large-text profiles, both scopes,
concurrent/stale AI updates, duplicate settlement, delayed recovery, forged
ratings/uncertainty/counters/history, source ownership and receipt privacy.
Real signed-in multi-account production settlement and physical-device viewing
remain release checks after policy/index deployment.

## Local qualification (2026-10-19)

The finished working tree passed all **977 Flutter tests** with concurrency 2,
strict `flutter analyze --no-pub --fatal-infos` with no issues, all **130 real
Firestore emulator authorization checks** (including 26 v3 checks and the
unchanged legacy suites), and the release web build with base href /stones/.
Toolchain: Flutter 3.47.7 / Dart 3.13.5, Node 24.19.0, Java 21,
firebase-tools 15.33.0 / Firestore emulator 1.22.0.

Live-listener coverage additionally verifies that late rank replies cannot
replace newer standings. Public live queries require server-confirmed snapshots;
an empty offline cache cannot clear a read failure or masquerade as an empty
ladder. Generated SDK/build files and the SDK's analyzer-configuration rewrite
are excluded from the change. Existing Firebase configuration is preserved.

That local qualification did not publish production rules/index/client changes,
a store release or physical-device qualification. Publish the rules/indexes before promoting the
version 3 client, then perform signed-in production result/recovery trials.


## Production Firebase publication (2026-10-19)

The owner explicitly authorized Firebase publication and completed the official
Firebase CLI remote Google sign-in. The target was stones-9a6a0, default database.
The existing production rules and index metadata were backed up before deployment.
No production game or rating records were seeded or rewritten.

The tested rules/index files were published using firebase-tools 15.33.0:

```
firebase deploy --project stones-9a6a0 --only firestore:rules,firestore:indexes --non-interactive
```

The rules release was updated at 2026-10-19T23:31:32.572762Z to ruleset
971cd735-72ca-4718-9cc4-389ee799c0c2. Readback exactly matched the tested rules
SHA-256 bb85b2c1ff8292f3eac7e9ecc36f3d51e37e622992e514e3a0c619c150ee2caf.
The deployed index configuration SHA-256 was
cbfc3169c136616658d9f381a414cc376c19556ea402da4188128488cf8419bb.
The prior ruleset e158e086-b1d8-4208-adc3-3fecaa05ecc5 is retained for rollback.

Both existing composite indexes were preserved. All five configured composite
indexes were confirmed READY at 2026-10-19T23:36:48.013Z. Anonymous production
REST checks passed for leaderboard, aggregate rank and AI reads in the overall,
square-5-2-standardTak-open and hex-2-3-sharedRoads-open pools. Public enumeration
of result sources, settlement receipts and AI result keys was denied. These
checks did not write or change any player records or game data.

This publication changes the Firebase backend. The version 3 web/Android client
has not been published by this action. Real signed-in result settlement and
physical-device qualification remain separate release checks.


## Ranking and large-board AI follow-up (2026-10-23)

ACCOUNT-03/04: the server rank aggregate now excludes AI, matching the local
human competition-rank calculation. AI rows and profiles show ratings without a
human rank. “Your standing” opens the signed-in player’s profile for the selected
pool, including a not-yet-rated account. Existing isAi/established/rating composite
indexes cover the query; this change adds no index requirement.

LEARN-01/COMPAT-06: new configurations use shared-search-v3. It adds a small
connected-road/central-access preference below the primary road-distance score.
Multiplayer considers each rival's score instead of only the maximum, and adds
nonlinear urgency for near-complete roads. Winning/blocking placements are
examined before unrelated moves; known immediate placement threats cannot be
ignored by the positional fallback if the full defense pass times out. The
full pass continues to cover stack-spread wins and defenses.
Existing v1/v2 saves keep their strategy and recorded engine version. New v3
skill results use the existing v2 rating IDs, carrying forward mean/RD, counters
and history; the game/receipt engine remains v3. New history writes are bound to
the receipt's engine by security rules. Old v1/v2 clients may omit the new history
field, while v3 receipts require it. Geometry-indexed shortest paths reuse
neighbor and boundary tables, avoid repeated Cell-map traversal and allocate distance buckets
only when used. This optimization retains path costs for every supported size.

Before changes, four sparse central-development fixtures (Hard/Expert, Square 8
and Hex radius 4) all scattered material. With v3 all four extend the central
road. In the same local native/JIT run, the Hex Expert fixture changed from
2.2 seconds/depth 2/timeout to about 0.5 seconds/depth 3; this is one diagnostic
position, not a browser/device benchmark or a general playing-strength claim.
Regression coverage also includes immediate wins/blocks at the largest sizes,
independent shortest-path comparison, old configuration roundtrips and v2/v3
rating continuity with explicit game engine metadata. A specific three-seat radius-4 fixture covers
Medium/Hard/Expert responding to a leading rival's two-move approach. With
full-round lookahead the regression checks the complete table cycle: the leading
road must not progress uncontested, allowing a later rival's defense or a leader
changing its plan instead of prescribing which player blocks on the first move.

A full native Dart/JIT engine trial used the reported setup: Hex radius 4,
three AI seats in Medium/Hard/Expert order, Ivory starting. Before the subsequent full-round lookahead update,
the working-tree engine finished at ply 159 with Expert/Copper winning by road.
The probe counted 102 opposing-top captures and 58 increases in a rival's
previously two/three-move road distance; no board/reserve/side-to-move position
repeated (maximum count 1). All moves were applied through MatchRules. It took
about 153 seconds locally. This is one full-game qualification, not a strength
ranking or browser/device acceptance result.

Publication prerequisite: deploy the updated Firestore engine allowlist before
publishing a client that creates v3 online games or submits v3 AI results.
This working-tree change does not establish backend/client publication, browser
usability acceptance, physical-device timing or broad strategy qualification.


Local verification used Flutter 3.47.7 / Dart 3.13.5 on Linux. The AI/ranking
checkpoint passed the full 1,687-test Flutter suite. After the owner's final
rating-continuity direction, all 72 affected rating/feedback/review tests and
31 match-screen/completed-history tests passed, including engine-history labels
on a 320px phone at 200% text. The full suite was not repeated after that final
identity/history update. All 146 Firestore emulator authorization checks,
strict analysis and the release web build passed. Formatting and diff checks
passed. No production data was migrated or written; browser/physical-device
acceptance and publication remain unverified.


## Full-round AI lookahead (2026-10-23)

LEARN-01: the owner clarified that a lookahead of one means one round, including
every opponent before the AI's next turn. Unreleased v3 now uses round targets
of 1/1/2/3 for Easy/Medium/Hard/Expert; saved v1/v2 searches retain their original
strategy. This changes no rating identity or per-game version policy.

Every nonterminal, uncancelled choice completes a selective first-round baseline,
even if initial ranking/defense consumes the refinement deadline. It evaluates
up to the tier's root width, then one plausible reply by each other seat in the
actual turn order. Each reply samples at most 48 legal moves, prioritizing
immediate winning/blocking placements, connected/central candidates and short
stack spreads (up to three stones in this mandatory sample). A terminal result
ends a line earlier. The baseline uses bounded work and cooperative yielding;
it may extend past the normal wall-clock deadline to finish the round. It is
not exhaustive examination of every legal response combination.

Easy's former positional-only shortcut is removed for v3. Its variation is
limited to near-equal choices already evaluated over a complete round. Other
tiers refine the first round and attempt deeper whole rounds under their
existing time budget; completed results replace the baseline only after every
root in the iteration finishes. Refinements retain full legal carry generation.
Hard/Expert round counts are targets, not guaranteed completed depth on all
boards/devices. Search statistics now distinguish completed rounds, individual
moves and the seats actually considered by the baseline.

Regression requirements include every tier at two-to-four seats on both shapes,
Easy with rotated starters, forced deadline exhaustion on the maximum boards,
cancellation, legacy v2 Easy behavior, existing tactical/fork checks, legal
full-match playthroughs and the maximum-board full-round road response.


The final round-search change passed 198 focused AI regressions, including all
60 new round/seat/deadline/cancellation checks and the existing tactics, forced
fork, largest-board and complete-match checks. Strict analysis, Dart formatting,
diff checks and the release web build passed on Flutter 3.47.7 / Dart 3.13.5,
Linux. The full unrelated application suite was not repeated for this follow-up.

A native engine stress trial on radius-4 Hex with four Easy seats applied 240
legal moves; all 240 choices covered a complete round and all four seats. It
recorded 155 opposing-top captures and remained unfinished when the trial stopped.
On the host running concurrent tests/builds, total time was about 86 seconds and
the slowest choice about 1.1 seconds, illustrating the baseline's soft deadline;
this is not a browser/device latency or game-completion qualification. Physical
and browser responsiveness/strength acceptance remain open. Nothing was deployed.

The subsequent five-part AI upgrade implementation, frozen reference engine,
repetition context, material-weight limits and qualification commands are recorded
in [AI upgrades](AI_UPGRADES.md). That audit distinguishes the latest verification
from these earlier round-search probes.

## Hosted ranking diagnosis (2026-10-23)

A fresh read of the production `release-manifest.json` returned source
`56cb6fbd3b46c0a5ddb1ae383b1a77bb931f08c1`. This predates the human-only
rank and personal-card navigation fix in `7e0cd72`; the reported off-by-one
rank and unclickable card are consistent with that older client. Before the
fix, both `competitionRank` and the server aggregate counted established AI.
One established AI above a human therefore adds one to their displayed rank.
The source fix preserves mixed rating order and excludes AI from both counts.
The personal card and the own leaderboard row both open `PlayerDetailScreen`.

ACCOUNT-03/04 regression coverage now additionally checks multiple interleaved
AI, human ties, provisional exclusion and stable numbering through all three
filters. Existing journeys check home → standings → own profile and an unrated
account in the selected format. No additional runtime change is needed for
these reported symptoms. Publication is still separate from source verification;
the v3 Firestore prerequisite and manual Deploy Main process above still apply.

Verification for this diagnosis: all 28 tests in
`test/ratings/rating_system_test.dart` and
`test/ratings/skill_leaderboard_test.dart` passed on Linux with Flutter 3.47.7 /
Dart 3.13.5. Strict analysis (`flutter analyze --fatal-infos`) also passed.
This includes the same-account/same-ladder navigation assertion
for the personal card and own row. Hosted evidence is the read-only production
manifest, not a new deployment or browser/device acceptance trial.
