# Bundle Size Analysis Report - Stones

**Date:** 2026-01-07
**Analyzed by:** Claude Code

---

## Executive Summary

This analysis identifies bundle size optimization opportunities for both web (JS/CSS) and mobile (APK/IPA) builds. Key findings:

1. **Audio files (WAV)**: 153KB uncompressed - potential 90% reduction with MP3/OGG
2. **Web icons oversized**: 1024x1024 PNGs served as 192/512px icons - 75% reduction possible
3. **Heavy dependencies**: Firebase, mobile_scanner, qr_flutter add significant bundle weight
4. **No code-splitting**: Entire app loads as monolithic bundle
5. **Google Fonts**: Network-loaded fonts block rendering

**Estimated Total Savings: 40-60% reduction in initial bundle size**

---

## Asset Size Analysis

### Current Asset Breakdown

| Category | Size | Files | Notes |
|----------|------|-------|-------|
| Audio (WAV) | 153KB | 12 files | Uncompressed 16-bit PCM at 44.1kHz |
| App Icon | 8.5KB | 1 file | 1024x1024 PNG (appropriate) |
| Splash | 0.5KB | 1 file | branding.png |
| Web Icons | 34KB | 4 files | All 1024x1024 (wrong!) |
| Favicon | 8.5KB | 1 file | 1024x1024 (oversized) |
| **Total Assets** | **~205KB** | **19 files** | |

### Issue #1: Uncompressed WAV Audio Files (HIGH IMPACT)

**Location:** `assets/sounds/`
**Current Size:** 153KB total
**Potential Size:** ~15KB (with MP3/OGG compression)
**Savings:** ~138KB (90% reduction)

**Problem:** All audio files are uncompressed WAV (16-bit PCM, 44.1kHz mono):
```
win.wav                  52KB  (largest - victory fanfare)
stack_move_marble.wav    16KB
stack_move_carved.wav    16KB
stack_move.wav           16KB
illegal_move.wav         13KB
wall_flatten.wav          9KB
piece_place_*.wav         4.5KB each (6 files)
achievement_unlock.wav    4.5KB
```

**Recommendation:**
1. Convert to OGG Vorbis (best for web) or MP3 (universal support)
2. Use 22.05kHz sample rate (sufficient for UI sounds)
3. Use quality level 3-5 (VBR) for small file sizes

**Conversion command:**
```bash
for f in assets/sounds/*.wav; do
  ffmpeg -i "$f" -c:a libvorbis -q:a 4 -ar 22050 "${f%.wav}.ogg"
done
```

### Issue #2: Oversized Web Icons (HIGH IMPACT)

**Location:** `web/icons/` and `web/favicon.png`
**Current Size:** 42.5KB (4 icons + favicon)
**Potential Size:** ~10KB
**Savings:** ~32KB (75% reduction)

**Problem:** All icon files are 1024x1024 regardless of declared size:
```
Icon-192.png          8.5KB  (declares 192x192, is 1024x1024!)
Icon-512.png          8.5KB  (declares 512x512, is 1024x1024!)
Icon-maskable-192.png 8.5KB  (declares 192x192, is 1024x1024!)
Icon-maskable-512.png 8.5KB  (declares 512x512, is 1024x1024!)
favicon.png           8.5KB  (should be 32x32 or 64x64)
```

**Recommendation:**
1. Resize icons to their declared sizes
2. Use PNG optimization (pngquant, oxipng)
3. Consider WebP for modern browsers

**Conversion commands:**
```bash
# Resize to correct dimensions
convert assets/icon/app_icon.png -resize 192x192 web/icons/Icon-192.png
convert assets/icon/app_icon.png -resize 512x512 web/icons/Icon-512.png
convert assets/icon/app_icon.png -resize 192x192 web/icons/Icon-maskable-192.png
convert assets/icon/app_icon.png -resize 512x512 web/icons/Icon-maskable-512.png
convert assets/icon/app_icon.png -resize 32x32 web/favicon.png

# Optimize PNGs
pngquant --force --quality=80-90 web/icons/*.png web/favicon.png
```

---

## Dependency Size Analysis

### Heavy Dependencies (Estimated Impact)

| Package | Estimated Size | Used In | Notes |
|---------|---------------|---------|-------|
| `firebase_core` + `cloud_firestore` + `firebase_auth` | ~500-800KB | Online play | Heavy SDK, consider lazy loading |
| `mobile_scanner` | ~300-500KB | QR scanning | Camera + ML library |
| `qr_flutter` | ~50-100KB | QR generation | Lighter than scanner |
| `google_fonts` | ~20KB + font files | App-wide | Network latency impact |
| `audioplayers` | ~100-200KB | Sound effects | Platform-specific audio |
| `games_services` | ~100-200KB | Achievements | Google Play Games SDK |

