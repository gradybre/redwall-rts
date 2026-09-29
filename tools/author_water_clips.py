#!/usr/bin/env python3
"""Author the water clips -- surface swim, tread-water, and the otters' dive -- for every rigged creature.

Decision 0203. Meshy's action catalogue cannot be listed without spending, and none of its clips is known
to swim, so these are AUTHORED: each clip is a function of phase that poses Meshy's own 24-joint humanoid,
written as ordinary glTF keys into a copy of the creature's raw `rigged.glb`. Nothing is re-exported: the
file keeps Meshy's mesh, skin, material and 0.01 Armature byte for byte, and only its animation is new, so
the four-step chain (repair, tail, ground, bake) takes it exactly as it takes a Meshy clip.

THE POSE LANGUAGE. Each joint's pose is a rotation R in CHARACTER axes -- the rest pose's own +X (the
creature's left), +Y (up) and +Z (front, glTF's) -- applied in its parent's posed frame. Its local key is
then B_p^T R B_p L0, where B_p is the parent's rest world rotation and L0 the joint's rest local rotation,
so R = identity is the rest pose exactly. A left/right pair is mirrored across the creature's midplane: a
rotation about X is the same on both sides, one about Y or Z changes sign. The same numbers therefore pose
every creature: a squirrel and a badger bend the same joints the same way, at their own bone lengths.

THE WATERLINE IS y = 0. Every water clip is authored against the water surface, not the ground:
  * SURFACE clips (swim, tread-water) hold the `neck` joint at `neck_y` (a share of the creature's height)
    on every key, plus a small bob. The head rides above the surface and the body below it.
  * SUBMERGED clips (dive) hold `Spine01` at `spine_y`, so the whole body is under the surface.
The game places a swimmer's root at the water surface (or, diving, at the surface), exactly as it places a
walker's root on the ground. `tools/ground_meshy_clips.py` checks the convention and never lifts, seats or
pins a water clip (its WATER_CLIPS).

Every clip is in place (the hips keep their rest x and z) and loops: the last key repeats the first, as in
Meshy's clips. Keys are at 30 Hz from 1/30 s, as Meshy's are. Nothing here decides a swimming speed: that
is movement's (MOVE-G01), and the clip records only its period.

	python3 tools/author_water_clips.py              # author every rigged creature's water clips
	python3 tools/author_water_clips.py --dry-run    # author and report, write nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bake_meshy_tail import _worlds_at  # noqa: E402
from ground_meshy_clips import _basis, _compose, _quat, _quats, _transpose, world_in_parent_space  # noqa: E402
from repair_meshy_rig import RepairRefused, append_accessor, geometry_height_m, read_glb, write_glb  # noqa: E402
from rig_meshy_tail import node_worlds  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library/creature"
MANIFEST = ROOT / "docs/art-reference/asset_library/authored.json"
OUT_DIR = "authored"
STAMP = "redwall_authored_clip"
STAMP_VERSION = 1
KEY_RATE_HZ = 30
SIDES = ("Left", "Right")
JOINTS = ("Hips", "Spine02", "Spine01", "Spine", "neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase")
SURFACE, SUBMERGED = "surface", "submerged"


class AuthorRefused(RepairRefused):
	"""A creature or clip this tool must not author, with the reason."""


# --- rotations in character axes (three unit columns, as ground_meshy_clips keeps them) --------------

def rot_x(degrees: float) -> list[list[float]]:
	"""About the creature's left-right axis: + pitches the top forward (+Y towards +Z)."""
	c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
	return [[1.0, 0.0, 0.0], [0.0, c, s], [0.0, -s, c]]


def rot_y(degrees: float) -> list[list[float]]:
	"""About the vertical: + turns +Z towards +X (the creature's left)."""
	c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
	return [[c, 0.0, -s], [0.0, 1.0, 0.0], [s, 0.0, c]]


def rot_z(degrees: float) -> list[list[float]]:
	"""About the front-back axis: + turns +X towards +Y."""
	c, s = math.cos(math.radians(degrees)), math.sin(math.radians(degrees))
	return [[c, s, 0.0], [-s, c, 0.0], [0.0, 0.0, 1.0]]


def chain(*rotations: list) -> list[list[float]]:
	"""The product of rotations, the LAST applied first: chain(a, b) turns by b, then by a."""
	out = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
	for r in rotations:
		out = _compose(out, r)
	return out


