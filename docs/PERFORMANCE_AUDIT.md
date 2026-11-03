# Performance audit — 2026-11-03

The reported problem is scrolling the latest website in **Firefox on Android**.
The phone model, Android version and Firefox version were not supplied. This
audit preserves features, visual detail, animations, audio, AI strength,
accessibility and saved-data compatibility.

## Source and measurement boundaries

The read-only hosted integrity check passed for source
`95439d23502e0e247ccf3e194dc12b928759d14e`. The checkout's baseline is
`44c45a1d59d01b91bc2b682bfcde03b6e09e6dbc`; its application, dependency and web
sources match that hosted source. The existing local `analysis_options.yaml`
change is unrelated and retained.

Local checks use Flutter 3.47.7 / Dart 3.13.5 and release JavaScript/CanvasKit,
Linux with a two-CPU quota, desktop Firefox 153.0 and a 390×844 viewport at DPR 1.
The browser uses software graphics and wheel input. Browser semantics are
enabled consistently for automation. Production account, database and analytics
requests are blocked; disposable contexts contain only generated local games.
Public Firebase SDK bytes are cached locally between runs. Fresh-context and
reload startup observations are not physical cold-network startup measurements.

**No physical Android responsiveness, touch latency, GPU memory, TalkBack,
120 Hz behavior or real-account/network-load acceptance is claimed.** The
existing goals remain p95 visible input response within 100 ms on a named
midrange phone and smooth 60 Hz interaction, including during AI search.

## Ranked findings and changes

| Priority | Finding and evidence | Action / status |
| --- | --- | --- |
| High | Static city previews replay expensive textures, paths, gradients and blurred piece shadows during browser composition. Flutter paint counts are already zero during warmed gallery scrolling, so paint-count reuse alone does not establish cheap rasterization. The pinned web engine's `PaintVisitor.visitPicture` draws retained pictures during composition. | Each preview now prepares a device-resolution image from the **same** shared painter after its first frame. Scrolling reuses that image. No ornament, piece, shadow or resolution is removed. Browser measurements distinguish this from repaint isolation alone. |
| High | Scrolling an open preview re-recorded both complete board samples on every scroll frame: **120 sample paints over 60 frames**, at 390×844, 844×390 and 1366×900. | Repaint isolation reduces warmed dialog scroll sample paints to **zero** at all three sizes. Square/Hex, four owners, all piece types, locked requirements and read-only preview behavior are retained. |
| Medium | Changing placement animation enablement and a clock default rebuilt the application root twice and the settings route twice. Both appearance themes were constructed on each root build. | The root selects only appearance mode and retains its two immutable themes. Appearance, clock and Play Games consumers subscribe within their own sections. The same probe now records **zero** root and settings-route rebuilds for those changes; real appearance changes still update immediately. |
| Medium | The global audio listener re-synchronized effects for any settings change, including clock typing and appearance changes. Synchronization includes initialization checks and a mute-preference write. | Subscribe only to effects mute and music volume. A regression verifies unrelated edits do not reconfigure unlocked audio and subsequent mute changes still apply. |

The optional preview image budget is **32 MiB of RGBA pixels across all samples**,
including rasterizations still in flight. Board, pieces, geometry, layout size
and device pixel ratio invalidate an image. Replaced/unmounted images and stale
asynchronous results are disposed; an in-flight reservation remains held until
completion. Allocation failure or budget exhaustion retains the full-detail
vector preview. This bounds application-owned preview images, not total browser,
GPU, display-list or audio memory. Public preview constructors and settings
interfaces are unchanged; implementation state is private. No new dependencies,
renderer switches, storage migrations or backend changes are required.
Deferred Play Games sign-in/restore feedback remains scoped to the Settings
screen even when its lazy section scrolls out of view; disposal regressions
cover both callbacks.

## Measured browser comparison

Five before/after pairs ran sequentially after stopping compilers, test runners
and other browser probes. Each run used a fresh Firefox process/context, a warm
reload, identical SDK caching and 12 wheel steps per scenario. All ten journeys
passed with zero page errors. Values below are **median per-run p95 animation-frame
callback gaps**, not phone frame rates or compositor timings.

| Scenario | Before (ms) | After (ms) |
| --- | ---: | ---: |
| Settings gallery scrolling | 433.2 | 100.6 |
| Open city preview scrolling | 649.7 | 267.2 |
| Settings after Square and Hex play | 417.0 | 100.4 |
| Achievements | 66.4 | 66.1 |
| Learning list | 49.8 | 49.7 |
| My games | 17.2 | 17.2 |
| Leaderboard without live backend | 33.4 | 34.2 |

The targeted settings gaps improve approximately 4.3×, 2.4× and 4.2× respectively;
the other lists show no consistent change. Fresh-context semantics-ready startup
was 1.52 → 1.54 s, and reload was 1.09 → 1.09 s. These are local observations,
not Android startup budgets. The remaining long gaps, especially in dialogs,
mean this does **not** establish the 60 Hz acceptance goal.

A separate Firefox profile with diagnostic overhead and competing test work
captured 652/806 gallery and 1,889/2,010 dialog leaf samples in unsymbolicated
CanvasKit WebAssembly functions. Those intervals had zero and one GC/CC markers
respectively. This supports investigating rendering further on this host; it
does not establish a phone bottleneck, exact raster CPU cost or absence of memory
leaks. The generated profile and interval summary remain in
`build/qa/performance/firefox-profile/`.

## Wider audit and remaining work

The [app-wide benefit/effort review](PERFORMANCE_OPPORTUNITIES.md) expands this
backlog with measured board/history work counts, twelve ranked opportunities,
section coverage and cross-platform regression gates.