### Issue #3: Firebase Bundle Bloat (HIGH IMPACT)

**Location:** `lib/providers/online_game_provider.dart`, `lib/main.dart`
**Current Impact:** ~500-800KB in final bundle
**Potential Savings:** 300-500KB deferred

**Problem:** Firebase SDK (Firestore, Auth) loads eagerly even when user doesn't use online features.

**Recommendation - Deferred Loading:**
```dart
// lib/services/firebase_loader.dart
import 'package:firebase_core/firebase_core.dart' deferred as firebase;
import 'package:cloud_firestore/cloud_firestore.dart' deferred as firestore;

Future<void> initializeFirebase() async {
  await firebase.loadLibrary();
  await firestore.loadLibrary();
  await firebase.Firebase.initializeApp(...);
}
```

### Issue #4: Mobile Scanner Only Used in Online Lobby (MEDIUM IMPACT)

**Location:** `lib/screens/online_lobby_screen.dart:5`
**Current Impact:** ~300-500KB always loaded
**Potential Savings:** Entire package deferred until needed

**Problem:** `mobile_scanner` and `qr_flutter` are only used for game code sharing, but loaded in main bundle.

**Recommendation - Deferred Import:**
```dart
// online_lobby_screen.dart
import 'package:mobile_scanner/mobile_scanner.dart' deferred as scanner;
import 'package:qr_flutter/qr_flutter.dart' deferred as qr;

// In widget that needs QR:
Future<void> _showQRScanner() async {
  await scanner.loadLibrary();
  // Now use scanner.MobileScanner(...)
}
```

### Issue #5: Google Fonts Network Dependency (MEDIUM IMPACT)

**Location:** `lib/main.dart:62,70`
**Current Impact:** Render-blocking font fetch + ~50-200KB per font weight

**Problem:** `GoogleFonts.loraTextTheme()` fetches fonts from Google's CDN at runtime, blocking initial render.

**Recommendation Options:**

**Option A - Bundle Font Subset (Preferred):**
```bash
# Download only Latin subset of Lora
# Add to pubspec.yaml:
flutter:
  fonts:
    - family: Lora
      fonts:
        - asset: fonts/Lora-Regular.ttf
        - asset: fonts/Lora-Bold.ttf
          weight: 700
```

```dart
// main.dart - Use bundled font
theme: ThemeData(
  fontFamily: 'Lora',
  // ...
)
```

**Option B - Use System Fonts:**
```dart
// Use platform fonts for faster LCP
fontFamily: 'Georgia, serif', // Similar to Lora
```

---

## Web-Specific Optimizations

### Issue #6: No Code-Splitting (HIGH IMPACT)

**Current State:** Entire app (~2-4MB JS) loads as single `main.dart.js`
**Potential Savings:** 40-60% initial bundle reduction

**Problem:** Flutter web doesn't support automatic code-splitting, but deferred imports can help.

**Recommendation - Manual Deferred Loading:**

```dart
// Defer heavy screens
import 'screens/online_lobby_screen.dart' deferred as online_lobby;
import 'screens/achievements_screen.dart' deferred as achievements;
import 'screens/settings_screen.dart' deferred as settings;

// Load when navigating
void _openOnlineLobby() async {
  showLoading();
  await online_lobby.loadLibrary();
  Navigator.push(context,
    MaterialPageRoute(builder: (_) => online_lobby.OnlineLobbyScreen())
  );
}
```

### Issue #7: Web Bundle Compression

**Recommendation:** Ensure server sends gzip/brotli compressed assets:

```nginx
# nginx.conf
gzip on;
gzip_types text/javascript application/javascript application/wasm;
gzip_min_size 1000;

# For even better compression
brotli on;
brotli_types text/javascript application/javascript application/wasm;
```

Typical compression ratios:
- `main.dart.js`: 4MB → ~800KB gzipped → ~600KB brotli
- WASM files: Similar 70-80% reduction

### Current Web Optimizations (Already Implemented)

These optimizations are already in `web/index.html`:
- Preconnect hints for fonts.googleapis.com, gstatic.com, firebasestorage.googleapis.com
- Deferred Firebase Analytics loading with `requestIdleCallback`
- Fade transition for loading indicator (prevents CLS)

---

## Mobile-Specific Optimizations (APK/IPA)

### Issue #8: APK Split by ABI

**Current State:** Single universal APK
**Potential Savings:** 30-40% per ABI split

**Recommendation:**
```yaml
# android/app/build.gradle
android {
    splits {
        abi {
            enable true
            reset()
            include 'armeabi-v7a', 'arm64-v8a', 'x86_64'
            universalApk false
        }
    }
}
```

