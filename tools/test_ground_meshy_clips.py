#!/usr/bin/env python3
"""Self-test for tools/ground_meshy_clips.py (decisions 0193, 0195, 0197, 0201, 0202).

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
  N08  a foot that must be pinned but cannot be refuses (decision 0202): no legs to re-solve, a leg that
       changes length, a gait whose feet never move back. (A contact the leg cannot reach, or whose pin would
       move a kneeling knee, is not refused: it is left and reported -- see the pinning tests.)
  N09  a water clip that breaks its medium's rule refuses (decision 0203): a surface clip whose Head dips
       under the waterline or whose Hips rise above it; a submerged clip any body vertex of which breaks the
       surface (a chained tail's are the spring's, and are not counted); an unknown medium.
  (and a standing clip the seat leaves floating refuses: test_a_seat_that_leaves_the_clip_floating_refuses;
  an untwist that leaves the hips turning or a foot sliding refuses: test_an_untwist_that_does_not_hold_is_refused;
  a pin that does not hold refuses: test_a_pin_that_does_not_hold_is_refused)

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
	_refuses_with("N01 an already-grounded clip refuses", "already grounded", lambda: ground.ground_clip(once))


def test_n02_no_animation_refuses() -> None:
	"""rigged.glb has nothing to ground."""
	_refuses_with("N02 a file with no animation refuses", "no animation", lambda: ground.ground_clip(fixture._chained()))


def test_n03_no_support_refuses() -> None:
	"""With the foot renamed Spine, nothing is support."""
	def rename(doc: dict) -> None:
		next(n for n in doc["nodes"] if n.get("name") == "LeftFoot")["name"] = "Spine"
	_refuses_with("N03 no foot, toe or leg refuses", "no vertex is weighted", lambda: ground.ground_clip(_edit(fixture._clip(fixture._chained()), rename)))


def test_n04_an_animated_ancestor_of_hips_refuses() -> None:
	"""A channel on the Armature root."""
	def animate_root(doc: dict) -> None:
		root = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Armature")
		doc["animations"][0]["channels"].append({"sampler": 2, "target": {"node": root, "path": "translation"}})
	_refuses_with("N04 an animated Hips ancestor refuses", "ancestor of Hips", lambda: ground.ground_clip(_edit(fixture._clip(fixture._chained()), animate_root)))


def test_n05_no_hips_translation_refuses() -> None:
	"""The Hips translation channel removed."""
	def drop(doc: dict) -> None:
		anim = doc["animations"][0]
		anim["channels"] = [c for c in anim["channels"] if c["target"]["path"] != "translation"]
	_refuses_with("N05 no Hips translation refuses", "Hips translation", lambda: ground.ground_clip(_edit(fixture._clip(fixture._chained()), drop)))


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
	_refuses_with("N06 a Hips scale of 1.1765 refuses", "scaled away", lambda: ground.ground_clip(_with_hips_scale(1.1765)))
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
		_refuses_with("a standing clip left floating refuses", "still floats", lambda: ground.ground_clip(fixture._clip(fixture._chained(), hips_y=[0.5] * 5)))
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
		_refuses_with("a lift that leaves the foot below ground refuses", "still reaches", lambda: ground.ground_clip(fixture._clip(fixture._chained())))
	finally:
		ground.apply_lift = real
	## Only the keys that needed no lift are moved: lifting every key would leave the clip floating, and be
	## refused for that before this check is reached (it was, until decision 0202 matched refusals on their reason).
	ground.apply_lift = lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times,
		[x + 0.01 if x == 0.0 else x for x in lifts], roots)
	try:
		_refuses_with("a lift that moves keys needing none refuses", "needed no lift moved", lambda: ground.ground_clip(fixture._clip(fixture._chained())))
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
	"""The hips 0.5 m up (so no lift), travelling 0.5 m/s along +Z with the sway in X and Z. It is graded as a
	gait (decision 0202): its foot, fixed to the hips, moves with them, so it is never planted."""
	path = [(_sway(k), 0.5, 0.5 * WALK_TIMES[k] + _sway(k)) for k in range(63)]
	return fixture._clip(fixture._chained(), times=WALK_TIMES, hips_xyz=path)


def test_a_travelling_clip_is_put_in_place_with_its_sway_kept() -> None:
	"""The 1.0333 m of travel leaves the hips; the stride's sway does not."""
	out, row = ground.ground_clip(_walk(), gait=True)
	doc, binary = read_glb(out)
	_times, path = ground.root_path(doc, binary)
	check("the hips now end where they began", math.hypot(path[-1][0] - path[0][0], path[-1][1] - path[0][1]) < 1e-5)
	check("key 5 keeps its sway in Z", _near(path[5][1] - path[0][1], _sway(5) - _sway(0), 1e-5))
	check("key 5 keeps its sway in X", _near(path[5][0] - path[0][0], _sway(5) - _sway(0), 1e-5))
	check("the travel is reported", _near(row["root_travel_m"], 1.0333, 1e-4) and row["loop_gap_m"] < 1e-4)


def test_the_root_motion_is_recorded_on_the_hips() -> None:
	"""What gameplay needs: the path, the travel and period, the mean speed of 0.5 m/s."""
	out, _row = ground.ground_clip(_walk(), gait=True)
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
		_refuses_with("a clip left travelling half a metre refuses", "still travels", lambda: ground.ground_clip(_walk(), gait=True))
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


def _skeleton(extra: tuple = ()) -> tuple[dict, bytes, list[str]]:
	"""The biped's skeleton and skin: one vertex under each foot, one on the head, and any `extra` vertices:
	((x, y, z), joint) wholly on that joint, or ((x, y, z), joint, second joint, its weight). Returns the doc,
	its BIN and the node names."""
	names = [n for n, _t, _c in BIPED_NODES]
	joints = names[1:]
	nodes = [{"name": n, "translation": t, "children": c} for n, t, c in BIPED_NODES]
	nodes.append({"name": "body", "mesh": 0, "skin": 0})
	verts = [((0.1, 0.0, 0.0), joints.index("LeftFoot"), 0, 0.0), ((-0.1, 0.0, 0.0), joints.index("RightFoot"), 0, 0.0),
		((0.0, 0.8, 0.0), joints.index("Head"), 0, 0.0)] + [(e[0], joints.index(e[1]), joints.index(e[2]) if len(e) > 2 else 0,
		e[3] if len(e) > 2 else 0.0) for e in extra]
	ibm = []
	for j in joints:
		x, y, z = BIPED_REST[j]
		ibm.append((1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -x, -y, -z, 1))
	doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0, 10]}], "nodes": nodes,
		"skins": [{"joints": list(range(1, 10)), "inverseBindMatrices": 3}],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0, "JOINTS_0": 1, "WEIGHTS_0": 2}}]}],
		"accessors": [], "bufferViews": [], "buffers": [{"byteLength": 0}]}
	binary = b""
	binary, _ = tail.append_accessor(doc, binary, [v[0] for v in verts], 5126, "VEC3")
	binary, _ = tail.append_accessor(doc, binary, [(v[1], v[2], 0, 0) for v in verts], 5123, "VEC4")
	binary, _ = tail.append_accessor(doc, binary, [(1.0 - v[3], v[3], 0.0, 0.0) for v in verts], 5126, "VEC4")
	binary, _ = tail.append_accessor(doc, binary, ibm, 5126, "MAT4")
	return doc, binary, names


