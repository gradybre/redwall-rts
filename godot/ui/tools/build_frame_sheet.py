#!/usr/bin/env python3
"""Assemble the container-frame placement contact sheet from the rendered panels.

Every panel is pasted at its exact rendered pixel size -- nothing here scales art and nothing
here computes geometry. Placement is decided once, in `godot/ui/ui_frame_geometry.gd`, and
`render_frame_panels.gd` has already composed each panel through it; this script only labels
the panels and lays them out, so the sheet is evidence about the contract rather than about
Pillow.

Inputs:  godot/ui/review/exports/frame_<key>_<w>x<h>.png (from render_frame_panels.gd)
Output:  godot/ui/review/sheets/art_frame_geometry.png
Needs:   Pillow. Run: python3 godot/ui/tools/build_frame_sheet.py
"""
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - a missing optional tool, not a product failure
    sys.exit('build_frame_sheet.py needs Pillow: python3 -m pip install --user pillow')

UI = Path(__file__).resolve().parents[1]
EXPORTS = UI / 'review' / 'exports'
SHEETS = UI / 'review' / 'sheets'
FONT_REGULAR = UI / 'fonts' / 'NotoSans-Regular.ttf'
FONT_SEMIBOLD = UI / 'fonts' / 'NotoSans-SemiBold.ttf'

PAPER = (234, 225, 200, 255)
TEXT_ON_PAPER = (37, 55, 45, 255)
MUTED_ON_PAPER = (67, 82, 63, 255)
RULE = (154, 154, 150, 255)

# Must match SHEET_SIZES in render_frame_panels.gd and in test_ui_frame_geometry.gd.
SIZES = [(132, 76), (300, 120), (760, 96)]
FRAMES = ['resource_tray', 'time_group', 'map_folio', 'journal', 'command_dock']

MARGIN = 28
GUTTER = 24
ROW_GAP = 30
TITLE_H = 26
CAPTION_H = 18
HEADER_H = 64


def fonts():
    """The three text sizes this sheet uses."""
    return (ImageFont.truetype(str(FONT_SEMIBOLD), 17),
            ImageFont.truetype(str(FONT_SEMIBOLD), 13),
            ImageFont.truetype(str(FONT_REGULAR), 11))


def row_height():
    """Title band plus the tallest panel in a row plus its caption."""
    return TITLE_H + max(height for _, height in SIZES) + CAPTION_H


def sheet_size():
    """Overall canvas, sized to the real panels rather than to a guess."""
    width = MARGIN * 2 + sum(w for w, _ in SIZES) + GUTTER * (len(SIZES) - 1)
    height = HEADER_H + len(FRAMES) * (row_height() + ROW_GAP) + MARGIN
    return width, height


def draw_row(sheet, draw, frame, top, small, tiny):
    """Paste one silhouette's three panels and caption each with its real pixel size."""
    draw.text((MARGIN, top), frame.replace('_', ' ').upper(), font=small, fill=TEXT_ON_PAPER)
    x = MARGIN
    for width, height in SIZES:
        panel = Image.open(EXPORTS / ('frame_%s_%dx%d.png' % (frame, width, height)))
        y = top + TITLE_H + (max(h for _, h in SIZES) - height)
        sheet.paste(panel.convert('RGBA'), (x, y), panel.convert('RGBA'))
        draw.rectangle([x - 1, y - 1, x + width, y + height], outline=RULE)
        draw.text((x, y + height + 4), '%d x %d' % (width, height),
                  font=tiny, fill=MUTED_ON_PAPER)
        x += width + GUTTER


def main():
    """Build the sheet and report where it landed."""
    heading, small, tiny = fonts()
    sheet = Image.new('RGBA', sheet_size(), PAPER)
    draw = ImageDraw.Draw(sheet)
    draw.text((MARGIN, MARGIN - 6), 'ART-UI container frames: placement at three panel sizes',
              font=heading, fill=TEXT_ON_PAPER)
    draw.text((MARGIN, MARGIN + 16),
              'Corners own the corners at their declared extent; strips run between them at '
              'their declared thickness, scaled along the run only.',
              font=tiny, fill=MUTED_ON_PAPER)
    top = HEADER_H
    for frame in FRAMES:
        draw_row(sheet, draw, frame, top, small, tiny)
        top += row_height() + ROW_GAP
    SHEETS.mkdir(parents=True, exist_ok=True)
    target = SHEETS / 'art_frame_geometry.png'
    sheet.convert('RGB').save(target)
    print('frame-sheet: wrote %s' % target)


if __name__ == '__main__':
    main()
