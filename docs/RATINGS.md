# Ratings and competition

New configurations now use **version 3 skill ratings**: one Overall ladder plus
the exact format ladder, shared human/AI updates, uncertainty ranges and unordered
multiplayer losses. See [the current skill-rating contract](SKILL_RATINGS.md).
The version 2 and version 1 sections below retain their compatibility and
historical publication evidence; they are not the v3 default.

Updated 2026-10-19: new unified matches use **placement Elo for humans and AI**.
The default leaderboard combines both; every eligible version 2 match updates
all participants' global ratings in the existing board/clock ladder. The actual
winner places first, other seats rank by exposed flats, and equal counts tie.
Shares include match-specific confirmed Elo deltas from immutable receipts.

See [results, sharing, and placement Elo](RESULT_SHARING.md) for the current
contract, eligibility, transaction/rule checks, repeated-AI handling, trust
boundary, verification and deployment sequence. Missing configuration metadata
retains the version 1 protocol; settled history is not recalculated.

The remainder of this audit records the historical version 1 design and its
production publication evidence. Its human-only ladder and AI-sampling policy
apply to that legacy protocol, rather than new version 2 matches.

## Current architecture: Firebase Spark, local AI

Updated 2026-10-16. All computer opponents calculate on the device running the
match, using the existing shared search and cancellation/scheduling. No move
requires a cloud request. No Cloud Functions, Admin SDK or billing upgrade is
required by this implementation. The previous Functions implementation was never
deployed and has been removed, including its packages and deployment entry.

Firebase Authentication supplies identities. Firestore stores recoverable rooms,
account ratings, history and result receipts. Its security rules independently
check Elo arithmetic and atomic updates; they do not trust submitted totals.
Client replay is an honesty check, not proof that the client binary is original.

## Findings in the old Elo system

The legacy client accepted arbitrary scores, could award the same game twice,
and computed updates outside a protected transaction. History writes were
separate and failures hidden. Production rules denied the collection while the
UI fabricated bot ratings. Device caches were not account-scoped, Google and
Play Games identities were mixed, and unified matches did not call the old hook.
Leaderboard list position was mislabeled as global rank. That data is not imported.

## Human result protocol

1. After a terminal online game, each permanent-account participant replays the
   confirmed move history with the same MatchRules used by gameplay. Abandoned,
   Court, local/hotseat and independently unowned seats are excluded.
2. Each account can write only its own `/matches/{code}/ratingVotes/{uid}` vote.
   It contains the current ply, winner index (-1 means draw), and public alias.
   Normal clients only vote for a replayed terminal result. Rules bind the vote
   to room membership and the exact append-only log length.
3. A transaction reads the room, receipt, votes and every old rating before any
   write. The last agreeing voter can settle for everyone. All 2–4 independent
   human owners must have voted for the same outcome and ply. Guest accounts
   cannot vote. Duel concessions/timeouts must name the surviving player;
   multi-seat abandonment is unrated.
4. The transaction adds an opaque result receipt, freezes the room with its
   `ratingReceipt` pointer, updates all players and appends each player's history.
   Rules recompute expected scores from old database ratings, require all
   participant writes and matching history, and reject altered pools, arbitrary
   points, changed counts, partial settlement and repeat use of a receipt.
5. Concurrent games retry against current ratings. Concurrent observers of one
   game share one receipt. Already recorded results return success without
   awarding again. Pending/disputed confirmations are explicitly shown, with
   retry and room reopening. An online wait for peer votes is bounded to 12s;
   transactions are bounded to 15s in the application. Timed-out transactions may
   still finish: receipts make retry safe. No gameplay waits on rating settlement.

Public player records use cryptographically random 256-bit receipt IDs, not invitation codes or hashes of short invitation codes. New rooms allocate a fixed rating key at creation; a permanent participant can allocate it once for an older room. AI source keys are private and immutable. Receipt
contents and move evidence are participant-private; votes are room-member-only.
Public aliases are user-chosen, not verified real names. Public rating history
uses a player's sequential game number and generic opponent descriptions.

### Honest limitations

Rules enforce ownership, agreement, arithmetic, append-only room metadata and
atomicity, but cannot replay arbitrary Tak histories or attest a browser binary.
One modified client cannot award itself points without every opponent's vote.
Colluding accounts can manufacture agreement, and a loser who never confirms
can withhold settlement. The system must display pending results instead of
inventing an uncontested win. There is no server to finalize games when every
client has closed; reopening the saved room retries completion. Outside help,
account farming and deliberate withholding need future moderation/abuse work.
These are community competition ratings, not independently adjudicated tournament
results. Do not advertise this protocol as cheat-proof.

## AI community estimates

