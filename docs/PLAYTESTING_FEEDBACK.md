# Playtesting feedback implementation

Tracks all 18 requirement IDs in the supplied brief (which called them 17).
New gameplay uses the shared match engine. Firebase remains on Spark.

## Verified findings

- BOARD-01: Hex's hand-written fitting denominator overestimated its extent.
  Sizing now measures actual cell centers and polygon extents. Narrow Hex tables
  use available width and scroll controls below the board. Square sizing is kept.
- BOARD-02: Room codecs already preserve host board and per-seat styles. The
  gallery coupled board and piece selection. They now have separate controls;
  join metadata and owner-based buried/preview/carried rendering are retained.
- GAME-01: Shared Court takeback already removes the latest human move plus AI
  replies, persists the rewind, and supports finished games. Existing regressions
  cover both board shapes. No additional online undo protocol was introduced.
- ONLINE-02: The reported production room has three human owners, but only two Google
  accounts and two matching v3 result votes. The third owner is anonymous. No
  receipt exists. The consensus process cannot accept that guest's vote. This is
  confirmed account eligibility, not evidence of slow first-time initialization.
- ONLINE-01: Google sign-in is enabled and both www.douglastkaiser.com and
  douglastkaiser.com are authorized. Current code uses popup sign-in/linking.
  The screenshot is a Firebase missing-state failure; its browser-specific cause
  remains unverified. The owner explicitly deferred this issue pending a retry
  with the playtester. No auth-domain or OAuth-provider change is warranted yet.
- AI-01/AI-02: Current search uses topology-specific geometry, not square-only
  logic. Paired probes reproduced non-monotonic strength when increasing depth
  alone. New search includes alpha-beta for duels, horizon win checks, retained
  root fallback, all-tier tactical defense and controlled lower-tier choices.
  Historical configs keep the v1 engine and rating identities; new configs bind
  the v2 engine and independent ratings.

## Requirement traceability

| ID | Implementation | Verification |
| --- | --- | --- |
| BOARD-01 | Actual Hex extents; width-sized narrow board; scrolling controls | Geometry, phone/layout and real gesture tests; Chromium phone capture |
| BOARD-02 | Independent board/piece selection; preserve room seat styles | Existing room round trips and owner-layer tests, gallery migration tests |
| BOARD-03 | Celestial board-only reward, polled established-human Overall rank | Top-decile boundaries, provisional exclusion, cutoff ties; live server queries |
| UX-01 | App-owned browser history, back to previous screen, forward restoration | Chromium Home → Settings → Back → Forward; Android remains device qualification |
| UX-02 | New-turn/restored-position Flat selection | Wall-to-next-turn widget regression; normal draft clear preserves same-turn choice |
| UX-03 | Own-turn banner and dedicated sound, deduplicated by match/ply | Multiplayer transition logic; sound independent of music |
| UX-04 | Always-available audio control; independent effects/music; bundled loop | Persisted independent settings, enlarged-text phone panel, visual browser check |
| GAME-01 | Verify existing durable Court takebacks | Square/Hex controller and terminal-takeback regressions |
| GAME-02 | Court-only legal next-move win scan for each seat; road or flats | Both shapes, placement/spread legality through MatchRules; stale analysis disposal |
| GAME-03 | Active local elapsed clock; online acknowledged start/finish | Unlimited-game, pause/resume/save/share tests; timestamp authorization tests |
| AI-01 | Measured adjacent difficulty tuning; separate v2 identity | Paired tournament tool, tactical fixtures, complete playthroughs |
| AI-02 | Hex-aware goals and multiplayer utility; improved tactical search | Hex 2–4-seat tactics, legal playthroughs, paired Hex calibration |
| ONLINE-01 | Inspect production configuration; actionable storage error copy | Deferred by owner; real iPhone retry still needed |
| ONLINE-02 | Verified account-status metadata, explicit guest explanation, bounded retries | Three-/four-player settlement emulation, new-player defaults, partial receipts, identity changes |
| ONLINE-03 | Participant-only temporary chat, 500 characters, aggressive masking | Access, impersonation, edits, expiry, closed-game and cleanup emulator tests |
| SHARE-01 | Immutable per-match deltas for player and spectator shares | Signed/zero/pending/unrated text and native/SMS clipboard tests |
| SHARE-02 | Frozen elapsed time in result text | Unlimited/timed and repeated share duration tests |
| DOCS-01 | Publisher Core Rules PDF link in About | Link target from existing rules audit; variant labeling |

## Contracts and limits

- New config `aiEngine` defaults to `shared-search-v2`; missing saved metadata
  decodes to `shared-search-v1`. The original engine remains available for old
  matches. Receipt/profile rules bind each engine to its matching AI identity.
- Local `elapsed.milliseconds` checkpoints active play independently of countdowns;
  local suspension freezes it. Online `startedAt`, `lastMoveAt`, `finishedAt` are
  server timestamps. Existing games without timing evidence retain unavailable
  duration. Completed local history keeps the frozen duration.
