# Stones: finishing plan and product decisions

Planning record, 2026-10-17. Product decisions below are confirmed; release targets
and the delivery sequence are proposed defaults. This document scopes the coding
handoff. Protocol and migration tasks require their specified design/test review
before deployment; no gameplay changes have been implemented in this audit.

Execution began on 2026-10-17 on `codex/finishing-foundation`. See
[release readiness](RELEASE_READINESS.md) for implemented work, qualification and
pending gates. Packets are not complete merely because a prototype/build exists.
The baseline tooling and isolated design preview are implemented on the branch.
The owner approved the revised game-first preview and authorized continuation.
Packet 3 is in implementation; physical-device qualification for packet 1 remains
pending. Later packets have not been represented as complete.

## Product promise

**A beautiful, welcoming place to learn and play Tak with friends, together or
across several days.** Keep the crafted boards and tactile pieces, with a direct,
playful game menu. Owner feedback rejected the hospitality/marketing treatment
("Pull up a chair") as corporate and overdone. Lead with playing and learning
the game, use concrete instructions, and let the pieces provide the character.

Decisions confirmed with the owner:

- Optimize the first ten minutes for newcomers invited by friends.
- Square leads the introduction; Hex is a visible, polished expansion.
- Keep Square and Hex selectable, the shared controls and flexible two-to-four
  player seat setup. Variants must be clearly distinguished from standard Tak.
- Live and asynchronous friend play are both release promises.
- Earned themes, achievements and learning progress follow the signed-in account
  between Android and web. Guests can still play without signing in.
- Keep game AI on participants' devices and Firebase on Spark. A narrowly scoped
  free-tier service for reminders is acceptable; paid hosting is not assumed.
- Release after quality gates pass, without an arbitrary deadline.
- Retain exactly five visual sets. More modes and more sets are not the finish.
- Offer an AI replacement after explicit resignation in a casual group game;
  continuing this way makes the game unrated. Closing the app preserves the seat.
- Timing belongs in shared game settings and uses a chess-style per-player time
  bank. Do not introduce a separate per-turn correspondence deadline by default.
- A timeout with more than two players must allow the table to continue with the
  existing pieces left in place. Skip the expired seat's future turns; its pieces
  remain capturable/carryable under normal rules, but that player cannot win.
  If only one active player remains, that player wins.
- Offer one welcoming early cosmetic reward; reserve the remaining sets for
  substantial skill challenges. Preserve all already earned cosmetics.

## Audit: enough capability, incomplete player journeys

The shared game engine, controls, saves, local AI, Court, learning, five themes,
achievements and community ratings provide sufficient breadth. The most valuable
remaining work connects these capabilities into dependable experiences.

| Area | Current evidence | Finishing requirement |
| --- | --- | --- |
| Starting | Square/Hex entry points lead to a long shared configuration form. Joining is below that form. | Quick default starts, direct Join, advanced choices disclosed when needed. |
| Returning | Durable rooms exist, but saved-room shortcuts are a local list of ten entries. | Account-backed My games with turn/status, recovery and completed games. |
| Finishing | Shared result controls show flat counts and Back to play selection. | Explain the actual result, highlight its cause, review the moves and rematch. |
| Identity | Google identity owns online seats and ratings; progression remains local. Legacy Play Games saves use the old Square implementation. | One coherent Stones account, safe progress migration and explicit lifecycle controls. |
| Learning | A filtered catalog of lessons/studies; completion returns to the list. Several multiplayer studies repeat one cap-delivery motif. | A short fundamentals path, Next/Practice actions and a curated tactical progression. |
| Presentation | Warm colors and ornate pieces, but menu/setup surfaces remain conventional forms. | Consistent game-first presentation with readable, stable controls. |
| Competition | Many independent rating pools and intentionally cautious calibration. | A restrained secondary feature; spotlight standard Square rather than an empty maze of ladders. |
| Release | Substantial automated coverage, but actual account/device qualification and Android/web parity remain incomplete. | Real-device and multi-account release evidence, plus accurate store/privacy disclosures. |

Audit sources are the current shared screens/services, development map and
existing audit documents. Saved UI captures were inspected; the live browser
inspection timed out. This audit is not a completed fresh usability trial.
Historical documents contain superseded architecture and status statements.

The privacy page presently contradicts account/room/rating storage and Analytics
initialization. Resolve implementation and disclosures together. Account deletion
is absent from the current account interface. These are release work, not polish.

## Feature and quality boundaries

A feature earns its place if it helps someone learn, play, return, improve or
express taste. It becomes bloat when it demands attention before a normal game,
duplicates another system, or creates combinations we cannot support reliably.

