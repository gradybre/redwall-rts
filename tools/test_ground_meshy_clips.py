#!/usr/bin/env python3
"""Self-test for tools/ground_meshy_clips.py (decisions 0193, 0195, 0197, 0201).

NEGATIVE TESTS COME FIRST:

  N01  a clip already grounded refuses, so a lift is never applied twice.
  N02  a file with no animation refuses.
  N03  a skin with no foot, toe or leg joint has no support, and refuses rather than lifting
       by some other part.
  N04  a clip that animates an ancestor of Hips refuses: a Hips lift would not be a world lift.
  N05  a clip that does not animate the Hips translation refuses.
  N06  a clip that scales a bone away from its rest refuses: the creature would grow and shrink
       (decision 0197). A scale key at rest passes.
  N07  a clip that swings round but cannot be untwisted refuses (decision 0201): no Head, a missing
       leg, a leg that changes length, a foot beyond reach, a straight leg, an upside-down Hips key.
  (and a standing clip the seat leaves floating refuses: test_a_seat_that_leaves_the_clip_floating_refuses;
  an untwist that leaves the hips turning or a foot sliding refuses: test_an_untwist_that_does_not_hold_is_refused)

THE FIXTURE is the bake test's Meshy-shaped clip: the hips drop 0.6 m on key 2. The foot's
lowest vertex (y 0.548 at bind) then reaches -0.052, while the tail and the body -- both on the
hips at y 0.5 -- reach -0.1. So a lift of exactly 0.052 on key 2 alone proves that support is the
foot, and that neither the tail nor the body is counted. A scale-2 armature case checks that
the lift is converted into the Hips parent's units. Expected values are literals.
"""

from __future__ import annotations

import json
import math
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ground_meshy_clips as ground  # noqa: E402
import rig_meshy_tail as tail  # noqa: E402
import bake_meshy_tail as bake  # noqa: E402
import test_bake_meshy_tail as fixture  # noqa: E402
from repair_meshy_rig import read_glb, write_glb  # noqa: E402

CASES: list[str] = []
FAILURES: list[str] = []


def check(name: str, condition: bool) -> None:
	"""Record one named check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _refuses(name: str, action) -> None:
	"""Check that `action` raises the tool's refusal, and nothing else."""
	try:
		action()
	except ground.RepairRefused:
		check(name, True)
		return
	check(name + " (did not refuse)", False)


def _refuses_with(name: str, text: str, action) -> None:
	"""Check that `action` raises the tool's refusal, for the stated reason."""
	try:
		action()
	except ground.RepairRefused as refused:
		check(name + ("" if text in str(refused) else f" (refused for another reason: {refused})"), text in str(refused))
		return
	check(name + " (did not refuse)", False)


def _near(a: float, b: float, tolerance: float = 1e-5) -> bool:
	"""Float equality to a stated tolerance."""
	return abs(a - b) <= tolerance


def _hips_y(data: bytes) -> list[float]:
	"""The Hips translation y on each of the output's keys."""
	doc, binary = read_glb(data)
	_hips, channel = ground._hips(doc)
	sampler = doc["animations"][0]["samplers"][channel["sampler"]]
	return [row[1] for row in tail.read_accessor(doc, binary, sampler["output"])]


def _edit(data: bytes, change) -> bytes:
	"""Apply `change(doc)` to a copy of the file."""
	doc, binary = read_glb(data)
	change(doc)
	return write_glb(doc, binary)


# --- negative tests ---------------------------------------------------------------------

def test_n01_a_grounded_clip_refuses() -> None:
	"""Grounding an output again would lift it twice."""
	once, _row = ground.ground_clip(fixture._clip(fixture._chained()))
	_refuses("N01 an already-grounded clip refuses", lambda: ground.ground_clip(once))


def test_n02_no_animation_refuses() -> None:
	"""rigged.glb has nothing to ground."""
	_refuses("N02 a file with no animation refuses", lambda: ground.ground_clip(fixture._chained()))


def test_n03_no_support_refuses() -> None:
	"""With the foot renamed Spine, nothing is support."""
	def rename(doc: dict) -> None:
		next(n for n in doc["nodes"] if n.get("name") == "LeftFoot")["name"] = "Spine"
	_refuses("N03 no foot, toe or leg refuses", lambda: ground.ground_clip(_edit(fixture._clip(fixture._chained()), rename)))


def test_n04_an_animated_ancestor_of_hips_refuses() -> None:
	"""A channel on the Armature root."""
	def animate_root(doc: dict) -> None:
		root = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Armature")
		doc["animations"][0]["channels"].append({"sampler": 2, "target": {"node": root, "path": "translation"}})
	_refuses("N04 an animated Hips ancestor refuses", lambda: ground.ground_clip(_edit(fixture._clip(fixture._chained()), animate_root)))


def test_n05_no_hips_translation_refuses() -> None:
	"""The Hips translation channel removed."""
	def drop(doc: dict) -> None:
		anim = doc["animations"][0]
		anim["channels"] = [c for c in anim["channels"] if c["target"]["path"] != "translation"]
	_refuses("N05 no Hips translation refuses", lambda: ground.ground_clip(_edit(fixture._clip(fixture._chained()), drop)))


