# App-wide performance: benefit versus effort

Follow-up to the [settings performance audit](PERFORMANCE_AUDIT.md), November 3,
2026. This review explores shared and platform-specific opportunities throughout
the application. The exploration below records the starting evidence. The follow-up implementation
is documented in [the shared performance audit](PERFORMANCE_STAGE2.md); it does
not extend physical-device qualification.

The next stage should start with shared rendering and derived data, followed by
lazy collections, history and small I/O improvements. These have broader reach
than optimizing individual screens. Worker architectures, renderer switches and
storage migrations should follow only when measurements justify their effort.

## Evidence obtained

`tools/performance_opportunity_probe_test.dart` supplies reproducible diagnostics
for the starting source. Its three original checks passed on Flutter 3.47.7 /
Dart 3.13.5, Linux, using the test renderer and mock preferences. The current
probe adds collection mounting and reports the retained implementation; use
[the stage-two evidence](qa/performance-stage2.json) for current results. These are **work counts and
debug-VM observations**, not physical-device latency or frame-rate measurements.

| Probe | Observed work |
| --- | --- |
| Square 8×8, seven-drop draft, 20 selection rebuilds | 20 whole-board paints, including 1,280 static texture cells; 19,040 instrumented route-cell steps |
| Hex radius 4, eight-drop draft, 20 selection rebuilds | 20 whole-board paints, including 1,220 static texture cells; 20,960 instrumented route-cell steps |
| History with 40-move games | A ten-game page retains 410 replay positions; twenty games retain 820. Increasing the page limit and repeating the same request rebuilds validated records again. |
| History with 500 saved games | Approximately 1.71 MB of stored JSON is scanned/decoded before selecting a page. In this single exploratory run, 10/20-game reads took roughly 40–77 ms in the debug VM. |

The board probes vary presentation selection on a legally constructed spread
fixture; they are not complete human gesture journeys. Route-step counts include
the route-line painter. Source inspection identifies most of that work in the
`_staged` getter: it reconstructs the same drop map repeatedly for every cell's
semantics and badges. A complete interactive before/after trace is still needed
to quantify the user-visible gain.

## Ranked implementation backlog

Effort is relative engineering effort: **S** is a few hours to roughly a day,
**M** is roughly one to three days, **L** is a substantial architectural change.
These are sizing estimates, not delivery promises. Benefit is potential reach
and avoidable work; the first audit measures browser gains and the second measures shared work,
retention and rendering parity. Neither qualifies physical-device latency.