def _animate(doc: dict, binary: bytes, names: list[str], times: list[float], outs: dict) -> bytes:
	"""The skeleton with one clip: `outs` maps (node name, path) to that channel's rows on `times`."""
	binary, t_in = tail.append_accessor(doc, binary, [(t,) for t in times], 5126, "SCALAR")
	samplers, channels = [], []
	for (name, path), rows in outs.items():
		binary, out = tail.append_accessor(doc, binary, rows, 5126, "VEC4" if path == "rotation" else "VEC3")
		samplers.append({"input": t_in, "output": out})
		channels.append({"sampler": len(samplers) - 1, "target": {"node": names.index(name), "path": path}})
	doc["animations"] = [{"name": "idle", "samplers": samplers, "channels": channels}]
	doc["buffers"][0]["byteLength"] = len(binary)
	return write_glb(doc, binary)


def _biped(yaw: list | None = None, hips_xz: tuple = (0.2, 0.1), drop: tuple = (), head: bool = True,
		leg_len: list | None = None, spine_pitch: list | None = None) -> bytes:
	"""The biped fixture and its clip. `drop` removes named nodes; `leg_len` keys LeftLeg's translation."""
	yaw = yaw or BIPED_YAW
	times = BIPED_TIMES[:len(yaw)]
	doc, binary, names = _skeleton()
	hips_r = [_q_mul(_q("y", y), _q("x", p)) for y, p in zip(yaw, BIPED_PITCH)]
	outs = {("Hips", "rotation"): hips_r, ("Hips", "translation"): [(hips_xz[0], 0.5, hips_xz[1])] * len(times),
		("Spine", "rotation"): [_q("x", p) for p in (spine_pitch or BIPED_PITCH)[:len(times)]]}
	if head:
		outs[("Head", "rotation")] = [_q("y", h) for h in BIPED_HEAD[:len(times)]]
	if leg_len:
		outs[("LeftLeg", "translation")] = [(0.0, -y, 0.05) for y in leg_len]
	for name in drop:
		doc["nodes"][names.index(name)]["name"] = name + "_gone"
	return _animate(doc, binary, names, times, outs)


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


# --- pinning: a planted foot stays where it is planted (decision 0202) ---------------------------
#
# THE STANDER is the biped standing still, keyed at 30 Hz with no yaw, so nothing untwists. Moving its hips
# with the legs unkeyed carries the feet along the ground with them: a planted foot drifting by exactly the
# hips' path. Pitching an UpLeg by theta about X swings that whole leg, so its foot vertex -- 0.5 m below the
# hip, under the ankle -- moves to z = -0.5 sin(theta), height 0.5 - 0.5 cos(theta). Expected values are
# literals, computed by hand from those two lines.

def _pitch_for(z: float) -> float:
	"""The UpLeg pitch, in degrees, that puts that leg's foot vertex at z."""
	return math.degrees(math.asin(-z / 0.5))


def _stander(n: int, hips: list | None = None, pitch: dict | None = None, knee: dict | None = None,
		extra: tuple = (), leg_len: list | None = None, foot: float | None = None, height: float = 0.5,
		flip: bool = False) -> bytes:
	"""The stander over n keys: hips at (x, `height`, z) per key from `hips` (default still at the rest hips);
	each side's UpLeg pitched by `pitch[side]` degrees (its quaternions stored with w < 0 if `flip`), Leg by
	`knee[side]`, and both feet by `foot`; `leg_len` keys LeftLeg's length."""
	doc, binary, names = _skeleton(extra)
	outs = {("Hips", "rotation"): [(0.0, 0.0, 0.0, 1.0)] * n,
		("Hips", "translation"): [(x, height, z) for x, z in (hips or [(0.0, 0.0)] * n)]}
	for side, degrees in (pitch or {}).items():
		outs[(side + "UpLeg", "rotation")] = [tuple(-c for c in _q("x", d)) if flip else _q("x", d) for d in degrees]
	if foot is not None:
		for side in ("Left", "Right"):
			outs[(side + "Foot", "rotation")] = [_q("x", foot)] * n
	for side, degrees in (knee or {}).items():
		outs[(side + "Leg", "rotation")] = [_q("x", d) for d in degrees]
	if leg_len:
		outs[("LeftLeg", "translation")] = [(0.0, -y, 0.05) for y in leg_len]
	return _animate(doc, binary, names, [k / 30 for k in range(n)], outs)


SWAY = [(0.0, 0.0), (0.005, 0.0), (0.01, 0.0), (0.02, 0.0), (0.03, 0.0), (0.02, 0.0), (0.01, 0.0), (0.005, 0.0), (0.0, 0.0)]


def _foot_vertex(data: bytes, side: str) -> list[tuple]:
	"""That side's foot vertex, skinned, on every key."""
	times, points = ground.foot_points(*read_glb(data))
	return [points[side][k][0] for k in range(len(times))]


def _channel_output(data: bytes, name: str, path: str) -> int:
	"""The output accessor of the named node's channel."""
	doc = read_glb(data)[0]
	node = next(i for i, n in enumerate(doc["nodes"]) if n.get("name") == name)
	anim = doc["animations"][0]
	return anim["samplers"][next(c for c in anim["channels"] if c["target"] == {"node": node, "path": path})["sampler"]]["output"]


def test_a_drifting_planted_foot_is_pinned() -> None:
	"""The hips sway 3 cm sideways and back with the legs unkeyed: both feet slide 3 cm. Pinned, each ankle
	stays at (+-0.1, 0.02, 0) on every key; the hips keep their sway; nothing needed lowering."""
	out, row = ground.ground_clip(_stander(9, SWAY))
	poses = _poses(out, ("LeftFoot", "RightFoot", "Hips"))
	check("the left ankle stays at (0.1, 0.02, 0)", all(_near(p["LeftFoot"][12], 0.1) and _near(p["LeftFoot"][13], 0.02)
		and _near(p["LeftFoot"][14], 0.0) for p in poses))
	check("the right ankle stays at (-0.1, 0.02, 0)", all(_near(p["RightFoot"][12], -0.1) and _near(p["RightFoot"][14], 0.0) for p in poses))
	check("the hips keep their sway", all(_near(p["Hips"][12], x) for p, (x, _z) in zip(poses, SWAY)))
	check("reported: 2 contacts, both pinned, 0.03 m -> 0", row["contacts"] == 2 and row["contacts_pinned"] == 2
		and row["contact_slide_before_m"] == 0.03 and row["contact_slide_after_m"] == 0.0 and row["pin_max_m"] == 0.03)
	check("no hips drop, no ramp, nothing left unpinned", row["pin_hips_drop_m"] == 0.0 and row["loop_ramp_m"] == 0.0 and row["unpinned"] == [])
	stamp = read_glb(out)[0]["asset"]["extras"][ground.STAMP]
	check("the stamp records the pin", stamp["pinned"] == {"contacts": 2, "max_move_m": 0.03, "decision": "0202"})


