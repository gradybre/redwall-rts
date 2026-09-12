#!/usr/bin/env python3
"""Compose the ART-UI review contact sheets from the exported PNGs.

Every tile is pasted at its exact delivered pixel size -- nothing here upscales art to make
it look better than it is. Where a magnified copy is shown it is labelled as such and uses
nearest-neighbour, so a reviewer sees the real pixels rather than a smoothed version.

Inputs:  godot/ui/ui_art_manifest.json and godot/ui/review/exports/*.png
         (both produced by the two Godot tools beside this file)
Outputs: godot/ui/review/sheets/*.png
Needs:   Pillow. Run: python3 godot/ui/tools/build_contact_sheets.py
"""
import json
from pathlib import Path
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - a missing optional tool, not a product failure
    sys.exit("build_contact_sheets.py needs Pillow: python3 -m pip install --user pillow")

UI = Path(__file__).resolve().parents[1]
EXPORTS = UI / 'review' / 'exports'
SHEETS = UI / 'review' / 'sheets'
FONT_REGULAR = UI / 'fonts' / 'NotoSans-Regular.ttf'
FONT_SEMIBOLD = UI / 'fonts' / 'NotoSans-SemiBold.ttf'

FOREST = (30, 48, 40, 255)
PAPER = (234, 225, 200, 255)
NEUTRAL = (154, 154, 150, 255)
TEXT_ON_FOREST = (245, 240, 223, 255)
TEXT_ON_PAPER = (37, 55, 45, 255)
MUTED_ON_FOREST = (190, 202, 191, 255)
MUTED_ON_PAPER = (67, 82, 63, 255)

MARGIN = 24
GUTTER = 28


def stem(asset_id):
    """The export filename stem the Godot exporter writes for a stable ID."""
    return asset_id.lower().replace('.', '_')


def load(asset_id, size):
    """Open one exported PNG at one delivered size."""
    return Image.open(EXPORTS / ('%s_%d.png' % (stem(asset_id), size))).convert('RGBA')


def fonts():
    """The vendored Noto faces used for sheet labels; no OS font is substituted."""
    return (ImageFont.truetype(str(FONT_SEMIBOLD), 15),
            ImageFont.truetype(str(FONT_REGULAR), 12),
            ImageFont.truetype(str(FONT_SEMIBOLD), 20))


def header(draw, title, subtitle, width, colour, muted, title_font, body_font):
    """Draw the sheet title block and return the y the first row starts at."""
    draw.text((MARGIN, MARGIN), title, font=title_font, fill=colour)
    draw.text((MARGIN, MARGIN + 26), subtitle, font=body_font, fill=muted)
    return MARGIN + 56


def sheet(name, size, background):
    """A blank sheet of the requested size and background."""
    image = Image.new('RGBA', size, background)
    return image, ImageDraw.Draw(image)


def resource_sheet(manifest):
    """ART-UI-03: the six painted resource icons at 24 and 32, on FOREST, plus a 4x study."""
    label, small, title = fonts()
    ids = [a['id'] for a in manifest['assets'] if a['category'] == 'painted_resource']
    cell = 128
    image, draw = sheet('res', (MARGIN * 2 + cell * len(ids), 320), FOREST)
    top = header(draw, 'ART-UI-03 painted resources', 'actual 24 px and 32 px, FOREST panel; '
                 'the 4x study below shows the real pixels, nearest neighbour',
                 image.width, TEXT_ON_FOREST, MUTED_ON_FOREST, title, small)
    for column, asset_id in enumerate(ids):
        x = MARGIN + column * cell
        draw.text((x, top), asset_id.split('.')[-1].replace('_', ' ').title(),
                  font=label, fill=TEXT_ON_FOREST)
        image.paste(load(asset_id, 24), (x, top + 26), load(asset_id, 24))
        draw.text((x + 30, top + 30), '24', font=small, fill=MUTED_ON_FOREST)
        image.paste(load(asset_id, 32), (x, top + 60), load(asset_id, 32))
        draw.text((x + 38, top + 68), '32', font=small, fill=MUTED_ON_FOREST)
        big = load(asset_id, 24).resize((96, 96), Image.NEAREST)
        image.paste(big, (x, top + 104), big)
        draw.text((x, top + 204), '24 px at 4x', font=small, fill=MUTED_ON_FOREST)
    image.save(SHEETS / 'art_ui_03_resources.png')
    return 'art_ui_03_resources.png'


