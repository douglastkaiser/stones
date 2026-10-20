# Release candidate audit — 2026-10-20

The owner has authorized main promotion and client publication. The matching
[Firebase rules/indexes are published](releases/FIREBASE_20261020.md). This record
distinguishes automated qualification from remaining physical-device acceptance. Product contracts are in
[PLAYER_EXPERIENCE.md](PLAYER_EXPERIENCE.md).

## Corrections from the final review

- A failed local rematch save now preserves the completed game and confirmed
  moves. Retry creates a new identity and rotates the starter only after saving.
- Archive retries normalize moves, so JSON key ordering cannot cause conflicts.
- History filters owners before decoding payloads, validates storage identities,
  and replays only the requested page. One corrupt record cannot hide other games;
  damaged data is retained and the user sees a recovery warning.
- Study progress immediately exposes its saving state during retry, preventing
  premature continuation or duplicate writes.
- Browser evidence clears prior captures and explicitly marks failed runs, so a
  previous successful summary cannot qualify a later failure. Leaderboard checks
  use the actual accessible row controls exposed by Flutter.
- CI retains hidden web artifact files required by its integrity manifest.
  Generated Android wrapper/cache files are excluded from source control.

Regression tests cover storage failure and retry, immutable/idempotent archives,
corrupt and foreign records, pagination and delayed study-progress writes.

## Evidence and remaining gates

| Check | Evidence | Limit |
| --- | --- | --- |
| Flutter suite | 996 passed on frozen audited Dart sources | Does not replace device testing. |
| Static checks | Strict analysis, changed-Dart format, workflow lint, diff whitespace passed | Hosted pipeline must accept the actual commit. |
| Release helpers | 29 Python checks passed | Publishing has not occurred. |
| Firestore authorization | 136 emulator checks passed, including AI-only 2–4 seats, repeats and rejection cases | New rules must be deployed before the client. |
| Web | Production and separate emulator builds passed; production fingerprint/manifest verification passed | Not phone startup/performance evidence. |
| Browser | Earlier complete core journeys passed. Expanded run verified real SDK AI-only settlement in Overall/format and no duplicate on reopen | Final corrected hosted run passed all nine journeys with zero page errors. |
| Android | SDK/JDK installed; build attempted | Final hosted CI compiled and retained the candidate debug APK successfully. |

An all-AI game must start under a permanent signed-in account to submit ratings.
The observer gets neither personal rating nor achievements. Shared AI identities
receive the same rating protocol as other players; duplicate identities count
once without learning from comparisons against themselves. Existing receipts
are immutable, and historical games are not batch-submitted.

## Hosted audit and workspace interruption

The first candidate `2df1b28471e987802688d1ffbd9f41735797ad35` passed
[hosted analysis, 996 tests, 29 release-tool checks and web compilation](https://github.com/douglastkaiser/stones/actions/runs/39496314476),
and [Firestore authorization](https://github.com/douglastkaiser/stones/actions/runs/39496314518).
Its expanded browser run reached both updated leaderboard rows after actual SDK
settlement/reopen checks. The final assertion failed because it expected separate
text nodes; Flutter exposes those names in accessible row buttons. The assertion
is corrected without weakening the database or duplicate checks. Follow-up
`a045e37` passed [all final CI jobs](https://github.com/douglastkaiser/stones/actions/runs/39497631177)
and [authorization checks](https://github.com/douglastkaiser/stones/actions/runs/39497631273).

The workspace then lost connectivity. The follow-up is committed using GitHub's
repository API, preserving the existing candidate tree except for the reviewed
browser/documentation edits. The workspace reconnected and its clean tree was aligned to the final commit.
Interrupted probes were rerun: all twelve longer AI games passed across the full
three-format matrix. The owner subsequently authorized main promotion and
client publication after the verified Firebase update.
Repository branch-protection settings could not be inspected with this connection.

## Before going wide

1. Require green CI and Firestore Rules runs on the exact candidate commit,
   including the complete expanded browser harness and Android compilation.
2. Backend prerequisite completed: the qualified rules were published and read
   back, five indexes remain READY, and thirteen read-only production checks passed.
   No game/player/rating records were written. See the linked publication record.
3. Exercise a Play-installed upgrade, Google sign-in, cold/warm invitations,
   backgrounded AI, offline/rejoin, large text and TalkBack on named phones.
   Confirm an independently signed-in production game settles and recovers once.
4. Observe five unfamiliar players using the candidate without coaching. Record
   completion, invitation join time, confusion and whether they want another game.
5. Promote the verified artifact, retain rollback evidence and monitor failures.
   A debug APK build is separate from Play signing, distribution and store gates.

Account-wide progress/inbox, online rematch consent and reminders remain later
work. Local history does not imply synchronization. No rules, website or store
release is authorized merely by a green test result.