def test_a_slide_within_the_threshold_is_left_alone() -> None:
	"""A 1.99 cm sway is Meshy's noise: nothing is rewritten. 2.01 cm is pinned."""
	small = _stander(5, [(0.0, 0.0), (0.00995, 0.0), (0.0199, 0.0), (0.00995, 0.0), (0.0, 0.0)])
	out, row = ground.ground_clip(small)
	check("1.99 cm: nothing pinned", row["contacts_pinned"] == 0 and "pinned" not in read_glb(out)[0]["asset"]["extras"][ground.STAMP])
	check("1.99 cm: no leg is keyed, as in the source", all(c["target"]["node"] not in (2, 3, 4, 5, 6, 7) for c in read_glb(out)[0]["animations"][0]["channels"]))
	big = _stander(5, [(0.0, 0.0), (0.01005, 0.0), (0.0201, 0.0), (0.01005, 0.0), (0.0, 0.0)])
	check("2.01 cm: pinned", ground.ground_clip(big)[1]["contacts_pinned"] == 2)


## A step: the left foot stands at z = 0 (keys 0-2), lifts -- thigh forward 20 deg, knee bent 60 deg --
## (keys 3-4), stands 10 cm ahead (keys 5-8), lifts again (keys 9-10) and is back at z = 0 on key 11.
STEP_KEYS = 12


def _step(landing: list[float]) -> bytes:
	"""The stander stepping with its left foot; `landing` is the foot's z on keys 5-8."""
	zs = [0.0, 0.0, 0.0, None, None] + landing + [None, None, 0.0]
	pitch = [(-20.0 if z is None else _pitch_for(z)) for z in zs]
	knee = [(60.0 if z is None else 0.0) for z in zs]
	return _stander(STEP_KEYS, pitch={"Left": pitch}, knee={"Left": knee})


def test_a_deliberate_step_is_untouched() -> None:
	"""The step lifts the foot clear of the ground, so the landing starts a contact of its own. Nothing drifts
	within a contact, so nothing is rewritten: the step stays a step."""
	source = _step([0.1, 0.1, 0.1, 0.1])
	out, row = ground.ground_clip(source)
	check("contacts: left at keys 0-2, 5-8 and 11, right throughout",
		row["contact_keys"] == {"Left": [[0, 2], [5, 8], [11, 11]], "Right": [[0, 11]]})
	check("the step is not pinned", row["contacts_pinned"] == 0 and row["contact_slide_before_m"] == 0.0)
	check("the left thigh's channel is the source's", _channel_output(out, "LeftUpLeg", "rotation") == _channel_output(source, "LeftUpLeg", "rotation"))
	check("the landing is 10 cm ahead", all(_near(v[2], 0.1, 1e-6) for v in _foot_vertex(out, "Left")[5:9]))


def test_a_landing_that_drifts_is_held_where_it_lands() -> None:
	"""The same step, the landed foot then sliding 3 cm on: 0.10, 0.11, 0.12, 0.13. Only that contact is
	pinned, at 0.10, where it landed; the stand before the step and after it are the source's."""
	out, row = ground.ground_clip(_step([0.1, 0.11, 0.12, 0.13]))
	feet = _foot_vertex(out, "Left")
	check("one contact pinned, 0.03 m -> 0", row["contacts_pinned"] == 1 and row["contact_slide_before_m"] == 0.03
		and row["contact_slide_after_m"] == 0.0)
	check("keys 5-8 hold the landing, z 0.10", all(_near(v[2], 0.1, 1e-5) for v in feet[5:9]))
	check("keys 0-2 and 11 stand at z 0, as in the source", all(_near(feet[k][2], 0.0, 1e-9) for k in (0, 1, 2, 11)))


## An in-place gait: 13 keys, a 0.4 s loop. The left foot is planted on keys 0-8 and swings on 9-12; the right
## is planted on keys 2-10 and swings on 10-12 and 0-2. Each planted step moves back 0.02 m (0.6 m/s at 30
## Hz), except five: the left's go 0.015 (it creeps 2.5 cm forward against the ground), the right's 0.025
## (2.5 cm back). The mean over every planted step is exactly 0.6 m/s.
GAIT_LEFT = [0.0675, 0.0475, 0.0325, 0.0175, 0.0025, -0.0125, -0.0275, -0.0475, -0.0675, -0.03375, 0.0, 0.03375, 0.0675]
GAIT_RIGHT = [0.0, 0.04625, 0.0925, 0.0725, 0.0475, 0.0225, -0.0025, -0.0275, -0.0525, -0.0725, -0.0925, -0.04625, 0.0]


def _gait() -> bytes:
	"""The stander walking in place: GAIT_LEFT and GAIT_RIGHT are each foot's z per key."""
	return _stander(13, pitch={"Left": [_pitch_for(z) for z in GAIT_LEFT], "Right": [_pitch_for(z) for z in GAIT_RIGHT]})


def test_a_gaits_planted_foot_moves_back_at_its_ground_speed() -> None:
	"""The gait's speed is found (0.6 m/s) and recorded; each planted foot then moves back exactly 0.02 m a key:
	the left from where the loop starts (0.0675, the seam), the right from where it lands (0.0925 on key 2)."""
	out, row = ground.ground_clip(_gait(), gait=True)
	left, right = _foot_vertex(out, "Left"), _foot_vertex(out, "Right")
	check("the gait's speed is 0.6 m/s", row["gait_speed_m_s"] == 0.6)
	check("both stances crept 2.5 cm, and are pinned", row["contact_slide_before_m"] == 0.025 and row["contacts_pinned"] == 2
		and row["contact_keys"] == {"Left": [[0, 8]], "Right": [[2, 10]]})
	check("the left moves back 0.02 m a key over keys 0-8", all(_near(left[k][2], 0.0675 - 0.02 * k, 1e-5) for k in range(9)))
	check("the right moves back 0.02 m a key over keys 2-10", all(_near(right[k][2], 0.0925 - 0.02 * (k - 2), 1e-5) for k in range(2, 11)))
	check("read back on a ground moving at 0.6 m/s, nothing slides", row["contact_slide_after_m"] == 0.0)
	check("each swing covers one stride, 0.24 m, along the ground", row["ground_scrape_m"] == 0.24)
	hips = next(n for n in read_glb(out)[0]["nodes"] if n.get("name") == "Hips")
	check("the Hips carry the gait", hips["extras"]["gait"] == {"speed_m_s": 0.6, "period_s": 0.4, "stride_m": 0.24, "decision": "0202"})


def test_a_standing_clip_is_not_graded_as_a_gait() -> None:
	"""The same file graded as standing: every foot touches the ground throughout, so each is one contact, and
	nothing is recorded on the Hips."""
	out, row = ground.ground_clip(_gait())
	check("no gait speed", "gait_speed_m_s" not in row and "gait" not in next(n for n in read_glb(out)[0]["nodes"] if n.get("name") == "Hips").get("extras", {}))
	check("standing contacts are by height", row["contact_keys"] == {"Left": [[0, 12]], "Right": [[0, 12]]})


