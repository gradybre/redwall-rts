#!/usr/bin/env python3
"""Self-test for tools/author_water_clips.py (decision 0203).

NEGATIVE TESTS COME FIRST:

  N01  a skeleton missing one of the posed joints refuses: the clips pose Meshy's 24-joint humanoid by name.
  N02  a rig that already has a tail chain refuses: authoring starts from the raw rigged.glb.
  N03  an authored clip refuses to be authored again.
  N04  a species with no water clips authored refuses, naming it.
  N05  two scene roots refuse.

THE FIXTURE is Meshy-shaped: an Armature at scale 0.01 with every translation in centimetres, and bones that
run along their local +Y. The shoulders carry Meshy's rest turn (the left one -90 deg about Z, so its arm runs
along world +X; the right one +90 deg), so a pose that ignored the parent's rest basis would bend the wrong way.
Expected values are literals.
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import author_water_clips as author  # noqa: E402
import bake_meshy_tail as bake  # noqa: E402
from repair_meshy_rig import append_accessor, read_accessor, read_glb, write_glb  # noqa: E402

CASES: list[str] = []
FAILURES: list[str] = []
HALF = math.sqrt(0.5)
## (name, parent, translation in cm, rest rotation)
BONES = [("Hips", "Armature", [0, 50, 0], None), ("Spine02", "Hips", [0, 10, 0], None), ("Spine01", "Spine02", [0, 10, 0], None),
	("Spine", "Spine01", [0, 10, 0], None), ("neck", "Spine", [0, 10, 0], None), ("Head", "neck", [0, 5, 0], None),
	("head_end", "Head", [0, 10, 0], None),
	("LeftShoulder", "Spine", [5, 5, 0], [0.0, 0.0, -HALF, HALF]), ("LeftArm", "LeftShoulder", [0, 10, 0], None),
	("LeftForeArm", "LeftArm", [0, 20, 0], None), ("LeftHand", "LeftForeArm", [0, 20, 0], None),
	("RightShoulder", "Spine", [-5, 5, 0], [0.0, 0.0, HALF, HALF]), ("RightArm", "RightShoulder", [0, 10, 0], None),
	("RightForeArm", "RightArm", [0, 20, 0], None), ("RightHand", "RightForeArm", [0, 20, 0], None),
	("LeftUpLeg", "Hips", [10, 0, 0], None), ("LeftLeg", "LeftUpLeg", [0, -22, 0], None), ("LeftFoot", "LeftLeg", [0, -22, 0], None),
	("LeftToeBase", "LeftFoot", [0, -5, 5], None), ("RightUpLeg", "Hips", [-10, 0, 0], None), ("RightLeg", "RightUpLeg", [0, -22, 0], None),
	("RightFoot", "RightLeg", [0, -22, 0], None), ("RightToeBase", "RightFoot", [0, -5, 5], None)]


def check(name: str, condition: bool) -> None:
	"""Record one named check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _refuses(name: str, text: str, action) -> None:
	"""Check that `action` raises the tool's refusal, with `text` in its reason."""
	try:
		action()
	except author.RepairRefused as refused:
		check(name, text in str(refused))
		return
	check(name + " (did not refuse)", False)


