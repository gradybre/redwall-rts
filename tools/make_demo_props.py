#!/usr/bin/env python3
"""Game-budget versions of the library's new props and plants, for the live demo. Decision 0196.

WHY. The farm/tunnel and water/bridge/forestry passes (asset library README, 2026-09-29) bought a
concept and a textured HIGH-POLY per asset and NO L0: the game-budget versions are to be made free,
in Blender. This makes them, from the high-poly sources, into the gitignored godot/demo/assets/
(nothing derived from the library is committed, decision 0188):

  props/<key>.glb        every prop: decimated to its GAP-04 family budget (below), a new UV unwrap
                         with the high-poly's albedo, roughness and normal BAKED onto it at the
                         family's texture size, bottom origin (lowest point y = 0, centred on X/Z),
                         facing kept (+Z, glTF front -- the demo turns nothing; a human still has to
                         check each one faces the right way, see the README's facing note)
  icons/<key>.png        the pantry's items and the tunnels' finds and relics: a 128 px
                         transparent render of that L0, one camera and one light rig for all
  plants/<key>.glb       every plant: the same, for what stands above its soil line, the soil line
                         at y = 0 (the concepts stand each plant on a clump of soil, and show the
                         turnip's and carrot's roots below it as a cut-away: both are cut off)
  plants/<key>_cards.png the plant as alpha cards: full front, full side, thinned, sparse
  plants/<key>_tops.png  (rosette plants) the same three seen from straight above

and returns one manifest row per key, with provenance: the source's path and SHA-256, the
family, its budget, the triangles and texture size reached, and how it was reduced.

BUDGETS (GAP-04, `godot/assets/lookdev/lookdev_dimensions.gd` FAMILY_TRIANGLE_CEILING L0), aimed
~4% under the ceiling as the library's own L0s were:
  small_prop           1,150 of 1,200   items, finds, relics, tools, tunnel brace and rubble, gear
  furniture_instance   1,900 of 2,000   boats, jetty, bridges, smoking rack, trunks, plank stack
  ground_cover_cluster   580 of 600     one plant (its close-up mesh; beds draw the cards)
Texture edge: the families' ceiling is 1,024. Furniture bakes at 1,024; small props and plants at
512 -- a carried radish or a relic in a panel is never more than a few dozen pixels on screen, and
every map at 1,024 would cost ~4 MB of video memory per prop for nothing.

	python3 tools/make_demo_props.py                          # everything (needs blender)
	python3 tools/make_demo_props.py --only item_carrot jetty # a few keys; merges into the manifest

stage_demo_assets.py calls this, so a full staging run already includes it. Needs `blender` on
PATH (docs/ENVIRONMENT.md); without it these keys are left out of the manifest and the demo draws
its placeholders. Runs JOBS Blender processes at once; about 7 minutes for everything. Each key's
result is kept beside its model (props/<key>.made.json, with the job -- stamped with the Blender
script's SHA-256 -- and the source's), so a re-run remakes only what changed or is missing; --force
remakes everything.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"
BLENDER_SCRIPT = pathlib.Path(__file__).resolve().parent / "demo_props_blender.py"
RES = "res://demo/assets"
JOBS = 6
ICON_PX = 128
CARD_PX_PER_UNIT = 256

## family: (GAP-04 key, target triangles, texture px)
FAMILIES = {
	"small_prop": ("small_prop", 1150, 512),
	"furniture": ("furniture_instance", 1900, 1024),
	"plant": ("ground_cover_cluster", 580, 512),
}

ITEMS = ["item_radish", "item_turnip", "item_carrot", "item_beetroot", "item_onion", "item_leek", "item_lettuce",
	"item_celery", "item_strawberry", "item_peas", "item_barley", "item_oats",
	"item_trout", "item_perch", "item_eel", "item_shrimp", "item_mussels", "item_hotroot"]
FINDS = ["find_flint", "find_clay", "relic_bell", "relic_key", "relic_banner"]
## The underground pass's seven props (asset library README, "Underground revamp pass"; decision 0204), each in the
## family its size suggests -- root_bin at the furniture budget, since at 1,150 its feet and slats collapsed. Four are
## used as made; make_demo_derived_props.py fixes the other three's known defects from the same high-poly (decision
## 0371): the door split from its frame, the arch's slab cut out, the hand lantern and hanging stores at the furniture
## budget.
UNDERGROUND_PROPS = {"burrow_door": "furniture", "tunnel_arch": "furniture", "hand_lantern": "small_prop",
	"hanging_stores": "small_prop", "root_bin": "furniture", "chimney_pot": "small_prop", "rag_rug": "small_prop"}
## Every prop: key -> family. Most have no L0 at all. basket is rebuilt from its high-poly because its
## library L0 shatters (the README's "Known problems"); the older props this pass puts to use (the
## lantern, the chamber's bed, jars and shelf, the tools) are rebuilt too, because their library L0s
## carry 2,048 px maps -- over GAP-04's 1,024 px ceiling for their families -- and the demo imports
## every map uncompressed (~67 MB of video memory each). The hearth is the burrow home's (decision 0210): it has an
## L0, but its maps are the same 2,048 px.
PROPS = {
	**{key: "small_prop" for key in ITEMS},
	**{key: "small_prop" for key in FINDS},
	**{key: "small_prop" for key in ["tunnel_brace", "tunnel_rubble", "mole_pick", "fishing_rod", "fishing_net",
		"eel_trap", "gnawed_log", "chopping_block", "sapling_basket", "sawhorse", "basket",
		"wall_lantern", "clay_jars", "spade", "hoe", "sickle", "axe"]},
	**{key: "furniture" for key in ["boat_coracle", "boat_rowboat", "boat_raft", "jetty", "smoking_rack",
		"bridge_plank", "bridge_log", "bridge_pier", "felled_trunk", "plank_stack", "bed", "pantry_shelf", "hearth"]},
	**UNDERGROUND_PROPS,
}
ICONS = set(ITEMS) | set(FINDS)

## Every plant: key -> (soil line in the source's glTF y, whether it gets top-down cards).
## The soil line is MEASURED: the 95th percentile height of the source's soil-coloured faces (the
## top of its soil clump), read with the same colour test the tool cuts by; the turnip's clump
## rides up its bulb, so its line is the 80th (-0.186), leaving the purple shoulder showing as a
## turnip's does. Rosettes (a crown of leaves seen from above) get tops; upright plants do not --
## a stand of upright cards covers its own top (crop_cards.gd's finding for wheat).
PLANTS = {
	"plant_radish": (-0.451, True),
	"plant_turnip": (-0.186, True),
	"plant_carrot": (-0.207, True),
	"plant_beetroot": (-0.603, True),
	"plant_onion": (-0.821, False),
	"plant_leek": (-0.826, False),
	"plant_lettuce": (-0.292, True),
	"plant_celery": (-0.744, False),
	"plant_strawberry": (-0.241, True),
	"plant_peas": (-0.798, False),
	"plant_barley": (-0.82, False),
	"plant_oats": (-0.79, False),
}


def category_of(key: str) -> str:
	"""The library family folder of a key."""
	return "environment" if key in PLANTS else "prop"


def source_of(library: pathlib.Path, key: str) -> pathlib.Path:
	"""The high-poly source of a key."""
	return library / category_of(key) / key / "highpoly.glb"


def sha256(path: pathlib.Path) -> str:
	"""The file's SHA-256, streamed."""
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for block in iter(lambda: handle.read(1 << 20), b""):
			digest.update(block)
	return digest.hexdigest()


