#!/usr/bin/env python3
"""The new foods, plants and props art pass, staged for the live demo. Decision 0941.

WHY. Brendan approved an art pass on 2026-10-01 ("Full pass, ~480 credits") for the orchards, foraging,
infirmary, dishes and hives work: eleven world models and 24 icons. Their sources are in the gitignored
provisional library (decision 0188); this makes the game-ready versions into the gitignored
godot/demo/assets/ and returns their manifest rows. The ledger of what was bought is in
docs/art-reference/asset_library/; what each asset replaces is in
docs/art-reference/asset_library/food_art_mapping.json. NOTHING HERE IS WIRED INTO GAMEPLAY: the
branches that draw orchards, forage spots, the infirmary and dishes read these keys after integration.

MODELS. Every model is made in two free steps, both headless Blender:
  1. tools/demo_props_blender.py's prop job, as make_demo_props.py uses it: the high-poly decimated to its
     GAP-04 family budget (godot/assets/lookdev/lookdev_dimensions.gd FAMILY_TRIANGLE_CEILING L0, aimed
     a little under), a fresh UV unwrap, the high-poly's albedo, roughness and normal baked on -- ONE
     material, which is what the seasonal leaf shader needs (season_view.gd dresses surface 0 only);
  2. the asset-pipeline skill's prep_unit.py, --no-rotate (these Meshy outputs MEASURE Y-up), which
     scales the model to its role's height, puts its origin at the ground centre and verifies both.
     --allow-flat for what is deeper than tall (patches, the basket, the infirmary).
So, UNLIKE the older staged models (~1.9 m native, sized at run time by world_sizes.gd / demo_props.gd),
these arrive AT GAME SCALE: each row says `prescaled: true` and its `height_m`. A sizing rule that
divides the target by the manifest's AABB height still works (the factor is 1.0).

Facing: kept as authored, +Z (glTF front). Not checked by any tool -- see the contact sheet.

ICONS. Meshy image-to-image sheets of nine (3 x 3), in the style of the existing pantry icons, are cut
here into 128 px transparent PNGs like make_demo_props.py's renders: the cell's flat grey background is
flood-filled from the cell's border (only what is connected to the border goes, so a pale flour sack
survives), the edge softened, the subject centred with ICON_MARGIN_PX each side on its longest axis.
Rows go to the manifest's top-level "icons" section, {key: {"icon": res://...}}, which
tools/demo_texture_imports.py already finds (it walks the whole manifest for images).

	python3 tools/make_demo_food_art.py                  # everything (needs blender; ~15 minutes)
	python3 tools/make_demo_food_art.py --only apple_tree item_apple
	python3 tools/make_demo_food_art.py --icons-only     # no Blender needed

stage_demo_assets.py calls `stage()`. Each model's result is kept beside it (<key>.made.json, with
the job and the source's SHA-256), so a re-run remakes only what changed.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import io
import json
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"
RES = "res://demo/assets"
BAKER = pathlib.Path(__file__).resolve().parent / "demo_props_blender.py"
PREP = ROOT / ".claude/skills/asset-pipeline/scripts/prep_unit.py"
JOBS = 3

## GAP-04 family: (key, L0 ceiling, texture edge ceiling).
FAMILY = {
	"building": ("building_assembly", 32000, 2048),
	"furniture": ("furniture_instance", 2000, 1024),
	"small_prop": ("small_prop", 1200, 1024),
	"tree": ("tree_large_vegetation", 6000, 2048),
	"ground_cover": ("ground_cover_cluster", 600, 1024),
}

## key: library source, family, triangle target, texture px, staged folder, and its size. `sink_m` is how far
## to let the placed model down into flat ground to hide a base it was modelled on (world_sizes.gd SINK_M's
## meaning, at drawn scale): the pear's concept stood it on a square plate up to 0.12 m thick; the
## infirmary's earth base measures 0.25 m (median) to 0.32 m (90th percentile) at its rim. `height_m` is
## the model's height at game scale; the infirmary is instead fitted to its 8 x 8-tile (16 m) footprint
## under its 5.5 m envelope (BUILDING_MAX_Y_MM). DEMO-ONLY sizes, judged against the DEC-039 creatures (a
## 1.00 m mouse) and what each replaces -- the orchard draws its fruit trees at 0.36 of a 13 m oak (4.7 m).
MODELS = {
	"apple_tree": {"source": "environment/apple_tree/highpoly.glb", "family": "tree", "target": 5800,
		"texture_px": 2048, "folder": "world", "height_m": 4.7},
	"pear_tree": {"source": "environment/pear_tree/highpoly.glb", "family": "tree", "target": 5800,
		"texture_px": 2048, "folder": "world", "height_m": 5.2, "sink_m": 0.15},
	"raspberry_canes": {"source": "environment/raspberry_canes/highpoly.glb", "family": "tree", "target": 3000,
		"texture_px": 1024, "folder": "world", "height_m": 1.4},
	## The library's 2026-09-24 bramble (open canes) shattered into floating clumps at 2,410 and 5,230
	## triangles; this one was generated as a solid mound of grouped leaf masses, like the fruit trees.
	"bramble_blackberry": {"source": "environment/bramble_blackberry/highpoly.glb", "family": "tree",
		"target": 3000, "texture_px": 1024, "folder": "world", "height_m": 1.2, "flat": True},
	"hazel_bush": {"source": "environment/hazel_bush/highpoly.glb", "family": "tree", "target": 3000,
		"texture_px": 1024, "folder": "world", "height_m": 3.0},
	"strawberry_patch": {"source": "environment/strawberry_patch/highpoly.glb", "family": "ground_cover",
		"target": 580, "texture_px": 512, "folder": "world", "height_m": 0.35, "flat": True},
	"mushroom_forage": {"source": "environment/mushroom_forage/highpoly.glb", "family": "ground_cover",
		"target": 580, "texture_px": 512, "folder": "world", "height_m": 0.45, "flat": True},
	"herb_patch": {"source": "environment/herb_patch/highpoly.glb", "family": "ground_cover", "target": 580,
		"texture_px": 512, "folder": "world", "height_m": 0.5, "flat": True},
	"apple_basket": {"source": "prop/apple_basket/highpoly.glb", "family": "small_prop", "target": 1150,
		"texture_px": 512, "folder": "props", "height_m": 0.4, "flat": True},
	"bee_skep": {"source": "prop/bee_skep/highpoly.glb", "family": "furniture", "target": 1900,
		"texture_px": 1024, "folder": "props", "height_m": 0.75},
	## The infirmary's Blender bake left black streaks across its slate roof and walls (rays missing the
	## high-poly's overlapping slates), so it uses Meshy's own 30,000-triangle remesh, as decision 0188's
	## buildings did: `l0` names that file, which is only normalised, not baked.
	"infirmary_ward": {"source": "building/infirmary_ward/highpoly.glb", "l0": "building/infirmary_ward/l0.glb",
		"family": "building", "target": 30000, "texture_px": 2048, "folder": "world", "plan_m": 16.0,
		"max_height_m": 5.5, "flat": True, "sink_m": 0.33},
}

ICON_PX = 128
ICON_MARGIN_PX = 4
SHEET_GRID = 3
## Background: a pixel within this RGB distance of the cell's border median is background, if connected
## to the border; the alpha ramps over the next EDGE_SOFT units, so edges are antialiased, not cut.
BACKGROUND_TOLERANCE = 18.0
EDGE_SOFT = 22.0
## icon key: (sheet, column, row). Sheets are library files; every cell's sheet and position is in the
## ledger (docs/art-reference/asset_library/food_art.json).
ICONS = {
	"item_apple": ("icon/sheet_foods_a/sheet.png", 0, 0),
	"item_pear": ("icon/sheet_foods_a/sheet.png", 1, 0),
	"item_berries": ("icon/sheet_foods_a/sheet.png", 2, 0),
	"item_nuts": ("icon/sheet_foods_a/sheet.png", 0, 1),
	"item_mushrooms": ("icon/sheet_foods_a/sheet.png", 1, 1),
	"item_herb": ("icon/sheet_foods_a/sheet.png", 2, 1),
	"item_potato": ("icon/sheet_foods_a/sheet.png", 0, 2),
	"item_flour": ("icon/sheet_foods_a/sheet.png", 2, 2),
	"item_dried_fish": ("icon/sheet_dishes_b/sheet.png", 0, 0),
	"dish_oatcake": ("icon/sheet_dishes_b/sheet.png", 1, 0),
	"dish_farl": ("icon/sheet_dishes_b/sheet.png", 2, 0),
	"dish_hardtack": ("icon/sheet_dishes_b/sheet.png", 0, 1),
	"dish_salad": ("icon/sheet_dishes_b/sheet.png", 1, 1),
	"dish_baked_fish": ("icon/sheet_dishes_b/sheet.png", 2, 1),
	"dish_biscuit_soup": ("icon/sheet_dishes_b/sheet.png", 0, 2),
	"dish_pasty": ("icon/sheet_dishes_b/sheet.png", 1, 2),
	"dish_root_pie": ("icon/sheet_dishes_b/sheet.png", 2, 2),
	"dish_scones": ("icon/sheet_dishes_c/sheet.png", 0, 0),
	"dish_cordial": ("icon/sheet_dishes_c/sheet.png", 1, 0),
	"dish_woodland_pie": ("icon/sheet_dishes_c/sheet.png", 2, 0),
	"dish_nut_loaf": ("icon/sheet_dishes_c/sheet.png", 0, 1),
	"dish_herb_infusion": ("icon/sheet_dishes_c/sheet.png", 1, 1),
	"dish_bean_hotpot": ("icon/sheet_dishes_c/sheet.png", 2, 1),
	## The honey pot of sheet C (honey showing) replaced sheet A's (an empty-looking clay pot).
	"item_honey": ("icon/sheet_dishes_c/sheet.png", 0, 2),
}


def sha256(path: pathlib.Path) -> str:
	"""The file's SHA-256, streamed."""
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for block in iter(lambda: handle.read(1 << 20), b""):
			digest.update(block)
	return digest.hexdigest()


