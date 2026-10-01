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
  props/<key>__<part>.glb  the underground pass's props with their defects fixed (the burrow door's leaf split
                           from its frame, the arch's slab cut out, ...): make_demo_derived_props.py,
                           decision 0371
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

Textures: staging ends by applying tools/demo_texture_imports.py (VRAM compression for the models'
textures, the card atlases and icons packed as files); `--godot godot` on that tool imports whatever
staging added and settles it.

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
from bake_meshy_tail import _channels, _skinning, _worlds_at  # noqa: E402
from repair_meshy_rig import read_accessor, read_glb, write_glb  # noqa: E402
from rig_meshy_tail import mat_mul, node_worlds, transform_point  # noqa: E402
import ground_meshy_clips  # noqa: E402
import make_demo_crop_cards  # noqa: E402
import make_demo_props  # noqa: E402
import make_demo_derived_props  # noqa: E402
import demo_texture_imports  # noqa: E402

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
## Staged where the creature's grounded/ output has it. sleep_normally (Meshy 267 `Sleep_Normally`, decision
## 0204) is the eight cast creatures' sleep in bed (decision 0210); the beaver has none and lies down procedurally.
## cautious_crouch_walk_forward (524) is the eight's walk in a bore they stoop in, and heavy_hammer_swing (128) the
## diggers' strike at the face (mole digger, mole mason, badger quarryman), both decision 0371.
OPTIONAL_CLIPS = ["dive", "sleep_normally", "cautious_crouch_walk_forward", "heavy_hammer_swing"]
SLEEP_CLIP = "sleep_normally"
CROUCH_CLIP = "cautious_crouch_walk_forward"
DIG_CLIP = "heavy_hammer_swing"
HANDS = ("LeftHand", "RightHand")
## Clips pinned again as they are staged, with the grounding step's support tolerance raised to this (m): the mouse
## keeper's crouch walk, whose two contacts the library's grounding left unpinned as "support" (decision 0204: 8.8 cm
## of slide). At 2 cm both pin. The library's grounded clip is untouched; the staged copy is the pinned one, and its
## cast row says so (`repinned`). Decision 0371.
REPIN = {("mouse_keeper", CROUCH_CLIP): 0.02}
## The lying body is measured on every SLEEP_KEY_STEP-th key and every SLEEP_VERTEX_STEP-th body vertex (the tail's
## are left out: the demo's live tail spring places it). Enough to find the lowest point to the millimetre.
SLEEP_KEY_STEP = 4
SLEEP_VERTEX_STEP = 3
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


def _skin_point(mats: list, joints: tuple, weights: tuple, v: tuple) -> tuple[float, float, float]:
	"""One vertex skinned by its influences (column-major 4x4 matrices), in the clip's frame."""
	x = y = z = 0.0
	for j, w in zip(joints, weights):
		if w > 0.0:
			m = mats[j]
			x += w * (m[0] * v[0] + m[4] * v[1] + m[8] * v[2] + m[12])
			y += w * (m[1] * v[0] + m[5] * v[1] + m[9] * v[2] + m[13])
			z += w * (m[2] * v[0] + m[6] * v[1] + m[10] * v[2] + m[14])
	return x, y, z


def _body_vertices(names: list, jnt: list, wgt: list) -> list[int]:
	"""Every SLEEP_VERTEX_STEP-th vertex whose strongest influence is not a tail joint."""
	tail = {s for s, n in enumerate(names) if n.startswith("tail_")}
	return [v for v in range(len(jnt)) if jnt[v][max(range(4), key=lambda q: wgt[v][q])] not in tail][::SLEEP_VERTEX_STEP]


