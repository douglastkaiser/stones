# Release candidate audit — 2026-10-20

The candidate is isolated from main and production. This is an evidence record,
not a claim that a public release is ready. Product contracts are in
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
| Browser | Earlier complete core journeys passed. Expanded run verified real SDK AI-only settlement in Overall/format and no duplicate on reopen | Full expanded rerun pending after fixing a harness selector; external CDN fetch returned 503 locally. |
| Android | SDK/JDK installed; build attempted | Google Maven returned HTTP 503. No candidate APK qualification yet. |

An all-AI game must start under a permanent signed-in account to submit ratings.
The observer gets neither personal rating nor achievements. Shared AI identities
receive the same rating protocol as other players; duplicate identities count
once without learning from comparisons against themselves. Existing receipts
are immutable, and historical games are not batch-submitted.

## Before going wide

1. Require green CI and Firestore Rules runs on the exact candidate commit,
   including the complete expanded browser harness and Android compilation.
2. Publish and read back the qualified backward-compatible Firestore rules;
   verify required indexes before promoting the client. No production write or
   policy publication is performed by this audit.
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