def test_n08_pinning_refuses_what_it_cannot_solve() -> None:
	"""A drifting foot on a skeleton with no legs to re-solve; a leg that changes length; a gait whose feet
	never move back. Each for its own reason."""
	path = [(0.01 * x, -0.048, 0.0) for x in (0, 1, 3, 1, 0)]
	_refuses_with("N08 a drifting foot with no legs refuses", "re-solving the legs needs",
		lambda: ground.ground_clip(fixture._clip(fixture._chained(), times=fixture.TIMES, hips_xyz=path)))
	_refuses_with("N08 a pinned leg that changes length refuses", "changes length",
		lambda: ground.ground_clip(_stander(9, SWAY, leg_len=[0.24, 0.24, 0.24, 0.24, 0.25, 0.24, 0.24, 0.24, 0.24])))
	_refuses_with("N08 a gait whose feet never move back refuses", "never move back",
		lambda: ground.gait_speed([0.0, 1 / 30, 2 / 30], [[[(0.0, 0.0, 0.0)], [(0.0, 0.0, 0.01)], [(0.0, 0.0, 0.02)]]]))


def test_a_contact_the_leg_cannot_reach_is_left_and_reported() -> None:
	"""A 40 cm sway: holding the feet would need them 40 cm from under the hips, beyond the legs' reach. The
	contacts are left as they are, reported with their reason, and the clip still grounds."""
	far = [(0.0, 0.0), (0.2, 0.0), (0.4, 0.0), (0.2, 0.0), (0.0, 0.0)]
	out, row = ground.ground_clip(_stander(5, far))
	check("both contacts reported unreachable", row["unpinned"] == [{"side": "Left", "keys": [0, 4], "slide_m": 0.4, "reason": "reach"},
		{"side": "Right", "keys": [0, 4], "slide_m": 0.4, "reason": "reach"}])
	check("nothing pinned or recorded", row["contacts_pinned"] == 0 and "pinned" not in read_glb(out)[0]["asset"]["extras"][ground.STAMP])


def test_a_pin_that_would_move_the_support_is_left_and_reported() -> None:
	"""A spur on the left shin, 0.2 m ahead of it and 5 mm below the feet, is what the clip stands on (as a
	kneeling knee is). Swaying the hips 3 cm forward and back, holding the left foot would swing the shin and
	lift the spur more than 1 cm: that contact is left, reported "support". The right foot is pinned."""
	sway = [(0.0, z) for z in (0.0, 0.01, 0.03, 0.01, 0.0)]
	out, row = ground.ground_clip(_stander(5, sway, extra=(((0.1, -0.005, 0.25), "LeftLeg"),)))
	check("the left contact is left for the support", [u["reason"] for u in row["unpinned"]] == ["support"]
		and row["unpinned"][0]["side"] == "Left")
	check("the right contact is pinned", row["contacts_pinned"] == 1)
	check("the right ankle holds (-0.1, 0.02, 0)", all(_near(p["RightFoot"][14], 0.0) for p in _poses(out, ("RightFoot",))))


def test_a_pin_that_does_not_hold_is_refused() -> None:
	"""Two checks, each seeing what only it can: the legs left unsolved (the in-memory check of every pinned
	contact), and a key shoved sideways after the pin by the final lift (the read-back from the written file)."""
	unsolved = lambda real: (lambda doc, worlds, animated, hips, chain, targets: real(doc, worlds, animated, hips, chain, [None] * len(targets)))
	_patched("_pin_leg", unsolved, lambda: _refuses_with("legs left unsolved refuse", "in its contact", lambda: ground.ground_clip(_stander(9, SWAY))))
	shove = lambda real: (lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times, lifts,
		[[0.0, 0.0]] * 4 + [[0.03, 0.0]] + [[0.0, 0.0]] * 4))
	_patched("apply_lift", shove, lambda: _refuses_with("a foot shoved after the pin refuses", "after pinning", lambda: ground.ground_clip(_stander(9, SWAY))))


def test_contacts_are_by_height_standing_and_by_speed_in_a_gait() -> None:
	"""Standing: within 0.02 m of the ground. In a gait at 0.6 m/s (0.01 m a key at 30 Hz is half of it):
	moving with the ground slower than that, for at least 3 keys."""
	times = [k / 30 for k in range(6)]
	check("standing: 0.019 is planted, 0.021 is not", ground.contacts(times, [[0.0, 0.0]] * 5, [0.0, 0.019, 0.021, 0.0, 0.0, 0.03], None)
		== [(0, 1), (3, 4)])
	slips = [[0.0, 0.009], [0.0, 0.011], [0.006, 0.0], [0.0, 0.0], [0.0, 0.02]]
	check("gait: 0.009 planted, 0.011 not; 2 keys too short", ground.contacts(times, slips, [0.5] * 6, 0.6) == [(2, 4)])
	check("gait: 0.009 both ways planted, from 3 keys", ground.contacts(times, [[0.0, 0.009], [0.0, -0.009], [0.0, 0.02]] + [[0.0, 0.02]] * 2, [0.5] * 6, 0.6) == [(0, 2)])


def test_slips_are_the_contact_points_move_less_the_grounds() -> None:
	"""The lowest point on each key is followed to the next; the ground's own move is taken off."""
	points = [[(0.0, 0.1, 0.0), (0.0, 0.0, 0.0)], [(0.0, 0.0, 0.5), (0.01, 0.05, -0.02)], [(0.0, 0.0, 0.46), (0.0, 0.0, 0.0)]]
	slips = ground.foot_slips([0.0, 1 / 30, 2 / 30], points, [[0.0, -0.02], [0.0, -0.02]])
	check("key 0's lowest (the second point) moves (0.01, -0.02); less the ground: (0.01, 0)", all(_near(a, b) for a, b in zip(slips[0], (0.01, 0.0))))
	check("key 1's lowest (the first) moves (0, -0.04); less the ground: (0, -0.02)", all(_near(a, b) for a, b in zip(slips[1], (0.0, -0.02))))


def test_a_contact_slide_is_measured_from_where_it_is_held() -> None:
	"""From the landing; from the seam for a contact at the loop's end; less the loop-closing ramp for one
	spanning the whole clip."""
	times = [k / 30 for k in range(5)]
	slips = [[0.01, 0.0], [0.01, 0.0], [0.01, 0.0], [0.01, 0.0]]
	check("from the landing: 0.02 at keys 1-3", _near(ground.contact_slide(times, slips, [(1, 3)]), 0.02))
	check("at the loop's end: from key 4, 0.03 at key 1", _near(ground.contact_slide(times, slips, [(1, 4)]), 0.03))
	check("the whole clip, a steady 0.04: all ramp", _near(ground.contact_slide(times, slips, [(0, 4)]), 0.0)
		and _near(ground.loop_ramp(times, slips, [(0, 4)]), 0.04))
	out_back = [[0.01, 0.0], [0.01, 0.0], [-0.01, 0.0], [-0.01, 0.0]]
	check("the whole clip, out 0.02 and back: 0.02, no ramp", _near(ground.contact_slide(times, out_back, [(0, 4)]), 0.02)
		and ground.loop_ramp(times, out_back, [(0, 4)]) == 0.0)