def control_sheet(manifest):
    """ART-UI-04 and 05: toolbar art at 24, narrow symbols at 16, controls at 16/18/24."""
    label, small, title = fonts()
    painted = [a['id'] for a in manifest['assets'] if a['category'] == 'painted_command']
    narrow = [a['id'] for a in manifest['assets'] if a['category'] == 'symbolic_narrow']
    control = [a['id'] for a in manifest['assets'] if a['category'] == 'symbolic_control']
    cell = 128
    width = MARGIN * 2 + cell * max(len(painted), len(control))
    image, draw = sheet('ctl', (width, 430), FOREST)
    top = header(draw, 'ART-UI-04 / 05 controls',
                 'wide toolbar art at 24 (was 18), narrow symbolic at 16, '
                 'functional glyphs at 16 / 18 / 24 -- all actual size',
                 width, TEXT_ON_FOREST, MUTED_ON_FOREST, title, small)
    for column, asset_id in enumerate(painted):
        x = MARGIN + column * cell
        draw.text((x, top), asset_id.split('.')[-1].title(), font=label, fill=TEXT_ON_FOREST)
        image.paste(load(asset_id, 24), (x, top + 24), load(asset_id, 24))
        big = load(asset_id, 24).resize((72, 72), Image.NEAREST)
        image.paste(big, (x + 40, top + 24), big)
        draw.text((x, top + 100), '24 px, then 3x', font=small, fill=MUTED_ON_FOREST)
    row = top + 132
    draw.text((MARGIN, row), 'Narrow profile, 16 px symbolic', font=label,
              fill=TEXT_ON_FOREST)
    for column, asset_id in enumerate(narrow):
        x = MARGIN + column * cell
        image.paste(load(asset_id, 16), (x, row + 24), load(asset_id, 16))
        big = load(asset_id, 16).resize((64, 64), Image.NEAREST)
        image.paste(big, (x + 32, row + 20), big)
    row += 108
    draw.text((MARGIN, row), 'Functional controls, 16 / 18 / 24 px', font=label,
              fill=TEXT_ON_FOREST)
    for column, asset_id in enumerate(control):
        x = MARGIN + column * cell
        draw.text((x, row + 24), asset_id.split('.')[-1].title(), font=small,
                  fill=MUTED_ON_FOREST)
        offset = 0
        for size in (16, 18, 24):
            tile = load(asset_id, size)
            image.paste(tile, (x + offset, row + 44), tile)
            offset += size + 8
    image.save(SHEETS / 'art_ui_04_05_controls.png')
    return 'art_ui_04_05_controls.png'


def emblem_sheet(manifest):
    """ART-UI-06: the four generic species medallions at 48 and 64 on PAPER."""
    label, small, title = fonts()
    ids = [a['id'] for a in manifest['assets']
           if a['category'] == 'emblem' and a['id'].endswith('_64')]
    cell = 180
    image, draw = sheet('emb', (MARGIN * 2 + cell * len(ids), 420), PAPER)
    top = header(draw, 'ART-UI-06 species medallions',
                 'generic species identifiers at actual 48 px and 64 px on PAPER -- '
                 'not a portrait of any individual resident',
                 image.width, TEXT_ON_PAPER, MUTED_ON_PAPER, title, small)
    for column, asset_id in enumerate(ids):
        x = MARGIN + column * cell
        small_id = asset_id.replace('_64', '_48')
        draw.text((x, top), asset_id.split('.')[-1].replace('_64', '').title(),
                  font=label, fill=TEXT_ON_PAPER)
        image.paste(load(asset_id, 64), (x, top + 26), load(asset_id, 64))
        image.paste(load(small_id, 48), (x + 76, top + 42), load(small_id, 48))
        draw.text((x, top + 96), '64 px          48 px', font=small, fill=MUTED_ON_PAPER)
        big = load(asset_id, 64).resize((128, 128), Image.NEAREST)
        image.paste(big, (x, top + 116), big)
        draw.text((x, top + 248), '64 px at 2x', font=small, fill=MUTED_ON_PAPER)
    image.save(SHEETS / 'art_ui_06_medallions.png')
    return 'art_ui_06_medallions.png'


def ornament_sheet(manifest):
    """ART-UI-07: the ornament vocabulary, and the five assembled silhouettes beside it."""
    label, small, title = fonts()
    ids = [a['id'] for a in manifest['assets'] if a['category'] == 'ornament']
    panels = Image.open(EXPORTS / 'specimen_panels.png').convert('RGBA')
    width = max(MARGIN * 2 + panels.width, 720)
    image, draw = sheet('orn', (width, panels.height + 240), NEUTRAL)
    top = header(draw, 'ART-UI-01 / 02 / 07 / 08 silhouettes and ornament',
                 'five containers assembled from their own stretched edges and unscaled '
                 'corners; ornament sits at anchors only',
                 width, (24, 30, 26, 255), (58, 64, 58, 255), title, small)
    x = MARGIN
    for asset_id in ids:
        tile = load(asset_id, next(a['optical_widths'][0] for a in manifest['assets']
                                   if a['id'] == asset_id))
        image.paste(tile, (x, top + 14), tile)
        draw.text((x, top + 14 + tile.height + 4), asset_id.split('.')[-1].lower(),
                  font=small, fill=(38, 44, 38, 255))
        x += max(tile.width, 60) + GUTTER
    image.paste(panels, (MARGIN, top + 110), panels)
    draw.text((MARGIN, top + 110 + panels.height + 6),
              'resource tray / time group / map folio / journal / command dock, actual size',
              font=small, fill=(38, 44, 38, 255))
    image.save(SHEETS / 'art_ui_07_ornament_and_silhouettes.png')
    return 'art_ui_07_ornament_and_silhouettes.png'


def main():
    """Write every review sheet and name what was produced."""
    SHEETS.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((UI / 'ui_art_manifest.json').read_text())
    for produced in (resource_sheet(manifest), control_sheet(manifest),
                     emblem_sheet(manifest), ornament_sheet(manifest)):
        print('contact sheet:', SHEETS / produced)


if __name__ == '__main__':
    main()
