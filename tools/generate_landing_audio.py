"""Rebuild original, deterministic contact sounds (Python stdlib + ffmpeg)."""

import math
from pathlib import Path
import random
import struct
import subprocess
import tempfile
import wave


def synthesize(material, heavy):
    rate = 44100
    rng = random.Random(84 + material)
    modes = [(430, 870, 1320), (920, 1870, 3180), (1480, 2970, 4230)][material]
    duration = .24 if heavy else .19
    samples = []
    previous_noise = 0
    for i in range(round(rate * duration)):
        t = i / rate
        pitch = .86 if heavy else 1
        attack = min(1, t / .0015)
        noise = rng.uniform(-1, 1)
        # A restrained, filtered transient avoids a sharp digital click.
        filtered = .6 * noise + .4 * previous_noise
        previous_noise = noise
        transient = .38 * filtered * math.exp(-t / .006)
        modes_sample = sum(
            (.26 / (j + 1))
            * math.sin(2 * math.pi * frequency * pitch * t)
            * math.exp(-t / (.022 + material * .007 - j * .004))
            for j, frequency in enumerate(modes)
        )
        body = (.32 if heavy else .20) * math.sin(
            2 * math.pi * (135 if heavy else 205) * t
        ) * math.exp(-t / (.038 if heavy else .025))
        # A barely audible settling contact, rather than a separate second hit.
        settle_t = max(0, t - .063)
        settle = .035 * math.sin(2 * math.pi * modes[0] * pitch * settle_t) * math.exp(
            -settle_t / .014
        ) * min(1, settle_t / .002)
        fade = min(1, (duration - t) / .02)
        samples.append((transient + modes_sample + body + settle) * attack * fade)
    peak = max(abs(value) for value in samples)
    scale = (.70 if heavy else .58) / peak
    return rate, b"".join(struct.pack("<h", round(value * scale * 32767)) for value in samples)


def main():
    output = Path(__file__).resolve().parents[1] / "assets" / "sounds"
    with tempfile.TemporaryDirectory() as directory:
        wav_path = Path(directory) / "landing.wav"
        for material, name in enumerate(("wood", "stone", "marble")):
            for heavy in (False, True):
                rate, pcm = synthesize(material, heavy)
                with wave.open(str(wav_path), "wb") as wav:
                    wav.setnchannels(1)
                    wav.setsampwidth(2)
                    wav.setframerate(rate)
                    wav.writeframes(pcm)
                target = output / f"landing_{name}{'_heavy' if heavy else ''}.ogg"
                subprocess.run([
                    "ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
                    "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "5", str(target)
                ], check=True)
                print(target.name)


if __name__ == "__main__":
    main()
