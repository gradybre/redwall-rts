#!/usr/bin/env python3
"""Rebuild the live demo's shattered crop beds as a bed mesh plus alpha-cutout plant cards. Decision 0196.

WHY. Meshy's L0 remesh shatters thin foliage (the asset library README's "Known problems" lists
bramble, fern, wildflower, birch, apple and beans). crop_grain_ripe and crop_roots_ripe have the
same failure: 655 and 898 triangles cannot carry wheat stalks or feathery carrot tops, so they
render as paper shards. The README's own prescription is "build the L0 ... as leaf cards with
alpha". The grain concept also put a small well in the middle of the bed, which Meshy modelled;
a well does not belong in a grain bed, and the cards simply never include it.

WHAT IT MAKES, from the library's HIGH-POLY sources (whose geometry is good), into the gitignored
godot/demo/assets/world/ -- nothing derived from the library is committed (decision 0188):

  crop_bed.glb                   the wooden frame and dark soil of the roots bed, plants cut
                                 off (by height, and by colour at the soil), decimated; shared by both beds because the grain source's
                                 soil is textured with projected straw and never shows as soil
  crop_grain_ripe_cards.png      six narrow clumps of the real wheat, rendered to an RGBA atlas
  crop_roots_ripe_cards.png      three real carrot plants and two real turnips
  crop_roots_ripe_tops.png       the same five plants from straight above

and rewrites those two keys' rows in manifest.json to point at them (the row gains a "cards"
block the demo world reads). How the cards are rendered is in demo_crop_cards_blender.py.

	python3 tools/make_demo_crop_cards.py                      # after stage_demo_assets.py
	python3 tools/make_demo_crop_cards.py --library <path>     # the library lives outside git

stage_demo_assets.py calls this for the same keys, so a full staging run already includes it.
Needs `blender` on PATH (docs/ENVIRONMENT.md); without it the two keys are left out of the
manifest and the demo draws them as placeholders. Takes a few minutes: the sources are 7-8
million triangles each.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"
BLENDER_SCRIPT = pathlib.Path(__file__).resolve().parent / "demo_crop_cards_blender.py"
RES_WORLD = "res://demo/assets/world"

## Every length below is in the high-poly sources' own glTF units (Y up, +Z front; Meshy
## normalises every source to ~1.9 on its longest axis, so the two sources share a scale).
## Measured from the files with a height histogram and an orthographic top render.

## The roots source: soil surface ~ -0.088, frame top -0.058, plants above.
ROOTS_SOIL_Y = -0.088
BED_CUT_Y = -0.056
BED_TRIANGLES = 24000
## The frame's inner edge, as a half-width: plants are placed inside it.
BED_INNER_HALF = 0.86

## Leaves are gathered from this far beyond a region's box, so a leaf centred inside it is whole.
REGION_REACH = 0.2
## How far a plant region may move to centre itself on a crown.
CROWN_SNAP = 0.12

## Card cells: every region of one source is framed identically, so one card size fits all.
CARD_PX_PER_UNIT = 1190

CROPS = {
	"crop_grain_ripe": {
		"source": "environment/crop_grain_ripe/highpoly.glb",
		"soil_y": -0.15,
		"cell_m": [0.24, 0.43],
		## Narrow clumps of wheat, a few stalks each, away from the modelled well and the frame.
		## A stalk belongs to a clump when its centre does; it is never cut at the clump's edge.
		## Few stalks per card keeps the gaps between ears that make a stand read as wheat; a wide
		## strip renders as a solid mat of straw.
		"regions": [
			{"kind": "wheat", "centre": [-0.55, -0.55], "half": [0.06, 0.03]},
			{"kind": "wheat", "centre": [0.55, -0.5], "half": [0.06, 0.03]},
			{"kind": "wheat", "centre": [-0.5, 0.58], "half": [0.06, 0.03]},
			{"kind": "wheat", "centre": [0.52, 0.55], "half": [0.06, 0.03]},
			{"kind": "wheat", "centre": [-0.62, 0.05], "half": [0.06, 0.03]},
			{"kind": "wheat", "centre": [0.6, 0.0], "half": [0.06, 0.03]},
		],
		## No top-down render: a dense stand of narrow cards covers its own top, and flat canopy
		## patches laid over it were tried and read as shelves.
	},
	"crop_roots_ripe": {
		"source": "environment/crop_roots_ripe/highpoly.glb",
		"soil_y": -0.07,
		"cell_m": [0.42, 0.32],
		## One plant each. The centre is a guess read off a top render; the box snaps onto the
		## nearest crown within "snap", then keeps the leaves centred in its share of the grid
		## (carrots are ~0.2 apart, turnips ~0.34).
		"regions": [
			{"kind": "carrot", "centre": [-0.316, 0.46], "half": [0.1, 0.09], "snap": CROWN_SNAP},
			{"kind": "carrot", "centre": [0.27, 0.17], "half": [0.1, 0.09], "snap": CROWN_SNAP},
			{"kind": "carrot", "centre": [-0.1, 0.69], "half": [0.1, 0.09], "snap": CROWN_SNAP},
			{"kind": "turnip", "centre": [0.02, -0.41], "half": [0.17, 0.14], "snap": CROWN_SNAP},
			{"kind": "turnip", "centre": [-0.34, -0.71], "half": [0.17, 0.14], "snap": CROWN_SNAP},
		],
		## Each plant again from straight above; the demo lays it flat over its standing cards.
		"top_cell_m": [0.42, 0.42],
		"top_regions": "same",
	},
}
BED_SOURCE = "environment/crop_roots_ripe/highpoly.glb"


def cell_px(cell_m: list[float]) -> list[int]:
	"""Pixel size of one atlas cell: the same density for every crop, even numbers."""
	return [int(round(v * CARD_PX_PER_UNIT / 2.0)) * 2 for v in cell_m]


def _regions(crop: dict, regions: list[dict]) -> list[dict]:
	"""Regions as the Blender script takes them."""
	return [{"kind": r["kind"], "centre": r["centre"], "half": r["half"], "reach": REGION_REACH,
		"snap": r.get("snap", 0.0), "soil_y": crop["soil_y"]} for r in regions]


def top_regions(crop: dict) -> list[dict]:
	"""The regions rendered from above: none, their own list, or "same" as the standing cards."""
	regions = crop.get("top_regions", [])
	return crop["regions"] if regions == "same" else regions


def card_job(key: str, library: pathlib.Path, world: pathlib.Path) -> dict:
	"""The Blender job that renders one crop's standing and top-down atlases."""
	crop = CROPS[key]
	front = {"view": "front", "atlas": str(world / f"{key}_cards.png"), "cell_m": crop["cell_m"],
		"cell_px": cell_px(crop["cell_m"]), "regions": _regions(crop, crop["regions"])}
	atlases = [front]
	if top_regions(crop):
		atlases.append({"view": "top", "atlas": str(world / f"{key}_tops.png"), "cell_m": crop["top_cell_m"],
			"cell_px": cell_px(crop["top_cell_m"]), "regions": _regions(crop, top_regions(crop))})
	return {"source": str(library / crop["source"]), "cards": atlases}