def _scale_hips(value: float):
	"""An edit adding a Hips scale channel held at `value` on the clip's 2-key sampler."""
	def change(doc: dict) -> None:
		hips = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Hips")
		anim = doc["animations"][0]
		anim["samplers"].append({"input": anim["samplers"][0]["input"], "output": len(doc["accessors"])})
		anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": hips, "path": "scale"}})
		doc["accessors"].append({"bufferView": len(doc["bufferViews"]), "componentType": 5126, "count": 2, "type": "VEC3"})
		doc["bufferViews"].append({"buffer": 0, "byteOffset": doc["buffers"][0]["byteLength"], "byteLength": 24})
	return change


def _with_hips_scale(value: float) -> bytes:
	"""The fixture clip with a 2-key Hips scale channel held at `value`."""
	doc, binary = read_glb(fixture._clip(fixture._chained()))
	_scale_hips(value)(doc)
	binary += struct.pack("<6f", *([value] * 6))
	doc["buffers"][0]["byteLength"] = len(binary)
	return write_glb(doc, binary)


def test_n06_a_clip_that_scales_a_bone_refuses() -> None:
	"""Meshy's idle Hips scale, 1.1765, left in: refused. The same channel at rest, 1.0: grounded."""
	_refuses("N06 a Hips scale of 1.1765 refuses", lambda: ground.ground_clip(_with_hips_scale(1.1765)))
	_out, row = ground.ground_clip(_with_hips_scale(1.0))
	check("a Hips scale at rest grounds", row["keys"] == 5)


# --- positive tests ---------------------------------------------------------------------

def test_the_lift_is_the_feets_depth_on_that_key_only() -> None:
	"""Key 2 lifted 0.052 (the foot), not 0.1 (the tail or body); every other key untouched."""
	out, row = ground.ground_clip(fixture._clip(fixture._chained()))
	ys = _hips_y(out)
	check("key 2's hips rise from -0.1 to -0.048", _near(ys[2], -0.048))
	check("the other keys are unchanged", all(_near(ys[k], 0.5) for k in (0, 1, 3, 4)))
	check("one key lifted, by 0.052", row["keys_lifted"] == 1 and row["max_lift_m"] == 0.052)
	check("support before -0.052, after 0", row["support_min_before_m"] == -0.052 and _near(row["support_min_after_m"], 0.0, 1e-4))


def test_a_clip_off_the_ground_by_design_is_never_lowered() -> None:
	"""Hips held at 0.5, a chair clip: the foot floats 0.548 m on every key, and nothing moves."""
	out, row = ground.ground_clip(fixture._clip(fixture._chained(), hips_y=[0.5] * 5), stands=False)
	check("no key lifted", row["keys_lifted"] == 0)
	check("no hips key lowered", all(_near(y, 0.5) for y in _hips_y(out)))
	check("nothing seated", row["seated_m"] == 0.0)


def test_a_standing_clip_that_floats_is_seated() -> None:
	"""The same clip standing: every hips key drops the whole 0.548 m gap, to -0.048, so it touches."""
	out, row = ground.ground_clip(fixture._clip(fixture._chained(), hips_y=[0.5] * 5))
	check("every hips key lowered to -0.048", all(_near(y, -0.048) for y in _hips_y(out)))
	check("seated by 0.548", row["seated_m"] == 0.548 and row["keys_lifted"] == 0)
	check("the support now touches the ground", _near(row["support_min_after_m"], 0.0, 1e-4))


def test_a_float_within_tolerance_is_not_seated() -> None:
	"""A clip whose lowest support is within a millimetre of the ground already touches it."""
	check("0.0009 m: nothing moves", ground.ground_lifts([0.0009, 0.3], True) == [0.0, 0.0])
	check("0.0011 m: seated", ground.ground_lifts([0.0011, 0.3], True) == [-0.0011, -0.0011])
	check("a clip that dips still only lifts that key", ground.ground_lifts([0.2, -0.05], True) == [0.0, 0.05])


def test_only_the_chair_clip_is_off_the_ground() -> None:
	"""The library grounds a chair clip as off the ground, and the idle as standing."""
	check("the chair clip does not stand", not ground.stands("/lib/badger_cellarer/tailed/anim_chair_sit_idle.glb"))
	check("the idle stands", ground.stands("/lib/badger_cellarer/tailed/anim_idle.glb"))


def test_a_seat_that_leaves_the_clip_floating_refuses() -> None:
	"""With the seat sabotaged to nothing, the re-skinned standing clip still floats and is refused."""
	real = ground.apply_lift
	ground.apply_lift = lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times, [0.0] * len(lifts), roots)
	try:
		_refuses("a standing clip left floating refuses", lambda: ground.ground_clip(fixture._clip(fixture._chained(), hips_y=[0.5] * 5)))
	finally:
		ground.apply_lift = real