These are source-confirmed costs or qualification gaps, not additional proven
causes of the reported settings lag:

| Area | Inspection / local coverage | Next action and acceptance |
| --- | --- | --- |
| Gameplay rendering | Per-cell pieces and the board already have repaint boundaries. One board painter combines static material/grid/goals with changing selection, destinations and road overlays. Clock labels rebuild independently. | On the reference phone, profile dense Square/Hex, tall stacks, four seats, inspection and spread drafts. If static material replay dominates, split material/goals and interaction overlays into independent layers. Preserve exact geometry, layer order, gestures and image comparisons before keeping that change. |
| AI / Court / navigation | Web search and Court threat scans share the browser thread and cooperatively yield through the existing 4 ms budget. Native search uses an isolate. Disposing the match screen suspends local play, invalidates search tokens and detaches room work; a covered, still-mounted route needs separate profiling. Clock checkpoints use a separate timer. Existing AI diagnostics cover both shapes, two/four seats and all difficulties. | Profile active searches and covered-route transitions on Android Firefox. Move independently identified blocking work to resumable chunks or a worker with stale-result cancellation. Retain engine versions, legal candidates, search depth, difficulty, timing contracts and results; do not lower strength or interrupt live matches to meet a UI target. |
| Audio / memory | Music is opt-in, has two voices and retains up to two decoded arrangements. One 138.6 s stereo arrangement at 44.1 kHz needs approximately 46.6 MiB of float samples, independent of compressed download size. Voice references can extend buffer lifetimes. Position timers stop on pause/stop; no per-position UI subscription was found. | Record allocation/GC profiles across menu → Square → Hex → learning, loops and background/resume with music on and off. Check retained buffers after transitions. Any streaming/buffer-lifetime change must preserve Firefox gesture permission, crossfades, gapless loops and independent effects. |
| Lists / network | History replays only the visible page, but scans and decodes stored metadata first. The leaderboard listens to the top 50 players plus AI profiles and rebuilds its list on state updates. Achievements and learning use finite collections. Real cloud traffic is excluded from local measurements. | Profile a populated disposable history and test-backend leaderboard with frequent updates. Introduce chunked metadata work or lazy rows only when their cost is demonstrated; preserve records, ordering, pagination, rank semantics and refresh behavior. |
| Startup / lifecycle | Validated appearance loads before the first menu; optional services initialize independently of UI readiness. Elite eligibility polls every 60 s with disposal and a busy guard. Browser checks exercise fresh/reload startup, repeated navigation and settings after both game geometries. | Complete physical cold/warm startup, browser toolbar resize, rotation, enlarged text and background/resume trials. Capture visible action completion rather than equating HTTP transfer time or an animation-frame callback with user-visible readiness. |

## Reproduce and interpret evidence

Generated logs, profiles, contact sheets and raw measurements live in
`build/qa/performance/`; they are not shipped assets. The compact verification
record is [performance-verification.json](qa/performance-verification.json).

```sh
python scripts/generate_music.py
flutter test --no-pub test/audit/settings_performance_test.dart
flutter test --no-pub test/widgets/theme_sample_cache_test.dart
flutter test --no-pub tools/shared_performance_probe_test.dart --reporter expanded
flutter analyze --fatal-infos
flutter test --no-pub --concurrency=2
flutter build web --release --base-href /stones/ --no-web-resources-cdn
node tools/serve_web.mjs
python tools/performance_browser_probe.py --label after --runs 5
```

For an independent baseline, copy the two probe files (the settings test and
browser script) into a clean worktree at `44c45a1`, with their existing test
helpers. Run the settings test with
`--dart-define=STONES_PERF_ASSERT=false` and
`--dart-define=STONES_PERF_OUTPUT=build/qa/performance/before`. Build the baseline
to its own directory, serve it on a separate port, and pass that URL and
`--web-root` to the browser script. Run compared builds sequentially with no
compiler, test runner or competing browser in the background. Keep browser,
viewport, DPR, semantics, input steps and network policy identical.

The browser probe records raw `requestAnimationFrame` gaps, p50/p95/max,
gaps above 50/100 ms, source-artifact hashes, resource counts and browser details.
These measure main-thread callback cadence, **not compositor-dropped frames or
actual FPS**. Pointer-to-second-frame observations are explicitly proxies, not
verified visible input latency. Firefox does not expose Chromium's heap API;
its heap field is null. Use a separate `--firefox-profile --runs 1` diagnostic
for sampled stacks and GC markers; profiler overhead must not enter the timed
comparison.

Validation passed **2,070 full-suite tests**, followed by **12 focused checks**
covering the final asynchronous Play Games feedback guards as well as caching,
settings and audio. The shared-engine diagnostic passed all 16 shape/seat/tier
cases. Strict analysis reports no issues and the final release web build passes.
The final compiled main script and bootstrap hashes match the artifacts used in
the ten timed Firefox journeys. Separate Firefox profiling and Chromium
154.0.8037.57 journeys also pass without page errors; their timings are excluded
from the comparison because other verification work was running.

Shared vector contact sheets cover all 36 cosmetic combinations on both
shapes without pixel changes. Cache tests additionally verify cached pixel
equality at DPR 2, cosmetic/shape/size/DPR invalidation, budget fallback, pending
disposal and resource reuse. Existing city, enlarged text, locked preview,
independent selection, gesture, reduced-motion, learning, audio, history and
online-compatibility regressions remain required.

Feature contracts: PREF-01–06, APP-02/06/08. This is a local source candidate;
publication and physical-device qualification remain separate.
