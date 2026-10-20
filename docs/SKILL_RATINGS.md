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
competition rank for equal established ratings; rank counts all established
records, including those outside the visible top 50. Provisional status lasts
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
AI IDs remain ai_shared-search-v1_<difficulty> and are shared across all users
and devices. Every eligible human/AI or mixed game changes these shared profiles
in both scopes; no ten-game human anchor or daily sampling gate applies to v3.
An engine strategy change requires a new engine identity.

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