def test_the_lift_is_converted_into_the_hips_parent_space() -> None:
	"""A 0.01-scale parent needs 100 local units per metre; under a Z-up parent, world up is local +Z."""
	def doc_with_parent(parent: dict) -> dict:
		return {"nodes": [{"name": "Armature", "children": [1], **parent}, {"name": "Hips"}], "scenes": [{"nodes": [0]}], "scene": 0}
	scaled = ground.lift_in_parent_space(doc_with_parent({"scale": [0.01] * 3}), 1)
	check("a 0.01 parent: 100 local units up", all(_near(a, b) for a, b in zip(scaled, (0.0, 100.0, 0.0))))
	half = math.sqrt(0.5)
	rotated = ground.lift_in_parent_space(doc_with_parent({"rotation": [-half, 0.0, 0.0, half]}), 1)
	## Rotating -90 deg about X takes local +Z to world +Y, so world up is local +Z.
	check("a Z-up parent: world up is local +Z", all(_near(a, b) for a, b in zip(rotated, (0.0, 0.0, 1.0))))
	check("no parent: world up", ground.lift_in_parent_space({"nodes": [{"name": "Hips"}]}, 0) == [0.0, 1.0, 0.0])


def test_a_scaled_armature_gets_its_lift_in_local_units() -> None:
	"""Armature scale 2: the foot reaches -0.104 m on key 2, and the hips key rises 0.052 LOCAL units."""
	def double(doc: dict) -> None:
		next(n for n in doc["nodes"] if n.get("name") == "Armature")["scale"] = [2.0, 2.0, 2.0]
	out, row = ground.ground_clip(_edit(fixture._clip(fixture._chained()), double))
	check("the world lift is 0.104 m", row["max_lift_m"] == 0.104)
	check("the local hips key rises from -0.1 to -0.048", _near(_hips_y(out)[2], -0.048))
	check("the support ends exactly on the ground", _near(row["support_min_after_m"], 0.0, 1e-4))


def test_a_lift_that_does_not_ground_the_clip_refuses() -> None:
	"""The re-skinned output is checked: with the lift sabotaged to nothing, the clip is refused."""
	real = ground.apply_lift
	ground.apply_lift = lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times, [0.0] * len(lifts), roots)
	try:
		_refuses("a lift that leaves the foot below ground refuses", lambda: ground.ground_clip(fixture._clip(fixture._chained())))
	finally:
		ground.apply_lift = real
	ground.apply_lift = lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times, [x + 0.01 for x in lifts], roots)
	try:
		_refuses("a lift that moves keys needing none refuses", lambda: ground.ground_clip(fixture._clip(fixture._chained())))
	finally:
		ground.apply_lift = real


def test_the_output_keeps_the_source_and_is_stamped() -> None:
	"""Source BIN as a prefix, one stamp carrying the source hash."""
	source = fixture._clip(fixture._chained())
	out, _row = ground.ground_clip(source)
	check("source BIN survives as a prefix", read_glb(out)[1].startswith(read_glb(source)[1]))
	stamp = read_glb(out)[0]["asset"]["extras"][ground.STAMP]
	check("stamped with the source hash", stamp["source_sha256"] == __import__("hashlib").sha256(source).hexdigest())
	check("stamped once", json.dumps(read_glb(out)[0]["asset"]).count(ground.STAMP) == 1)


## A walk: 63 keys at 30 Hz, the hips going 0.5 m/s forward (+Z) with a 5 cm sideways-and-forward
## sway whose period is exactly the 31-key averaging window. The average of the sway over any window
## is then exactly 0, so the root is exactly the straight 0.5 m/s line and what stays is the sway.
WALK_TIMES = [k / 30 for k in range(63)]


def _sway(k: int) -> float:
	"""The sway at key k: period 31 keys, starting mid-stride (7 keys in), so the hips' first position
	is NOT the root's -- the root line runs through the sway's middle."""
	return 0.05 * math.sin(2.0 * math.pi * (k + 7) / 31)


def _walk() -> bytes:
	"""The hips 0.5 m up (so no lift), travelling 0.5 m/s along +Z with the sway in X and Z."""
	path = [(_sway(k), 0.5, 0.5 * WALK_TIMES[k] + _sway(k)) for k in range(63)]
	return fixture._clip(fixture._chained(), times=WALK_TIMES, hips_xyz=path)


def test_a_travelling_clip_is_put_in_place_with_its_sway_kept() -> None:
	"""The 1.0333 m of travel leaves the hips; the stride's sway does not."""
	out, row = ground.ground_clip(_walk())
	doc, binary = read_glb(out)
	_times, path = ground.root_path(doc, binary)
	check("the hips now end where they began", math.hypot(path[-1][0] - path[0][0], path[-1][1] - path[0][1]) < 1e-5)
	check("key 5 keeps its sway in Z", _near(path[5][1] - path[0][1], _sway(5) - _sway(0), 1e-5))
	check("key 5 keeps its sway in X", _near(path[5][0] - path[0][0], _sway(5) - _sway(0), 1e-5))
	check("the travel is reported", _near(row["root_travel_m"], 1.0333, 1e-4) and row["loop_gap_m"] < 1e-4)


def test_the_root_motion_is_recorded_on_the_hips() -> None:
	"""What gameplay needs: the path, the travel and period, the mean speed of 0.5 m/s."""
	out, _row = ground.ground_clip(_walk())
	hips = next(n for n in read_glb(out)[0]["nodes"] if n.get("name") == "Hips")
	motion = hips["extras"]["root_motion"]
	check("travel 1.0333 m along +Z", motion["travel_m"] == [0.0, 1.03333])
	check("period 2.0667 s", motion["period_s"] == 2.06667)
	check("mean speed 0.5 m/s", _near(motion["mean_speed_m_s"], 0.5, 1e-4))
	check("key 5's root is 0.5 x 5/30 m forward", motion["keys_xz"][5] == [0.0, round(0.5 * 5 / 30, 5)])
	check("one root key per clip key", len(motion["keys_xz"]) == 63)


