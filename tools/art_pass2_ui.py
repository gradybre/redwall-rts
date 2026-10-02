#!/usr/bin/env python3
"""Art pass 2's UI art, cut from its Meshy sheets (decision 0951). Pillow only; no paid call, nothing wired in.

Inputs are the library's (gitignored, decision 0188) `ui/` sheets; outputs go to the gitignored
godot/demo/assets/ui/ beside the demo's other staged files, plus a crop manifest (ART-LOCK-001 §6: keep the
original sheet, the crop coordinates and each export).

  portraits/<cast key>_{48,64}.png   the nine named residents' medallions (ART-LOCK-001 §5's frame: an opaque
                                     I03 roundel, 44 px at 48 and 60 px at 64, an I07 brass ring 1 / 1.5 px with
                                     an I01 contour, the shared oak sprig at lower left, 6x8 / 8x11 px)
  portraits/<cast key>_24.png        the 24 px DIAGNOSTIC (22 px roundel, no sprig): a species test, not a size
                                     to ship (§5)
  portraits/<cast key>_source.png    the 512 px crop the medallions are made from
  tapestry/tapestry_ground.png       the woven ground, wall keyed to transparent (loops and fringe kept)
  tapestry/tapestry_ground_half.png  the same at half size, for a 560 x 640 panel's nine-patch
  tapestry/emblem_<kind>_{24,32,64}.png  the eight embroidered badges, one per tapestry.gd KIND_*
  chronicle/chronicle_page.png       the parchment page, cut inside its deckle (the table it lay on removed)
  art_pass2_ui.json                  every crop box, size and nine-patch margin

	python3 tools/art_pass2_ui.py [--sheets DIR]   # --sheets also writes contact sheets there
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY_CANDIDATES = [ROOT / "assets/library", pathlib.Path.home() / "Developer/redwall-rts/assets/library"]
OUT = ROOT / "godot/demo/assets/ui"

## ART-LOCK-001 §3 pigments.
I01_INK = (0x25, 0x37, 0x2D)
I03_OAT = (0xEA, 0xE1, 0xC8)
I04_CREAM = (0xF5, 0xF0, 0xDF)
I06_LEAF = (0x46, 0x66, 0x47)
I07_BRASS = (0xB4, 0x9A, 0x58)
I09_UMBER = (0x59, 0x43, 0x32)

## Each resident's crop in its 1024 px sheet: (sheet, x, y, side[, inset]). An inset < 1 shrinks the subject
## onto an I03 field, bottom-aligned, where the sheet's frame lines left no room above the ears (the squirrels). Read by eye from the sheets, ears inside,
## cut at the upper chest; the sheets' order is the order the prompts named them.
PORTRAITS = {
	"mouse_keeper": ("sheet_a", 22, 286, 360),
	"mouse_fieldworker": ("sheet_a", 338, 286, 352),
	"mole_digger": ("sheet_a", 664, 300, 360),
	"squirrel_gatherer": ("sheet_b", 80, 300, 276, 0.9),
	"squirrel_forester": ("sheet_b", 375, 300, 276, 0.9),
	"otter_boatwright": ("sheet_b", 680, 362, 262),
	"otter_fisher": ("sheet_c", 92, 330, 285),
	"badger_quarryman": ("sheet_c", 382, 335, 280),
	"beaver_bridgewright": ("sheet_c", 676, 345, 280),
}
## size: (roundel diameter, ring width, sprig box w x h or None) -- ART-LOCK-001 §5.
MEDALLION = {48: (44, 1.0, (6, 8)), 64: (60, 1.5, (8, 11)), 24: (22, 1.0, None)}
SUPER = 8
SOURCE_PX = 512

## The emblem sheet (1376 x 768): badge centres and radius, measured by eye from the sheet; tapestry.gd's
## KIND_* order (founding, the hall, harvest, winter, dressing, milestone, chronicle, event).
EMBLEM_KINDS = ["founding", "hall", "harvest", "winter", "dressing", "milestone", "chronicle", "event"]
EMBLEM_CENTRES = [(216, 221), (530, 221), (845, 221), (1159, 221), (216, 545), (530, 545), (845, 545), (1159, 545)]
EMBLEM_RADIUS = 116
EMBLEM_SIZES = [24, 32, 64, 128]

## The tapestry ground (896 x 1200): the cloth's body (loops above it, fringe below are keyed, not cut).
TAPESTRY_BODY = (66, 112, 830, 1062)
## Its nine-patch margins at full size: the border band ends here (left, top, right, bottom). The bottom is 240 (half
## size 120), past the inner rule's rows (481-483 at half size), so the rule stays in the border band and never repeats in
## the centre (Brendan's ruling of 2026-10-02 on decision 0903; it was 232).
TAPESTRY_PATCH = (180, 226, 178, 240)
WALL_TOLERANCE = 16
## The chronicle page (896 x 1200): the paper inside its deckle edge.
CHRONICLE_PAPER = (74, 82, 826, 1130)


def library() -> pathlib.Path:
	"""The asset library: this checkout's, else the main checkout's (decision 0188)."""
	for candidate in LIBRARY_CANDIDATES:
		if candidate.is_dir():
			return candidate
	raise SystemExit("no assets/library")


def paper_colour(image: Image.Image) -> tuple[int, int, int]:
	"""The crop's paper: the median of its four corner patches."""
	w, h = image.size
	samples: list[tuple[int, int, int]] = []
	for x0, y0 in ((2, 2), (w - 14, 2), (2, h - 14), (w - 14, h - 14)):
		samples.extend(image.crop((x0, y0, x0 + 12, y0 + 12)).getdata())
	return tuple(sorted(s[c] for s in samples)[len(samples) // 2] for c in range(3))


def to_oat(image: Image.Image) -> Image.Image:
	"""Shift the crop's paper onto the I03 field, so every roundel's field is the same pigment."""
	paper = paper_colour(image)
	gains = [I03_OAT[c] / max(paper[c], 1) for c in range(3)]
	bands = [band.point(lambda v, g=g: min(255, int(v * g + 0.5))) for band, g in zip(image.split(), gains)]
	return Image.merge("RGB", bands)


def sprig(w: int, h: int) -> Image.Image:
	"""The shared oak sprig, drawn at SUPER x: a stem and two lobed leaves in I06 with an I01 contour."""
	W, H = w * SUPER, h * SUPER
	layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	draw = ImageDraw.Draw(layer)
	ink = max(2, SUPER // 2)
	draw.line([(W * 0.2, H * 0.98), (W * 0.55, H * 0.45)], fill=I09_UMBER + (255,), width=ink)
	for cx, cy, rx, ry in ((0.42, 0.32, 0.34, 0.30), (0.70, 0.62, 0.28, 0.24)):
		for k in range(3):
			oy = (k - 1) * ry * 0.55
			box = [W * (cx - rx * (0.8 - abs(k - 1) * 0.25)), H * (cy + oy / 1.0 - ry * 0.45),
				W * (cx + rx * (0.8 - abs(k - 1) * 0.25)), H * (cy + oy + ry * 0.45)]
			draw.ellipse(box, fill=I06_LEAF + (255,), outline=I01_INK + (255,), width=ink)
	return layer


def medallion(crop: Image.Image, size: int) -> Image.Image:
	"""One medallion export at `size` (48, 64, or the 24 diagnostic)."""
	diameter, ring, sprig_box = MEDALLION[size]
	S = size * SUPER
	D = diameter * SUPER
	off = (S - D) // 2
	canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	disc = Image.new("L", (S, S), 0)
	ImageDraw.Draw(disc).ellipse([off, off, off + D - 1, off + D - 1], fill=255)
	field = Image.new("RGBA", (S, S), I03_OAT + (255,))
	subject = crop.resize((D, D), Image.LANCZOS).convert("RGBA")
	field.paste(subject, (off, off))
	canvas.paste(field, (0, 0), disc)
	draw = ImageDraw.Draw(canvas)
	ring_px = max(1, round(ring * SUPER))
	contour_px = max(1, round(0.75 * SUPER))
	draw.ellipse([off, off, off + D - 1, off + D - 1], outline=I01_INK + (255,), width=contour_px)
	draw.ellipse([off + contour_px, off + contour_px, off + D - 1 - contour_px, off + D - 1 - contour_px],
		outline=I07_BRASS + (255,), width=ring_px)
	if sprig_box is not None:
		leaf = sprig(*sprig_box)
		## Centred on the ring at lower left (225 degrees), overlapping it as the concept's sprig does.
		at_x = S // 2 - int(D * 0.5 * 0.7071)
		at_y = S // 2 + int(D * 0.5 * 0.7071)
		canvas.alpha_composite(leaf, (max(0, at_x - leaf.size[0] // 2), min(S - leaf.size[1], at_y - leaf.size[1] // 2)))
	return canvas.resize((size, size), Image.LANCZOS)


def portraits(lib: pathlib.Path, out: pathlib.Path) -> dict:
	"""Every resident's source crop and medallions."""
	folder = out / "portraits"
	folder.mkdir(parents=True, exist_ok=True)
	rows = {}
	for key, (sheet, x, y, side, *rest) in PORTRAITS.items():
		source = Image.open(lib / "ui/portraits" / f"{sheet}.png").convert("RGB")
		crop = to_oat(source.crop((x, y, x + side, y + side))).resize((SOURCE_PX, SOURCE_PX), Image.LANCZOS)
		if rest:
			inner = int(SOURCE_PX * rest[0])
			field = Image.new("RGB", (SOURCE_PX, SOURCE_PX), I03_OAT)
			field.paste(crop.resize((inner, inner), Image.LANCZOS), ((SOURCE_PX - inner) // 2, SOURCE_PX - inner))
			crop = field
		crop.save(folder / f"{key}_source.png")
		files = {}
		for size in MEDALLION:
			path = folder / f"{key}_{size}.png"
			medallion(crop, size).save(path)
			files[str(size)] = path.relative_to(out.parent).as_posix()
		rows[key] = {"sheet": f"ui/portraits/{sheet}.png", "crop": [x, y, side, side], "inset": rest[0] if rest else 1.0,
			"files": files}
	return rows


def emblems(lib: pathlib.Path, out: pathlib.Path) -> dict:
	"""The eight tapestry badges, each a circle cut from the sheet with a soft alpha edge."""
	folder = out / "tapestry"
	folder.mkdir(parents=True, exist_ok=True)
	sheet = Image.open(lib / "ui/tapestry/tapestry_emblems_sheet.png").convert("RGB")
	rows = {}
	r = EMBLEM_RADIUS
	for kind, (cx, cy) in zip(EMBLEM_KINDS, EMBLEM_CENTRES):
		cell = sheet.crop((cx - r, cy - r, cx + r, cy + r)).convert("RGBA")
		mask = Image.new("L", (2 * r * 4, 2 * r * 4), 0)
		ImageDraw.Draw(mask).ellipse([6, 6, 8 * r - 7, 8 * r - 7], fill=255)
		cell.putalpha(mask.resize((2 * r, 2 * r), Image.LANCZOS))
		files = {}
		for size in EMBLEM_SIZES:
			path = folder / f"emblem_{kind}_{size}.png"
			cell.resize((size, size), Image.LANCZOS).save(path)
			files[str(size)] = path.relative_to(out.parent).as_posix()
		rows[kind] = {"centre": [cx, cy], "radius": r, "files": files}
	return rows


def key_wall(image: Image.Image, body: tuple[int, int, int, int]) -> Image.Image:
	"""The tapestry with the wall behind its loops and fringe made transparent (never inside the body)."""
	rgba = image.convert("RGBA")
	wall = paper_colour(image)
	px = rgba.load()
	w, h = rgba.size
	for yy in range(h):
		for xx in range(w):
			if body[0] <= xx < body[2] and body[1] <= yy < body[3]:
				continue
			r, g, b, _ = px[xx, yy]
			distance = max(abs(r - wall[0]), abs(g - wall[1]), abs(b - wall[2]))
			if distance < WALL_TOLERANCE:
				px[xx, yy] = (r, g, b, int(255 * max(0, distance - WALL_TOLERANCE // 2) / (WALL_TOLERANCE // 2)))
	return rgba


def tapestry(lib: pathlib.Path, out: pathlib.Path) -> dict:
	"""The woven ground at full and half size, with its nine-patch margins."""
	folder = out / "tapestry"
	folder.mkdir(parents=True, exist_ok=True)
	ground = key_wall(Image.open(lib / "ui/tapestry/tapestry_ground.png").convert("RGB"), TAPESTRY_BODY)
	ground.save(folder / "tapestry_ground.png")
	half = ground.resize((ground.size[0] // 2, ground.size[1] // 2), Image.LANCZOS)
	half.save(folder / "tapestry_ground_half.png")
	return {"full": {"file": "ui/tapestry/tapestry_ground.png", "size": list(ground.size), "body": list(TAPESTRY_BODY),
		"patch_margins_ltrb": list(TAPESTRY_PATCH)},
		"half": {"file": "ui/tapestry/tapestry_ground_half.png", "size": list(half.size),
		"patch_margins_ltrb": [m // 2 for m in TAPESTRY_PATCH]}}


def chronicle(lib: pathlib.Path, out: pathlib.Path) -> dict:
	"""The parchment page, cut inside its deckle edge."""
	folder = out / "chronicle"
	folder.mkdir(parents=True, exist_ok=True)
	page = Image.open(lib / "ui/chronicle/chronicle_page.png").convert("RGB").crop(CHRONICLE_PAPER)
	page.save(folder / "chronicle_page.png")
	return {"file": "ui/chronicle/chronicle_page.png", "crop": list(CHRONICLE_PAPER), "size": list(page.size),
		"text_area_ltrb": [130, 150, page.size[0] - 130, page.size[1] - 150]}


def contact_sheets(out: pathlib.Path, rows: dict, folder: pathlib.Path) -> None:
	"""Review sheets: the medallions at 1x on PANEL and PAPER grounds and at 4x; the emblems; the pages."""
	folder.mkdir(parents=True, exist_ok=True)
	keys = list(rows["portraits"])
	grounds = [(0x2E, 0x45, 0x37), I03_OAT]
	sheet = Image.new("RGB", (len(keys) * 300 + 20, 760), (200, 200, 196))
	draw = ImageDraw.Draw(sheet)
	for i, key in enumerate(keys):
		x = 10 + i * 300
		draw.text((x, 6), key, fill=(0, 0, 0))
		for j, ground in enumerate(grounds):
			draw.rectangle([x, 24 + j * 90, x + 280, 24 + j * 90 + 84], fill=ground)
			cx = x + 6
			for size in (24, 48, 64):
				image = Image.open(out / "portraits" / f"{key}_{size}.png")
				sheet.paste(image, (cx, 34 + j * 90), image)
				cx += size + 14
		big = Image.open(out / "portraits" / f"{key}_64.png").resize((256, 256), Image.NEAREST)
		draw.rectangle([x, 210, x + 280, 480], fill=grounds[0])
		sheet.paste(big, (x + 12, 218), big)
		big48 = Image.open(out / "portraits" / f"{key}_48.png").resize((192, 192), Image.NEAREST)
		draw.rectangle([x, 490, x + 280, 700], fill=I03_OAT)
		sheet.paste(big48, (x + 44, 500), big48)
	sheet.save(folder / "portraits_48_64_24.png")
	em = Image.new("RGB", (8 * 150 + 20, 330), (200, 200, 196))
	d = ImageDraw.Draw(em)
	for i, kind in enumerate(EMBLEM_KINDS):
		x = 10 + i * 150
		d.text((x, 4), kind, fill=(0, 0, 0))
		for j, ground in enumerate([I03_OAT, (0x2E, 0x45, 0x37)]):
			d.rectangle([x, 20 + j * 60, x + 140, 70 + j * 60], fill=ground)
			cx = x + 4
			for size in (24, 32):
				image = Image.open(out / "tapestry" / f"emblem_{kind}_{size}.png")
				em.paste(image, (cx, 26 + j * 60), image)
				cx += size + 8
		image = Image.open(out / "tapestry" / f"emblem_{kind}_128.png")
		em.paste(image, (x + 6, 150), image)
	em.save(folder / "tapestry_emblems.png")
	pages = Image.new("RGB", (1000, 640), (60, 70, 60))
	ground = Image.open(out / "tapestry" / "tapestry_ground_half.png")
	ground.thumbnail((470, 620))
	pages.paste(ground, (10, 10), ground)
	page = Image.open(out / "chronicle" / "chronicle_page.png")
	page.thumbnail((470, 620))
	pages.paste(page, (510, 10))
	pages.save(folder / "tapestry_and_chronicle.png")


def main() -> int:
	"""Cut everything and write the crop manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--sheets", type=pathlib.Path)
	args = parser.parse_args()
	lib = library()
	rows = {"portraits": portraits(lib, OUT), "emblems": emblems(lib, OUT), "tapestry": tapestry(lib, OUT),
		"chronicle": chronicle(lib, OUT)}
	(OUT / "art_pass2_ui.json").write_text(json.dumps(rows, indent=1) + "\n")
	if args.sheets:
		contact_sheets(OUT, rows, args.sheets)
	print(f"art_pass2_ui: {len(rows['portraits'])} portraits, {len(rows['emblems'])} emblems -> {OUT}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