def prop_job(library: pathlib.Path, out: pathlib.Path, key: str) -> dict:
	"""The Blender job for one prop (and its icon, if it has one)."""
	family, target, texture = FAMILIES[PROPS[key]]
	job = {"kind": "prop", "source": str(source_of(library, key)), "glb": str(out / "props" / f"{key}.glb"),
		"target_triangles": target, "texture_px": texture}
	if key in ICONS:
		job["icon"] = {"path": str(out / "icons" / f"{key}.png"), "px": ICON_PX}
	return job


def plant_job(library: pathlib.Path, out: pathlib.Path, key: str) -> dict:
	"""The Blender job for one plant: its cards, and its close-up mesh."""
	family, target, texture = FAMILIES["plant"]
	soil_y, tops = PLANTS[key]
	folder = out / "plants"
	job = {"kind": "plant", "source": str(source_of(library, key)), "soil_y": soil_y,
		"glb": str(folder / f"{key}.glb"), "target_triangles": target, "texture_px": texture,
		"cards": {"atlas": str(folder / f"{key}_cards.png"), "px_per_unit": CARD_PX_PER_UNIT}}
	if tops:
		job["cards"]["tops"] = str(folder / f"{key}_tops.png")
	return job


def job_for(library: pathlib.Path, out: pathlib.Path, key: str) -> dict:
	"""The job for any key, stamped with the Blender script's SHA-256 so a changed script remakes it."""
	job = plant_job(library, out, key) if key in PLANTS else prop_job(library, out, key)
	job["script_sha256"] = sha256(BLENDER_SCRIPT)
	return job