def res_path(out: pathlib.Path, path: pathlib.Path) -> str:
	"""A staged file's res:// path."""
	return f"{RES}/{path.relative_to(out).as_posix()}"


# --- models ----------------------------------------------------------------------------------

def glb_bounds(path: pathlib.Path) -> tuple[list[float], list[float], int]:
	"""The GLB's POSITION bounds over every primitive (node transforms are identity after Blender's
	export with applied transforms, checked), and its triangle count."""
	data = path.read_bytes()
	length = struct.unpack_from("<I", data, 12)[0]
	doc = json.loads(data[20:20 + length])
	for node in doc["nodes"]:
		if any(k in node for k in ("matrix", "rotation", "scale", "translation")) and "mesh" in node:
			raise RuntimeError(f"{path}: a mesh node carries a transform; bounds would be wrong")
	lo, hi, tris = [1e9] * 3, [-1e9] * 3, 0
	for mesh in doc["meshes"]:
		for prim in mesh["primitives"]:
			acc = doc["accessors"][prim["attributes"]["POSITION"]]
			lo = [min(a, b) for a, b in zip(lo, acc["min"])]
			hi = [max(a, b) for a, b in zip(hi, acc["max"])]
			tris += doc["accessors"][prim["indices"]]["count"] // 3
	return [round(v, 4) for v in lo], [round(v, 4) for v in hi], tris


