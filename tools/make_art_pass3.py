#!/usr/bin/env python3
"""Art pass 3's game-ready models, made from the library (decision 0971). Nothing here is wired in.

Brendan approved art pass 3 on 2026-10-02 ("Let's do the preserving/brewing, digging revamp, free now"; paid calls
delegated under decision 0961, cap 270). Its Meshy outputs live in the gitignored library (decision 0188); this tool
makes the game files from them, free, into the gitignored godot/demo/assets/props/, PRESCALED as pass 1's are
(decision 0941: each row's `height_m` is its height at game scale, origin at the ground centre, facing +Z as
authored):

  1. tools/demo_props_blender.py's prop job: the high-poly decimated to its GAP-04 family budget
     (lookdev_dimensions.gd FAMILY_TRIANGLE_CEILING L0, aimed a little under), a fresh unwrap, the high-poly's
     albedo, roughness and normal baked on -- one material. The L0 is kept in the LIBRARY as <key>/l0.glb.
  2. the timber kit only: tools/art_pass3_blender.py `split_kit` cuts its L0 into the post and the lintel.
  3. the asset-pipeline skill's prep_unit.py, --no-rotate (every source MEASURES Y-up, identity node), scaling to
     the row's height and verifying it; --allow-flat for what is deeper than tall.
  4. the timber kit only: art_pass3_blender.py `assemble_set` builds the standard bore's set from the staged post
     and lintel.

The keys, sizes and the code each file serves are in docs/art-reference/art_pass3_mapping.md. Sizes are PROPOSED
(demo-only), judged against the DEC-039 creatures (a 1.00 m mouse) and the props they stand beside.

	python3 tools/make_art_pass3.py [--only KEY ...]
	python3 tools/make_art_pass3.py --check-ice     # water_iced.gdshader is still water.gdshader plus its ICE lines
	python3 tools/make_art_pass3.py --icons         # cut the nine icons (no Blender; needs Pillow)

ICONS (Brendan's ruling, 2026-10-02: item and dish icons stay in the 3D-render style of the pantry icons). One
nano-banana-2 3x3 sheet conditioned on pass 1's sheet_foods_a, cut here exactly as pass 1 cut its sheets
(make_demo_food_art.py, decision 0941, on art/new-foods; the cutter is repeated here so this branch stands alone):
the cell's border-connected background flood-filled out, the edge softened, the subject centred in a transparent
ICON_PX square with ICON_MARGIN_PX each side on its longest axis. Written to godot/demo/assets/icons/<key>.png, with
their rows in godot/demo/assets/art_pass3_icons.json.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLS = pathlib.Path(__file__).resolve().parent
## The library is the main checkout's (worktrees have none): decision 0188 keeps it outside git.
LIBRARY_CANDIDATES = [ROOT / "assets/library", pathlib.Path.home() / "Developer/redwall-rts/assets/library"]
OUT = ROOT / "godot/demo/assets"
RES = "res://demo/assets"
BAKER = TOOLS / "demo_props_blender.py"
KIT = TOOLS / "art_pass3_blender.py"
PREP = ROOT / ".claude/skills/asset-pipeline/scripts/prep_unit.py"

## GAP-04 family: (key, L0 triangle ceiling, texture edge ceiling) -- lookdev_dimensions.gd.
FAMILY = {
	"furniture": ("furniture_instance", 2000, 1024),
	"small_prop": ("small_prop", 1200, 1024),
}

## key: library source, family, triangle target, texture px, and its size at game scale -- `height_m`, or
## `length_m` (the X extent: the rock face, sized across, not up). DEMO-ONLY sizes beside the 1.00 m mouse, approved by
## Brendan on 2026-10-02 as proposed (DEC-048):
##   crock        waist-high to a mouse, like the library's clay jars (0.55 m)
##   jar shelf    a mouse's chest high
##   ale cask     on its cradle, just under the village's upright barrel (0.95 m); at 0.7 m it read as a keg
##   brew vat     its rim at a mouse's chest, 0.8 m (measured: the rim is 0.84 of the model's height; the paddle
##                stands to the top)
##   rock face    one standard bore's floor across (1.0 m)
MODELS = {
	"crock_stoneware": {"source": "prop/crock_stoneware", "family": "small_prop", "target": 1150, "texture_px": 1024,
		"height_m": 0.5},
	"jar_shelf": {"source": "prop/jar_shelf", "family": "furniture", "target": 1900, "texture_px": 1024,
		"height_m": 0.95},
	"ale_cask": {"source": "prop/ale_cask", "family": "furniture", "target": 1900, "texture_px": 1024,
		"height_m": 0.8},
	"brew_vat": {"source": "prop/brew_vat", "family": "furniture", "target": 1900, "texture_px": 1024,
		"height_m": 0.95, "flat": True},
	"rock_face": {"source": "prop/rock_face", "family": "small_prop", "target": 1150, "texture_px": 1024,
		"length_m": 1.0},
	## The kit's budget is the assembled set's: two posts and a lintel under the furniture family's 2,000.
	"tunnel_timber_kit": {"source": "prop/tunnel_timber_kit", "family": "furniture", "target": 1200,
		"texture_px": 1024, "kit": True},
}
## THE TIMBER KIT (tunnel_marks.gd: a frame stands FRAME_CROWN_SHARE 0.72 of the standard bore's 1.0 m crown and
## is cut away above BRACE_CUT_M 0.62 in the U view; bore_mesh.gd: the standard floor is 1.0 m, 1.1 m at the
## springline). The lintel spans the springline, LINTEL_M long and LINTEL_SECTION_M high (the old box frame's cap
## is 0.09 m; this one is a little heavier); the set stands SET_HEIGHT_M: the lintel sits on the posts' shoulders
## (its housings take their tenons), so the post's shoulder stands SET_HEIGHT_M less the lintel; the posts' outer
## faces stand on the floor's edges, FLOOR_HALF_M out.
LINTEL_M = 1.1
LINTEL_SECTION_M = 0.13
SET_HEIGHT_M = 0.72
FLOOR_HALF_M = 0.5
## The lintel lay on the ground in the concept, its housings up and its underside untextured: it is NOT turned over
## in the set (turned, its bare underside showed along the top).
FLIP_LINTEL = False
KIT_PIECES = {"tunnel_post": "small_prop", "tunnel_lintel": "small_prop", "tunnel_set": "furniture"}


def library() -> pathlib.Path:
	"""The asset library: this checkout's, else the main checkout's."""
	for candidate in LIBRARY_CANDIDATES:
		if candidate.is_dir():
			return candidate
	raise SystemExit("no assets/library (decision 0188: it is local to the main checkout)")


def sha256(path: pathlib.Path) -> str:
	"""The file's SHA-256, streamed."""
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for block in iter(lambda: handle.read(1 << 20), b""):
			digest.update(block)
	return digest.hexdigest()


