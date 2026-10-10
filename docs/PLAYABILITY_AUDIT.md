# Playability and UX audit

Audit of `cf126b9`, followed by the improvements in this working tree. Updated
2026-10-09. This is an engineering playtest and usability inspection, not a user
study or a declaration of complete accessibility compliance.

## The player journey and the questions that matter

| Journey | Questions asked | Finding and response |
| --- | --- | --- |
| First visit | What is this game? What do I do to win? Where should a beginner start? | Replaced the unexplained button column with mode cards. Learning appears first; the subtitle describes connecting opposite edges. |
| Choosing a mode | How many people play? One device or several? Does it need a network? What is experimental? | Each card explains the player arrangement. Hex is still opt-in and explicitly experimental. |
| Returning | Can I continue? Will starting another game replace it? Will refreshing save it? | Continue appears before new modes. Session-only offline storage is disclosed; replacement confirmations remain. Durable browser match saving is still missing. |
| AI setup | What distinguishes Easy, Medium, Hard and Expert? Which color am I? Is my selection announced? | Added difficulty descriptions and selected semantics; game title names the AI. Ratings are estimates, not evidence of calibrated human skill. |
| Board size | Is the smallest board appropriate to learn on? Where do caps exist? Are stones all flat? | Supplies now say stones can be flat or standing. Contextual tips avoid caps on 3×3/4×4. A 5×5 default retains the complete piece set. |
| Timed setup | How many minutes does each player get? What happens with zero or a blank? Does changing size change the time? | Clock fields have labels and validation. Start rejects invalid time; size updates untouched defaults. |
| Opening | Why am I placing the other color? When does normal play start? | Existing opening instructions remain; help explains the two-turn exchange. Hex help explains its three-turn exchange. |
| Placement | Did I commit or merely preview? Can I cancel? How do I change orientation? | Trialled tap-to-preview/tap-to-confirm. Added help explaining the interaction. Square and hex gestures still differ; consolidating them needs a separate interaction redesign. |
| Stacks | Who owns a mixed stack? What is buried? How many may I carry? Which drops are legal? Can I crush my own wall? | Existing long-press inspection and legal-path preview remain. Rule/gesture regressions cover order, caps and walls. Hex gets individual focusable, labelled polygon cells. |
| Invalid actions | Does an invalid move leave the board intact? Is the explanation visible, or only audible? | Atomic rules remain authoritative. Some square invalid-action feedback is still sound-only: a follow-up should show the reason near the selected cell. |
| Waiting for AI | Is it thinking or frozen? Can I leave? Can an old response move in a new match? | Native search runs in an isolate; web yields between root candidates. Added mounted/state/session guards and retry after replacing a searched position. Large-board worst-case web responsiveness is still a profiling task. |
| AI quality | Does it take a win, defend, and evaluate both players consistently? Are harder tiers actually stronger? | Corrected fixed-perspective scores being negated between turns. Forced-fork and legal-match trials exercise the correction. Elo calibration and large sample strength comparisons remain open. |
| Online entry | Do I need an account? Where does the room code come from? Can I scan instead? How do I recover from a wrong code? | Clarified guest identity; labelled QR/clear/back actions. Invalid-length Join now has a real disabled state instead of a button that only shakes. |
| Online authority | Can I act on the opponent's turn? Are acknowledged moves duplicated? What happens when somebody leaves? | Hex controller/protocol tests already cover seat ownership and acknowledgement. Production multi-client, reconnect and clock synchronization require deployed-environment trials. |
| Three players | What are my goal edges? Whose turn is it? Which device controls each seat? Can the host just observe? | Separate three-seat chips identify ownership. Shared A/A, B/B and C/C boundaries are available to every color; legacy rooms retain assigned goals. Local, remote and AI ownership remain independent. |
| Hex setup | Can I configure every human/AI combination? Does it change normal Tak? Does it grant standard achievements? | Existing 27-configuration coverage retained. Setup and help explicitly state that square achievements and ratings do not apply. |
| Hex ending | Why did someone win? What were the flat counts? How do we play again? | Added all three exposed-flat scores and an explicit return-to-setup action. Supplies and starter advantage still need human balance testing. |
| Learning | Is the objective readable? Do I know why a lesson is locked? Can I get an optional clue? | Locked rows name prerequisites. Puzzle objectives are visible; authored hints are available on demand. |
| Progression | Does completing a step differ from winning a multi-move puzzle? Can a loss unlock the next puzzle? Is Next eligible? | Success uses the learner's result. Scripted puzzles require a win; losses/draws do not complete. Next checks prerequisites. |
| Tutorial completion | Can I replay, continue learning, or return home? Is restarting a scenario really a restart? | Every completion offers Home and Replay; eligible Next remains. Restart reloads the same scenario rather than a normal match carrying old scenario metadata. |
| Results | Can I see the board after winning? Why did I win? How do I play again? | Nonblocking road/result display retained, with visible Home/Play again. Terminal undo is disabled to avoid repeatedly recording the same win. |
| Achievements | Is something locked or disabled? What progress have I made? Which modes count? Where do I use a reward? | Readable labels, explicit lock status, progress counts, total wins, scope explanation, and a Settings link. Hex is excluded explicitly. |
| Achievement persistence | Does it need sign-in? Is it local, cloud, or synced? Can multiple unlocks obscure each other? | Corrected account copy: local achievements work without sign-in. Award dialogs are awaited instead of stacked. Unlock/persistence tests exercise all eleven awards. |
| Cosmetics | Can I preview a reward? Discover its requirement on a phone? Activate it with a keyboard? | Locked styles show their color and explain the requirement on tap. InkWell supplies activation/focus behavior instead of a GestureDetector alone. |
| Settings | Can I read and identify every switch and time field? Do audio changes agree with the game toolbar? | Switch/time labels added; in-game mute persists to the same preference. Android Play Games is explained honestly in the browser instead of showing a no-op sign-in button. |
| Navigation | Does Back leave or undo? Does Home lose the match? What happens to a clock? | Back navigation no longer secretly undoes. Explicit Home pauses an offline clock; Continue resumes it. Online clocks keep running. System-back clock handling remains a follow-up. |
| Phone layout | Do controls fit at 390 px and at larger text sizes? Can the smallest targets be hit? | Menu cards wrap descriptions; toolbar uses a labelled options menu so its title remains readable. Mobile widget checks and browser inspection are recorded below. |
| Accessibility | Are actions named, selected state announced, focus visible, and the board usable without color alone? | Added option/switch labels and per-cell hex keyboard activation. Full screen-reader navigation, color-vision simulation, zoom and device touch testing remain open. |
| Offline/error recovery | Can I still play offline when auth fails? Can I tell an online problem from a game problem? | Local/AI modes remain independent. Localhost is rejected by the existing reCAPTCHA site key; this does not prevent offline games. No authentication protection was bypassed. |
| Trust and completeness | Which things were actually trialled? Is the prototype balanced? Are claims supported? | The evidence matrix separates browser, widget, model, and backend coverage; production/device limitations are explicit. |