Keep flexible setup behind a simple default. Keep Court and curated puzzles.
Keep substantial optional mastery without requiring grind to understand the app.
Keep ratings accurate and optional. Defer new shapes, additional themes, a social
feed, public chat, tournaments, seasons, a friends graph and automatic opponent
matching. Invitations and rematches provide the first social loop.

Atmosphere belongs in the table surroundings, materials, restrained transitions
and sound. Ownership, piece type, stack contents, destination and confirmation
must remain clearer than decoration. No forced camera movement, particles over
playable cells, mandatory ambience or visual reliance on color alone. Respect
reduced motion, larger text and muted audio. Start with a strong Classic table;
the four unlockable sets inherit a coherent surrounding treatment without five
separate scene engines or a new 3D renderer.

## Proposed delivery sequence

Each numbered item is a bounded implementation packet for GPT-6.1 Sol Medium.
An implementer should take one packet at a time, preserve existing local changes,
and report code, tests, migration effects and remaining evidence separately.

### 1. Establish the release baseline

Reconcile the current architecture/release documents, identify the exact web and
Play builds, and create a reproducible device/test matrix. Inventory actual stored
data, Analytics use, existing accounts and old room/save formats before migration.
Record current startup, input, AI and reconnect timings on named reference devices.

Acceptance: a single current release checklist; reproducible testing commands;
explicit evidence versus untested claims; no configuration changes disguised as
cleanup. Restore a usable development/CI workflow without assuming the old local
temporary Flutter SDK still exists.

### 2. Approve the core visual and navigation prototype

Design the home, setup and one active Classic table together at phone and desktop
sizes. Keep Square/Hex home choices; add obvious Join, My games and Learn routes.
Use a restrained serif for identity and a highly readable interface typeface for
small controls/status. Move explanatory paragraphs out of the primary action path.
Keep the board's position stable as selection, hints and connection status change.

Acceptance: owner-approved captures/prototype of home, setup, active board and
result at narrow phone and desktop sizes; four-seat and tall-stack examples;
light/dark and large-text checks. Establish reusable design tokens/components
before the rest of the visual pass. This task does not rewrite game logic.

### 3. Finish first-game setup and invitations

Apply the approved shell to home/setup. Preserve the shared seat editor and all
existing configurations; expose sensible defaults and advanced options separately.
Put Join outside the create form. Add a canonical HTTPS room invitation, native
share sheet where available and copy-link/code fallbacks. Route cold starts and
already-running clients through one invitation handler, retaining legacy codes.

Acceptance: an invitee opens the correct room without selecting a board first;
full/ended/invalid rooms and wrong signed-in identity have useful recovery paths;
opening a link cannot silently replace an active match or claim an unintended seat.
Verify Android app links against the Play app-signing certificate and domain-root
association file, with a working browser fallback if app association is unavailable.

### 4. Unify account progress and migration

Introduce an account-scoped progression repository with a durable local cache and
owner-private Firestore storage. Preserve existing unlocks and known learning
completion. Deduplicate future progression using stable event/match identifiers;
do not sum overlapping snapshots or fabricate historical achievement evidence.
Specify and test legacy baseline import, concurrent devices, pending offline
events, account switching and explicit guest-to-existing-account merge before
connecting the UI. Device audio/accessibility preferences remain device-specific.

Acceptance: progress earned on A appears on B; concurrent/offline progress is
retained once; user A's cached progress never appears as user B's; migration can
be retried without awarding twice. Sync failure never blocks a game. Consolidate
account UI and clearly isolate legacy Play Games recovery during transition.

### 5. Make games discoverable across devices

Add a paginated private account-backed game index and a My games screen with Your
turn, Waiting, Inviting and Completed states. Treat index summaries as navigation
data; open the authoritative room and validate before playing. Maintain local
guest access, import existing shortcuts when ownership matches, and distinguish
archiving a shortcut from leaving/resigning. Preserve old room readers.

Acceptance: a second signed-in device finds joined/hosted rooms without a code;
completed and archived rooms behave predictably; stale summaries, missing rooms,
interrupted index writes and sign-out cannot leak another account's game list.
Keep collection reads bounded and rules deny arbitrary private-room enumeration.

### 6. Support continued group play after forfeiture

Create a versioned group-game lifecycle contract shared by rules, AI, previews,
replay, storage and online validation. Timeout retires the seat, skips its turns
and preserves every stone in place, including walls and capstones with normal
blocking/capture behavior. Inactive seats are excluded from winning roads, flat
scores and reserve-exhaustion triggers; the occupied board still includes their
pieces. One remaining active player wins. Ordinary two-player clock loss remains
a concession to the opponent.

