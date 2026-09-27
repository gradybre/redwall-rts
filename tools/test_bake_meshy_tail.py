#!/usr/bin/env python3
"""Self-test for tools/bake_meshy_tail.py (decision 0192). Godot is not run here.

The Godot half of the bake is the engine's own SpringBoneSimulator3D; what this tool owns, and
what is tested, is everything either side of it: which timeline the keys go on, how they are
written, and the independent ground check that skins the tail itself.

NEGATIVE TESTS COME FIRST:

  N01  a file already baked refuses, so a tail is never keyed twice.
  N02  a clip that already animates a tail joint refuses.
  N03  keys recorded at times other than the clip's own refuse: Godot re-optimizes imported
       clips, and a bake stepped on Godot's times would be written onto the wrong frames.
  N04  a recording with one frame too few refuses.
  N05  a recorded rotation that is not a unit quaternion refuses.
  N06  a clip with no LINEAR rotation channel has no timeline, and refuses.
  N07  a clip with no vertex weighted to a tail joint refuses the ground check.
  (A tail joint turning more than MAX_STEP_DEG in one frame is not refused but REPORTED, like the
  ground: the file is written, the manifest row says motion_ok false, and the run exits 1.
  max_step_degrees is what measures it, and is tested below.)

THE FIXTURE REPRODUCES MESHY'S CLIP SHAPE: the FIRST rotation channel is a constant one
compressed to 2 keys on a timeline of its own, and the clip's real 5-key timeline comes second.
The hips drop 0.6 m on key 2, so every expected ground value is a literal.
"""

from __future__ import annotations

import json
import math
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bake_meshy_tail as bake  # noqa: E402
import rig_meshy_tail as tail  # noqa: E402
import test_rig_meshy_tail as rig_fixture  # noqa: E402
from repair_meshy_rig import read_glb, write_glb  # noqa: E402

CASES: list[str] = []
FAILURES: list[str] = []
TIMES = [0.0, 1 / 30, 2 / 30, 3 / 30, 4 / 30]
HIPS_Y = [0.5, 0.5, -0.1, 0.5, 0.5]            # a 0.6 m drop on key 2
SIN45 = math.sqrt(0.5)


def check(name: str, condition: bool) -> None:
	"""Record one named check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _refuses(name: str, action) -> None:
	"""Check that `action` raises the tool's refusal, and nothing else."""
	try:
		action()
	except bake.RepairRefused:
		check(name, True)
		return
	check(name + " (did not refuse)", False)


def _near(a: float, b: float, tolerance: float = 1e-6) -> bool:
	"""Float equality to a stated tolerance."""
	return abs(a - b) <= tolerance


def _chained(with_chain: bool = True) -> bytes:
	"""The rig test's fixture with its leg renamed LeftFoot, so the ground check has feet; chained."""
	doc, binary = read_glb(rig_fixture._glb())
	doc["nodes"][1]["name"] = "LeftFoot"
	data = write_glb(doc, binary)
	if not with_chain:
		return data
	plan, sha = rig_fixture._plan(data)
	return tail.rig_file(data, plan, sha)[0]


