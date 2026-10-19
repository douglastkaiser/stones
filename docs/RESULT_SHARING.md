# Results, sharing, and placement Elo

Implemented 2026-10-19. This is the version 2 application result contract for
new unified matches. It covers Square and Hex with two to four seats.

## Standings

`MatchStandings` preserves the adjudicated winner, including road priority, in
first place. It ranks remaining seats by exposed ordinary flats. Standing
stones, caps and buried stones do not score. Equal counts share competition
rank: 1,2,2,4. A flat draw ties all leaders for first; an adjudicated road draw
ties the seats with roads for first. Other seats remain below those leaders.
Abandoned matches have no competitive standings. This adds multiplayer
placements to the Stones variant; official two-player Tak victory is unchanged.

`MatchConfig.ratingVersion` defaults to 2 for new configurations. Missing wire
metadata decodes to version 1, preserving old saves/rooms and their original
winner/loser-tie semantics. Already settled receipts are immutable and never
re-awarded. Achievements continue to use the actual game winner.

## Global human and AI ratings

Each shape, size, seat count, rules profile and clock category retains its
existing ladder. Every human and AI in an eligible version 2 match participates
in the same Elo update. AI identity is global per engine/difficulty:
`ai_shared-search-v1_easy`, `medium`, `hard`, or `expert`. These records are shared
across accounts and devices. Humans and AI appear in the default combined
leaderboard; optional All/Humans/AI filters change only presentation.

A higher placement scores 1 against an opponent, an equal placement 0.5, and a
lower placement 0. Average pair changes over the number of opponents, using
pre-transaction ratings, K=40 for the first 30 games then 20, nearest-integer
rounding and a floor of 100. Provisional ratings are marked for both kinds of
player until ten games. Global ranks count all established humans and AI,
including records outside the visible list; equal ratings share a rank.

If the same AI occupies several seats, compute its mean seat adjustment and
write its global profile once. Count each seat appearance in games and W/L/D,
and retain the match placements, representative seat, and appearance count in
history. Whole-game W/L/D is independent of pairwise Elo: a sole first place
wins, tied first places draw, and remaining seats lose.

Eligible local AI games bind the single human to the signed-in account when the
match starts; that binding is persisted with each save. Local hotseat games,
guests, Court, learning, abandonment, legacy Hex profiles, games shorter than an
opening cycle, and histories over 4096 individual moves are unrated. Online
human seats must have distinct owners and every signed-in human must confirm
the same full result. Timed AI games can qualify under their own clock ladder.
AI-only exhibitions remain unrated because they lack a human participant.

## Durable settlement and trust boundary

Version 2 votes agree on the move count, winner, termination reason, placements
and flat counts. One transaction reads current global profiles, then records
all participant updates, histories, a private immutable receipt, and the source
pointer. Receipts contain exact before/after ratings, so later shares do not
accidentally include changes from another game. Concurrent updates retry against
fresh profiles. A repeated source returns its original receipt without awarding
again. Pending peer confirmation and failed/retryable settlement remain visible.

Firestore rules validate identity, agreement, competition-rank shape, Elo
arithmetic, counters, historical deltas, source uniqueness and atomic settlement.
Checks are distributed between receipt, profile and history writes to fit the
Firestore expression/access budgets, including three copies of the same AI.
Rules do not replay arbitrary board histories. Clients replay confirmed moves;
online humans must agree, and local AI outcomes are player-device reports.
Modified clients or colluding players can fabricate reports. No remote AI,
Cloud Functions, billing upgrade, or independent execution attestation is added.

Legacy version 1 rooms and AI-sampling receipts retain their prior protocol for
compatibility; their old results do not acquire retrospective human Elo deltas.
Existing AI profile values/history are preserved as the starting global records.
An engine strategy change should use a new engine identity.

## Sharing

Completed matches expose Share result with a live, selectable preview. Public
player aliases identify opponents; AI labels include difficulty. Ambiguous local
hotseat results use neutral seat names. Repeated names/AI levels include seat
labels. Outcomes group every opponent into Lost to, Beat and Tied with clauses.

Default text has three lines: Stones/outcome; board/placement/reason/move count
and the sharer's signed Elo delta; then the canonical play URL. Positive,
negative and zero deltas are explicit. Pending/failed settlement says Elo
pending; practice says Unrated. Opening or refreshing the preview can retrieve
a settled receipt. The optional board image lists each participant's delta.

Duration is included only from frozen local clock banks or acknowledged online
board-finish timestamps. It describes consumed play-clock time, not waiting in
a lobby, time away, or time since opening the share dialog. Untimed games and
online concessions without a reliable end timestamp omit duration.

The maintained `share_plus` package supplies Android/native and Web Share
integration. Text message opens the platform SMS composer with an encoded body.
Copy result and Copy link remain available. Dismissal is normal; unsupported
sharing falls back to copy/selectable text. Web email fallbacks are disabled.

Include final board renders an independent, fixed-width PNG using the actual
board renderer, themes, final stacks and winning road. It excludes controls,
inspection and previews. The PNG is prepared before the share click, disposed
when converted, and regenerated when names or Elo change. Web supports direct
image download; native targets can accept the file through their share sheet.
Receiving apps control whether they retain both text and an attachment. The
website address is printed in the image as well as included in the text.

The link always opens https://www.douglastkaiser.com/stones/ . Open Graph and
Twitter metadata provide a standard site preview. Sharing does not publish a
private room code or create a public result/replay endpoint.

## Verification and rollout

Run `flutter analyze --fatal-infos`, `flutter test`, and the release web build.
The database suite is:

```sh
npx --yes firebase-tools@15.33.0 emulators:exec --only firestore \
  --project demo-stones-hex \
  'node --test --test-concurrency=1 tools/hex_rules/*.test.mjs'
```

`result_sharing_test.dart` covers placement, formatting, SMS and Elo mathematics;
`result_share_widget_test.dart` covers cancellation, fallbacks and actual Square/
Hex PNG encoding. `placement_ratings.test.mjs` checks real database authorization,
including mixed seats, repeated AI, ties, forged writes, concurrent global AI
updates, immutable deltas, duplicate completion and source ownership.

Publish qualified `firestore.rules` and `firestore.indexes.json` before the
version 2 client. The global-rank aggregate needs the new gamesPlayed/rating
index. Preserve Firebase configuration. Android uses AGP 8.12.1 for share_plus;
its existing Gradle 8.14.3 and Kotlin 2.2.20 remain compatible. A physical-device
share-sheet/SMS trial and real-account production settlement are separate from
emulator and headless-browser evidence. Record actual release evidence here;
source changes alone do not mean the production policy/client was published.

### Implementation verification (2026-10-19)

- Strict Flutter analysis: no issues.
- Full Flutter suite: 959 tests passed.
- Firestore emulator suite: 104 tests passed, including 23 placement-settlement
  tests; no failures or skipped tests.
- Web-release preparation script suite: 6 tests passed.
- Release JavaScript web build passed with `/stones/` as its base href.
- Android debug APK built successfully with the native sharing dependency.
- Chromium at a 390 × 844 viewport exercised a saved, legally completed game,
  copying the succinct result and canonical URL, unsupported-share fallback,
  and downloading the actual final-board PNG at 1080 × 1424 pixels.

The physical-device native share-sheet/SMS trial and real-account production
settlement remain unverified. Production rules, indexes and hosting were not
published: the Firebase CLI authentication probe failed because this workspace
has no authenticated Firebase identity. The client must not be published ahead
of its new rules and indexes.