def sleep_row(path: pathlib.Path) -> dict:
	"""How the lying body of a sleep clip sits (decision 0210), measured from its skinned vertices: the LOWEST
	point it reaches over the clip (grounding seats a clip by its legs, so a lying torso sinks below 0 -- decision
	0204 found up to 19.5 cm), the middle of its footprint (x, z) and the way from its hips to its head (x, z,
	unit) at the middle key -- so the demo can lay it on a mattress, head to the pillow."""
	doc, binary = read_glb(path.read_bytes())
	skin, names, ibm, pos, jnt, wgt = _skinning(doc, binary)
	body = _body_vertices(names, jnt, wgt)
	times, animated = _channels(doc, binary)
	low = math.inf
	middle = len(times) // 2
	footprint: list[tuple[float, float, float]] = []
	for k in sorted(set(range(0, len(times), SLEEP_KEY_STEP)) | {middle}):
		worlds = _worlds_at(doc, animated, k)
		mats = [mat_mul(worlds[node], list(ibm[i])) for i, node in enumerate(skin["joints"])]
		points = [_skin_point(mats, jnt[v], wgt[v], pos[v]) for v in body]
		low = min(low, min(p[1] for p in points))
		if k == middle:
			footprint = points
			joint = {doc["nodes"][n].get("name"): worlds[n] for n in skin["joints"]}
	xs, zs = [p[0] for p in footprint], [p[2] for p in footprint]
	head = (joint["Head"][12] - joint["Hips"][12], joint["Head"][14] - joint["Hips"][14])
	length = math.hypot(*head) or 1.0
	return {"floor_y_m": round(low, 4), "centre_m": [round((min(xs) + max(xs)) / 2, 4), round((min(zs) + max(zs)) / 2, 4)],
		"head": [round(head[0] / length, 4), round(head[1] / length, 4)], "length_m": round(max(max(xs) - min(xs), max(zs) - min(zs)), 4)}


def _joint_track(clip: pathlib.Path | bytes, joint: str) -> tuple[list[float], list[list[float]]]:
	"""A clip's (a file's, or its bytes') key times and a joint's world position at each key."""
	times, tracks = _joint_tracks(clip, [joint])
	return times, tracks[0]


def _joint_tracks(clip: pathlib.Path | bytes, joints: list[str]) -> tuple[list[float], list[list[list[float]]]]:
	"""A clip's key times and each of `joints`' world positions at each key, the clip read once."""
	doc, binary = read_glb(clip if isinstance(clip, bytes) else clip.read_bytes())
	indices = [next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == joint) for joint in joints]
	times, animated = _channels(doc, binary)
	worlds = [_worlds_at(doc, animated, k) for k in range(len(times))]
	return times, [[w[index][12:15] for w in worlds] for index in indices]


def crouch_row(crouch: pathlib.Path, walk: pathlib.Path, staged: bytes | None = None) -> dict:
	"""How the crouch walk moves (decision 0371): the speed its planted feet move at -- the grounding step's own measure
	of a gait's ground speed (decision 0202: play it at ground speed over this, or a planted foot slides); the root
	motion it took out (decision 0195) is kept beside it, which is not always the same (the mouse keeper's feet move at
	0.76 m/s, its hips travelled 0.88) -- and how much lower its head goes than the walk's (the median Head height of
	each), so the procedural stoop adds only what is still needed. Measured off `staged` -- the clip as staged, repinned
	when it is (REPIN) -- when given, else off the library's."""
	data = staged if staged is not None else crouch.read_bytes()
	doc, binary = read_glb(data)
	hips = next(n for n in doc["nodes"] if n.get("name") == "Hips")
	root = float(hips.get("extras", {}).get("root_motion", {}).get("mean_speed_m_s", 0.0))
	feet = ground_meshy_clips._foot_contacts(doc, binary, True, True)["speed"] if "skins" in doc else None
	low = statistics.median(p[1] for p in _joint_track(data, "Head")[1])
	high = statistics.median(p[1] for p in _joint_track(walk, "Head")[1])
	return {"speed_m_s": round(feet if feet else root, 4), "root_speed_m_s": round(root, 4),
		"head_drop_m": round(max(high - low, 0.0), 4)}


def repin(data: bytes, tolerance: float) -> tuple[bytes, dict]:
	"""A grounded gait pinned again by the grounding step with its support tolerance raised to `tolerance` (see REPIN):
	the new clip and the pin's report."""
	doc, binary = read_glb(data)
	saved = ground_meshy_clips.PIN_SUPPORT_TOLERANCE_M
	ground_meshy_clips.PIN_SUPPORT_TOLERANCE_M = tolerance
	try:
		binary, report = ground_meshy_clips.pin_feet(doc, binary, True, True)
	finally:
		ground_meshy_clips.PIN_SUPPORT_TOLERANCE_M = saved
	return write_glb(doc, binary), {"support_tolerance_m": tolerance, "contacts": report["contacts"],
		"contacts_pinned": report["contacts_pinned"], "contact_slide_before_m": report["contact_slide_before_m"],
		"unpinned": report["unpinned"]}


