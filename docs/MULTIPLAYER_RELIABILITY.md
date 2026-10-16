# Multiplayer reliability audit — 2026-10-16

The reported failure had no device, room code or reproduction steps. These
findings establish independent defects; they do not identify which one caused
that particular attempt.

## Confirmed code paths and repairs

- Failed account initialization stayed cached. Retrying Create/Join after the
  network recovered reused the failure until a separate Settings retry. Failed
  bootstrap work is now released so the next attempt retries, while concurrent
  requests still share initialization and guest identity. Google sign-in benefits
  from the same recovery path.
- Online creation and authentication did not use the controller's network
  deadline. A never-completing request left hosting/joining busy indefinitely.
  Both now use the existing deadline, as do AI lease acquisition and its recovery
  read. Stale completions remain guarded by the session epoch.
- Creating/joining a server room awaited the local shortcut write in the same
  failure path. If device storage failed, the valid room was discarded from the
  controller and the screen could not open. Opening/subscribing now happens
  independently; shortcut failure or timeout shows a persistent warning with the
  room code. It never grants/changes a seat or alters the board. A late failure
  from an old session cannot affect a new match.
- An unconfirmed metadata event reporting connectivity could unlock a board
  after a disconnected event, before a server snapshot confirmed its history.
  Unconfirmed events can now disconnect but cannot reconnect. A confirmed room
  update or explicit server reconciliation restores play.
- Disconnecting while AI search was running cancelled that search without
  clearing its busy state. That also disabled the manual Reconnect button.
  Cancelling an active search now releases busy unless a move still awaits
  acknowledgement; a regression checks recovery before a new server event.

The shared controller fixes apply to new Square and Hex rooms with any supported
seat mixture. The original room codecs and Firebase access policies are unchanged.

## Verification

### Recovery qualification follow-up

The follow-up adds bounded automatic recovery to the shared controller. Transient
transport failures and stale-turn conflicts reconcile with authenticated server
reads after 1, 2, 4, 8, 16 and 30 seconds. Requests have the existing 20-second
deadline. The retry budget resets only when a live subscription confirms a
snapshot; successful reads alone cannot sustain an endless broken-watch loop.
A subscription that never produces its first server snapshot also times out.
Permission, identity and history errors stop automatic retries. The retained
board stays visible, and manual Reconnect starts a fresh retry budget.

Recovery never resubmits an uncertain move. Concurrent reconnect requests share
one operation. Subscription generations reject queued callbacks from previous
watches, and failed or hanging cancellation cannot block a new server read.
Reauthentication must return the original seat owner. Returning from the app's
background performs server reconciliation; exiting the online game screen
detaches the local session without deleting the room or relinquishing its seats.

`test/game/multiplayer_resilience_test.dart` injects subscription errors, silent
completion, missing first snapshots, failed/hung cancellation, lost successful
acknowledgements, account changes and rewritten history. It races two devices on
one seat and two guests claiming an expired AI runner. Twelve seeded multi-client
trials cover both shapes with two, three and four seats, timed and untimed, with
up to 40 turns each, connection loss and repeated cold rejoins. Each confirmed
turn checks board, history length, next player, reserves and clock banks across
clients. These are independent in-memory clients with room codec round trips;
they are not physical devices or Firebase SDK transport qualification.
The screen widget regression covers foreground recovery after missing a turn.

Run 38967940253 at 76e4c31 passed strict analysis, all 715 tests, release web
compilation/startup checks and Android debug APK compilation (including all
12 Android release-preflight tests). Subsequent changes affect the fault-test
fixture only: it now supplies a realistic asynchronous initial snapshot, then
waits for that snapshot before injecting an outage. The first fixture revision
incorrectly injected faults before startup finished and failed five tests in
38968246197; no application change was needed. Corrected source at 2a80658 passed
strict analysis and all 715 tests in 38968912417. Application, dependency and
workflow files are identical to the fully compiled 76e4c31 source.

### Remaining device qualification

Before describing multiplayer as fully qualified, run independent browser and
Android installations against the deployed release, recording versions, room
codes and the action immediately before any failure:

- Host/join both shapes, including four remote seats and a mixed human/AI game.
- Switch Wi-Fi/mobile data and use airplane mode during a turn and while its
  confirmation is pending. Confirm one move, retained previews and recovery.
- Background, kill and reopen host and guest apps; return with the same identity.
  Confirm history, seats, cosmetics and clocks, including elapsed offline time.
- Close the AI runner and let another participant take over after lease expiry.
- Open one seat on two devices and attempt the same turn concurrently.
- Reopen an invitation from a cold start, test a full room and try a different
  identity. No existing seat may be silently reassigned.
- Test the previous installed Android/web release alongside the new web release.
  Shared protocol compatibility is required, while client recovery improvements
  only take effect after that client updates.

### Initial repair evidence

`test/game/multiplayer_recovery_regression_test.dart` exercises stalled creation
on both shapes, stalled authentication during create/join, failing bookmarks
during create/join, hanging bookmarks, late warning isolation, metadata ordering,
stalled AI lease/recovery calls and disconnecting an active AI search.
`test/account_test.dart` checks automatic bootstrap retry for multiplayer and
Google sign-in while preserving concurrent guest-request coalescing.
`test/game/match_screen_test.dart` verifies
that the room, controls, code and storage warning remain available together.

The initial ten regressions were committed separately on
`codex/multiplayer-recovery` to verify failure against the original controller.
Baseline CI run 38964360873 passed the original 668 tests and failed all ten
new regressions, confirming the defects. The first repair at 25888f1 passed strict
analysis and all 682 tests (run 38964619638). Final source at ac44483 passed strict
analysis and all 685 tests in run 38965274544, including account retry and the
AI-disconnect regression. That run also passed release web compilation/startup
fingerprinting checks and Android APK compilation.

The guarded production REST probe passed all six isolated trials on this date:
Square and Hex with two, three and four seats, authenticated joins, themes,
server clocks, AI ownership, rejected stale/stranger writes, independent cold
reads and durable endings. Four anonymous QA identities and six ended rooms
were created; no existing player rooms or policies were modified.

No browser surface was connected for this audit, and the previous temporary
Flutter SDK was no longer usable here. CI provides Flutter analysis, widget/model
tests
and build evidence. These are distinct from a new two-device browser/Android
playtest, which remains necessary to match an otherwise unspecified report.

## Publication

The repair was fast-forwarded and pushed to main at 6c23be5. Deploy Main
38966080464 and Pages publication 38966258462 succeeded. The public startup
ledger names `main.0bca85e7b6b983c54ef5.dart.js`; downloading that entrypoint
confirmed the 6c23be5 version and new shortcut-warning text. Three startup pairs
are retained for cached pages. Refresh the website before retesting.

The shared Android code compiles with these fixes. This audit did not publish
a new Play Store release; installed Android apps require a release containing
the repaired shared code. No Firebase policy, configuration or signing changes
were needed.