def _clip(data: bytes, tail_channel: bool = False, hips_y: list | None = None, foot_y: list | None = None) -> bytes:
	"""Add a Meshy-shaped clip: a 2-key constant rotation FIRST, then the 5-key timeline.

	`hips_y` overrides the hips' drop; `foot_y` adds a translation channel lowering LeftFoot."""
	doc, binary = read_glb(data)
	nodes = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
	binary, short_t = tail.append_accessor(doc, binary, [(0.0,), (TIMES[-1],)], 5126, "SCALAR")
	binary, short_r = tail.append_accessor(doc, binary, [(0.0, 0.0, 0.0, 1.0)] * 2, 5126, "VEC4")
	binary, full_t = tail.append_accessor(doc, binary, [(t,) for t in TIMES], 5126, "SCALAR")
	binary, hips_r = tail.append_accessor(doc, binary, [tuple(rig_fixture.HIPS_ROTATION)] * 5, 5126, "VEC4")
	binary, hips_t = tail.append_accessor(doc, binary, [(0.0, y, 0.0) for y in (hips_y or HIPS_Y)], 5126, "VEC3")
	samplers = [{"input": short_t, "output": short_r}, {"input": full_t, "output": hips_r},
		{"input": full_t, "output": hips_t}]
	channels = [{"sampler": 0, "target": {"node": nodes["LeftFoot"], "path": "rotation"}},
		{"sampler": 1, "target": {"node": nodes["Hips"], "path": "rotation"}},
		{"sampler": 2, "target": {"node": nodes["Hips"], "path": "translation"}}]
	if tail_channel:
		channels.append({"sampler": 1, "target": {"node": nodes["tail_03"], "path": "rotation"}})
	if foot_y:
		binary, foot_t = tail.append_accessor(doc, binary, [(0.1, y, 0.0) for y in foot_y], 5126, "VEC3")
		samplers.append({"input": full_t, "output": foot_t})
		channels.append({"sampler": len(samplers) - 1, "target": {"node": nodes["LeftFoot"], "path": "translation"}})
	doc["animations"] = [{"name": "clip", "samplers": samplers, "channels": channels}]
	return write_glb(doc, binary)


def _recording(frames: int = 5, norm: float = 1.0) -> dict:
	"""What the Godot half returns: the clip's times and one quaternion per tail joint per frame."""
	return {"times": TIMES[:frames], "rotations": [[[0.0, 0.0, 0.0, norm]] * 8 for _ in range(frames)]}


# --- negative tests ---------------------------------------------------------------------

def test_n01_a_baked_file_refuses() -> None:
	"""Baking an output again would key the tail twice."""
	once = bake.write_keys(_clip(_chained()), _recording())
	_refuses("N01 an already-baked file refuses", lambda: bake.write_keys(once, _recording()))
	## The stamp alone must refuse too: a baked file whose tail channels were stripped by a later
	## tool is still an output, and re-baking it would bake over the bake.
	doc, binary = read_glb(_clip(_chained()))
	doc["asset"].setdefault("extras", {})[bake.STAMP] = {"version": 1}
	stamped = write_glb(doc, binary)
	_refuses("N01 the bake stamp alone refuses", lambda: bake.write_keys(stamped, _recording()))


def test_n02_a_clip_animating_the_tail_refuses() -> None:
	"""The bake owns the tail's channels; it does not overwrite someone else's."""
	_refuses("N02 a clip with a tail channel refuses", lambda: bake.write_keys(_clip(_chained(), True), _recording()))


def test_n03_keys_off_the_clips_own_times_refuse() -> None:
	"""A recording shifted by 10 ms is on Godot's times, not the file's."""
	shifted = _recording()
	shifted["times"] = [t + 0.01 for t in TIMES]
	_refuses("N03 shifted key times refuse", lambda: bake.write_keys(_clip(_chained()), shifted))


def test_n04_a_short_recording_refuses() -> None:
	"""One frame short of the clip's keys."""
	short = _recording()
	short["rotations"] = short["rotations"][:4]
	_refuses("N04 a recording one frame short refuses", lambda: bake.write_keys(_clip(_chained()), short))


def test_n05_a_non_unit_rotation_refuses() -> None:
	"""A norm of 1.5 is not a rotation, and is not silently normalised."""
	_refuses("N05 a non-unit quaternion refuses", lambda: bake.write_keys(_clip(_chained()), _recording(norm=1.5)))


def test_n06_no_linear_rotation_means_no_timeline() -> None:
	"""With every rotation STEP, there is no timeline to write on."""
	doc, _binary = read_glb(_clip(_chained()))
	for sampler in doc["animations"][0]["samplers"]:
		sampler["interpolation"] = "STEP"
	_refuses("N06 no LINEAR rotation refuses", lambda: bake.rotation_time_accessor(doc))


def test_n07_no_tail_weights_refuses_the_ground_check() -> None:
	"""An unchained file has nothing to check, and says so."""
	_refuses("N07 an unchained clip refuses the ground check",
		lambda: bake.ground_report(_clip(_chained(with_chain=False))))


