# Google sign-in investigation — 2026-10-22

The application recovery, fresh-tap handling and remembered-account startup are
now [implemented and documented](GOOGLE_SIGN_IN_FIX.md). Findings below describe
the investigation phase; the original device-specific trigger is still unconfirmed.

## Conclusion and limits

The supplied error is Firebase's authentication helper failing to recover its
initial OAuth state. Controlled tests reproduced the exact screen by (1) clearing
the helper's session storage before the callback and (2) opening the callback in
a fresh top-level tab. With storage intact, the same synthetic callback reached
Stones' error handling instead. The callback used an intentionally invalid code;
production credential exchange was blocked throughout.

This establishes a mechanism, **not the cause on the affected iPhone**. Storage
restrictions, browser/app switching, and a resumed/stale authentication window
remain candidates. There is no physical iOS device or real Google test account
available. Desktop WebKit and emulator credentials cannot establish iOS success.
The screenshot's controls appear consistent with Chrome on iOS; the browser and
iOS version are unknown. Safari, Chrome, installed web apps and embedded browsers
must remain in the device matrix.

The investigation phase delivered the tools, regression coverage and remediation
specification below. Subsequent application changes are recorded in the linked
implementation report; no production hosting or OAuth change has been deployed.

## Confirmed application and production facts

- Both fresh web sign-in and guest linking use Firebase popup APIs. No application
  call to `signInWithRedirect` or `getRedirectResult` was found. The screenshot's
  redirect wording is generic and does not identify the application's flow.
- Firebase owns room seats. Guest linking retains the UID; account collisions
  require an explicit switch, and switching/sign-out are blocked in active rooms.
  Android obtains native Google credentials. There is no native iOS project and
  its Firebase options remain placeholders; this incident concerns the web app.
- The public release manifest identified source
  `2b72e84bb51c4e8d16fb024c571f71b7539bb795`, built with Flutter 3.47.7.
  The investigated workspace is `fc31e80`; its account service, controller,
  account card and settings implementation match that deployed source.
- The active startup pair was `flutter_bootstrap.1fcc3c15d82822347c53.js` and
  `main.70ad0479cfab6619ced0.dart.js`. Two previous pairs were retained.
  A later full hash-integrity check was blocked by the environment transport
  failure described below; the manifest is not a claim that all bytes were verified.
- GitHub Pages redirects to `https://www.douglastkaiser.com/stones/`. The public
  Identity Toolkit project configuration includes `localhost`, both Firebase
  defaults, `douglastkaiser.github.io`, `douglastkaiser.com`, and
  `www.douglastkaiser.com`. The earlier missing-domain issue is not present in
  this observation. OAuth client settings and current App Check enforcement
  could not be independently inspected with privileged credentials.
- The Firebase helper `/__/auth/iframe` returned 200 on
  `stones-9a6a0.firebaseapp.com`; the same path returned 404 on the game origin.
  The app therefore uses a cross-origin authentication helper. This is not,
  by itself, proof that the popup flow is misconfigured. No COOP, COEP, CSP or
  X-Frame-Options header appeared on the observed game HTML response.
- Runtime requests loaded Firebase JS **11.9.1**, as expected from the locked
  FlutterFire packages, and **12.6.0** for the separately initialized analytics
  module. Both versions were present in successful account-chooser runs. There
  is no demonstrated SDK-version regression; an upgrade/downgrade is not yet a fix.

## Browser evidence

Every hosted context was disposable. Analytics, production Firestore access,
token refresh, App Check exchange, and production Google API writes were blocked.
No real account credentials were entered. Reports retain only classifications,
origins, public configuration, SDK versions and input/popup timings. They omit
OAuth parameters, raw SDK errors, storage values, personal identifiers, screenshots
and traces. These interceptions make the runs diagnostic experiments rather
than unmodified production end-to-end qualification.

| Scenario | Observation | What it establishes |
| --- | --- | --- |
| Chromium cold and prepared account screen | Google chooser reached | Initial Google handoff can work with the deployed build |
| Firefox cold sign-in | Google chooser reached | Not a universal cross-browser startup failure |
| Desktop WebKit cold sign-in, early run | Google chooser reached | Initial WebKit handoff can work; not iOS credential exchange |
| Chromium/Firefox close popup and retry | Chooser reached on retry | Cancellation can release the pending attempt |
| Forced Chromium popup blocking | Stones displayed popup recovery message | Existing `popup-blocked` handling is reachable |
| Chromium offline then restore/retry | Chooser reached after recovery | At least this interruption is recoverable |
| Chromium desktop tab switch/resume | Chooser reached | Ordinary desktop tab switching alone did not reproduce the screen |
| Denied helper `sessionStorage`, before Google callback | Chooser still reached | Reaching Google does not prove callback storage will work |
| Synthetic callback, original context and storage intact | Callback relayed; Stones displayed connection error because exchange was deliberately blocked | Helper state was recovered |
| Same callback after clearing helper storage | Exact missing-initial-state page; parent still waiting | Lost helper state can strand the popup flow |
| Callback in a new top-level tab | Exact missing-initial-state page | A fresh context can lose the helper state independently of domain authorization |