def test_pin_corrections_hold_each_contact_and_ease_between() -> None:
	"""Ten keys; a contact on keys 2-5 creeping 0.01 m a key in x. Held where it lands: 0, -0.01, -0.02, -0.03.
	Before it, nothing; after it, smoothstep back to nothing at the seam (key 9)."""
	times = [k / 30 for k in range(10)]
	slips = [[0.0, 0.0]] * 2 + [[0.01, 0.0]] * 3 + [[0.0, 0.0]] * 4
	moves, pinned, unreachable = ground.pin_corrections(times, slips, [(2, 5)])
	check("pinned, none unreachable", pinned == [(2, 5)] and unreachable == [])
	check("held: 0, -0.01, -0.02, -0.03", all(_near(moves[k][0], x) for k, x in zip(range(2, 6), (0.0, -0.01, -0.02, -0.03))))
	check("keys 0-1: nothing", moves[0] == [0.0, 0.0] and moves[1] == [0.0, 0.0])
	check("keys 6-9 ease back: -0.0253125, -0.015, -0.0046875, 0", all(_near(moves[k][0], x) for k, x in
		zip(range(6, 10), (-0.0253125, -0.015, -0.0046875, 0.0))))
	end, _p, _u = ground.pin_corrections(times, slips[:2] + [[0.0, 0.0]] * 4 + [[0.01, 0.0]] * 3, [(6, 9)])
	check("a contact at the loop's end is held there: 0.03, 0.02, 0.01, 0", all(_near(end[k][0], x) for k, x in zip(range(6, 10), (0.03, 0.02, 0.01, 0.0))))
	check("0.0199: not pinned; kept or ineligible: not pinned", ground.pin_corrections(times, [[0.00995, 0.0]] * 2 + [[0.0, 0.0]] * 7, [(0, 2)])[1] == []
		and ground.pin_corrections(times, slips, [(2, 5)], keep=[(2, 5)])[1] == []
		and ground.pin_corrections(times, slips, [(2, 5)], eligible=[(0, 1)])[1] == [])


def test_a_long_gap_eases_out_and_in_over_a_quarter_second() -> None:
	"""Contacts 0.6 s apart (keys 0 and 18): the move eases out over 0.25 s after the first, is nothing in the
	middle, and eases in over 0.25 s before the second. A gap of 0.5 s or less eases across the whole of it."""
	times = [k / 30 for k in range(19)]
	moves = [[0.03, 0.0]] + [None] * 17 + [[-0.03, 0.0]]
	ground._ease(times, moves)
	check("0.1 s after: smoothstep(0.4) of the way out", _near(moves[3][0], 0.03 * (1 - 0.4 * 0.4 * (3 - 0.8))))
	check("0.3 s in: nothing", moves[9] == [0.0, 0.0])
	check("0.1 s before the next: smoothstep(0.6) of the way in", _near(moves[15][0], -0.03 * (0.6 * 0.6 * (3 - 1.2))))
	short = [[0.03, 0.0]] + [None] * 14 + [[-0.03, 0.0]]
	ground._ease(times[:16], short)
	check("0.5 s apart: across the whole gap", _near(short[5][0], 0.03 - 0.06 * ((1 / 3) ** 2 * (3 - 2 / 3))))


def test_a_contact_is_held_where_the_leg_can_reach_it() -> None:
	"""With `drop` the hips' lowering a move needs: a landing needing none is kept; else the anchor needing
	least; within PIN_DROP_MAX_M (0.03) it is pinned, beyond it reported unreachable."""
	times = [k / 30 for k in range(10)]
	slips = [[0.0, 0.0]] * 2 + [[0.01, 0.0]] * 3 + [[0.0, 0.0]] * 4
	## A drop of as much as the foot is moved: held where it lands the worst key needs 0.03; held at key 3 or 4,
	## 0.02 -- key 3 is the first of those.
	moves, pinned, _u = ground.pin_corrections(times, slips, [(2, 5)], lambda k, move: abs(move[0]))
	check("held at key 3, which asks least of the leg", pinned == [(2, 5)]
		and all(_near(moves[k][0], x) for k, x in zip(range(2, 6), (0.01, 0.0, -0.01, -0.02))))
	check("a landing needing no drop is kept", ground.pin_corrections(times, slips, [(2, 5)], lambda k, move: 0.0)[0][2] == [0.0, 0.0])
	check("a drop of 0.03 is allowed", ground.pin_corrections(times, slips, [(2, 5)], lambda k, m: 0.03 if m != [0.0, 0.0] else 0.0)[1] == [(2, 5)])
	check("0.031 is not", ground.pin_corrections(times, slips, [(2, 5)], lambda k, m: 0.031 if m != [0.0, 0.0] else 0.0)[2] == [(2, 5)])
	swing = lambda k, m: math.inf if k == 7 and m != [0.0, 0.0] else 0.0
	check("a swing key out of reach gives up the nearest contact", ground.pin_corrections(times, slips, [(2, 5)], swing)[1:] == ([], [(2, 5)]))


def test_the_hips_drop_is_what_the_reach_needs_eased() -> None:
	"""A lone 0.01 m drop on key 5 of 11, eased over 4 keys either side: never less than asked, 0.01 over keys
	1-9, less at the ends, and the two seam keys equal."""
	eased = ground.smooth_drops([0.0] * 5 + [0.01] + [0.0] * 5)
	check("key 5: 0.01", _near(eased[5], 0.01))
	check("key 1: 5/6 of it (the window runs off the start)", _near(eased[1], 0.01 * 5 / 6))
	check("the seams: 4/5 of it, equal", _near(eased[0], 0.008) and eased[0] == eased[-1])
	check("never less than asked", all(e >= d for e, d in zip(eased, [0.0] * 5 + [0.01] + [0.0] * 5)))


def test_a_legs_drop_is_zero_within_reach_and_infinite_beyond() -> None:
	"""A 1 m leg (0.5 + 0.5) hanging 0.9 m straight down: its reach is 0.99 m. Moving the ankle 0.3 m across
	needs no drop (sqrt(0.81 + 0.09) = 0.949); 0.5 m needs 0.9 - sqrt(0.99^2 - 0.25) = 0.0455 m; 1.0 m is beyond."""
	def m(x: float, y: float) -> list:
		return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, 0.0, 1]
	worlds = [{0: m(0.0, 1.0), 1: m(math.sqrt(0.25 - 0.45 ** 2), 0.55), 2: m(0.0, 0.1)}]
	drop = ground.leg_drop(worlds, (0, 1, 2))
	check("0.3 m: none", drop(0, [0.3, 0.0]) == 0.0)
	check("0.5 m: 0.0455", _near(drop(0, [0.5, 0.0]), 0.9 - math.sqrt(0.99 ** 2 - 0.25), 1e-12))
	check("1.0 m: beyond", drop(0, [1.0, 0.0]) == math.inf)
	check("no move: none", drop(0, [0.0, 0.0]) == 0.0)