def glb_bounds(path: pathlib.Path) -> tuple[list[float], list[float], int]:
	"""The GLB's POSITION bounds over every primitive and its triangle count (mesh nodes must carry no
	transform: Blender's export with applied transforms writes none)."""
	data = path.read_bytes()
	length = struct.unpack_from("<I", data, 12)[0]
	doc = json.loads(data[20:20 + length])
	for node in doc["nodes"]:
		if "mesh" in node and any(k in node for k in ("matrix", "rotation", "scale", "translation")):
			raise RuntimeError(f"{path}: a mesh node carries a transform; bounds would be wrong")
	lo, hi, tris = [1e9] * 3, [-1e9] * 3, 0
	for mesh in doc["meshes"]:
		for prim in mesh["primitives"]:
			accessor = doc["accessors"][prim["attributes"]["POSITION"]]
			lo = [min(a, b) for a, b in zip(lo, accessor["min"])]
			hi = [max(a, b) for a, b in zip(hi, accessor["max"])]
			tris += doc["accessors"][prim["indices"]]["count"] // 3
	return [round(v, 4) for v in lo], [round(v, 4) for v in hi], tris


def run(command: list[str], marker: str) -> str:
	"""Run a headless Blender command; return its stdout, or raise with its tail."""
	done = subprocess.run(command, capture_output=True, text=True)
	if done.returncode != 0 or marker not in done.stdout:
		raise RuntimeError(f"{' '.join(command[4:7])} failed (exit {done.returncode}):\n{done.stdout[-2500:]}\n"
			f"{done.stderr[-1500:]}")
	return done.stdout


