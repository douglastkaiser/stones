# Screenshots for Play Store Listing

## Current 1.1.0 assets (October 24, 2026)

Use the six JPEGs in `store_assets/screenshots/phone/` (1080x1920) and the two
JPEGs in each of `tablet_7/` and `tablet_10/` (1920x1080). Paths are relative to
the repository root. The phone sequence uploaded to Console is Square, home,
stack inspection, learning, seat setup, Hex. Tablet order is Square/Hex for
7-inch and Hex/Square for 10-inch.

`phone_poster.html` is the editable caption/frame composition. Serve the repository
root so its relative raw-capture and Roboto/Lora font paths resolve, then render each
`?shot=01_square` through `06_learn` at 1080x1920 with full-page capture.
The source HTML documents its exact asset paths. Never stretch a truncated
viewport screenshot to meet the required size.

These are actual browser UI captures from the verified production artifact of
`3995847`, matching Android 1.1.0 (503). They are not physical Android screenshots
or device acceptance. The application UI is unaltered; captions/framing are
assisted compositions declared as such in Console. Raw tablet captures retain
their separate capture provenance. See [the manifest](../assets_1_1_0.json) for
dimensions and SHA-256 hashes, and [the release record](../../docs/releases/STORE_LISTING_20261024.md)
for verification and submission outcome.

The earlier capture suggestions below are reference material, not the current
uploaded asset inventory.

## Requirements

Google Play Store screenshot specifications:
- **Quantity**: 2-8 images per device type
- **Aspect ratio**: 16:9 or 9:16
- **Minimum dimension**: 320px
- **Maximum dimension**: 3840px
- **Format**: JPEG or 24-bit PNG (no alpha)
- **File size**: Max 8MB per image

## Recommended Screenshots

Capture the following screens to showcase Stones' features:

### 1. Gameplay (Primary)
- Active game on a 5×5 board
- Show a mid-game position with both players' pieces
- Road-building progress visible
- Captures the strategic depth

### 2. Main Menu
- Clean home screen showing game options
- Demonstrates polished UI

### 3. VS Computer
- AI opponent selection screen
- Show difficulty levels (Easy to Expert)

### 4. Online Multiplayer
- Online lobby or room code entry screen
- Highlights multiplayer capability

### 5. Tutorial
- Interactive tutorial in progress
- Shows the game is beginner-friendly

### 6. Puzzles
- Puzzle selection or active puzzle
- Demonstrates single-player content

### 7. Themes (Optional)
- Showcase unlockable board themes
- Visual variety

### 8. Achievements (Optional)
- Achievement screen
- Shows progression system

## How to Capture

### Option A: Web Build
```bash
flutter build web
# Run in Chrome, use DevTools to set device dimensions
# Capture at 1080x1920 (9:16) or 1920x1080 (16:9)
```

### Option B: Android Emulator
```bash
flutter build apk
# Install on emulator with Pixel device profile
# Use emulator screenshot feature (camera icon)
```

### Option C: Physical Device
- Run debug build on Android phone
- Use device screenshot (Power + Volume Down)

## File Naming Convention

```
01_gameplay.png
02_main_menu.png
03_vs_computer.png
04_online_lobby.png
05_tutorial.png
06_puzzles.png
07_themes.png
08_achievements.png
```

## Tips

- Use a clean device state (no notifications)
- Ensure battery/time status bar looks normal
- Capture during an interesting game state
- Good lighting on physical devices
- Consider adding device frame mockups for marketing