| Order | Opportunity and minimum change | Reach / potential benefit | Effort and regression conditions |
| --- | --- | --- | --- |
| 1 | Derive staged drops, per-cell visuals and seat palettes once per relevant build/immutable input. Share one authoritative spread-preview result between board, hand and controls instead of recomputing it through separate getters. Reuse board layout geometry for unchanged size/topology; retain shared immutable palette colors rather than repeatedly interpolating them. | Shared Square/Hex play, learning, review, touch/drag/keyboard interactions; all Flutter platforms. High-frequency work with direct evidence. | S–M. Bound caches by actual inputs. Preserve full stack contents, owner/theme changes, before/after draft states, labels, geometry and hit targets. Measure allocations and interaction latency, not just getter counts. |
| 2 | Separate static board material/grid/goals from selection, road and draft overlays. Reuse the static layer while interaction feedback changes. | Shared play, learning and review on web/native; high potential because expensive material painting is currently coupled to selection changes. | M. First measure layer separation. Web retained pictures can still rasterize every frame. Any further bitmap cache must account for effective zoom/DPR and memory; retain vector rendering during unsuitable transforms. Keep exact layer order, goal markings and high-zoom detail. |
| 3 | Make settings-gallery rows and large collections truly lazy. Build/prefetch near the viewport; dispose offscreen preview images and unused name consumers when safe. Use slivers/builders rather than putting a whole collection in one large `Column`/`Wrap`. | Settings, leaderboard, achievements, learning, My games, chat. Less layout, painting, image preparation and offscreen subscription work across platforms; especially useful at high DPR. | M. Preserve every entry and action, category/filter state, scroll restoration, focus, text scaling and screen-reader traversal. Keep focused controls alive. Names must be correct when rows become visible; prefetch the next viewport without subscribing to every offscreen player. |
| 4 | Reuse unchanged, already validated history records across repeat reads and “Show more.” Separate a validated final-position summary from retaining every intermediate position; materialize review positions when requested. | My games, history/review/rematch; CPU and memory savings on every platform, growing with collection/game length. | M. Keep raw records authoritative, owner isolation and immutable validation intact. Bound reuse by memory/record count and invalidate on raw-data changes. Preserve corrupt-record reporting, chronology, pagination and exact review positions. Start without a storage migration. |
| 5 | Batch newly received chat cleanup IDs into one serialized preference update. Avoid rebuilding chat when neither messages nor errors/expiry state changed. | Online chat; reduces bursts of platform/storage calls and quiet-poll UI work on web/native. | S. A fresh batch can currently perform one write per new message, up to the query limit of 50. Repeated IDs already skip writes. Preserve the three-second poll interval, delivery, ordering, expiry, filtering, retry and cleanup after reconnect; never persist message text. |
| 6 | Narrow remaining provider consumers and deduplicate equivalent data notifications. Home currently watches complete rating/account states; profile name streams include metadata updates even when the returned name is unchanged. | Home/account panels, standings, profiles, online roster, learning and compatibility screens. Moderate shared CPU/layout savings; small changes individually. | S–M in small batches. Select the exact displayed/action-driving fields. Preserve cached-versus-server confirmation, errors/retry, account changes, entitlement revocation and visible live updates. Do not globally discard Firestore metadata. |
| 7 | Coalesce genuinely duplicate in-flight rank/profile requests and redundant refresh paths; avoid fetching the same initial standings independently before attaching their live source when an equivalent live bootstrap is available. | Account/competition/profile screens; network latency, battery and backend-read savings across platforms. | S–M. Preserve server rank/tie semantics and freshness. Include identity, pool, rating and relevant refresh generation in reuse decisions. A changed leaderboard can change rank even when the personal rating is unchanged. Do not introduce indefinite rank/eligibility caches. |
| 8 | Bound sound-effect preparation concurrency and decouple independent optional startup work. Measure player setup before changing it. | Startup and first interactions on web/native; potential reduction in serialized initialization and platform calls. | S–M pilot. There is one player per `GameSound`, prepared serially. The dependency already has a shared asset cache, so duplicated URLs do **not** establish duplicated downloads. Preserve first-effect readiness, overlap/retrigger behavior, mute, all effects, error cleanup and retry. Do not blindly pool playback channels or lazy-load every first sound. |
| 9 | Release obsolete inactive music-buffer references after completed/cancelled transitions, where profiling demonstrates retention. Audit caches and two voice references together. | Browser music memory and GC on phones/desktops; potentially important on low-memory devices. Native music uses a different asset-player backend. | M. A long stereo decoded arrangement is about 46.6 MiB; `stop()` currently retains a voice's `_buffer`. This is not proof of a leak or an automatically reclaimable 93 MiB. Preserve active/paused buffers, offsets, immediate gesture permission, loop overlap and crossfades. Measure on/off/background/rapid-transition sequences. |
| 10 | Reuse trustworthy local completion/replay analysis within one immutable completion context, if finish/save traces show repeated work. Yield/chunk large metadata and JSON work when it blocks the UI. | Match finish, rewards, history, saves/recovery; all platforms, with particular browser main-thread relevance. | M. Never skip replay validation, change reward evidence or acknowledge a move before required durable storage. Keep account/result identity, old readers, corruption detection and transaction semantics. Persisted summaries/indexes require separate migration review if later needed. |
| 11 | Investigate stale native AI work after cancellation and long non-yielding web search segments. Add cancellation/worker support only around measured offenders. | Native battery/CPU after navigation; browser responsiveness during AI/Court. | M–L. Native dispatch already uses `compute`; web already cooperates with a four-millisecond budget. Preserve engine version, strength, candidate coverage, seeds, time contracts and stale-result rejection. Never solve jank by weakening AI or stopping a live online game. |
| 12 | Measure cold transport/parse/engine costs before introducing deferred optional libraries or changing web asset delivery. Audit result export preparation under repeated rating/name updates. | Cold web startup, older devices/connections, sharing dialog. | M–L, conditional. Preserve cold invitations, old-game adapters, sign-in, camera permissions, exact source/update recovery and full-resolution exports. Result image export already has signature guarding and image disposal. Do not add a service worker, switch renderers or remove legacy support as an unmeasured shortcut. |

Apply the smallest useful changes within each row; the table is not a mandate
for twelve simultaneous refactors. Start with orders 1–5. Expand the remaining
small changes when their traces or work counters justify them. Stop or defer
work whose measurable gain is within noise or whose compatibility cost exceeds
its benefit.

## Coverage and existing optimizations to retain