def test_one_frame_turns_are_measured() -> None:
	"""A 180 deg flip on key 2 (the glitch the zero-time wrap produced) and a 90 deg turn."""
	flip = _recording()
	flip["rotations"][2] = [[0.0, 1.0, 0.0, 0.0]] * 8
	check("a 180 deg one-frame flip is over the limit", bake.max_step_degrees(flip) > bake.MAX_STEP_DEG)
	check("the limit is 90 deg", bake.MAX_STEP_DEG == 90.0)
	turn = _recording()
	turn["rotations"][2] = [[0.0, SIN45, 0.0, SIN45]] * 8
	check("a 90 deg turn is measured as 90", _near(bake.max_step_degrees(turn), 90.0, 1e-4))
	check("a still recording has no step", _near(bake.max_step_degrees(_recording()), 0.0, 1e-4))


# --- positive tests ---------------------------------------------------------------------

def test_the_timeline_is_the_longest_linear_rotation_not_the_first() -> None:
	"""Meshy's first rotation channel is a 2-key constant; the 5-key one is the clip."""
	doc, _binary = read_glb(_clip(_chained()))
	chosen = bake.rotation_time_accessor(doc)
	check("the timeline has 5 keys", doc["accessors"][chosen]["count"] == 5)
	check("the first rotation's 2-key input is not chosen",
		chosen != doc["animations"][0]["samplers"][0]["input"])


def test_eight_channels_on_the_clips_timeline() -> None:
	"""One rotation channel per tail joint, in chain order, on the timeline accessor, read back exactly."""
	source = _clip(_chained())
	recording = _recording()
	recording["rotations"][2] = [[0.0, SIN45, 0.0, SIN45]] * 8
	out = bake.write_keys(source, recording)
	doc, binary = read_glb(out)
	anim = doc["animations"][0]
	added = anim["channels"][3:]
	names = [doc["nodes"][c["target"]["node"]]["name"] for c in added]
	check("eight channels added", len(added) == 8)
	check("in chain order", names == [f"tail_{i:02d}" for i in range(8)])
	timeline = bake.rotation_time_accessor(read_glb(source)[0])
	check("all on the clip's timeline", all(anim["samplers"][c["sampler"]]["input"] == timeline for c in added))
	keys = tail.read_accessor(doc, binary, anim["samplers"][added[5]["sampler"]]["output"])
	check("tail_05 key 2 reads back as recorded", all(_near(a, b) for a, b in zip(keys[2], (0.0, SIN45, 0.0, SIN45))))
	check("tail_05 key 0 reads back as identity", all(_near(a, b) for a, b in zip(keys[0], (0.0, 0.0, 0.0, 1.0))))
	check("source BIN survives as a prefix", binary.startswith(read_glb(source)[1]))
	stamp = doc["asset"]["extras"][bake.STAMP]
	check("stamped with frames and source hash",
		stamp["frames"] == 5 and stamp["source_sha256"] == __import__("hashlib").sha256(source).hexdigest())


def test_sampling_holds_blends_and_clamps() -> None:
	"""STEP holds, LINEAR blends, ends clamp, and a rotation takes the short way round."""
	keys, outs = [0.0, 1.0], [(0.0,), (10.0,)]
	check("LINEAR midpoint", bake._sample(keys, outs, 0.5, False, False) == [5.0])
	check("STEP holds the previous key", bake._sample(keys, outs, 0.9, True, False) == [0.0])
	check("clamped before the first key", bake._sample(keys, outs, -1.0, False, False) == [0.0])
	check("clamped after the last key", bake._sample(keys, outs, 2.0, False, False) == [10.0])
	flipped = [(0.0, 0.0, 0.0, 1.0), (0.0, -SIN45, 0.0, -SIN45)]      # 90 deg about Y, stored negated
	half = bake._sample(keys, flipped, 0.5, False, True)
	check("rotation blends the short way to 45 deg",
		all(_near(a, b) for a, b in zip(half, (0.0, 0.3826834, 0.0, 0.9238795))))


