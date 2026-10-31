#!/usr/bin/env python3
"""Deterministic offline synthesis. Only text sources belong in Git.

python3 scripts/generate_music.py          # render missing/stale assets
python3 scripts/generate_music.py --check  # verify source + asset hashes
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import wave

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/sounds/music"
spec = importlib.util.spec_from_file_location("stones_score", ROOT / "music/score.py")
score = importlib.util.module_from_spec(spec)
spec.loader.exec_module(score)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_digest():
    sources = (ROOT / "music/score.py", ROOT / "music/requirements.txt", Path(__file__))
    return hashlib.sha256(b"".join(p.read_bytes() for p in sources)).hexdigest()


def voice(instrument, midi, seconds, rng, rate):
    """Modal plucks and damped keys: acoustic character without recorded samples."""
    length = max(1, int((seconds + 1.2) * rate))
    t = np.arange(length, dtype=np.float64) / rate
    frequency = 440 * 2 ** ((midi - 69) / 12)
    if instrument in ("brush", "shaker"):
        noise = rng.normal(0, 1, length)
        # Moving-average high-pass gives the brush/shaker its soft friction.
        low = np.convolve(noise, np.ones(23) / 23, mode="same")
        signal = noise - low
        decay = .075 if instrument == "shaker" else .14
        result = .16 * signal * np.exp(-t / decay) * (1 - np.exp(-t / .006))
    elif instrument == "kick":
        phase = 2 * np.pi * (48 * t + 3.5 * (1 - np.exp(-t / .025)))
        result = np.sin(phase) * np.exp(-t / .065) * (1 - np.exp(-t / .002))
    else:
        result = np.zeros(length)
        harmonics = 14 if instrument == "string" else (7 if instrument == "keys" else 5)
        for partial in range(1, harmonics + 1):
            if frequency * partial > rate * .45:
                break
            detune = 1 + .00012 * partial * partial if instrument == "keys" else 1
            amplitude = (1 / partial ** (1.5 if instrument == "keys" else 1.25))
            decay = (seconds * .7 + .35) / (1 + partial * .22)
            phase = .12 * partial if instrument != "bass" else 0
            result += amplitude * np.sin(2 * np.pi * frequency * partial * detune * t + phase) * np.exp(-t / decay)
        attack = .014 if instrument == "keys" else .004
        result *= (1 - np.exp(-t / attack))
        # A plucked string's pick and softly damped release.
        if instrument == "string":
            result += rng.normal(0, .04, length) * np.exp(-t / .008)
        result *= np.exp(-np.maximum(t - seconds, 0) / .12)
        result *= .48
    result[-min(length, 256):] *= np.linspace(1, 0, min(length, 256))
    return result


def render(track, rate=score.SAMPLE_RATE):
    beat = 60 / score.TEMPO
    length = round(score.bars(track) * 4 * beat * rate)
    mix = np.zeros((length, 2), dtype=np.float64)
    rng = np.random.default_rng(score.SEED + score.TRACKS.index(track))
    for position, instrument, midi, duration, gain, pan in score.events(track):
        # Bounded deterministic timing/velocity variation, without wandering tempo.
        human = rng.uniform(-.009, .009) if instrument not in ("bass", "kick") else 0
        start = round((position * beat + human) * rate) % length
        signal = voice(instrument, midi, duration * beat, rng, rate)
        gain *= rng.uniform(.94, 1.06)
        stereo = signal[:, None] * np.array([np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)]) * gain
        # Wrap note tails into the opening: the score is a continuous cycle.
        first = min(len(stereo), length - start)
        mix[start:start + first] += stereo[:first]
        if first < len(stereo):
            mix[:len(stereo) - first] += stereo[first:]
    # Small room: opposing early reflections and a restrained diffuse tail.
    dry = mix.copy()
    for delay, gain in ((.047, .09), (.079, .075), (.131, .055), (.223, .035), (.349, .02)):
        mix += np.roll(dry[:, ::-1], round(delay * rate), axis=0) * gain
    mix -= np.mean(mix, axis=0)
    rms = float(np.sqrt(np.mean(mix * mix)))
    mix *= min(.0794 / max(rms, 1e-9), .72 / max(float(np.max(np.abs(mix))), 1e-9))
    if not np.isfinite(mix).all():
        raise ValueError(f"Non-finite audio: {track}")
    # Playback begins its next voice at the musical boundary. This extra opening
    # tail covers decoder padding and the 900 ms crossfade without skipping beats.
    mix = np.concatenate((mix, mix[:round(1.5 * rate)]))
    return np.round(mix * 32767).astype("<i2")


def current(output=OUTPUT):
    try:
        manifest = json.loads((output / "manifest.json").read_text())
        return (manifest["source"] == source_digest()
                and set(manifest["tracks"]) == set(score.TRACKS)
                and all(digest(output / f"{name}.mp3") == data["sha256"]
                        for name, data in manifest["tracks"].items()))
    except (OSError, ValueError, KeyError, TypeError):
        return False


def generate(output=OUTPUT):
    if not shutil.which("ffmpeg"):
        raise SystemExit("Music generation requires FFmpeg (with libmp3lame). See music/README.md.")
    expected_numpy = (ROOT / "music/requirements.txt").read_text().strip().split("==")[1]
    if np.__version__ != expected_numpy:
        raise SystemExit("Install music/requirements.txt in a Python venv before rendering.")
    output.mkdir(parents=True, exist_ok=True)
    manifest = {"source": source_digest(), "numpy": np.__version__,
                "encoder": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                "tracks": {}}
    with tempfile.TemporaryDirectory(prefix="stones-music-") as temp:
        for track in score.TRACKS:
            pcm = render(track)
            wav = Path(temp) / f"{track}.wav"
            with wave.open(str(wav), "wb") as stream:
                stream.setnchannels(2)
                stream.setsampwidth(2)
                stream.setframerate(score.SAMPLE_RATE)
                stream.writeframes(pcm.tobytes())
            target = Path(temp) / f"{track}.mp3"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav),
                            "-map_metadata", "-1", "-c:a", "libmp3lame", "-b:a", "128k",
                            "-fflags", "+bitexact", "-flags:a", "+bitexact", str(target)], check=True)
            shutil.copyfile(target, output / target.name)
            manifest["tracks"][track] = {
                "sha256": digest(target), "seconds": len(pcm) / score.SAMPLE_RATE,
                "pcm_sha256": hashlib.sha256(pcm.tobytes()).hexdigest(),
                "peak": float(np.max(np.abs(pcm.astype(float)))) / 32767,
                "rms": float(np.sqrt(np.mean((pcm.astype(float) / 32767) ** 2))),
            }
            print(f"Rendered {track}: {len(pcm) / score.SAMPLE_RATE:.1f}s", flush=True)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if args.check:
        if not current():
            raise SystemExit("Missing/stale music: run python3 scripts/generate_music.py")
        print("Music assets match their text sources and recorded hashes.")
    elif args.force or not current():
        generate()
    else:
        print("Music assets are current.")


if __name__ == "__main__":
    main()
