"""Validate generated dimensions, destinations, QR payloads and ZIP contents."""
import json
from html.parser import HTMLParser
from pathlib import Path
import tempfile
import sys
import zipfile

import cairosvg
from PIL import Image
import zxingcpp

ROOT = Path(__file__).resolve().parents[2]
import argparse
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, default=ROOT / 'web', help='Source or actual Flutter build web root')
OUT = parser.parse_args().root / 'share'
kit = json.loads((OUT / 'kit.json').read_text())

class Metadata(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.values = {}
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        if tag == 'meta':
            attrs = dict(attrs)
            self.values[attrs.get('property', attrs.get('name'))] = attrs.get('content')


for page in [OUT / 'index.html', OUT.parent / 'index.html']:
    meta = Metadata(page.read_text()).values
    assert meta['og:image'] == kit['base_url'] + 'share/assets/stones-social-light.png'
    assert meta['og:image:width'] == '1200' and meta['og:image:height'] == '630'
    assert meta['twitter:card'] == 'summary_large_image'

for item in kit['items']:
    with Image.open(OUT / 'assets' / (item['name'] + '.png')) as image:
        assert image.size == (item['width'], item['height']), item['name']
for name, target in [('web', kit['base_url']), ('android', kit['android']['destination'])]:
    for extension in ['png', 'svg']:
        path = OUT / 'assets' / f'qr-{name}.{extension}'
        with tempfile.TemporaryDirectory() as temp:
            if extension == 'svg':
                rendered = Path(temp) / 'qr.png'
                cairosvg.svg2png(url=str(path), background_color='white',
                                output_width=984, output_height=984, write_to=str(rendered))
                path = rendered
            result = zxingcpp.read_barcode(Image.open(path))
            assert result and result.text == target, (path, result)
for theme in ['light', 'dark']:
    result = zxingcpp.read_barcode(Image.open(OUT / 'assets' / f'stones-story-{theme}.png'))
    assert result and result.text == kit['base_url'], theme
with zipfile.ZipFile(OUT / 'stones-promo-kit.zip') as bundle:
    assert bundle.testzip() is None
    assert set(bundle.namelist()) == {'stones-promo-kit/' + p.name for p in (OUT / 'assets').iterdir()}
    for path in (OUT / 'assets').iterdir():
        assert bundle.read('stones-promo-kit/' + path.name) == path.read_bytes()
# Exercise the real publisher against the selected source or release-build root.
sys.path.insert(0, str(ROOT / 'scripts'))
from publish_web import publish
with tempfile.TemporaryDirectory() as temp:
    source = OUT.parent
    for preview in [None, '123']:
        target = Path(temp) / ('preview' if preview else 'production')
        publish(source, target, preview)
        destination = target / 'pr/123' if preview else target
        for path in OUT.rglob('*'):
            if path.is_file():
                assert (destination / 'share' / path.relative_to(OUT)).read_bytes() == path.read_bytes(), path
print('PASS: 12 dimensions, 6 QR payloads, ZIP bytes, production/preview publication')
