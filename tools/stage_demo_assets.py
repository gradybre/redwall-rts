#!/usr/bin/env python3
"""Stage the live demo's assets from the provisional library into godot/demo/assets/. Decision 0196.

The asset library lives outside git (decision 0188), so the demo cannot commit its models. This
copies the chosen ones into the gitignored godot/demo/assets/ and writes manifest.json there,
which the demo scene reads. Without it the demo still runs, on placeholder shapes.

  world/<key>.glb          buildings, environment and props: their L0, unchanged -- except the
                           crops whose L0 shatters (grain, roots), which make_demo_crop_cards.py
                           rebuilds as a bare bed plus alpha-cutout cards of the real plants
  props/, plants/, icons/  the 2026-09-29 passes' props and plants, which have no L0: made by
                           make_demo_props.py from their high-poly sources (budget meshes, plant
                           cards, item icons)
  cast/<key>/body.glb      the creature's grounded rigged.glb: mesh, textures, skeleton, tail chain
  cast/<key>/<clip>.glb    each clip STRIPPED to its skeleton and animation. Every clip file
                           repeats the whole mesh and its 2K textures (~17 MB); the demo needs
                           only the animation, and importing 48 copies of the textures is slow.

Measured from the files, not assumed, and written to the manifest:
  * every world asset's axis-aligned bounds (metres), for placement;
  * every creature's WALK SPEED: the walk clip plays in place, so the planted foot moves
    backwards at exactly the speed the creature must cover ground for it not to slide. The
    grounding tool now pins each planted foot and RECORDS that speed on the clip's Hips bone
    (`gait.speed_m_s`, decision 0202), and that is what is used. Only a clip without the record
    falls back to the old estimate here (`walk_speed`): the median speed of a toe within PLANTED_M
    of the lowest any toe reaches -- which decision 0202 found counts the SWING toe scraping the
    ground on some walks, and read the squirrel forester 21% fast (0.828 against 0.682). The row
    keeps both, and says which it used.

`--only world|cast` restages one half and MERGES it into an existing manifest.json, so restaging
the cast keeps the world's entries (and the other way round).

    python3 tools/stage_demo_assets.py
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import shutil
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bake_meshy_tail import _channels, _worlds_at  # noqa: E402
from repair_meshy_rig import read_accessor, read_glb, write_glb  # noqa: E402
from rig_meshy_tail import node_worlds, transform_point  # noqa: E402
import make_demo_crop_cards  # noqa: E402
import make_demo_props  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"

WORLD = {
	"building": ["residence", "hall", "kitchen", "well", "workbench", "covered_store", "open_stockpile", "fence"],
	## The README's shattered-foliage L0s (bramble, fern, wildflower, birch, apple) are left out.
	## crop_grain_ripe and crop_roots_ripe shatter too; they are staged by make_demo_crop_cards.py.
	## oak_stump_fresh is the forestry demo's newly felled stump (godot/demo/forestry/).
	"environment": ["oak_mature", "beech_mature", "oak_sapling", "stump_mossy", "oak_stump_fresh", "mossy_boulder",
		"rock_cluster", "fallen_log", "grass_tuft", "mushroom_cluster", "reeds", "crop_cabbage_ripe"],
	"prop": ["barrel", "crate", "log_stack", "handcart", "water_bucket", "sack_pile", "table_stools",
		"wheelbarrow", "cauldron_tripod"],
}
## Older library buildings the farm/tunnel pass puts to use (demo/props/demo_props.gd sizes them): the
## root cellar's door-in-a-mound and the compost bins. Staged like WORLD. (The older props it uses --
## lantern, bed, basket, jars, shelf, tools -- are remade by make_demo_props.py instead: their L0s'
## maps are over budget, or shatter.)
DRESSING = {"building": ["cellar", "composter"]}
## Water-side dressing, placed by godot/demo/water/ (not world_layout.gd). Staged like WORLD.
WATER = {"building": ["boathouse", "weir", "fisher_shelter", "mill"], "prop": ["fish_creel"]}
CAST = ["mouse_keeper", "mouse_fieldworker", "squirrel_gatherer", "squirrel_forester", "otter_boatwright",
	"otter_fisher", "mole_digger", "badger_quarryman"]
## pull_radish is the tunnel digger's clip (godot/demo/tunnel/): no creature has a dig clip, and
## hauling up out of the ground reads closest to one. Staged for every creature, like the others.
## swim and tread_water (every creature) and dive (the otters) are staged for the water gameplay to come
## (decision 0203); the demo's actors do not play them yet (godot/demo/cast/demo_actor.gd CLIPS).
CLIPS = ["idle", "walk", "collect_object", "stand_and_drink", "wave_one_hand", "carry_heavy_object_walk",
	"pull_radish", "swim", "tread_water"]
## Staged where the creature's grounded/ output has it.
OPTIONAL_CLIPS = ["dive"]
## Staged only once its grounded clips exist (the beaver bridgewright, DEC-041, is still going through
## repair -> tail -> ground -> bake): a resident with no special gameplay yet.
OPTIONAL_CAST = ["beaver_bridgewright"]
## DEC-039's heights; the beaver's is DEC-041's proposed 1434 u (1.40 m).
SPECIES_HEIGHT_M = {"mouse": 1.00, "mole": 0.90, "squirrel": 1.15, "otter": 1.49, "badger": 2.55, "beaver": 1.40}
FEET = ("LeftToeBase", "RightToeBase")
PLANTED_M = 0.01       # a toe within this of the clip's lowest toe point is planted


def bounds(doc: dict, binary: bytes) -> tuple[list[float], list[float]]:
	"""World-space AABB of every mesh in the static scene, from each POSITION accessor's min/max."""
	worlds = node_worlds(doc)
	lo, hi = [math.inf] * 3, [-math.inf] * 3
	for index, node in enumerate(doc["nodes"]):
		if "mesh" not in node:
			continue
		for prim in doc["meshes"][node["mesh"]]["primitives"]:
			acc = doc["accessors"][prim["attributes"]["POSITION"]]
			for corner in range(8):
				p = [acc["max"][i] if corner >> i & 1 else acc["min"][i] for i in range(3)]
				w = transform_point(worlds[index], p)
				lo, hi = [min(a, b) for a, b in zip(lo, w)], [max(a, b) for a, b in zip(hi, w)]
	return [round(v, 4) for v in lo], [round(v, 4) for v in hi]