## Findings fixed

1. **High: incorrect AI search signs.** Fixed-perspective evaluations now use
   maximizing/minimizing turns with alpha-beta pruning. The old alternating
   negations could favor worse positions depending on depth parity.
2. **High: puzzle completion on a loss.** Learner victory is now required for a
   finished puzzle, and scripted puzzles cannot unlock on their first setup move.
3. **High: stale AI work and screen disposal.** Search does not apply after the
   game/session changes or access a departed WidgetRef. Native search moves off
   the UI thread; browser root candidates yield to rendering.
4. **Medium: unclear first-run choices and poor dark-menu contrast.** Mode cards
   use theme colors, visible player arrangements, and a clear learning route.
5. **Medium: missing result actions and scenario navigation.** Prominent replay,
   home, restart and prerequisite-aware progression actions were added.
6. **Medium: misleading storage/account/achievement claims.** Copy now distinguishes
   local achievements, session-only games, Android cloud saves and experimental Hex.
7. **Medium: inaccessible settings, choices and Hex canvas.** Added labels,
   selected states, polygon cell semantics and keyboard activation.
8. **Medium: incomplete reward UX.** Added local progress, total wins, readable
   requirements, reward navigation and tap/keyboard explanations for locked styles.
9. **Medium: silent clock fallback and disabled-looking Join.** Match time input
   validates and blocks starting with zero/blank; invalid Join is actually disabled.
10. **Low: irrelevant, unstable hints.** Square tips are tied to turn/board context;
    authored puzzle hints can be requested instead of existing only in metadata.

11. **High: misleading puzzle setups.** The Crucible had an unintended winding
    road on its second move. Iron Causeway filled the board before the final
    cap spread. Corrected those cells and replayed all three scripted multi-move
    solutions to learner road victories.
12. **Medium: narrow/enlarged-text overflow.** Fixed the result heading, clock
    setup, settings headers and achievement statistics. Regression trials scroll
    both themes at 320 px with 150% text, and exercise 390 px result/help flows.
13. **Medium: AI starts during widget construction.** Initial AI and resumed clock
    updates now happen after mounting. Leaving during the AI delay is covered by
    a disposal regression. Completed guided lessons no longer schedule an
    unnecessary opponent move.

## Evidence matrix

Final automated verification: the **176-test Flutter suite passed**, followed
by **four additional targeted tests** (three full Hex matches and the native
isolate API). This makes 180 distinct passing tests, with 48 added by this audit. Strict `flutter analyze --fatal-infos` reported no issues.
Release web build succeeded and the updated build was trialled at 390x844.
The existing Flutter bootstrap/service-worker deprecation warnings remain; they
do not prevent this build. The evidence below distinguishes actual browser
trials from model fixtures.

