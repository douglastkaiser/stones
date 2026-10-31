# The Common Table: music contract and qualification

Affected feature IDs: **APP-02**, **PREF-06**. Adjacent journeys are startup with
music off, saved audio preferences, local/AI/online Square and Hex, Court,
learning/retry/next lesson, match completion/rematch, review, browser Back/Forward,
dialogs/settings and background/resume. No match mechanics, save formats, effect
assets or preference keys change.

## Behavior and source

The previous app-wide 24-second mono sine-wave WAV is replaced by five related
arrangements of an original Dorian motif: menus, Square, Hex, learning and results.
The acoustic-style palette is synthesized from text, not recorded musicians.
Patterns, counterpoint, harmony and six eight-bar sections provide variation over
137 seconds; outcome-neutral results use 46 seconds. Ordinary setup/account/
collection/history pages use menu music. Court, lessons, puzzles and review use
learning music, including study completion. Live ordinary matches choose by shape
and switch to results on completion. Local, AI and online modes share that mapping.
Legacy Square/Hex and Hex exercises participate in the same music owner.

The page-route director excludes dialogs/sheets and ignores cue changes from
covered pages. A page pop restores its predecessor; replacements and rematches
update the cue without duplicating players. Rebuilds with an unchanged cue do not
restart the track. Two voices crossfade for 900 ms; a 1.5-second circular opening
tail provides overlap at loop boundaries. Platforms that cannot report duration
fall back to restarting at completion. This fallback may have an audible gap.

Music remains opt-in, uses the existing persisted volume and pauses outside the
foreground. Effects remain separately controlled. Failed music/effect loading
cannot prevent navigation or play; subsequent interaction retries failed audio.
Music does not depend on effect initialization. The serial transition queue
invalidates obsolete work during rapid navigation, muting and disposal.
Native playback uses audioplayers. Web playback uses two buffer voices in one
shared Web Audio context, unlocked synchronously by trusted pointer, keyboard or
accessibility activation. The stock web media-element backend lost autoplay
permission on some asynchronous source changes during qualification. The browser
adapter keeps at most two decoded arrangements cached and releases its context
when the audio owner is disposed. In-flight loads cannot delay resource disposal.

See [authoring and build instructions](../music/README.md). Generated MP3s and
their manifest are ignored; all Flutter CI preparation uses the shared music
action. The manifest checks source/output hashes and records PCM metrics and
encoder provenance. Same-toolchain rendering is reproducible; byte equality
between different platforms or encoders is not promised.

## Verification record

2026-10-31, Linux workspace, Flutter 3.47.7 / Dart 3.13.5:

- **91 focused Flutter checks passed in two runs (43 and 48)**, covering service transitions/cancellation,
  failed audio and retry, disposal during loading, lifecycle/mute, pointer-free
  audio activation, page ownership/dialogs/replacements, frozen review, startup
  preferences, shared Square/Hex audio access at enlarged text sizes, match
  layouts/completion, legacy Hex learning/goals and browser Back/Forward history.
- **83 Python checks passed**, including deterministic arrangement rendering,
  wrapped loop tails, distinct arrangements, clipping/RMS bounds, and rejection
  of stale, changed or missing generated assets. A fresh render of all five
  arrangements reproduced the prior PCM and MP3 hashes with this toolchain.
  Full MP3 decoding found finite samples, comparable RMS (~0.0755) and peaks
  below 0.49. The ignored playback files total approximately 9.6 MB (decimal).
- **Strict analysis and the release web build passed.** Music generation,
  manifest verification and workflow YAML parsing passed. All Flutter CI jobs
  prepare music; web CI also runs the real Chromium playback harness.
- **Chromium and WebKit 26.5 (Linux headless) passed seven real playback
  journeys each**: opt-in, Square, a full natural loop, Hex, learning, saved
  preference/fresh interaction, and music with failed effect downloads. These
  journeys also exercise sheets, mute/re-enable and return navigation. The
  harness observes actual decoded audio, context state and gain; it does not
  substitute playback or override autoplay policy.
- The broad Flutter run during implementation reached **1,990 passing checks**
  and two failures: isolated review unexpectedly required app providers, and a
  test compiled against an earlier cached music-scope interface while source
  was changing. Both affected files pass in the final focused rerun. The entire
  broad suite was not repeated against the final snapshot.

Before pushing, the soundtrack was rebased onto `2338b7f` (placement/landing
feedback), preserving its audio provenance and PREF-06 behavior. All **113**
combined music, landing-feedback, settings, startup, match, review, learning and
browser-history checks passed with `--concurrency=2`. Strict analysis, the three
renderer tests, complete music regeneration and manifest verification also passed.

Evidence is generated under `build/qa/music/`, including playback reports,
decoded metrics, logs and a downloadable HTML/MP3 listening bundle. These are
local review artifacts, not versioned sound files or production publication.

**Remaining qualification:** Firefox 153 headless cannot start its audio context
in this workspace, including on a standalone trusted-click oscillator page
outside Stones; its playback check timed out and is not claimed as passed.
Android compilation was attempted but stopped because no Android SDK is installed.
Physical Android/iPhone listening, native interruptions, real screen readers,
subjective full-arrangement listening and final-snapshot full-suite execution
remain unverified. Linux WebKit is not physical iPhone Safari acceptance.