The state-clearing test is fault injection, not a simulation of Safari's storage
partitioning. Likewise, private browser contexts are isolated test profiles,
not qualification of Safari Private Browsing, iOS process suspension or a PWA.
Full private-mode/partitioning, embedded-browser, background/kill and callback
return tests remain device work. One Firefox prepared-screen run did not reach
the chooser within the observation window; it is inconclusive, not a confirmed
Firefox defect. Helper-frame blocking did not prevent Chromium's initial chooser;
that experiment does not verify the return relay.

Late in the investigation, all tested public hosts began returning HTTP 503 from
the execution environment's outbound proxy with a Cloudflare tunnel connection
failure. This affected Stones, Firebase and gstatic alike. Later WebKit, callback
and service-popup emulator attempts were blocked/inconclusive; they must not be
counted as product failures or successful qualification. Environment status still
reported connected; the individual HTTP errors establish the actual limitation.

## Remediation specification

### 1. Parent-window recovery: demonstrated gap

The helper can show an error without resolving the parent's popup promise. The
controller only leaves `busy` after that promise completes, so error-message
mapping alone cannot recover this screen.

- Add a 30-second **notice timer**, owned by the controller and cancelled on
  success, error, cancellation or disposal. While the same attempt is still
  pending, show: “Sign-in is taking longer than expected. Check the Google
  sign-in tab. If it shows an error, close that tab, return to Stones in the same
  browser, and try again.” Announce the notice through the existing live region.
- Preserve `busy`, UID and the in-flight attempt while the notice is displayed.
  Do not wrap Firebase authentication in a timeout that unlocks a second attempt:
  timing out the Dart future does not cancel a late Firebase sign-in.
- A late success still completes normally; closing the popup follows the existing
  Firebase cancellation path and permits a fresh tap. The timer must not overwrite
  an account collision, a completed operation or an error from a newer attempt.
- Make the slow-sign-in help reachable on both the home shortcut and Account
  card. Change storage-error guidance to return to the same browser/tab and
  restart from Stones. Do not require disabling tracking protection or clearing
  site data; clearing data can remove the guest's room identity.
- Keep `AccountService` unchanged. Store the timer/attempt generation privately
  in `AccountController`; use the existing error/notice presentation without
  exposing raw Firebase messages. Test the timer with controlled time and a
  deferred service future, including late success and disposal.

This mitigates the demonstrated stranded UI; it does not claim to restore missing
OAuth state inside Firebase's hosted helper.

### 2. Avoid initialization on the web popup gesture path

The home shortcut can await lazy initialization or guest creation before invoking
the popup API. Popup instrumentation also observed inactive user activation in
one slow synthetic attempt. Automation still opened the window, so this is a
separate compatibility risk, not a proven explanation for the screenshot.

- When web sign-in is requested before initialization is ready or while guest
  creation is pending, open/show the Account card and finish preparation there.
  Require a fresh tap on its enabled Google button after preparation; do not
  queue an interactive popup across the asynchronous work.
- Keep the initialized path directly connected to the button gesture and retain
  the current anonymous-link versus explicit-existing-account decision.
- Leave the native Android flow unchanged. Add a regression that deferred web
  preparation never launches a popup until the subsequent explicit tap.

### 3. Select the underlying fix from device evidence

- If the callback opens in another browser, app, private session or top-level
  tab, keep the entire authentication attempt in the originating browser context.
  For unsupported embedded browsers, provide an explicit “open Stones in your
  browser” action; no automatic redirect loop or cross-context token transfer.
- If the same-context device trace demonstrates third-party helper storage
  partitioning, prepare a same-origin authentication-helper reverse proxy as
  described in Firebase's official guidance. It must serve **GET and POST**
  `/__/auth/**` at the root of `www.douglastkaiser.com`, forwarding the full path,
  query and body to `https://stones-9a6a0.firebaseapp.com`. It must proxy rather
  than HTTP-redirect and must bypass the Flutter app, caching and SPA rewrites.
- Only after those endpoints work, set the web and analytics `authDomain` to
  `www.douglastkaiser.com`; add the exact Google OAuth redirect URI
  `https://www.douglastkaiser.com/__/auth/handler` and verify Firebase authorization.
  Preserve project ID, keys, UIDs and Firestore rules. GitHub Pages cannot provide
  that reverse proxy alone: the hosting/edge configuration must be established
  before this change is implemented. Reverting only the auth-domain configuration
  must remain possible. Keep popup authentication during this change.