def walk_speed(path: pathlib.Path) -> float:
	"""Median horizontal speed of a planted toe over the in-place walk clip (m/s): a toe is planted
	while it is within PLANTED_M of the lowest point any toe reaches in the whole clip."""
	doc, binary = read_glb(path.read_bytes())
	names = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
	times, animated = _channels(doc, binary)
	toes = [[_worlds_at(doc, animated, k)[names[f]][12:15] for f in FEET] for k in range(len(times))]
	ground = min(t[1] for key in toes for t in key)
	speeds = []
	for k in range(len(times) - 1):
		for f in range(len(FEET)):
			if toes[k][f][1] - ground < PLANTED_M:
				dx = toes[k + 1][f][0] - toes[k][f][0]
				dz = toes[k + 1][f][2] - toes[k][f][2]
				speeds.append(math.hypot(dx, dz) / (times[k + 1] - times[k]))
	return round(statistics.median(speeds), 4)


def gait_speed(path: pathlib.Path) -> float | None:
	"""The in-place gait's ground speed recorded on the clip's Hips bone (decision 0202), or None."""
	doc, _ = read_glb(path.read_bytes())
	for node in doc["nodes"]:
		if node.get("name") == "Hips":
			gait = node.get("extras", {}).get("gait", {})
			if "speed_m_s" in gait:
				return round(float(gait["speed_m_s"]), 4)
	return None


def walk_row(path: pathlib.Path) -> dict:
	"""The cast row's walk fields: the recorded gait speed where there is one, else the estimate."""
	estimate = walk_speed(path)
	recorded = gait_speed(path)
	return {"walk_speed_m_s": recorded if recorded is not None else estimate,
		"walk_speed_source": "gait" if recorded is not None else "toe_slide_estimate",
		"walk_speed_estimate_m_s": estimate}


def strip_to_animation(data: bytes) -> bytes:
	"""The clip without its mesh, materials and images: skeleton and animation only."""
	doc, binary = read_glb(data)
	for node in doc["nodes"]:
		node.pop("mesh", None)
	for key in ("meshes", "materials", "textures", "images", "samplers"):
		doc.pop(key, None)
	doc.pop("extensionsUsed", None)
	doc.pop("extensionsRequired", None)
	return write_glb(doc, binary)