AI executes locally in both web and Android. After a natural, untimed, unassisted
duel, a signed-in established human (10 competitive games in the same pool) can
contribute a replay-checked result. Humans never gain or lose competitive Elo
from AI games. Samples update only the versioned AI record, anchored to the
human's existing competitive rating. Rules check the exact bot Elo update,
engine/difficulty identifiers, established anchor, unique source receipt,
matching history, and a per-account/pool/difficulty 24-hour sampling interval.
An immutable opponent marker counts distinct contributors. Each engine revision
starts fresh; bump `shared-search-v1` when search/rules/budget changes.

Modified clients can fabricate local outcomes or claim another difficulty. No
client secret, App Check token or hash proves execution of the AI. Sampling
limits and established-account requirements reduce impact but do not prevent
coordinated fabrication. The UI calls these **community estimates**, never
server-verified AI ratings. Zero samples show Uncalibrated; 30 games against 10
distinct contributors are required before the estimate loses its calibration
question mark. Device-dependent search timing can also affect observed strength.
Timed and multiplayer AI games are practice, not duel calibration data.

## Ladders and mathematics

Pools separate shape, size, player count, rules profile and clock category
(untimed, under 10 minutes, 10+ minutes). The normal selector exposes 81 pools.
All players and bots start at neutral 1200, hidden behind Unrated/Uncalibrated
until games exist. Human standings exclude bots and the first 10 provisional
games. Ties use competition rank (1,1,3); aggregate counts include players beyond
the displayed top 50. Rankings query validated `established` player fields,
avoiding a separate standings table that could become stale.

Expected score is `1/(1+10^((opponent-player)/400))`. K is 40 for the first 30
games, then 20, with nearest-integer new totals and a floor of 100. For 3/4-player
games, the winner beats each rival; losing rivals tie one another; an overall
draw ties every pair. Sum pair deltas and divide by the number of opponents.
All comparisons use pre-transaction ratings. Player W/L/D records the whole-game
outcome rather than the individual pair comparisons. This is Stones community
Elo, not FIDE or Chess.com strength.

## Reads, identity and presentation

Account changes clear prior identity immediately and invalidate late replies.
Leaderboards/profiles have bounded requests and visible failure/retry states.
Never substitute fake bots or silently call a failed read an empty leaderboard.
Seat labels, account cards, history, own rank and mobile/desktop competition views
share the same account/pool model. Read-only browsing does not require sign-in.
Firestore timestamps are converted at the repository boundary for model/UI use.

## Rollout and qualification

The user approved publication of the exact `01b15ac` rules on 2026-10-17. They
are now published in production, and both required query indexes are Enabled.
Client promotion/deployment status is recorded in the publication evidence below. Preserve the existing Firebase
configuration and attachments. Deploy the qualified rules and indexes before
publishing the new client:

```sh
firebase deploy --project stones-9a6a0 --only firestore:rules,firestore:indexes
```

No Cloud Functions command or billing upgrade belongs in this rollout. Wait for
indexes to finish building. Verify actual signed-in duel and four-seat outcomes,
duplicate completion, reconnect/reopen, account switch, disagreement/pending
status, leaderboard reads, and AI sampling after an established anchor exists.
Qualification uses full Flutter tests, strict analysis, release web/Android
builds and the real demo Firestore emulator authorization suite. Final evidence
is recorded below when complete. Earlier Functions/backend results are not
qualification evidence for this different protocol.

Spark quotas still apply: database storage/reads/writes are finite, especially
when waiting on peer votes or replaying many rooms. This design avoids paid
compute, not all resource limits. No automatic matchmaking, season reset,
account deletion/rename propagation or retention cleanup is implemented here.

## Source map

- `lib/game/rating_evidence.dart`: replay eligibility and exact-history comparison.
- `lib/services/rating_repository.dart`: transactional votes, receipts, Elo, AI samples.
- `firestore.rules`: independent authorization, arithmetic and atomicity checks.
- `firestore.indexes.json`: public competition query indexes.
- `lib/game/match_provider.dart`: local search, nonblocking completion submission.
- `lib/game/rating_pool.dart`, `lib/models/elo_rating.dart`: ladders and display models.
- `lib/providers/elo_provider.dart`: identity-safe bounded read state.
- `test/ratings/`: model, replay, identity, responsiveness and display regressions.
- `tools/hex_rules/spark_ratings.test.mjs`: real database adversarial transactions.


## Qualification evidence and original publication handoff (2026-10-17)

The approval-pending handoff below is historical; see the subsequent publication evidence.