def test_a_clip_that_still_travels_is_refused() -> None:
	"""The written clip is read back: with the extracted root sabotaged to half, it still travels."""
	real = ground.extract_root
	ground.extract_root = lambda times, path: [[r[0] / 2, r[1] / 2] for r in real(times, path)]
	try:
		_refuses("a clip left travelling half a metre refuses", lambda: ground.ground_clip(_walk()))
	finally:
		ground.extract_root = real


def test_a_clip_in_place_has_no_root_motion() -> None:
	"""The 5-key fixture never moves sideways: nothing is extracted, nothing recorded."""
	out, row = ground.ground_clip(fixture._clip(fixture._chained()))
	hips = next(n for n in read_glb(out)[0]["nodes"] if n.get("name") == "Hips")
	check("no root motion recorded", "root_motion" not in hips.get("extras", {}))
	check("no travel reported", row["root_travel_m"] == 0.0)


def test_extracting_the_root_changes_no_height() -> None:
	"""The lift is vertical and the root horizontal: the support's heights are what the lift alone gives.
	The walk floats, so it is grounded as off the ground; seating it would move every key."""
	source = _walk()
	out, _row = ground.ground_clip(source, stands=False)
	_t, before = ground.lowest_support(*read_glb(source))
	_t, after = ground.lowest_support(*read_glb(out))
	check("every key's lowest support height is unchanged (no lift was needed)", all(_near(a, b, 1e-6) for a, b in zip(before, after)))


# --- untwisting: an in-place clip that swings round is held at the walk's heading (0201) ---
#
# THE BIPED FIXTURE: Armature -> Hips -> (LeftUpLeg -> LeftLeg -> LeftFoot), the same on the right,
# and Spine -> Head. Every rest rotation is identity, so the rest pose faces +Z; each leg bends its
# knee 5 cm forward and puts its foot 0.48 m below the hips at x = +-0.1. One vertex under each foot
# (the support) and one on the head. The clip stands 0.2 m to the side and 0.1 m forward of the rest
# hips, and yaws them -40, -40, +10, -80, -40 deg -- Meshy's idle in five keys -- with a 5 deg pitch on
# keys 1 and 3; the legs are not keyed, so the feet swing round with the hips. The head is keyed at
# +40, +40, +80, 0, +40 deg: on key 0 it looks straight ahead while the body is turned, as Meshy's does.
#
# Expected, as literals: the hips face 0 deg on every key and keep their pitch; they stand over the
# rest hips at (0, 0.5, 0); both feet stay at (+-0.1, 0.02, 0) on every key; the head's own yaw is
# kept less the 40 deg gaze fix (0, 0, +40, -40, 0); the spine's channel is untouched.

BIPED_TIMES = [0.0, 1 / 30, 2 / 30, 3 / 30, 4 / 30]
BIPED_YAW = [-40.0, -40.0, 10.0, -80.0, -40.0]
BIPED_PITCH = [0.0, 5.0, 0.0, 5.0, 0.0]
BIPED_HEAD = [40.0, 40.0, 80.0, 0.0, 40.0]


def _q(axis: str, degrees: float) -> tuple:
	"""A quaternion (x, y, z, w) for `degrees` about the X or Y axis."""
	h = math.radians(degrees) / 2.0
	return (math.sin(h), 0.0, 0.0, math.cos(h)) if axis == "x" else (0.0, math.sin(h), 0.0, math.cos(h))


def _q_mul(a: tuple, b: tuple) -> tuple:
	"""The quaternion product a * b."""
	ax, ay, az, aw = a
	bx, by, bz, bw = b
	return (aw * bx + ax * bw + ay * bz - az * by, aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw, aw * bw - ax * bx - ay * by - az * bz)


BIPED_NODES = [("Armature", [0.0, 0.0, 0.0], [1]), ("Hips", [0.0, 0.5, 0.0], [2, 5, 8]),
	("LeftUpLeg", [0.1, 0.0, 0.0], [3]), ("LeftLeg", [0.0, -0.24, 0.05], [4]), ("LeftFoot", [0.0, -0.24, -0.05], []),
	("RightUpLeg", [-0.1, 0.0, 0.0], [6]), ("RightLeg", [0.0, -0.24, 0.05], [7]), ("RightFoot", [0.0, -0.24, -0.05], []),
	("Spine", [0.0, 0.1, 0.0], [9]), ("Head", [0.0, 0.15, 0.0], [])]
BIPED_REST = {"Hips": (0.0, 0.5, 0.0), "LeftUpLeg": (0.1, 0.5, 0.0), "LeftLeg": (0.1, 0.26, 0.05), "LeftFoot": (0.1, 0.02, 0.0),
	"RightUpLeg": (-0.1, 0.5, 0.0), "RightLeg": (-0.1, 0.26, 0.05), "RightFoot": (-0.1, 0.02, 0.0),
	"Spine": (0.0, 0.6, 0.0), "Head": (0.0, 0.75, 0.0)}