def test_a_gait_speed_is_where_its_planted_feet_agree() -> None:
	"""Two feet stepping back 0.02, 0.015 and 0.025 m a key at 30 Hz: 0.6 m/s. Where two speeds would both hold,
	the one nearest the median backward speed is taken."""
	def track(steps: list[float]) -> list[list[tuple]]:
		z, out = 0.0, [[(0.0, 0.0, 0.0)]]
		for dz in steps:
			z += dz
			out.append([(0.0, 0.0, z)])
		return out
	times = [k / 30 for k in range(9)]
	feet = [track([-0.02, -0.015, -0.015, -0.02, 0.07, 0.0, 0.0, 0.0]), track([-0.02, -0.025, -0.025, -0.02, 0.09, 0.0, 0.0, 0.0])]
	check("0.6 m/s", _near(ground.gait_speed(times, feet), 0.6, 1e-9))
	## 12 steps back at 0.7 m/s and 10 at 1.2: the median is 0.7. Seeded at 0.84 (1.2 x 0.7) both are planted and
	## the mean, 0.927, holds too; every lower seed settles on 0.7.
	many = [k / 30 for k in range(23)]
	two = [track([-0.7 / 30] * 12 + [-1.2 / 30] * 10)]
	check("two speeds hold: the one nearest the median, 0.7", _near(ground.gait_speed(many, two), 0.7, 1e-9))
	check("seeded high, it settles on 0.927", _near(ground._settle([(0.0, -0.7 / 30, 1 / 30)] * 12 + [(0.0, -1.2 / 30, 1 / 30)] * 10, 0.84), (8.4 + 12.0) / 22, 1e-9))
	check("nothing planted: no speed", ground._settle([(0.0, 0.5, 1 / 30)], 0.6) is None)


def test_a_ground_scrape_is_the_longest_drag_outside_contacts() -> None:
	"""Steps along the ground outside contacts add up; one off the ground ends the run."""
	slips = [[0.0, 0.03], [0.0, 0.04], [0.0, 0.05], [0.0, 0.01], [0.0, 0.02]]
	heights = [0.0, 0.01, 0.0, 0.05, 0.0, 0.0]
	check("0.07 before the lift, 0.02 after; inside a contact nothing counts", _near(ground.ground_scrape(slips, heights, []), 0.07)
		and _near(ground.ground_scrape(slips, heights, [(0, 1)]), 0.04))


def test_the_gait_clips_are_named() -> None:
	"""The walk, the run and the two carry walks are gaits; the idle and the chair are not."""
	check("gaits", all(ground.is_gait(f"/lib/k/tailed/{c}.glb") for c in ("anim_walk", "anim_run", "anim_carry_heavy_object_walk",
		"anim_carry_water_bucket_walk")))
	check("not gaits", not ground.is_gait("/lib/k/tailed/anim_idle.glb") and not ground.is_gait("/lib/k/tailed/anim_collect_object.glb"))


def test_anchors_prefer_the_landing_and_keep_the_seam() -> None:
	"""A contact is held where it lands, else anywhere in it; one touching the loop's seam only there."""
	check("interior", ground._anchors(10, 2, 5) == [2, 3, 4, 5])
	check("at the start", ground._anchors(10, 0, 5) == [0])
	check("at the end", ground._anchors(10, 6, 9) == [9])


## A travelling gait: the hips go forward 0.01 m a key (0.3 m/s), 13 keys. The left foot stands on the ground
## at z = 0.06 on keys 0-8, creeping forward 0.004 m a key on keys 2-7 (2.4 cm in all), then swings 0.024 m a
## key to 0.18 -- one loop's travel on -- by key 12. The right stands at 0.08 on keys 2-10 without creeping.
TRAVEL_HIPS = [0.01 * k for k in range(13)]
TRAVEL_LEFT = [0.06, 0.06, 0.064, 0.068, 0.072, 0.076, 0.08, 0.084, 0.084, 0.108, 0.132, 0.156, 0.18]
TRAVEL_RIGHT = [0.02, 0.05, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.08, 0.11, 0.14]


def test_a_travelling_gaits_planted_foot_stays_put_on_the_ground() -> None:
	"""The creeping left contact is pinned where it lands, at z = 0.06; the right, which does not creep, is not
	pinned. Read back in place, with the recorded root motion added back, the left foot stays at 0.06."""
	pitch = {"Left": [_pitch_for(z - h) for z, h in zip(TRAVEL_LEFT, TRAVEL_HIPS)],
		"Right": [_pitch_for(z - h) for z, h in zip(TRAVEL_RIGHT, TRAVEL_HIPS)]}
	out, row = ground.ground_clip(_stander(13, [(0.0, h) for h in TRAVEL_HIPS], pitch=pitch), gait=True)
	check("travelling: contacts left 0-8, right 2-10", row["contact_keys"] == {"Left": [[0, 8]], "Right": [[2, 10]]})
	check("the left creep is pinned, the right left alone", row["contacts_pinned"] == 1 and row["contact_slide_before_m"] == 0.024)
	check("read back on the travelling ground, nothing slides", row["contact_slide_after_m"] == 0.0)
	roots = next(n for n in read_glb(out)[0]["nodes"] if n.get("name") == "Hips")["extras"]["root_motion"]["keys_xz"]
	left = _foot_vertex(out, "Left")
	check("the left foot, root added back, stays at z 0.06 on keys 0-8", all(_near(left[k][2] + roots[k][1], 0.06, 1e-4) for k in range(9)))
	check("no gait speed is recorded for a travelling gait", "gait_speed_m_s" not in row)


## Sway beyond the legs' slack: 9 cm sideways at key 4. A leg 0.48 m from hip to ankle, of bones sqrt(0.24^2 +
## 0.05^2) each, may reach 0.99 of 0.490306; holding the foot 0.09 m aside then needs the hips down by
## 0.48 - sqrt(0.485303^2 - 0.09^2) = 0.003008 m on key 4, eased (4 keys either side) over the whole 9-key clip.
WIDE = [(0.0, 0.0), (0.02, 0.0), (0.045, 0.0), (0.07, 0.0), (0.09, 0.0), (0.07, 0.0), (0.045, 0.0), (0.02, 0.0), (0.0, 0.0)]


def test_hips_come_down_where_a_leg_cannot_reach() -> None:
	"""The hips drop 0.003008 m on every key, and both ankles still hold (+-0.1, 0.02, 0) -- the loop's seam keys
	too, where nothing moves the feet but the hips are lower."""
	out, row = ground.ground_clip(_stander(9, WIDE))
	reach = 0.99 * 2.0 * math.sqrt(0.24 ** 2 + 0.05 ** 2)
	drop = 0.48 - math.sqrt(reach ** 2 - 0.09 ** 2)
	poses = _poses(out, ("Hips", "LeftFoot", "RightFoot"))
	check("reported: the hips drop 0.003", row["pin_hips_drop_m"] == round(drop, 4) and row["contacts_pinned"] == 2)
	check("the hips are down by the drop on every key", all(_near(p["Hips"][13], 0.5 - drop, 1e-6) for p in poses))
	check("both ankles hold on every key, the seams too", all(_near(p[f][13], 0.02, 1e-6) and _near(p[f][12], x, 1e-6) and _near(p[f][14], 0.0, 1e-6)
		for p in poses for f, x in (("LeftFoot", 0.1), ("RightFoot", -0.1))))


