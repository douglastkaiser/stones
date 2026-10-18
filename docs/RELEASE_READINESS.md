# Current release qualification

Updated 2026-10-17. This is the current evidence/checklist; historical audit pages
describe their own revisions and must not be interpreted as today's architecture.
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

Flutter is pinned to 3.47.7 in CI. No functioning local Flutter/Dart command was
found when execution began; approximately 2.4 GB of disk was available. Use CI
rather than installing an unbounded second SDK into this workspace.

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
| `/ratingPools`, `/ratingResults`, votes, limits/AI keys | Public aliases/standings plus private receipts/evidence and anti-duplication metadata | Separate community ratings from cosmetic progress; preserve atomic result identities. |
| `/users`, `/achievements` | Legacy per-owner paths retained by rules | Inspect real wire formats before migration; do not assume these are the authoritative current progression. |
| `achievement_progression_v2` | Device-local counters, evidence, completion IDs, unlocked rewards and pending notices | Preserve old awards; merge by stable evidence/event identities, not by adding two snapshots. |
| `unified_local_match_v1` | One current shared local game with history/configuration | Do not replace during sign-in or while navigating an invitation. |
| `online_rooms_v1` | At most ten local shortcuts scoped by UID | This is not an account-wide room inbox. Import only after checking ownership. |
| Settings/cosmetics preferences | Local audio, appearance, selected earned set, defaults | Keep device accessibility/audio preferences local; synchronize earned ownership separately. |
| Play Games legacy save | Optional native old Square cloud save and a separate identity | Isolate recovery; do not market this as shared-engine/account progression sync. |

The current privacy page claims no analytics/personal data and short room
retention. `web/index.html` explicitly initializes Firebase Analytics, while
accounts, rooms and ratings persist. Do not copy these claims into the next Play
declaration. Decide and implement actual telemetry/retention/deletion behavior
before publishing matching disclosures in finishing packet 11.

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
| 2. Prototype | Isolated candidate published; 31 focused checks, 24 captures and live Square/Hex inspection | Owner visual feedback before applying the design to production screens. |
| 3–12 | Not started | Follow the plan's dependencies and per-packet contracts. |

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