- `/playerAccounts/{uid}` contains only `registered: bool`, written by its owner
  and checked against the auth token's anonymous/permanent status. Reads require
  authentication; enumeration and extra identity/profile fields are denied.
  Missing metadata in older rooms remains unknown, never assumed signed in.
- Top-decile eligibility uses human established Overall competition rank at or
  above the ceil(population/10) cutoff, including ties. It is checked on the
  server every minute while observed. Failed checks render the default board;
  selection never grants a permanent achievement. This remains client-enforced
  cosmetic eligibility under the existing Spark trust boundary.
- Chat uses Firebase REST delivery so message bodies never enter the native
  Firestore document cache. UI state is memory-only and starts at room entry.
  Five-minute expiry and closed-table rules deny reads. Connected clients delete
  expired/finished messages. Only pending document IDs/expiry times persist for
  cleanup. Spark cannot guarantee physical deletion while every client is closed;
  an interrupted send can leave an unreadable expired document.
- Effects default on and background music off. Browser audio starts after user
  interaction. New audio is synthesized locally and uses the repository license.
- Browser Forward restores standard material routes. Dismissed transient popup
  routes are not recreated; unsupported forward entries normalize to the current
  visible route. Back is navigation and never implicitly undoes a move.

## Validation and publication

- Flutter 3.47.7 / Dart 3.13.5 installed in the task workspace.
- All 141 Firestore emulator checks passed, including old rating protocols,
  178 online seat combinations, chat and new engine identity checks.
- The complete Flutter regression suite passed 1,027 tests. The final app-shell
  review then passed 28 focused startup, achievement, invitation and audio checks.
  That review also fixed the root's redundant home/initial-route configuration
  and supplied an overlay ancestor for the persistent audio tooltip.
- Strict analysis passed with no issues. Final release web compilation passed.
- All 29 release-tool Python checks passed.
- The [duel calibration record](qa/playtesting-ai-duels.json) contains 600 games:
  50 seeded paired starts per adjacent tier on Square 3×3 and Hex radius 2.
  Stronger-tier decisive win rates were Square 93.8%, 83.5%, 88.7%; Hex 91.8%,
  71.1%, 88.0%. Draws and unfinished trials are reported separately. These are
  default duel results, not a human skill estimate or multiplayer qualification.
- Additional three-/four-seat tactics cover rivals beyond the immediately next
  seat. A small three-seat Hex probe informed that correction. Multiplayer
  calibration remains [exploratory](qa/playtesting-ai-multiplayer-probe.json):
  13 of 27 games exceeded the 80-ply trial bound and Expert did not outperform
  Hard in this small probe. The duel strength claim must not be extended to
  multiplayer. This is an open calibration limit, not a passed acceptance check.
- Independent Chromium phone contexts against Auth/Firestore emulators verified
  chat delivery, substring masking and no restored messages after rejoining.
  Chromium also verified Home → Settings → browser Back → Forward, Hex width,
  and the independent audio switches. External production Firebase/Analytics
  requests were blocked in offline visual trials.
- The owner explicitly approved production Firebase deployment on 2026-10-21.
  Reviewed rules from a72c299 were released at 14:31 UTC to `stones-9a6a0`;
  a subsequent server read matched the source bytes exactly. All six indexes,
  including the single added chat index, were READY at 14:35 UTC. No indexes
  were deleted and billing was unchanged. No receipts or account flags were
  edited by the deployment. See the [release evidence](qa/playtesting-firebase-release.json).
- PR CI passed analysis/tests, room authorization, web and Android compilation.
  Its browser journey exposed a pop/next-lesson race in asynchronous browser
  history. History writes now wait for traversal acknowledgement; focused
  regressions cover immediate next-route pushes and successive app Back actions.
  The journey's turn labels and rated AI fixture also follow the new UI/engine.
  All 28 focused navigation/startup checks and strict analysis passed. The rebuilt
  emulator-only app passed the complete nine-scenario Chromium journey with no
  page errors, including lesson sequencing, durable saves, friend reconnect and
  v2 AI rating settlement/recovery.
- Physical iOS sign-in, Android swipe-back and Play-signed audio/sharing remain
  device qualification, not results established by desktop or emulator checks.

### Reproducing additional checks

- Duel calibration: `flutter test tools/ai_tournament_test.dart --dart-define=AI_PAIRS=50`.
  `AI_PLAYERS`, `AI_TOURNAMENT_SHAPE` and `AI_TOURNAMENT_TIER` select probes.
- Chat journey: build `tools/integration_app.dart` to `build/integration-web` with
  base href `/stones/`, serve it on localhost:4174, start the demo Auth/Firestore
  emulators (9099/8088), then run `python3 tools/chat_browser_journey.py`.
  `STONES_CHROMIUM` can point to an installed Chromium. The tool blocks production
  endpoints and uses independent identities and browser storage.