def blender_job(script: pathlib.Path, job: dict) -> dict:
	"""Run one Blender job file and return its RESULT."""
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
		json.dump(job, handle)
	try:
		stdout = run([blender(), "--background", "--factory-startup", "--python", str(script), "--", handle.name],
			"RESULT ")
	finally:
		pathlib.Path(handle.name).unlink()
	return json.loads(next(line for line in stdout.splitlines() if line.startswith("RESULT "))[7:])


def blender() -> str:
	"""The blender executable."""
	found = shutil.which("blender")
	if found is None:
		raise SystemExit("blender is not on PATH (docs/ENVIRONMENT.md)")
	return found


def prep(source: pathlib.Path, staged: pathlib.Path, height: float, flat: bool) -> None:
	"""prep_unit.py: scale to `height`, origin at the ground centre, verified (it exits 1 on a failed check)."""
	staged.parent.mkdir(parents=True, exist_ok=True)
	run([blender(), "--background", "--factory-startup", "--python", str(PREP), "--", str(source), str(staged),
		"--height", str(height), "--no-rotate"] + (["--allow-flat"] if flat else []), "\nOK")


def height_for(spec: dict, source: pathlib.Path) -> float:
	"""The row's height at game scale: given, or from its `length_m` across X at the source's proportions."""
	if "height_m" in spec:
		return spec["height_m"]
	lo, hi, _ = glb_bounds(source)
	return round(spec["length_m"] * (hi[1] - lo[1]) / (hi[0] - lo[0]), 4)


def bake(lib: pathlib.Path, key: str) -> tuple[pathlib.Path, dict]:
	"""The key's L0 into the library (<source>/l0.glb) by demo_props_blender.py's prop job."""
	spec = MODELS[key]
	folder = lib / spec["source"]
	job = {"kind": "prop", "source": str(folder / "highpoly.glb"), "glb": str(folder / "l0.glb"),
		"target_triangles": spec["target"], "texture_px": spec["texture_px"]}
	return folder / "l0.glb", blender_job(BAKER, job)


def row_for(lib: pathlib.Path, key: str, family: str, staged: pathlib.Path, height: float, made: dict,
		source: str) -> dict:
	"""The staged model's row, checked against its family budget, its height and its ground origin."""
	family_key, ceiling, texture_ceiling = FAMILY[family]
	lo, hi, tris = glb_bounds(staged)
	if tris > ceiling or made["texture_px"] > texture_ceiling:
		raise RuntimeError(f"{key}: {tris} triangles / {made['texture_px']} px over {family_key}'s {ceiling} / "
			f"{texture_ceiling}")
	if abs(lo[1]) > 0.001 or abs((hi[1] - lo[1]) - height) > 0.002:
		raise RuntimeError(f"{key}: bounds {lo}..{hi} do not stand {height} m tall on y = 0")
	return {"path": f"{RES}/{staged.relative_to(OUT).as_posix()}", "aabb_min": lo, "aabb_max": hi,
		"height_m": height, "size_m": [round(hi[i] - lo[i], 3) for i in range(3)], "prescaled": True,
		"family": family_key, "triangles": tris, "texture_px": made["texture_px"], "method": made["method"],
		"facing": "+Z", "tool": "tools/make_art_pass3.py", "decision": "0971", "source": source,
		"source_sha256": sha256(lib / source), "sha256": sha256(staged)}


def make_model(lib: pathlib.Path, key: str) -> dict[str, dict]:
	"""One plain key: bake, normalise, verify."""
	spec = MODELS[key]
	l0, made = bake(lib, key)
	height = height_for(spec, l0)
	staged = OUT / "props" / f"{key}.glb"
	prep(l0, staged, height, spec.get("flat", False))
	return {key: row_for(lib, key, spec["family"], staged, height, made, f"{spec['source']}/highpoly.glb")}


