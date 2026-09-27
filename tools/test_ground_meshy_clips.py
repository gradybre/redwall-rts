#!/usr/bin/env python3
"""Self-test for tools/ground_meshy_clips.py (decision 0193).

NEGATIVE TESTS COME FIRST:

  N01  a clip already grounded refuses, so a lift is never applied twice.
  N02  a file with no animation refuses.
  N03  a skin with no foot, toe or leg joint has no support, and refuses rather than lifting
       by some other part.
  N04  a clip that animates an ancestor of Hips refuses: a Hips lift would not be a world lift.
  N05  a clip that does not animate the Hips translation refuses.

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
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import ground_meshy_clips as ground  # noqa: E402
import rig_meshy_tail as tail  # noqa: E402
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


# --- positive tests ---------------------------------------------------------------------

def test_the_lift_is_the_feets_depth_on_that_key_only() -> None:
	"""Key 2 lifted 0.052 (the foot), not 0.1 (the tail or body); every other key untouched."""
	out, row = ground.ground_clip(fixture._clip(fixture._chained()))
	ys = _hips_y(out)
	check("key 2's hips rise from -0.1 to -0.048", _near(ys[2], -0.048))
	check("the other keys are unchanged", all(_near(ys[k], 0.5) for k in (0, 1, 3, 4)))
	check("one key lifted, by 0.052", row["keys_lifted"] == 1 and row["max_lift_m"] == 0.052)
	check("support before -0.052, after 0", row["support_min_before_m"] == -0.052 and _near(row["support_min_after_m"], 0.0, 1e-4))


def test_a_clip_above_the_ground_is_never_lowered() -> None:
	"""Hips held at 0.5: the foot never goes below the ground, so nothing moves."""
	out, row = ground.ground_clip(fixture._clip(fixture._chained(), hips_y=[0.5] * 5))
	check("no key lifted", row["keys_lifted"] == 0)
	check("no hips key lowered", all(_near(y, 0.5) for y in _hips_y(out)))


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
	ground.apply_lift = lambda doc, binary, times_index, times, lifts: real(doc, binary, times_index, times, [0.0] * len(lifts))
	try:
		_refuses("a lift that leaves the foot below ground refuses", lambda: ground.ground_clip(fixture._clip(fixture._chained())))
	finally:
		ground.apply_lift = real
	ground.apply_lift = lambda doc, binary, times_index, times, lifts: real(doc, binary, times_index, times, [x + 0.01 for x in lifts])
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