def mirrored(side: str, x: float = 0.0, y: float = 0.0, z: float = 0.0) -> list[list[float]]:
	"""An X, then Y, then Z turn given for the LEFT side, mirrored for the right: Y and Z change sign."""
	sign = 1.0 if side == "Left" else -1.0
	return chain(rot_z(sign * z), rot_y(sign * y), rot_x(x))


# --- the poses -------------------------------------------------------------------------------------
#
# Each style returns, for a phase in [0, 1), {joint: R} and the anchor's height as a share of the creature's
# height. Degrees throughout. A "+swing" arm moves forward, "+down" lowers it from the T-pose, "+flex" bends
# an elbow or knee, a "+hip" flexion raises the thigh forward, "+point" points the toes.

def _arm(side: str, down: float, swing: float, flex: float, hand: float = 0.0, sweep: float = 0.0) -> dict:
	"""One arm: lowered from the T-pose by `down`, swung forward by `swing`, swept back about the vertical by
	`sweep`; the elbow bent forward by `flex`, the hand by `hand`."""
	return {side + "Arm": chain(rot_x(-swing), mirrored(side, y=sweep), mirrored(side, z=-down)),
		side + "ForeArm": mirrored(side, y=-flex), side + "Hand": mirrored(side, z=-hand)}


def _leg(side: str, hip: float, knee: float, point: float, spread: float = 0.0) -> dict:
	"""One leg: thigh raised forward by `hip` and out by `spread`, knee bent by `knee`, toes pointed by `point`."""
	return {side + "UpLeg": chain(rot_x(-hip), mirrored(side, z=spread)), side + "Leg": rot_x(knee),
		side + "Foot": rot_x(point)}


def _head_level(pitch: float, share: float = 1.0) -> dict:
	"""neck and Head turned back by half of `share` of the body's pitch each, so the face looks ahead."""
	return {"neck": rot_x(-pitch * share / 2.0), "Head": rot_x(-pitch * share / 2.0)}


def paddle(phase: float, p: dict) -> dict:
	"""A dog paddle: the body tilted forward, the head up, forepaws circling under the chin in turn,
	hind legs kicking in turn. Mice, squirrels, moles; the badger with a slower, heavier stroke."""
	a = 2.0 * math.pi * phase
	pitch = p["pitch"] + 3.0 * math.sin(2.0 * a)
	pose = {"Hips": chain(rot_x(pitch), rot_z(4.0 * p["amp"] * math.sin(a))), "Spine02": rot_x(-6.0), "Spine01": rot_x(-4.0),
		**_head_level(pitch, 0.85)}
	for side, offset in zip(SIDES, (0.0, math.pi)):
		b = a + offset
		pose |= _arm(side, 62.0, 38.0 + 32.0 * p["amp"] * math.sin(b), 70.0 + 38.0 * p["amp"] * math.cos(b), 25.0)
		pose |= _leg(side, 38.0 + 26.0 * p["amp"] * math.sin(b + math.pi), 48.0 + 32.0 * p["amp"] * math.sin(b + math.pi / 2.0),
			35.0 + 15.0 * math.sin(b), 6.0)
	return {"pose": pose, "anchor": p["neck_y"] + 0.012 * math.sin(2.0 * a)}


def hindkick(phase: float, p: dict) -> dict:
	"""A beaver's swim: the body low and near level, forepaws held tucked to the chest, the webbed hind feet
	driving in turn, the head just clear of the water."""
	a = 2.0 * math.pi * phase
	pitch = p["pitch"] + 2.0 * math.sin(2.0 * a)
	pose = {"Hips": chain(rot_x(pitch), rot_z(3.0 * math.sin(a))), "Spine02": rot_x(-5.0), "Spine01": rot_x(-5.0),
		**_head_level(pitch, 0.9)}
	for side, offset in zip(SIDES, (0.0, math.pi)):
		b = a + offset
		pose |= _arm(side, 78.0, 40.0, 115.0, 30.0)
		pose |= _leg(side, 30.0 + 34.0 * math.sin(b + math.pi), 52.0 + 40.0 * math.sin(b + math.pi / 2.0),
			40.0 + 25.0 * math.sin(b), 4.0)
	return {"pose": pose, "anchor": p["neck_y"] + 0.008 * math.sin(2.0 * a)}