def make_kit(lib: pathlib.Path) -> dict[str, dict]:
	"""The timber kit: bake, split, normalise the lintel (by length) and post (to the set's height), assemble."""
	spec = MODELS["tunnel_timber_kit"]
	folder = lib / spec["source"]
	l0, made = bake(lib, "tunnel_timber_kit")
	split = blender_job(KIT, {"step": "split_kit", "source": str(l0), "post_glb": str(folder / "l0_post.glb"),
		"lintel_glb": str(folder / "l0_lintel.glb"), "lintel_length_m": LINTEL_M, "lintel_section_m": LINTEL_SECTION_M})
	source = f"{spec['source']}/highpoly.glb"
	rows = {}
	lintel_h = LINTEL_SECTION_M
	prep(folder / "l0_lintel.glb", OUT / "props/tunnel_lintel.glb", lintel_h, True)
	rows["tunnel_lintel"] = row_for(lib, "tunnel_lintel", "small_prop", OUT / "props/tunnel_lintel.glb", lintel_h,
		made, source)
	post_h = round((SET_HEIGHT_M - lintel_h) / split["post"]["shoulder_share"], 4)
	prep(folder / "l0_post.glb", OUT / "props/tunnel_post.glb", post_h, False)
	rows["tunnel_post"] = row_for(lib, "tunnel_post", "small_prop", OUT / "props/tunnel_post.glb", post_h, made,
		source)
	assembled = blender_job(KIT, {"step": "assemble_set", "post_glb": str(OUT / "props/tunnel_post.glb"),
		"lintel_glb": str(OUT / "props/tunnel_lintel.glb"), "glb": str(OUT / "props/tunnel_set.glb"),
		"floor_half_m": FLOOR_HALF_M, "flip_lintel": FLIP_LINTEL, "shoulder_share": split["post"]["shoulder_share"]})
	set_h = round(assembled["aabb_max"][1] - assembled["aabb_min"][1], 4)
	rows["tunnel_set"] = row_for(lib, "tunnel_set", "furniture", OUT / "props/tunnel_set.glb", set_h, made, source)
	rows["tunnel_set"]["post_centre_x_m"] = assembled["post_centre_x_m"]
	for role in ("post", "lintel"):
		rows[f"tunnel_{role}"]["split"] = split[role]
	return rows


ICON_PX = 128
ICON_MARGIN_PX = 4
SHEET_GRID = 3
BACKGROUND_TOLERANCE = 18.0
EDGE_SOFT = 22.0
ICON_SHEET = "icon/sheet_preserves_finds/sheet.png"
## icon key: (column, row) in ICON_SHEET. The keys are proposed; the features that use them name the final ones.
ICONS = {
	"item_jam": (0, 0), "item_pickles": (1, 0), "item_dried_fruit": (2, 0),
	"item_cheese": (0, 1), "item_ale": (1, 1), "item_cider": (2, 1),
	"find_coins": (0, 2), "find_old_map": (1, 2), "find_spring": (2, 2),
}


