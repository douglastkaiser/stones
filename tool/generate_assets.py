#!/usr/bin/env python3
"""Generate app icon and splash screen assets for Stones app.

Creates simple abstract stone/path design using pure Python (no external deps).
Run with: python3 tool/generate_assets.py
"""

import os
import struct
import zlib
from math import sqrt

def main():
    print("Generating app assets...")

    # Ensure directories exist
    os.makedirs("assets/icon", exist_ok=True)
    os.makedirs("assets/splash", exist_ok=True)
    os.makedirs("assets/sounds", exist_ok=True)

    # Generate icons
    generate_app_icon("assets/icon/app_icon.png", 1024)
    generate_adaptive_foreground("assets/icon/app_icon_foreground.png", 1024)
    generate_splash_logo("assets/splash/splash_logo.png", 512)

    # Create placeholder sound files (empty but valid)
    create_placeholder_sounds()

    print("Assets generated successfully!")

def generate_app_icon(path: str, size: int):
    """Generate main app icon with brown background."""
    pixels = [[0, 0, 0, 255] for _ in range(size * size)]

    # Background: warm brown (#795548)
    bg = (121, 85, 72, 255)
    for i in range(len(pixels)):
        pixels[i] = list(bg)

    # Stone colors
    cream = (245, 235, 220)
    charcoal = (60, 55, 50)

    center = size / 2
    stone_size = size * 0.18
    spacing = size * 0.15

    # Draw stones forming a path
    stones = [
        # Cream stones (path from bottom-left to top-right)
        (center - spacing * 1.5, center + spacing * 1.2, cream, False),
        (center - spacing * 0.3, center + spacing * 0.4, cream, False),
        (center + spacing * 0.9, center - spacing * 0.4, cream, False),
        (center + spacing * 2.0, center - spacing * 1.2, cream, False),
        # Charcoal stones
        (center - spacing * 0.5, center - spacing * 0.8, charcoal, True),
        (center + spacing * 1.3, center + spacing * 0.6, charcoal, False),
    ]

    for x, y, color, standing in stones:
        draw_stone(pixels, size, x, y, stone_size, color, standing)

    save_png(path, pixels, size, size)
    print(f"  Created: {path}")

def generate_adaptive_foreground(path: str, size: int):
    """Generate adaptive icon foreground with transparent background."""
    pixels = [[0, 0, 0, 0] for _ in range(size * size)]

    cream = (245, 235, 220)
    charcoal = (60, 55, 50)

    center = size / 2
    stone_size = size * 0.12
    spacing = size * 0.10

    stones = [
        (center - spacing * 1.0, center + spacing * 0.8, cream, False),
        (center + spacing * 0.2, center + spacing * 0.1, cream, False),
        (center + spacing * 1.3, center - spacing * 0.7, cream, False),
        (center - spacing * 0.3, center - spacing * 0.5, charcoal, True),
        (center + spacing * 0.9, center + spacing * 0.5, charcoal, False),
    ]

    for x, y, color, standing in stones:
        draw_stone(pixels, size, x, y, stone_size, color, standing)

    save_png(path, pixels, size, size)
    print(f"  Created: {path}")

def generate_splash_logo(path: str, size: int):
    """Generate splash screen logo with transparent background."""
    pixels = [[0, 0, 0, 0] for _ in range(size * size)]

    cream = (245, 235, 220)
    charcoal = (60, 55, 50)

    center = size / 2
    stone_size = size * 0.15
    spacing = size * 0.12

    stones = [
        (center - spacing * 0.8, center + spacing * 0.5, cream, False),
        (center + spacing * 0.4, center - spacing * 0.2, cream, False),
        (center - spacing * 0.2, center - spacing * 0.6, charcoal, True),
    ]

    for x, y, color, standing in stones:
        draw_stone(pixels, size, x, y, stone_size, color, standing)

    save_png(path, pixels, size, size)
    print(f"  Created: {path}")

