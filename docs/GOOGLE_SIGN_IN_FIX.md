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

## Durable qualification and deployment

Account regressions run independently of the player journeys in Chromium,
Firefox and WebKit. A source-labelled emulator build is shared by those jobs;
each engine exercises the application popup, direct emulator credentials and
actual browser-process restarts. Popup cancellation and explicit collision
confirmation are checked through the UI. Denied IndexedDB/local persistence is
fault-injected to verify usable session fallback; this is not iOS private-mode
qualification. Failure in one suite does not suppress the others.

A second matrix downloads the production web artifact from the same CI attempt,
verifies its manifest, build kind and authentication source hashes, then checks
strict pre-credential outcomes. Cold/prepared login must reach Google, blocked
popups must show help, and cancellation must allow another chooser. Both helper
state-loss faults must show delayed help, keep the attempt locked, and allow a
new popup only after closing the failed attempt and tapping again. These checks
never exchange real credentials. Observation-only and incomplete reports fail
qualification. Public setup assets may retry transient transport failures up to
three times; behavioral assertions are never retried to manufacture a pass.

Deploy Main requires two consecutive successful **complete CI attempts** for the
selected main commit, successful rules checks, and every required browser job.
Use a full workflow rerun for the second qualification; a failed-jobs-only rerun
is not a substitute. Artifacts carry their attempt number. Before publishing,
the workflow preserves the previous canonical artifact and publishing commit,
verifies every rollback file, and uploads a 90-day rollback archive. Publication
keeps the existing shared lock and bounded cached-startup retention.

After publication, three engine jobs wait up to five minutes for the selected
source, verify hosted HTML/bootstrap/main-script integrity, and check Google
handoff without entering an account. Publication and hosted acceptance have
separate statuses. The daily/manual Hosted login monitor checks the currently
deployed source and the same pre-credential outcomes. A provider/network failure
fails verification; it does not automatically replace production. All evidence
remains in Actions artifacts, without account data or OAuth URLs.

For a broken published application, run **Rollback Main** with the Deploy Main
run ID and the full previous SHA recorded in `rollback-source.json`. It accepts
only this repository's deployment archive, verifies the explicitly chosen source
and all bytes, preserves the current release, and republishes through the same
`stones-gh-pages-publication` lock. It preserves previews/startup assets, commits
normally and repeats hosted checks against the previous SHA. Backend contract
mismatches fail closed; an app rollback does not roll back Firebase rules. Do not force-push or rebuild an old release and call it
the verified artifact. Rollback is a deliberate release action, not a response
to an isolated Google outage.

### Evidence correction

The first pushed fix, `8ffde24`, passed hosted analysis/tests, Android compilation,
web build and rules authorization, but its player journey failed: the version-3
fixture correctly displayed “Overall and format ratings recorded” while the
probe expected “Elo recorded”. Because the account checks followed it with `&&`,
they did not run in that CI attempt. Earlier local browser passes did not carry
an immutable manifest proving their build/source correspondence and do not
qualify the hardened release. The new clean-build and manifest checks supersede
that evidence for release qualification; the original reports remain historical.

```sh
# Build fresh output directories with the pinned Flutter SDK first.
python3 scripts/prepare_web_release.py build/integration-web
python3 scripts/web_artifact.py create build/integration-web --kind emulator
# Inside demo-stones-hex auth/firestore emulators:exec:
python3 tools/google_auth_browser_checks.py --browsers chromium,firefox,webkit \
  --expected-source "$(git rev-parse HEAD)"

python3 scripts/prepare_web_release.py build/web
python3 scripts/web_artifact.py create build/web
python3 tools/google_auth_release_checks.py --browsers chromium,firefox,webkit \
  --expected-source "$(git rev-parse HEAD)"
python3 tools/hosted_auth_check.py --expected-source <full-published-sha>
```

Physical iPhone Safari/Chrome, real Google exchange, native Android chooser
behavior, app suspension, home-screen launch and embedded-browser returns remain
separate device acceptance. Record versions, launch surface, source SHA and
pass/fail for each case in the investigation checklist; never record callback
queries or clear an existing player's website data to make a check pass.


### Browser harness portability

The first hardened candidate's hosted CI passed the full 1,644-test Flutter suite,
builds and player journeys. Additional cross-engine qualification exposed harness
differences: Firefox's Google identifier is a visible text field rather than an
email-type input, and WebKit cannot fulfill a routed request with synthetic HTTP
302. The probe checks the actual identifier control and uses a validated
same-popup JavaScript navigation for its invalid-code callback fixture. This
keeps helper-state loss real while avoiding the unsupported interception API.
Denied persistence is tested once per engine in the independent credential suite
after SDK auth readiness; popup UI checks retain their own required outcomes.
Dependency HTTP errors are recorded only as origins, status codes and resource
types. These corrections do not change production authentication behavior.