def _distance(a: tuple, b: tuple) -> float:
	"""Euclidean RGB distance."""
	return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def cut_cell(sheet, column: int, row: int):
	"""One cell of a 3 x 3 sheet (a PIL image) with its border-connected background made transparent."""
	from PIL import Image, ImageFilter
	w, h = sheet.size[0] // SHEET_GRID, sheet.size[1] // SHEET_GRID
	cell = sheet.crop((column * w, row * h, (column + 1) * w, (row + 1) * h)).convert("RGB")
	px = cell.load()
	border = [px[x, y] for x in range(w) for y in (0, h - 1)] + [px[x, y] for y in range(h) for x in (0, w - 1)]
	background = tuple(sorted(c[i] for c in border)[len(border) // 2] for i in range(3))
	alpha = Image.new("L", (w, h), 255)
	pa = alpha.load()
	seen = bytearray(w * h)
	stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
	while stack:
		x, y = stack.pop()
		if seen[y * w + x]:
			continue
		seen[y * w + x] = 1
		d = _distance(px[x, y], background)
		if d > BACKGROUND_TOLERANCE + EDGE_SOFT:
			continue
		pa[x, y] = int(255 * max(0.0, d - BACKGROUND_TOLERANCE) / EDGE_SOFT)
		if d <= BACKGROUND_TOLERANCE:
			stack.extend((nx, ny) for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
				if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx])
	alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
	out = cell.convert("RGBA")
	out.putalpha(alpha)
	return out


def fit_icon(cut):
	"""The cut subject centred on a transparent ICON_PX square, its longest side ICON_PX - 2 margins."""
	from PIL import Image
	box = cut.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
	if box is None:
		raise RuntimeError("the cell is empty after the background cut")
	subject = cut.crop(box)
	scale = (ICON_PX - 2 * ICON_MARGIN_PX) / max(subject.size)
	subject = subject.resize((max(1, round(subject.size[0] * scale)), max(1, round(subject.size[1] * scale))),
		Image.LANCZOS)
	icon = Image.new("RGBA", (ICON_PX, ICON_PX), (0, 0, 0, 0))
	icon.alpha_composite(subject, ((ICON_PX - subject.size[0]) // 2, (ICON_PX - subject.size[1]) // 2))
	return icon


def make_icons(lib: pathlib.Path) -> int:
	"""Cut every icon of ICON_SHEET into OUT/icons/; write their rows to OUT/art_pass3_icons.json."""
	from PIL import Image
	sheet = Image.open(lib / ICON_SHEET)
	(OUT / "icons").mkdir(parents=True, exist_ok=True)
	rows = {}
	for key, (column, row) in ICONS.items():
		target = OUT / "icons" / f"{key}.png"
		fit_icon(cut_cell(sheet, column, row)).save(target)
		rows[key] = {"icon": f"{RES}/icons/{key}.png", "px": ICON_PX, "sheet": ICON_SHEET, "cell": [column, row],
			"sheet_sha256": sha256(lib / ICON_SHEET), "sha256": sha256(target), "tool": "tools/make_art_pass3.py",
			"decision": "0971"}
		print(f"  {key:18} {ICON_SHEET} {column},{row}", flush=True)
	(OUT / "art_pass3_icons.json").write_text(json.dumps(rows, indent=1, sort_keys=True) + "\n")
	return 0


def check_ice() -> int:
	"""Whether godot/demo/water/water_iced.gdshader is water.gdshader verbatim apart from its own header and the lines
	marked `// ICE` (decision 0971): 0 if so, 1 with the first difference if not."""
	water = (ROOT / "godot/demo/water/water.gdshader").read_text().splitlines()
	iced = (ROOT / "godot/demo/water/water_iced.gdshader").read_text().splitlines()
	body = [line for line in iced[iced.index(water[0]):] if not line.rstrip().endswith("// ICE")]
	for number, (want, have) in enumerate(zip(water, body), start=1):
		if want != have:
			print(f"water_iced.gdshader differs from water.gdshader at its line {number}:\n  {want}\n  {have}")
			return 1
	if len(water) != len(body):
		print(f"water_iced.gdshader has {len(body)} body lines, water.gdshader {len(water)}")
		return 1
	print("water_iced.gdshader matches water.gdshader apart from its ICE lines")
	return 0


def main() -> int:
	"""Make every model (or `--only` ones) and merge their rows into OUT/art_pass3_models.json."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--only", nargs="+", choices=list(MODELS))
	parser.add_argument("--check-ice", action="store_true")
	parser.add_argument("--icons", action="store_true")
	args = parser.parse_args()
	if args.check_ice:
		return check_ice()
	if args.icons:
		return make_icons(library())
	lib = library()
	record = OUT / "art_pass3_models.json"
	rows = json.loads(record.read_text()) if record.exists() else {}
	for key in args.only or list(MODELS):
		made = make_kit(lib) if MODELS[key].get("kit") else make_model(lib, key)
		rows.update(made)
		record.write_text(json.dumps(rows, indent=1, sort_keys=True) + "\n")
		for name, row in made.items():
			print(f"  {name:18} {row['triangles']:5} tris  {row['texture_px']} px  {row['height_m']} m tall  "
				f"size {row['size_m']}", flush=True)
	return 0


if __name__ == "__main__":
	sys.exit(main())