def glb_texture_px(path: pathlib.Path) -> int:
	"""The widest PNG embedded in a GLB (its IHDR width)."""
	data = path.read_bytes()
	length = struct.unpack_from("<I", data, 12)[0]
	doc = json.loads(data[20:20 + length])
	binary = data[20 + length + 8:]
	widest = 0
	for image in doc.get("images", []):
		view = doc["bufferViews"][image["bufferView"]]
		start = view.get("byteOffset", 0)
		if binary[start:start + 8] == b"\x89PNG\r\n\x1a\n":
			widest = max(widest, struct.unpack_from(">I", binary, start + 16)[0])
	return widest


def shrink_textures(source: pathlib.Path, target: pathlib.Path, edge: int) -> int:
	"""Copy a GLB with every embedded PNG over `edge` px resized to fit it (Lanczos), the buffer rebuilt;
	return the widest map written. Meshy's remeshed L0s carry 4,096 px maps, over GAP-04's building edge."""
	Image, _ = _pil()
	from repair_meshy_rig import read_glb, write_glb
	doc, binary = read_glb(source.read_bytes())
	replaced = {}
	for image in doc.get("images", []):
		view = doc["bufferViews"][image["bufferView"]]
		start = view.get("byteOffset", 0)
		picture = Image.open(io.BytesIO(binary[start:start + view["byteLength"]]))
		if max(picture.size) > edge:
			scale = edge / max(picture.size)
			picture = picture.resize((round(picture.size[0] * scale), round(picture.size[1] * scale)), Image.LANCZOS)
			encoded = io.BytesIO()
			picture.save(encoded, "PNG")
			replaced[image["bufferView"]] = encoded.getvalue()
	rebuilt = b""
	for index, view in enumerate(doc["bufferViews"]):
		start = view.get("byteOffset", 0)
		data = replaced.get(index, binary[start:start + view["byteLength"]])
		rebuilt += b"\x00" * (-len(rebuilt) % 4)
		view["byteOffset"], view["byteLength"] = len(rebuilt), len(data)
		rebuilt += data
	target.write_bytes(write_glb(doc, rebuilt))
	return glb_texture_px(target)