def _biped(yaw: list | None = None, hips_xz: tuple = (0.2, 0.1), drop: tuple = (), head: bool = True,
		leg_len: list | None = None, spine_pitch: list | None = None) -> bytes:
	"""The biped fixture and its clip. `drop` removes named nodes; `leg_len` keys LeftLeg's translation."""
	yaw = yaw or BIPED_YAW
	times = BIPED_TIMES[:len(yaw)]
	names = [n for n, _t, _c in BIPED_NODES]
	joints = names[1:]
	nodes = [{"name": n, "translation": t, "children": c} for n, t, c in BIPED_NODES]
	nodes.append({"name": "body", "mesh": 0, "skin": 0})
	verts = [((0.1, 0.0, 0.0), joints.index("LeftFoot")), ((-0.1, 0.0, 0.0), joints.index("RightFoot")),
		((0.0, 0.8, 0.0), joints.index("Head"))]
	ibm = []
	for j in joints:
		x, y, z = BIPED_REST[j]
		ibm.append((1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1))
	doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0, 10]}], "nodes": nodes,
		"skins": [{"joints": list(range(1, 10)), "inverseBindMatrices": 3}],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0, "JOINTS_0": 1, "WEIGHTS_0": 2}}]}],
		"accessors": [], "bufferViews": [], "buffers": [{"byteLength": 0}]}
	binary = b""
	binary, _ = tail.append_accessor(doc, binary, [v for v, _j in verts], 5126, "VEC3")
	binary, _ = tail.append_accessor(doc, binary, [(j, 0, 0, 0) for _v, j in verts], 5123, "VEC4")
	binary, _ = tail.append_accessor(doc, binary, [(1.0, 0.0, 0.0, 0.0)] * len(verts), 5126, "VEC4")
	binary, _ = tail.append_accessor(doc, binary, ibm, 5126, "MAT4")
	binary, t_in = tail.append_accessor(doc, binary, [(t,) for t in times], 5126, "SCALAR")
	hips_r = [_q_mul(_q("y", y), _q("x", p)) for y, p in zip(yaw, BIPED_PITCH)]
	outs = {("Hips", "rotation"): hips_r, ("Hips", "translation"): [(hips_xz[0], 0.5, hips_xz[1])] * len(times),
		("Spine", "rotation"): [_q("x", p) for p in (spine_pitch or BIPED_PITCH)[:len(times)]]}
	if head:
		outs[("Head", "rotation")] = [_q("y", h) for h in BIPED_HEAD[:len(times)]]
	if leg_len:
		outs[("LeftLeg", "translation")] = [(0.0, -y, 0.05) for y in leg_len]
	samplers, channels = [], []
	for (name, path), rows in outs.items():
		binary, out = tail.append_accessor(doc, binary, rows, 5126, "VEC4" if path == "rotation" else "VEC3")
		samplers.append({"input": t_in, "output": out})
		channels.append({"sampler": len(samplers) - 1, "target": {"node": names.index(name), "path": path}})
	doc["animations"] = [{"name": "idle", "samplers": samplers, "channels": channels}]
	doc["buffers"][0]["byteLength"] = len(binary)
	for name in drop:
		node = names.index(name)
		doc["nodes"][node]["name"] = name + "_gone"
	return write_glb(doc, binary)


def _poses(data: bytes, names: tuple) -> list[dict]:
	"""World matrices of the named nodes on every key of the clip."""
	doc, binary = read_glb(data)
	index = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
	times, animated = bake._channels(doc, binary)
	return [{n: bake._worlds_at(doc, animated, k)[index[n]] for n in names} for k in range(len(times))]


def _local_yaw(data: bytes, name: str) -> list[float]:
	"""Degrees of the Y-twist in the named node's local rotation keys."""
	doc, binary = read_glb(data)
	node = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == name)
	anim = doc["animations"][0]
	channel = next(c for c in anim["channels"] if c["target"] == {"node": node, "path": "rotation"})
	return [math.degrees(2.0 * math.atan2(q[1], q[3])) for q in tail.read_accessor(doc, binary, anim["samplers"][channel["sampler"]]["output"])]


def test_n07_untwisting_refuses_what_it_cannot_solve() -> None:
	"""A swinging clip with no Head, no right leg, or a leg that changes length; a straight leg; an
	upside-down Hips key; a foot beyond reach. Each for its own reason."""
	_refuses_with("N07 a swinging clip with no Head refuses", "Head", lambda: ground.ground_clip(_biped(drop=("Head",), head=False)))
	_refuses_with("N07 a swinging clip with no RightLeg refuses", "RightLeg", lambda: ground.ground_clip(_biped(drop=("RightLeg",))))
	_refuses_with("N07 a leg that changes length refuses", "changes length",
		lambda: ground.ground_clip(_biped(leg_len=[0.24, 0.24, 0.3, 0.24, 0.24])))
	_refuses_with("N07 a foot beyond its leg's horizontal reach refuses", "beyond",
		lambda: ground._hip_drop([0.0, 1.0, 0.0], [0.5, 0.0, 0.0], 0.4))
	_refuses_with("N07 a straight leg has no knee direction", "straight",
		lambda: ground._solve_leg([0, 0.5, 0], [0, 0.02, 0], 0.24, 0.24, [0.0, -1.0, 0.0]))
	flip = [[1.0, 0.0, 0.0], [0.0, -1.0, 0.0], [0.0, 0.0, -1.0]]   # 180 deg about X: no heading
	_refuses_with("N07 an upside-down Hips key refuses", "upside down", lambda: ground._yaw_of(flip))


