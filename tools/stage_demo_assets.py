#!/usr/bin/env python3
"""Stage the live demo's assets from the provisional library into godot/demo/assets/. Decision 0196.

The asset library lives outside git (decision 0188), so the demo cannot commit its models. This
copies the chosen ones into the gitignored godot/demo/assets/ and writes manifest.json there,
which the demo scene reads. Without it the demo still runs, on placeholder shapes.

  world/<key>.glb          buildings, environment and props: their L0, unchanged -- except the
                           crops whose L0 shatters (grain, roots), which make_demo_crop_cards.py
                           rebuilds as a bare bed plus alpha-cutout cards of the real plants
  cast/<key>/body.glb      the creature's grounded rigged.glb: mesh, textures, skeleton, tail chain
  cast/<key>/<clip>.glb    each clip STRIPPED to its skeleton and animation. Every clip file
                           repeats the whole mesh and its 2K textures (~17 MB); the demo needs
                           only the animation, and importing 48 copies of the textures is slow.

Measured from the files, not assumed, and written to the manifest:
  * every world asset's axis-aligned bounds (metres), for placement;
  * every creature's WALK SPEED: the walk clip plays in place, so the planted foot slides
    backwards at exactly the speed the creature would cover ground. Moving the creature at
    that speed keeps its feet from sliding. A toe counts as planted only within PLANTED_M of the
    lowest any toe reaches in the whole clip -- measuring against the other toe instead let a
    lifting foot count, and read the squirrel forester 8% fast.

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

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"

WORLD = {
	"building": ["residence", "hall", "kitchen", "well", "workbench", "covered_store", "open_stockpile", "fence"],
	## The README's shattered-foliage L0s (bramble, fern, wildflower, birch, apple) are left out.
	## crop_grain_ripe and crop_roots_ripe shatter too; they are staged by make_demo_crop_cards.py.
	"environment": ["oak_mature", "beech_mature", "oak_sapling", "stump_mossy", "mossy_boulder", "rock_cluster",
		"fallen_log", "grass_tuft", "mushroom_cluster", "reeds", "crop_cabbage_ripe"],
	"prop": ["barrel", "crate", "log_stack", "handcart", "water_bucket", "sack_pile", "table_stools",
		"wheelbarrow", "cauldron_tripod"],
}
CAST = ["mouse_keeper", "mouse_fieldworker", "squirrel_gatherer", "squirrel_forester", "otter_boatwright",
	"otter_fisher", "mole_digger", "badger_quarryman"]
CLIPS = ["idle", "walk", "collect_object", "stand_and_drink", "wave_one_hand", "carry_heavy_object_walk"]
SPECIES_HEIGHT_M = {"mouse": 1.00, "mole": 0.90, "squirrel": 1.15, "otter": 1.49, "badger": 2.55}
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
	for category, keys in WORLD.items():
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


def stage_cast(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""Copy each creature's grounded body, strip its clips, and measure its walk."""
	rows = {}
	for key in CAST:
		grounded = library / "creature" / key / "grounded"
		folder = out / "cast" / key
		folder.mkdir(parents=True, exist_ok=True)
		shutil.copyfile(grounded / "rigged.glb", folder / "body.glb")
		clips = {}
		for clip in CLIPS:
			(folder / f"{clip}.glb").write_bytes(strip_to_animation((grounded / f"anim_{clip}.glb").read_bytes()))
			clips[clip] = f"res://demo/assets/cast/{key}/{clip}.glb"
		species = key.split("_")[0]
		rows[key] = {"species": species, "height_m": SPECIES_HEIGHT_M[species],
			"tailed": (library / "creature" / key / "tailed").is_dir(),
			"body": f"res://demo/assets/cast/{key}/body.glb", "clips": clips,
			"walk_speed_m_s": walk_speed(grounded / "anim_walk.glb")}
	return rows


def main() -> int:
	"""Stage everything and write the manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--only", choices=("world", "cast"), help="stage one half")
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
	if args.only in (None, "cast"):
		manifest["cast"] = stage_cast(args.library, args.out)
	args.out.mkdir(parents=True, exist_ok=True)
	(args.out / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
	for key, row in manifest["cast"].items():
		print(f"  {key:18} walk {row['walk_speed_m_s']:.3f} m/s  tailed {row['tailed']}")
	print(f"stage_demo_assets: {len(manifest['world'])} world assets, {len(manifest['cast'])} creatures -> {args.out}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
