# Binary assets in this repository

This project already contains a small set of historical binary assets (icons, splash art, and the original core sounds) that were committed directly to Git before the current cosmetics work. No new binary assets were added in this update; board textures and cosmetic audio now use procedural rendering and existing sounds instead of additional files.

## Existing binary assets
- **Initial icon and splash art** were introduced in commits `8c79f90` (app icon) and `746c4ce` (splash screen) as PNG files under `assets/icon/` and `assets/splash/`.
- **Core sound effects** (`piece_place.wav`, `stack_move.wav`, etc.) were committed in `ddd6423`, with volume adjustments in `02eed02`. These reside in `assets/sounds/`.
- **Branding image fix** (`assets/splash/branding.png`) landed in `a657281`.

## Guidance
- Reuse the existing sounds or generate visuals procedurally instead of checking in new binaries.
- If a future change truly requires another binary asset, document the source, format, and commit in this file to keep the history clear.
