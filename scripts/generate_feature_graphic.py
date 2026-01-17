#!/usr/bin/env python3
"""Generate the feature graphic for the Google Play Store (1024x500)."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

# Colors from the app theme
BACKGROUND_COLOR = (55, 60, 67)  # Dark blue-gray background matching app icon
BOARD_FRAME_INNER = (121, 85, 72)  # 0xFF795548
BOARD_FRAME_OUTER = (93, 64, 55)  # 0xFF5D4037
TITLE_COLOR = (78, 52, 46)  # 0xFF4E342E
LIGHT_PIECE = (245, 240, 230)  # 0xFFF5F0E6
DARK_PIECE = (61, 61, 61)  # 0xFF3D3D3D
LIGHT_PIECE_BORDER = (139, 115, 85)  # 0xFF8B7355
DARK_PIECE_BORDER = (107, 107, 107)  # 0xFF6B6B6B
SUBTITLE_COLOR = (93, 64, 55)  # 0xFF5D4037

# Dimensions
WIDTH = 1024
HEIGHT = 500


def create_feature_graphic():
    """Create the feature graphic with icon, title, and tagline."""
    # Create base image with gradient-like background
    img = Image.new('RGBA', (WIDTH, HEIGHT), (55, 60, 67, 255))
    draw = ImageDraw.Draw(img)

    # Add subtle gradient effect (vertical)
    for y in range(HEIGHT):
        # Gradient from darker at top to slightly lighter at bottom
        factor = y / HEIGHT
        r = int(52 + factor * 8)
        g = int(58 + factor * 8)
        b = int(68 + factor * 6)
        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b, 255))

    # Load fonts
    try:
        title_font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 72)
        subtitle_font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 28)
    except:
        # Fallback to default
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()

    # Load the app icon
    icon_path = os.path.join(os.path.dirname(__file__), '..', 'store_assets', 'app_icon_512.png')
    if os.path.exists(icon_path):
        icon = Image.open(icon_path).convert('RGBA')
        # Scale icon to fit nicely (about 300px tall)
        icon_size = 300
        icon = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)

        # Position icon on the left side
        icon_x = 80
        icon_y = (HEIGHT - icon_size) // 2

        # Add a subtle shadow behind the icon
        shadow = Image.new('RGBA', (icon_size + 30, icon_size + 30), (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle([15, 15, icon_size + 15, icon_size + 15], radius=20, fill=(0, 0, 0, 60))
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=12))
        img.paste(shadow, (icon_x - 15, icon_y - 10), shadow)

        # Paste the icon
        img.paste(icon, (icon_x, icon_y), icon)

    # Draw title "STONES"
    title_text = "STONES"
    text_x = 420
    title_y = HEIGHT // 2 - 50

    # Draw title with slight shadow for depth
    draw.text((text_x + 2, title_y + 2), title_text, font=title_font, fill=(0, 0, 0, 80))
    draw.text((text_x, title_y), title_text, font=title_font, fill=(255, 255, 255, 255))

    # Draw subtitle tagline
    subtitle_text = "A game of roads and flats"
    subtitle_y = title_y + 85
    draw.text((text_x + 1, subtitle_y + 1), subtitle_text, font=subtitle_font, fill=(0, 0, 0, 40))
    draw.text((text_x, subtitle_y), subtitle_text, font=subtitle_font, fill=(200, 190, 180, 255))

    # Add decorative line between title and subtitle
    line_y = title_y + 75
    draw.rectangle([text_x, line_y, text_x + 320, line_y + 2], fill=BOARD_FRAME_INNER)

    # Draw stacked stones decoration on the right
    pieces_x = 850
    pieces_y = HEIGHT // 2 + 30

    def draw_flat_stone(x, y, width, height, color, border_color):
        """Draw an elliptical flat stone."""
        # Shadow
        draw.ellipse([x - width//2 + 3, y - height//2 + 3, x + width//2 + 3, y + height//2 + 3], fill=(0, 0, 0, 40))
        draw.ellipse([x - width//2, y - height//2, x + width//2, y + height//2], fill=color, outline=border_color, width=2)

    # Stack of 3 stones
    draw_flat_stone(pieces_x, pieces_y + 35, 90, 22, DARK_PIECE, DARK_PIECE_BORDER)
    draw_flat_stone(pieces_x, pieces_y + 18, 90, 22, LIGHT_PIECE, LIGHT_PIECE_BORDER)
    draw_flat_stone(pieces_x, pieces_y, 90, 22, DARK_PIECE, DARK_PIECE_BORDER)

    # Capstone on top
    cap_y = pieces_y - 35
    draw.ellipse([pieces_x - 3 + 18, cap_y - 3, pieces_x + 3 + 18, cap_y + 30 + 3], fill=(0, 0, 0, 30))
    draw.ellipse([pieces_x - 18, cap_y, pieces_x + 18, cap_y + 30], fill=LIGHT_PIECE, outline=LIGHT_PIECE_BORDER, width=2)

    # Save the image
    output_path = os.path.join(os.path.dirname(__file__), '..', 'store_assets', 'feature_graphic.png')
    img.save(output_path, 'PNG')
    print(f"Feature graphic saved to: {output_path}")

    return output_path


if __name__ == '__main__':
    create_feature_graphic()