Explicit casual group resignation offers a permanent AI substitute after the
remaining human owners agree; declining substitution retires the seat. Substitution
keeps that seat's pieces/reserves and makes the continuation unrated. Retired or
replaced humans cannot reclaim their seat by reconnecting. Page closure is neither
resignation nor timeout unless the configured clock actually expires.

Before coding, specify the versioned action order, race handling, opening turns
and rating/achievement qualification in fixtures. Keep initial seat configuration
and the original rule profile immutable: a four-seat Square game reduced to two
does not silently become standard Tak. Old rooms retain their old termination
semantics. Upgrade readers before enabling creation of the new room version.

Acceptance: expiry versus move races, retirement during the opening, captured
inactive pieces, inactive capstone blockers, inactive roads, active-only flat
ties, successive retirements, consent races, reconnect and replay on both shapes.
Rules, AI and human previews must agree. Specialist achievement credit must never
be fabricated for a game made easier by a replacement or timeout.

### 7. Complete the end-of-game and repeat-play loop

Explain victory/draw/resignation and visually identify the winning road or flat
count. Add read-only move review and Play again with the existing setup. Online
rematches require participant acceptance, create a new room and rotate the
starting seat; never erase the finished log or reuse its reward/rating identity.
Represent waiting/declined rematches explicitly and permit returning later.

Acceptance: duplicate taps and concurrent rematch requests create one agreed next
table; leaving the result screen loses no result/progress; review never changes
the recorded game. Integrate the lifecycle from packet 6 rather than creating a
second resignation or timeout implementation.

### 8. Deliver asynchronous play and reminders

Use the same room engine. Untimed is the default; optional chess-style cumulative
time banks belong in the shared setup/settings. Extend custom time entry to suit
long games without adding a separate per-turn deadline system. Closing an online
game does not pause a configured clock. Add durable turn metadata and reminder intent
with successful room updates, then process it in a small trusted service.

Cloudflare Workers Free with Firebase Cloud Messaging is a candidate, not a
proven deployment choice. First verify token validation, FCM sending, retry/dedup
storage and scheduled recovery within its CPU/request and Spark read/write limits.
Use bounded batches and no whole-database polling. A client closing immediately
after its move must not lose the reminder job. Validate membership/current turn;
the client must never choose arbitrary recipients or supply notification text.

Ask for notification permission after a player chooses reminders for a useful
game. Provide per-game mute, clear disabled/unsupported states and no repeated
nagging. Notifications open the correct game and stale notifications show its
current state. Never make gameplay depend on notification delivery.

AI still runs locally: finish consecutive pending AI turns while a participant
keeps the table open; recover a lost runner through the existing lease. If all
participants close before this completes, expose Waiting for computer and a way
to reopen the table. Do not imply that AI continues in the cloud. Test this
interruption explicitly before promising asynchronous mixed tables.

Acceptance: real Android and supported-browser background delivery; duplicate,
stale and failed jobs; revoked tokens; sign-out; denied permission; next-day room
recovery; service outage/quota behavior. A provider acceptance response is not
proof that a device displayed a notification.

### 9. Turn learning into a short path and curate progression

Create a common Square fundamentals path leading into a coached game, with Next,
Continue learning and Try a game actions. Teach Hex differences after fundamentals
without hiding direct access. Use visual move/road highlights with short coaching
explanations; hints must remain optional. Edit repeated puzzles into optional
variations and curate distinct tactical problems across shapes/sizes/phases.

Acceptance: newcomers understand the opening swap, walls/caps, stack control,
spreading and winning roads; all studies retain legal-state and solution proofs;
human solve trials validate difficulty ordering. Preserve saved IDs/awards through
content changes. Proposed reward default: keep Morocco as the learning reward,
earned through the common Square fundamentals rather than requiring every variant
tutorial. Classic stays available immediately; Slate, Marble and Kyoto retain
substantial mastery routes. Preserve all already earned rewards and alternate
earning routes. No sixth set or extra badge catalog is needed.

### 10. Apply the visual finish and performance limits

Extend the approved design across learning, collection, account and game history.
Polish five existing sets, sounds, stack inspection and feedback with the same
renderers on both boards. Load secondary visual assets on demand and keep an
immediate inexpensive fallback. No new theme count or separate Hex interaction.

Acceptance: dense Square/Hex boards, four owners and mixed-theme stacks remain
readable on a physical phone; controls remain stable; reduced motion/audio and
large text work; before/after measurements meet the agreed performance budgets.
Visual review should judge coherence and legibility, not just ornament density.

### 11. Finish account lifecycle, disclosure and support