def test_the_loop_seam_is_measured_in_degrees() -> None:
	"""Identity on the first frame, 90 deg about Y on the last: a 90 deg seam."""
	recording = _recording()
	recording["rotations"][-1] = [[0.0, SIN45, 0.0, SIN45]] * 8
	check("seam of 90 degrees", _near(bake.seam_degrees(recording), 90.0, 1e-4))
	check("a still clip has no seam", _near(bake.seam_degrees(_recording()), 0.0, 1e-4))


def test_the_ground_check_skins_the_tail_itself() -> None:
	"""The hips drop 0.6 m on key 2: tail vertices at y 0.5 reach -0.1; the foot's at 0.548 reach -0.052;
	the tail base, at y 0.5 on the hips' axis, reaches -0.1."""
	report = bake.ground_report(_clip(_chained()))
	check("tail low is -0.1", report["tail_min_y_m"] == -0.1)
	check("feet low is -0.052", report["feet_min_y_m"] == -0.052)
	check("the worst key is key 2", report["worst_time_s"] == round(2 / 30, 4))
	root = next(n for n in read_glb(_clip(_chained()))[0]["nodes"] if n.get("name") == "tail_00")
	check("the base floor is tail_00 at -0.1 less its radius",
		report["root_floor_y_m"] == round(-0.1 - root["extras"]["spring_radius_m"], 4))
	check("all five keys checked", report["keys"] == 5)


def test_the_springs_floor_follows_the_clip() -> None:
	"""Per key: min(0, tail base less its radius). Sunk FEET do not lower it (decision 0192)."""
	import tempfile
	root = next(n for n in read_glb(_chained())[0]["nodes"] if n.get("name") == "tail_00")
	r0 = root["extras"]["spring_radius_m"]
	with tempfile.TemporaryDirectory() as tmp:
		path = pathlib.Path(tmp) / "clip.glb"
		path.write_bytes(_clip(_chained()))
		floors = bake.clip_floor(path)
		check("the hips' drop buries the base: key 2 is the base's floor",
			floors == [0.0, 0.0, round(-0.1 - r0, 5), 0.0, 0.0])
		path.write_bytes(_clip(_chained(), hips_y=[0.5] * 5, foot_y=[-0.05, -0.05, -0.75, -0.05, -0.05]))
		check("a foot sunk 0.7 m on key 2 does not lower the spring's floor",
			bake.clip_floor(path) == [0.0] * 5)


def _chain_after(data: bytes, rotations: list, k: int) -> list:
	"""World points of the chain (and tip) at key k with `rotations` on the tail joints."""
	doc, binary = read_glb(data)
	tail, _base = bake._chain(doc)
	_times, animated = bake._channels(doc, binary)
	animated = {**animated, **{node: {"rotation": [f[j] for f in rotations]} for j, node in enumerate(tail)}}
	return bake._chain_points(doc, bake._worlds_at(doc, animated, k), tail)


