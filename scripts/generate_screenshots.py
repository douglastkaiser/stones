#!/usr/bin/env python3
"""
Generate app store screenshots for Stones.

Since Flutter is not available, this creates visual representations
based on the app's actual code and color scheme.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os
import math

# =============================================================================
# COLOR DEFINITIONS (from GameColors in lib/theme/game_colors.dart)
# =============================================================================

# Player Piece Colors
LIGHT_PIECE = (245, 240, 230)  # 0xFFF5F0E6
LIGHT_PIECE_SECONDARY = (232, 224, 208)  # 0xFFE8E0D0
LIGHT_PIECE_BORDER = (139, 115, 85)  # 0xFF8B7355
DARK_PIECE = (61, 61, 61)  # 0xFF3D3D3D
DARK_PIECE_SECONDARY = (74, 74, 74)  # 0xFF4A4A4A
DARK_PIECE_BORDER = (107, 107, 107)  # 0xFF6B6B6B

# Board Colors
BOARD_FRAME_OUTER = (93, 64, 55)  # 0xFF5D4037
BOARD_FRAME_INNER = (121, 85, 72)  # 0xFF795548
BOARD_BACKGROUND = (109, 76, 65)  # 0xFF6D4C41
GRID_LINE = (78, 52, 46)  # 0xFF4E342E
CELL_BACKGROUND = (215, 204, 200)  # 0xFFD7CCC8
CELL_BACKGROUND_LIGHT = (239, 235, 233)  # 0xFFEFEBE9
CELL_SELECTED = (255, 224, 130)  # 0xFFFFE082

# UI Colors
TITLE_COLOR = (78, 52, 46)  # 0xFF4E342E
SUBTITLE_COLOR = (93, 64, 55)  # 0xFF5D4037
CONTROL_PANEL_BG = (250, 248, 245)  # 0xFFFAF8F5

# Screen background
SCREEN_BG_LIGHT = (255, 251, 250)  # Light theme background
SCREEN_BG_DARK = (30, 30, 30)  # Dark theme background

# =============================================================================
# SCREENSHOT DIMENSIONS
# =============================================================================

# Phone: 9:16 aspect ratio
PHONE_WIDTH = 1080
PHONE_HEIGHT = 1920

# 7-inch tablet: 9:16 (can also use 16:9)
TABLET_7_WIDTH = 1200
TABLET_7_HEIGHT = 1920

# 10-inch tablet: 9:16 (needs min 1080px per side)
TABLET_10_WIDTH = 1600
TABLET_10_HEIGHT = 2560


def load_fonts():
    """Load fonts for text rendering."""
    fonts = {}
    try:
        fonts['title_large'] = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 72)
        fonts['title'] = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 48)
        fonts['subtitle'] = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 32)
        fonts['body'] = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 28)
        fonts['button'] = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 28)
        fonts['small'] = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20)
    except:
        fonts['title_large'] = ImageFont.load_default()
        fonts['title'] = ImageFont.load_default()
        fonts['subtitle'] = ImageFont.load_default()
        fonts['body'] = ImageFont.load_default()
        fonts['button'] = ImageFont.load_default()
        fonts['small'] = ImageFont.load_default()
    return fonts


def draw_rounded_rect(draw, coords, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    x1, y1, x2, y2 = coords

    if fill:
        # Fill the main rectangle areas
        draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=fill)
        draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=fill)
        # Fill the corners
        draw.pieslice([x1, y1, x1 + 2*radius, y1 + 2*radius], 180, 270, fill=fill)
        draw.pieslice([x2 - 2*radius, y1, x2, y1 + 2*radius], 270, 360, fill=fill)
        draw.pieslice([x1, y2 - 2*radius, x1 + 2*radius, y2], 90, 180, fill=fill)
        draw.pieslice([x2 - 2*radius, y2 - 2*radius, x2, y2], 0, 90, fill=fill)

    if outline:
        # Draw outline
        draw.arc([x1, y1, x1 + 2*radius, y1 + 2*radius], 180, 270, fill=outline, width=width)
        draw.arc([x2 - 2*radius, y1, x2, y1 + 2*radius], 270, 360, fill=outline, width=width)
        draw.arc([x1, y2 - 2*radius, x1 + 2*radius, y2], 90, 180, fill=outline, width=width)
        draw.arc([x2 - 2*radius, y2 - 2*radius, x2, y2], 0, 90, fill=outline, width=width)
        draw.line([x1 + radius, y1, x2 - radius, y1], fill=outline, width=width)
        draw.line([x1 + radius, y2, x2 - radius, y2], fill=outline, width=width)
        draw.line([x1, y1 + radius, x1, y2 - radius], fill=outline, width=width)
        draw.line([x2, y1 + radius, x2, y2 - radius], fill=outline, width=width)


def draw_button(draw, x, y, width, height, text, font, fill_color, text_color, outline=None):
    """Draw a rounded button with text."""
    radius = height // 4
    coords = [x, y, x + width, y + height]
    draw_rounded_rect(draw, coords, radius, fill=fill_color, outline=outline, width=3)

    # Center text
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    text_x = x + (width - text_width) // 2
    text_y = y + (height - text_height) // 2 - 4
    draw.text((text_x, text_y), text, font=font, fill=text_color)


def draw_flat_stone(draw, x, y, width, height, is_light, with_shadow=True):
    """Draw a flat stone piece."""
    if is_light:
        fill = LIGHT_PIECE
        border = LIGHT_PIECE_BORDER
    else:
        fill = DARK_PIECE
        border = DARK_PIECE_BORDER

    # Shadow
    if with_shadow:
        draw.ellipse([x - width//2 + 4, y - height//2 + 4,
                     x + width//2 + 4, y + height//2 + 4],
                    fill=(0, 0, 0, 50))

    # Stone
    draw.ellipse([x - width//2, y - height//2, x + width//2, y + height//2],
                fill=fill, outline=border, width=2)


def draw_standing_stone(draw, x, y, width, height, is_light):
    """Draw a standing stone piece."""
    if is_light:
        fill = LIGHT_PIECE
        border = LIGHT_PIECE_BORDER
    else:
        fill = DARK_PIECE
        border = DARK_PIECE_BORDER

    # Shadow
    shadow_offset = 5
    draw.rectangle([x - width//2 + shadow_offset, y - height//2 + shadow_offset,
                   x + width//2 + shadow_offset, y + height//2 + shadow_offset],
                  fill=(0, 0, 0, 40))

    # Standing stone (rectangle)
    draw.rectangle([x - width//2, y - height//2, x + width//2, y + height//2],
                  fill=fill, outline=border, width=2)


def draw_capstone(draw, x, y, radius, is_light):
    """Draw a capstone piece."""
    if is_light:
        fill = LIGHT_PIECE
        border = LIGHT_PIECE_BORDER
    else:
        fill = DARK_PIECE
        border = DARK_PIECE_BORDER

    # Shadow
    draw.ellipse([x - radius + 4, y - radius + 4, x + radius + 4, y + radius + 4],
                fill=(0, 0, 0, 50))

    # Capstone (circle, slightly 3D)
    draw.ellipse([x - radius, y - radius, x + radius, y + radius],
                fill=fill, outline=border, width=3)


def draw_game_board(img, draw, board_x, board_y, board_size, cell_size, game_state=None):
    """Draw the game board with wood texture effect."""
    total_size = cell_size * board_size
    frame_width = 15

    # Outer frame
    draw.rectangle([board_x - frame_width, board_y - frame_width,
                   board_x + total_size + frame_width, board_y + total_size + frame_width],
                  fill=BOARD_FRAME_OUTER)

    # Inner frame
    draw.rectangle([board_x - 5, board_y - 5,
                   board_x + total_size + 5, board_y + total_size + 5],
                  fill=BOARD_FRAME_INNER)

    # Draw cells
    for row in range(board_size):
        for col in range(board_size):
            cell_x = board_x + col * cell_size
            cell_y = board_y + row * cell_size

            # Cell background with subtle gradient effect
            draw.rectangle([cell_x + 2, cell_y + 2, cell_x + cell_size - 2, cell_y + cell_size - 2],
                          fill=CELL_BACKGROUND)

            # Grid lines (inset effect)
            draw.line([cell_x, cell_y, cell_x + cell_size, cell_y], fill=GRID_LINE, width=2)
            draw.line([cell_x, cell_y, cell_x, cell_y + cell_size], fill=GRID_LINE, width=2)

    # Draw pieces from game state
    if game_state:
        for (row, col), pieces in game_state.items():
            cell_x = board_x + col * cell_size + cell_size // 2
            cell_y = board_y + row * cell_size + cell_size // 2

            # Draw stack of pieces
            piece_height = min(cell_size // 8, 12)
            for i, (piece_type, is_light) in enumerate(pieces):
                offset_y = -i * (piece_height + 2)

                if piece_type == 'flat':
                    draw_flat_stone(draw, cell_x, cell_y + offset_y,
                                   cell_size - 20, piece_height + 8, is_light)
                elif piece_type == 'standing':
                    draw_standing_stone(draw, cell_x, cell_y + offset_y,
                                       cell_size // 4, cell_size - 25, is_light)
                elif piece_type == 'capstone':
                    draw_capstone(draw, cell_x, cell_y + offset_y - 5,
                                 cell_size // 4, is_light)


def draw_piece_counter(draw, x, y, width, height, fonts, is_light, flat_count, cap_count):
    """Draw a piece counter panel."""
    # Background
    bg_color = LIGHT_PIECE if is_light else DARK_PIECE
    border_color = LIGHT_PIECE_BORDER if is_light else DARK_PIECE_BORDER
    text_color = DARK_PIECE if is_light else LIGHT_PIECE

    draw_rounded_rect(draw, [x, y, x + width, y + height], 10, fill=bg_color, outline=border_color, width=2)

    # Flat stone icon and count
    draw_flat_stone(draw, x + 30, y + height // 2, 35, 12, is_light, with_shadow=False)
    draw.text((x + 55, y + height // 2 - 12), str(flat_count), font=fonts['body'], fill=text_color)

    # Capstone icon and count
    draw_capstone(draw, x + width - 50, y + height // 2, 12, is_light)
    draw.text((x + width - 30, y + height // 2 - 12), str(cap_count), font=fonts['body'], fill=text_color)


def create_main_menu_screenshot(width, height, fonts, output_path):
    """Create main menu screenshot."""
    img = Image.new('RGBA', (width, height), SCREEN_BG_LIGHT)
    draw = ImageDraw.Draw(img)

    center_x = width // 2

    # Status bar simulation (top)
    draw.rectangle([0, 0, width, 60], fill=(240, 240, 240))

    # Top bar with About and Settings
    top_y = 80
    draw.text((30, top_y), "About", font=fonts['body'], fill=SUBTITLE_COLOR)

    # Trophy icon position (right side)
    draw.text((width - 150, top_y), "🏆", font=fonts['body'], fill=SUBTITLE_COLOR)
    draw.text((width - 80, top_y), "⚙️", font=fonts['body'], fill=SUBTITLE_COLOR)

    # Logo area - draw stacked stones
    logo_y = height // 4
    stack_x = center_x

    # Draw 3 stacked flat stones
    draw_flat_stone(draw, stack_x, logo_y + 40, 100, 25, False)
    draw_flat_stone(draw, stack_x, logo_y + 20, 100, 25, True)
    draw_flat_stone(draw, stack_x, logo_y, 100, 25, False)
    draw_capstone(draw, stack_x, logo_y - 45, 20, True)

    # Title
    title_text = "STONES"
    bbox = draw.textbbox((0, 0), title_text, font=fonts['title_large'])
    title_width = bbox[2] - bbox[0]
    draw.text((center_x - title_width // 2, logo_y + 80), title_text, font=fonts['title_large'], fill=TITLE_COLOR)

    # Subtitle
    subtitle_text = "A game of roads and flats"
    bbox = draw.textbbox((0, 0), subtitle_text, font=fonts['subtitle'])
    subtitle_width = bbox[2] - bbox[0]
    draw.text((center_x - subtitle_width // 2, logo_y + 160), subtitle_text, font=fonts['subtitle'], fill=SUBTITLE_COLOR)

    # Buttons
    button_width = int(width * 0.55)
    button_height = 70
    button_x = center_x - button_width // 2
    buttons_y = height // 2 + 80
    button_spacing = 85

    # Local Game button (primary)
    draw_button(draw, button_x, buttons_y, button_width, button_height,
               "Local Game", fonts['button'], BOARD_FRAME_INNER, (255, 255, 255))

    # Online Game button
    draw_button(draw, button_x, buttons_y + button_spacing, button_width, button_height,
               "Online Game", fonts['button'], BOARD_FRAME_OUTER, (255, 255, 255))

    # Vs Computer button (outlined)
    draw_button(draw, button_x, buttons_y + button_spacing * 2, button_width, button_height,
               "Vs Computer", fonts['button'], SCREEN_BG_LIGHT, BOARD_FRAME_INNER, outline=BOARD_FRAME_INNER)

    # Tutorials button (outlined)
    draw_button(draw, button_x, buttons_y + button_spacing * 3, button_width, button_height,
               "Tutorials & Puzzles", fonts['button'], SCREEN_BG_LIGHT, BOARD_FRAME_INNER, outline=BOARD_FRAME_INNER)

    # Version footer
    draw.text((center_x - 40, height - 60), "v1.0.0", font=fonts['small'], fill=(150, 150, 150))

    img.save(output_path, 'PNG')
    print(f"Saved: {output_path}")


def create_game_screenshot(width, height, fonts, output_path):
    """Create in-game screenshot showing mid-game state."""
    img = Image.new('RGBA', (width, height), SCREEN_BG_LIGHT)
    draw = ImageDraw.Draw(img)

    center_x = width // 2

    # Calculate board dimensions
    board_size = 5  # 5x5 board
    # Board should fit nicely with some padding
    available_height = height - 400  # Leave room for UI elements
    available_width = width - 60
    max_board_size = min(available_width, available_height)
    cell_size = max_board_size // board_size
    total_board_size = cell_size * board_size

    board_x = center_x - total_board_size // 2
    board_y = 200

    # Top bar with back button and menu
    draw.text((30, 80), "←", font=fonts['title'], fill=SUBTITLE_COLOR)
    draw.text((width - 80, 80), "⋮", font=fonts['title'], fill=SUBTITLE_COLOR)

    # Current player indicator
    indicator_y = 130
    draw.text((center_x - 80, indicator_y), "White's Turn", font=fonts['body'], fill=TITLE_COLOR)

    # Sample game state - mid-game on 5x5
    game_state = {
        (0, 0): [('flat', False)],
        (0, 4): [('flat', True)],
        (1, 1): [('flat', True), ('flat', False)],
        (1, 2): [('standing', False)],
        (2, 0): [('flat', False)],
        (2, 2): [('flat', True)],
        (2, 3): [('capstone', True)],
        (3, 1): [('flat', False)],
        (3, 3): [('flat', True)],
        (4, 2): [('flat', False), ('flat', True)],
        (4, 4): [('flat', True)],
    }

    # Draw board
    draw_game_board(img, draw, board_x, board_y, board_size, cell_size, game_state)

    # Piece counters below board
    counter_y = board_y + total_board_size + 50
    counter_width = (width - 80) // 2 - 20
    counter_height = 60

    # White pieces counter (left)
    draw_piece_counter(draw, 30, counter_y, counter_width, counter_height, fonts, True, 16, 1)

    # Black pieces counter (right)
    draw_piece_counter(draw, width - 30 - counter_width, counter_y, counter_width, counter_height, fonts, False, 17, 1)

    # Turn indicator below counters
    turn_y = counter_y + counter_height + 30
    turn_text = "Turn 8"
    bbox = draw.textbbox((0, 0), turn_text, font=fonts['small'])
    turn_width = bbox[2] - bbox[0]
    draw.text((center_x - turn_width // 2, turn_y), turn_text, font=fonts['small'], fill=SUBTITLE_COLOR)

    img.save(output_path, 'PNG')
    print(f"Saved: {output_path}")


def create_vs_computer_screenshot(width, height, fonts, output_path):
    """Create vs computer difficulty selection screenshot."""
    img = Image.new('RGBA', (width, height), SCREEN_BG_LIGHT)
    draw = ImageDraw.Draw(img)

    center_x = width // 2

    # Dialog background
    dialog_width = int(width * 0.85)
    dialog_height = int(height * 0.7)
    dialog_x = center_x - dialog_width // 2
    dialog_y = (height - dialog_height) // 2

    # Shadow
    shadow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rectangle([0, 0, width, height], fill=(0, 0, 0, 80))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Dialog
    draw_rounded_rect(draw, [dialog_x, dialog_y, dialog_x + dialog_width, dialog_y + dialog_height],
                     20, fill=(255, 255, 255))

    # Title
    title_text = "Play vs Computer"
    bbox = draw.textbbox((0, 0), title_text, font=fonts['title'])
    title_width = bbox[2] - bbox[0]
    draw.text((center_x - title_width // 2, dialog_y + 30), title_text, font=fonts['title'], fill=TITLE_COLOR)

    content_y = dialog_y + 100
    section_x = dialog_x + 40

    # Board Size section
    draw.text((section_x, content_y), "Board Size", font=fonts['button'], fill=TITLE_COLOR)

    chip_y = content_y + 45
    chip_width = 70
    chip_height = 40
    chip_spacing = 10
    chips_start_x = section_x

    sizes = ['3×3', '4×4', '5×5', '6×6', '7×7', '8×8']
    for i, size in enumerate(sizes):
        chip_x = chips_start_x + i * (chip_width + chip_spacing)
        is_selected = size == '5×5'

        if is_selected:
            draw_rounded_rect(draw, [chip_x, chip_y, chip_x + chip_width, chip_y + chip_height],
                            8, fill=(BOARD_FRAME_INNER[0], BOARD_FRAME_INNER[1], BOARD_FRAME_INNER[2], 50),
                            outline=BOARD_FRAME_INNER, width=2)
        else:
            draw_rounded_rect(draw, [chip_x, chip_y, chip_x + chip_width, chip_y + chip_height],
                            8, fill=(240, 240, 240), outline=(200, 200, 200), width=1)

        bbox = draw.textbbox((0, 0), size, font=fonts['small'])
        text_width = bbox[2] - bbox[0]
        text_color = BOARD_FRAME_INNER if is_selected else SUBTITLE_COLOR
        draw.text((chip_x + (chip_width - text_width) // 2, chip_y + 10), size, font=fonts['small'], fill=text_color)

    # Your Color section
    color_y = chip_y + 80
    draw.text((section_x, color_y), "Your Color", font=fonts['button'], fill=TITLE_COLOR)

    color_option_y = color_y + 45
    option_width = (dialog_width - 100) // 2
    option_height = 50

    # White option (selected)
    draw_rounded_rect(draw, [section_x, color_option_y, section_x + option_width, color_option_y + option_height],
                     8, fill=(BOARD_FRAME_INNER[0], BOARD_FRAME_INNER[1], BOARD_FRAME_INNER[2], 30),
                     outline=BOARD_FRAME_INNER, width=2)
    draw.ellipse([section_x + 15, color_option_y + 17, section_x + 35, color_option_y + 37], fill=LIGHT_PIECE, outline=LIGHT_PIECE_BORDER)
    draw.text((section_x + 45, color_option_y + 13), "White", font=fonts['body'], fill=BOARD_FRAME_INNER)

    # Black option
    black_x = section_x + option_width + 20
    draw_rounded_rect(draw, [black_x, color_option_y, black_x + option_width, color_option_y + option_height],
                     8, outline=(200, 200, 200), width=1)
    draw.ellipse([black_x + 15, color_option_y + 17, black_x + 35, color_option_y + 37], fill=DARK_PIECE, outline=DARK_PIECE_BORDER)
    draw.text((black_x + 45, color_option_y + 13), "Black", font=fonts['body'], fill=SUBTITLE_COLOR)

    # Difficulty section
    diff_y = color_option_y + 90
    draw.text((section_x, diff_y), "Difficulty", font=fonts['button'], fill=TITLE_COLOR)

    difficulties = ['Easy', 'Medium', 'Hard', 'Expert']
    diff_option_y = diff_y + 45
    diff_height = 45
    diff_spacing = 8

    for i, diff in enumerate(difficulties):
        opt_y = diff_option_y + i * (diff_height + diff_spacing)
        is_selected = diff == 'Medium'

        if is_selected:
            draw_rounded_rect(draw, [section_x, opt_y, section_x + dialog_width - 80, opt_y + diff_height],
                            8, fill=(BOARD_FRAME_INNER[0], BOARD_FRAME_INNER[1], BOARD_FRAME_INNER[2], 30),
                            outline=BOARD_FRAME_INNER, width=2)
            text_color = BOARD_FRAME_INNER
        else:
            draw_rounded_rect(draw, [section_x, opt_y, section_x + dialog_width - 80, opt_y + diff_height],
                            8, outline=(200, 200, 200), width=1)
            text_color = SUBTITLE_COLOR

        draw.text((section_x + 20, opt_y + 10), diff, font=fonts['body'], fill=text_color)

    # Action buttons
    button_y = dialog_y + dialog_height - 80
    cancel_width = 100
    start_width = 140

    draw.text((dialog_x + 40, button_y + 15), "Cancel", font=fonts['button'], fill=BOARD_FRAME_INNER)

    draw_button(draw, dialog_x + dialog_width - start_width - 40, button_y, start_width, 50,
               "Start Game", fonts['button'], BOARD_FRAME_INNER, (255, 255, 255))

    img.save(output_path, 'PNG')
    print(f"Saved: {output_path}")


def create_achievements_screenshot(width, height, fonts, output_path):
    """Create achievements screen screenshot."""
    img = Image.new('RGBA', (width, height), SCREEN_BG_LIGHT)
    draw = ImageDraw.Draw(img)

    center_x = width // 2

    # Top bar
    draw.text((30, 80), "←", font=fonts['title'], fill=SUBTITLE_COLOR)

    title_text = "Achievements"
    bbox = draw.textbbox((0, 0), title_text, font=fonts['title'])
    title_width = bbox[2] - bbox[0]
    draw.text((center_x - title_width // 2, 80), title_text, font=fonts['title'], fill=TITLE_COLOR)

    # Achievement cards
    card_width = width - 60
    card_height = 100
    card_x = 30
    card_spacing = 15

    achievements = [
        ("🏆", "First Victory", "Win your first game", True),
        ("🎯", "Road Builder", "Win by creating a road", True),
        ("🏔️", "Tower of Power", "Build a stack of 5+ pieces", True),
        ("⚡", "Speed Demon", "Win in under 2 minutes", False),
        ("🧩", "Puzzle Master", "Complete all puzzles", False),
        ("🤖", "AI Conqueror", "Beat Hard AI", False),
    ]

    for i, (icon, title, desc, unlocked) in enumerate(achievements):
        card_y = 180 + i * (card_height + card_spacing)

        if card_y + card_height > height - 50:
            break

        # Card background
        if unlocked:
            card_bg = (255, 253, 245)
            border_color = (255, 200, 100)
        else:
            card_bg = (245, 245, 245)
            border_color = (200, 200, 200)

        draw_rounded_rect(draw, [card_x, card_y, card_x + card_width, card_y + card_height],
                         15, fill=card_bg, outline=border_color, width=2)

        # Icon circle
        icon_x = card_x + 50
        icon_y = card_y + card_height // 2
        icon_radius = 30

        if unlocked:
            draw.ellipse([icon_x - icon_radius, icon_y - icon_radius,
                         icon_x + icon_radius, icon_y + icon_radius],
                        fill=(255, 230, 150))
        else:
            draw.ellipse([icon_x - icon_radius, icon_y - icon_radius,
                         icon_x + icon_radius, icon_y + icon_radius],
                        fill=(220, 220, 220))

        # Icon (emoji approximation - just draw text)
        draw.text((icon_x - 15, icon_y - 15), icon, font=fonts['subtitle'], fill=TITLE_COLOR)

        # Title and description
        text_x = icon_x + icon_radius + 25
        draw.text((text_x, card_y + 25), title, font=fonts['button'],
                 fill=TITLE_COLOR if unlocked else (150, 150, 150))
        draw.text((text_x, card_y + 58), desc, font=fonts['small'],
                 fill=SUBTITLE_COLOR if unlocked else (180, 180, 180))

        # Checkmark for unlocked
        if unlocked:
            draw.text((card_x + card_width - 50, card_y + 35), "✓", font=fonts['title'], fill=(100, 180, 100))

    img.save(output_path, 'PNG')
    print(f"Saved: {output_path}")


def main():
    """Generate all screenshots."""
    fonts = load_fonts()

    # Create output directories
    output_dir = os.path.join(os.path.dirname(__file__), '..', 'store_assets', 'screenshots')
    os.makedirs(os.path.join(output_dir, 'phone'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'tablet_7'), exist_ok=True)
    os.makedirs(os.path.join(output_dir, 'tablet_10'), exist_ok=True)

    # Generate phone screenshots
    print("\nGenerating phone screenshots (1080x1920)...")
    create_main_menu_screenshot(PHONE_WIDTH, PHONE_HEIGHT, fonts,
                               os.path.join(output_dir, 'phone', '01_main_menu.png'))
    create_game_screenshot(PHONE_WIDTH, PHONE_HEIGHT, fonts,
                          os.path.join(output_dir, 'phone', '02_game_board.png'))
    create_vs_computer_screenshot(PHONE_WIDTH, PHONE_HEIGHT, fonts,
                                 os.path.join(output_dir, 'phone', '03_vs_computer.png'))
    create_achievements_screenshot(PHONE_WIDTH, PHONE_HEIGHT, fonts,
                                  os.path.join(output_dir, 'phone', '04_achievements.png'))

    # Generate 7-inch tablet screenshots
    print("\nGenerating 7-inch tablet screenshots (1200x1920)...")
    create_main_menu_screenshot(TABLET_7_WIDTH, TABLET_7_HEIGHT, fonts,
                               os.path.join(output_dir, 'tablet_7', '01_main_menu.png'))
    create_game_screenshot(TABLET_7_WIDTH, TABLET_7_HEIGHT, fonts,
                          os.path.join(output_dir, 'tablet_7', '02_game_board.png'))
    create_vs_computer_screenshot(TABLET_7_WIDTH, TABLET_7_HEIGHT, fonts,
                                 os.path.join(output_dir, 'tablet_7', '03_vs_computer.png'))
    create_achievements_screenshot(TABLET_7_WIDTH, TABLET_7_HEIGHT, fonts,
                                  os.path.join(output_dir, 'tablet_7', '04_achievements.png'))

    # Generate 10-inch tablet screenshots
    print("\nGenerating 10-inch tablet screenshots (1600x2560)...")
    create_main_menu_screenshot(TABLET_10_WIDTH, TABLET_10_HEIGHT, fonts,
                               os.path.join(output_dir, 'tablet_10', '01_main_menu.png'))
    create_game_screenshot(TABLET_10_WIDTH, TABLET_10_HEIGHT, fonts,
                          os.path.join(output_dir, 'tablet_10', '02_game_board.png'))
    create_vs_computer_screenshot(TABLET_10_WIDTH, TABLET_10_HEIGHT, fonts,
                                 os.path.join(output_dir, 'tablet_10', '03_vs_computer.png'))
    create_achievements_screenshot(TABLET_10_WIDTH, TABLET_10_HEIGHT, fonts,
                                  os.path.join(output_dir, 'tablet_10', '04_achievements.png'))

    print("\nDone! Screenshots saved to store_assets/screenshots/")


if __name__ == '__main__':
    main()
