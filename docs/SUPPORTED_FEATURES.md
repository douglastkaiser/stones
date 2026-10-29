# Feature inventory and regression contract

Updated 2026-10-26 against published application `58a1f56`, including the ranking/large-board
follow-up in [skill ratings](SKILL_RATINGS.md#ranking-and-large-board-ai-follow-up-2026-10-23)
and [v3 AI upgrades](AI_UPGRADES.md).
The 2026-10-23 [stack-control revision](STACK_INTERACTION.md#piece-depth-and-simultaneous-controls-2026-10-23)
adds bounded piece depth, restores on-board hold expansion and supports board
taps alongside pickup/current-drop minus-plus controls. Its implementation and
local qualification are recorded separately from the [completed web/Firebase publication](RELEASE_READINESS.md#published-web-and-firebase-release-2026-10-24)
and pending physical-device acceptance.

This is the durable reference for what Stones
does, what it is intended to do, and what future changes must preserve. Its scope
is the **entire available history**: 489 reachable commits from the initial
2025-12-05 commit through the `fc31e80` gameplay update, checked against current screens, services,
tests and product plans. Related fixes are grouped by feature. Commit references
explain provenance; the current behavior below takes precedence over an older
commit's design or an audit's historical status.

The 2026-10-22 Google sign-in update below extends this baseline; see
[its implementation and qualification limits](GOOGLE_SIGN_IN_FIX.md).

The main sections describe current implementation contracts. The later tables
explicitly retain historical capabilities with incomplete shared-engine parity,
planned capabilities, and intentional exclusions. Implementation, usability
acceptance and platform deployment are separate facts; this document does not
certify a fresh app trial. See [release readiness](RELEASE_READINESS.md) for
distribution and device qualification.

## How a coding agent should use this document

1. Before editing, identify affected feature IDs and adjacent features that share
   state, controls, storage, identity or navigation. Read their linked contracts.
2. Preserve the described behavior and compatibility. An intentional change must
   revise the corresponding entry, explain migration/limits, and stay within the
   user's task. A feature missing from a newer screen is a parity question to
   investigate, not permission to silently drop it.
3. Use the regression map and journey matrix below to select meaningful tests
   and manual trials. Include failure/recovery paths and relevant combinations,
   rather than testing only the new happy path.
4. Update this inventory in the same change when behavior, support or a known
   gap changes. Retain feature IDs; add IDs rather than renumbering existing ones.
   Do not turn this into a per-release completion checklist.
5. Report the affected IDs, verification performed and unresolved limits in the
   handoff. Keep build/platform-specific results in the relevant audit or release
   record. Passing unit tests does not establish usability or deployment.

## Product scope

Stones should be a welcoming place to learn and play Tak with friends, on one
device or across devices and days. Standard two-player Square is the introduction;
Hex and flexible multiplayer are explicit variants. Preserve guest access, shared
controls, local AI, optional Court coaching, learning, five coordinated visual
sets, progression and community competition. Advanced configuration and ratings
should not obstruct starting an ordinary game.

The [finishing plan](FINISHING_PLAN.md) records the intended complete journeys,
including work still pending below. It is the source for product decisions;
[the development map](DEVELOPMENT.md) identifies current architecture.

## Start and configure a game

Sources: [first-game invitations](FIRST_GAME_INVITATIONS.md),
[player experience](PLAYER_EXPERIENCE.md), [shared play](UNIFIED_PLAY_PLAN.md).
History: `cf126b9`, `87f40d9`, `47191d3`, `7f6d298`, `45d2946`, `2df1b28`.

- **SETUP-01 · Quick starts:** start coached Square practice, ordinary computer play,
  friends on one device, or an online invitation from the game menu without
  having to understand every advanced setting. Learn with the computer explicitly
  identifies its Court Mode coaching, Tak! warnings and takebacks.
- **SETUP-02 · Square and Hex:** choose either shape; Square defaults to an untimed 5×5
  duel and Hex to an untimed radius-2 three-player variant. Standard Tak and
  additional variants remain distinguishable.
- **SETUP-03 · Custom tables:** configure Square sizes 3–8 or Hex radii 2–4, two to four
  seats, starter, and supported clock/practice options. Saved setup preferences
  survive returning to Customize.
- **SETUP-04 · Seat choices:** use local humans, remote humans and individually configured
  AI seats, including mixed tables and AI-only observation. Setup makes who will
  control each seat clear.
- **SETUP-05 · Protect an existing game:** starting or joining another game asks before
  replacement; cancelling or a failed join preserves the active game and save.

- **SETUP-06 · Identity and seat order:** human color/seat, starter and AI difficulty
  remain distinct choices. Adding/removing a setup seat or changing shape retains
  valid settings and adjusts incompatible options visibly. A two-player Square
  rules profile cannot silently apply to a different shape or player count.

## Core rules and variants

Sources: [official-rules audit](TAK_RULES.md), [shared play](UNIFIED_PLAY_PLAN.md),
[legacy Hex](HEX_MODE.md), [Hex victory audit](HEX_VICTORY_AUDIT.md).
Implementation: [shared rules](../lib/game/match_rules.dart),
[configuration](../lib/game/match_config.dart), [geometry](../lib/game/board_geometry.dart).
History: `3634f4b`, `aad64fd`, `7b5e726`, `cf126b9`, `f6660ac`, `47191d3`, `b81e5a8`.

- **RULE-01 · Supplies and opening:** Square ordinary/cap supplies are 10/0, 15/0,
  21/1, 30/1, 40/2 and 50/2 for sizes 3–8. Flats and walls share the ordinary
  reserve. The first complete seat cycle places the next seat's flat and consumes
  that seat's supply; movement, walls and caps are forbidden during the opening.
  Standard two-player opening remains the official opposing-flat exchange.
- **RULE-02 · Placement and control:** place only on empty in-bounds cells from
  the appropriate reserve. Only the exposed top stone controls a stack. Capturing
  control does not change the identities or order of buried stones.
- **RULE-03 · Stack movement:** lift a nonempty top portion of an owned stack up
  to the geometry's carry limit; stack height itself is unlimited. Move straight
  through orthogonal Square or neighboring Hex cells with positive bottom-first
  drops, preserving order. Ordinary movement cannot cover walls or capstones.
- **RULE-04 · Capstone crushing:** a capstone alone on the final drop may flatten
  either owner's wall. A cap above another carried stone cannot crush prematurely;
  earlier legal drops may leave the cap alone for the final step.
- **RULE-05 · Roads:** only exposed flats and caps connect opposite sides; walls
  and diagonal Square contacts do not. Resolve after the complete move. A mover
  with a road wins simultaneous roads; an opponent-only road can win for that
  opponent. Shared multiplayer also handles multiple opponent roads as a draw.
- **RULE-06 · Flat endings:** only without a road, a full board or a seat's exhausted
  total reserve ends play. Count exposed ordinary flats only; tied leaders draw.
  An unused cap keeps the total reserve nonempty. Do not introduce automatic
  repetition/no-progress draws or komi into the default rules.
- **RULE-07 · Variant identity:** standard Tak is two-player Square. Variable-seat
  Square and Hex retain explicit versioned Stones rules. New shared Hex players
  have symmetric opposite-side goals; old assigned-goal Hex rooms keep their
  original interpretation. Geometry, opening, reserves and outcomes agree across
  human previews, AI, studies, saved replay and online validation.
- **RULE-08 · Atomic moves:** illegal, stale or finished-state moves leave the
  board, turn, reserves, confirmed log and rewards unchanged. A spread commits as
  one move; a draft never advances turns or submits an intermediate result.

## Play and understand the board

Sources: [rules audit](TAK_RULES.md), [Hex victory](HEX_VICTORY_AUDIT.md),
[stack interaction](STACK_INTERACTION.md), [layout](COMMUNITY_AND_LAYOUT.md),
[playtesting feedback](PLAYTESTING_FEEDBACK.md).
History: `7b5e726`, `f6660ac`, `901a3ad`, `5c3598a`, `2f82bba`, `a72c299`, `c27247e`.

- **PLAY-01 · Placement and opening:** preview and confirm legal flat/wall/capstone
  placements; opening exchanges, supplies and unavailable choices are enforced.
  A new turn/restored position defaults the piece choice to Flat.
- **PLAY-02 · Inspectable stacks:** inspect either player's stack, even when it is not
  your turn or the game is finished. Read every layer in order, with ownership,
  piece type and theme intact; expand/scroll without resizing the board. In shared
  Square/Hex play, hold fans up to five top layers directly on the board until
  release/cancel; changed display or original inspection layers reset expansion.
  Empty cells retain their tap recognition. Explicit inspection and the full
  scrollable tray remain available.
- **PLAY-03 · Explicit pickup:** select a top portion by layer or minus/plus, respecting
  the carry limit. Initial selection takes the legal maximum; subsequent source
  taps take one fewer and wrap from one to maximum. Buttons and layer selection
  remain available together until dropping begins.
- **PLAY-04 · Draft a spread:** tap neighbors or drag to stage bottom-first drops along
  a straight path. See the carried hand, pieces left behind and staged counts.
  Release never silently commits a spread. Current-drop minus/plus controls stay
  available alongside board taps, including after the hand empties. Minus returns
  a stone to hand and removes an empty destination, restoring pickup controls if
  the path becomes empty.
- **PLAY-05 · Correct a draft:** undo a drop, drop the remainder, inspect another stack
  and return, or cancel. Blocked/off-path taps explain the constraint and preserve
  the draft. Undo also restores a destination removed with minus; changing the
  pickup quantity starts fresh drop history. Confirm is available only for a
  complete legal move.
- **PLAY-06 · Consistent rules:** previews, live play, AI, learning and replay agree on
  ownership, carry limits, blockers and capstone crushing. No partial spread
  prematurely resolves a win.
- **PLAY-07 · Understand the result:** roads take priority over flats, simultaneous
  roads use the mover rule, and only exposed ordinary flats score. Full-board,
  exhausted-supply, draw, resignation, timeout and abandonment endings are clear.
- **PLAY-08 · Usable small-screen tables:** both shapes keep a stable, width-based board;
  primary confirm/cancel actions remain reachable above the safe area. Secondary
  details may scroll. Try rotation, keyboard insets and enlarged text, including
  while a stack draft is open.
  Landscape/desktop adapt to a board beside a measured control panel when space
  permits, fitting the whole board to height in landscape. Compact player tiles
  reveal details on demand. Confirm, Cancel and spread Undo stay outside scrolling
  content; toolbar/menu audio commands do not cover the move controls.
- **PLAY-09 · Turn cues:** shared-device human turns and online own-turn transitions
  identify the active seat and sound once when effects are enabled; rebuilding,
  pausing or reconnecting does not produce misleading repeated alerts.

- **PLAY-10 · Readable game state:** show active seat, opening state, reserves,
  piece choices, waiting/saving/AI-thinking/paused/disconnected states and winning
  road highlights. Compact stacks retain visible layers and a total-height badge;
  their height must not be confused with the carry limit. Decoration and preview
  marks must not obscure ownership, piece type, source or legal targets.
- **PLAY-11 · Precision board navigation:** retain fit overview, density-aware
  zoom targeting a usable cell size, two-finger pan/zoom and explicit mouse Pan
  or Space-drag. Navigation cannot stage or confirm moves, even if a second
  finger joins a stack drag. Fit/Return to play stay reachable; rotation retains
  draft and normalized focus, focused cells reveal themselves at the current zoom,
  and changing matches resets the view. Web semantic hit regions match cell
  polygons so neighboring labels cannot intercept touches. See [adaptive gameplay
  UX](ADAPTIVE_GAMEPLAY_UX.md), introduced by `fc31e80`.

- **PLAY-12 · Keep active games awake:** unfinished, unpaused games request a screen
  wake lock while their game page is visible and the app is foregrounded. Shared
  Square/Hex and legacy game screens cover human, AI, mixed, online and AI-only
  play, including long remote-turn waits and temporary disconnections. In-game
  dialogs retain the request; explicit pause, completion, leaving/covering the
  page and backgrounding release it. Returning to eligible play reacquires it.
  Supported Android and HTTPS browsers remain subject to device/browser policy;
  denied or unsupported requests do not interrupt play and retry on foreground
  return or the next game interaction. Manual locking and background execution
  remain platform-controlled. Source: `lib/services/game_wake_lock.dart`;
  regressions: `test/game_wake_lock_test.dart`, `test/game/match_screen_test.dart`.
  Physical-device timeout qualification is tracked in [release readiness](RELEASE_READINESS.md).

## AI, practice and learning

Sources: [shared play](UNIFIED_PLAY_PLAN.md), [puzzle audit](PUZZLE_AUDIT.md),
[player experience](PLAYER_EXPERIENCE.md), [playtesting feedback](PLAYTESTING_FEEDBACK.md),
[large-board follow-up](SKILL_RATINGS.md#ranking-and-large-board-ai-follow-up-2026-10-23).
History: `40c55bb`, `a3869a7`, `a5ab875`, `6018f05`, `7e83417`, `6788062`,
`2df1b28`, `a72c299`, `8e38486`.

- **LEARN-01 · Four AI choices:** Easy, Medium, Hard and Expert make legal moves on both
  shapes and mixed two-to-four-seat tables without blocking normal interaction.
  The source candidate adds a Hard/Expert v3 duel safety check after the original
  strategic search. It replaces a move only after proving a forced loss and
  verifying a defense at the same finite horizon (three, then five plies).
  A completed near-term repair survives deeper timeout. Total duel targets are
  200/500/2000/5000 ms; the original strategic allocation and all multiplayer/
  saved-v1/v2 budgets remain unchanged. Hard/Expert v3 duel strategic search
  reuses immutable-stack sharing and exact component-based win detection from
  the safety search to reduce overhead within those same targets; see the
  [search overhead repair](AI_SEARCH_OVERHEAD.md). Connectivity orders exact proof work;
  selected native Square-5/Hex-2 Hard/Expert reference evidence supports the
  repair. Prior local representative tier runs passed; current-source CI must
  independently qualify ordering. Full size/player strength and
  browser/device responsiveness remain separate qualification requirements.
  See [the tactical repair](AI_TACTICAL_REPAIR.md) for verification and limits.
  Internal opt-in v3 duel experiments provide completed full-width minimax and a
  separate bounded road-resilience term. Defaults remain selective/zero until
  independent strength and latency gates pass. Their emergency timeout fallback
  may report zero completed plies; multiplayer keeps its mandatory round. See
  [duel experiments](AI_DUEL_EXPERIMENTS.md) for source behavior and evidence limits.
  New games use the v3 search with connected-road development and central access
  as secondary preferences. Multiplayer values each rival's progress and near-road
  threats instead of only the strongest rival, to encourage timely interference.
  Winning/blocking placements are examined first and known placement defenses
  survive positional-search timeout. Indexed path evaluation shares cached
  geometry across search positions. Saved v1/v2 configurations retain their strategy and recorded engine version.
  New v3 AI continue the existing v2 rating profiles. Lookahead targets count
  full table rounds: Easy one, Medium two in duels (one in multiplayer), Hard two,
  Expert three. Every difficulty
  completes a bounded, selective first round that models every rival's turn;
  wider/deeper refinements use the remaining thinking budget. Easy varies among
  near-equal choices evaluated over that round. Saved v1/v2 search is unchanged.
  V3 uses bounded decision-local score/move/transposition caches, exact legal
  horizon tactics and at most one extra forcing round within the refinement
  deadline. Forks are proven only after joint multiplayer defenses fail; incomplete
  verification is unknown. Small legal material probes are capped below a road
  unit; cap mobility currently has zero weight after a connected-development
  regression in pilot checks. Confirmed position history discourages repeated
  near-equal root moves without adding a repetition draw rule. History rebuilds
  after load/reconnect/takeback and reaches native/browser search consistently.
  See [AI upgrades and qualification](AI_UPGRADES.md) for weights and remaining gates,
  and the [Hex balance investigation](AI_BALANCE_INVESTIGATION.md) for opening/seat
  controls and exact bounded defensive counterexamples. Hex tier separation is
  still unproven; the strict per-board CI gates are retained.
  The 2026-10-26 source follow-up establishes Hard-width lower-depth duel results
  before Expert's widest refinement. Multiplayer retains its prior search widths
  and root order. An isolated capstone reserve-credit pilot lost
  both seat rotations and was rejected; there is no capstone opening restriction.
  Medium now chooses its best completed result instead of a periodic second
  near-equal choice, and its duel target deepens within the unchanged 500 ms
  budget; saved v1/v2 strategies retain their existing behavior.
  Completed duel horizon checks recognize rival threats with no legal defense
  as forced losses, while retaining terminal draws as defenses. Interrupted
  checks do not establish a forced result; multiplayer still needs joint proof.
  Optional
  seeded final-choice policies are experimental and disabled in normal play;
  full-window alternative scores and tactical/repetition safeguards apply.
  Six required native adjacent-tier CI groups cover Square-5 and two-seat Hex-2;
  a manual full-size/player-count workflow checks held-out ordering separately.
  Immediate wins and blocks are covered at Square 8 and Hex radius 4 for all four
  difficulties at two/four seats; broad strength and device timing remain unqualified.
  Difficulty-strength acceptance is still open (see limits below).
- **LEARN-02 · Court practice:** play untimed, unrated coached games with free takebacks,
  including recovery of a finished practice position. Inspect legal next-move
  winning threats for each seat on Square and Hex. Customize → Game settings
  always shows Court Mode; incompatible seats leave the switch disabled with
  guidance to choose a local human and an AI with no online seats. Changing seats
  enables the switch immediately when eligible. Before an AI can take a legal
  immediate win after human play, automatically pause with Tak!, Take back and
  Let AI play. Take back restores the latest human decision, including intervening
  AI replies; allowing the win still permits a finished-game takeback. Applies to
  road and flat wins, including stack movement, on both shapes and all supported
  seat counts. See [Court audit](COURT_MODE.md),
  `test/game/court_setup_navigation_test.dart` and `court_winning_reply_test.dart`.
- **LEARN-03 · Square fundamentals:** follow nine lessons, receive completion feedback,
  and continue with Next or coached practice after progress saves successfully.
- **LEARN-04 · Broader learning:** open Square/Hex tutorials, verified puzzle studies and
  multiplayer opening studies; use the same board controls, hints/retry and
  completion flow as appropriate to the exercise.
- **LEARN-05 · Learning isolation:** entering, retrying and leaving lessons does not
  replace the saved real game or award live-game results from a study position.

- **LEARN-06 · Guided progression:** retain catalog prerequisites/locks, completed
  indicators, Continue learning and stable lesson/study IDs. Square fundamentals
  lead to practice while the full Square/Hex catalogs remain accessible. Content
  replacement preserves known completion and previously earned rewards.
- **LEARN-07 · Honest puzzle success:** accept legal alternate attempts and
  certified solutions, enforce the study's move budget, and award completion only
  for the actual objective. Loss, draw or advancing a scripted step cannot count
  as a puzzle win. Reveal optional hints progressively and distinguish assisted
  from unaided completion. Difficulty ordering still needs human solve trials.
- **LEARN-08 · Coaching control:** requested suggestions explain observable move
  effects and load a legal preview for explicit confirmation. AI commentary and
  next-move threat warnings are bounded estimates, not proof of a forced win.
  Ignore stale results after navigation or position changes; coaching never
  changes the live board just by calculating a suggestion. The Court loss pause
  requires a verified legal winning reply rather than a heuristic evaluation;
  Take back or Let AI play explicitly resolves it, and generic Resume cannot
  bypass the choice. Ordinary games and isolated lessons retain their flow.

## Save, return and finish

Sources: [recovery](PERFORMANCE_AND_RECOVERY.md), [shared play](UNIFIED_PLAY_PLAN.md),
[player experience](PLAYER_EXPERIENCE.md), [result sharing](RESULT_SHARING.md),
[playtesting feedback](PLAYTESTING_FEEDBACK.md).
History: `a6e2adf`, `567376f`, `db47e49`, `d37748b`, `2b914c7`, `2df1b28`, `a72c299`.

- **SAVE-01 · Durable local play:** continue a saved game after restart with confirmed
  moves intact; a failed save offers recovery rather than silently losing play.
- **SAVE-02 · Clocks:** use per-seat time banks; local pause survives resume, and online
  timing follows server-confirmed state. Unlimited games still record elapsed
  active play; completed duration stays frozen when evidence is available.
- **SAVE-03 · My games:** return through saved-room shortcuts and browse device-local
  completed history, scoped to the appropriate account/guest. A damaged record
  does not hide the readable games.
- **SAVE-04 · Review:** replay a completed game's moves without mutating live play,
  submitting ratings again or earning duplicate rewards.
- **SAVE-05 · Play again:** start a local rematch with a new identity and rotated starter
  after completion processing; a failed save preserves the finished game.
- **SAVE-06 · Share a result:** preview/copy text or a link, invoke supported native/Web
  Share or SMS, and export the final-board PNG. Use the correct participants,
  outcome, immutable per-game rating changes and available frozen duration.
  Pending and unrated results must not masquerade as settled ratings.

- **SAVE-07 · Explicit ending:** confirm resignation/end-match. A two-seat
  resignation or clock loss awards the opponent; current multiplayer resignation
  or timeout abandons without a winner. Closing the screen/app does not resign.
  Preserve the terminal reason through save, reconnect, review, share and awards.
- **SAVE-08 · Pause and AI recovery:** local pause suspends active play/timing
  durably. An online clock continues independently of a player's screen; pausing
  a local AI runner does not pause the shared room clock. Pending AI work can
  resume from confirmed state when a participant reopens the room; it does not
  run on a cloud game server while all participants are away. A Court loss pause
  saves its verified winning reply and restores the same decision on local reload;
  failed takeback/continuation saves retain the position and allow retry.

## Play with other people

Sources: [invitations](FIRST_GAME_INVITATIONS.md),
[community and layout](COMMUNITY_AND_LAYOUT.md),
[multiplayer reliability](MULTIPLAYER_RELIABILITY.md),
[playtesting feedback](PLAYTESTING_FEEDBACK.md).
History: `9c1114a`, `b81e5a8`, `25888f1`, `603c86d`, `45d2946`, `2651001`,
`a5a1106`, `911af8f`, `a72c299`, `8e38486`.

- **ONLINE-01 · Private invitations:** find Room CODE / Invite / QR, share or copy the
  canonical link/code, and join from a cold link, pasted link or supported legacy
  code. Opening an invitation alone never claims a seat.
- **ONLINE-02 · QR invitations:** display a readable QR or scan into the Join form;
  joining still requires confirmation. Camera denial offers paste/code fallback.
- **ONLINE-03 · Open tables:** explicitly publish an unstarted room with a free remote
  seat, browse/refresh available tables, and confirm joining. Private rooms are
  not listed; full, started, withdrawn and expired tables disappear appropriately.
- **ONLINE-04 · Seat ownership:** simultaneous joiners cannot claim the same seat; only
  authorized players can act. Account switching and saved-room recovery protect
  the original identity and active session.
- **ONLINE-05 · Reconnect:** startup and outages reach a usable error/retry state instead
  of spinning indefinitely. Restore confirmed moves and reconcile interrupted
  submissions; stale clients cannot overwrite newer play or duplicate AI turns.
- **ONLINE-06 · Temporary room chat:** participants can exchange bounded, masked messages;
  closed/expired messages are unavailable and rejoining does not restore chat
  history. Expiry cleanup continues while the panel is collapsed.

- **ONLINE-07 · Waiting and observing:** distinguish waiting for human seats,
  waiting for an AI runner and watching an AI-only table from a playable human
  turn. Viewing without a controlled seat must not grant move authority or
  personal wins/rewards. Preserve supported mixed local/remote/AI seat setups.
- **ONLINE-08 · Failure containment:** bookmark storage and optional features
  cannot block room creation, joining or a confirmed turn. Preserve the last
  confirmed board during outages; reject corrupt or rewritten history with a
  useful recovery state. Bound retries and dispose old identity/subscription work
  so a late response cannot change the current room or account.
- **ONLINE-09 · Data access and input validation:** preserve authenticated seat/
  membership checks, unpredictable invitation codes, immutable room configuration,
  bounded validated inputs and rejection of stale/unauthorized writes. Public
  names, ratings and opt-in listings are distinct from private room/history/
  receipt/chat data. Do not leak invitation codes into public rating history or
  enable private-room enumeration to implement discovery. Backend authorization
  and App Check configuration need appropriate emulator/deployment evidence.

## Identity, ratings and progression

Sources: [accounts](ANDROID_AND_ACCOUNTS.md), [community](COMMUNITY_AND_LAYOUT.md),
[skill ratings](SKILL_RATINGS.md), [achievements](ACHIEVEMENTS.md),
[themes](THEMES.md), [playtesting feedback](PLAYTESTING_FEEDBACK.md),
[Google sign-in recovery and remembered accounts](GOOGLE_SIGN_IN_FIX.md).
History: `4ddf3b1`, `2b02dd7`, `69e3c6e`, `afb68ea`, `4c7ca14`, `911af8f`,
`2b914c7`, `84e90a2`, `4886cc5`, `e6c2319`.

- **ACCOUNT-01 · Guest or Google account:** play as a guest, sign in from Home/Settings,
  view account status, and sign out with active-room protections intact. Web
  sign-in requires a fresh tap after account preparation. A pending attempt shows
  recovery help after 30 seconds and stays locked until completion/cancellation;
  close a failed Google tab and retry in the same browser without clearing guest
  data. Optional status publication cannot delay a successful sign-in. Physical
  iOS and real Google credential exchange remain unqualified. Independent
  Chromium/Firefox/WebKit emulator and production-artifact checks protect the
  recovery contract; credential-only fixtures do not qualify popup UI behavior.
- **ACCOUNT-02 · Public Stones name:** edit a name independently of Google profile data;
  it appears consistently in games, profiles and standings across devices.
- **ACCOUNT-03 · Overall and format ratings:** eligible new games contribute once to both
  ladders. Show provisional status, uncertainty and exact established human rank;
  AI and provisional players do not consume rank numbers, and tied human ratings
  share a rank consistently across home, standings and profiles;
  distinguish unavailable data from an unrated account. Regression coverage includes
  multiple interleaved AI, tied humans and provisional humans across All/Humans/AI
  filters. See the [hosted ranking diagnosis](SKILL_RATINGS.md#hosted-ranking-diagnosis-2026-10-23).
- **ACCOUNT-04 · Human and AI standings:** use All/Humans/AI filters, inspect player details
  and history, and refresh standings. AI rows remain sorted by rating without a
  human rank number. The signed-in “Your standing” card opens that player’s
  profile in the selected ladder, including an unrated account. New skill-history
  entries preserve the game’s AI engine version, shown in AI profiles; old missing
  metadata stays unlabelled. Current AI
  identities do not duplicate historical placeholders. Eligible AI-only reports do not award the observer.
- **ACCOUNT-05 · Rating eligibility and recovery:** explain guest/practice/shared-seat
  exclusions and pending peer confirmation. Retry interrupted settlement without
  duplicate awards or losing already-confirmed deltas.
- **ACCOUNT-06 · Current multiplayer outcomes:** new version-3 games have one winner and
  unordered losses, or a genuine draw; do not award consolation placements.
  Existing version-1/2 saves keep their original rating contract.
- **ACCOUNT-07 · Mastery collection:** browse 25 achievements, filters, requirement progress,
  points/ranks, earned dates and next goals. Qualified results and learning save
  once, show unlock feedback, and preserve proven migrated rewards.
- **ACCOUNT-08 · Appearance:** preview the five visual sets, choose board and pieces
  independently, and preserve each seat's appearance online and in stack layers.
  Viewing another player's set does not grant ownership.
- **ACCOUNT-09 · Celestial board:** only the single highest-rated established human in
  Overall is eligible; revocation or failed eligibility checks restores the
  default appearance, including an already-open share image.

- **ACCOUNT-10 · Safe identity transitions:** restore an existing Firebase identity
  before creating a guest. Linking a guest to a new Google account preserves UID
  and rooms; a collision with an existing account needs an explicit switch.
  Cancellation preserves the current identity. Active rooms block sign-out and
  switching an already registered account, including direct sign-in requests;
  linking a guest remains available. Keep Play Games identity separate
  from Stones/Firebase identity; neither optional service gates local play.
- **ACCOUNT-11 · Progress durability and eligibility:** save learning, achievement
  evidence and unlock notices without overlapping writes losing progress. Dedup
  match awards by stable session identity and verify replay before statistics.
  Preserve proven old unlocks without inventing specialist evidence. Court,
  studies, spectators, shared-device results and early concessions keep their
  documented eligibility limits. Release builds cannot use debug unlock/reset
  gestures to fabricate mastery.
- **ACCOUNT-12 · Room-scoped cosmetics:** everyone sees the host's recorded board
  and each seat's recorded piece set, including buried/captured/preview stones.
  Reconnect does not rewrite those choices. Missing or unknown metadata falls
  back safely to Classic; viewing a locked opponent set never writes local
  entitlements. Cosmetic entitlement remains client-enforced.
- **ACCOUNT-13 · Remembered account:** restore the last Firebase session on Home
  independently of audio and optional Play Games startup, without a new guest or
  Google chooser. SDK-managed persistence remembers the last successful login;
  explicit sign-out survives browser restart. Denied storage, private browsing,
  clearing/evicting data, another browser/profile/origin or a revoked session can
  require another sign-in. Local play remains available during restoration or
  failure; achievements, themes and settings retain their device-local limits.
  Browser-process restart and denied-persistent-storage checks cover restoration,
  last-account replacement, explicit sign-out and usable session fallback.

## Preferences, presentation and accessible input

Sources: [themes](THEMES.md), [stack display](STACK_DISPLAY.md),
[layout](COMMUNITY_AND_LAYOUT.md), [finishing plan](FINISHING_PLAN.md).
Implementation: [Settings](../lib/screens/settings_screen.dart),
[saved settings](../lib/providers/settings_provider.dart),
[stack rendering](../lib/widgets/piece_stack_view.dart),
[shared board](../lib/game/board_view.dart).
History: `8d2cdfb`, `9961f5e`, `5c6cbf2`, `4843a45`, `6f89bae`, `cfc08a6`,
`9a66f86`, `dff1883`, `d3b129a`, `4886cc5`, `c27247e`.

- **PREF-01 · Appearance modes:** persist System/Light/Dark independently of the
  board/piece set. Menus, settings, learning, dialogs and status/action text remain
  readable in each mode; follow system changes when System is selected. Resolve
  validated saved appearance before building the initial menu, with one shared
  settings initialization. Missing/invalid preferences or unavailable storage use
  System. The web loader resolves the same preference before paint; Android's
  native launch follows system appearance until Flutter paints the saved mode.
  Source and regressions: [startup identity audit](STARTUP_IDENTITY.md).
- **PREF-02 · Clock defaults:** preserve editable per-board defaults, enablement
  and per-game overrides. Defaults affect new configurations, never reset a
  running game's time bank, and survive temporarily entering untimed Court.
- **PREF-03 · Five-set continuity:** keep Classic Wood, Slate, Marble, Morocco and
  Kyoto, real locked previews and earned selection. Preserve saved mixed choices
  and index migration from Minimalist/Pixel to Morocco/Kyoto. Celestial is a
  conditional board reward, not a sixth coordinated board-and-piece set.
- **PREF-04 · Visual feedback:** preserve legible selection, staged/ghost moves,
  layer transitions and result feedback across both shapes. Shared layer
  animations respect reduced motion. Use bounded, deterministic ornament and
  shared painters for gameplay/previews; no visual effect can change legality.
  Pieces share bounded side thickness, bevels and contact shadows across all five
  sets, retaining owner colors and flat/wall/capstone identities.
- **PREF-05 · Accessible interaction:** retain focusable actions, descriptive cell
  and stack semantics, an explicit inspect action, status announcements and
  visible selection/focus. Touch and click alternatives must expose everything
  otherwise available by hover/drag. On-board hold expansion is optional: the
  persistent tray and accessible Inspect stack action retain full-layer access.
  Web startup announces loading/failure status, exposes keyboard-operable Reload,
  respects reduced motion, safe areas and enlarged text on narrow viewports.
  See [startup identity audit](STARTUP_IDENTITY.md) for browser evidence and physical
  screen-reader limits. Enlarged text and scrollable content must
  retain essential actions. Shared boards provide directional focus traversal and
  reveal focused cells when zoomed. Escape-cancel parity and physical screen-reader
  qualification remain tracked below rather than assumed complete.
- **PREF-06 · Sound feedback:** maintain mute, independent background music and
  persisted preferences, plus appropriate placement/movement/crushing/win/threat/
  award/turn effects where wired. Inspection/rebuilds must not sound like moves.
  Optional audio failure cannot prevent a legal turn or require sound to play.

## Navigation, audio, help and delivery

Sources: [feedback](FEEDBACK.md), [playtesting feedback](PLAYTESTING_FEEDBACK.md),
[player experience](PLAYER_EXPERIENCE.md), [release readiness](RELEASE_READINESS.md).
History: `92550dd`, `928b515`, `7036dd9`, `911af8f`, `2df1b28`, `a72c299`,
`aa15870`, `8e38486`.

- **APP-01 · Browser navigation:** Back returns to the previous screen and Forward
  restores supported routes, including working lesson actions. Back does not
  implicitly undo a move.
- **APP-02 · Audio:** reach audio controls throughout the app; change effects and music
  independently and retain preferences. Effects default on, music off; web audio
  begins after user interaction.
- **APP-03 · Help:** find the publisher's Core Rules PDF in About with variants clearly
  distinguished from official Tak.
- **APP-04 · Feedback:** open an editable Problem/Idea/Other report from Settings/About,
  optionally include version/platform, and open an email draft or copy/preview
  the report if email launch fails. The user sends it; opening is not delivery.
- **APP-05 · Web updates:** a previously cached page can still load retained startup
  assets after a rollout. Release artifacts identify the source being reviewed.

- **APP-06 · Install and startup:** use the shared geometric stacked-stones mark
  on loading, home, About/licenses, Android/web icons and favicon. Launch backdrops
  match cream `#EDE5D7` / charcoal `#1B1816`; Android includes pre-12 and 12+
  light/dark resources, transparent splash marks and padded adaptive foregrounds.
  Web loading remains until the initialized Flutter interface paints, then fades
  briefly without a minimum startup delay. Bootstrap/engine/app-start failures
  expose readable status and working Reload; help appears after 15 seconds while
  startup continues. Optional account/audio/network services do not gate local
  play. Asset generation preserves the custom loader, relative web base paths,
  invitation routing, fingerprinted startup and previous-release compatibility.
  See [startup identity audit](STARTUP_IDENTITY.md) for verified artifacts,
  accessibility journeys and remaining Android/device qualification. Retain
  installable-web manifest/standalone configuration. The declared PWA shortcut and
  browser install support need actual end-to-end checks; a manifest alone does
  not establish offline startup or shortcut routing.
- **APP-07 · About and diagnostics:** expose the app version/source revision,
  game/rules information, privacy link and support entry points. Keep feedback
  diagnostics opt-in and exclude account IDs, room links, private moves and logs
  by default. Never claim an email was delivered just because a composer opened.
  Release builds derive the visible version from `pubspec.yaml` (1.1.0 for the
  October 24 Android update) and retain the exact build source.
- **APP-08 · Responsive performance:** keep immediate interaction feedback and
  useful AI/loading/retry states while bounded search yields off the UI path.
  Cancel stale work on position/account/navigation changes. Dense boards, tall
  stacks, four seats and optional audio/assets cannot make ordinary play unusable.
  Measure on named devices; proposed latency/frame/startup targets in the finishing
  plan are acceptance goals, not established measurements.
- **APP-09 · Delivery compatibility:** preserve signed Android package/update
  identity, monotonically valid version codes, source-labelled artifacts, web
  base paths/cold invitation routes and previous-save readers. CI, room rules,
  web/Android builds and previews must remain usable. Qualify the exact artifact,
  verify required backend rules/indexes before dependent clients, preserve
  bounded cached startup assets, and keep rollback possible. Require two
  consecutive complete CI qualifications for the selected source, including
  independent three-engine account/recovery checks. Archive and verify the
  previous artifact before publication, checking its backend hashes against its
  own committed source even when the new release changes rules or indexes.
  Release tools follow the workflow revision while application bytes remain
  pinned to the selected qualified artifact. Check hosted source/integrity/login
  afterward and daily, reporting publication separately from acceptance. Browser
  qualification pins Ubuntu 24.04 and the browser tooling; dependency setup uses
  bounded transport retries and cannot substitute for passing application checks.
  Advancing Android's visible version retains the signing identity. The 1.1.0
  update rebuilds prepared application `72b9f1d` with only version metadata and
  documentation changes. Verify its report, bundle and Console code before Alpha
  publication; store acceptance does not qualify physical-device updates, login
  or saved-game use. See [Android 1.1.0 (503)](releases/ANDROID_503.md) for
  exact source/artifact, Alpha review submission and retained device limits.

- **APP-10 · Store presentation:** Play descriptions and artwork reflect the
  distributed game's actual Square/Hex, two-to-four-player, AI and learning
  capabilities. Preserve clear variant identity and device-local progression
  limits; do not promise synchronized unlocks, automatic matchmaking or pricing
  guarantees absent from the implementation. Capture real application UI with
  source/viewport provenance, distinguish it from physical-device qualification,
  and record store-listing submission separately from binary availability.
  Sources: [listing copy](../store_listing/full_description.txt),
  [listing capture and submission record](releases/STORE_LISTING_20261024.md),
  [Android release](releases/ANDROID_503.md).

## Historical capabilities and compatibility obligations

These capabilities appear in the full history and remain relevant even where the
new shared screen does not provide parity. They are not automatically new work
authorized by this inventory. Investigate the stated boundary before changing an
adapter, deleting an old implementation, or calling a replacement complete.

| ID / feature | Current contract or parity gap | Evidence |
| --- | --- | --- |
| COMPAT-01 · Move history and last-move highlighting | Original Square play has a collapsible notation history and affected-cell highlights. Shared play retains confirmed moves and completed-game step/slider review, but its active screen does not expose the old notation panel or last-move highlight. Keep this parity gap visible; do not assume result review fully replaces in-game history. | `1377230`, `6f89bae`; [legacy screen](../lib/main.dart), [shared screen](../lib/game/match_screen.dart), [review](../lib/game/match_review_screen.dart) |
| COMPAT-02 · Undo versus takeback | Legacy untimed offline Square offers undo (including human/AI reply pairs); timed undo is disabled. Shared live-match takeback is Court-only. Draft undo is separate and remains available before submission. Broader untimed shared undo is a parity question, not an implemented guarantee. Never restore legacy local-only online undo without a coordinated remote protocol. | `1377230`, `e1fde83`, `f063762`, `a3869a7`; [rules audit](TAK_RULES.md), [controller](../lib/game/match_controller.dart) |
| COMPAT-03 · Keyboard play | Legacy Square has arrow navigation, Enter activation and Escape cancellation. Shared BoardView now provides arrow-based directional focus traversal with focusable InkWell/actions and zoom-aware cell reveal. Legacy Escape-cancel parity still needs explicit qualification; do not drop accessible actions during navigation changes. | `dff1883`, `fc31e80`; [legacy board](../lib/main.dart), [shared board](../lib/game/board_view.dart), [adaptive UX](ADAPTIVE_GAMEPLAY_UX.md) |
| COMPAT-04 · Optional Android Play Games | Compile-time-enabled Android integration has separate sign-in, legacy untimed Square cloud-save/explicit restore, achievement and score hooks. It is unavailable on web and does not synchronize shared-game progression. Safe restore cannot silently replace active play; native service configuration/IDs and Play-device qualification are separate prerequisites. | `23d3e84`, `d6c654c`, `4ddf3b1`; [service](../lib/services/play_games_service.dart), [save codec](../lib/services/play_games_save.dart), [tests](../test/play_games_save_test.dart) |
| COMPAT-05 · Old rooms and saves | Preserve supported old Square, H-prefixed Hex and unified invitation dispatch, codecs, recorded goals, seat ownership and result semantics. Replay through the correct adapter; missing metadata must use its documented fallback rather than current defaults. | `cf126b9`, `b81e5a8`, `401e393`; [room navigation](../lib/game/room_navigation.dart), [shared play](UNIFIED_PLAY_PLAN.md) |
| COMPAT-06 · Rating generations | Original Elo/history, version-1 settlement and version-2 placement Elo remain historical contracts. New games use version 3 Overall/format skill and unordered losses, with recorded v1/v2/v3 game engines. The v3 engine continues existing v2 AI ratings as requested; historical v1 ratings remain separate. Never resettle old receipts, reinterpret old placements or rewrite historical engine versions. | `461dc71`, `8cff17f`, `2b914c7`, `84e90a2`, `a72c299`; [ratings](RATINGS.md), [sharing](RESULT_SHARING.md), [current skill](SKILL_RATINGS.md) |
| COMPAT-07 · Learning and cosmetic migration | Old chapter/prerequisite metadata, completed IDs, achievement ledgers and saved cosmetic indices carry user progress. Preserve known ownership even when content or earning requirements change; obsolete puzzles/placeholder badges need not be restored as current content. | `215e300`, `6a4f5d4`, `cea2f44`, `5263b31`, `a078f04`; [achievements](ACHIEVEMENTS.md), [themes](THEMES.md) |
| COMPAT-08 · Retired interaction designs | Browser Back-as-undo, QR auto-join, Hex hidden behind an opt-in toggle, automatic spread submission and old pending-drop cycling have been superseded. Source-tap pickup cycling is explicitly restored alongside minus/plus controls; current-drop editing remains a reversible draft. Current navigation, explicit join and staged confirmation contracts take precedence. Historical commits are not instructions to restore these designs. | `dda35e8`, `3e6d65a`, `cf126b9`, `87f40d9`, `2f82bba`, `aa15870` |

## Intended capabilities and remaining acceptance

These are part of the intended product or known qualification work. Their status
must stay explicit until implementation and acceptance evidence justify changing it.

| ID / area | Current boundary and desired behavior | Source |
| --- | --- | --- |
| PLAN-01 · Account progression | Merge/cache foundation exists; achievements, unlocks and learning remain device-local. Complete owner-private bounded remote storage, explicit guest import, offline/concurrent device merging, account switching and UI integration without duplicate awards. | [Account progress](ACCOUNT_PROGRESS.md), finishing packet 4 |
| PLAN-02 · Account game index | My games is currently a local archive/shortcut list. Add a private paginated cross-device index with Your turn/Waiting/Inviting/Completed states, safe archive semantics and authoritative room validation. | [Finishing plan](FINISHING_PLAN.md), packet 5 |
| PLAN-03 · Group forfeiture continuation | Current multiplayer resignation/timeout abandons the match. Intended versioned behavior retires timed-out seats while keeping pieces, skips their turns, and offers consensual permanent AI substitution after casual resignation; substitution makes continuation unrated. Old rooms retain old endings. | [Shared play](UNIFIED_PLAY_PLAN.md), finishing packet 6 |
| PLAN-04 · Online rematch | Local Play again exists. Online rematch needs consent, waiting/declined states, a new room/identity, rotated starter and race-safe creation without erasing the original result. | [Player experience](PLAYER_EXPERIENCE.md), finishing packet 7 |
| PLAN-05 · Asynchronous return and reminders | Durable rooms exist, but the full account-backed return/reminder journey is unfinished. Add opt-in per-game reminders, authorized durable delivery, mute/denied/unsupported states and stale-notification recovery. Longer cumulative time controls and waiting-for-computer handling must preserve the same room engine; no per-turn deadline is implied. | [Finishing plan](FINISHING_PLAN.md), packet 8 |
| PLAN-06 · Learning curation | Fundamentals/Next/practice exist. Further curate distinct tactical studies and optional variations, establish difficulty with human solve trials and preserve proofs, IDs and earned rewards. Morocco remains an early learning reward with preserved alternate routes. | [Player experience](PLAYER_EXPERIENCE.md), [puzzle audit](PUZZLE_AUDIT.md), finishing packet 9 |
| PLAN-07 · Visual and performance finish | Core menu/table styling exists. Complete coherent learning/account/history/collection surfaces, dense mixed-theme readability, reduced-motion/audio behavior and measured performance on reference phones. Keep five coordinated sets. | [Finishing plan](FINISHING_PLAN.md), packet 10 |
| PLAN-08 · Account lifecycle and disclosures | Feedback exists. Account/data deletion needs discoverable app/web entry points, reauthentication, retryable cleanup and treatment of shared histories/rooms. Align actual Analytics/retention, privacy text and store disclosures before public release. | [Feedback](FEEDBACK.md), finishing packet 11 |
| PLAN-09 · Release baseline and parity | Continue exact-source/artifact/backend qualification and rollback. Qualify one source across web and Play Android, actual update/install, old saves, independent accounts and a long-running friend game. Store-track publication and production-access requirements remain separate gates. | [Release readiness](RELEASE_READINESS.md), finishing packets 1 and 12 |
| PLAN-10 · AI strength | Hard/Expert v3 strategic duels reuse immutable-stack sharing and exact component win checks to reduce overhead within unchanged thinking limits; see [the overhead repair](AI_SEARCH_OVERHEAD.md) for correctness checks and exact-source release requirements. The source uses an exact forced-loss veto in Hard/Expert v3 duels, retaining the original strategy unless a bounded loss is proved and a defense verified. Connectivity orders proof attempts. Selected native confirmation covers 50 distinct openings per board, swapped seats, Square 5/Hex radius 2 and Hard/Expert: 226–161 with 13 draws against the frozen original; aggregate opening-stream-clustered p = 0.0002154. All 400 games and 203 replacements passed independent replay/proof checks. Four tiers, six unchanged required representative adjacent-tier gates, a manually requested all-size/player-count matrix and resumable reference tooling are implemented. Full-width/weighted-evaluation variants remain opt-in after failed development/latency studies; the capstone reserve-credit pilot was rejected, and organic variation remains opt-in experimental. Full size/player strength qualification, the material-weight pilot grid, human Expert strength and browser/device responsiveness remain open. The selected native result does not qualify the full matrix or publish a release. | [Tactical repair](AI_TACTICAL_REPAIR.md), [confirmation](qa/ai-fix/reference-study.json), [AI upgrades](AI_UPGRADES.md) |
| PLAN-11 · Device and usability acceptance | Physical iPhone web sign-in retry, Android back gestures, Play-signed invitations/audio/sharing, native safe areas, keyboard/screen readers, large text and unfamiliar-player trials remain acceptance work. Browser viewport tests do not establish these. | [Release readiness](RELEASE_READINESS.md), [playtesting feedback](PLAYTESTING_FEEDBACK.md) |

Current constraints also remain visible:

- **LIMIT-01 · Platform scope:** web and Android releases can differ. Native iOS
  lacks a complete project/signing/qualification path; an old workflow/assets
  directory is not iOS support. PWA configuration does not promise universal
  browser installation, offline startup, push delivery or working shortcuts.
- **LIMIT-02 · Infrastructure:** gameplay AI runs on participant devices and
  Firebase stays on Spark. A free reminder service is a proposal requiring
  feasibility/authorization, not an existing cloud AI or notification service.
- **LIMIT-03 · Chat retention:** expired/closed chat becomes unreadable. Physical
  deletion cannot be guaranteed while all clients are closed on Spark.
- **LIMIT-04 · Competition trust:** Spark validates settlement constraints, not
  independently executed histories. Local AI reports and agreeing clients are
  not cheat-proof attestation; cosmetic ownership is also client-enforced.
- **LIMIT-05 · Deliberate scope:** public/global chat, a social feed, tournaments,
  seasons, friends graph, automatic matchmaking, new shapes and additional visual
  sets are deferred by the finishing plan. Publisher wagering/multi-game scoring,
  komi and repetition/no-progress rules are not current default features. Do not
  turn a historical mention into a supported promise or add these incidentally.

## Full-history feature provenance

The full log was reviewed without a sprint/date cutoff. This map retains origins
that the October-only inventory missed, alongside later replacement contracts.
Merge, formatting, build-repair and repeated qualification commits are folded into
their feature families. Use `git log --all -- <path>` and linked audits when a
change needs finer-grained history; counts/dates above describe this baseline.

| Feature family | Foundational history | Later evolution / current references |
| --- | --- | --- |
| Rules, board and results | `3634f4b`, `aad64fd`, `58008b9` | `7b5e726`, `47191d3`; RULE, PLAY, SAVE |
| Placement, spreads, ghosts and gestures | `9261d2c`, `7fc586e`, `4585284`, `5e640a1`, `5ee22ca`, `e91b164` | `901a3ad`, `87f40d9`, `2f82bba`; PLAY |
| Undo, move history and inspection | `1377230`, `d5a9a3a`, `e1fde83` | `5c3598a`, `2f82bba`; COMPAT-01/02, PLAY |
| Menus, setup and clocks | `f6f38a6`, `6f89bae`, `cfc08a6`, `9a66f86`, `948d4f8`, `c44a23d` | `7f6d298`, `db47e49`, `45d2946`, `2df1b28`; SETUP, SAVE |
| AI and Court | `bad51bb`, `51db7fb`, `c38f50b`, `faa42a6`, `8c8fd23`, `ca43585`, `a4128da` | `a3869a7`, `7e83417`, `a72c299`, `8e38486`; LEARN, PLAN-10 |
| Online rooms, QR and recovery | `de610fc`, `1f990eb`, `b86a5a7`, `7f6153a`, `f5ff3b9` | `cf126b9`, `a6e2adf`, `603c86d`, `2651001`, `911af8f`; ONLINE |
| Identity and Play Games | `23d3e84`, `3834e59`, `5dee653`, `e1723cc`, `d6c654c` | `4ddf3b1`, `4ac6485`, `911af8f`; ACCOUNT, COMPAT-04 |
| Tutorials, puzzles and progression | `215e300`, `83298e1`, `cea2f44`, `89965ee`, `be8042b`, `eb3078e`, `65351fc`, `d7e3f5a`, `5263b31` | `a5ab875`, `6018f05`, `2df1b28`; LEARN, COMPAT-07 |
| Achievements and cosmetic rewards | `6a4f5d4`, `14ecf00`, `8d820ed`, `1ba77ab`, `1bff96c` | `2b02dd7`, `a078f04`, `e6c2319`; ACCOUNT, PREF |
| Visuals, settings, accessibility and audio | `8d2cdfb`, `9961f5e`, `5c6cbf2`, `ddd6423`, `4843a45`, `9993e3f`, `0f08f05`, `d80a079`, `dff1883` | `4886cc5`, `d3b129a`, `c27247e`, `a72c299`, `fc31e80`; PLAY-11, PREF, APP |
| Ratings, leaderboard and profiles | `461dc71`, `84b3ae5`, `8cff17f`, `4cc35c3` | `69e3c6e`, `afb68ea`, `2b914c7`, `84e90a2`; ACCOUNT, COMPAT-06 |
| Performance and startup reliability | `87532ef`, `06fef03`, `6ee7072`, `d175735`, `e4e9ae8`, `25b15f9`, `8d2ca1e` | `a6e2adf`, `92550dd`, `928b515`; APP |
| Privacy, security and support | `f86e115`, `90c1b5a`, `94c9d30`, `65e1277`, `8645312` | `6a5a8b4`, `7036dd9`, `a72c299`; ONLINE, ACCOUNT, APP, PLAN-08 |
| Web, PWA, previews and version identity | `fd3c058`, `0539c34`, `f06ea89`, `8d5857a`, `9933f8a`, `59637ce` | `b8666a5`, `2df1b28`, `a045e37`; APP, LIMIT-01 |
| Android distribution and store assets | `30ac05b`, `8c79f90`, `746c4ce`, `122e304`, `189c9c7`, `73bc01e`, `1f303e7`, `a8ce4be`, `429ef23` | `4ddf3b1`, `ccbbaae`, `454351b`; APP, PLAN-09 |
| Hex, multiplayer and shared learning | `cf126b9`, `f6660ac`, `47191d3`, `567376f` | `7f6d298`, `401e393`, `7e83417`; RULE, SETUP, LEARN |
| Finished-game review, rematch and sharing | `2b914c7`, `2df1b28` | `a72c299`, `8e38486`; SAVE, PLAN-04 |

## Regression starting points

This is a routing map, not a mandate to run every suite for every edit. Read the
tests and select checks that exercise the changed behavior and its shared state.
Run the full tests and strict analyzer after mechanics changes as AGENTS requires.
Deployment/device claims need their own evidence.

| Affected feature IDs | Implementation / contract | Existing verification starting points |
| --- | --- | --- |
| RULE, PLAY | `lib/game/match_rules.dart`, `move_selection.dart`, `board_view.dart`, `stack_move_tray.dart` | `test/game/unified_rules_test.dart`, `move_selection_test.dart`, `stack_interaction_test.dart`, `stack_badges_test.dart`; `test/models/game_rules_test.dart`; `test/hex/hex_victory_audit_test.dart` |
| PLAY-08/11, PREF-05 | `lib/game/board_viewport.dart`, `board_view.dart`, `match_table_layout.dart`; [adaptive gameplay](ADAPTIVE_GAMEPLAY_UX.md) | `test/game/board_viewport_test.dart`, `adaptive_interaction_test.dart`, `adaptive_capture_test.dart`; `tools/adaptive_browser_probe.py`; physical-device and screen-reader trials |
| SETUP, PREF, APP navigation | `match_config.dart`, `match_setup_form.dart`, `match_table_layout.dart`; `lib/widgets/game_menu.dart`; `lib/services/app_history_observer.dart` | `test/game/match_setup_test.dart`, `setup_recovery_test.dart`, `community_layout_test.dart`, `first_game_flow_test.dart`; `test/browser_history_observer_test.dart`, `audio_settings_test.dart`, `widgets/piece_stack_view_test.dart` |
| LEARN | `study_controller.dart`, `study_screen.dart`, `study_catalog.dart`, `learning_hub.dart`, `match_coaching.dart`, `match_threats.dart` | `test/game/shared_study_test.dart`, `multiplayer_studies_test.dart`, `first_game_journey_test.dart`, `playtesting_feedback_test.dart`; `test/audit/puzzle_contract_test.dart`, `puzzle_authoring_test.dart`; `test/models/scenario_library_test.dart` |
| LEARN AI | `match_ai.dart`, `match_ai_engine.dart`; historical `lib/services/ai/` | `test/game/shared_ai_tactics_test.dart`, `shared_ai_playthrough_test.dart`, `match_ai_test.dart`, `ai_round_search_test.dart`, `large_board_ai_test.dart`, `ai_upgrade_test.dart`, `ai_qualification_test.dart`; `tools/ai_qualification.dart`, `tools/ai_latency.dart`; [qualification and open gates](AI_UPGRADES.md) |
| SAVE | `match_controller.dart`, `match_storage.dart`, `completed_match.dart`, `match_clock.dart`, `match_elapsed.dart`, `result_share_data.dart` | `test/game/match_controller_test.dart`, `match_clock_test.dart`, `completed_match_test.dart`, `result_explanation_test.dart`, `result_sharing_test.dart`, `result_share_widget_test.dart` |
| ONLINE | `match_room_store.dart`, `room_navigation.dart`, `room_invitation.dart`, `open_tables.dart`; `lib/services/match_chat_service.dart`; `firestore.rules` | `test/game/match_room_test.dart`, `multiplayer_recovery_regression_test.dart`, `multiplayer_resilience_test.dart`; `test/open_tables_test.dart`, `match_chat_lifecycle_test.dart`; `tools/hex_rules/`; `tools/chat_browser_journey.py` |
| ACCOUNT, COMPAT, PLAN-01 | `lib/providers/account_provider.dart`, `achievements_provider.dart`, `elite_theme_provider.dart`; `lib/progression/`; `lib/services/play_games_service.dart` | `test/account_test.dart`, `play_games_save_test.dart`, `community_ui_test.dart`; `test/achievements/`; `test/ratings/`; Firestore emulator authorization trials |
| ACCOUNT-01/10/13 | `lib/providers/account_provider.dart`, `lib/services/account_service.dart`, `lib/screens/main_menu_screen.dart`, `lib/widgets/account_card.dart`; [sign-in recovery](GOOGLE_SIGN_IN_FIX.md) | Account/home tests; `tools/google_auth_browser_checks.py` for emulator linking and browser-process restart/sign-out; `tools/google_auth_probe.py` for helper-state loss/new-tab recovery; physical iOS and real Google verification remain separate |
| APP delivery/performance | `.github/workflows/`, `scripts/`, `web/`; [release readiness](RELEASE_READINESS.md) | Python release/preflight checks; `tools/browser_journeys.py`; `tools/shared_performance_probe_test.dart`; native/browser/device trials appropriate to the artifact |

## Journeys and combinations to preserve

For each affected journey, cover the relevant combinations below. Avoid claiming
the whole matrix passed because a single configuration worked.

| Journey | Observable result and adjacent regressions to check |
| --- | --- |
| First launch → learn → coached game | Readable home, guest access, prerequisites, saved completion, Next/Practice navigation, Morocco progress; real saved game remains intact. |
| Custom setup → play → draft → confirm | Valid seat/shape/size settings, opening, reserves, clear ownership, inspect/carry/drop/undo/cancel, stable board and reachable primary actions; no partial submission. |
| Play → pause/background → reload → continue | Confirmed moves, local pause/time banks and active elapsed time survive correctly; online clocks/seat ownership remain authoritative. |
| Invitation/QR/open table → join | Cold/warm routes and canonical/legacy codes work; cancel/full/stale/invalid/failed joins preserve active play and identity. No implicit seat claim. |
| Mixed online table → disconnect → reconnect | Last confirmed board stays visible, retry is bounded, AI lease can recover, no lost/duplicate move, correct turn cue and no stale subscriptions. |
| Guest → Google → account switch/cancel | UID-safe link/collision/cancel behavior, fresh web tap after preparation, delayed helper recovery without overlapping attempts, active-room identity guards, correct room/profile/rating visibility, optional Play Games isolation and no mistaken progress-sync promise. |
| Sign in → close browser → reopen → sign out → reopen | Last account restores on Home without waiting for audio; explicit sign-out persists; a subsequent login replaces the remembered account. Denied/private storage retains usable local play and honest session limits. |
| Finish → rewards/ratings → review → share → again | Correct reason, one settlement/award, stable deltas/duration, read-only review, no lost result on save failure, new rematch identity. |
| Change appearance/audio/navigation | Light/dark/system, locked/earned mixed sets, Celestial revocation, independent effects/music, Back/Forward and lesson callbacks preserve the live game and clear status. |

Relevant dimensions: Square/Hex; minimum/default/maximum size; two/three/four
seats; local humans/AI/mixed remote/AI-only observer; guest/signed-in/distinct
owners; timed/untimed/Court/study; opening/midgame/tall stacks/terminal; new versus
legacy saves/rooms/engines/ratings; online/offline/slow/denied/corrupt storage;
phone/landscape/desktop with safe areas and keyboard insets; light/dark/system,
100/150/200% text, reduced motion, muted sound, touch/pointer/keyboard/semantics.

The task handoff should identify affected IDs, behavior preserved or intentionally
changed, checks actually run and remaining gaps. Update a linked audit when new
evidence changes support status. Keep this reference focused on enduring behavior
and gaps; release-specific pass/fail logs belong with their build evidence.