def target_height(spec: dict, baked: pathlib.Path) -> float:
	"""The height to scale to: the spec's, or for a footprint-fitted model the height at which its plan's
	longest side is `plan_m`, capped at `max_height_m`."""
	if "height_m" in spec:
		return spec["height_m"]
	lo, hi, _ = glb_bounds(baked)
	native_h = hi[1] - lo[1]
	plan = max(hi[0] - lo[0], hi[2] - lo[2])
	return round(min(spec["max_height_m"], native_h * spec["plan_m"] / plan), 4)


def run(command: list[str], marker: str | None = None) -> str:
	"""Run a headless Blender command; return its stdout, or raise with its tail."""
	done = subprocess.run(command, capture_output=True, text=True)
	if done.returncode != 0 or (marker and marker not in done.stdout):
		raise RuntimeError(f"{' '.join(command[:4])} failed (exit {done.returncode}):\n"
			f"{done.stdout[-2500:]}\n{done.stderr[-1500:]}")
	return done.stdout


def bake_job(library: pathlib.Path, key: str, scratch: pathlib.Path) -> dict:
	"""demo_props_blender.py's prop job for this key (no icon)."""
	spec = MODELS[key]
	job = {"kind": "prop", "source": str(library / spec["source"]), "glb": str(scratch / f"{key}_baked.glb"),
		"target_triangles": spec["target"], "texture_px": spec["texture_px"],
		"script_sha256": sha256(BAKER), "prep_sha256": sha256(PREP)}
	if "l0" in spec:
		job["l0_sha256"] = sha256(library / spec["l0"])
	return job


def make_model(library: pathlib.Path, out: pathlib.Path, key: str) -> dict:
	"""Bake, normalise and verify one model; return its manifest row."""
	blender = shutil.which("blender")
	if blender is None:
		raise RuntimeError("blender is not on PATH (see docs/ENVIRONMENT.md)")
	spec = MODELS[key]
	with tempfile.TemporaryDirectory() as tmp:
		scratch = pathlib.Path(tmp)
		job = bake_job(library, key, scratch)
		if "l0" in spec:
			job["glb"] = str(scratch / f"{key}_l0.glb")
			edge = shrink_textures(library / spec["l0"], pathlib.Path(job["glb"]), spec["texture_px"])
			result = {"texture_px": edge, "method": f"meshy_remesh, maps resized to {edge} px"}
		else:
			(scratch / "job.json").write_text(json.dumps(job))
			stdout = run([blender, "--background", "--factory-startup", "--python", str(BAKER), "--",
				str(scratch / "job.json")], "RESULT ")
			result = json.loads(next(l for l in stdout.splitlines() if l.startswith("RESULT "))[7:])
		height = target_height(spec, pathlib.Path(job["glb"]))
		staged = out / spec["folder"] / f"{key}.glb"
		staged.parent.mkdir(parents=True, exist_ok=True)
		prep = [blender, "--background", "--factory-startup", "--python", str(PREP), "--", job["glb"],
			str(staged), "--height", str(height), "--no-rotate"] + (["--allow-flat"] if spec.get("flat") else [])
		run(prep, "\nOK")
	return model_row(library, out, key, staged, height, result)


