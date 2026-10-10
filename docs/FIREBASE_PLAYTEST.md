# Firebase preparation for multiplayer playtesting

Project: `stones-9a6a0`. The manually triggered Deploy Main GitHub workflow
publishes the browser app to GitHub Pages; pushing `main` alone does not run it
and it does not deploy Firebase rules. Firebase configuration and
credentials were not changed by this iteration.

## Console verification (2026-10-09)

Connected to the production project and saved the previously published policy
in [FIRESTORE_BEFORE_2026_10_09.rules](FIRESTORE_BEFORE_2026_10_09.rules).
That policy had square games, `/users` and `/achievements` blocks, but no Hex
or rating/history permissions. The repository now preserves both existing
profile/achievement blocks while adding the previously prepared game rules.

Firebase's Rules Playground compiled the complete merged policy and confirmed:

- Unauthenticated Hex room read: denied.
- Authenticated Hex room-code read: allowed.
- Square creation as a Black host with a Morocco board: allowed.
- Hex creation with host human, remote human, AI, Morocco board/pieces: allowed.
- Same Hex payload with an authenticated forged host: denied.

These are simulations; no test document was written into the production database.
Anonymous and Google sign-in are already enabled. The web app is registered
with reCAPTCHA App Check. Authentication and enforcement were not changed.

**Published on 2026-10-09 to `stones-9a6a0`.** After explicit approval of the
exact payload, Firebase Console showed the new starred published version
(`Today • 6:46 PM`) and no unpublished draft. The editor payload matched
`firestore.rules` before publication. Commit/push itself does not publish rules.

Shared Elo ratings/history were already denied in the deployed policy. Their
current client implementation writes both players' ratings and global AI ratings;
trustworthy shared rating updates need server authority. This deployment does
not introduce permissive rating writes. Ordinary room play is a separate path.

## Required backend change

Publish the updated game authorization blocks in `firestore.rules`:

- `/games/{code}` accepts a host-selected `boardTheme` and each player's
  `pieceStyle`. The board and creator color are immutable after creation.
  Hosts may choose Ivory or Charcoal; the guest fills the vacant color without
  rewriting the host's player data or board.
- `/hexGames/{code}` accepts the host's `boardTheme` and three-seat
  `pieceStyles` map. A guest may reserve a vacant seat and set only that seat's
  pieces. Joins and moves cannot change the host board or other seat styles.
- Old rooms without cosmetic metadata remain valid and render Classic. No
  manual document migration, new indexes, Storage assets or Cloud Functions
  are needed for this feature.

For future updates, save and compare the currently published policy again.
Preserve any existing collection policies before merging changed game rules.
The current rating boundary is described above; the fallback deny must not
silently erase policies added in a later deployment.

With Java and the Firebase CLI available, run the local authorization suite
from the repository root before publishing:

```powershell
firebase emulators:exec --only firestore --project demo-stones-hex "node --test tools/hex_rules/hex_rules.test.mjs"
```

The tests bind to loopback port 8088 and use a demo project, not production
identities. This iteration checked JavaScript syntax but could not run the
emulator because its runtime is unavailable on the development host.

Once the repository rules include any existing production collection policies:

```powershell
firebase login
firebase deploy --only firestore:rules --project stones-9a6a0
```

Alternatively, publish the merged rules in Firebase Console → Firestore
Database → Rules. See [Firebase's rules deployment guide](https://firebase.google.com/docs/rules/manage-deploy).

## Authentication and App Check

Ensure Authentication → Sign-in method has Anonymous enabled if it is not
already enabled. This app uses anonymous sign-in for room ownership.
Test the published browser app with its existing App Check registration.

The current reCAPTCHA provider reports that localhost is unsupported. For local
Firebase trials, use a registered App Check debug provider/token following
[Firebase's debug-provider guide](https://firebase.google.com/docs/app-check/web/debug-provider).
Do not add localhost to production reCAPTCHA domains or disable enforcement to
work around this. The published site avoids the localhost issue:
`https://douglastkaiser.github.io/stones/`.

## Two-client playtest

Use different browsers/devices or a private window, so the clients have distinct
anonymous identities; two ordinary tabs can share the same identity.

1. Host with an earned non-Classic set; guest keeps Classic. Both should see the
   host's board, the host's themed pieces, and the guest's Classic pieces.
2. Inspect the opponent's theme. The locked viewer sees its sample and unlock
   instructions but gains no achievement or selectable set.
3. Exercise placements, mixed stacks, spreads, wall flattening and inspection.
   Piece styles stay with their original color after captures. Reconnect using
   the same browser identity and code; board and pieces remain fixed.
4. Repeat square creation with the host choosing Charcoal.
5. Repeat Hex with one host human, one remote human and one AI. All clients see
   the host board; the remote human brings their own pieces; AI uses the host's
   pieces. Check Copper's palette, six-direction spreads and road results.
6. Change local Settings after leaving, then create a new room. The new room
   uses the new host selection; existing rooms keep their recorded selection.

Flutter rendering, model and responsive checks passed. Live two-device behavior
and backend authorization remain to be verified after deploying merged rules.

## Recovery and interruption playtest

After the recovery iteration, validate with the same browser profile/account:

1. Create a room, close the tab while waiting, reopen and use Resume online game.
2. Join from an independent identity, make moves, then close both clients.
   Reopen each and verify board, reserves, turn, themes and history match.
3. Close the Hex host on an AI turn. The room stays saved; reopening that host
   should resume its bot turn while preserving every human seat.
4. Interrupt the network while committing a square move. Input must lock or
   report an unconfirmed save; recovery must show the server-confirmed log.
5. For a timed square room, wait with the tab closed and verify time was consumed
   rather than reset. Verify expiration reaches both clients. New moves carry
   clock balances; legacy logs have approximate recovery. Server clock authority
   and clock-skew protection are still separate work.
6. Remove a saved shortcut and rejoin by code to confirm removal does not delete
   the room. Try a different identity; it must not take an occupied seat.

No additional Firebase collection/index is introduced by recovery. See
[performance and recovery](PERFORMANCE_AND_RECOVERY.md) for the contract and
verification boundaries.

## Shared Hex goals compatibility, 2026-10-09

Published the one-line `version in [1, 2]` room-creation compatibility update
to stones-9a6a0; the console's active revision is Today 9:02 PM. Compared the
complete staged policy with the repository and the previous published policy;
only the supported version predicate changed. Firebase compiled it successfully
and the authenticated legacy-room creation simulation remained allowed.
Authentication, room visibility, seat authority and immutable metadata restrictions
are unchanged; existing rooms keep version 1. Dart replay/join/append tests cover
both versions and attempted version changes. Emulator tests now use version 2
and cover legacy support and immutable versions, but were not executed here
because the Java/Firebase emulator runtime is unavailable. No production test
documents were created. Browser proof: `build/firebase-hex-v2-published.png`.