- Do not adopt redirect authentication, move domains, upgrade all Firebase
  packages, or unify the analytics SDK as an assumed cure. Test any SDK-specific
  change against a minimal reproducer and the locked version first.

No hosting or OAuth configuration change is justified solely by the current
screenshot. Missing state must never be bypassed or replaced with a fabricated
OAuth state to complete a real sign-in.

## Reproduction tools and validation

Install Playwright 1.62.0 and its Chromium, Firefox and WebKit dependencies. Keep
TLS verification enabled. In managed proxy environments, Firefox additionally
needs `certutil` and the public CA configured by `NODE_EXTRA_CA_CERTS`; the probe
imports it into a temporary Firefox profile and deletes that profile afterward.

```sh
python tools/google_auth_probe.py --browsers chromium,firefox,webkit
python tools/google_auth_probe.py --browsers chromium \
  --cases callback_same_context,callback_storage_lost,callback_new_context \
  --output build/qa/google-auth/callbacks.json

flutter build web --release --target tools/integration_app.dart \
  --base-href /stones/ --output build/integration-web --no-web-resources-cdn
WEB_ROOT=build/integration-web node tools/serve_web.mjs
# In another terminal, start the existing demo emulators:
npx --yes firebase-tools@15.33.0 emulators:start \
  --only auth,firestore --project demo-stones-hex
# Then run either explicit scope:
python tools/google_auth_emulator_probe.py
python tools/google_auth_emulator_probe.py --credentials-only \
  --output build/qa/google-auth/emulator-credentials.json
```

The emulator's popup relay still depends on Google's public iframe SDK. A blocked
network can prevent its popup from opening. The explicitly selected
`--credentials-only` mode uses fake emulator provider claims to test Firebase
linking/persistence and the app's identity subscription without that relay. It
**does not qualify `FirebaseAccountService.signInGoogle` or Google's callback**.
The fixture operations verify the local demo project and auth-emulator binding
before any mutation. The harness binds the emulator immediately after the real
SDK's `initializeAuth`: the locked FlutterFire implementation can otherwise begin
restoring a release-build identity before the entry point calls `useAuthEmulator`.
This setup is restricted to disposable test contexts and does not alter the
production Firebase configuration. Emulator results and local test counts are
recorded in [the QA summary](qa/google-auth-2026-10-22.json).

All 18 credential-only checks passed: Chromium, Firefox and WebKit each verified
fresh credential sign-in, identity restoration, sign-out, a collision preserving
the guest, linking preserving the guest UID, and restoration of the linked user.
These are Firebase SDK and app identity-subscription checks with fake provider
claims, not successful real Google popup exchanges.

Added controller regressions cover missing state, unsupported storage, popup
blocking and network failure while owning an active room: each preserves the
guest, resets busy, omits private SDK details, and permits a fresh retry. Further
regressions cover disposal during sign-in and cancellation with a restored Google
identity. Existing tests cover collisions, explicit switching and duplicate taps.

Validation: all 20 account tests, 33 Python release-tool/policy checks, strict
Flutter analysis, and release and emulator web builds passed. The full Flutter
run finished with 1,631 passing tests and one Hex recovery timing failure
(`fresh Hex host and guest return to existing seats and identical saved state`);
that test passed on its isolated rerun. No gameplay source was changed.

## Physical-device acceptance checklist

When a device becomes available, record browser/app and iOS versions, launch
surface, exact Stones origin, normal/private mode and whether the Google window
returns to the original browser. Do not collect callback query parameters.

1. Open the main URL in Safari, then Chrome, without clearing existing site data.
   Test cold home login and the prepared Account card. Complete a real Google
   sign-in, reload, and confirm identity restoration and room access.
2. In a disposable test profile, create a guest room and link a new Google account.
   Confirm the seat remains owned by the same UID. Try a Google account that
   already exists: retain the guest until the explicit switch, and block switching
   while the room is active.
3. Cancel, close, block the popup, interrupt/restore the network, switch apps, lock
   the phone and resume. Confirm recovery and that late callbacks do not switch
   identity after an apparently cancelled attempt.
4. Repeat from Safari Private Browsing, a home-screen web app and a link opened
   inside another app. Mark unsupported surfaces explicitly; keep privacy defaults.
5. If the helper fails, close only that login tab and retry from the originating
   Stones tab. Record whether this works and whether another browser/app handled
   the callback. Reproduce on both old and proposed builds before claiming a fix.

References: [Firebase redirect/storage best practices](https://firebase.google.com/docs/auth/web/redirect-best-practices),
[Google authentication in Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth),
[Firebase emulator authentication](https://firebase.google.com/docs/emulator-suite/connect_auth).
The upstream [iOS redirect regression report](https://github.com/firebase/firebase-js-sdk/issues/10428)
concerns a different flow and SDK version; it is not evidence of the same defect
in Stones' popup implementation.
