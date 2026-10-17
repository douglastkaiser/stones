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
- AI does not award human competitive points. AI calibration must be attributed
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
