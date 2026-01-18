#!/usr/bin/env python3
"""
Capture real screenshots from the deployed Stones app using Playwright.

This script is designed to run in CI to capture accurate app store screenshots.

Usage:
    python scripts/capture_screenshots.py

Environment variables:
    APP_URL: URL of the deployed app (default: https://douglastkaiser.github.io/stones/)
"""

import os
import sys
import time
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout

# App URL - can be overridden by environment variable
APP_URL = os.environ.get('APP_URL', 'https://douglastkaiser.github.io/stones/')

# Screenshot configurations matching Google Play requirements
CONFIGS = {
    'phone': {
        'width': 1080,
        'height': 1920,
        'device_scale_factor': 1,  # Final image will be 1080x1920
    },
    'tablet_7': {
        'width': 1200,
        'height': 1920,
        'device_scale_factor': 1,
    },
    'tablet_10': {
        'width': 1600,
        'height': 2560,
        'device_scale_factor': 1,
    },
}


def wait_for_app_load(page, timeout=30000):
    """Wait for the Flutter app to fully load."""
    try:
        # Wait for the main content to be visible
        # Flutter web apps typically have a loading indicator that disappears
        page.wait_for_load_state('networkidle', timeout=timeout)

        # Additional wait for Flutter to render
        # Look for app-specific elements
        page.wait_for_selector('text=STONES', timeout=timeout)

        # Give a bit more time for animations
        time.sleep(2)
        return True
    except PlaywrightTimeout:
        print("Warning: Timeout waiting for app to load")
        return False


def safe_click(page, selector, timeout=5000):
    """Safely click an element, returning True if successful."""
    try:
        element = page.locator(selector).first
        element.wait_for(state='visible', timeout=timeout)
        element.click()
        time.sleep(0.5)
        return True
    except Exception as e:
        print(f"  Could not click '{selector}': {e}")
        return False


def safe_click_text(page, text, exact=True, timeout=5000):
    """Safely click an element by text content."""
    try:
        element = page.get_by_text(text, exact=exact).first
        element.wait_for(state='visible', timeout=timeout)
        element.click()
        time.sleep(0.5)
        return True
    except Exception as e:
        print(f"  Could not click text '{text}': {e}")
        return False


def capture_main_menu(page, output_path):
    """Capture the main menu screen."""
    print("  Capturing main menu...")
    page.goto(APP_URL, wait_until='networkidle')
    wait_for_app_load(page)
    page.screenshot(path=output_path)
    print(f"    Saved: {output_path}")


def capture_game_board(page, output_path):
    """Start a game and capture the board."""
    print("  Capturing game board...")
    page.goto(APP_URL, wait_until='networkidle')
    wait_for_app_load(page)

    # Click Local Game
    if not safe_click_text(page, "Local Game"):
        print("    Warning: Could not find Local Game button")
        return

    time.sleep(1)

    # Select 5x5 board (should open a dialog)
    safe_click_text(page, "5×5", exact=True)
    time.sleep(0.5)

    # Click Start Game
    if safe_click_text(page, "Start Game"):
        time.sleep(2)

        # Try to make a few moves for a more interesting screenshot
        # Click on board cells to place pieces
        try:
            # Find the board area and click some cells
            # The board should be roughly centered
            viewport = page.viewport_size
            center_x = viewport['width'] // 2
            board_top = 200  # Approximate board position
            cell_size = min(viewport['width'] - 60, viewport['height'] - 400) // 5

            # Place a few pieces by clicking cells
            moves = [
                (2, 2),  # Center
                (0, 0),  # Corner
                (1, 3),  # Off-center
                (4, 4),  # Opposite corner
                (2, 0),  # Edge
                (3, 2),  # Near center
            ]

            board_left = center_x - (cell_size * 5) // 2

            for row, col in moves:
                x = board_left + col * cell_size + cell_size // 2
                y = board_top + row * cell_size + cell_size // 2
                page.mouse.click(x, y)
                time.sleep(0.8)
        except Exception as e:
            print(f"    Note: Could not simulate moves: {e}")

        page.screenshot(path=output_path)
        print(f"    Saved: {output_path}")
    else:
        print("    Warning: Could not start game")


