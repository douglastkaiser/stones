# Google sign-in recovery and remembered accounts

Implemented 2026-10-22 following the
[browser investigation](GOOGLE_SIGN_IN_INVESTIGATION.md).

## Behavior

- The home screen restores the saved Firebase identity immediately after its
  first frame, independently of audio, Play Games and rating initialization.
  A restored account appears without opening Google or creating a new guest.
  Local play remains available while restoration is pending or fails.
- While restoration is pending, home sign-in opens the Account card for preparation. Google opens only
  after a fresh tap on its ready sign-in button. The controller also refuses to
  queue a web popup across initialization or pending guest creation.
- At 30 seconds, a pending sign-in displays accessible recovery help on the home
  screen and Account card. Browser guidance explains closing the failed Google
  tab and retrying in the same browser; Android guidance refers to its account
  chooser. The attempt remains locked until Firebase completes or cancels it.
- Closing the failed popup allows a fresh attempt. Late success still completes
  normally; a late error, collision, initialization retry or auth-stream update
  cannot unlock a second concurrent attempt or leave an old notice timer running.
- Optional account-status metadata is published in the background after Google
  authentication; it no longer delays completion of a successful login.
- Errors advise preserving website data, which can contain a guest's room identity.

## Remembering the last account

Firebase manages credentials and refreshes the session. The locked FlutterFire
initializer already prefers persistent IndexedDB, then local storage, with session
or memory fallback when browser storage is unavailable. The fix restores that
session promptly rather than waiting behind optional startup work. It does not
copy tokens, passwords, emails or an account-selection flag into another store.

Tests close the browser process and reopen the same temporary profile. They
verify that the home screen restores the signed-in account, explicit sign-out
survives another restart, and a later login replaces the remembered account.
Private browsing, clearing data, a different browser/profile/origin, browser
storage eviction or a revoked session can still require signing in again.

Guest linking preserves the guest UID and seats. Account collisions still require
the existing-account confirmation. Signing out and switching identities remain
blocked in active online rooms, including a registered player's direct sign-in
request. Achievements, cosmetics and preferences retain their existing device-local
behavior; no account-data or room migration is introduced.

## Interfaces and verification

`AccountState` adds optional `notice` and `preparing` fields. `AccountController`
adds `requireFreshGesture`, defaulting to web behavior, to exercise browser
preparation deterministically in tests. `AccountService` is unchanged. Firebase
project settings, OAuth domains, hosting, Firestore rules and dependencies are
unchanged.

Validation covers cold preparation, duplicate requests, pending guest creation,
30-second help, late success/cancellation/collision, timer disposal, initialization
recovery, remembered identity restoration, sign-out and active-room protections.
UI checks include narrow screens and large text. Results are recorded in
[the implementation QA summary](qa/google-auth-fix-2026-10-22.json).

The full Flutter run passed 1,644 tests; the final account suite passed 31 tests,
with 41 account/home checks also passing. Strict analysis, 34 Python checks and
the release web build passed. All three desktop engines passed 18 emulator
credential/linking checks and 15 browser-restart checks. Controlled callback
faults verified the recovery notice, single-attempt lock and popup-close recovery.
The player browser journeys also passed local save/resume, review/rematch,
independent friend clients, disconnect/rejoin, computer replies and idempotent
rating settlement, with no page errors.

The browser regression job now runs credential/linking checks and full browser
process restart checks in Chromium alongside existing player journeys. The same
harness was also exercised locally in Firefox and WebKit. It uses the demo
emulators and disposable profiles containing fake provider credentials.
The existing player-journey selectors were updated for the current phone Match
options menu, current-player seat indicator and completed-rating label; their
underlying gameplay and backend assertions remain in place.

```sh
flutter analyze --fatal-infos
flutter test
python3 -m unittest discover -s scripts -p 'test_*.py'

# After building tools/integration_app.dart into build/integration-web:
npx --yes firebase-tools@15.33.0 emulators:exec \
  --only auth,firestore --project demo-stones-hex \
  'python3 tools/google_auth_browser_checks.py --browsers chromium,firefox,webkit'

# Optional controlled callback faults on a locally served release build.
# Public helper/setup requests are allowed; real identity exchanges are blocked.
python3 tools/google_auth_probe.py --base http://localhost:4174/stones/ \
  --cases callback_storage_lost,callback_new_context --verify-recovery \
  --browsers chromium --output build/qa/google-auth/recovery-fix.json
```

Physical iOS and real Google credential exchange remain unverified. The
application now recovers from the demonstrated helper-state failure; this does
not establish which device/browser condition caused the original report.
No redirect-flow or same-origin hosting migration is assumed to be necessary,
and nothing has been deployed by these workspace changes.
