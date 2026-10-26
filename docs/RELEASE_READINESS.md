# Current release qualification

## Keep active games awake, 2026-10-26 (local source)

PLAY-12 adds automatic screen wake-lock requests on shared Square/Hex and legacy
Square/Hex game pages. Human, mixed and AI-only play stay eligible while waiting
for a move or reconnecting. Explicit pause, completion, leaving/covering the page
and backgrounding release the request. Dialogs retain it. Foreground return
reasserts the eligible request; denied/unsupported requests remain nonblocking
and retry on the next game tap.

Local validation uses Flutter 3.47.7 / Dart 3.13.5 on Linux. The 33 focused
wake-lock/game-screen tests and strict analysis passed. Coverage includes both
geometries with zero/one/two AI seats, five simulated idle minutes, actual local
completion/rematch, remote-turn waiting, online background/reconciliation,
dialogs versus full pages, reference ownership, denied requests and departure
during delayed acquisition. A release web build passed. A localhost Chromium
trial using the browser's real Screen Wake Lock API confirmed acquire → pause
release → resume acquire → leave release in an ordinary computer game.
A second real-API Chromium trial at 390×844 watched two AIs advance from 3 to
20 occupied cells during 15 seconds without input, retaining the wake lock;
pause/resume/leave produced the expected release/acquire/release sequence.
The complete Flutter suite passed all 1,796 tests in 16 minutes 10 seconds.

This is local source qualification, with no hosting or Play publication. Native
Android compilation/install and physical Android/iPhone/desktop display-timeout
trials remain unverified. Browser/device policy can deny or revoke wake locks;
manually locking a device, background execution and laptop lid closure remain
platform-controlled. Headless Chromium and simulated idle time do not establish
physical-device sleep prevention. Safari/Firefox and installed mobile web app
qualification remain pending.

## Android 1.1.0 (503) publication, 2026-10-24

**Available to selected testers.** At 17:04 UTC, Play Console confirmed existing
Alpha **1.1.0 (503)** is available, released October 23 at 7:21 PM Console time.
The 02:13 UTC submission was approved and published automatically with managed
publishing off. Signing, Stones Testing (three users), United
States targeting and other tracks were retained; internal testing remains 385.

The owner requested a visible version increase
from the prepared 1.0.0 (502); source `3995847bb5af77d59e4080d94f207eee6adf7975`
changes only version metadata and inventory documentation relative to `72b9f1d`.
The signed release passed preflight, strict analysis, 1,785 tests, all APK/AAB
builds and signature checks. Two fresh complete eleven-job source-identical CI
qualifications passed. Earlier main WebKit storage-denial timeouts remain in
the audit; no root-cause repair is claimed. All 146 rules tests passed. No
additional Firebase deployment was performed. Play accepted the AAB, reported
Ready to release with zero device-support losses and completed quick checks.
See [the exact release record](releases/ANDROID_503.md) for artifact digests,
signatures and Console proof. Physical-device install/update, real Google
credential exchange and saved-game/usability acceptance remain unverified.
Inventory references updated: APP-07 and APP-09.

## Play store listing refresh, 2026-10-24

