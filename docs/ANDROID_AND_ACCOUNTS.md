# Android and account audit

Audited 2026-10-10. These are application features, separate from Tak mechanics.

## Account ownership

Firebase Authentication owns square and Hex multiplayer seats. Play Games is an
optional Android integration with a different identity; it must not gate room
creation or Google account sign-in. Settings now has a shared Account card.

Both game variants restore the Firebase identity before creating an anonymous
guest. Google sign-in links a guest where possible, preserving its UID and rooms.
An existing Google account cannot absorb another UID's guest rooms: collisions
remain guests until the user explicitly chooses the existing account. Switching
identities and signing out are blocked while an online room is active.

Android uses GoogleSignIn to obtain a credential for Firebase, following
[Firebase's Flutter integration](https://firebase.google.com/docs/auth/flutter/federated-auth).
Browser uses Firebase's Google popup flow. Cancellation preserves identity;
errors provide recovery steps and never expose raw credentials or SDK messages.
Duplicate guest/auth requests coalesce. Initialization is lazy and retryable.

Room codes can be resumed on another device using the same Google account.
Achievements, theme unlocks, puzzle progress and preferences are currently local;
signing in does not synchronize those. Guest identity cannot survive clearing
browser storage or app data. Shared ratings still require authoritative backend
writes; the current Firestore policy intentionally denies client rating writes.

## Production Firebase observations and change

Console verified Google and Anonymous providers enabled. Authorized domains
initially included only localhost and the two Firebase default domains. The
hosted `douglastkaiser.github.io` domain was missing, blocking browser Google
sign-in. After explicit user approval, it was added and confirmed in the saved
domain table. No provider, Firestore rule or App Check enforcement was changed.

The registered Android package is `com.douglastkaiser.stones`. Console SHA-1s
match the two Android clients in the existing google-services.json:

- `FA:63:FB:8F:BB:9B:27:F6:90:54:1B:E7:BC:11:62:AC:90:3A:30:CB`
- `23:1A:A5:01:2D:38:05:18:61:BF:AE:C6:5C:46:B2:7E:92:5C:44:B9`

No SHA-256 entries were shown. Android App Check is unregistered. Web uses
reCAPTCHA. Authentication and Firestore App Check are **Monitoring**, not
enforced, so this is not currently an enforced login blocker. Do not enable
enforcement before registering and testing every supported delivery channel.
The release workflow prints the public APK certificate SHA-1/SHA-256; compare
these with Firebase. Play Store installs use the separate Play **app-signing**
certificate, not necessarily the upload certificate. Obtain both from Play
Console's App integrity page. Register the real certificates rather than
guessing from checked-in JSON. See
[Google's certificate guide](https://developers.google.com/android/guides/client-auth).

## Android release process

Android Release runs manually on main, using Flutter 3.47.7 and Java 17. It checks
signing inputs, package/project identity, registered upload-key SHA-1 and native
Google's required web OAuth client before building. Signing secrets are scoped
to the steps that need them; the temporary keystore is removed on completion.

Required GitHub Actions secrets:

- `ANDROID_UPLOAD_KEYSTORE_B64`
- `ANDROID_UPLOAD_STORE_PASSWORD`
- `ANDROID_UPLOAD_KEY_ALIAS`
- `ANDROID_UPLOAD_KEY_PASSWORD`

The workflow produces a universal installable `app-release.apk`, APKs split by
ABI, and optionally a Play Store AAB. Flutter owns ABI splitting; debug and
bundles no longer inherit conflicting Gradle splits. Signature verification,
SHA-256 checksums and commit/version metadata accompany artifacts, named by
version code and commit and retained for 30 days. AABs cannot be installed directly.

Version code defaults to commit count. Set the workflow's `build_number` input to
a positive code above the highest code already uploaded to Play Console when
needed. CI also compiles a debug Android APK; this catches native/plugin build
regressions that Flutter widget tests and web builds cannot detect.

The most recent existing Android Release run was successful on 2026-01-28
([run 21424203306](https://github.com/douglastkaiser/stones/actions/runs/21424203306)),
before the recent gameplay upgrades. It does not validate this new code.

No JDK, Android SDK or attached Android device was available locally during this
audit. The new Android CI job and signed release workflow must run after these
changes are pushed; a native compile, signing pass or successful device login
must not be claimed based on Dart tests alone.

## Optional Play Games

Play Games is disabled in builds without real configuration. Set GitHub variable
`STONES_PLAY_GAMES_APP_ID` to the numeric Games services project ID from Play
Console (not a Firebase app ID). Release builds then pass the Dart enable flag
and Android string resource together. Local configured builds need that same
environment variable and `--dart-define=STONES_PLAY_GAMES_ENABLED=true`.

The Android Application initializes the SDK only for a configured project ID.
The v21 SDK supports suppressing launch-time profile creation prompts; explicit
connection belongs in Settings. See
[Google's native integration](https://developer.android.com/games/pgs/android/android-signin).
Publish matching Play Games credentials/settings and add testers before trialing
an unpublished game. Firebase Google sign-in remains independent of these steps.

Placeholder achievement/leaderboard IDs were removed. Optional Dart defines are
`PLAY_GAMES_ACHIEVEMENT_FIRST_WIN`, `ROAD_BUILDER`, `FLAT_EARTH`, `GIANT_SLAYER`,
`SPEED_DEMON`, `CAPSTONE_MASTER` (all with the full `PLAY_GAMES_ACHIEVEMENT_`
prefix), and `PLAY_GAMES_LEADERBOARD_TOTAL_WINS`, `LONGEST_STREAK`, `FASTEST_WIN`
(all with the full `PLAY_GAMES_LEADERBOARD_` prefix). Empty IDs skip publication;
local achievements continue to work. Configure real values before enabling
external achievement reporting. Set the optional GitHub variable
`PLAY_GAMES_IDS_JSON` to a JSON object mapping the full define names above to
real published IDs; the release workflow validates and includes that file.
Local builds may pass those same defines individually.

Play Games no longer automatically replaces the board when signing in. Cloud
restoration is explicit and refuses active online, puzzle, tutorial, Court or
timed contexts. Saves include local/AI mode, difficulty and human color. Older
ambiguous saves are rejected. Writes are serialized to keep older asynchronous
uploads from overwriting newer moves; opening an empty board does not replace
the last save. AI wins do not award the human a win. This save format covers
ordinary square games only; Hex online room persistence remains Firestore-based.

## Verification and remaining device trials

Account tests cover restored identity, coalesced authentication, linking during
matches, collisions, explicit switching, cancellation, sign-out protection,
retries, disposal and stream errors. Widget tests cover 320px and 1000px layouts
at 150% text scaling. Cloud-save tests cover AI/session/stack restoration,
unsupported formats and corrupt dimensions. Six Python tests exercise signing
preflight failures and check that passwords never enter logs or subprocess args.

Before calling the login repair fully verified, trial these on the hosted site
and a signed Android install (including Play internal testing):

1. Sign in as a new Google user; cancel and retry; restart and check identity.
2. Create square and Hex rooms as a guest, link Google, close/reopen and resume.
3. Attempt linking an existing account; retain guest rooms until explicitly
   switching, then resume that account's room from another device by code.
4. Sign out with no active room; sign back in; check name/email and room access.
5. Test popup blocking, loss of network, Android back/cancel and repeated taps.
6. If Play Games is configured, connect separately, verify a human AI victory,
   restart, explicitly restore the saved AI mode/color and verify no current
   game is overwritten. Test legacy saves produce a safe failure.

Domain registration is verified in production; credential exchange on a user's
device and Play Store certificate/SDK behavior still require these trials.

Audit verification: all 433 Flutter tests passed; strict analysis reported no
issues; release web build succeeded. All six Python preflight tests passed.
Workflow YAML and embedded Python parsed successfully. Browser inspection
confirmed the Account card initializes and fits 390px and 1366px viewports;
final account/Settings/cloud-save regressions passed (31 tests). Native Android builds,
Play Console signing identity and actual Google credential exchange are still
unverified locally. See GitHub Actions for native builds and release artifacts.