def draw_stone(pixels: list, img_size: int, cx: float, cy: float,
               stone_size: float, color: tuple, standing: bool):
    """Draw a rounded rectangle stone with shadow."""
    width = stone_size
    height = stone_size * 1.4 if standing else stone_size * 0.6
    radius = min(width, height) * 0.25

    # Shadow
    shadow = (40, 30, 25)
    shadow_offset = 4
    for py in range(int(cy - height/2 + shadow_offset), int(cy + height/2 + shadow_offset)):
        for px in range(int(cx - width/2 + shadow_offset), int(cx + width/2 + shadow_offset)):
            if 0 <= px < img_size and 0 <= py < img_size:
                if is_inside_rounded_rect(px, py, cx + shadow_offset, cy + shadow_offset,
                                         width, height, radius):
                    idx = py * img_size + px
                    # Blend shadow
                    old = pixels[idx]
                    if old[3] > 0:  # Has content
                        pixels[idx] = [
                            int(old[0] * 0.7 + shadow[0] * 0.3),
                            int(old[1] * 0.7 + shadow[1] * 0.3),
                            int(old[2] * 0.7 + shadow[2] * 0.3),
                            old[3]
                        ]
                    else:
                        pixels[idx] = [shadow[0], shadow[1], shadow[2], 180]

    # Stone body
    for py in range(int(cy - height/2), int(cy + height/2)):
        for px in range(int(cx - width/2), int(cx + width/2)):
            if 0 <= px < img_size and 0 <= py < img_size:
                if is_inside_rounded_rect(px, py, cx, cy, width, height, radius):
                    idx = py * img_size + px
                    # Gradient for depth
                    dy = (py - (cy - height/2)) / height
                    light = 1.0 - dy * 0.15
                    pixels[idx] = [
                        int(min(255, color[0] * light)),
                        int(min(255, color[1] * light)),
                        int(min(255, color[2] * light)),
                        255
                    ]

    # Border
    border = (int(color[0] * 0.5), int(color[1] * 0.5), int(color[2] * 0.5))
    border_width = 3
    for py in range(int(cy - height/2 - border_width), int(cy + height/2 + border_width)):
        for px in range(int(cx - width/2 - border_width), int(cx + width/2 + border_width)):
            if 0 <= px < img_size and 0 <= py < img_size:
                inside = is_inside_rounded_rect(px, py, cx, cy, width, height, radius)
                inside_inner = is_inside_rounded_rect(px, py, cx, cy,
                                                      width - border_width * 2,
                                                      height - border_width * 2,
                                                      max(0, radius - border_width))
                if inside and not inside_inner:
                    idx = py * img_size + px
                    pixels[idx] = [border[0], border[1], border[2], 255]

def is_inside_rounded_rect(px: float, py: float, cx: float, cy: float,
                           width: float, height: float, radius: float) -> bool:
    """Check if point is inside a rounded rectangle."""
    left = cx - width / 2
    right = cx + width / 2
    top = cy - height / 2
    bottom = cy + height / 2

    # Inside main rect (excluding corners)
    if left + radius <= px <= right - radius and top <= py <= bottom:
        return True
    if left <= px <= right and top + radius <= py <= bottom - radius:
        return True

    # Check corners
    corners = [
        (left + radius, top + radius),
        (right - radius, top + radius),
        (left + radius, bottom - radius),
        (right - radius, bottom - radius),
    ]

    for corner_x, corner_y in corners:
        dx = px - corner_x
        dy = py - corner_y
        if dx * dx + dy * dy <= radius * radius:
            # Verify correct quadrant
            if (px < left + radius or px > right - radius) and \
               (py < top + radius or py > bottom - radius):
                return True

    return False

def save_png(path: str, pixels: list, width: int, height: int):
    """Save pixel data as PNG file."""
    # Prepare raw image data
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0)  # Filter: none
        for x in range(width):
            idx = y * width + x
            raw_data.extend(pixels[idx])

    # Compress
    compressed = zlib.compress(bytes(raw_data), 9)

    # Build PNG
    png_data = bytearray()

    # Signature
    png_data.extend([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

    # IHDR
    ihdr = bytearray()
    ihdr.extend(struct.pack(">I", width))
    ihdr.extend(struct.pack(">I", height))
    ihdr.extend([8, 6, 0, 0, 0])  # 8-bit RGBA
    write_chunk(png_data, b"IHDR", bytes(ihdr))

    # IDAT
    write_chunk(png_data, b"IDAT", compressed)

    # IEND
    write_chunk(png_data, b"IEND", b"")

    with open(path, "wb") as f:
        f.write(png_data)

def write_chunk(output: bytearray, chunk_type: bytes, data: bytes):
    """Write a PNG chunk."""
    output.extend(struct.pack(">I", len(data)))
    output.extend(chunk_type)
    output.extend(data)
    crc = zlib.crc32(chunk_type + data) & 0xFFFFFFFF
    output.extend(struct.pack(">I", crc))

def create_placeholder_sounds():
    """Create minimal valid WAV files as placeholders.

    These are silent 0.1 second mono 8-bit WAV files.
    Real sounds should be sourced from opengameart.org or freesound.org.
    """
    sounds = ["place.wav", "slide.wav", "flatten.wav", "win.wav"]

    for sound in sounds:
        path = f"assets/sounds/{sound}"
        create_silent_wav(path, duration_ms=100)
        print(f"  Created placeholder: {path}")

def create_silent_wav(path: str, duration_ms: int = 100):
    """Create a minimal silent WAV file."""
    sample_rate = 8000
    num_samples = int(sample_rate * duration_ms / 1000)

    # WAV header
    wav = bytearray()

    # RIFF header
    data_size = num_samples
    file_size = 36 + data_size

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
    wav.extend(bytes([128] * num_samples))  # silence (128 for unsigned 8-bit)

    with open(path, "wb") as f:
        f.write(wav)

if __name__ == "__main__":
    main()
