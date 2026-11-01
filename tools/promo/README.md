# Stones promotional kit

Public route: `/stones/share/`. Source templates and editable vector composition
live here; generated static files are committed under `web/share/` so Flutter's
normal web build includes them without generation dependencies in CI.

## Regenerate

Use Python 3.12 or later and the bundled Roboto font. SVG lettering is outlined
from that font to preserve the identity on hosts without installed fonts.

```sh
python3 -m venv /tmp/stones-promo-venv
/tmp/stones-promo-venv/bin/pip install -r tools/promo/requirements.txt
/tmp/stones-promo-venv/bin/python tools/promo/generate.py
/tmp/stones-promo-venv/bin/python tools/promo/generate.py --check
/tmp/stones-promo-venv/bin/python tools/promo/verify.py
/tmp/stones-promo-venv/bin/python -m unittest discover -s tools/promo -p 'test_*.py'
```

Edit `config.json` for destinations, descriptive copy, and `android_status`
(`testing` or `public`). The generator derives every Android label, availability
line, instruction, embed description, and QR destination from that state. Testing
uses enrollment; public uses the Play listing. Review all formats for text fit after changes. Layout and vector sources are
in `generate.py`; the page, styles and interactions have separate editable sources.
Regenerate rather than editing files under `web/share/` directly. Changing the
production base URL also requires updating the app's canonical `stonesPlayUrl`
and main-page metadata, which are existing application sources.

Android QR codes intentionally target tester enrollment, followed by the Play
listing linked on the page. On 2026-11-01 the public listing returned HTTP 404;
this does not establish public Android availability or eligibility for any tester.
Confirm release access before replacing testing language. Keep the informational
iOS line without an App Store badge until there is a release.

PNG downloads are offered for every graphic, and SVG downloads for banners and
QR codes. The ZIP also contains all editable generated SVGs, fonts, font licenses,
and usage instructions. Its entries have fixed timestamps for reproducibility.
The website requires no Flutter, remote fonts, analytics, or embed scripts.

## Browser checks

With Playwright 1.58.2, marked 17.0.1, and Chromium available:

```sh
python3 -m http.server 8765 --directory web
# In another terminal; CHROMIUM_PATH is optional for a Playwright-managed browser:
CHROMIUM_PATH=/usr/bin/chromium node tools/promo/browser_check.cjs
```

`PLAYWRIGHT_MODULE` can identify an existing Playwright module installation.
`MARKED_MODULE` can identify the absolute path to `marked/lib/marked.esm.js`.
The script tests every embed, gallery/downloads, narrow layouts at 100%/200%, copied HTML on a separate
host, rendered Markdown, both release-state controls, copy denial/manual selection, and keyboard focus. Screenshots
are written to `/tmp/stones-share-{desktop,mobile}.png`. `verify.py` checks actual
PNG dimensions, decodes standalone SVG/PNG and both poster QR payloads, verifies
every ZIP entry byte-for-byte, and exercises the existing publisher in production
and PR-preview layouts against the selected source or actual release-build root.

## CI and build verification

The promotional-kit CI job checks for source drift (text/vector bytes and raster
pixels, ignoring PNG compression differences), decodes QR payloads, validates ZIP contents and tests both release states.
The web-build job depends on that job, validates the actual Flutter build's kit,
and runs browser checks against the packaged page. ZIP validation compares its
contents with committed assets, independently of PNG compression differences.

For the built artifact, run `python tools/promo/verify.py --root build/web`.
`about_browser_check.cjs` additionally exercises the real Flutter About screen,
external opening and gallery load at production and preview base paths. Serve
`build/web`, set `PROMO_ORIGIN` to the server origin, and use the same Playwright
and Chromium selectors as the other browser check. It routes bundled CanvasKit
locally and blocks optional external services. Preview checking rewrites only the
HTML base tag, matching Flutter's `--base-href` substitution.

## Implementation qualification — 2026-11-01

- Generated 10 promotional designs plus 2 standalone QR codes. All dimensions,
  6 QR decodes, ZIP contents, social preview metadata, regeneration drift checks
  and both release-state
  regressions pass. Social/square downloads now contain the production web address.
- Linux Chromium: 320, 390 and 1280 pixel layouts at 100%/200%; every download and
  HTML/Markdown snippet; separate-host HTML and rendered Markdown; clipboard
  success and denied/manual fallback; Escape dismissal and keyboard focus pass.
  Public-release configuration updates controls without leftover testing labels.
- Flutter 3.47.7 / Dart 3.13.5 from `/workspace/.tools/flutter`: strict analysis
  passes. The real browser About → external kit journey passes for production
  and PR-preview roots. All 11 targeted sharing-kit/feedback tests pass, including native launch
  success/decline/exception handling and production/preview URL resolution.
- The full Flutter suite completed in 16m52s: 2,018 passed, one failed. The
  failure was `shared_ai_playthrough_test.dart` / “mixed AI difficulties complete
  a legal BoardShape.hex 4-seat match”: it did not finish within 150 moves.
  The isolated test passed on unchanged HEAD
  (`3424ec93c63d71f7cdeeb4c297ad7c8950c0473f`, 1m29s) and on the working-tree
  rerun (1m28s); AI engine/rules/test files are byte-identical between them. This is a broader AI repeatability issue,
  not a claimed green full-suite run. No AI behavior or test expectations were changed.
- The release web build passes. Every kit file survives actual production and
  preview publication byte-for-byte. Existing publication regression tests pass.
- The build emits existing Wasm-incompatible-plugin and Cupertino font warnings;
  the supported dart2js web build succeeds. Required music was generated using
  the normal repository renderer and remains ignored, outside the source diff.

Account-specific Android enrollment cannot be established by an anonymous request:
its URL redirects to Google sign-in. The public listing returned HTTP 404; the
kit therefore conservatively advertises testing with an eligibility explanation
and web fallback. Physical Android launching and printed QR scanning have not
been qualified on a device. No deployment or Play release was performed. The
pre-existing `analysis_options.yaml` change was preserved.

Affected inventory: APP-11, adjacent APP-06 branding and APP-07 About.