def test_a_swinging_idle_faces_the_walk_on_every_key() -> None:
	"""The Hips' heading is 0 deg on every key; their pitch is kept; they stand over the rest hips."""
	out, row = ground.ground_clip(_biped())
	doc, binary = read_glb(out)
	check("untwisted, reported", row["untwisted"] and row["heading_swing_deg"] == 90.0 and row["heading_net_deg"] == 0.0)
	check("turned by +40 deg, gaze fixed by -40 deg", row["turned_deg"] == 40.0 and row["gaze_deg"] == -40.0)
	check("every Hips key faces 0 deg", all(_near(h, 0.0, 1e-4) for h in ground.hips_headings(doc, binary)))
	check("the report reads it back", row["heading_off_after_deg"] == 0.0)
	pitch = [math.degrees(2.0 * math.atan2(q[0], q[3])) for q in _hips_rotations(out)]
	check("the Hips keep their 5 deg pitch", all(_near(a, b, 1e-3) for a, b in zip(pitch, BIPED_PITCH)))
	hips = [p["Hips"] for p in _poses(out, ("Hips",))]
	check("the hips stand over the rest hips", all(_near(m[12], 0.0) and _near(m[13], 0.5) and _near(m[14], 0.0) for m in hips))
	check("no drop was needed", row["hips_drop_max_m"] == 0.0)


def _hips_rotations(data: bytes) -> list[tuple]:
	"""The Hips rotation keys of a file."""
	doc, binary = read_glb(data)
	hips, _channel = ground._hips(doc)
	anim = doc["animations"][0]
	channel = next(c for c in anim["channels"] if c["target"] == {"node": hips, "path": "rotation"})
	return tail.read_accessor(doc, binary, anim["samplers"][channel["sampler"]]["output"])


def test_the_feet_stay_planted() -> None:
	"""The source's feet swing round with the hips: the right foot 0.1087 m on key 3 (40 deg of yaw about
	the hips plus the 5 deg pitch, computed by hand). The output's stay at (+-0.1, 0.02, 0)."""
	out, row = ground.ground_clip(_biped())
	check("the source's feet slid 0.1087 m", row["feet_slide_before_m"] == 0.1087)
	check("the output's feet do not slide", row["feet_slide_after_m"] == 0.0)
	poses = _poses(out, ("LeftFoot", "RightFoot"))
	check("the left foot is at (0.1, 0.02, 0) on every key",
		all(_near(p["LeftFoot"][12], 0.1) and _near(p["LeftFoot"][13], 0.02) and _near(p["LeftFoot"][14], 0.0) for p in poses))
	check("the right foot is at (-0.1, 0.02, 0) on every key",
		all(_near(p["RightFoot"][12], -0.1) and _near(p["RightFoot"][13], 0.02) and _near(p["RightFoot"][14], 0.0) for p in poses))
	check("the feet still touch the ground", _near(row["support_min_after_m"], 0.0, 1e-4) and row["seated_m"] == 0.0)
	knees = _poses(out, ("LeftLeg", "RightLeg"))
	check("the knees stay bent forward, where the rest pose has them",
		all(_near(p[n][14], 0.05) and _near(p[n][13], 0.26) for p in knees for n in p))


def test_the_upper_body_keeps_its_own_motion() -> None:
	"""The head's yaw on its neck is kept, less the gaze fix; the spine's channel is not touched."""
	source, (out, _row) = _biped(), ground.ground_clip(_biped())
	check("the head keeps its look-around, turned -40", all(_near(a, b, 1e-3) for a, b in zip(_local_yaw(out, "Head"), (0.0, 0.0, 40.0, -40.0, 0.0))))
	head = [p["Head"] for p in _poses(out, ("Head",))]
	check("on key 0 the head faces the walk", _near(math.degrees(math.atan2(head[0][8], head[0][10])), 0.0, 1e-3))
	def spine_output(data: bytes) -> int:
		"""The Spine rotation channel's output accessor."""
		doc = read_glb(data)[0]
		anim = doc["animations"][0]
		return anim["samplers"][next(c for c in anim["channels"] if c["target"] == {"node": 8, "path": "rotation"})["sampler"]]["output"]
	check("the spine's channel is untouched", spine_output(out) == spine_output(source))


def test_the_untwisted_clip_still_loops() -> None:
	"""The source's first and last keys match, and so do the output's, bone by bone."""
	poses = _poses(ground.ground_clip(_biped())[0], ("Hips", "LeftLeg", "RightLeg", "LeftFoot", "Head"))
	check("the last key is the first", all(_near(a, b, 1e-5) for n in poses[0] for a, b in zip(poses[0][n], poses[-1][n])))


def test_a_clip_that_does_not_swing_far_is_untouched() -> None:
	"""A 44.8 deg swing is gait or a gesture: nothing is rewritten. 45.2 deg is untwisted."""
	source = _biped(yaw=[0.0, 44.8, 0.0])
	out, row = ground.ground_clip(source)
	check("44.8 deg: not untwisted", row["untwisted"] is False and "untwisted" not in read_glb(out)[0]["asset"]["extras"][ground.STAMP])
	check("44.8 deg: the Hips rotation is the source's", _hips_rotations(out) == _hips_rotations(source))
	check("45.2 deg: untwisted", ground.ground_clip(_biped(yaw=[0.0, 45.2, 0.0]))[1]["untwisted"])