def run_blender(job: dict) -> dict:
	"""Run one job headless; return what it printed on its RESULT line."""
	blender = shutil.which("blender")
	if blender is None:
		raise RuntimeError("blender is not on PATH (see docs/ENVIRONMENT.md)")
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
		json.dump(job, handle)
	command = [blender, "--background", "--factory-startup", "--python", str(BLENDER_SCRIPT), "--", handle.name]
	done = subprocess.run(command, capture_output=True, text=True)
	pathlib.Path(handle.name).unlink()
	for line in done.stdout.splitlines():
		if line.startswith("RESULT "):
			return json.loads(line[len("RESULT "):])
	raise RuntimeError(f"blender job failed (exit {done.returncode}):\n{done.stdout[-3000:]}\n{done.stderr[-2000:]}")


def res_path(out: pathlib.Path, path: str) -> str:
	"""A staged file's res:// path."""
	return f"{RES}/{pathlib.Path(path).relative_to(out).as_posix()}"


def manifest_row(library: pathlib.Path, out: pathlib.Path, key: str, result: dict) -> dict:
	"""The manifest row for a made key: where it is, how big, and where it came from."""
	kind = "plant" if key in PLANTS else PROPS[key]
	family, target, texture = FAMILIES[kind]
	source = source_of(library, key)
	row = {"category": category_of(key), "path": res_path(out, result["glb"]),
		"aabb_min": result["aabb_min"], "aabb_max": result["aabb_max"], "family": family,
		"triangles": result["triangles"], "triangle_budget": target, "texture_px": result["texture_px"],
		"method": result["method"], "facing": "+Z", "tool": "tools/make_demo_props.py",
		"source": source.relative_to(library).as_posix(), "source_sha256": sha256(source)}
	if "icon" in result:
		row["icon"] = res_path(out, result["icon"]["icon"])
	if key in PLANTS:
		row["cards"] = card_block(out, key, result)
	return row


def card_block(out: pathlib.Path, key: str, result: dict) -> dict:
	"""A plant row's `cards`: its atlas (and tops), cell size in the source's units, cell names, and
	the source's soil line and crown (the close-up mesh has both at its origin)."""
	made = result["cards"]
	block = {"texture": res_path(out, made["atlas"]["path"]), "variants": made["atlas"]["variants"],
		"cell_m": made["cell_m"], "cells": made["cells"], "soil_y": PLANTS[key][0], "crown": result["axis"],
		"half_width": result["half_width"], "height": result["height"]}
	if "tops" in made:
		block["tops"] = {"texture": res_path(out, made["tops"]["path"]), "variants": made["tops"]["variants"],
			"cell_m": made["top_cell_m"]}
	return block


