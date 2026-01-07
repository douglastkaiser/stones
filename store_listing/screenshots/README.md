# Screenshots for Play Store Listing

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