def model_row(library: pathlib.Path, out: pathlib.Path, key: str, staged: pathlib.Path, height: float,
		result: dict) -> dict:
	"""The manifest row for a made model, checked against its budget, height and ground origin."""
	spec = MODELS[key]
	family, ceiling, texture_ceiling = FAMILY[spec["family"]]
	lo, hi, tris = glb_bounds(staged)
	if tris > spec["target"] or tris > ceiling:
		raise RuntimeError(f"{key}: {tris} triangles over its target {spec['target']} / ceiling {ceiling}")
	if result["texture_px"] > texture_ceiling:
		raise RuntimeError(f"{key}: {result['texture_px']} px over the family's {texture_ceiling}")
	if abs(lo[1]) > 0.001 or abs((hi[1] - lo[1]) - height) > 0.002:
		raise RuntimeError(f"{key}: bounds {lo}..{hi} do not stand {height} m tall on y = 0")
	source = library / spec.get("l0", spec["source"])
	return {"category": source.relative_to(library).parts[0], "path": res_path(out, staged), "aabb_min": lo,
		"aabb_max": hi, "height_m": height, "sink_m": spec.get("sink_m", 0.0), "prescaled": True, "family": family, "triangles": tris,
		"triangle_budget": spec["target"], "texture_px": result["texture_px"], "method": result["method"],
		"facing": "+Z", "tool": "tools/make_demo_food_art.py", "decision": "0941",
		"source": spec.get("l0", spec["source"]), "source_sha256": sha256(source)}


def cached_row(library: pathlib.Path, out: pathlib.Path, key: str) -> dict | None:
	"""The row made before from the same source by the same job, if its model is still there."""
	record = out / MODELS[key]["folder"] / f"{key}.made.json"
	if not record.is_file():
		return None
	made = json.loads(record.read_text())
	job = bake_job(library, key, pathlib.Path("/"))
	job.pop("glb")
	same = made.get("job") == job and made.get("spec") == MODELS[key]
	source = library / MODELS[key].get("l0", MODELS[key]["source"])
	if not same or made["row"]["source_sha256"] != sha256(source):
		return None
	return made["row"] if (out / made["row"]["path"][len(RES) + 1:]).is_file() else None


def make_one(library: pathlib.Path, out: pathlib.Path, key: str, force: bool) -> dict:
	"""Make one model (or reuse its cached row), record it, and return its row."""
	row = None if force else cached_row(library, out, key)
	if row is not None:
		print(f"  {key:18} cached ({row['triangles']} tris, {row['height_m']} m)", flush=True)
		return row
	row = make_model(library, out, key)
	job = bake_job(library, key, pathlib.Path("/"))
	job.pop("glb")
	(out / MODELS[key]["folder"] / f"{key}.made.json").write_text(
		json.dumps({"job": job, "spec": MODELS[key], "row": row}, indent=1) + "\n")
	print(f"  {key:18} {row['triangles']:6} tris ({row['family']}, {row['method']}), {row['texture_px']} px, "
		f"{row['height_m']} m", flush=True)
	return row


# --- icons -----------------------------------------------------------------------------------

def _distance(a: tuple, b: tuple) -> float:
	"""Euclidean RGB distance."""
	return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2) ** 0.5


def _pil():
	"""Pillow, imported only when icons are cut, so staging without it still stages the models."""
	try:
		from PIL import Image, ImageFilter
	except ImportError as error:
		raise RuntimeError("cutting icons needs Pillow (python3 -m pip install pillow)") from error
	return Image, ImageFilter


