from pathlib import Path
import struct
import tempfile
import unittest
import zlib

from scripts.check_startup_branding import check, ROOT
from scripts.generate_branding import asset_matches


def pixels(name):
    data = (ROOT / name).read_bytes()
    width, height = struct.unpack('!2I', data[16:24])
    offset = 8
    compressed = b''
    while offset < len(data):
        size = struct.unpack('!I', data[offset:offset+4])[0]
        if data[offset+4:offset+8] == b'IDAT':
            compressed += data[offset+8:offset+8+size]
        offset += size + 12
    raw = zlib.decompress(compressed)
    for y in range(height):
        row = raw[y*(1+4*width):(y+1)*(1+4*width)]
        assert row[0] == 0  # Canonical generator emits unfiltered RGBA rows.
        for x in range(width):
            yield x, y, width, row[1+x*4:5+x*4]


class StartupBrandingTests(unittest.TestCase):
    def test_windows_checkout_line_endings_do_not_count_as_geometry_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'stones_mark_geometry.dart'
            source = (ROOT / 'lib/widgets/stones_mark_geometry.dart').read_text(encoding='utf-8')
            path.write_bytes(source.replace('\n', '\r\n').encode('utf-8'))
            self.assertTrue(asset_matches(path, source.encode('utf-8')))
            path.write_bytes(source.replace('32, 16, 36, 16', '32, 16, 35, 16').encode('utf-8'))
            self.assertFalse(asset_matches(path, source.encode('utf-8')))

    def test_generation_preserves_loader_and_native_window_backgrounds(self):
        check()

    def test_transparent_adaptive_and_android12_marks_fit_circular_safe_area(self):
        for name, diameter in [('assets/icon/adaptive_foreground.png', 66/108),
                               ('assets/splash/android12.png', 2/3),
                               ('assets/splash/android12_dark.png', 2/3)]:
            visible = 0
            for x, y, size, rgba in pixels(name):
                if rgba[3]:
                    visible += 1
                    radius = ((x+.5-size/2)**2+(y+.5-size/2)**2)**.5
                    self.assertLessEqual(radius, size*diameter/2+1, name)
            self.assertGreater(visible, 0)

    def test_pre12_splash_has_no_baked_background(self):
        for name in ['assets/splash/mark.png', 'assets/splash/mark_dark.png']:
            self.assertEqual(next(pixels(name))[3][3], 0)


if __name__ == '__main__':
    unittest.main()