def check_row(key: str, row: dict) -> None:
	"""Refuse a row over its budget or its family's texture ceiling (1,024)."""
	if row["triangles"] > row["triangle_budget"]:
		raise RuntimeError(f"{key}: {row['triangles']} triangles over its budget {row['triangle_budget']}")
	if row["texture_px"] > 1024:
		raise RuntimeError(f"{key}: {row['texture_px']} px textures over the family ceiling 1024")


def cached_row(library: pathlib.Path, out: pathlib.Path, key: str) -> dict | None:
	"""The row of a key made before from the same source by the same job, if its files are all there."""
	record = out / "props" / f"{key}.made.json"
	if not record.is_file():
		return None
	made = json.loads(record.read_text())
	job = job_for(library, out, key)
	if made.get("job") != job or made.get("source_sha256") != sha256(source_of(library, key)):
		return None
	row = made["row"]
	files = [row["path"], row.get("icon", ""), row.get("cards", {}).get("texture", ""),
		row.get("cards", {}).get("tops", {}).get("texture", "")]
	if not all((out / f[len(RES) + 1:]).is_file() for f in files if f):
		return None
	return row


def make_one(library: pathlib.Path, out: pathlib.Path, key: str, force: bool) -> tuple[str, dict]:
	"""Make one key (or reuse its cached row) and return its checked row."""
	row = None if force else cached_row(library, out, key)
	if row is not None:
		print(f"  {key:22} cached ({row['triangles']} tris)", flush=True)
		return key, row
	job = job_for(library, out, key)
	result = run_blender(job)
	row = manifest_row(library, out, key, result)
	check_row(key, row)
	(out / "props" / f"{key}.made.json").write_text(json.dumps(
		{"job": job, "source_sha256": row["source_sha256"], "row": row}, indent=1) + "\n")
	print(f"  {key:22} {row['triangles']:5} tris ({row['family']}, {row['method']}), "
		f"{row['texture_px']} px, {result['seconds']} s", flush=True)
	return key, row


def stage(library: pathlib.Path, out: pathlib.Path, keys: list[str] | None = None, force: bool = False) -> dict:
	"""Make every key (or `keys`), JOBS at a time; return {key: manifest row} for every one made. A
	key that fails is reported and left out (the demo draws its placeholder); the run then raises."""
	for folder in ("props", "icons", "plants"):
		(out / folder).mkdir(parents=True, exist_ok=True)
	wanted = keys if keys else [*PROPS, *PLANTS]
	unknown = [key for key in wanted if key not in PROPS and key not in PLANTS]
	if unknown:
		raise RuntimeError(f"unknown keys: {', '.join(unknown)}")
	rows, failed = {}, {}
	with concurrent.futures.ThreadPoolExecutor(max_workers=JOBS) as pool:
		futures = {pool.submit(make_one, library, out, key, force): key for key in wanted}
		for future in concurrent.futures.as_completed(futures):
			try:
				key, row = future.result()
				rows[key] = row
			except RuntimeError as error:
				failed[futures[future]] = str(error).splitlines()[-1] if str(error) else "failed"
	for key, reason in failed.items():
		print(f"make_demo_props: {key} FAILED: {reason}")
	return {"rows": rows, "failed": failed}


def patch_manifest(out: pathlib.Path, rows: dict) -> None:
	"""Merge these rows into an existing manifest.json's world, leaving everything else."""
	path = out / "manifest.json"
	manifest = json.loads(path.read_text()) if path.exists() else {"world": {}, "cast": {}}
	manifest.setdefault("world", {}).update(rows)
	path.write_text(json.dumps(manifest, indent=1) + "\n")


def main() -> int:
	"""Make the props and plants and patch the staged manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--only", nargs="+", help="make only these keys")
	parser.add_argument("--force", action="store_true", help="remake keys whose cached result still matches")
	args = parser.parse_args()
	made = stage(args.library, args.out, args.only, args.force)
	patch_manifest(args.out, made["rows"])
	print(f"make_demo_props: {len(made['rows'])} keys -> {args.out}; {len(made['failed'])} failed")
	return 1 if made["failed"] else 0


if __name__ == "__main__":
	sys.exit(main())
