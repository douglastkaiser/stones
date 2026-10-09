# Firebase preparation for multiplayer playtesting

Project: `stones-9a6a0`. The main GitHub workflow publishes the browser app to
GitHub Pages; it does not deploy Firebase rules. Firebase configuration and
credentials were not changed by this iteration.

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

First save and compare the currently published Firestore rules. The checked-in
file has no `/ratings` or `/ratings/{id}/history` permissions, while the app's
Elo provider uses those paths. If production already has policies for them or
other collections, preserve those blocks when merging the changed game rules.
Do not replace working production collection policies with the fallback deny.

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
