# Startup and identity refresh — 2026-10-26

Local, unpublished candidate based on main `8be2bc9`. The workspace was reset to
the fetched main and non-ignored untracked files were removed at the owner's
request before implementation. No gameplay, screen layout, account protocol,
invitation format, save format, Firebase configuration or publication changed.

## Findings and implementation

The previous web loader used blue-gray `#46505A` and brown `#795548` instead of
the app's cream/charcoal backdrop. It dismissed immediately after `runApp()`;
settings loaded independently in both the app and menu, after the menu could
already paint. An out-of-range saved appearance could throw. Android launch and
normal-window resources depended on platform default colors; Android 12 launch
resources were generated only in CI. About used a separate shadowed painter and
the adaptive foreground retained a generic white circle. Web splash generation
could replace the custom loader.

- `assets/icon/stones.svg` is the canonical geometry: three spaced, rectangular
  stones. `scripts/generate_branding.py` generates Flutter geometry and PNGs
  without third-party dependencies; it verifies the inline web geometry matches.
  Flutter uses existing theme foreground/primary colors. Home keeps its header
  controls and layout; About keeps icon/version taps, licenses, rules, privacy,
  feedback and other interactions. The wordmark uses the existing sans font.
- Web appearance resolves synchronously in the document head using the existing
  `flutter.theme_mode` SharedPreferences key. Only valid persisted enum integers
  are accepted; missing, malformed, wrong-type and inaccessible storage fall back
  to system appearance. The initialized menu is built only after the shared,
  idempotent settings future completes. Unrelated malformed preference types use
  their defaults without discarding a valid appearance. Production and emulator
  entry points share `launchStones`; optional services start outside this gate.
- The fixed, scrollable HTML overlay has zero body margin, safe-area padding,
  responsive typography, a status live region and a native Reload button.
  Reduced motion disables both rotation and fade. Foreground/backdrop contrast
  is 11.13:1 light and 14.66:1 dark; accent/backdrop is 6.00:1 and 9.93:1.
  A captured 280 px/200% text case exposed clipped text during development;
  bounded content width and responsive wordmark sizing fix it, with an explicit
  overlay/wordmark overflow regression.
- Only `flutter-first-frame` dismisses the web overlay, with a 160 ms fade and
  no artificial startup delay. Bootstrap download/load, engine and runner faults
  expose readable recovery. At 15 seconds help and Reload appear while the same
  startup attempt continues. Later successful rendering still dismisses it.
- Android uses system-qualified cream `#EDE5D7` / charcoal `#1B1816` launch and
  normal-window resources, including explicit Android 12 window/splash colors.
  Splash PNGs are transparent. Adaptive artwork fits the central 66/108 circle;
  Android 12 artwork fits the central 192/288 circle. Flutter's first interface
  applies the saved appearance after native system appearance.
- Native splash and launcher web generation are disabled. The custom manifest,
  maskable padding, base href placeholder, invitation routing and fingerprint /
  two-previous-release retention remain. CI checks canonical assets before
  generation and checks native backgrounds/custom HTML afterward. Web CI also
  runs startup faults and real painted handoff checks, retaining screenshots,
  frame observations and videos. The legacy branding script delegates to the
  canonical generator; the obsolete fallback wordmark and circle were removed.

## Regression contract and evidence

Updated inventory: **APP-06**, **PREF-01**, **PREF-05**. Adjacent regression
requirements: **APP-01** browser navigation, **APP-02/PREF-06** optional audio,
**APP-03/04/07** About actions, **APP-05/09** fingerprint/retention, base paths and
cold invitations, and existing Square/Hex home/play/learning journeys. No board
gestures, rendering, mechanics or persistent schemas were modified.

Validation uses Windows 11, Flutter **3.47.7**, Dart **3.13.5**, Python 3.13 and
Playwright **1.62.0**. This is local qualification of a modified workspace, not a
published release or two-run remote CI qualification. Source/artifact hashes,
command outcomes and platform gaps are recorded in
[the verification ledger](qa/startup-verification.json).

