# Performance and online recovery audit

Updated 2026-10-09. Application behavior, not a change to square Tak or Hex rules.

## Player questions and recovery contract

- Can a host or guest close the app, refresh, or return tomorrow? Online rooms
  remain in Firestore. The menu's **Resume online game** list stores up to ten
  local room pointers, separately for square and Hex. Loading a pointer fetches
  the current room; it does not trust a cached board as the saved game.
- Does the host need to remember a code? Creation saves the pointer before the
  server request, covering a close while awaiting acknowledgement. Joins save
  after validating the intended seat and before sending its reservation. A
  request that never committed can leave a shortcut to a nonexistent room;
  resume reports that error, and removing the shortcut does not delete a room.
- Can a different identity take over a saved seat? Resume checks the saved UID
  against restored authentication, then verifies room ownership. It never fills
  a new seat as a substitute for recovery. The room code is an invitation,
  not a credential for taking an occupied seat.
- What comes back? Board, reserves, turn, move history, completed result, host
  board theme and participants' piece sets. Square replay verifies the recorded
  mover and pickup/drop count; it stops at the first bad record and retains the
  last valid prefix. Finished rooms are available to their existing players.
- What if a move fails to save? Square input locks while its transaction is
  pending. The transaction verifies the expected log prefix and turn. Failure
  triggers a server rebuild or a visible reconnect error, rather than pretending
  the optimistic move was saved. Hex already uses acknowledged snapshots.
- Does a slow cached snapshot allow play? Square listens to metadata changes
  and locks input until a server snapshot confirms state. A listener from an old
  room cannot mutate a newer room. Both modes cancel subscriptions on disposal.
- What happens to Hex AI? The returning host restores bot scheduling. Guests
  keep their seats. AI pauses while the host is absent; authority does not
  silently transfer to another guest.
- What happens to clocks? New timed square moves checkpoint both balances in
  the move record. Recovery subtracts elapsed time using the server's last-move
  timestamp; timer callbacks use wall-clock elapsed time instead of counting
  ticks. Timeout results are committed to the room and replayed by both clients.
  Legacy logs with only client move timestamps have approximate balances.
- What if storage is cleared or another device is used? Anonymous identity and
  shortcuts belong to the browser profile/origin. Clearing data, private-session
  teardown, reinstalling, or another browser can lose that identity. Signed-in
  users can rejoin by code on another device with the same Firebase account.
  Account linking/cross-device guest recovery is separate product work.
- Does absence destroy or automatically resign a room? No. Removing a menu
  shortcut also leaves the server room untouched. No move for a minute is
  described as inactivity, not proof of a disconnection.

## Speed findings and changes

| Area | Finding | Change / practical limit |
| --- | --- | --- |
| Web startup | Deprecated `loadEntrypoint`, `window.load` dependency, eager reCAPTCHA script | Modern generated bootstrap starts immediately; App Check activates when online play initializes. Firebase project configuration is preserved. |
| Menu | Offline entry also initialized Firebase ratings and requested AI rating documents | Load cached ratings only; online features initialize their backend when requested. |
| Release logging | Every interaction and online snapshot printed verbose diagnostics | Game, online and rating diagnostics print only in debug builds. |
| Square AI | Yielding only between root candidates leaves expensive subtrees blocking browser input | Cooperative ~4 ms slices throughout ranking, threat scanning and recursive search, plus cancellation when the board/screen changes. Native AI remains isolated. |
| Thinking delay | Unbounded large-board Expert search can take seconds | Iterative deepening retains a fully completed search. Easy/Medium/Hard/Expert budgets are 350/600/1000/1500 ms, checked at work boundaries; an individual operation can exceed a boundary. The existing 200 ms presentation delay and isolate overhead are additional. |
| Hex AI | Root-only yielding still blocks during ranking and MaxN recursion | Cooperative ranking and recursive MaxN; native computation remains in an isolate. |
| Hex sync | Every snapshot rebuilt the complete move log | Validate immutable prefix records and apply only appended moves. Metadata-only updates reuse the board. Fresh recovery still validates the entire log. |
| Hex rendering | Identical style/selection lists and new geometry objects caused unnecessary paint/reclip work | Compare values, preserve clips when geometry is unchanged, and isolate board painting with a RepaintBoundary. Square already isolates cells. |
| Clocks | Delayed/background timers lost elapsed seconds | Derive remaining time from wall-clock elapsed time and durable online balances. |

Five procedural themes remain code-based, avoiding extra bitmap sets or asset
downloads. Sound assets are small and already reused. Runtime fonts, the Flutter
engine and Firebase web SDK still contribute to a cold browser load; the release
payload measurements and browser trials below are distinct from native phone
performance. There is no claim that a cached desktop load predicts a slow
mobile connection.

