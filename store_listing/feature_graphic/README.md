# Feature Graphic for Play Store

## Current 1.1.0 artwork

`feature_graphic_1_1.svg` is the editable source for the current
`store_assets/feature_graphic.png` (repository-relative), a 1024x500 RGB PNG.
It uses the current wood, ivory and charcoal palette, a Square position based
on the verified gameplay capture, and the line "Every stack changes the road."
This assisted vector composition is declared as created/edited using AI in
Play Console. It is illustrative artwork; the listing's gameplay images are
actual UI captures. See [the manifest](../assets_1_1_0.json) and
[publication record](../../docs/releases/STORE_LISTING_20261024.md).

The template and design notes below predate this revision and are retained
as reference material.

## Specifications

- **Dimensions**: 1024 × 500 px
- **Format**: JPEG or 24-bit PNG (no alpha)
- **File size**: Max 1MB

## Design Concept

### Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                                                                 │
│    ┌─────────────────┐                                          │
│    │                 │                                          │
│    │   Game Board    │         S T O N E S                      │
│    │   (5×5 grid)    │                                          │
│    │   with pieces   │     Build Roads. Block Paths.            │
│    │                 │         Claim Victory.                   │
│    │                 │                                          │
│    └─────────────────┘                                          │
│                                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Elements

1. **Background**
   - Clean gradient (dark blue to blue-gray, or warm wood tones)
   - Subtle texture optional

2. **Game Board** (left-center)
   - 5×5 grid shown at an angle (slight 3D perspective)
   - Mid-game position with:
     - White flat stones forming partial road
     - Black flat stones forming partial road
     - 1-2 standing stones (walls)
     - One capstone visible
   - Board should show strategic tension

3. **Title** (right side)
   - "STONES" in clean, modern typography
   - Large, prominent, easy to read at small sizes
   - White or light color for contrast

4. **Tagline** (below title)
   - "Build Roads. Block Paths. Claim Victory."
   - Smaller, lighter weight font
   - Summarizes gameplay in one line

### Color Palette

Primary colors should match game themes:
- Board: Warm wood tones (#B8860B, #DEB887)
- Light pieces: Cream/white (#FFFEF0, #F5F5DC)
- Dark pieces: Deep brown (#4A3728, #654321)
- Background: Slate/blue-gray (#2F4F4F, #4A5568)

### Typography

- Title: Bold, geometric sans-serif (e.g., Montserrat, Poppins)
- Tagline: Light weight version of same font

## Production Notes

- Keep safe zone: 10% margin from edges (100px horizontal, 50px vertical)
- Test at small size (how it appears in search results)
- Avoid small text that won't be readable
- No screenshots or device frames in feature graphic
- Consider creating dark and light versions

## Included Template

See `feature_graphic_template.svg` for an editable starting point.
