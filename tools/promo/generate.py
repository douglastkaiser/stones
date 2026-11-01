"""Generate the static sharing kit. Run from any directory; see README.md."""
import argparse
import io
import tempfile
import json
import re
from pathlib import Path
import shutil
import zipfile
from urllib.parse import urlsplit

from PIL import Image, ImageChops
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

import cairosvg
import qrcode
import qrcode.image.svg

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent
CONFIG = json.loads((SOURCE / 'config.json').read_text())
OUT = ROOT / 'web/share'
ASSETS = OUT / 'assets'
FORMATS = [('banner', 728, 90), ('rectangle', 300, 250),
           ('social', 1200, 630), ('square', 1080, 1080), ('story', 1080, 1920)]


def promotional_config(config):
    """Derive all platform copy and destinations from one Android release state."""
    result = dict(config)
    state = config['android_status']
    if state not in ('testing', 'public'):
        raise ValueError('android_status must be testing or public')
    testing = state == 'testing'
    android = {
        'title': 'Android testing access' if testing else 'Available on Android',
        'action': 'Join Android testing' if testing else 'Get it on Google Play',
        'destination': config['android_enrollment_url'] if testing else config['android_url'],
        'qr_action': 'join Android testing' if testing else 'install on Android',
        'qr_note': 'Links to tester enrollment' if testing else 'Links to Google Play',
        'instructions': (
            'Android is currently offered through testing. Sign in with your Google account '
            'to check eligibility. If you can join, enroll and then open the Play Store listing. '
            'Enrollment is not guaranteed; if unavailable, play on the web.' if testing else
            'Install Stones from its Google Play listing, or play on the web.'),
    }
    result['android'] = android
    result['availability_lines'] = ['Play on web', android['title'], 'Coming soon to iOS']
    result['availability'] = '. '.join(result['availability_lines']) + '.'
    return result


CONFIG = promotional_config(CONFIG)


FONT = TTFont(ROOT / 'assets/fonts/Roboto-Regular.ttf')
GLYPHS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()


def text(x, y, size, value, color):
    # Outline the bundled font so SVG embeds and PNGs match on every host.
    paths = []
    offset = 0
    for char in value:
        glyph = GLYPHS[CMAP[ord(char)]]
        pen = SVGPathPen(GLYPHS)
        glyph.draw(pen)
        paths.append(f'<path transform="translate({offset} 0)" d="{pen.getCommands()}"/>')
        offset += glyph.width
    scale = size / FONT['head'].unitsPerEm
    return (f'<g fill="{color}" transform="translate({x} {y}) scale({scale} {-scale})">'
            + ''.join(paths) + '</g>')


def qr_svg(url):
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,
                       box_size=12, border=4)
    qr.add_data(url)
    qr.make(fit=True)
    stream = io.BytesIO()
    qr.make_image(image_factory=qrcode.image.svg.SvgPathImage).save(stream)
    svg = stream.getvalue().decode()
    # qrcode's optional XML backends differ in empty-element whitespace. Keep
    # both the QR SVG and its embedded story copy stable across environments.
    svg = re.sub(r"\s+/>", "/>", svg)
    svg = re.sub(r'(<svg[^>]*>)', r'\1<rect width="100%" height="100%" fill="white"/>', svg, count=1)
    return svg.encode()


def artwork(kind, width, height, dark):
    bg, fg, accent = ('#1B1816', '#EDE5D7', '#DFA67D') if dark else ('#EDE5D7', '#322B25', '#88401F')
    web, android, ios = CONFIG['availability_lines']
    address = urlsplit(CONFIG['base_url']).netloc.removeprefix('www.') + urlsplit(CONFIG['base_url']).path
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             f'<rect width="{width}" height="{height}" fill="{bg}"/>']
    if kind == 'banner':
        parts += [f'<g transform="translate(12 10) scale(.7)">{mark(fg, accent)}</g>',
                  text(98, 35, 25, 'STONES', fg), text(98, 59, 14, 'Every stack changes the road.', accent),
                  text(400, 33, 15, web, fg), text(400, 54, 12, android, fg),
                  text(400, 74, 12, ios, fg), text(610, 53, 17, 'PLAY', accent)]
    elif kind == 'rectangle':
        parts += [f'<g transform="translate(20 16) scale(.52)">{mark(fg, accent)}</g>',
                  text(85, 53, 27, 'STONES', fg), text(22, 108, 18, 'Every stack changes', fg),
                  text(22, 134, 18, 'the road.', fg), text(22, 169, 14, web, accent),
                  text(22, 192, 12, android, fg), text(22, 212, 12, ios, fg),
                  text(22, 237, 12, 'Build roads. Block paths.', accent)]
    else:
        margin = 64
        parts += [f'<g transform="translate({margin} 52) scale(1.1)">{mark(fg, accent)}</g>',
                  text(210, 128, 62, 'STONES', fg)]
        y = 240
        parts += [text(margin, y, 52, 'Every stack changes', fg), text(margin, y + 68, 52, 'the road.', fg)]
        # Abstract stacked-stone motif; no simulated gameplay claim.
        for i, length in enumerate([200, 300, 400]):
            parts.append(f'<rect x="{width - margin - length}" y="{370 + i * 45}" width="{length}" height="28" rx="4" fill="{accent if i == 1 else fg}"/>')
        footer = 535 if kind == 'social' else 700
        parts += [text(margin, footer, 28, f'{web} · {android}', fg),
                  text(margin, footer + 40, 25, ios, accent)]
        if kind == 'story':
            # Embed the same verified QR source with its white quiet zone.
            import base64
            data = base64.b64encode((ASSETS / 'qr-web.svg').read_bytes()).decode()
            parts += ['<rect x="274" y="994" width="532" height="532" rx="12" fill="white"/>',
                      f'<image x="290" y="1010" width="500" height="500" href="data:image/svg+xml;base64,{data}"/>',
                      text(290, 1590, 30, 'Scan to play on the web', fg),
                      text(64, 1790, 24, address, accent)]
        else:
            parts += [text(margin, 612 if kind == 'social' else 960, 24, address, accent)]
    return ''.join(parts) + '</svg>'