def undulate(phase: float, p: dict) -> dict:
	"""An otter's surface swim: the body nearly level, a wave running from the chest to the hind feet, the
	hind legs kicking together with it, the forepaws held back along the chest, the head up."""
	a = 2.0 * math.pi * phase
	lag = math.radians(55.0)
	pitch = p["pitch"] + 5.0 * math.sin(a)
	pose = {"Hips": rot_x(pitch), "Spine02": rot_x(-7.0 * math.sin(a + lag)), "Spine01": rot_x(-6.0 * math.sin(a + 2.0 * lag)),
		"Spine": rot_x(-5.0 * math.sin(a + 3.0 * lag)), **_head_level(pitch, 0.95)}
	for side in SIDES:
		pose |= _arm(side, 80.0, 18.0 + 10.0 * math.sin(a), 95.0 + 10.0 * math.sin(a), 20.0)
		pose |= _leg(side, 12.0 + 22.0 * math.sin(a - lag), 25.0 + 25.0 * math.sin(a - 2.0 * lag),
			85.0 + 12.0 * math.sin(a - 3.0 * lag), 8.0)
	return {"pose": pose, "anchor": p["neck_y"] + 0.01 * math.sin(a)}


def tread(phase: float, p: dict) -> dict:
	"""Treading water: upright, arms out at the surface sculling forward and back, legs cycling in turn."""
	a = 2.0 * math.pi * phase
	pose = {"Hips": chain(rot_x(p["pitch"]), rot_y(3.0 * math.sin(a))), **_head_level(p["pitch"], 0.7)}
	for side, offset in zip(SIDES, (0.0, math.pi)):
		b = a + offset
		pose |= _arm(side, 48.0, 22.0, 30.0 + 10.0 * math.sin(2.0 * a), 10.0 * math.cos(2.0 * a), 22.0 * math.sin(2.0 * a))
		pose |= _leg(side, 32.0 + 20.0 * math.sin(b), 58.0 + 28.0 * math.sin(b + math.pi / 2.0), 30.0 + 10.0 * math.sin(b), 10.0)
	return {"pose": pose, "anchor": p["neck_y"] + 0.012 * math.sin(2.0 * a)}


def dive(phase: float, p: dict) -> dict:
	"""An otter under water: streamlined and level, forepaws laid back along the body, a wave running from
	the chest through the hips to the feet, the hind feet pointed and kicking together."""
	a = 2.0 * math.pi * phase
	lag = math.radians(50.0)
	pose = {"Hips": rot_x(p["pitch"] + 6.0 * math.sin(a)), "Spine02": rot_x(-8.0 * math.sin(a + lag)),
		"Spine01": rot_x(-7.0 * math.sin(a + 2.0 * lag)), "Spine": rot_x(-6.0 * math.sin(a + 3.0 * lag)),
		"neck": rot_x(-28.0 - 4.0 * math.sin(a + 4.0 * lag)), "Head": rot_x(-30.0)}
	for side in SIDES:
		pose |= _arm(side, 84.0, -8.0, 12.0, 10.0)
		pose |= _leg(side, 6.0 + 22.0 * math.sin(a - lag), 12.0 + 22.0 * math.sin(a - 2.0 * lag),
			88.0 + 10.0 * math.sin(a - 3.0 * lag), 4.0)
	return {"pose": pose, "anchor": p["spine_y"] + 0.02 * math.sin(a)}


STYLES = {"paddle": (paddle, SURFACE, "neck"), "hindkick": (hindkick, SURFACE, "neck"), "undulate": (undulate, SURFACE, "neck"),
	"tread": (tread, SURFACE, "neck"), "dive": (dive, SUBMERGED, "Spine01")}