def _rig(drop: str = "", tail: bool = False, roots: int = 1, height: float = 1.0) -> bytes:
	"""The fixture rig: the skeleton, a `height` (1.0 m) tall three-vertex mesh, and Meshy's own one-key clip0."""
	nodes = [{"name": "Armature", "scale": [0.01, 0.01, 0.01], "children": []}]
	index = {"Armature": 0}
	for name, parent, t, r in BONES:
		index[name] = len(nodes)
		nodes.append({"name": name + ("_gone" if name == drop else ""), "translation": [float(v) for v in t],
			**({"rotation": r} if r else {})})
		nodes[index[parent]].setdefault("children", []).append(index[name])
	if tail:
		nodes.append({"name": "tail_00", "translation": [0.0, 0.0, -10.0]})
		nodes[index["Hips"]]["children"].append(len(nodes) - 1)
	nodes.append({"name": "char1", "mesh": 0})
	nodes[0]["children"].append(len(nodes) - 1)
	doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0] + ([index["Hips"]] if roots == 2 else [])}],
		"nodes": nodes, "meshes": [{"primitives": [{"attributes": {"POSITION": 0}}]}], "accessors": [], "bufferViews": [],
		"buffers": [{"byteLength": 0}]}
	binary, _ = append_accessor(doc, b"", [(0.0, 0.0, 0.0), (0.1, height, 0.0), (-0.1, 0.5, 0.1)], 5126, "VEC3")
	doc["accessors"][0]["min"], doc["accessors"][0]["max"] = [-0.1, 0.0, 0.0], [0.1, height, 0.1]
	binary, t_in = append_accessor(doc, binary, [(0.0,)], 5126, "SCALAR")
	binary, r_out = append_accessor(doc, binary, [(0.0, 0.0, 0.0, 1.0)], 5126, "VEC4")
	doc["animations"] = [{"name": "Armature|clip0|baselayer", "samplers": [{"input": t_in, "output": r_out}],
		"channels": [{"sampler": 0, "target": {"node": index["Hips"], "path": "rotation"}}]}]
	doc["buffers"][0]["byteLength"] = len(binary)
	return write_glb(doc, binary)


def _worlds(data: bytes) -> tuple[list[float], list[dict], dict]:
	"""The output clip's times, every node's world matrix per key, and the node indices by name."""
	doc, binary = read_glb(data)
	times, animated = bake._channels(doc, binary)
	names = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
	return times, [bake._worlds_at(doc, animated, k) for k in range(len(times))], names


def _offset(worlds: dict, names: dict, a: str, b: str) -> list[float]:
	"""World position of b less that of a, rounded to 0.1 mm."""
	return [round(worlds[names[b]][12 + i] - worlds[names[a]][12 + i], 4) + 0.0 for i in range(3)]


TREAD = ("anim_tread_water", "tread", 1.6, {"pitch": 10.0, "neck_y": 0.02})


# --- negative tests ---------------------------------------------------------------------------------

def test_n01_a_skeleton_missing_a_joint_refuses() -> None:
	"""LeftForeArm renamed: the arm cannot be posed."""
	_refuses("N01 a missing joint refuses", "LeftForeArm", lambda: author.author(_rig(drop="LeftForeArm"), *TREAD))


def test_n02_a_tailed_rig_refuses() -> None:
	"""A rig with tail_00 is an output of rig_meshy_tail, not Meshy's rigged.glb."""
	_refuses("N02 a tailed rig refuses", "tail chain", lambda: author.author(_rig(tail=True), *TREAD))


def test_n03_an_authored_clip_refuses() -> None:
	"""Authoring an output again."""
	once, _ = author.author(_rig(), *TREAD)
	_refuses("N03 an authored clip refuses", "already an authored clip", lambda: author.author(once, *TREAD))


def test_n04_an_unknown_species_refuses() -> None:
	"""A stoat has no swim authored."""
	_refuses("N04 an unknown species refuses, naming it", "species 'stoat'", lambda: author.species_clips("stoat_scout"))


def test_n05_two_scene_roots_refuse() -> None:
	"""A second root would be left out of the pose."""
	_refuses("N05 two scene roots refuse", "one scene root", lambda: author.author(_rig(roots=2), *TREAD))


# --- positive tests ---------------------------------------------------------------------------------

def test_rotations_turn_the_way_their_names_say() -> None:
	"""rot_x(90) takes up to front; rot_y(90) front to the left (+X); rot_z(90) left to up."""
	from ground_meshy_clips import _apply
	def near(v: list, w: list) -> bool:
		return all(abs(a - b) < 1e-12 for a, b in zip(v, w))
	check("rot_x(90): +Y to +Z", near(_apply(author.rot_x(90.0), [0, 1, 0]), [0, 0, 1]))
	check("rot_y(90): +Z to +X", near(_apply(author.rot_y(90.0), [0, 0, 1]), [1, 0, 0]))
	check("rot_z(90): +X to +Y", near(_apply(author.rot_z(90.0), [1, 0, 0]), [0, 1, 0]))
	check("chain(a, b) applies b first: z then x takes +X to +Z",
		near(_apply(author.chain(author.rot_x(90.0), author.rot_z(90.0)), [1, 0, 0]), [0, 0, 1]))
	check("the right side mirrors a Z turn", near(_apply(author.mirrored("Right", z=90.0), [-1, 0, 0]), [0, 1, 0]))
	check("the right side keeps an X turn", near(_apply(author.mirrored("Right", x=90.0), [0, 1, 0]), [0, 0, 1]))