def test_a_clip_that_turns_for_good_is_untouched() -> None:
	"""A clip ending 10.2 deg from where it began turns on purpose; 9.8 deg is a swing that returns."""
	check("net 10.2 deg: not untwisted", ground.ground_clip(_biped(yaw=[0.0, 60.0, 10.2]))[1]["untwisted"] is False)
	check("net 9.8 deg: untwisted", ground.ground_clip(_biped(yaw=[0.0, 60.0, 9.8]))[1]["untwisted"])


def test_a_travelling_clip_is_not_untwisted() -> None:
	"""A walk's heading follows its path; only an in-place clip is held still. The 63-key walk with its
	hips swinging 0 -> 90 -> 0 deg is left turning. (Its skeleton has no legs, so an untwist would refuse.)"""
	doc, binary = read_glb(_walk())
	hips = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Hips")
	anim = doc["animations"][0]
	channel = next(c for c in anim["channels"] if c["target"] == {"node": hips, "path": "rotation"})
	binary, out = tail.append_accessor(doc, binary, [_q("y", 90.0 * math.sin(math.pi * k / 62)) for k in range(63)], 5126, "VEC4")
	anim["samplers"].append({"input": anim["samplers"][channel["sampler"]]["input"], "output": out})
	channel["sampler"] = len(anim["samplers"]) - 1
	doc["buffers"][0]["byteLength"] = len(binary)
	_out, row = ground.ground_clip(write_glb(doc, binary), stands=False)
	check("a travelling clip swinging 90 deg is never untwisted", row["heading_swing_deg"] == 90.0 and row["untwisted"] is False)
	check("...and its travel is still extracted", row["root_travel_m"] > 1.0)


def test_the_stamp_records_the_untwist_only_where_it_happened() -> None:
	"""A clip that was untwisted says so in its stamp; the Meshy fixture, which does not swing, does not."""
	stamp = read_glb(ground.ground_clip(_biped())[0])[0]["asset"]["extras"][ground.STAMP]
	check("the stamp records the untwist", stamp["untwisted"] == {"turned_deg": 40.0, "gaze_deg": -40.0, "hips_drop_max_m": 0.0, "decision": "0201"})
	plain = read_glb(ground.ground_clip(fixture._clip(fixture._chained()))[0])[0]["asset"]["extras"][ground.STAMP]
	check("a clip that does not swing has no untwist in its stamp", "untwisted" not in plain and plain["version"] == 3)


def test_a_hips_drop_is_exactly_what_the_reach_needs() -> None:
	"""The hip 0.5 m above a foot directly below, with 0.4 m of reach: down 0.1 m. Within reach: 0."""
	check("a drop of exactly 0.1 m", _near(ground._hip_drop([0.0, 0.5, 0.0], [0.0, 0.0, 0.0], 0.4), 0.1, 1e-12))
	check("0.3 m above: no drop", ground._hip_drop([0.0, 0.3, 0.0], [0.0, 0.0, 0.0], 0.4) == 0.0)
	check("0.3 across, 0.5 up, reach 0.5: down 0.1", _near(ground._hip_drop([0.3, 0.5, 0.0], [0.0, 0.0, 0.0], 0.5), 0.1, 1e-12))


def test_a_raised_idle_is_lowered_where_its_legs_cannot_reach() -> None:
	"""With the hips raised 3 cm on key 2 -- further than the legs ever straighten -- the hips come down
	exactly those 3 cm there, and the feet still stay put."""
	doc, binary = read_glb(_biped())
	hips = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Hips")
	anim = doc["animations"][0]
	channel = next(c for c in anim["channels"] if c["target"] == {"node": hips, "path": "translation"})
	binary, out = tail.append_accessor(doc, binary, [(0.2, 0.5, 0.1), (0.2, 0.5, 0.1), (0.2, 0.53, 0.1), (0.2, 0.5, 0.1), (0.2, 0.5, 0.1)], 5126, "VEC3")
	anim["samplers"].append({"input": anim["samplers"][channel["sampler"]]["input"], "output": out})
	channel["sampler"] = len(anim["samplers"]) - 1
	doc["buffers"][0]["byteLength"] = len(binary)
	result, row = ground.ground_clip(write_glb(doc, binary))
	check("the hips dropped 0.03 m", row["hips_drop_max_m"] == 0.03)
	check("so key 2 is back at 0.5 m", all(_near(p["Hips"][13], 0.5) for p in _poses(result, ("Hips",))))
	check("and the feet did not slide", row["feet_slide_after_m"] == 0.0)


def test_the_gaze_fix_turns_the_head_about_the_vertical() -> None:
	"""With the spine pitched 20 deg on key 0, the head's key-0 world rotation is the source's turned
	about the world vertical by exactly turned + gaze = 0 deg: the nod stays a nod, in the new facing."""
	source = _biped(spine_pitch=[20.0, 25.0, 20.0, 25.0, 20.0])
	out, row = ground.ground_clip(source)
	before, after = _poses(source, ("Head",))[0]["Head"], _poses(out, ("Head",))[0]["Head"]
	turn = math.radians(row["turned_deg"] + row["gaze_deg"])
	c, s_ = math.cos(turn), math.sin(turn)
	expected = [[c * before[4 * i] + s_ * before[4 * i + 2], before[4 * i + 1], -s_ * before[4 * i] + c * before[4 * i + 2]] for i in range(3)]
	check("the head is the source's, turned about the vertical", all(_near(expected[i][j], after[4 * i + j], 1e-5) for i in range(3) for j in range(3)))


