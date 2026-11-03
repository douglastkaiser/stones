# Shared performance implementation

November 3, 2026. This addresses opportunities 1–5 from the
[app-wide benefit/effort review](PERFORMANCE_OPPORTUNITIES.md), on top of the
[settings optimization](PERFORMANCE_AUDIT.md). It preserves supported features,
visual detail, rules, AI strength, polling cadence and storage formats. This is
local source and a local release-web candidate; no deployment was performed.

The source promotion also preserves main commit `945d79a`'s unified city gallery.
The measurements below describe the earlier, source-bound candidate; current-main
integration is qualified separately in [Main integration](#main-integration).

## Changes and compatibility boundaries

- **Shared Square/Hex boards:** reuse layout centers/bounds/polygons, staged drop
  counts, immutable seat colors and unchanged stack visuals. Share the rules
  engine's preview result between hand and board consumers. Keys cover the actual
  position, original/landing positions, styles and draft values. Same-ply position
  replacement and caller-mutated style maps invalidate reuse. The public hand
  getter still returns an independently mutable list.
- **Static board material:** retain vector commands for the frame and each cell,
  replayed between dynamic highlights in the original order. Putting all static
  material below all highlights changes dense-board blending, so that approach
  was rejected. Vectors preserve zoom/DPR detail. Each board owns one layout and
  material set, releases pictures on size/topology/theme changes or disposal,
  and uses direct-vector painting beyond 128 cells (supported maxima: 64/61).
  This saves command preparation; renderers may still rasterize every replay.
- **Collections:** standings and completed-game entries mount near the viewport.
  The finite settings gallery and achievement grid keep their previous renderers.
  Retain natural row heights, widths, spacing,
  every entry/filter/action/label and scroll state. Focused rows stay alive;
  constrained widths remain responsive. Saved-room controls retain pending
  navigation/errors while offscreen and keep their identity when header rows
  change. Settings retain the previous layout,
  independent controls and screen-scoped asynchronous Play Games feedback. Learning already
  used per-entry lazy children and was left intact. Chat was already lazy.
- **History:** fully replay and validate a record before accepting it, but retain
  only its final position until review requests intermediate positions. Reuse
  unchanged validated summaries/metadata across reads. Exact raw strings remain
  authoritative: mutation, repair, deletion and account/guest-scope changes
  invalidate reuse. Metadata is bounded to 1,024 records/2 Mi characters;
  summaries to 32 records/2 Mi characters. Reviewed records leave the summary
  cache before materializing positions, preventing it from pinning expanded
  replays. First review materializes the positions with another replay; subsequent
  access on that record reuses the immutable list. No migration, skipped
  validation or deferred durable save.
- **Chat:** persist up to 50 fresh cleanup IDs in one serialized owner-scoped
  preference write. Keep IDs collected before a malformed later row fails. Skip
  duplicate writes and equivalent UI rebuilds; retain three-second polling,
  ordering, filtering, errors/recovery, expiry, finish and collapsed-panel cleanup.
  Retry failed platform writes even when SharedPreferences already updated its
  memory cache. Persist no message bodies.

## Evidence and regression scope

The actual shared BoardView renderer produced **216 byte-identical before/after
PNGs**: both shapes, all six board materials, all six piece styles and three sizes
(224/380/760), with mixed four-seat stacks and overlapping selected/destination/
road/draft highlights. Captures reuse widgets across style/theme/size/topology
transitions. Lifecycle tests additionally compare updated cached boards with fresh
mounts and verify picture release, mutable styles and same-ply replacements.

| Work / retention fixture | Before | After |
| --- | ---: | ---: |
| Square: 20 selection updates, static cell command recordings | 1,280 | 0 after warm paint |
| Hex: 20 selection updates, static cell command recordings | 1,220 | 0 after warm paint |
| Square: instrumented route-cell steps | 19,040 | 140 |
| Hex: instrumented route-cell steps | 20,960 | 160 |
| Twenty validated 40-move history summaries, retained positions | 820 | 20 until review |
| Fifty-entry standings fixture, mounted name rows at entry | 50 | 3 |
| Fifty fresh chat cleanup IDs, preference writes | 50 | 1 |
| Equivalent chat poll, panel rebuilds | 1 | 0 |

The board still visits its painter and replays 1,280/1,220 cell pictures in these
fixtures. These counts do not imply zero raster work or a frame rate. Initial
history reads still scan keys and validate the selected page. Position counts
measure retained states, not bytes or peak validation allocations.

New regressions cover offscreen focus retention/release, final entries remaining
reachable, constrained row widths and scroll offsets, bounded history caches,
repairs/deletions/account switches, immutable complete reviews, concurrent chat
rooms/account isolation/failed-write recovery, quiet polls, changed messages,
repeated errors/recovery, expiry and timer disposal. Existing board/stack/gesture,
city/locked-preview, enlarged-text/light/dark/responsive, review/rematch, account,
rules/AI, online/recovery and audio checks remain requirements.

Validation passed **2,081 full-suite tests** with concurrency two, followed by
**55 focused checks on the exact final source** after the saved-shortcut retention
and key guards. These cover lifecycle, keyboard traversal, recovery, standings
and community UI. Strict analysis reports no issues; the final release
JavaScript/CanvasKit web build passes. Existing dependency
Wasm dry-run warnings do not establish Wasm support; no renderer was changed.

## Final browser comparison

Five sequential Firefox pairs and a final Chromium journey pass with zero page
errors on the exact final release artifact. The corrected probe waits **1,000 ms**
before every scroll sample, excluding route/modal transitions and initial preview
preparation. Earlier navigation-overlap measurements remain separate in
`build/qa/performance-stage2/navigation-overlap/`; they are not steady-scroll
results. Do not attribute changes caused by this protocol correction to the app,
or compare these absolute values directly with the first audit's protocol.

Values are median per-run p95 **rAF callback gaps**, in milliseconds, on the
2-CPU software-rendering desktop host. They are not compositor FPS or phone
latency. Input steps, viewport, DPR, semantics, network policy and settling waits
are identical within each pair; no tests/compiler/browser compete with timed runs.

| Scenario | Before | After |
| --- | ---: | ---: |
| Settings gallery | 100.5 | 100.7 |
| City dialog | 267.0 | 283.6 |
| Settings after both games | 100.6 | 100.6 |
| Achievements | 50.5 | 50.5 |
| Learning | 49.5 | 34.2 |
| My games | 17.2 | 17.2 |
| Standings (no live backend) | 33.2 | 17.4 |

Settings retains its previous range. These short host samples do not establish
additional settings gains or a global frame-rate improvement. Learning/standings
have lower medians here; small-sample timing and shared dependencies do not
isolate their causes. Cold/warm app-ready medians are approximately 1.53/1.12 s
before and 1.56/1.11 s afterward. Device qualification remains open.

Three independent VM probe pairs show the 500-record repeated twenty-game read
at a median **59.6 → 2.2 ms**; the first ten-game read remains approximately
**42.1 → 41.3 ms**. Growing from ten to twenty games is **84.5 → 19.1 ms**.
These are mock-preferences/debug-VM observations, not device latency targets.
The fifty-entry standings fixture mounts three name rows instead of fifty and
verifies the final entry remains reachable. Settings/achievement mount counts
remain six/twenty-five because their finite rendering pilots were excluded.

## Rejected gallery pilot

The gallery virtualization pilot passed correctness tests but regressed the
release Firefox scroll measurements: the first comparison's gallery p95 rAF gap
rose from 100.9 ms to 216.8 ms, with a second candidate run at 233.4 ms. Post-game
settings similarly rose from 100.6 ms to 216.8/217.5 ms. Preparing and disposing
small preview images while rows enter/leave view trades retained resources for
new scroll work; fewer mounted samples did not establish a useful gain.

That pilot was reverted. Keep the first audit's six-city cached gallery and
32 MiB budget/fallback. Laziness remains for the larger collections. Rejected
source/artifact hashes and raw measurements are archived under
`build/qa/performance-stage2/rejected-gallery-lazy/`, separately from the final
comparison. The final build must preserve the existing settings improvement.

## Rejected achievement-grid pilot

Five paired release journeys gave mixed achievement timings: median per-run p95
callback gaps were 67.0 ms before and 83.5 ms with lazy rows; ranges overlapped
(50.4–217.0 ms and 50.5–133.4 ms). Fewer mounted cards did not establish a reliable
scroll improvement. The prototype also rebuilt row children on scroll-only
constraints; a targeted fixture counted 600 calls during 20 small offset changes.

The finite 25-card grid retains its previous renderer. The responsive-row helper
and its prototype tests are excluded from the final change. Large one-column
standings/history lists retain lazy mounting and focused-row preservation.
Raw prototype evidence is separate under
`build/qa/performance-stage2/rejected-achievement-lazy/`.

## Remaining opportunities

Orders 6–12 remain measurement-gated, not implicitly completed:

| Opportunity | Decision |
| --- | --- |
| More provider selection / name metadata | Lazy rows remove offscreen consumers. Broader selection needs live-update traces and field-by-field action/error review; no global metadata suppression. |
| Coalesce rank/profile requests | Equivalent request identity/freshness is unproven against changing leaderboards. Preserve rank and eligibility freshness. |
| Sound initialization concurrency | Assets are already cached by the dependency. Require platform startup traces before risking first-effect readiness, overlap or error cleanup. |
| Browser music buffers | Reference inspection identifies potential retention, not reclaimable bytes. Require heap evidence across paused/active/cancelled crossfades. |
| Completion reuse / persistence chunking | History reuse is implemented. Reward evidence, required saves and independent external records still validate as before; broader trust needs finish traces. |
| AI worker/cancellation architecture | Existing native isolation/web yielding remain. No strength, candidates, engine version or timing-contract changes without measured blocking segments. |
| Web bundles / renderer / export | No service-worker, renderer, library deferral or compatibility-reader changes without cold-route and transport measurements. Export already guards its image signature and disposes images. |

The review covers every section; it does not mandate speculative refactors of
working subsystems. Shared Flutter changes benefit their callers across targets,
but do not establish performance on every platform.

## Reproduce and qualification limits

Use Flutter 3.47.7 / Dart 3.13.5 and generated music assets. Save source/artifacts
before changing them; the stage-two baseline includes the first settings fix.

```sh
flutter test --no-pub
flutter analyze --no-pub --fatal-infos
flutter test --no-pub tools/performance_render_parity_test.dart --reporter expanded
flutter test --no-pub tools/performance_opportunity_probe_test.dart --reporter expanded
flutter build web --release --base-href /stones/ --no-web-resources-cdn
PORT=4175 WEB_ROOT=build/performance-stage2-before node tools/serve_web.mjs
PORT=4176 WEB_ROOT=build/web node tools/serve_web.mjs
python tools/performance_browser_probe.py --url http://127.0.0.1:4176/stones/ --web-root build/web --label after --runs 5 --output build/qa/performance-stage2
```

Use `--dart-define=STONES_PARITY_DIR=...` and
`--dart-define=STONES_OPPORTUNITY_OUTPUT=...` for separate captures. Compare identical
browser, viewport, DPR, semantics and input steps, sequentially without competing
verification work. The probe blocks production account/database/analytics traffic.
Its rAF gaps measure callback timing, not compositor FPS or visible-input latency.

Physical Android Firefox/Chrome, native Android GPU/heap/battery, Safari/WebKit,
phone touch/rotation/background, real assistive technology and populated live
cloud scenarios still need named-device qualification. Future native iOS/desktop
retain existing support limits. No feature was removed or intentionally changed;
local parity checks cannot guarantee every device-specific behavior.

Feature contracts updated: **APP-08, SAVE-03/04, ONLINE-06**. Adjacent PLAY/PREF/
LEARN/competition/account and legacy journeys remain regression requirements.
Source/artifact hashes and final verification outcomes:
[performance-stage2.json](qa/performance-stage2.json).

## Main integration

Before promotion, main advanced to `945d79a2bd7d17ffe979f853bdd7d762e9ff9eca`
(unified city gallery with independent board/piece selection). That feature,
its matching-city previews, locked/selected part labels, new room-appearance
regressions and ACCOUNT-08 contract are retained. The preview cache is applied
to the newer gallery rather than restoring the former category tabs. The browser
probe supports both old comparison artifacts and the current unified gallery.

The integrated source passes **2,088 full-suite tests**, **52 focused gallery,
cache and room checks**, strict analysis and changed-file formatting. The release
web build passes; Firefox and Chromium complete the unified-gallery journey with
zero page errors. All **216 shared-board render comparisons** remain byte-identical.
The production-code difference from the earlier measured candidate is confined
to the upstream gallery change; older comparative timings do not qualify that
new layout. No new timing-gain claim is made for it.

See [the integration record](qa/performance-main-integration.json) for source and
artifact hashes. Source promotion to main is authorized; publishing remains a
separate manual workflow. Physical-device limits above remain open. The user's
pre-existing analyzer exclusions are preserved locally and excluded from the
performance commit.