def test_the_identity_pose_is_the_rest_exactly() -> None:
	"""A style that poses nothing, anchored where the rest neck is (0.9 m): every key is the rest pose."""
	author.STYLES["rest"] = (lambda phase, p: {"pose": {}, "anchor": 0.9}, author.SURFACE, "neck")
	try:
		out, _ = author.author(_rig(), "anim_swim", "rest", 0.1, {})
	finally:
		del author.STYLES["rest"]
	doc, binary = read_glb(out)
	rest = {n["name"]: n.get("rotation", [0.0, 0.0, 0.0, 1.0]) for n in doc["nodes"] if "name" in n}
	anim = doc["animations"][0]
	worst = 0.0
	for c in anim["channels"]:
		rows = read_accessor(doc, binary, anim["samplers"][c["sampler"]]["output"])
		node = doc["nodes"][c["target"]["node"]]
		expected = rest[node["name"]] if c["target"]["path"] == "rotation" else node["translation"]
		worst = max(worst, max(abs(abs(sum(a * b for a, b in zip(row, expected))) - (1.0 if len(row) == 4 else 0.0))
			if len(row) == 4 else max(abs(a - b) for a, b in zip(row, expected)) for row in rows))
	check("every key is the rest to 1e-6", worst < 1e-6)


def test_an_arm_is_lowered_in_character_axes_on_both_sides() -> None:
	"""The shoulders' rest turns are -90 and +90 deg about Z; lowering each arm 90 deg puts both forearms 0.2 m
	straight DOWN from the elbow's parent, whatever those rest turns were."""
	author.STYLES["arms"] = (lambda phase, p: {"pose": {**author._arm("Left", 90.0, 0.0, 0.0), **author._arm("Right", 90.0, 0.0, 0.0)},
		"anchor": 0.9}, author.SURFACE, "neck")
	try:
		out, _ = author.author(_rig(), "anim_swim", "arms", 0.1, {})
	finally:
		del author.STYLES["arms"]
	_times, worlds, names = _worlds(out)
	check("the left forearm hangs 0.2 m below the upper arm", _offset(worlds[0], names, "LeftArm", "LeftForeArm") == [0.0, -0.2, 0.0])
	check("the right forearm hangs 0.2 m below it too", _offset(worlds[0], names, "RightArm", "RightForeArm") == [0.0, -0.2, 0.0])


def test_an_elbow_bends_forward_and_a_thigh_lifts_forward() -> None:
	"""Arm lowered 90, elbow bent 90: the hand is 0.2 m in FRONT (+Z) of the elbow. A thigh raised 90: the knee is
	0.22 m in front of the hip."""
	author.STYLES["bend"] = (lambda phase, p: {"pose": {**author._arm("Left", 90.0, 0.0, 90.0), **author._leg("Left", 90.0, 0.0, 0.0)},
		"anchor": 0.9}, author.SURFACE, "neck")
	try:
		out, _ = author.author(_rig(), "anim_swim", "bend", 0.1, {})
	finally:
		del author.STYLES["bend"]
	_times, worlds, names = _worlds(out)
	check("the hand is 0.2 m in front of the elbow", _offset(worlds[0], names, "LeftForeArm", "LeftHand") == [0.0, 0.0, 0.2])
	check("the knee is 0.22 m in front of the hip", _offset(worlds[0], names, "LeftUpLeg", "LeftLeg") == [0.0, 0.0, 0.22])