## Measurement and verification

Repeatable diagnostic:

```sh
flutter test tools/performance_probe_test.dart --concurrency=1 --reporter=expanded
flutter test --concurrency=1
flutter analyze --fatal-infos
flutter build web --release --base-href /stones/
```

The probe exercises every square difficulty on 5×5/8×8 and every Hex radius.
Its 1 ms timer records event-loop gaps while direct VM search runs. It is a
development-host scheduling diagnostic, not Android/iOS or JavaScript frame
timing. Compare equivalent workloads on the same machine; JIT warm-up affects
the first sample. Timing is reported rather than asserted in CI.

Before adding the thinking budget, the empty 8×8 Expert workload took 10.16 s
uninterrupted and 10.68 s cooperatively. Cooperative search's maximum observed
VM event-loop gap was 8.69 ms; 5×5 Hard/Expert gaps were 4.77/4.81 ms. Radius-4
Hex took 1.44 s cooperatively with a 5.89 ms maximum gap. Those initial numbers
explain the changes; rerun the probe for current bounded square search.

Recovery regressions cover new persistence instances, malformed shortcuts,
both square colors, corrupt logs, finished and waiting rooms, clock absence,
fresh Hex host/guest controllers, host AI restart, wrong identities, and the
menu at 360/1440 px. Responsive-search tests check cancellation and tactical
decisions. The complete suite passed 286 tests before the final small rendering/isolation
refinements; 74 focused tests then passed, followed by 12 recovery/isolation
checks and 11 timing probes. Final review added lesson/isolation and in-flight
Hex AI coverage; all 20 recovery/controller review tests passed. Strict analysis
passed. Release web compilation
passed; its remaining Wasm dry-run warnings come from secure-storage interop.
No physical Android/iOS device or live Firebase room was used.

Final bounded VM samples (empty boards):

| Board | Easy | Medium | Hard | Expert |
| --- | ---: | ---: | ---: | ---: |
| 5x5 | 43 ms | 55 ms | 698 ms | 1500 ms |
| 8x8 | 162 ms | 258 ms | 1000 ms | 1500 ms |

Largest-board Expert's cooperative max observed event-loop gap was 4.83 ms.
Hex radii 2/3/4 took 89/395/1557 ms, with maximum observed gaps of
5.01/5.07/5.77 ms. These are single-host samples, with warm-up and runtime
variation; they are not latency guarantees.

The JavaScript release entrypoint is 3,604,458 bytes (1,057,641 bytes when
locally gzip-compressed). Bootstrap is 13,563 bytes / 5,410 gzip. The Chromium
CanvasKit engine is another 5,428,806 bytes / 2,059,127 gzip; the universal engine
is 7,284,602 bytes / 2,911,112 gzip. A browser selects its engine, rather than
necessarily downloading both. Sound assets total 46,360 bytes. Gzip sizes are
local estimates, not verified hosting transfer sizes.

The release browser trial exercised an 8x8 Expert AI opening at desktop and
390x844 phone viewport sizes, with no captured warning/error logs. Viewport
simulation checks layout, not physical phone performance. A final warm localhost
reload reached the bootstrap app-ready marker in 992 ms (browser-control wall
time, one sample, without cold-network or CPU throttling). Backend identity,
network and close/reopen trials remain pending. Returning to the menu during
AI computation remained responsive. The final bootstrap also hides the finished
loading indicator from the accessibility tree.

## Deployment and remaining boundaries

No new collection, query index, document migration or asset upload is needed.
The updated game rules from the previous theme iteration still need deployment;
see [Firebase preparation](FIREBASE_PLAYTEST.md). Optional clock balance fields
are additional move metadata allowed by the checked-in square move validator.
Production policy must still be compared before deploying.

Live close/reopen, multi-tab transaction races, network interruption and
background phone behavior require a deployed backend and two independent
identities. Clock balances and expiration remain honest-client logic: they are
not a server-authoritative rated clock and can be affected by device clock skew
or a modified client. Match-based Elo idempotency, coordinated rematches,
consensual takebacks, linked guest accounts, bot-host handoff, and a server room
retention policy remain separate follow-ups. Do not declare those verified from
the controller tests.

Official references: [Flutter web initialization](https://docs.flutter.dev/platform-integration/web/initialization),
[Firebase authentication persistence](https://firebase.google.com/docs/auth/web/auth-state-persistence),
[Flutter Firebase authentication](https://firebase.google.com/docs/auth/flutter/start),
and [App Check reCAPTCHA setup](https://firebase.google.com/docs/app-check/web/recaptcha-provider).