def mark(fg, accent):
    return (f'<rect x="32" y="16" width="36" height="16" fill="{fg}"/>'
            f'<rect x="24" y="40" width="52" height="16" fill="{accent}"/>'
            f'<rect x="16" y="64" width="68" height="16" fill="{fg}"/>')


def generate(output=OUT, config=CONFIG):
    global OUT, ASSETS, CONFIG
    OUT, ASSETS, CONFIG = output, output / 'assets', config
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name, url in [('web', CONFIG['base_url']), ('android', CONFIG['android']['destination'])]:
        svg = qr_svg(url)
        (ASSETS / f'qr-{name}.svg').write_bytes(svg)
        cairosvg.svg2png(bytestring=svg, background_color='white', output_width=984,
                        output_height=984, write_to=str(ASSETS / f'qr-{name}.png'))
    items = []
    for kind, w, h in FORMATS:
        for theme in ['light', 'dark']:
            name = f'stones-{kind}-{theme}'
            svg = artwork(kind, w, h, theme == 'dark')
            (ASSETS / f'{name}.svg').write_text(svg)
            cairosvg.svg2png(bytestring=svg.encode(), write_to=str(ASSETS / f'{name}.png'))
            items.append(dict(name=name, title=f'{kind.title()} · {theme}', width=w, height=h,
                              svg=kind in ['banner', 'rectangle'], destination=CONFIG['base_url']))
    for name, target in [('web', CONFIG['base_url']), ('android', CONFIG['android']['destination'])]:
        items.append(dict(name=f'qr-{name}', title=f'QR · {name}', width=984, height=984,
                          svg=True, destination=target))
    manifest = dict(CONFIG, items=items)
    (OUT / 'kit.json').write_text(json.dumps(manifest, indent=2) + '\n')
    page = (SOURCE / 'page.html').read_text().replace('<!-- KIT_CONFIG -->',
            json.dumps(manifest).replace('<', '\\u003c'))
    page = page.replace('https://www.douglastkaiser.com/stones/', CONFIG['base_url'])
    (OUT / 'index.html').write_text(page)
    for name in ['kit.js', 'kit.css']:
        shutil.copyfile(SOURCE / name, OUT / name)
    for name in ['Roboto-Regular.ttf', 'Lora-Regular.ttf']:
        shutil.copyfile(ROOT / 'assets/fonts' / name, ASSETS / name)
    for name in ['Roboto-OFL.txt', 'Lora-OFL.txt']:
        shutil.copyfile(ROOT / 'assets/fonts' / name, ASSETS / name)
    (ASSETS / 'USAGE.txt').write_text('Stones promotional kit\n\n' + CONFIG['availability'] + '\n\n' +
        CONFIG['android']['instructions'] + '\n\nYou may copy, host, and embed these graphics to promote Stones. '
        'Preserve proportions, readable text, and QR quiet zones. Do not imply endorsement or App Store availability. '
        'Banners suit websites; social suits link previews; square suits feeds; story suits vertical posts and posters. '
        'Android QR: ' + CONFIG['android']['qr_note'] + '.\n\n' + CONFIG['base_url'] + '\n')
    with zipfile.ZipFile(OUT / 'stones-promo-kit.zip', 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(ASSETS.iterdir()):
            info = zipfile.ZipInfo('stones-promo-kit/' + path.name, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(info, path.read_bytes())
    print(f'Generated {len(items)} promotional graphics in {OUT}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Fail on stale committed kit files')
    args = parser.parse_args()
    if args.check:
        committed = OUT
        with tempfile.TemporaryDirectory() as temp:
            generated = Path(temp) / 'share'
            generate(generated)
            actual = {p.relative_to(committed): p.read_bytes() for p in committed.rglob('*') if p.is_file()}
            expected = {p.relative_to(generated): p.read_bytes() for p in generated.rglob('*') if p.is_file()}
            stale = []
            for path in actual.keys() | expected.keys():
                if actual.get(path) == expected.get(path):
                    continue
                if path.suffix == '.zip':
                    # verify.py validates the committed archive against its own assets.
                    continue
                if path.suffix == '.png' and path in actual and path in expected:
                    old = Image.open(io.BytesIO(actual[path])).convert('RGBA')
                    new = Image.open(io.BytesIO(expected[path])).convert('RGBA')
                    # Ignore PNG compression differences; rendered pixels must match.
                    if old.size == new.size and not any(high for _, high in ImageChops.difference(old, new).getextrema()):
                        continue
                stale.append(str(path))
            stale.sort()
            if stale:
                raise SystemExit('Stale kit; run tools/promo/generate.py: ' + ', '.join(stale))
        print('PASS: committed kit matches sources')
    else:
        generate()