## Per species, each clip: its style, period and parameters. `amp` scales a paddle's strokes; heights are
## shares of the creature's height. The otter alone dives (its surface swim and its dive are the otter's own).
SPECIES_CLIPS = {
	"mouse": {"anim_swim": ("paddle", 0.9, {"pitch": 52.0, "amp": 1.0, "neck_y": 0.0}),
		"anim_tread_water": ("tread", 1.6, {"pitch": 10.0, "neck_y": 0.02})},
	"squirrel": {"anim_swim": ("paddle", 0.9, {"pitch": 52.0, "amp": 1.0, "neck_y": 0.0}),
		"anim_tread_water": ("tread", 1.6, {"pitch": 10.0, "neck_y": 0.02})},
	"mole": {"anim_swim": ("paddle", 0.8, {"pitch": 55.0, "amp": 1.0, "neck_y": 0.0}),
		"anim_tread_water": ("tread", 1.5, {"pitch": 10.0, "neck_y": 0.02})},
	"badger": {"anim_swim": ("paddle", 1.3, {"pitch": 48.0, "amp": 1.15, "neck_y": 0.0}),
		"anim_tread_water": ("tread", 2.0, {"pitch": 10.0, "neck_y": 0.02})},
	"beaver": {"anim_swim": ("hindkick", 1.1, {"pitch": 64.0, "neck_y": 0.01}),
		"anim_tread_water": ("tread", 1.8, {"pitch": 10.0, "neck_y": 0.02})},
	"otter": {"anim_swim": ("undulate", 1.2, {"pitch": 72.0, "neck_y": 0.02}),
		"anim_tread_water": ("tread", 1.6, {"pitch": 10.0, "neck_y": 0.02}),
		"anim_dive": ("dive", 1.4, {"pitch": 88.0, "spine_y": -0.42})},
}


# --- writing the clip -------------------------------------------------------------------------------

def _joint_nodes(doc: dict) -> dict[str, int]:
	"""Every posed joint's node index; refuses a skeleton missing one (not Meshy's humanoid)."""
	by_name = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
	missing = [name for name in JOINTS if name not in by_name]
	if missing:
		raise AuthorRefused(f"the skeleton lacks {missing}; the water clips pose Meshy's 24-joint humanoid")
	if any(n.get("name", "").startswith("tail_") for n in doc["nodes"]):
		raise AuthorRefused("the rig already has a tail chain; author from the raw rigged.glb")
	return {name: by_name[name] for name in JOINTS}


def local_rotation(doc: dict, node: int, parent_rest: list, r: list) -> list[list[float]]:
	"""The local rotation that turns `node` by the character-axes rotation `r` in its parent's posed frame:
	B_p^T r B_p L0. With r the identity this is L0, the rest, exactly."""
	x, y, z, w = doc["nodes"][node].get("rotation", [0.0, 0.0, 0.0, 1.0])
	rest = [[1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w)],
		[2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w)],
		[2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)]]
	return _compose(_compose(_compose(_transpose(parent_rest), r), parent_rest), rest)


def clip_keys(doc: dict, style: str, period_s: float, params: dict) -> dict:
	"""Every key of one clip: times, each joint's local rotation, the Hips translation, and the anchor's height
	as posed -- solved so the anchor joint stands exactly at its share of the creature's height."""
	fn, medium, anchor_name = STYLES[style]
	nodes = _joint_nodes(doc)
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	rest = node_worlds(doc)
	height = geometry_height_m(doc)
	count = round(period_s * KEY_RATE_HZ) + 1
	times = [(k + 1) / KEY_RATE_HZ for k in range(count)]
	hips = nodes["Hips"]
	rotations: dict[int, list] = {n: [] for n in nodes.values()}
	translations, anchors = [], []
	for k in range(count):
		posed = fn((k % (count - 1)) / (count - 1), params)
		for name, node in nodes.items():
			r = posed["pose"].get(name, rot_x(0.0))
			rotations[node].append(local_rotation(doc, node, _basis(rest[parents[node]]) if node in parents else rot_x(0.0), r))
		animated = {n: {"rotation": [_quat(rotations[n][-1])]} for n in rotations}
		animated[hips]["translation"] = [doc["nodes"][hips].get("translation", [0.0, 0.0, 0.0])]
		worlds = _worlds_at(doc, animated, 0)
		lift = posed["anchor"] * height - worlds[nodes[anchor_name]][13]
		delta = world_in_parent_space(doc, hips, [0.0, lift, 0.0])
		translations.append(tuple(t + d for t, d in zip(animated[hips]["translation"][0], delta)))
		anchors.append(posed["anchor"] * height)
	return {"times": times, "rotations": rotations, "translations": translations, "hips": hips, "medium": medium,
		"anchor": anchor_name, "anchor_y_m": anchors, "height_m": height}