Build command:
```bash
flutter build apk --split-per-abi
```

### Issue #9: Android App Bundle (Preferred)

**Recommendation:** Use AAB instead of APK for Play Store:
```bash
flutter build appbundle --release
```

Benefits:
- Google Play delivers optimized APK per device
- Automatic ABI splitting
- Resource optimization
- ~20-40% smaller downloads

### Issue #10: ProGuard/R8 Code Shrinking

**Location:** `android/app/build.gradle`

Ensure R8 is enabled:
```gradle
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

---

## Dart Code Optimizations

### Issue #11: Large Widget Files

**Top Files by Line Count:**
| File | Lines | Optimization Opportunity |
|------|-------|-------------------------|
| `procedural_painters.dart` | 2,627 | Extract to separate file, consider caching painted images |
| `main_menu_screen.dart` | 1,308 | Split into smaller widgets |
| `online_lobby_screen.dart` | 1,296 | Defer loading entirely |
| `scenario.dart` | 962 | Contains 50+ predefined scenarios - could load from JSON |

### Issue #12: Procedural Textures Recreated

**Location:** `lib/widgets/procedural_painters.dart`
**Impact:** Memory + CPU waste

**Problem:** Complex procedural textures are repainted on every frame.

**Recommendation:** Cache to `ui.Image`:
```dart
class WoodTexturePainter extends CustomPainter {
  static final Map<int, ui.Image> _cache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final key = size.hashCode;
    if (_cache.containsKey(key)) {
      canvas.drawImage(_cache[key]!, Offset.zero, Paint());
      return;
    }
    // Generate and cache texture...
  }
}
```

---

## Implementation Priority

### Immediate (1-2 hours)

| Action | File | Estimated Savings |
|--------|------|-------------------|
| Resize web icons to declared sizes | `web/icons/` | ~32KB |
| Convert WAV to OGG/MP3 | `assets/sounds/` | ~138KB |

### Short-term (1-2 days)

| Action | File | Estimated Savings |
|--------|------|-------------------|
| Bundle Lora font subset | `lib/main.dart`, `pubspec.yaml` | 200-500KB (removes network dep) |
| Defer Firebase loading | `lib/main.dart` | 300-500KB initial |
| Enable APK split by ABI | `android/app/build.gradle` | 30-40% per device |

### Medium-term (3-5 days)

| Action | File | Estimated Savings |
|--------|------|-------------------|
| Defer online_lobby_screen | `lib/screens/` | 300-500KB (scanner+qr) |
| Cache procedural textures | `lib/widgets/procedural_painters.dart` | Memory reduction |
| Extract scenarios to JSON | `lib/models/scenario.dart` | Tree-shaking opportunity |

---

## Estimated Final Bundle Sizes

### Web Build

| Component | Current (Est.) | After Optimization |
|-----------|----------------|-------------------|
| main.dart.js (gzipped) | ~800KB | ~500KB |
| Assets (sounds) | 153KB | ~15KB |
| Web icons | 42KB | ~10KB |
| **Total Initial Load** | **~1MB** | **~525KB** |

### Android APK

| Component | Current (Est.) | After Optimization |
|-----------|----------------|-------------------|
| Flutter engine (arm64) | ~6MB | ~6MB (fixed) |
| Dart code (compiled) | ~3MB | ~2MB (with tree-shaking) |
| Assets | 205KB | ~30KB |
| Native libraries | ~2MB | ~2MB (with ABI split) |
| **Total APK (single ABI)** | **~15MB** | **~10MB** |

---

## Verification Commands

After implementing changes:

```bash
# Web bundle analysis
flutter build web --release
du -sh build/web/*.js
gzip -k build/web/main.dart.js && ls -la build/web/main.dart.js*

# APK size analysis
flutter build apk --release --analyze-size
flutter build apk --release --split-per-abi
ls -la build/app/outputs/flutter-apk/*.apk

# Asset verification
find build/web -name "*.png" -exec identify {} \;
find build/web -name "*.ogg" -o -name "*.mp3" | xargs du -h
```

---

## Conclusion

The codebase has several opportunities for significant bundle size reduction:

1. **Quick wins (170KB savings):** Resize web icons, compress audio files
2. **Medium effort (500KB+ savings):** Bundle fonts, defer Firebase, ABI splitting
3. **Larger refactors (ongoing):** Deferred screen loading, texture caching

The most impactful single change is **converting WAV files to OGG** - a 90% reduction in audio asset size with minimal effort.

For web specifically, **deferring Firebase and mobile_scanner** would significantly reduce initial bundle size since most users don't immediately need online features.
