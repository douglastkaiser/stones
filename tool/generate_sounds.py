#!/usr/bin/env python3
"""Generate synthesized sound effects for Stones app.

Creates simple but pleasant sounds without external dependencies.
Run with: python3 tool/generate_sounds.py
"""

import os
import struct
import math

def main():
    print("Generating sound effects...")
    os.makedirs("assets/sounds", exist_ok=True)

    # Stone placement - soft tap/click
    generate_place_sound("assets/sounds/place.wav")

    # Stack sliding - whoosh
    generate_slide_sound("assets/sounds/slide.wav")

    # Wall flatten - thunk
    generate_flatten_sound("assets/sounds/flatten.wav")

    # Win - pleasant chime
    generate_win_sound("assets/sounds/win.wav")

    print("Sound effects generated successfully!")

def generate_place_sound(path: str):
    """Soft tap sound for placing a stone."""
    sample_rate = 22050
    duration = 0.15
    samples = int(sample_rate * duration)

    data = []
    for i in range(samples):
        t = i / sample_rate
        # Quick attack, fast decay
        env = math.exp(-t * 40) * (1 - math.exp(-t * 500))
        # Low thud with some higher harmonics
        wave = math.sin(2 * math.pi * 150 * t) * 0.6
        wave += math.sin(2 * math.pi * 300 * t) * 0.3
        wave += math.sin(2 * math.pi * 80 * t) * 0.2
        # Add some noise for texture
        noise = (hash(i) % 1000 / 1000 - 0.5) * 0.1
        sample = int((wave * env + noise * env) * 127 + 128)
        data.append(max(0, min(255, sample)))

    save_wav(path, data, sample_rate)
    print(f"  Created: {path}")

def generate_slide_sound(path: str):
    """Whoosh sound for sliding stack."""
    sample_rate = 22050
    duration = 0.25
    samples = int(sample_rate * duration)

    data = []
    for i in range(samples):
        t = i / sample_rate
        # Envelope: rise then fall
        env = math.sin(math.pi * t / duration) ** 0.5 * 0.8
        # Filtered noise (pseudo-whoosh)
        noise = 0
        for freq in [400, 600, 800, 1000, 1200]:
            phase = hash(i * freq) % 1000 / 1000 * 2 * math.pi
            noise += math.sin(2 * math.pi * freq * t + phase) * (1 / freq)
        # Pitch sweep
        sweep = math.sin(2 * math.pi * (200 + t * 400) * t) * 0.3
        sample = int((noise * 3 + sweep) * env * 127 + 128)
        data.append(max(0, min(255, sample)))

    save_wav(path, data, sample_rate)
    print(f"  Created: {path}")

def generate_flatten_sound(path: str):
    """Thunk sound for flattening a wall."""
    sample_rate = 22050
    duration = 0.2
    samples = int(sample_rate * duration)

    data = []
    for i in range(samples):
        t = i / sample_rate
        # Sharp attack, medium decay
        env = math.exp(-t * 25) * (1 - math.exp(-t * 800))
        # Lower thud than place
        wave = math.sin(2 * math.pi * 100 * t) * 0.5
        wave += math.sin(2 * math.pi * 60 * t) * 0.4
        wave += math.sin(2 * math.pi * 200 * t) * 0.2
        # Impact noise
        if t < 0.02:
            noise = (hash(i) % 1000 / 1000 - 0.5) * 0.5
        else:
            noise = 0
        sample = int((wave + noise) * env * 127 + 128)
        data.append(max(0, min(255, sample)))

    save_wav(path, data, sample_rate)
    print(f"  Created: {path}")

def generate_win_sound(path: str):
    """Pleasant chime for winning."""
    sample_rate = 22050
    duration = 1.0
    samples = int(sample_rate * duration)

    # C major arpeggio frequencies (C5, E5, G5, C6)
    notes = [523.25, 659.25, 783.99, 1046.50]
    note_duration = 0.2
    note_gap = 0.15

    data = []
    for i in range(samples):
        t = i / sample_rate
        sample_val = 0

        for idx, freq in enumerate(notes):
            note_start = idx * note_gap
            if t >= note_start:
                note_t = t - note_start
                # Bell-like envelope
                env = math.exp(-note_t * 3) * (1 - math.exp(-note_t * 100))
                # Sine with harmonics for bell tone
                wave = math.sin(2 * math.pi * freq * note_t) * 0.5
                wave += math.sin(2 * math.pi * freq * 2 * note_t) * 0.25
                wave += math.sin(2 * math.pi * freq * 3 * note_t) * 0.1
                sample_val += wave * env * 0.4

        sample = int(sample_val * 127 + 128)
        data.append(max(0, min(255, sample)))

    save_wav(path, data, sample_rate)
    print(f"  Created: {path}")

def save_wav(path: str, data: list, sample_rate: int):
    """Save audio data as WAV file."""
    num_samples = len(data)
    data_size = num_samples
    file_size = 36 + data_size

    wav = bytearray()

    # RIFF header
    wav.extend(b"RIFF")
    wav.extend(struct.pack("<I", file_size))
    wav.extend(b"WAVE")

    # fmt chunk
    wav.extend(b"fmt ")
    wav.extend(struct.pack("<I", 16))  # chunk size
    wav.extend(struct.pack("<H", 1))   # PCM
    wav.extend(struct.pack("<H", 1))   # mono
    wav.extend(struct.pack("<I", sample_rate))
    wav.extend(struct.pack("<I", sample_rate))  # byte rate
    wav.extend(struct.pack("<H", 1))   # block align
    wav.extend(struct.pack("<H", 8))   # bits per sample

    # data chunk
    wav.extend(b"data")
    wav.extend(struct.pack("<I", data_size))
    wav.extend(bytes(data))

    with open(path, "wb") as f:
        f.write(wav)

if __name__ == "__main__":
    main()
