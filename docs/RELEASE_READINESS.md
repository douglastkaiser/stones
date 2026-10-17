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
| Android | Last recorded Play submission is code 403, source `6788062` | The October 10 record says in review. Current Play publication/install status has not been rechecked. Do not label it current or available from that record alone. |
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
Python qualification passed all 22 checks after using that writable temp location.

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
| 1. Baseline | Tooling and source/data inventory implemented | Fresh Play status, physical-device measurements and account trials pending. |
| 2. Prototype | Isolated Flutter candidate implemented | CI/layout captures, browser inspection and owner visual feedback. |
| 3–12 | Not started | Follow the plan's dependencies and per-packet contracts. |

Production gameplay, room rules and real-user data have not been changed by the
prototype. Use `lib/design_preview.dart` as a separate entry point. It has no
Firebase initialization, account access, preferences or achievement writes.
Composed sample positions are labeled and never treated as verified match history.