The English short/full descriptions, six phone screenshots, two screenshots
per tablet category and feature graphic were uploaded, reviewed, saved and
submitted as six listing changes. Source, hashes, capture provenance, asset
declarations and final Console status are in the [listing record](releases/STORE_LISTING_20261024.md).
APP-10 documents accurate store presentation. These browser captures do not
establish physical Android acceptance. Tester enrollment uses the existing
[opt-in link](https://play.google.com/apps/testing/com.douglastkaiser.stones)
after the tester's Google account email is added to Stones Testing.

## Published web and Firebase release, 2026-10-24

**Published and hosted-verified.** The [live website](https://www.douglastkaiser.com/stones/)
now serves application source `58a1f56545d165becaa23490f92658c041cfc755`: human-only
ranks, matching personal/profile standings, clickable Your standing, v3 AI and
the piece-depth/stack-controls revision. This source includes all
October application commits across 120 remote references. Both complete
[CI attempts](https://github.com/douglastkaiser/stones/actions/runs/40042345439)
passed: 1,785 Flutter tests each, strict analysis, web/Android compilation,
player journeys and independent Chromium/Firefox/WebKit account and production
recovery checks. All 146 [Firestore authorization tests](https://github.com/douglastkaiser/stones/actions/runs/40042345340)
passed. The [Firebase rules publication](releases/FIREBASE_20261024.md) is complete,
with exact source readback, six unchanged READY indexes and 13 production checks.

The first [website publication attempt](https://github.com/douglastkaiser/stones/actions/runs/40047543803)
stopped before changing the website: rollback verification compared the previous
artifact's backend hashes with the new working tree. APP-09 now verifies those
hashes from the explicitly selected previous Git commit. Both deploy and restore
workflows retain full source history for that comparison. Deployment tools are
pinned to the workflow revision, separately from the qualified application source.
All 45 release-tool tests passed, including changed rules/indexes and forged
rollback hashes; the actual previous `56cb6fb` artifact was captured and verified
against its own source. The release-tool fix is main commit `78b9181`; it changes
no application, asset or Firebase contract files relative to the qualified source.

The successful [Deploy Main retry](https://github.com/douglastkaiser/stones/actions/runs/40047952588)
used CI attempt 2's exact production artifact. Publishing commit
`95a3c5d8adc8556024156132765e2ca329a14b6c` passed
[Pages deployment](https://github.com/douglastkaiser/stones/actions/runs/40047999865).
All three hosted browser jobs passed source/integrity verification and all 12
cold/warm/blocked-popup/close-retry checks. Independent readback verified the
live HTML/bootstrap/main bytes against the artifact manifest and the backend
hashes against the published rules/index configuration. Two previous startup
pairs remain retained. The original 81-file `56cb6fb` release is archived for
90 days in rollback artifact `12541513443`.

The [publication audit](qa/publication-2026-10-24.json) binds the source, CI,
backend, artifact digests, rollback and hosted evidence. Android verification
covers compilation; a new Play Store distribution, physical-device trials,
real Google credential exchange and full AI strength/timing qualification are
separate from this web release. Earlier dated source-candidate sections below
retain their historical qualification limits.

## Piece depth and stack controls source candidate, 2026-10-23

Audited source revision based on `7e0cd72`; the owner approved committing and
pushing it to main after the final audit. The
[stack interaction contract](STACK_INTERACTION.md#piece-depth-and-simultaneous-controls-2026-10-23)
records the implementation and verification: solid piece depth for all five sets,
on-board hold expansion with the persistent full tray retained, and simultaneous
board/minus-plus pickup and current-drop controls. PLAY-02–05, PREF-04–05 and
COMPAT-08 are updated. Current instructions distinguish shared play from legacy
inspectors and old pending-drop controls.

The original revision passed 1,778 Flutter tests, strict analysis and production
web compilation on Linux with Flutter 3.47.7 / Dart 3.13.5. The pre-commit audit
reproduced and repaired an inspection-content lifecycle edge case and empty-cell
hold callbacks consuming taps. Added checks cover both repairs, hold/right-click
during drafts and direction restoration through undo.

The final unchanged candidate passes 1,784 full-suite tests with two concurrent
test processes, 99 focused checks, strict analysis, production web compilation,
formatting and diff whitespace checks. The
[source-bound audit record](qa/stack-controls-verification.json) records exact
commands, source/log hashes and remaining acceptance limits; the stack contract
preserves the initial and final stages separately.

These results establish local source qualification. Source promotion to main is
authorized; hosted CI results remain separate evidence. No hosted deployment,
Android build, browser-runtime/device trial or online multi-client trial is
claimed for this UI revision.
Existing v3 AI/backend publication gates below still apply; these UI changes do
not change room/save schemas, authentication, ratings or Firestore rules.

## AI and human standings source candidate, 2026-10-23

The [AI upgrade record](AI_UPGRADES.md) and [skill-rating contract](SKILL_RATINGS.md)
cover human-only ranks, clickable Your standing, v3 multiplayer search and
continued AI ratings with actual per-game engine history. The source candidate
is based on main `5053a0f`; it has not been published.

Local validation passed: 1,765 Flutter tests before final performance optimization;
216 affected AI tests after it; 20 focused cache/history/runner tests after recovery
changes; four final qualification tests; 146 Firestore rules tests; strict analysis;
and a release emulator web build with Chromium phone-viewport journeys. The
[source-bound verification record](qa/ai-upgrade-verification.json) preserves
stages and limitations. These checks do not establish complete strength or timing
qualification: the material pilot grid, held-out tier/reference tournaments,
paired native timing gates and physical-device acceptance remain open.

Publish the updated Firestore rules before publishing a client that creates v3
online games/results. Pushing main runs CI; Deploy Main remains manual. The
Google login publication below is the last recorded deployed web qualification.

## Google login hardening, 2026-10-22

[The login recovery contract](GOOGLE_SIGN_IN_FIX.md#durable-qualification-and-deployment)
records independent three-engine CI, exact-artifact recovery checks, the
version-3 rating-selector correction, two-attempt qualification, verified
rollback preservation and post-publication/daily hosted checks.

Source `56cb6fbd3b46c0a5ddb1ae383b1a77bb931f08c1` passed
[two complete CI attempts](https://github.com/douglastkaiser/stones/actions/runs/39865940116)
and [Firestore Rules](https://github.com/douglastkaiser/stones/actions/runs/39865940202).
All 11 CI jobs passed in both attempts: 1,645 Flutter tests, strict analysis,
44 Python checks, production/emulator web builds, Android debug compilation,
player journeys, 60 emulator account checks and 18 exact-artifact production
recovery cases across Chromium, Firefox and WebKit.

**Published and hosted-verified.** After connectivity recovered,
[Deploy Main](https://github.com/douglastkaiser/stones/actions/runs/39873007245)
published attempt 2's exact production artifact. Publishing commit
`5a6a7557f05ff524c6e1249f3739d8ee44a134fd` passed Pages deployment; the
[main site](https://www.douglastkaiser.com/stones/) serves the qualified source.
Chromium, Firefox and WebKit verified hosted startup integrity and all 12
pre-credential login cases. The previous `2b72e84` release was verified and
archived before publication, with a 90-day rollback artifact retained in that run.
No production rollback was performed.

The first [Hosted login monitor](https://github.com/douglastkaiser/stones/actions/runs/39873375971)
also passed in all three engines; daily checks run at 06:23 UTC.
[The qualification and publication record](qa/google-auth-qualification-2026-10-22.json)
contains job results, artifact IDs/digests, the resolved environment blocker and
remaining acceptance limits. Physical iPhone and real Google credential exchange
remain pending, including browser context, private-mode and app-suspension cases.
Earlier `8ffde24` and unbound local reports do not qualify this release.

## October 20 main promotion

The owner authorized committing/pushing the audited candidate to main, publishing
the qualified website and preparing the signed Android update after Firebase
publication. See [the candidate audit](RELEASE_CANDIDATE_AUDIT.md) and
[player experience and CI](PLAYER_EXPERIENCE.md) for the implemented contracts.

Candidate `a045e37` passed [full hosted CI](https://github.com/douglastkaiser/stones/actions/runs/39497631177)
and [Firestore authorization](https://github.com/douglastkaiser/stones/actions/runs/39497631273):
996 Flutter tests, strict analysis, 29 release-tool checks, production web and
Android compilation, nine browser journeys with zero page errors and 136 security
checks. The hosted web artifact passed independent 77-file manifest verification
after download, including its hidden Flutter build file. Twelve longer local AI
games passed across Square duels, four-player Square and three-player Hex; all
finished within 100 plies, with legal moves and no threefold-repeated positions.

[Firebase publication](releases/FIREBASE_20261020.md) is complete: the exact tested
rules were published/read back, all five indexes remain READY, and 13 read-only
production access checks passed. No player/game/rating records were seeded or
rewritten. This main promotion records that backend state without changing Dart
sources or the qualified rules/indexes.

Main must pass its own push CI and rules runs before Deploy Main can publish its
exact verified web artifact. Android Release separately creates signed APKs/AABs;
the existing workflow does not upload to Google Play. Follow the actual workflow
run/artifact evidence for completion; this commit does not predeclare publication.

Physical-device/Play upgrade, Google sign-in, independent account settlement,
large-text/screen-reader and newcomer playtests remain acceptance work. iOS has
no configured application and is unsupported. Account-progress sync, an account-
wide inbox, online rematch consent and reminders remain later work.

The sections below retain historical evidence updated 2026-10-17 onward. Their
SDK availability, test counts and deployment state describe their own revisions;
use the candidate audit above for the current qualification.
The delivery tracker is [FINISHING_PLAN.md](FINISHING_PLAN.md).

## Baseline before finishing work

| Surface | Observed evidence | Qualification limit |
| --- | --- | --- |
| Source | `main` at `4ac6485` before branch `codex/finishing-foundation` | Finishing changes are isolated on the branch. |
| Hosted web | `abbc262`; [Deploy Main 39054797531](https://github.com/douglastkaiser/stones/actions/runs/39054797531) succeeded | HTTP startup integrity verified again on 2026-10-17; not a phone performance test. |
| Last full qualification | `c0ed867`: 776 Flutter tests, strict analysis and web/Android builds; 77 emulator security checks | A previous revision's result does not qualify new code. |
| Android | Play Console rechecked October 17: code 403, source `6788062`, Available to testers on Google Play, full rollout on Closed testing - Alpha. Internal testing remains 385. | Actual install/update and account/device qualification are still pending. |
| Firebase | Spark; published ratings rules and enabled indexes; both custom-domain authentication entries saved | Firefox Android credential exchange still needs a real device trial. |

The live public entrypoint currently names
`flutter_bootstrap.d79be656aac029f5ef11.js` and
`main.9af5473e04e2605e15d0.dart.js`. Both content hashes match their filenames;
HTML, bootstrap and the startup manifest agree. Two previous pairs are retained.
The current main JavaScript is 3,818,455 bytes uncompressed. A single observed
transfer took 1,578 ms; that is **not** time to first useful frame or compressed
download size, and must not be used as a mobile speed claim.

## Reproduce checks

Flutter is pinned to 3.47.7 in CI. Use the same version locally. Keep SDKs and
generated artifacts outside version control. Android compilation requires JDK 17
with javac and the configured Android SDK; the rules emulator requires Java 21.

```sh
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build web --release --base-href /stones/
flutter build apk --debug
python -m unittest discover -s scripts -p 'test_*.py'
python scripts/release_baseline.py --live --output build/qa/release-baseline.json
flutter test tools/shared_performance_probe_test.dart --reporter expanded
```

On Windows if the sandbox temp directory denies test cleanup, set TEMP and TMP
for that command process to a writable workspace directory such as
`build/test-temp`. This avoids changing tests to bypass a filesystem failure.
Python qualification passed all 25 checks after using that writable temp location.
Use `--fresh` on the baseline script when a new preview path has a cached CDN 404;
use `--expected-source <revision>` to reject a coherent but older preview.
The main/bootstrapping scripts are still checked against their exact fingerprints.

The shared performance probe covers both shapes, two/four players and all four
AI levels on the **current** shared engine. It reports elapsed time and event-loop
gaps on the named runner. The older `tools/performance_probe_test.dart` measures
legacy engines and cannot qualify the new match engine.

## Stored data and migration boundaries

No production user enumeration or personal-data export was performed for this
inventory. Fields/ownership below come from the current models and rules.

| Store | Ownership and content | Migration obligation |
| --- | --- | --- |
| Firebase Authentication | Guest/permanent UID, Google provider/profile | Preserve seat UID on guest linking; explicitly handle existing-account collisions. |
| `/matches` | Private room code, host/owners, immutable configuration/themes, moves, clocks, runner lease and rating metadata | Keep version-1 readers; never reinterpret old termination rules. |
| `/games`, `/hexGames` | Older Square/Hex room codecs, including assigned-goal Hex versions | Keep legacy invitation/read adapters until an explicit sunset exists. |
| `/ratingPools`, `/skillPools`, `/skillSettlements`, `/ratingResults`, votes, limits/AI keys | Public aliases/standings plus private receipts/evidence and anti-duplication metadata | Separate community ratings from cosmetic progress; preserve atomic result identities. |
| `/users`, `/achievements` | Legacy per-owner paths retained by rules | Inspect real wire formats before migration; do not assume these are the authoritative current progression. |
| `achievement_progression_v2` | Device-local counters, evidence, completion IDs, unlocked rewards and pending notices | Preserve old awards; merge by stable evidence/event identities, not by adding two snapshots. |
| `unified_local_match_v1` | One current shared local game with history/configuration | Do not replace during sign-in or while navigating an invitation. |
| `online_rooms_v1` | At most ten local shortcuts scoped by UID | This is not an account-wide room inbox. Import only after checking ownership. |
| Settings/cosmetics preferences | Local audio, appearance, selected earned set, defaults | Keep device accessibility/audio preferences local; synchronize earned ownership separately. |
| Play Games legacy save | Optional native old Square cloud save and a separate identity | Isolate recovery; do not market this as shared-engine/account progression sync. |

The checked-in privacy page now discloses voluntary feedback email, account/room/
rating storage and existing website Analytics initialization; it no longer claims
no personal data or automatic room deletion. Publication, actual telemetry/
retention/deletion controls and matching Play declarations still require packet 11
qualification. The wording change does not implement deletion or change telemetry.

## Device and usability evidence still required

The following are **pending**, not passed by model/widget tests or HTTP requests.
Record build SHA/version, device/browser/version, connection, scenario and result
for each trial. No named physical reference phone is available to this agent.

| Target | Startup/input/AI | Google account | Invites/recovery | Progress/reminders | Accessibility |
| --- | --- | --- | --- | --- | --- |
| Firefox Android on the user's phone | Pending | Pending after domain repair | Pending | Pending new features | Pending |
| Chrome Android, midrange reference phone | Pending | Pending | Pending | Pending | Pending |
| Play-distributed Android candidate | Pending install/update | Pending signing-identity trial | Pending cold/warm links | Pending | Pending TalkBack |
| Desktop Chrome and Firefox | Pending current candidate | Pending independent accounts | Pending | Pending | Pending keyboard |
| Safari web | Pending | Pending | Pending | Supported notification combinations must be stated | Pending |

Capture cold/repeat time to useful frame, 95th percentile visible input response,
frame behavior while AI searches, reconnect and resume latency. Record hardware,
network and sample count. The proposed input target is 100 ms on a named midrange
phone; startup/frame thresholds must be justified from measurements.

Minimum fault journeys: close/reopen host, background during an AI turn, switch
network during a pending move, open the same seat on two devices, reopen after
an update, interrupt a progress sync and finish a rated game with independent
Google accounts. Each must preserve the last server-confirmed state.

## Execution status

| Packet | State | Remaining gate |
| --- | --- | --- |
| 1. Baseline | Tooling, source/data inventory and current Play status verified; shared-AI VM measurements recorded | Physical-device measurements and account trials pending. |
| 2. Prototype | Revised game-first direction approved by owner | Applied to real home/setup in packet 3. |
| 3. Setup/invitations | Code and review builds qualified; root Android association published | Merged to main at `7036dd9`; independent invitee and Play-signed device trials pending. |
| 4. Account progress | [Merge/cache foundation and verified-event adapters](ACCOUNT_PROGRESS.md) implemented | Remote adapter, rules, live-provider integration, account UI and multi-client qualification pending. |
| 5–10, 12 | Not started | Follow the plan's dependencies and per-packet contracts. |
| 11. Account/support | [Feedback flow](FEEDBACK.md) implemented; checked-in disclosures corrected | Account deletion, retention/telemetry decisions, publication and Play disclosures pending. |

Production gameplay, room rules and real-user data have not been changed by the
prototype. Use `lib/design_preview.dart` as a separate entry point. It has no
Firebase initialization, account access, preferences or achievement writes.
Composed sample positions are labeled and never treated as verified match history.

Play Console currently shows three opted-in closed testers. Production is inactive
and its application action is disabled. Its displayed requirement is twelve
opted-in testers for fourteen continuous days; that store gate is separate from
the product usability/friend-game gates. No track, tester list, account permission
or Play release was changed during this inspection.

Prototype qualification at `fce59c6`: [full CI](https://github.com/douglastkaiser/stones/actions/runs/39077486497)
passed 807 Flutter tests and strict analysis. [Preview workflow](https://github.com/douglastkaiser/stones/actions/runs/39077486576)
passed all 31 focused tests, generated 24 screenshots and measured 16 shared AI
workloads. The CI runner returned legal moves in 43–1,500 ms, with largest measured
cooperative event-loop gaps of 4.2–6.2 ms. These are bounded-workload VM observations,
not whole-game complexity coverage or physical phone frame-rate claims.

Final packaging candidate `d3b129a` passed [full CI](https://github.com/douglastkaiser/stones/actions/runs/39078011782):
807 Flutter tests, strict analysis, the normal release-web build and Android debug
APK compilation. Its [preview workflow](https://github.com/douglastkaiser/stones/actions/runs/39078011754)
also passed the 31 focused tests, 24 captures, 16 AI probes and isolated web build.
The published source metadata matches `d3b129a`; HTML, manifest and content hashes
agree. The previous preview startup pair is retained and its served hashes were
verified. Both font license files are served with the redistributed fonts.

The final baseline helper additionally checks an expected preview source revision
and refreshes mutable metadata to avoid treating a coherent old deployment as the
new one. All 25 Python checks passed locally, including these final diagnostics.
This helper/documentation follow-up changes no Dart runtime code. No production
game deployment, Play upload or Firebase policy change occurred in this packet.

## Game-first feedback revision

Owner feedback rejected the hospitality slogans and corporate landing-page feel.
Candidate `c48102c` replaces those with a direct play/learn menu, concrete rule
examples and ink/paper/copper surfaces. [Full CI](https://github.com/douglastkaiser/stones/actions/runs/39079325527)
passed 808 tests, strict analysis, web and Android debug compilation. The
[preview workflow](https://github.com/douglastkaiser/stones/actions/runs/39079325618)
passed 32 focused tests and 16 AI probes, captured 24 layouts, and published the
isolated preview. Pages run 39079468729 succeeded. The live footer matches
`c48102c`; switching from the resolved road to the eight-stone stack updates the
board and explanation. Visual approval remains pending.

The standalone HTTP/hash diagnostic was not executed because automatic approval
review hit an account usage limit. Do not record that as an integrity pass or
failure. The CI formatter patch is applied locally; a browser-title cleanup and
these evidence notes follow the reviewed source. No production gameplay, Firebase
policy or Play release has changed.

Follow-up `431cb20` passed preview run 39095129214 and Pages run 39095263203.
Its served revision and startup integrity passed the live baseline check after
publication; the earlier review usage-limit interruption is resolved. The final
normal CI run 39095129219 was still running at this record update. The preceding
full qualification covers the layout/interaction change; this follow-up changes
only formatting and the browser-tab title.

## First-game integration qualification

`b8666a5` passed [full CI](https://github.com/douglastkaiser/stones/actions/runs/39097647956):
833 tests, strict analysis, web release and Android debug builds. Its
[review pipeline](https://github.com/douglastkaiser/stones/actions/runs/39097647931)
passed 81 focused tests, 16 AI probes, 30 captures and both isolated web builds.
The actual app at `/stones/pr/finishing-game/` serves the expected source and
passed startup integrity checks. It uses real app services; the separate
`/stones/pr/finishing/` entry remains a sample without Firebase initialization.

The root website association uses the Play app-signing fingerprint, was published
from root-site commit `ba451723d035df7683570d3f96c1b983d855e8e3`, and returned
HTTP 200 with the exact expected JSON. A Play-installed device has not yet proved
cold/warm app-link routing or sharing. See [environment handoff](ENVIRONMENT_HANDOFF.md)
and [first-game invitations](FIRST_GAME_INVITATIONS.md). The finishing branch is
not merged to main, and these changes have not produced a Play release.

## Main promotion requested by owner

On 2026-10-18, the owner explicitly requested committing/pushing all remaining
finishing work to main before closing the thread. This supersedes the earlier
branch-only status above. The qualified implementation is being promoted intact;
remaining device/invitee gates and later finishing packets are still outstanding.
Deploy Main is manual and no new web publication or Play release is part of this
final commit/push. Continue from the latest main in the next environment.


## Owner-requested home, table and invitation follow-up

See [community and layout qualification](COMMUNITY_AND_LAYOUT.md). Home sign-in,
editable Stones profiles, wider desktop boards, compact mobile controls, top-of-
table invitations, QR display/scanning and opt-in Open tables are implemented
locally. The full Flutter suite passed 884 tests, followed by 44 focused tests
after the final desktop correction. Strict analysis, the final release-web build
and all 81 Firestore emulator tests passed. After the owner completed Firebase
browser login, the additive rules were published on 2026-10-19 UTC; the active
production rules source matches the tested SHA-256 recorded in the linked notes.
The app client has not been published; physical-device camera and independent
production-account qualification remain release checks.
