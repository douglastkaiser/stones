# The Common Table — Stones soundtrack

The source of truth is `score.py` plus `scripts/generate_music.py`, both covered
by the repository license. The melodies and procedural instruments are original;
no recorded instruments, soundfonts, third-party samples or borrowed melodies are
used. The sound suggests plucked strings, damped keys, upright bass and brushes;
these are synthesized timbres, not recordings of acoustic instruments.

## Prepare a checkout

Install Python 3.11+ and FFmpeg with `libmp3lame` (`brew install ffmpeg` on macOS,
`sudo apt-get install ffmpeg` on Ubuntu), then:

```sh
python3 -m venv .music-venv
.music-venv/bin/python -m pip install -r music/requirements.txt
.music-venv/bin/python scripts/generate_music.py
.music-venv/bin/python scripts/generate_music.py --check
flutter run
```

On Windows use `.music-venv\Scripts\python.exe` instead. Activate the venv if you
prefer ordinary `python` commands. Run preparation before Flutter tests/builds.
Generated `assets/sounds/music/` is ignored, including its hash manifest. A clean
Flutter checkout needs this preparation; generation errors fail CI before builds.
The shared CI action prepares every job that runs Flutter with bundled assets.

## Compose and render

Edit the motif, Dorian scale, extended chord voicings, section progression or
instrument patterns in `score.py`. Notes use MIDI pitches, durations and positions
use beats, and pan runs from -1 to +1. All arrangements use 84 BPM in 4/4. Hex
layers three-part accents over that meter. The long arrangements contain six
eight-bar sections (137.14 seconds); results use 16 bars (45.71 seconds). Learning
and Court stay gentle even on completion. Results are outcome-neutral.

The renderer adds seeded timing/velocity variation, frequency-dependent harmonic
decay, stereo placement and a small procedural room. Circular mixing wraps note
tails/reflections into the opening. An additional 1.5 seconds of that opening
covers the playback crossfade at each musical loop boundary. MP3 is stereo,
44.1 kHz, 128 kbps; all five assets together are approximately 9.6 MB.

Generation is incremental. `--force` re-renders everything; `--check` fails if a
file is missing, a source changed or an output hash differs. The manifest records
PCM hashes, peaks, RMS, durations and the encoder version. PCM is deterministic
with the same Python/NumPy/platform toolchain; MP3 byte reproducibility additionally
requires the same FFmpeg/libmp3lame version. Cross-platform bit equality is not a
compatibility promise. No synthesis or downloads happen during gameplay.

MusicDirector follows visible page routes. MusicScene supplies gameplay/learning
cues; ordinary pages default to menu. Dialogs and sheets keep the current music.
MusicService runs two voices with cancellable 900 ms equal-power fades, including
loop transitions. Native voices use audioplayers. Browser voices decode the same
MP3s into a shared Web Audio context unlocked directly by trusted input; this
preserves permission when asynchronously changing tracks in Firefox/WebKit.
The browser cache retains at most two decoded arrangements. No live synthesis
happens on either platform. Music remains opt-in and independent of sound effects.
Audible qualification is separate from unit tests.
