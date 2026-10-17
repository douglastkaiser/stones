# Ratings and competition audit

## Findings (2026-10-16)

The old client wrote both players and shared AI documents, accepted arbitrary
scores, and had no match receipt. A batch did not protect the read/compute/write
sequence from concurrent games. Each device could award the same online result.
History writes were separate and failures disappeared into debug logs. Firebase
rules deny those collections, while the UI fabricated AI entries at 800/1100/1400/
1700 and cleared errors. Offline cached identity was a single device-wide `local`
record. Google identity and Play Games identity were mixed. New unified matches
never invoked the old rating hook. Leaderboard positions were indexes in a top-50
mixed list, rather than a defined human competition rank. No rating tests existed.
Old data cannot be promoted into a trusted competitive ladder.

## Implementation contract

- New versioned ladders, partitioned by shape, size, seat count, rules and clock
  category. Rating means strength within a Stones pool, never a chess rating.
- Human competition requires independently owned seats and nonanonymous accounts.
  Local/shared-device/Court/learning games are unrated. Online completed histories
  are replayed on the server using the same Dart MatchRules as gameplay.
- One atomic transaction updates every participant, deterministic history entries
  and a unique match receipt. Retries and duplicate client observations are safe.
- Multiplayer Elo averages comparisons against opponents: sole winner beats each
  rival, losing rivals tie one another; a whole-game draw ties every pair. All
  deltas use pre-game ratings and total influence is normalized by opponents.
- All entities start from the same neutral prior. Fewer than ten games is
  provisional; no games means Unrated. Competitive human rank excludes bots and
  provisional players and uses competition ranking (equal ratings share rank).
- AI does not award human competitive points. Untimed AI duel calibration must be attributed
  to a particular engine revision and use server-generated moves, actual outcomes
  and established human opponents in the corresponding pool. No assumed
  difficulty-to-Elo mapping. An empty sample is explicitly Uncalibrated.
- Accounts are the identity source. Signing out/switching accounts clears visible
  personal data immediately; late requests cannot repaint a previous identity.
- Public leaderboards expose display names, ratings and W/L/D, never email.
  Clients cannot write rating totals, receipts, histories or calibration evidence.
- Errors, stale data and unavailable deployment are visible. Never invent entries
  or silently present a network failure as an empty successful leaderboard.

## Execution and qualification

1. Replace the unsafe client writer and fake fallback with a read-only,
   account-scoped rating repository and identity-safe provider.
2. Implement the shared server verifier and atomic rating processor, with an
   authenticated AI move service that records verifiable calibration evidence.
3. Display pool-specific ratings on accounts and match seats; rebuild competition
   and AI views with provisional status, exact rank and rating history.
4. Add model, identity/race, transaction/idempotency, verifier and responsive UI
   regressions. Run full Flutter analysis/tests, Node backend tests and builds.
5. Publish backend and read-only rules only after qualification; verify actual
   production behavior before describing the ladder as live. Record limitations.

## Sources

Firebase callable authentication and server error handling:
https://firebase.google.com/docs/functions/callable

Chess.com keeps bot games separate from competitive ratings:
https://support.chess.com/en/articles/8614091-how-can-i-play-against-the-chess-com-bots


## Backend rollout (not deployed)

The Firebase console currently shows **Spark** for `stones-9a6a0`. Firebase
requires [Blaze for Cloud Functions](https://firebase.google.com/docs/functions/faq-and-troubleshooting).
No billing plan was changed. New client/rules/backend code remains on the
qualification branch until this dependency is resolved; the deployed game is
unchanged. An operator must link a billing account before backend publication.
Budget alerts are not a hard spending cap. Each function has zero minimum
instances, a maximum of three instances, one concurrent request per instance, a 30-second timeout, and each signed-in
account has a 400-move daily calibration quota. These bounds are not a guarantee
of a zero bill. Monitor quota, invocation, read/write and artifact-storage costs.

With Node 22, the pinned Flutter/Dart SDK and Firebase CLI authenticated to the
project, from the repository root:

```sh
flutter pub get
npm --prefix functions ci
node --test functions/ratings.test.cjs
dart compile js -O2 tools/ratings/engine.dart -o functions/engine.js
node --test functions/*.test.cjs
firebase deploy --project stones-9a6a0 --only functions:ratings,firestore:rules
```

The `firebase.json` predeploy step recompiles the shared server engine. Generated
JavaScript and node_modules are ignored. Existing profile, achievement and room
policies are preserved. New public readers can access only rating metadata and
history; totals, receipts, calibration sessions, opponents, samples and quotas
remain server-owned. Keep historical `/ratings` and device-wide `elo_*` data out
of the new ladders. No destructive migration or leaderboard backfill is needed.
The engine revision `shared-search-v1` must change whenever its search behavior,
rules or budget changes; update client lookup and repository filters together.

After backend publication: verify public reads and forbidden writes, complete a
new signed-in human duel and a rematch, confirm both players receive one history
entry and a unique receipt, replay the same completion, reconnect both devices,
confirm draws and concessions, switch accounts, and establish ten games in one
pool. Then verify one server-generated AI game changes only the bot rating,
repeat it to prove deduplication, and repeat a second game that day to prove the
per-opponent sampling limit. Publish the qualified web client only after these
checks. Store rollout evidence here. Existing Android installations require a
new app release; this task does not submit a Play Store release.

## Practical boundaries

Ratings measure this community, not FIDE/Chess.com Elo. Small pools will remain
provisional longer. Three/four-player ratings use the explicit pair-comparison
rule above and are never mixed with duels. There is no automatic matching queue
or season reset. Friendly collusion, outside assistance and account abuse are
not solved by legal-history replay; moderation/abuse detection are future work.
AI calibration does not infer strength from a difficulty name and needs real
established opponents before it becomes useful. Account deletion/profile rename
handling and long-term evidence retention need an operator policy before wide
public rollout. History is bounded to the most recent 100 entries in the client.

Timed AI games remain practice: local pauseable clocks cannot establish trustworthy timed bot strength. Online AI calibration is also finalized by the room trigger, so closing the client after the final move does not lose that sample. Offline completed local saves replay completion when resumed.


## Regression evidence

The real Firestore emulator suite passed all 29 authorization tests in
[run 38995362862](https://github.com/douglastkaiser/stones/actions/runs/38995362862),
including public read-only competition access, forged-rating rejection and
private receipt/proof/quota denial. The compiled shared rules/AI plus rating
processor and service authorization passed all 17 backend tests. These include
an actual complete server-generated AI duel, idempotent completion and the
per-opponent daily limit. This is emulator/model evidence, not a claim of a
production deployment. Full Flutter and final build results will be recorded
once the final candidate completes qualification.

Legacy room codecs still decode old rating metadata for compatibility, but the app no longer advertises client-supplied legacy snapshots as trustworthy ranks or awards points for compatibility sessions.