def cut_cell(sheet, column: int, row: int):
	"""One cell of a 3 x 3 sheet (a PIL image) with its border-connected background made transparent."""
	Image, ImageFilter = _pil()
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
	Image, _ = _pil()
	box = cut.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
	if box is None:
		raise RuntimeError("the cell is empty after the background cut")
	subject = cut.crop(box)
	side = ICON_PX - 2 * ICON_MARGIN_PX
	scale = side / max(subject.size)
	subject = subject.resize((max(1, round(subject.size[0] * scale)), max(1, round(subject.size[1] * scale))),
		Image.LANCZOS)
	icon = Image.new("RGBA", (ICON_PX, ICON_PX), (0, 0, 0, 0))
	icon.alpha_composite(subject, ((ICON_PX - subject.size[0]) // 2, (ICON_PX - subject.size[1]) // 2))
	return icon


def make_icons(library: pathlib.Path, out: pathlib.Path, keys: list[str]) -> dict:
	"""Cut every icon in `keys`; return {key: row}."""
	Image, _ = _pil()
	(out / "icons").mkdir(parents=True, exist_ok=True)
	rows, sheets = {}, {}
	for key in keys:
		sheet_path, column, row = ICONS[key]
		if sheet_path not in sheets:
			sheets[sheet_path] = Image.open(library / sheet_path)
		target = out / "icons" / f"{key}.png"
		fit_icon(cut_cell(sheets[sheet_path], column, row)).save(target)
		rows[key] = {"icon": res_path(out, target), "px": ICON_PX, "sheet": sheet_path, "cell": [column, row],
			"sheet_sha256": sha256(library / sheet_path), "tool": "tools/make_demo_food_art.py", "decision": "0941"}
	return rows


# --- staging ---------------------------------------------------------------------------------

def stage(library: pathlib.Path, out: pathlib.Path, keys: list[str] | None = None, force: bool = False,
		models: bool = True) -> dict:
	"""Make the models (JOBS at a time) and icons in `keys` (default all); return {"world": rows,
	"icons": rows, "failed": {key: reason}}. A model that fails is reported and left out."""
	wanted = keys if keys else [*MODELS, *ICONS]
	unknown = [k for k in wanted if k not in MODELS and k not in ICONS]
	if unknown:
		raise RuntimeError(f"unknown keys: {', '.join(unknown)}")
	world, failed = {}, {}
	model_keys = [k for k in wanted if k in MODELS and models and (library / MODELS[k]["source"]).is_file()]
	with concurrent.futures.ThreadPoolExecutor(max_workers=JOBS) as pool:
		futures = {pool.submit(make_one, library, out, key, force): key for key in model_keys}
		for future in concurrent.futures.as_completed(futures):
			try:
				world[futures[future]] = future.result()
			except RuntimeError as error:
				failed[futures[future]] = str(error).strip().splitlines()[0]
	icon_keys = [k for k in wanted if k in ICONS and (library / ICONS[k][0]).is_file()]
	try:
		icons = make_icons(library, out, icon_keys)
	except RuntimeError as error:
		icons, failed["icons"] = {}, str(error)
	for key, reason in failed.items():
		print(f"make_demo_food_art: {key} FAILED: {reason}")
	return {"world": world, "icons": icons, "failed": failed}


def patch_manifest(out: pathlib.Path, made: dict) -> None:
	"""Merge these rows into an existing manifest.json, leaving everything else."""
	path = out / "manifest.json"
	manifest = json.loads(path.read_text()) if path.exists() else {"world": {}, "cast": {}}
	manifest.setdefault("world", {}).update(made["world"])
	manifest.setdefault("icons", {}).update(made["icons"])
	path.write_text(json.dumps(manifest, indent=1) + "\n")


def main() -> int:
	"""Make the art and patch the staged manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--only", nargs="+", help="make only these keys")
	parser.add_argument("--force", action="store_true", help="remake models whose cached result still matches")
	parser.add_argument("--icons-only", action="store_true", help="cut the icons; make no model")
	args = parser.parse_args()
	made = stage(args.library, args.out, args.only, args.force, models=not args.icons_only)
	patch_manifest(args.out, made)
	print(f"make_demo_food_art: {len(made['world'])} models, {len(made['icons'])} icons -> {args.out}; "
		f"{len(made['failed'])} failed")
	return 1 if made["failed"] else 0


if __name__ == "__main__":
	sys.exit(main())