def test_the_anchor_is_held_at_its_share_of_the_height() -> None:
	"""Tread-water on a 1.0 m rig: the neck at 0.02 m on key 0 and, at phase 1/8 (key 6 of 48), 0.02 + 0.012."""
	out, report = author.author(_rig(), *TREAD)
	_times, worlds, names = _worlds(out)
	check("key 0: the neck at 0.02", abs(worlds[0][names["neck"]][13] - 0.02) < 1e-6)
	check("key 6: the neck at 0.032", abs(worlds[6][names["neck"]][13] - 0.032) < 1e-6)
	check("the report gives the anchor's range", report["anchor"] == "neck" and report["anchor_y_m"] == [0.008, 0.032])


def test_the_anchor_scales_with_the_creatures_height() -> None:
	"""The same tread-water on a 2.0 m creature: the neck at 0.04 m on key 0 and 0.064 at phase 1/8."""
	out, _ = author.author(_rig(height=2.0), *TREAD)
	_times, worlds, names = _worlds(out)
	check("key 0: the neck at 0.04", abs(worlds[0][names["neck"]][13] - 0.04) < 1e-6)
	check("key 6: the neck at 0.064", abs(worlds[6][names["neck"]][13] - 0.064) < 1e-6)


def test_the_clip_loops_in_place_at_30_hz() -> None:
	"""1.6 s is 49 keys from 1/30 to 49/30 s; the last pose is the first; the hips keep their rest x and z."""
	out, report = author.author(_rig(), *TREAD)
	times, worlds, names = _worlds(out)
	check("49 keys", len(times) == 49 and report["keys"] == 49)
	check("from 1/30 s to 49/30 s", abs(times[0] - 1 / 30) < 1e-7 and abs(times[-1] - 49 / 30) < 1e-6)
	check("the last key's pose is the first's", all(abs(a - b) < 1e-6 for n in worlds[0] for a, b in zip(worlds[0][n], worlds[-1][n])))
	check("the hips stay over x 0, z 0", all(abs(w[names["Hips"]][12]) < 1e-9 and abs(w[names["Hips"]][14]) < 1e-9 for w in worlds))


def test_the_file_is_meshys_with_one_new_animation() -> None:
	"""The source BIN is a prefix; one animation, 22 rotation channels and the Hips translation; stamped."""
	source = _rig()
	out, _ = author.author(source, *TREAD)
	doc, binary = read_glb(out)
	check("the source BIN survives as a prefix", binary.startswith(read_glb(source)[1]))
	anim = doc["animations"]
	check("one animation, Meshy's clip0 replaced", len(anim) == 1 and anim[0]["name"] == "Armature|tread_water|redwall_authored")
	paths = sorted(c["target"]["path"] for c in anim[0]["channels"])
	check("22 rotations and one translation", paths.count("rotation") == 22 and paths.count("translation") == 1)
	hips = next(n for n in doc["nodes"] if n.get("name") == "Hips")
	check("the Hips say where the water is", hips["extras"]["water"] == {"medium": "surface", "waterline_y_m": 0.0, "period_s": 1.6, "decision": "0203"})
	stamp = doc["asset"]["extras"][author.STAMP]
	check("the stamp records the style and its parameters", stamp["style"] == "tread" and stamp["params"] == TREAD[3])


def test_every_species_gets_a_swim_and_a_tread_and_only_the_otter_dives() -> None:
	"""Six species; each has swim and tread-water; the dive is the otter's alone and submerged."""
	check("six species", sorted(author.SPECIES_CLIPS) == ["badger", "beaver", "mole", "mouse", "otter", "squirrel"])
	check("each swims and treads water", all({"anim_swim", "anim_tread_water"} <= set(c) for c in author.SPECIES_CLIPS.values()))
	check("only the otter dives", [s for s, c in author.SPECIES_CLIPS.items() if "anim_dive" in c] == ["otter"])
	check("the dive is submerged", author.STYLES[author.SPECIES_CLIPS["otter"]["anim_dive"][0]][1] == author.SUBMERGED)


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
	print("test_author_water_clips: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