def test_a_pinned_foot_keeps_its_own_rotation() -> None:
	"""With both feet pitched 20 deg on their shins, the pinned feet keep that world rotation on every key."""
	source = _stander(9, SWAY, foot=20.0)
	out, _row = ground.ground_clip(source)
	before, after = _poses(source, ("LeftFoot",)), _poses(out, ("LeftFoot",))
	check("the left foot's world rotation is the source's", all(_near(a["LeftFoot"][i], b["LeftFoot"][i], 1e-6) for a, b in zip(before, after) for i in range(11)))


def test_pinned_keys_keep_the_side_of_their_neighbours() -> None:
	"""The thighs keyed at rest but stored with w = -1: every pinned key stays on that side, so LINEAR keys do
	not swing the long way round."""
	out, _row = ground.ground_clip(_stander(9, SWAY, pitch={"Left": [0.0] * 9, "Right": [0.0] * 9}, flip=True))
	doc, binary = read_glb(out)
	anim = doc["animations"][0]
	channel = next(c for c in anim["channels"] if c["target"] == {"node": 2, "path": "rotation"})
	keys = tail.read_accessor(doc, binary, anim["samplers"][channel["sampler"]]["output"])
	check("consecutive thigh keys on one side", all(sum(a * b for a, b in zip(p, q)) > 0.0 for p, q in zip(keys, keys[1:])))


def test_a_sole_on_the_shin_too_is_pinned_in_more_passes() -> None:
	"""A toe vertex 0.2 m ahead of the left ankle and 1 mm under it, weighted 0.55 to the foot and 0.45 to the
	shin, is the foot's contact point. With the hips swaying 4 cm forward and back, one IK pass leaves it 0.8 mm
	off (the shin turns under it); the passes that follow bring it within 0.05 mm."""
	forward = [(0.0, z) for z in (0.0, 0.01, 0.02, 0.03, 0.04, 0.03, 0.02, 0.01, 0.0)]
	toe = (((0.1, -0.001, 0.2), "LeftFoot", "LeftLeg", 0.45),)
	_out, row = ground.ground_clip(_stander(9, forward, extra=toe))
	check("pinned, and read back to within 0.05 mm", row["contacts_pinned"] == 2 and row["contact_slide_after_m"] == 0.0)


def test_only_foot_and_toe_vertices_are_the_foot() -> None:
	"""The spur on the left shin is support, but not part of the foot: the left foot is its one vertex."""
	data = _stander(3, extra=(((0.1, -0.005, 0.25), "LeftLeg"),))
	check("one left foot vertex", len(ground.foot_points(*read_glb(data))[1]["Left"][0]) == 1)


def test_a_floating_clip_is_planted_from_where_it_is_seated() -> None:
	"""The sway with the hips 0.1 m higher: the feet float 0.1 m, the clip is seated, and the feet -- in
	contact once it is -- are pinned."""
	out, row = ground.ground_clip(_stander(9, SWAY, height=0.6))
	check("seated 0.1 m, and both feet pinned", row["seated_m"] == 0.1 and row["contacts_pinned"] == 2)


def test_the_support_culprit_is_the_leg_that_moved_it() -> None:
	"""The spur on the RIGHT shin this time: the right contact is left for the support, the left one pinned."""
	sway = [(0.0, z) for z in (0.0, 0.01, 0.03, 0.01, 0.0)]
	_out, row = ground.ground_clip(_stander(5, sway, extra=(((-0.1, -0.005, 0.25), "RightLeg"),)))
	check("the right contact is left for the support", [(u["side"], u["reason"]) for u in row["unpinned"]] == [("Right", "support")])
	check("the left is pinned", row["contacts_pinned"] == 1)


def test_edges_are_inclusive() -> None:
	"""0.02 m up is planted; a contact straying exactly 0.02 m is not pinned; two contacts either side of an
	unreachable swing key: the nearer is given up."""
	check("0.02 is planted", ground.contacts([0.0, 1 / 30], [[0.0, 0.0]], [0.02, 0.03], None) == [(0, 0)])
	times = [k / 30 for k in range(10)]
	check("exactly 0.02: not pinned", ground.pin_corrections(times, [[0.0, 0.0]] + [[0.01, 0.0]] * 2 + [[0.0, 0.0]] * 6, [(1, 3)])[1] == [])
	slips = [[0.0, 0.0]] + [[0.02, 0.0]] * 2 + [[0.0, 0.0]] * 3 + [[0.02, 0.0]] * 2 + [[0.0, 0.0]]
	swing = lambda k, m: math.inf if k == 4 and m != [0.0, 0.0] else 0.0
	_m, pinned, unreachable = ground.pin_corrections(times, slips, [(1, 3), (6, 8)], swing)
	check("the nearer contact is given up", pinned == [(6, 8)] and unreachable == [(1, 3)])


def test_a_leg_the_clip_holds_straighter_may_reach_as_far() -> None:
	"""A 1 m leg the clip holds 0.995 straight: its reach is 0.995, not 0.99. Moving the ankle 0.05 m across
	needs 0.995 - sqrt(0.995^2 - 0.05^2) of drop."""
	def m(x: float, y: float) -> list:
		return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, 0.0, 1]
	worlds = [{0: m(0.0, 1.0), 1: m(math.sqrt(0.25 - 0.4975 ** 2), 0.5025), 2: m(0.0, 0.005)}]
	check("0.05 m: the clip's own reach", _near(ground.leg_drop(worlds, (0, 1, 2))(0, [0.05, 0.0]), 0.995 - math.sqrt(0.995 ** 2 - 0.0025), 1e-9))


def test_the_seams_share_the_hips_drop() -> None:
	"""A drop asked only near the start eases into the first keys; the last key takes the first's, so the
	loop closes."""
	eased = ground.smooth_drops([0.0, 0.01] + [0.0] * 9)
	check("the seams equal, and not zero", eased[0] == eased[-1] and eased[0] > 0.0)


def test_a_gait_speed_seeded_off_the_median_can_settle_nearer_it() -> None:
	"""Two steps back at 0.5 m/s, one at 0.9, one at 1.4: the median is 0.9. Seeded at 0.72-0.99 the speed
	settles at 0.6333 (the 0.5s and the 0.9); at 1.08, at 1.15 (the 0.9 and the 1.4) -- which is nearer."""
	dt = 1 / 30
	def track(speeds: list[float]) -> list[list[tuple]]:
		z, out = 0.0, [[(0.0, 0.0, 0.0)]]
		for v in speeds:
			z -= v * dt
			out.append([(0.0, 0.0, z)])
		return out
	check("1.15", _near(ground.gait_speed([k * dt for k in range(5)], [track([0.5, 0.5, 0.9, 1.4])]), 1.15, 1e-9))