Provide a discoverable account/data deletion request path in the app and on the
website, with recent authentication and a durable, retryable cleanup procedure.
Define treatment of other players' shared histories and pending rooms before
implementation. Keep deletion from creating fabricated wins or corrupt ratings.
Assess whether a separately permissioned route in the small service can perform
bounded cleanup; never ship administrative credentials in the client.

Make the privacy page, actual telemetry, retention behavior and Play declarations
agree. Prefer removing unused Analytics initialization to collecting without a
clear product purpose. Add a support/report action with a preview of diagnostic
details; exclude credentials and private game content by default.

Acceptance: lifecycle cases and cleanup retries pass; unrelated participants'
data survives; guest versus account deletion is clear; published disclosures and
store metadata describe the shipped build. Public launch is gated on this task.

### 12. Qualify one release across web and Android

Keep community ratings secondary and make standard Square the discoverable
starting ladder. Preserve separate pools and honest AI calibration. Test actual
signed-in result settlement rather than relying on fake identities or arithmetic
unit tests. Build web and signed Android from the same qualified source revision;
verify update/install, OAuth, invitations, notifications and previous saves on
the Play-distributed app, not only a debug APK.

Use CI to produce reproducible candidate artifacts and release notes. Automated
upload to a testing track can follow a working credential/permission setup;
production publication remains a deliberate release action. Roll out backward-
compatible rules/indexes before dependent clients and retain recovery/rollback.

## Proposed release gates

These are proposed targets to confirm against the baseline, not current claims.

- Five unfamiliar testers; at least four can complete the fundamentals and start
  a game without coaching, join a valid invitation within 90 seconds after load,
  and explain why a sample result was won or drawn.
- Meet Play Console's production-access test requirement as well: on 2026-10-17
  it displays twelve opted-in testers for fourteen continuous days, with three
  currently opted in. This is separate from the product's usability sample.
- At least twenty completed friend games across the supported shapes, seat
  counts and human/AI combinations, including a week-long asynchronous trial.
  No unexplained state divergence, lost confirmed move, lost earned progress,
  duplicate result or unrecoverable room in the candidate build.
- Real independent accounts exercise sign-in/cancel/retry, guest linking,
  collision, account switching, device switching, rewards and rating settlement.
- Firefox Android and Chrome Android, Play Android build, desktop Firefox/Chrome,
  and Safari web are explicit coverage targets; list any unsupported notification
  combinations accurately rather than claiming universal delivery.
- Immediate visible tap response target: within 100 ms at the 95th percentile on
  a named midrange reference phone. Target smooth 60 Hz interaction while AI runs.
  Establish cold/repeat startup and network-recovery budgets from measured baseline
  before approving atmospheric assets. Loading and retry must always be visible.
- Narrow phones, desktop, larger text, reduced motion, keyboard focus and a native
  screen-reader pass. No clipped essential action, hover-only control or hidden
  board movement during a move.
- Full Flutter tests, fatal-info analysis, web/Android builds and relevant Firestore
  emulator/security checks pass. Device trials remain separate evidence.
- Zero unresolved release-blocking defects in rules, identity, state retention,
  invitations or updates. Minor cosmetic defects may be documented and deferred
  only when they do not obscure game information or essential controls.

## Coding handoff and checkpoints

The owner will select GPT-6.1 Sol Medium for implementation. Start with packet 1,
then prototype packet 2 and obtain visual feedback before spreading the design.
Keep product choices in this record rather than re-deciding them in each task.
Each packet should produce a reviewable change, focused regression evidence and
updated release notes. A passing build is not a completed usability test.

Use independent review for account isolation/migration, room lifecycle/protocol,
notification authorization and deletion. Persist unfinished acceptance evidence
between sessions; do not mark a packet complete while required device tests are
merely listed as future work. A service feasibility failure must be surfaced as
a constraint, not hidden by switching to paid infrastructure.

Before coding an affected packet, freeze its protocol/merge/lifecycle contract in
a short task specification with fixtures and acceptance tests. Do not hand a
coding agent an entire multi-system rewrite and expect product decisions to
emerge from implementation. The shared engine and existing data must remain the
foundation; old formats need explicit compatibility, not silent reinterpretation.

## References

- [Current architecture](DEVELOPMENT.md), [shared engine contract](UNIFIED_PLAY_PLAN.md),
  [accounts](ANDROID_AND_ACCOUNTS.md), [progression](ACHIEVEMENTS.md), [ratings](RATINGS.md).
- [Progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/).
- [Firebase messaging architecture](https://firebase.google.com/docs/cloud-messaging).
- [Workers limits](https://developers.cloudflare.com/workers/platform/limits/) and
  [scheduled execution](https://developers.cloudflare.com/workers/configuration/cron-triggers/).
- [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111).
