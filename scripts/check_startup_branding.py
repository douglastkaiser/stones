"""Guard generated launch surfaces and custom web loader after asset generation."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def check(root=ROOT):
    index = (root / 'web/index.html').read_text(encoding='utf-8')
    bootstrap = (root / 'web/flutter_bootstrap.js').read_text(encoding='utf-8')
    for marker in ('id="stones-loader"', 'flutter-first-frame', '15000',
                   'prefers-reduced-motion', 'flutter.theme_mode', 'role="status"',
                   'src="flutter_bootstrap.js"', '$FLUTTER_BASE_HREF'):
        assert marker in index, f'Missing loader contract: {marker}'
    assert "classList.add('loaded')" not in bootstrap
    res = root / 'android/app/src/main/res'
    adaptive = ET.parse(res / 'mipmap-anydpi-v26/ic_launcher.xml').getroot()
    inset = adaptive.find('foreground/inset')
    assert inset.get('{http://schemas.android.com/apk/res/android}inset') == '0%', 'Adaptive source is already padded'
    for qualifier in ('values', 'values-night', 'values-v31', 'values-night-v31'):
        styles = ET.parse(res / qualifier / 'styles.xml').getroot()
        normal = styles.find("style[@name='NormalTheme']")
        background = normal.find("item[@name='android:windowBackground']")
        assert background.text == '@color/startup_background', qualifier
        if 'v31' in qualifier:
            launch = styles.find("style[@name='LaunchTheme']")
            assert launch.find("item[@name='android:windowBackground']").text == '@color/startup_background'
            expected = '#1B1816' if 'night' in qualifier else '#EDE5D7'
            assert launch.find("item[@name='android:windowSplashScreenBackground']").text == expected
    for qualifier, expected in [('values', '#EDE5D7'), ('values-night', '#1B1816')]:
        colors = ET.parse(res / qualifier / 'startup_colors.xml').getroot()
        assert colors.find("color[@name='startup_background']").text == expected
    print('Generated Android backgrounds and custom web loader preserved')


if __name__ == '__main__':
    check()