def test_the_reach_is_the_clips_straightest_but_never_straighter_than_099() -> None:
	"""A leg the clip holds dead straight may reach 0.99 of its length; one it holds at 0.8, 0.8."""
	def m(y: float) -> list:
		return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.0, y, 0.0, 1]
	check("straight: 0.99", _near(ground._chain_lengths([{0: m(1.0), 1: m(0.5), 2: m(0.0)}], (0, 1, 2))[2], 0.99))
	bent = [{0: m(1.0), 1: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0.3, 0.6, 0.0, 1], 2: m(0.2)}]
	l1, l2, reach = ground._chain_lengths(bent, (0, 1, 2))
	check("bent: the clip's own straightest", _near(reach, 0.8, 1e-12) and _near(l1 + l2, 1.0, 1e-12))


def test_headings_unwrap_and_keys_never_flip() -> None:
	"""A heading crossing 180 deg continues past it; consecutive keys keep their quaternions on one side
	(-150 deg and -100 deg come out of the matrix conversion on opposite sides)."""
	check("170 then -170 is 170 then 190", ground._unwrap([170.0, -170.0]) == [170.0, 190.0])
	quats = ground._quats([ground._yaw(math.radians(-150.0)), ground._yaw(math.radians(-100.0))])
	check("consecutive keys on the same side", sum(a * b for a, b in zip(*quats)) > 0.0)


def _patched(name: str, replacement, action) -> None:
	"""Run `action` with ground.<name> replaced, then put it back."""
	real = getattr(ground, name)
	setattr(ground, name, replacement(real))
	try:
		action()
	finally:
		setattr(ground, name, real)


def test_an_untwist_that_does_not_hold_is_refused() -> None:
	"""Each check on the result catches what only it can see, with the untwist sabotaged three ways:
	- the hips written 3 cm high: the feet float off their pins, which only the 3-D pin check sees
	  (the ground step would otherwise just seat the clip);
	- the untwist skipped but reported done: the hips still swing, and the read-back heading check sees it;
	- key 2's hips moved 5 cm sideways after the untwist: a foot slides, and the read-back slide check sees it."""
	high = lambda real: (lambda doc, hips, world: real(doc, hips, [world[0], world[1] + 0.03, world[2]]))
	_patched("_hips_local", high, lambda: _refuses_with("hips written high refuse", "misses its pin", lambda: ground.ground_clip(_biped())))
	def skip(real):
		def fake(doc: dict, binary: bytes) -> tuple:
			_b, report = real(*read_glb(write_glb(doc, binary)))
			return binary, report
		return fake
	_patched("untwist", skip, lambda: _refuses_with("an untwist not written refuses", "still turn", lambda: ground.ground_clip(_biped())))
	shove = lambda real: (lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times, lifts,
		[[0.0, 0.0], [0.0, 0.0], [0.05, 0.0], [0.0, 0.0], [0.0, 0.0]]))
	_patched("apply_lift", shove, lambda: _refuses_with("a foot moved after the untwist refuses", "slides", lambda: ground.ground_clip(_biped())))


def test_a_crouching_key_bends_the_knees_and_keeps_the_feet() -> None:
	"""The hips 5 cm lower on key 2: the knees swing forward to take it, and the feet stay on their pins."""
	doc, binary = read_glb(_biped())
	hips = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Hips")
	anim = doc["animations"][0]
	channel = next(c for c in anim["channels"] if c["target"] == {"node": hips, "path": "translation"})
	binary, out = tail.append_accessor(doc, binary, [(0.2, 0.5, 0.1), (0.2, 0.5, 0.1), (0.2, 0.45, 0.1), (0.2, 0.5, 0.1), (0.2, 0.5, 0.1)], 5126, "VEC3")
	anim["samplers"].append({"input": anim["samplers"][channel["sampler"]]["input"], "output": out})
	channel["sampler"] = len(anim["samplers"]) - 1
	doc["buffers"][0]["byteLength"] = len(binary)
	result, row = ground.ground_clip(write_glb(doc, binary))
	poses = _poses(result, ("LeftLeg", "LeftFoot"))
	check("key 2's knee comes forward", poses[2]["LeftLeg"][14] > 0.1 and _near(poses[0]["LeftLeg"][14], 0.05))
	check("key 2's foot stays on its pin", _near(poses[2]["LeftFoot"][12], 0.1) and _near(poses[2]["LeftFoot"][13], 0.02) and _near(poses[2]["LeftFoot"][14], 0.0))


def main() -> int:
	"""Run every test and print the summary line."""
	for name, test in sorted(globals().items()):
		if name.startswith("test_") and callable(test):
			try:
				test()
			except Exception as error:  # noqa: BLE001 -- a crash is a failure, not a lost run
				check("%s raised %s: %s" % (name, type(error).__name__, error), False)
	for failure in FAILURES:
		print("FAIL %s" % failure)
	print("test_ground_meshy_clips: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
