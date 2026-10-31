"""Stones: The Common Table. Original score, expressed in beats and MIDI notes.

No samples or borrowed melodies. D Dorian, 84 BPM, 4/4 throughout. Each long
arrangement has six eight-bar sections: A, B, A', C, B', A''. Hex's three-part
accents float over the same meter. Edit this file, then run the music renderer.
"""

TEMPO = 84
SEED = 73129
SAMPLE_RATE = 44100
TRACKS = ("menu", "square", "hex", "learning", "results")
SECTIONS = ("A", "B", "A", "C", "B", "A")

# (beat, scale degree, length) in a four-bar phrase. This is the shared motif.
MOTIF = (
    (0.5, 0, .75), (1.5, 2, .5), (2.5, 4, 1.25),
    (4.5, 5, .5), (5.5, 4, .75), (7, 2, .75),
    (8.5, 1, .75), (10, 3, .5), (11, 2, 1),
    (12.5, 0, 2.5),
)
SCALE = (62, 64, 65, 67, 69, 71, 72)  # D E F G A B C

# Root plus close upper voicings: minor 9ths, major 7ths, 6/9s and suspensions.
HARMONY = {
    "A": ((38, (53, 57, 60, 64)), (43, (53, 57, 59, 64)),
          (48, (52, 55, 59, 62)), (45, (55, 59, 62, 64)),
          (38, (53, 57, 60, 64)), (41, (52, 57, 60, 67)),
          (43, (53, 57, 59, 64)), (45, (55, 59, 62, 64))),
    "B": ((41, (52, 57, 60, 67)), (48, (52, 55, 59, 62)),
          (43, (53, 57, 59, 64)), (38, (53, 57, 60, 64)),
          (40, (55, 59, 62, 66)), (45, (55, 59, 62, 64)),
          (43, (53, 57, 59, 64)), (45, (55, 59, 62, 64))),
    "C": ((47, (54, 57, 62, 64)), (43, (53, 57, 59, 64)),
          (38, (53, 57, 60, 64)), (45, (55, 59, 62, 64)),
          (41, (52, 57, 60, 67)), (48, (52, 55, 59, 62)),
          (43, (53, 57, 59, 64)), (45, (55, 59, 62, 64))),
}


def degree(value):
    octave, index = divmod(value, 7)
    return SCALE[index] + 12 * octave


def bars(track):
    return 16 if track == "results" else 48


def events(track):
    """Yield (beat, instrument, MIDI pitch, duration in beats, gain, pan)."""
    if track not in TRACKS:
        raise ValueError(f"Unknown arrangement: {track}")
    learning = track == "learning"
    hexagonal = track == "hex"
    for bar in range(bars(track)):
        section = bar // 8
        form = SECTIONS[section] if track != "results" else "A"
        root, chord = HARMONY[form][bar % 8]
        if track == "results" and bar % 8 in (6, 7):
            root, chord = 38, (53, 57, 59, 64)  # Land gently on D minor 6/9.
        start = bar * 4
        # Breathing room in C, more conversation in the final two sections.
        density = .72 if learning else (.8 if form == "C" else 1)
        for i, note in enumerate(chord):
            yield start + .02 * i, "keys", note, 3.5, .12 * density, -.22
        pattern = (0, 2/3, 4/3, 2, 8/3, 10/3) if hexagonal else (.0, .75, 1.5, 2.5, 3.25)
        if track == "menu":
            pattern = (0, 1.5, 2.75, 3.5)
        if learning:
            pattern = (0, 1.5, 3)
        for i, offset in enumerate(pattern):
            note = chord[(i + bar) % len(chord)] + (12 if i % 3 == 1 else 0)
            yield start + offset, "string", note, 1.25, .13 * density, .35
        for offset, pitch, gain in ((0, root, .28), (2.5, root + 7, .18), (3.5, root + 12, .11)):
            if not learning or offset == 0:
                yield start + offset, "bass", pitch, 1.3, gain, -.05
        if not learning or section in (2, 4, 5):
            for offset in (0, 2):
                yield start + offset, "kick", 36, .3, .13 * density, 0
            for offset in (1, 3):
                yield start + offset, "brush", 0, .45, .10 * density, -.3
            for i in range(8):
                yield start + i * .5 + (.06 if i % 2 else 0), "shaker", 0, .16, .025 * density, .5
        # Small answering phrases, absent from the opening to let the motif land.
        if section >= 1 and bar % 4 in (1, 3) and not learning:
            for i, offset in enumerate((2.75, 3.25, 3.75)):
                yield start + offset, "keys", chord[(bar + i) % 4] + 12, .5, .09, -.4
        if bar % 4 == 0:
            phrase = bar // 4
            for offset, step, length in MOTIF:
                # B answers above the theme; C turns its contour upside down.
                transformed = (step + 2) if form == "B" else (4 - step if form == "C" else step)
                if phrase % 2:
                    transformed += 7 if track == "hex" else 0
                instrument = "string" if track in ("menu", "hex") else "keys"
                yield start + offset, instrument, degree(transformed), length, .25 if not learning else .18, .12
            # A final varied reply instead of mechanically repeating every phrase.
            if section >= 2:
                yield start + 14, "string", degree(1), .5, .12, -.35
                yield start + 14.75, "string", degree(0), .9, .10, -.35
