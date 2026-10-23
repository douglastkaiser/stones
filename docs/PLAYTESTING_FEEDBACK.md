# Playtesting feedback implementation

Tracks all 18 requirement IDs in the supplied brief (which called them 17).
New gameplay uses the shared match engine. Firebase remains on Spark.

## Current follow-up, 2026-10-23

The [AI upgrade record](AI_UPGRADES.md) supersedes the original v2 strategy and
qualification checkpoint below. New configurations use v3; saved v1/v2 games keep
their engines. V3 continues v2 AI ratings and records the actual engine per game
and new rating-history item. Human rank numbers exclude AI; home/profile and
leaderboard ranks agree, and Your standing opens the player's profile.

Local evidence: 1,765 Flutter tests before final performance optimization,
216 affected AI tests after it, 20 focused tests after runner recovery changes,
a final four qualification tests, 146 rules tests, strict analysis and emulator
web/browser checks. Full strength, native timing and device qualification remain
open. See [release readiness](RELEASE_READINESS.md) for publication prerequisites.
The dated validation and original production diagnosis below are historical.
For subsequent sign-in remediation, see [Google login recovery](GOOGLE_SIGN_IN_FIX.md).

The subsequent 2026-10-23 [stack-control revision](STACK_INTERACTION.md#piece-depth-and-simultaneous-controls-2026-10-23)
adds solid piece depth, restores hold-to-expand in place and makes board taps and
minus/plus available together for pickup and current-drop revision. Its pre-commit
audit, lifecycle repair and fresh source validation are recorded in that contract;
the AI test counts above remain evidence for their own earlier checkpoint.

## Original verified findings

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
  That original checkpoint introduced v2 with independent ratings from v1.
  The current v3 follow-up retains v2 ratings, as described above.

## Requirement traceability

| ID | Implementation | Verification |
| --- | --- | --- |
| BOARD-01 | Actual Hex extents; width-sized narrow board; scrolling controls | Geometry, phone/layout and real gesture tests; Chromium phone capture |
| BOARD-02 | Independent board/piece selection; preserve room seat styles | Existing room round trips and owner-layer tests, gallery migration tests |
| BOARD-03 | Celestial board-only reward, polled established-human Overall rank | Server query selects one established human; live/exported revocation regression |
| UX-01 | App-owned browser history, back to previous screen, forward restoration | Chromium Home → Settings → Back → Forward; Android remains device qualification |
| UX-02 | New-turn/restored-position Flat selection | Wall-to-next-turn widget regression; normal draft clear preserves same-turn choice |
| UX-03 | Online own-turn and shared-device human-turn banner/sound, deduplicated by match/ply | Three-human and mixed human/AI transitions; pause/disconnect suppression; effects independent of music |
| UX-04 | Always-available audio control; independent effects/music; bundled loop | Persisted independent settings, enlarged-text phone panel, visual browser check |
| GAME-01 | Verify existing durable Court takebacks | Square/Hex controller and terminal-takeback regressions |
| GAME-02 | Court-only legal next-move win scan for each seat; road or flats | Both shapes, placement/spread legality through MatchRules; stale analysis disposal |
| GAME-03 | Active local elapsed clock; online acknowledged start/finish | Unlimited-game, pause/resume/save/share tests; timestamp authorization tests |
| AI-01 | Graded v3 search/endgame understanding; continue v2 rating identities; AI standings consume no human rank | Tactical/playthrough tests; actual-default benchmark gate; full strength qualification remains open |
| AI-02 | Hex-aware goals and multiplayer utility; bounded full-round search | Hex 2–4-seat tactics and legal playthroughs; actual three-seat default calibration remains open |
| ONLINE-01 | Inspect production configuration; actionable storage error copy | Deferred by owner; real iPhone retry still needed |
| ONLINE-02 | Verified account-status metadata, explicit guest explanation, bounded retries | Three-/four-player settlement emulation, new-player defaults, partial receipts, identity changes |
| ONLINE-03 | Participant-only temporary chat, 500 characters, aggressive masking | Access, impersonation, edits, expiry, closed-game and cleanup emulator tests |
| SHARE-01 | Immutable per-match deltas for player and spectator shares | Signed/zero/pending/unrated text and native/SMS clipboard tests |
| SHARE-02 | Frozen elapsed time in result text | Unlimited/timed and repeated share duration tests |
| DOCS-01 | Publisher Core Rules PDF link in About | Link target from existing rules audit; variant labeling |

## Contracts and limits

- New config `aiEngine` defaults to `shared-search-v3`; missing saved metadata
  decodes to `shared-search-v1`. Explicit v2 saves stay v2. V3 uses established
  `ai_shared-search-v2_<difficulty>` rating identities; game/receipt/history
  engine stamps retain the actual version. See [skill ratings](SKILL_RATINGS.md).
- Local `elapsed.milliseconds` checkpoints active play independently of countdowns;
  local suspension freezes it. Online `startedAt`, `lastMoveAt`, `finishedAt` are
  server timestamps. Terminal duration requires `finishedAt`; an earlier move timestamp
  cannot stand in for the finish. Existing games without timing evidence retain unavailable
  duration. Completed local history keeps the frozen duration.
- `/playerAccounts/{uid}` contains only `registered: bool`, written by its owner
  and checked against the auth token's anonymous/permanent status. Reads require
  authentication; enumeration and extra identity/profile fields are denied.
  Missing metadata in older rooms remains unknown, never assumed signed in.
- Celestial eligibility belongs only to the single highest-rated established
  human in Overall. Equal ratings use Firestore document ID ordering to select
  one player. It is checked on the server every minute while observed. Failed
  checks render the default board;
  selection never grants a permanent achievement. This remains client-enforced
  cosmetic eligibility under the existing Spark trust boundary.
- Chat uses Firebase REST delivery so message bodies never enter the native
  Firestore document cache. UI state is memory-only and starts at room entry.
  Five-minute expiry and closed-table rules deny reads. Connected clients delete
  expired/finished messages. A separate 30-second cleanup timer keeps running
  while chat is collapsed; receive polling remains opt-in. Only pending document IDs/expiry times persist for
  cleanup. Spark cannot guarantee physical deletion while every client is closed;
  an interrupted send can leave an unreadable expired document.
- Effects default on and background music off. Browser audio starts after user
  interaction. New audio is synthesized locally and uses the repository license.
- Browser Forward restores standard material routes. Dismissed transient popup
  routes are not recreated; unsupported forward entries normalize to the current
  visible route. Back is navigation and never implicitly undoes a move.

## PR review corrections

All seven P2 findings from the review of aa15870 are addressed:

| Finding | Correction | Regression evidence |
| --- | --- | --- |
| Forward restores disposed lesson callbacks | Restored lessons obtain their own achievement notifier and own Next/practice navigation | Real browser Back twice/Forward twice, solve and Next; existing sandbox/progression tests |
| Terminal online clock keeps running | Nullable elapsed state can be cleared; missing finish evidence stays unavailable | Older-client resignation after a known earlier move clears a running clock |
| Confirmed deltas disappear during errors/refresh | Recovery and both manual refresh paths merge the latest immutable receipts, including nonretryable errors | Partial Overall → permission denial; pending/manual/interleaved updates preserve both receipts |
| Same-device multiplayer has no turn cue | Shared-device human turns use the distinctive sound and seat-specific visual banner | Three humans and mixed human/AI tables; rebuild, pause, disconnect and terminal suppression |
| Current AI duplicates legacy placeholders | Canonical rating engine drives placeholders and filters live/static AI standings; historical receipts keep their legacy fallback | Exactly four current opponents; live/static mixed-engine inputs; AI outside top 50 remains visible; the later human-only ranking contract removes AI rank numbers |
| Collapsed chat stops expiry cleanup | Cleanup has an independent timer, local expiry removal and contained errors | Cleanup/retry while collapsed without receives; finish clears and disposal cancels timers; two-browser no-history journey |
| Sharing bypasses celestial revocation | Live and exported boards share reactive eligibility policy; theme/styles enter the PNG capture signature | Revoked at open, regained and revoked again while Share stays open |

The audit still tracks all 18 original IDs. ONLINE-01 remains explicitly deferred
by the owner. AI-01/AI-02 strength qualification and physical-device checks remain
open acceptance criteria, not completed work hidden by the correctness tests.

## Validation and publication

- Flutter 3.47.7 / Dart 3.13.5 installed in the task workspace.
- All 141 Firestore emulator checks passed, including old rating protocols,
  178 online seat combinations, chat and new engine identity checks.
- The previous complete Flutter regression suite passed 1,027 tests. The final app-shell
  review then passed 28 focused startup, achievement, invitation and audio checks.
  That review also fixed the root's redundant home/initial-route configuration
  and supplied an overlay ancestor for the persistent audio tooltip.
- Strict analysis passed with no issues. Final release web compilation passed.
- All 29 release-tool Python checks passed.
- The [duel calibration record](qa/playtesting-ai-duels.json) contains 600 games:
  50 seeded paired starts per adjacent tier on Square 3×3 and Hex radius 2.
  Stronger-tier decisive win rates were Square 93.8%, 83.5%, 88.7%; Hex 91.8%,
  71.1%, 88.0%. Draws and unfinished trials are reported separately. These are
  historical reduced-board duel results. Square defaults to 5×5 and Hex to three
  players, so these results do not qualify the real defaults or the subsequent
  review tuning. They are not a human skill estimate.
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
- After the seven PR-review fixes, all 1,039 Flutter tests passed, including nine
  new review regressions and the existing lesson sequencing/sandbox tests.
  Final production and emulator web builds and all nine rebuilt-browser journeys
  passed with no page errors. Current AI profile fixtures now use v2; mixed v1/v2 regressions cover both live
  and static standings. Strict analysis and all 29 Python release checks passed.
- Review AI tuning adds reserve deployment pressure, a more forgiving Easy move
  set, endgame flat-control evaluation for Hard/Expert and narrower multiplayer
  breadth so Expert can finish more full-round searches within the same budget.
  The [actual-default native probe](qa/playtesting-ai-defaults-probe.json) records
  45 games: three seeds with seat rotations per tier on Square 5×5/two seats and
  Hex radius 2/three seats. All finished within 160 plies. It is exploratory:
  Hex Medium/Easy has equal per-seat win share, and Hard/Medium has many draws.
  It does not satisfy the 50-seed gate or prove the human Expert target. Different
  runtime and ply bounds prevent direct comparison with the historical probe.
- Physical iOS sign-in, Android swipe-back and Play-signed audio/sharing remain
  device qualification, not results established by desktop or emulator checks.

### Reproducing additional checks

- Actual-default calibration: `flutter test tools/ai_tournament_test.dart --dart-define=AI_PAIRS=50`.
  This now uses Square 5×5/two seats and Hex radius 2/three seats. `AI_SIZE`,
  `AI_PLAYERS`, `AI_TOURNAMENT_SHAPE`, `AI_TOURNAMENT_TIER` and `AI_MAX_PLIES`
  select explicit alternatives. Smaller seed counts are exploratory only.
  Qualification requires at least 50 seeded seat rotations, 80% finished trials,
  50% decisive trials and stronger-tier per-seat win share above 60%.
- Native release calibration uses the same runner, rules and wall-clock budgets:
  `dart compile exe -DAI_PAIRS=50 tools/ai_calibration.dart -o build/qa/ai-calibration`,
  then `build/qa/ai-calibration`. Keep its results separate from Flutter/JIT and
  browser/device results; execution speed affects completed search depth.
- Chat journey: build `tools/integration_app.dart` to `build/integration-web` with
  base href `/stones/`, serve it on localhost:4174, start the demo Auth/Firestore
  emulators (9099/8088), then run `python3 tools/chat_browser_journey.py`.
  `STONES_CHROMIUM` can point to an installed Chromium. The tool blocks production
  endpoints and uses independent identities and browser storage.