def author(rigged: bytes, clip: str, style: str, period_s: float, params: dict) -> tuple[bytes, dict]:
	"""A copy of the raw rigged.glb whose one animation is the authored clip. Returns the file and a report."""
	doc, binary = read_glb(rigged)
	if STAMP in doc.get("asset", {}).get("extras", {}):
		raise AuthorRefused("already an authored clip; author from the raw rigged.glb")
	if len(doc["scenes"][doc.get("scene", 0)]["nodes"]) != 1:
		raise AuthorRefused("expected one scene root")
	keys = clip_keys(doc, style, period_s, params)
	original = binary
	binary, times = append_accessor(doc, binary, [(t,) for t in keys["times"]], 5126, "SCALAR")
	doc["accessors"][times]["min"], doc["accessors"][times]["max"] = [keys["times"][0]], [keys["times"][-1]]
	samplers, channels = [], []
	for node, rows in keys["rotations"].items():
		binary, out = append_accessor(doc, binary, _quats(rows), 5126, "VEC4")
		samplers.append({"input": times, "output": out, "interpolation": "LINEAR"})
		channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": "rotation"}})
	binary, out = append_accessor(doc, binary, keys["translations"], 5126, "VEC3")
	samplers.append({"input": times, "output": out, "interpolation": "LINEAR"})
	channels.append({"sampler": len(samplers) - 1, "target": {"node": keys["hips"], "path": "translation"}})
	doc["animations"] = [{"name": f"Armature|{clip[5:]}|redwall_authored", "samplers": samplers, "channels": channels}]
	period = keys["times"][-1] - keys["times"][0]
	doc["nodes"][keys["hips"]].setdefault("extras", {})["water"] = {"medium": keys["medium"], "waterline_y_m": 0.0,
		"period_s": round(period, 5), "decision": "0203"}
	doc["asset"].setdefault("extras", {})[STAMP] = {"version": STAMP_VERSION, "clip": clip, "style": style,
		"params": params, "source_sha256": hashlib.sha256(rigged).hexdigest(), "decision": "0203"}
	out = write_glb(doc, binary)
	if not read_glb(out)[1].startswith(original):
		raise AuthorRefused("the rigged file's BIN data did not survive intact")
	return out, {"style": style, "medium": keys["medium"], "keys": len(keys["times"]), "period_s": round(period, 4),
		"anchor": keys["anchor"], "anchor_y_m": [round(min(keys["anchor_y_m"]), 4), round(max(keys["anchor_y_m"]), 4)]}


def species_clips(key: str) -> dict:
	"""The clips a creature `<species>_<role>` gets; refuses a species with no swim authored."""
	species = key.split("_")[0]
	if species not in SPECIES_CLIPS:
		raise AuthorRefused(f"{key}: no water clips are authored for species '{species}'")
	return SPECIES_CLIPS[species]


def author_library(library: pathlib.Path, dry_run: bool) -> list[dict]:
	"""Author every rigged creature's water clips into <key>/authored/."""
	rows = []
	for key_dir in sorted(p for p in library.iterdir() if (p / "rigged.glb").is_file()):
		rigged = (key_dir / "rigged.glb").read_bytes()
		for clip, (style, period, params) in sorted(species_clips(key_dir.name).items()):
			out, report = author(rigged, clip, style, period, params)
			if not dry_run:
				(key_dir / OUT_DIR).mkdir(exist_ok=True)
				(key_dir / OUT_DIR / f"{clip}.glb").write_bytes(out)
			rows.append({"key": key_dir.name, "clip": clip, **report, "params": params,
				"source_sha256": hashlib.sha256(rigged).hexdigest(), "output_sha256": hashlib.sha256(out).hexdigest()})
	return rows


def main() -> int:
	"""Author the library's water clips and write the manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
	parser.add_argument("--dry-run", action="store_true")
	args = parser.parse_args()
	try:
		rows = author_library(args.library, args.dry_run)
	except RepairRefused as refused:
		print(f"author_water_clips: REFUSED -- {refused}")
		return 1
	for r in rows:
		print(f"  {r['key']:20} {r['clip']:18} {r['style']:9} {r['medium']:9} {r['keys']:3} keys, {r['period_s']:.3f} s")
	print(f"author_water_clips: {len(rows)} clips{' (dry run)' if args.dry_run else ''}")
	if not args.dry_run:
		args.manifest.write_text(json.dumps({"tool": "tools/author_water_clips.py", "decision": "0203",
			"waterline_y_m": 0.0, "key_rate_hz": KEY_RATE_HZ, "count": len(rows), "clips": rows}, indent=1) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
