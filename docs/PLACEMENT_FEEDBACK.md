# Placement and stack landing feedback

Implemented 2026-10-31 for shared Square/Hex matches and learning. Feature contracts:
PLAY-01, PLAY-04, PREF-04 and PREF-06. Rules, saved games, online messages, legacy
screens, rewards and clocks keep their existing contracts.

## Player behavior

Confirmed reserve placements drop into the cell, compress slightly on contact,
rebound a little and settle. A landing lasts 280 ms, with contact at 100 ms.
Spread destinations stagger in bottom-first route order by up to 35 ms; the
complete spread finishes within 420 ms. Only incoming visible layers receive
the landing transform, retaining supporting layers, owner styles and badges.
Capstones and groups have a heavier settle. Contact shadows are cell-clipped.

Settings → Appearance → Placement animations defaults on, persists locally and
resets to on. It is independent of Sound effects and background music. System
reduced motion suppresses landing motion. Turning motion off settles active
effects; turning it back on affects future moves. Without animation, the first
contact sound plays immediately. Existing short inspection/layer transitions
continue to honor the system reduced-motion preference.

Original wood, stone and marble clacks follow the existing board-material mapping
for reserve placements and mover-piece mapping for stack drops. A destination
group sounds once, with heavier variants for groups/caps; a crush uses the
existing crushing sound. Winning moves retain contact followed by the result cue.
The existing sound-effects toggle controls all of these, and optional audio
failures never reject a move. Browser audio still depends on user-gesture unlock.
See [audio provenance](../assets/sounds/SYNTHESIZED_AUDIO.md).

## Integration and cancellation

`MoveFeedbackBatch` contains uniquely identified, transient before/move/after
records. Local moves publish only after storage succeeds. Online moves publish
only for a single live append in the same room revision, suppressing joins,
duplicate snapshots, takebacks, disconnected catch-up and restore. Learning
records accepted player moves and automatic replies in order, without adding
them to competitive history or saved-game/network formats.

The match screen presents those records once, using one controller and repainting
only animated destination stacks per frame. Learning can show successive visual
snapshots while board semantics, controls and results retain the final committed
state. Pointer/keyboard board input immediately settles to that state before play.
New confirmed moves replace outstanding effects; board interaction, position
replacement, pause/disconnect, route coverage, backgrounding and disposal discard
pending motion/audio. Review and initial screen construction never replay a batch.

## Verification

Automated coverage lives in `move_feedback_test.dart`, `landing_feedback_test.dart`
and `audio_settings_test.dart`, alongside existing shared/legacy stack interaction,
viewport, gesture, study and recovery suites. New cases cover durable confirmation,
AI/online turns, duplicate/recovery suppression, ordered learning replies, tall
mixed-owner stacks, maximum carries, crushing, material mapping, contact timing,
winning cues, independent settings, reduced motion, cancellation and stable bounds.

Validation on Linux with Flutter 3.47.7 / Dart 3.13.5:

- The final full suite passes all **2,003** tests with
  `flutter test --no-pub --concurrency=2`, including shared/legacy stack gestures,
  inspection, draft revision, viewports, learning, recovery and AI playthroughs.
- All 24 focused feedback/settings checks pass. They also cover winning contact
  followed by the win cue, route coverage/disposal, optional audio exceptions,
  paused confirmations and preventing old motion from resuming when re-enabled.
- Strict analysis passes without issues. The default JavaScript release web
  build passes; existing secure-storage Wasm compatibility and Cupertino-font
  warnings remain. This is not Wasm qualification.
- All four Chromium 151.0.7922.34 release-browser journeys pass: Square and Hex
  with touch at 390×844 and mouse at 1366×900. They exercise default-on settings,
  confirmed placements, spread Undo/confirmation, actual contact playback,
  independent mute, animation-off persistence, saved-game restore without replay,
  and playback while motion remains disabled. No page errors were recorded.
- Six approach/contact/spread frames were generated on both shapes, with the
  shared fonts loaded, and representative frames visually reviewed. Browser
  screenshots also retain readable controls and owner markers.
- All six original Vorbis assets decode as mono 44.1 kHz, last 190/240 ms, and
  have zero clipped samples (decoded peaks 0.542–0.687).

Reproduce the focused checks, frame captures and browser qualification with:

```sh
flutter test --no-pub --concurrency=2
flutter test --no-pub test/game/landing_feedback_test.dart test/game/move_feedback_test.dart test/audio_settings_test.dart
flutter test --no-pub test/game/landing_feedback_test.dart --dart-define=STONES_CAPTURE_LANDINGS=true
flutter analyze --no-pub --fatal-infos
flutter build web --no-pub --release
node tools/serve_web.mjs
# In another terminal, with Playwright Chromium installed:
python3 tools/placement_browser_probe.py
```

Generated captures, browser results, audio metrics and source-bound verification
metadata live under `build/qa/landings/`; they are local QA artifacts, not tracked
source or publication evidence. Audio startup remains optional and independent of
gameplay; the browser playback checks wait for asset preloading after a user
gesture. Successful playback promises establish decoding/playback, not subjective
listening quality. Physical Android/iPhone, Safari, native interaction, screen
readers, measured frame performance and hands-on audio/feel acceptance remain
unqualified by this change. No deployment or Android release is included.