| Section / subsystem | Review outcome |
| --- | --- |
| Home, setup, account, settings, city previews | Provider subscription scope, optional startup, gallery virtualization and image lifetimes are candidates. Preserve independent settings and reader compatibility. |
| Shared Square/Hex matches, Court and studies | Primary next target: static material and derived board/draft data. Share improvements across callers. |
| Dense/tall stacks, zoom, inspector, placement animation | Preserve all layers, gestures and feedback. Piece painter invalidation already compares visible color/style/type/identity fields; do not “fix” it with unnecessary repaints or lower detail. |
| Clocks and elapsed time | Labels already rebuild independently; retain authoritative clock behavior. Timer consolidation is a low-priority measurement candidate, not a reason to reduce clock accuracy. |
| Learning and achievements | List building and scoped progression consumers are candidates. Collections are finite; benchmark their actual cost before adding large cache systems. |
| History, review, rematch and local recovery | Page parsing, replay reuse and intermediate-position retention have direct evidence. Keep all historical formats and validation. |
| Competition, player profiles, owner names and temporary rewards | Lazy rows, narrow subscriptions and duplicate reads are candidates. Preserve tie/rank logic, public names, identity scope and server-checked revocation. |
| Online rooms, reconnect and AI leases | Room replay is already memoized per immutable room and supports validated incremental append. Recovery has bounded timers. Preserve pending-write/server-confirmation distinctions; do not replace these protections with a blind snapshot cache. |
| Chat and storage | Batch cleanup identifiers and skip equivalent presentation updates. Existing duplicate-ID checks and joined-at/expiry semantics remain intact. |
| Music and sound effects | Inspect decoder/player/buffer lifetimes and initialization scheduling separately by backend. Preserve every sound and transition. |
| Results, image export, sharing, About, feedback, help and invitations | No broad high-cost hot path established in support screens. Preserve existing export signature caching/disposal, first-use flows and fallback actions; include them in regression journeys. |
| AI/rules/progression core | Existing topology/search caches, trusted immutable copy paths, cooperative yielding, native isolation and network work outside local progress queues are already useful. Avoid blanket rewrites. |
| Legacy Square/Hex compatibility | Included in regression scope when shared helpers change. Delete no compatibility code, routes or saved-format readers for performance. |

## Platform and regression gates

Use one scenario catalog with platform-specific measurement adapters:

- **Browsers:** Chrome/Chromium and Firefox on desktop and Android; Safari/WebKit
  on Apple devices. Include narrow/wide screens, DPR 1/2/3+, rotation and 60/120 Hz
  devices where available. Browser emulation does not qualify physical touch,
  compositor behavior or device memory.
- **Native Android:** profile/release builds on a named midrange and a lower-end
  phone; include GPU raster timing, UI timing, heap/GC, memory pressure and battery
  work in foreground/background/resume. Native timings and web timings stay separate.
- **Future native iOS/desktop:** keep shared optimizations backend-independent
  and the scenario catalog reusable. Native iOS currently lacks its complete
  project/signing/qualification path; desktop host widget tests are not desktop
  product qualification. Add device/build adapters when those targets exist;
  do not silently expand supported-platform promises.

For each retained optimization, compare the same fixtures/artifact/settings in
repeated runs without competing verification work. Collect visible input
completion, UI/raster distributions where supported, allocation/heap peaks and
plateaus, I/O/decoder/query counts, cold/warm startup and resource cleanup.
Continue to use the existing 100 ms p95 visible-input and smooth 60 Hz goals;
120 Hz has an approximately 8.3 ms frame budget. Request-animation-frame gaps
remain diagnostics, not compositor frame-rate proof.

Feature parity is an acceptance gate: Square/Hex, two/three/four seats, all six
cities and mixed combinations, tall stacks, carry/drop/Undo/Cancel/confirm,
crushing, inspection, zoom/rotation, reduced motion, enlarged text, keyboard and
screen readers, sound/music controls, clocks, names/ratings, save/resume/review,
old formats, corruption recovery, accounts and multiplayer faults. Use image and
semantic comparisons, rule/differential tests, subscription/write-count checks
and real interaction journeys appropriate to the changed subsystem. Do not lower
resolution, remove shadows or animation, truncate collections, weaken AI,
reduce delivery cadence, skip validation or delay required persistence to claim
a gain. Investigate latency/memory regressions even when average throughput improves.

Changes should remain separate and reversible, with source-bound before/after
evidence and explicit device gaps. Update affected feature contracts alongside
implementation. The implementation updates APP-08, SAVE-03/04 and ONLINE-06 with cache and
persistence guarantees; supported capabilities and device limits stay unchanged.

## Reproduce this exploration

```sh
flutter test --no-pub tools/performance_opportunity_probe_test.dart --reporter expanded
flutter analyze --no-pub --fatal-infos
```

Generated data is in `build/qa/performance-opportunities/`. The source-bound
summary is [performance-opportunities.json](qa/performance-opportunities.json).
No phone measurements, production network writes, deployment or new-platform
support were performed. Orders 1–5 are addressed in the
[shared performance audit](PERFORMANCE_STAGE2.md). The settings-gallery lazy-row
pilot was rejected after a measured scroll regression; the previous cached
gallery remains. The finite achievement-grid pilot also had mixed timing and
was excluded. Orders 6–12 remain conditional
for the reasons recorded there; this is not a mandate to rewrite working
subsystems without evidence of benefit.