| Check | Evidence / scope |
| --- | --- |
| Strict analysis | `flutter analyze --fatal-infos`: no issues. |
| Settings/widget regressions | 12 focused tests: Light/Dark/System, invalid types/ranges, unavailable storage, concurrent/delayed single read; menu absent while settings wait, first menu uses Dark, permanently pending audio does not gate it. |
| Complete Flutter suite | All 1,808 tests passed in the final isolated run (8 min 58 sec). An earlier overlapping full/focused run had one missing generated `ink_sparkle.frag` error; it is retained as a failed run, not hidden by focused results. |
| Python release tools | 50 tests passed after regression review, including unchanged previous-release retention checks, custom-loader fingerprint preservation, native resource checks, transparent PNGs and circular icon safe areas. |
| Web release build | Release dart2js build at `/stones/`, local engine resources, then release fingerprint preparation. Known secure-storage Wasm dry-run incompatibilities and existing Cupertino-font warning remain; no Wasm support is claimed. Generated output contains the intended custom loader and identical source geometry. |
| Browser loader checks | Chromium 151 and WebKit 26.5 each passed 16 scenarios: saved modes, absent/wrong-type/out-of-range values (including `2.0`), storage denial, 15-second help, eventual rendering, reduced motion, 280×568 at 200% text, bootstrap download/synchronous/asynchronous failure, engine/runner failure, working Reload and no dismissal on runner completion alone. |
| Compiled browser handoff | Chromium and WebKit each passed five additional cases: saved Light against dark system at 320 px, saved Dark against light system at 1366 px, System/dark phone, invalid/light desktop and unavailable-storage/dark phone. Real compiled entrypoint download delayed 1.2 seconds; optional HTTPS services blocked. First-frame timing, pre-frame loader visibility, backdrop continuity, loading/menu images and video captured. |
| Small/masked icons | Visually inspected favicon at 16/32 px, legacy 48 px icon, circular adaptive/maskable previews and light/dark transparent splash marks. Safe-area bounds also checked automatically. |
| Android build / devices | `flutter build apk --debug` attempted and stopped: Android SDK unavailable. Generated resources and generator repeatability verified; no APK/device launch acceptance is claimed. |

Screenshots inspected:

- [Dark loader, 280 px / 200% text](qa/startup/loader-dark-280-large.png)
- [Light phone menu](qa/startup/menu-light-phone.png)
- [Dark desktop menu](qa/startup/menu-dark-desktop.png)
- [Failure and Reload](qa/startup/bootstrap-failure.png)
- [Small and circular icon previews](qa/startup/icons.png)
- [Phone transition frames](qa/startup/transition-light-phone.png)

Reproduce with the pinned SDK on PATH:

```sh
flutter pub get
python scripts/generate_branding.py --check
dart run flutter_launcher_icons
dart run flutter_native_splash:create
python scripts/check_startup_branding.py
flutter analyze --fatal-infos
flutter test
python -m unittest discover -s scripts -p 'test_*.py'
flutter build web --release --base-href /stones/ --no-web-resources-cdn
python scripts/prepare_web_release.py
python tools/startup_browser_checks.py --root build/web --real
flutter build apk --debug
```

Do not run two Flutter test processes against the same generated asset directory.
Browser evidence is under `build/qa/startup/<engine>/`, including videos and frame
records. `--browser webkit` or `--browser firefox` selects additional installed
Playwright engines. CI uploads Chromium evidence separately from the web artifact.

## Regression review before source promotion, 2026-10-26

The owner authorized commit and push to main after this regression pass. The
review found and repaired two asset-pipeline issues: Git's Windows CRLF checkout
must not count as generated Dart geometry drift, and the launcher generator must
not add its default 16% inset around an already padded adaptive foreground. The
Dart source check now normalizes line endings while PNG checks remain exact;
Android adaptive inset is explicitly zero and checked after generation. These
changes affect generator portability and launcher sizing; application Dart/web
runtime sources and the captured web artifact are unchanged from full validation.

All 50 Python checks and 37 adjacent Flutter regressions passed. The latter cover
startup and saved settings, independent audio controls, About/feedback and app
listener lifecycle, browser history, setup recovery, community/home controls and
Square/Hex setup/play at phone/desktop sizes. Strict analysis passed again.
The prior complete 1,808-test run and Chromium/WebKit 21-case startup runs remain
applicable; no mechanics or application Dart sources changed during this review.
Workflow YAML, native resource XML, deleted-asset replacements, dependency lock
versions and the diff against APP-06/PREF-01/PREF-05 were reviewed. No unrelated
regression was found. Generated analyzer exclusions are excluded from the commit,
as are local SDK/build artifacts. Firebase configuration remains unchanged.

Remote main was still the baseline `8be2bc9` at review. Source promotion does not
publish hosting, Firebase or a Play release. Android compilation/device and
Firefox process-launch gaps below remain explicit qualification limits.

## Remaining qualification

- Android SDK/toolchain compilation, pre-12 and 12+ system light/dark launches,
  launcher masks, normal-window transition and a saved preference opposite to
  system appearance need emulator and physical-device checks. No physical Android
  device, Play installation/update or signed release was tested here.
- Desktop headless WebKit does not establish physical iPhone/Safari acceptance.
  Firefox execution was attempted but its installed Windows executable failed to
  launch with `spawn UNKNOWN`; this is an environment qualification gap.
- Actual screen-reader announcements/focus, device safe-area insets, OS-level
  enlarged fonts, install prompts/standalone startup, PWA shortcut routing and
  offline first launch remain device/browser acceptance tasks. The loader's DOM,
  accessible status/button, overflow and reduced-motion behavior were exercised.
- Synthetic bootstrap/engine/app faults establish recovery paths, not exhaustive
  CDN/proxy/browser-extension failures. Startup observations on localhost are not
  production latency targets. No hosting, Firebase or Play publication occurred.