def test_the_ground_constraint_lifts_a_tail_to_its_clearance() -> None:
	"""Hips at 0.02 m on key 2: the level tail is closer to the ground than its thickness, and is lifted."""
	data = _clip(_chained(), hips_y=[0.5, 0.5, 0.02, 0.5, 0.5])
	doc, binary = read_glb(data)
	clear = bake.tail_clearances(doc, binary)
	still = [[[0.0, 0.0, 0.0, 1.0]] * 8 for _ in range(5)]
	out = bake.lift_tail(doc, binary, still, [0.0] * 5, clear)
	check("frames above their clearance come back unchanged", all(out[k] == still[k] for k in (0, 1, 3, 4)))
	before, after = _chain_after(data, still, 2), _chain_after(data, out, 2)
	need = [0.0] + [max(clear[i - 1], clear[min(i, 7)]) for i in range(1, 9)]
	check("key 2 was below its clearance", any(before[i][1] < need[i] for i in range(1, 9)))
	check("key 2: every joint and the tip at or above its clearance", all(after[i][1] >= need[i] - 1e-9 for i in range(1, 9)))
	check("the base does not move", all(_near(a, b, 1e-12) for a, b in zip(before[0], after[0])))
	check("every segment keeps its length", all(_near(math.dist(before[i], before[i + 1]), math.dist(after[i], after[i + 1]), 1e-9) for i in range(8)))
	lowered = bake.lift_tail(doc, binary, still, [0.0, 0.0, -0.5, 0.0, 0.0], clear)
	check("a floor lowered under the tail lifts nothing", lowered == [[bake._normal(q) for q in f] for f in still])
	## 0.04 m: reachable from a base held at 0.02 m (a floor beyond reach is the buried-base case).
	raised = bake.lift_tail(doc, binary, still, [0.0, 0.0, 0.04, 0.0, 0.0], clear)
	check("a floor raised to 0.04 m lifts every joint above 0.04 m plus its clearance",
		all(p[1] >= 0.04 + need[i] - 1e-9 for i, p in enumerate(_chain_after(data, raised, 2)) if i))
	def heading(points: list) -> float:
		return math.degrees(math.atan2(points[8][0] - points[0][0], points[8][2] - points[0][2]))
	check("the lifted tail keeps its heading (the hips' 30 deg yaw is respected)", abs(heading(after) - heading(before)) < 5.0)
	turned = [[[0.0, math.sin(math.radians(2.5)), 0.0, math.cos(math.radians(2.5))]] * 8 for _ in range(5)]
	kept = bake.lift_tail(doc, binary, turned, [-0.5] * 5, clear)
	check("a frame needing no lift is passed through exactly, not recomputed", kept == [[bake._normal(q) for q in f] for f in turned])


def test_clearances_measure_the_tails_thickness() -> None:
	"""The strip is 1 cm wide; one segment also holds the fringe vertex 3.6 cm above the strip."""
	doc, binary = read_glb(_chained())
	clear = bake.tail_clearances(doc, binary)
	check("eight clearances", len(clear) == 8)
	check("plain strip segments clear exactly half its width", round(clear[1], 4) == 0.005 and round(clear[2], 4) == 0.005)
	check("exactly one segment holds the fringe, and clears more than 3.5 cm", sum(1 for c in clear if c > 0.035) == 1)
	check("the root segment's vertices blend into the hips, so it has none of its own", clear[0] == 0.0)


def test_the_verdict_measures_the_tail_against_what_the_spring_controls() -> None:
	"""A tail may not go below the ground -- or the feet, or its base's floor, where the clip sinks those."""
	tolerance = bake.GROUND_TOLERANCE_M
	check("above the ground passes", bake.ground_verdict(0.01, 0.0, 0.05)["ground_ok"])
	check("within tolerance passes", bake.ground_verdict(-tolerance, 0.0, 0.05)["ground_ok"])
	check("below the ground, feet and base on it, fails", not bake.ground_verdict(-tolerance - 0.001, 0.0, 0.05)["ground_ok"])
	check("the clip sinks the feet: tail no lower passes", bake.ground_verdict(-0.138, -0.175, 0.05)["ground_ok"])
	check("the clip sinks the feet: tail lower fails", not bake.ground_verdict(-0.2, -0.175, 0.05)["ground_ok"])
	check("the clip buries the base: tail no lower passes", bake.ground_verdict(-0.13, -0.066, -0.134)["ground_ok"])
	check("the clip buries the base: tail lower fails", not bake.ground_verdict(-0.2, -0.066, -0.134)["ground_ok"])
	check("sunk feet are reported as the clip's", bake.ground_verdict(-0.138, -0.175, 0.05)["clip_below_ground"])
	check("a buried base is reported as the clip's", bake.ground_verdict(0.01, 0.0, -0.134)["clip_below_ground"])
	check("a grounded clip is not", not bake.ground_verdict(0.01, 0.0, 0.05)["clip_below_ground"])
	check("feet and base ABOVE the ground do not raise the bar", bake.ground_verdict(-0.004, 0.03, 0.05)["ground_ok"])


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
	print("test_bake_meshy_tail: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
