import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

from scripts import generate_music as music


class MusicGenerationTest(unittest.TestCase):
    def test_arrangements_are_deterministic_safe_and_musically_distinct(self):
        # Low-rate full arrangements preserve timing/structure while keeping CI light.
        hashes = set()
        for track in music.score.TRACKS:
            with self.subTest(track=track):
                pcm = music.render(track, rate=2000)
                expected = round(music.score.bars(track) * 4 * 60 / music.score.TEMPO * 2000) + 3000
                self.assertEqual(pcm.shape, (expected, 2))
                self.assertLessEqual(np.max(np.abs(pcm.astype(float))), .721 * 32767)
                self.assertGreater(np.sqrt(np.mean((pcm.astype(float) / 32767) ** 2)), .04)
                self.assertTrue(np.array_equal(pcm[-3000:], pcm[:3000]))
                hashes.add(pcm.tobytes())
        self.assertEqual(len(hashes), 5)
        self.assertTrue(np.array_equal(music.render("menu", 2000), music.render("menu", 2000)))

    def test_asset_validation_rejects_missing_modified_and_stale_outputs(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.assertFalse(music.current(root))
            tracks = {}
            for track in music.score.TRACKS:
                target = root / f"{track}.mp3"
                target.write_bytes(track.encode())
                tracks[track] = {"sha256": music.digest(target)}
            (root / "manifest.json").write_text(json.dumps({"source": music.source_digest(), "tracks": tracks}))
            self.assertTrue(music.current(root))
            with patch.object(music, "source_digest", return_value="changed"):
                self.assertFalse(music.current(root))
            (root / "menu.mp3").write_bytes(b"modified")
            self.assertFalse(music.current(root))
            (root / "menu.mp3").unlink()
            self.assertFalse(music.current(root))

    def test_score_contains_polyphony_sections_and_valid_event_ranges(self):
        for track in music.score.TRACKS:
            events = list(music.score.events(track))
            self.assertGreater(len(events), 400)
            self.assertGreaterEqual(len({event[1] for event in events}), 3)
            for beat, instrument, pitch, duration, gain, pan in events:
                self.assertGreaterEqual(beat, 0)
                self.assertLess(beat, music.score.bars(track) * 4)
                self.assertGreater(duration, 0)
                self.assertGreater(gain, 0)
                self.assertLessEqual(abs(pan), 1)


if __name__ == "__main__":
    unittest.main()