def bed_job(library: pathlib.Path, world: pathlib.Path) -> dict:
	"""The Blender job that cuts, decimates and exports the shared bed."""
	return {"source": str(library / BED_SOURCE), "bed": {
		"glb": str(world / "crop_bed.glb"), "cut_y": BED_CUT_Y, "inner_half": BED_INNER_HALF,
		"target_triangles": BED_TRIANGLES}}


def run_blender(job: dict) -> dict:
	"""Run one job headless and return what it printed on its RESULT line."""
	blender = shutil.which("blender")
	if blender is None:
		raise RuntimeError("blender is not on PATH (see docs/ENVIRONMENT.md)")
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
		json.dump(job, handle)
	command = [blender, "--background", "--factory-startup", "--python", str(BLENDER_SCRIPT), "--", handle.name]
	done = subprocess.run(command, capture_output=True, text=True)
	pathlib.Path(handle.name).unlink()
	for line in done.stdout.splitlines():
		if line.startswith("demo_crop_cards:"):
			print("  " + line)
		if line.startswith("RESULT "):
			return json.loads(line[len("RESULT "):])
	raise RuntimeError(f"blender job failed (exit {done.returncode}):\n{done.stdout[-3000:]}\n{done.stderr[-3000:]}")


def cleanup_cells(world: pathlib.Path) -> None:
	"""Remove the per-cell renders; only the atlases are kept."""
	for cell in world.glob("*_*.png.cell*.png"):
		cell.unlink()


def manifest_row(key: str, bed: dict) -> dict:
	"""The manifest row for a carded crop: the shared bed, plus the cards it carries."""
	crop = CROPS[key]
	kinds: dict[str, list[int]] = {}
	for index, region in enumerate(crop["regions"]):
		kinds.setdefault(region["kind"], []).append(index)
	# The bed was lifted so its base is y = 0; the soil moves with it.
	soil = ROOTS_SOIL_Y + bed["lifted_by"]
	cards = {"texture": f"{RES_WORLD}/{key}_cards.png", "variants": len(crop["regions"]),
		"cell_m": crop["cell_m"], "kinds": kinds, "soil_y": round(soil, 4),
		"inner": [-BED_INNER_HALF, BED_INNER_HALF, -BED_INNER_HALF, BED_INNER_HALF], "source": crop["source"]}
	if top_regions(crop):
		cards["tops"] = {"texture": f"{RES_WORLD}/{key}_tops.png", "variants": len(top_regions(crop)),
			"cell_m": crop["top_cell_m"]}
	return {"category": "environment", "path": f"{RES_WORLD}/crop_bed.glb",
		"aabb_min": bed["aabb_min"], "aabb_max": bed["aabb_max"], "cards": cards}


def stage(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""Build the bed and every crop's cards; return {key: manifest row}."""
	world = out / "world"
	world.mkdir(parents=True, exist_ok=True)
	print("make_demo_crop_cards: cutting the bed from the roots source")
	bed = run_blender(bed_job(library, world))["bed"]
	rows = {}
	for key in CROPS:
		print(f"make_demo_crop_cards: rendering {key} cards")
		run_blender(card_job(key, library, world))
		rows[key] = manifest_row(key, bed)
	cleanup_cells(world)
	return rows


def patch_manifest(out: pathlib.Path, rows: dict) -> None:
	"""Replace the carded keys' rows in an existing manifest.json, leaving everything else."""
	path = out / "manifest.json"
	manifest = json.loads(path.read_text()) if path.exists() else {"world": {}, "cast": {}}
	manifest.setdefault("world", {}).update(rows)
	path.write_text(json.dumps(manifest, indent=1) + "\n")


def main() -> int:
	"""Build the carded crops and patch the staged manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	args = parser.parse_args()
	rows = stage(args.library, args.out)
	patch_manifest(args.out, rows)
	print(f"make_demo_crop_cards: {', '.join(rows)} -> {args.out / 'world'}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