def test_the_support_culprit_is_the_side_that_moved_it_nearest_the_key() -> None:
	"""With the lowest support point on key 8 given: the side of the old lowest if it rose, of the new lowest
	if it sank; that side's pinned contact nearest key 8; any side's if that side has none."""
	saved, doc = {"clip": "saved"}, {"clip": "pinned"}
	plans = {"Left": ([(0, 9)], None), "Right": ([(0, 3), (6, 9)], None)}
	def culprit(before: tuple, after: tuple, chosen: dict = plans) -> tuple:
		real = ground._lowest_support_side
		ground._lowest_support_side = lambda d, b, k: before if d is saved else after
		try:
			return ground._support_culprit(saved, b"", doc, b"", 8, chosen)
		finally:
			ground._lowest_support_side = real
	check("the old lowest rose: its side", culprit((-0.005, "Right"), (0.0, "Left")) == ("Right", (6, 9)))
	check("a new lowest sank below it: its side", culprit((0.0, "Left"), (-0.02, "Right")) == ("Right", (6, 9)))
	check("of that side's contacts, the nearest key 8", culprit((-0.005, "Right"), (0.0, "Right")) == ("Right", (6, 9)))
	check("a side with none pinned: the nearest of any", culprit((0.0, "Right"), (0.0, "Right"), {"Left": ([(0, 3), (5, 7)], None)}) == ("Left", (5, 7)))


# --- water clips (decision 0203) ---------------------------------------------------------------
#
# The stander's rest: Hips 0.5, Spine 0.6, Head joint 0.75, head vertex 0.8, foot vertices 0. Held at hips height
# h, the Head joint is at h + 0.25, the head vertex at h + 0.3 and the feet at h - 0.5: far under any ground.

def _swimmer(height: float, n: int = 5, extra: tuple = (), rename: dict | None = None, hips: list | None = None) -> bytes:
	"""The stander held at hips height `height` on every key, optionally with nodes renamed."""
	data = _stander(n, height=height, extra=extra, hips=hips)
	return _edit(data, lambda doc: [n.__setitem__("name", rename[n["name"]]) for n in doc["nodes"] if n.get("name") in (rename or {})])


def test_n09_a_water_clip_that_breaks_its_rule_refuses() -> None:
	"""Surface: Head 0.25 above the hips must clear y = 0 and the hips must not. Submerged: nothing breaks it."""
	_refuses_with("N09 a surface clip whose Head dips under refuses", "Head above the waterline",
		lambda: ground.ground_clip(_swimmer(-0.26), stands=False, water="surface"))
	_refuses_with("N09 a surface clip whose Hips rise above refuses", "Head above the waterline",
		lambda: ground.ground_clip(_swimmer(0.0), stands=False, water="surface"))
	_refuses_with("N09 a submerged clip whose head breaks the surface refuses", "breaks the surface",
		lambda: ground.ground_clip(_swimmer(-0.29), stands=False, water="submerged"))
	_refuses_with("N09 an unknown medium refuses", "unknown water medium",
		lambda: ground.ground_clip(_swimmer(-0.5), stands=False, water="lava"))
	_refuses_with("N09 a body vertex above the surface is counted", "breaks the surface",
		lambda: ground.ground_clip(_swimmer(-0.9, extra=(((0.0, 1.5, 0.0), "Spine"),)), stands=False, water="submerged"))


def test_a_surface_clip_is_held_at_the_waterline_not_the_ground() -> None:
	"""Hips at -0.1 on every key: the feet are 0.6 m under the ground, and nothing is lifted, seated or pinned."""
	source = _swimmer(-0.1)
	out, row = ground.ground_clip(source, stands=False, water="surface")
	check("no hips key moves", all(_near(y, -0.1) for y in _hips_y(out)))
	check("nothing lifted or seated", row["keys_lifted"] == 0 and row["max_lift_m"] == 0.0 and row["seated_m"] == 0.0)
	check("the feet stay 0.6 m down", row["support_min_before_m"] == -0.6 and row["support_min_after_m"] == -0.6)
	check("no contact is found or pinned", row["contacts"] == 0 and row["contacts_pinned"] == 0 and not row["untwisted"])
	check("the Head's lowest is 0.15 and the Hips' highest -0.1", row["head_min_y_m"] == 0.15 and row["hips_max_y_m"] == -0.1)
	check("the medium is reported", row["water"] == "surface" and "body_max_y_m" not in row)
	stamp = read_glb(out)[0]["asset"]["extras"][ground.STAMP]
	check("the stamp names the medium, for the bake", stamp["water"] == "surface" and stamp["max_lift_m"] == 0.0)
	check("the source BIN survives as a prefix", read_glb(out)[1].startswith(read_glb(source)[1]))


def test_a_submerged_clip_reports_its_highest_point() -> None:
	"""Hips at -0.9: the head vertex is the highest point, at 0.8 - 0.5 - 0.9 = -0.6."""
	_out, row = ground.ground_clip(_swimmer(-0.9), stands=False, water="submerged")
	check("the body's highest point is -0.6", row["body_max_y_m"] == -0.6)
	check("and the Head joint's lowest -0.65", row["head_min_y_m"] == -0.65)


def test_a_chained_tail_may_break_the_surface_in_a_dive() -> None:
	"""The same vertex 2.0 m up, on a joint named tail_00: the spring's, so not counted -- the bake checks it."""
	_out, row = ground.ground_clip(_swimmer(-0.9, extra=(((0.0, 2.0, 0.0), "Spine"),), rename={"Spine": "tail_00"}),
		stands=False, water="submerged")
	check("the tail vertex is left to the bake", row["body_max_y_m"] == -0.6)


def test_a_water_clip_that_travels_has_its_travel_taken_out() -> None:
	"""A swimmer drifting 0.3 m forward over the loop plays in place, its travel recorded, as a carry walk's is."""
	path = [(0.0, 0.3 * k / 8) for k in range(9)]
	out, row = ground.ground_clip(_swimmer(-0.1, n=9, hips=path), stands=False, water="surface")
	check("the travel is 0.3 m", row["root_travel_m"] == 0.3)
	doc = read_glb(out)[0]
	hips = next(n for n in doc["nodes"] if n.get("name") == "Hips")
	check("recorded on the Hips as root motion", hips["extras"]["root_motion"]["travel_m"] == [0.0, 0.3])
	check("and the loop closes", row["loop_gap_m"] <= ground.ROOT_MOTION_MIN_M)


def test_a_water_clip_that_moves_is_refused() -> None:
	"""The rewrite of an in-place water clip must leave every key where it was; a lift slipped in is caught."""
	def lifting(real):
		return lambda doc, binary, times_index, times, lifts, roots=None: real(doc, binary, times_index, times, [0.01] * len(lifts), roots)
	_patched("apply_lift", lifting, lambda: _refuses_with("an in-place water clip that moves refuses", "water clip moved",
		lambda: ground.ground_clip(_swimmer(-0.1), stands=False, water="surface")))


def test_the_water_clips_are_named() -> None:
	"""swim and tread-water at the surface, the dive submerged; none stands; a walk is not a water clip."""
	check("swim is a surface clip", ground.water_medium("/lib/otter_fisher/tailed/anim_swim.glb") == "surface")
	check("tread-water is a surface clip", ground.water_medium("/lib/otter_fisher/tailed/anim_tread_water.glb") == "surface")
	check("the dive is submerged", ground.water_medium("/lib/otter_fisher/tailed/anim_dive.glb") == "submerged")
	check("a walk is not in water", ground.water_medium("/lib/otter_fisher/tailed/anim_walk.glb") is None)
	check("no water clip stands", not any(ground.stands(f"/lib/k/tailed/{c}.glb") for c in ground.WATER_CLIPS))


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