| Area | Browser trial | Additional automated coverage |
| --- | --- | --- |
| Easy | Complete 3×3 match to road loss; result and New Game inspected | Immediate wins at 3/5/8; seeded full 3×3 match |
| Medium | Human Dark, opening exchange and AI follow-up | Same sizes and seeded match |
| Hard | Human Dark, opening and wall response | Same plus a three-ply forced fork |
| Expert | Human Dark, opening and next response repeated on the updated build | Same plus a three-ply forced fork |
| Tutorials | First two lessons completed, Next and saved progress inspected | Every authored first action; scenario success contract |
| Puzzles | Selector/locked prerequisites inspected | All six first actions and three full multi-move solutions |
| Local | Updated 390 px: complete road win, visible board, Home/Play again, retained 3x3 size and zero-minute rejection | Gesture/rules tests; result/help/disposal and clock-layout flows |
| Hex | Updated 390 px: 19-cell Enter preview/confirm; 61-cell two-human/AI exchange, AI follow-up and pause feedback. Previous spread trial retained | 27 seat configurations, replay/AI/controller/rules/widget tests; full three-AI matches on all sizes |
| Online | Lobby, code entry and invalid Join inspected | Existing room/emulator coverage; no claim of production multi-client play |
| Settings | Updated dark phone controls, readable locked previews, tap requirements and Android-only sign-in explanation verified | Validation, persistence and mobile layout checks |
| Achievements | Updated device-local tutorial/win progress survived reload; Use rewards opens Settings | All eleven unlocks, duplicate suppression and rehydration |

### Full Hex AI trial observations

These are single deterministic native runs, starting with Ivory; timings are
not browser latency or statistically calibrated benchmarks. All moves were
accepted by HexRules, all games reached a terminal result, and the AI
returned no further move afterward.

| Cells | Moves to finish | Whole-match search time | Winner |
| --- | --- | --- | --- |
| 19 | 84 | 13.3 s | Copper |
| 37 | 54 | 36.3 s | Copper |
| 61 | 66 | 165.0 s | Copper |

The repeated Copper winner merits starter-rotation and human balance trials;
three runs cannot establish an advantage. Large-board search cost is an observed
performance concern, beyond checking that inputs remain responsive.

## Responsive follow-up (2026-10-09)

Requested a second check for mobile and desktop web. **72 focused Flutter
layout/gesture tests passed** and strict analysis and the release web build
passed. This adds 58 layout cases to the previous 180 tests (238 current cases);
the entire suite was not rerun during this presentation-only follow-up.

The matrix covers 320x568, 390x844, 844x390 landscape, 1024x600 and 1366x768,
with 100% and 150% text. It exercises 8x8 square opening previews/cancel,
results, tutorial objectives, 61-cell Hex previews/confirm and setup. Settings
and achievements scroll in both themes at phone, landscape and desktop sizes.
Existing stack gestures and Hex confirmation regressions also passed.

Fixed instruction-panel overflow, tiny/collapsed Hex boards on short screens,
scaled square supply panels, and enlarged-text Hex action overflow. Short
windows scroll the game content rather than squeezing away the board. Settings
and achievements use a centered maximum width on desktop.

Actual browser inspection of the rebuilt release verified desktop 61-cell
layout at 1366x768, its 320x568 phone preview and confirmation controls, and
scrolling to those controls at 844x390. These are simulated viewport sizes;
physical-device Safari/Chrome, safe-area keyboards and platform rendering still
need device smoke tests.

## Prioritized remaining work

The next movement iteration is documented in [MOVEMENT_UX.md](MOVEMENT_UX.md).
It adds explicit square carry/drop controls, actionable adjacent highlights,
reversible step planning and displacement-based dragging. Hex's endpoint and
distribution picker remains a separate follow-up.

- **Before production online Hex trials:** deploy reviewed Firestore rules. AI
  still runs on the host; there is no host failover or authoritative server
  adjudication. Honest clients reject illegal logs, but a modified client can
  still lock a room with a shape-valid illegal move.
- **Durable offline matches:** save a versioned square/hex snapshot and replay
  history, with restore/migration/error tests. Session-only Continue is now honest.
- **AI strength/performance:** compare tiers over many seeds and board sizes,
  measure large-board web root evaluation, and consider a dedicated web worker.
  Yielding candidates does not make every sub-search interruptible.
- **Physical devices and 200% text:** the responsive follow-up covers 150% text
  and short screens. Check real keyboards, safe areas and 200% accessibility
  sizes on Safari/Chrome and native devices.
- **Clock lifecycle:** explicit offline Home pauses; test OS back, backgrounding
  and real online clock synchronization across devices before promising fairness.
- **Accessible controls:** measure all theme/cosmetic contrasts, add reduced-motion
  preference, screen-reader announcements for moves/results, and test native
  TalkBack/VoiceOver. Hex fixed goal edges still rely heavily on color.
- **In-context invalid move explanations:** explain caps, blocked walls, carry
  limits and wrong tutorial actions visually; muted play must remain understandable.
- **Balance:** rotate starters, measure Hex reserve endings and kingmaking with
  people. Automated legality tests are not a balance study.
- **Progress identity:** offline/browser achievements are device-local. Reliable
  cloud sync and durable per-match award identifiers need a separate schema.
- **Product flows:** explicit online draw/rematch negotiation and Hex resignation,
  cleanup/abandoned seats and reconnection belong to protocol changes, not cosmetic UI.

## Reference criteria

The inspection uses W3C guidance on
[text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html),
[target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html),
and [labels/instructions](https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html).
Theme-based improvements are not a claim that every screen passes WCAG.
