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

The shared controller fixes apply to new Square and Hex rooms with any supported
seat mixture. The original room codecs and Firebase access policies are unchanged.

## Verification

`test/game/multiplayer_recovery_regression_test.dart` exercises stalled creation
on both shapes, stalled authentication during create/join, failing bookmarks
during create/join, hanging bookmarks, late warning isolation, metadata ordering
and stalled AI lease/recovery calls. `test/game/match_screen_test.dart` verifies
that the room, controls, code and storage warning remain available together.

The initial ten regressions were committed separately on
`codex/multiplayer-recovery` to verify failure against the original controller.
CI results and final publishing status will be recorded after completion.

The guarded production REST probe passed all six isolated trials on this date:
Square and Hex with two, three and four seats, authenticated joins, themes,
server clocks, AI ownership, rejected stale/stranger writes, independent cold
reads and durable endings. Four anonymous QA identities and six ended rooms
were created; no existing player rooms or policies were modified.

No browser surface was connected for this audit, and the previous temporary
Flutter SDK had been removed. CI provides Flutter analysis, widget/model tests
and build evidence. These are distinct from a new two-device browser/Android
playtest, which remains necessary to match an otherwise unspecified report.