def dig_row(path: pathlib.Path) -> dict:
	"""When the dig swing strikes (decision 0371): its length, and the moment its hands come lowest after they were
	highest -- the blow -- so the demo can start a swing that lands as a quantum's cut does."""
	times, (left, right) = _joint_tracks(path, list(HANDS))
	hands = [(a[1] + b[1]) * 0.5 for a, b in zip(left, right)]
	top = max(range(len(hands)), key=lambda k: hands[k])
	blow = min(range(top, len(hands)), key=lambda k: hands[k])
	return {"length_s": round(times[-1], 4), "impact_s": round(times[blow], 4)}


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


def stage_derived(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""The fixed props' rows (make_demo_derived_props.py), or none without Blender -- the demo then draws each one's
	stand-in. A key that failed is left out and reported."""
	try:
		return make_demo_derived_props.stage(library, out)["rows"]
	except RuntimeError as error:
		print(f"stage_demo_assets: derived props skipped, they will be stand-ins: {error}")
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
		staged = {}
		repinned = {}
		for clip in [*CLIPS, *(c for c in OPTIONAL_CLIPS if (grounded / f"anim_{c}.glb").is_file())]:
			data = (grounded / f"anim_{clip}.glb").read_bytes()
			if (key, clip) in REPIN:
				data, repinned[clip] = repin(data, REPIN[(key, clip)])
			staged[clip] = data
			(folder / f"{clip}.glb").write_bytes(strip_to_animation(data))
			clips[clip] = f"res://demo/assets/cast/{key}/{clip}.glb"
		species = key.split("_")[0]
		rows[key] = {"species": species, "height_m": SPECIES_HEIGHT_M[species],
			"tailed": (library / "creature" / key / "tailed").is_dir(),
			"body": f"res://demo/assets/cast/{key}/body.glb", "clips": clips,
			**walk_row(grounded / "anim_walk.glb")}
		if SLEEP_CLIP in clips:
			rows[key]["sleep"] = sleep_row(grounded / f"anim_{SLEEP_CLIP}.glb")
		if CROUCH_CLIP in clips:
			rows[key]["crouch"] = crouch_row(grounded / f"anim_{CROUCH_CLIP}.glb", grounded / "anim_walk.glb",
				staged[CROUCH_CLIP])
		if repinned:
			rows[key]["repinned"] = repinned
		if DIG_CLIP in clips:
			rows[key]["dig"] = dig_row(grounded / f"anim_{DIG_CLIP}.glb")
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
		manifest["world"].update(stage_derived(args.library, args.out))
	if args.only in (None, "cast"):
		manifest["cast"] = stage_cast(args.library, args.out)
	args.out.mkdir(parents=True, exist_ok=True)
	(args.out / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
	for key, row in manifest["cast"].items():
		print(f"  {key:18} walk {row['walk_speed_m_s']:.3f} m/s ({row['walk_speed_source']}; estimate "
			f"{row['walk_speed_estimate_m_s']:.3f})  tailed {row['tailed']}")
	print(f"stage_demo_assets: {len(manifest['world'])} world assets, {len(manifest['cast'])} creatures -> {args.out}")
	stage_texture_imports(args.out)
	return 0


def stage_texture_imports(out: pathlib.Path) -> None:
	"""Put the staged textures' import settings to the rule (tools/demo_texture_imports.py) wherever their
	.import files already exist. A GLB's images are extracted -- and their .import files written -- only
	when Godot imports it, so after staging new models run the settle step, which imports, rewrites and
	reimports until nothing changes (the Windows build runs it itself)."""
	if out.resolve() != demo_texture_imports.ASSETS.resolve():
		print(f"stage_demo_assets: {out} is not the project's demo/assets; texture imports left as they are")
		return
	counts = demo_texture_imports.apply(out, demo_texture_imports.PROJECT)
	print(f"stage_demo_assets: texture imports set ({len(counts['changed'])} changed); to import and compress "
		"what staging added: python3 tools/demo_texture_imports.py --godot godot")


if __name__ == "__main__":
	sys.exit(main())