def stage_world(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""Copy each world L0 and measure it."""
	rows = {}
	for category, keys in [*WORLD.items(), *WATER.items(), *DRESSING.items()]:
		for key in keys:
			source = library / category / key / "l0.glb"
			target = out / "world" / f"{key}.glb"
			target.parent.mkdir(parents=True, exist_ok=True)
			shutil.copyfile(source, target)
			lo, hi = bounds(*read_glb(source.read_bytes()))
			rows[key] = {"category": category, "path": f"res://demo/assets/world/{key}.glb", "aabb_min": lo, "aabb_max": hi}
	return rows


def stage_crop_cards(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""The carded crops' rows, or none -- the demo then draws those beds as placeholders."""
	try:
		return make_demo_crop_cards.stage(library, out)
	except RuntimeError as error:
		print(f"stage_demo_assets: crop cards skipped, beds will be placeholders: {error}")
		return {}


def stage_props(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""The made props' and plants' rows (make_demo_props.py), or none without Blender -- the demo then
	draws those keys as placeholders. A key that failed is left out and reported."""
	try:
		return make_demo_props.stage(library, out)["rows"]
	except RuntimeError as error:
		print(f"stage_demo_assets: props skipped, they will be placeholders: {error}")
		return {}


def cast_keys(library: pathlib.Path) -> list[str]:
	"""The creatures to stage: the CAST, and each OPTIONAL_CAST creature whose grounded clips exist."""
	return [*CAST, *(key for key in OPTIONAL_CAST if (library / "creature" / key / "grounded").is_dir())]


def stage_cast(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""Copy each creature's grounded body, strip its clips, and measure its walk."""
	rows = {}
	for key in cast_keys(library):
		grounded = library / "creature" / key / "grounded"
		folder = out / "cast" / key
		folder.mkdir(parents=True, exist_ok=True)
		shutil.copyfile(grounded / "rigged.glb", folder / "body.glb")
		clips = {}
		for clip in [*CLIPS, *(c for c in OPTIONAL_CLIPS if (grounded / f"anim_{c}.glb").is_file())]:
			(folder / f"{clip}.glb").write_bytes(strip_to_animation((grounded / f"anim_{clip}.glb").read_bytes()))
			clips[clip] = f"res://demo/assets/cast/{key}/{clip}.glb"
		species = key.split("_")[0]
		rows[key] = {"species": species, "height_m": SPECIES_HEIGHT_M[species],
			"tailed": (library / "creature" / key / "tailed").is_dir(),
			"body": f"res://demo/assets/cast/{key}/body.glb", "clips": clips,
			**walk_row(grounded / "anim_walk.glb")}
	return rows


def main() -> int:
	"""Stage everything and write the manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--only", choices=("world", "props", "cast"),
		help="stage one part: world (with the crop cards and the props), props alone, or cast")
	args = parser.parse_args()
	manifest = {"tool": "tools/stage_demo_assets.py", "decision": "0196", "facing": "+Z", "world": {}, "cast": {}}
	existing = args.out / "manifest.json"
	if args.only and existing.is_file():
		kept = json.loads(existing.read_text())
		manifest["world"] = kept.get("world", {})
		manifest["cast"] = kept.get("cast", {})
	if args.only in (None, "world"):
		manifest["world"] = stage_world(args.library, args.out)
		manifest["world"].update(stage_crop_cards(args.library, args.out))
	if args.only in (None, "world", "props"):
		manifest["world"].update(stage_props(args.library, args.out))
	if args.only in (None, "cast"):
		manifest["cast"] = stage_cast(args.library, args.out)
	args.out.mkdir(parents=True, exist_ok=True)
	(args.out / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
	for key, row in manifest["cast"].items():
		print(f"  {key:18} walk {row['walk_speed_m_s']:.3f} m/s ({row['walk_speed_source']}; estimate "
			f"{row['walk_speed_estimate_m_s']:.3f})  tailed {row['tailed']}")
	print(f"stage_demo_assets: {len(manifest['world'])} world assets, {len(manifest['cast'])} creatures -> {args.out}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