Source `c0ed867` passed all 776 Flutter tests, strict analysis with no issues,
release web build, and Android debug APK build in
[CI 39000326913](https://github.com/douglastkaiser/stones/actions/runs/39000326913).
The final rules at `01b15ac` passed all 77 real Firestore emulator authorization
checks in [run 39000275972](https://github.com/douglastkaiser/stones/actions/runs/39000275972).
Those rules are unchanged in `c0ed867`. The suite covers every supported shape,
size and 2/3/4-player count; clock-pool isolation; every AI difficulty; Hex AI;
exact math; final-voter atomic settlement; stale totals; duplicate sources;
unauthorized/anonymous/partial writes; private evidence and old-room key setup.
No physical-device or production rating trial is claimed by these checks.

The console still uses Spark. Two required collection-scoped player indexes were
created without changing access controls: `isAi ASC, established ASC, rating DESC`
(index `CICAgOjXh4EK`, observed Enabled) and the corresponding `rating ASC` index
(`CICAgJiUpoMK`, creation accepted, last observed Building). There were no existing
manual indexes to replace. The optional `ratingResults.moves` automatic-index
exemption is checked into the deployment configuration; the console returned an
error saving it and it was cancelled. It is an optimization, not an eligibility
or integrity requirement. Do not describe it as deployed until verified.

The exact committed rules were staged as unpublished changes in the console.
The Firebase tab subsequently crashed during screenshot capture. Production
access rules were not published. Publishing broadens access to the new ratings
namespace, so browser automation requires action-time confirmation; a request
identifying `stones-9a6a0` and the exact `01b15ac` payload is pending. Restage from
that commit if the console draft was lost. After approval: publish, verify the
index is enabled, run live multi-account/reconnect/duplicate trials, then promote
the qualified client to main and deploy. Keep private room/evidence IDs out of
public trial reports. No billing change, Cloud Functions deployment or automatic
Play Store release is authorized by this handoff.


## Approved production publication (2026-10-17)

The user confirmed publication of the pinned `01b15ac` payload. After recovering
the crashed console in a fresh tab, the exact approved rules were restaged and
published. Firebase visibly marked the new rules as the starred current revision
("Today, 10:35 AM" in the console). No Functions or billing operations were used.
Both collection-scoped player indexes are now visibly Enabled, including
`CICAgJiUpoMK`; existing manual indexes were not replaced.

`STONES_LIVE_TEST=stones-9a6a0 python tools/live_rating_probe.py` passed against
production using ordinary client API permissions:

- Public established-player leaderboard and aggregate rank queries succeed.
- Private receipt and AI-source enumeration are denied.
- An isolated Square room accepts its new random rating key, independent join,
  legal opening exchange, cold recovery and durable resignation.
- Anonymous accounts cannot confirm results, forge totals or create receipts.
- Only the two disposable QA identities created by this probe were removed.
  No existing user rooms were read or modified and no ratings were awarded.

The local Node process terminated before executing the broader existing probe;
its output is not claimed as live evidence. The focused Python probe is retained
for repeatable verification. Full competitive settlement with distinct real
Google accounts and real community AI samples still needs a human play test;
those scenarios are covered in the emulator but not claimed as production trials.
The optional move-evidence index exemption remains configured but unapplied after
the console save error. It does not block the feature. The qualified client was promoted to main as `abbc262`; deployment evidence follows below.


## Web release completed (2026-10-17)

Main was fast-forwarded and pushed to `abbc262`. Its app, Android, dependency,
Firebase policy and deployment sources are identical to qualified `c0ed867`;
only audit evidence and the manual production probe were added afterwards.
[Deploy Main 39054797531](https://github.com/douglastkaiser/stones/actions/runs/39054797531)
and [Pages publication 39054916646](https://github.com/douglastkaiser/stones/actions/runs/39054916646)
both completed successfully. The site is live at
https://www.douglastkaiser.com/stones/ (the GitHub Pages address redirects there).

HTTP checks verified hosted HTML/manifest/bootstrap agreement, the compiled
asset SHA-256 filename, and embedded build identity `abbc262`. Current startup
assets are `flutter_bootstrap.d79be656aac029f5ef11.js` and
`main.9af5473e04e2605e15d0.dart.js`. Both preceding startup pairs remain reachable
for cached pages. The visible menu shows `v1.0.0+454.gabbc262.d20261017`.
A real hosted browser trial opened Competition successfully, loaded the fresh
human ladder without a permission/index error, and showed every AI difficulty as
Uncalibrated with zero games rather than an invented rating. Google-account
competitive outcomes and populated AI estimates still require real playtesting.

The machine briefly ran out of disk/virtual memory during Git publication.
Only generated Flutter `build/test_cache`, `build/unit_test_assets` and
`.dart_tool/flutter_build` caches inside the verified workspace were removed
(about 98 MB). Source, APKs, screenshots and remote attachments were preserved.
No Android Play Store publication, billing-plan upgrade or cloud AI was performed.