def capture_vs_computer_dialog(page, output_path):
    """Capture the vs computer setup dialog."""
    print("  Capturing vs computer dialog...")
    page.goto(APP_URL, wait_until='networkidle')
    wait_for_app_load(page)

    if safe_click_text(page, "Vs Computer"):
        time.sleep(1)
        page.screenshot(path=output_path)
        print(f"    Saved: {output_path}")

        # Close dialog
        safe_click_text(page, "Cancel")
    else:
        print("    Warning: Could not find Vs Computer button")


def capture_tutorials_dialog(page, output_path):
    """Capture the tutorials and puzzles dialog."""
    print("  Capturing tutorials dialog...")
    page.goto(APP_URL, wait_until='networkidle')
    wait_for_app_load(page)

    if safe_click_text(page, "Tutorials & Puzzles"):
        time.sleep(1)
        page.screenshot(path=output_path)
        print(f"    Saved: {output_path}")

        # Close dialog
        safe_click_text(page, "Close")
    else:
        print("    Warning: Could not find Tutorials button")


def capture_achievements_screen(page, output_path):
    """Capture the achievements screen."""
    print("  Capturing achievements screen...")
    page.goto(APP_URL, wait_until='networkidle')
    wait_for_app_load(page)

    # Try to find and click the achievements button (trophy icon in top bar)
    # It might be an IconButton with tooltip "Achievements"
    clicked = False

    # Try various selectors for the achievements button
    selectors = [
        '[aria-label="Achievements"]',
        'button:has-text("🏆")',
        'button[title="Achievements"]',
    ]

    for selector in selectors:
        if safe_click(page, selector):
            clicked = True
            break

    if not clicked:
        # Try clicking by position (achievements is typically in top-right)
        try:
            viewport = page.viewport_size
            # Achievements button is usually second from right in top bar
            page.mouse.click(viewport['width'] - 120, 100)
            time.sleep(1)
            clicked = True
        except Exception:
            pass

    if clicked:
        time.sleep(1)
        page.screenshot(path=output_path)
        print(f"    Saved: {output_path}")
    else:
        print("    Warning: Could not find achievements button")


def capture_settings_screen(page, output_path):
    """Capture the settings screen."""
    print("  Capturing settings screen...")
    page.goto(APP_URL, wait_until='networkidle')
    wait_for_app_load(page)

    # Settings is typically the gear icon in top-right
    clicked = False

    selectors = [
        '[aria-label="Settings"]',
        'button:has-text("⚙")',
        'button[title="Settings"]',
    ]

    for selector in selectors:
        if safe_click(page, selector):
            clicked = True
            break

    if not clicked:
        # Try clicking by position
        try:
            viewport = page.viewport_size
            page.mouse.click(viewport['width'] - 50, 100)
            time.sleep(1)
            clicked = True
        except Exception:
            pass

    if clicked:
        time.sleep(1)
        page.screenshot(path=output_path)
        print(f"    Saved: {output_path}")
    else:
        print("    Warning: Could not find settings button")


def capture_screenshots():
    """Capture all screenshots for all device configurations."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_base = os.path.join(script_dir, '..', 'store_assets', 'screenshots')

    print(f"Capturing screenshots from: {APP_URL}")
    print(f"Output directory: {os.path.abspath(output_base)}")

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-setuid-sandbox']
        )

        for config_name, config in CONFIGS.items():
            print(f"\n{'='*60}")
            print(f"Capturing {config_name} screenshots ({config['width']}x{config['height']})")
            print('='*60)

            output_dir = os.path.join(output_base, config_name)
            os.makedirs(output_dir, exist_ok=True)

            context = browser.new_context(
                viewport={'width': config['width'], 'height': config['height']},
                device_scale_factor=config['device_scale_factor'],
            )

            page = context.new_page()

            # Capture each screen
            capture_main_menu(page, os.path.join(output_dir, '01_main_menu.png'))
            capture_game_board(page, os.path.join(output_dir, '02_game_board.png'))
            capture_vs_computer_dialog(page, os.path.join(output_dir, '03_vs_computer.png'))
            capture_tutorials_dialog(page, os.path.join(output_dir, '04_tutorials.png'))
            capture_achievements_screen(page, os.path.join(output_dir, '05_achievements.png'))
            capture_settings_screen(page, os.path.join(output_dir, '06_settings.png'))

            context.close()

        browser.close()

    print(f"\n{'='*60}")
    print("Screenshot capture complete!")
    print(f"Screenshots saved to: {os.path.abspath(output_base)}")
    print('='*60)


if __name__ == '__main__':
    try:
        capture_screenshots()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
