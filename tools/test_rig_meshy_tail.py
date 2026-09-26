#!/usr/bin/env python3
"""Self-test for tools/rig_meshy_tail.py (decision 0191).

NEGATIVE TESTS COME FIRST AND OUTNUMBER THE POSITIVE ONES:

  N01  an empty capsule refuses, rather than chaining nothing and calling it a tail.
  N02  a file whose POSITION data differs from rigged.glb refuses: the segmentation is
       only valid on the mesh it was computed from.
  N03  an already-chained file refuses, so a chain is never added twice.
  N04  a skin with no Hips refuses: the chain has nothing to hang from.
  N05  a chain that would leave no room for the three sockets refuses (64-bone budget).
  N06  a joint whose inverse bind disagrees with the node hierarchy is caught by
       verify_bind -- the check that keeps the chain's two halves honest.
  N07  a mesh with two primitives refuses rather than half-rigging it.
  N08  a chain with more segments than the tail has surface for refuses: an empty segment
       has no radius to measure, and a guessed one is what let fur sink through the ground.

THE FIXTURE REPRODUCES EACH REAL DEFECT FOUND ON 2026-09-26:
  * the tail is bound to a THIGH (LeftUpLeg), as Meshy bound the squirrel gatherer's;
  * the tail strip is split by a UV SEAM: its middle station is duplicated, so without
    welding the surface walk stops halfway;
  * a FRINGE vertex sits at 1.2x the capsule radius (the growth must take it) and another
    at 1.6x (the growth must not).

Expected values are literals. The written GLB is read back with `struct` where it matters.
"""

from __future__ import annotations

import json
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import rig_meshy_tail as tail  # noqa: E402
from repair_meshy_rig import read_glb, write_glb  # noqa: E402

CASES: list[str] = []
FAILURES: list[str] = []
RADIUS = 0.03
X = 0.013                         # the tail is off-centre, so no translation component is zero
CENTRELINE = [[X, 0.5, -0.02], [X, 0.5, -0.25], [X, 0.5, -0.47]]
HIPS_YAW_DEG = 30.0               # Meshy's hips are rotated; an identity basis hides transposition errors
HIPS_ROTATION = [0.0, 0.25881904510252074, 0.0, 0.9659258262890683]   # quaternion for 30 degrees about +Y
STATIONS = 11                     # tail strip stations at z = -0.05 ... -0.45
SEAM_STATION = 5


def check(name: str, condition: bool) -> None:
	"""Record one named check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _refuses(name: str, action) -> None:
	"""Check that `action` raises TailRefused (or the repair tool's refusal), and nothing else."""
	try:
		action()
	except tail.RepairRefused:
		check(name, True)
		return
	check(name + " (did not refuse)", False)


def _mesh():
	"""Positions, triangles and (joint, weight) rows. Vertex roles are returned by index."""
	pos, tris, bind = [], [], []
	for k in range(STATIONS):
		z = -0.05 - 0.04 * k
		pos += [(X - 0.005, 0.5, z), (X + 0.005, 0.5, z)]
		bind += [(1, 1.0), (1, 1.0)]                      # bound to the THIGH
	seam = len(pos)                                        # duplicate station 5: a UV seam
	pos += [pos[2 * SEAM_STATION], pos[2 * SEAM_STATION + 1]]
	bind += [(1, 1.0), (1, 1.0)]
	for k in range(STATIONS - 1):
		a, b = (seam, seam + 1) if k == SEAM_STATION else (2 * k, 2 * k + 1)
		tris += [(a, b, 2 * k + 2), (b, 2 * k + 3, 2 * k + 2)]
	near, far = len(pos), len(pos) + 1                     # fringe at 1.2r and at 1.6r
	pos += [(X, 0.5 + 1.2 * RADIUS, -0.27), (X, 0.5 + 1.6 * RADIUS, -0.31)]
	bind += [(1, 1.0), (1, 1.0)]
	tris += [(2 * 5 + 2, 2 * 5 + 3, near), (2 * 6 + 2, 2 * 6 + 3, far)]
	front = len(pos)                                       # inside the capsule, before the root
	pos += [(X, 0.5, 0.01)]
	bind += [(0, 1.0)]
	tris += [(0, 1, front)]
	body = len(pos)                                        # a separate body triangle, far away
	pos += [(-0.05, 0.5, 0.1), (0.05, 0.5, 0.1), (0.0, 0.6, 0.1)]
	bind += [(0, 1.0)] * 3
	tris += [(body, body + 1, body + 2)]
	roles = {"strip": set(range(2 * STATIONS)) | {seam, seam + 1}, "near": near, "far": far,
		"front": front, "body": {body, body + 1, body + 2}, "tip": {2 * STATIONS - 2, 2 * STATIONS - 1},
		"root": {0, 1}}
	return pos, tris, bind, roles


def _hips_world() -> list:
	"""Hips at (0, 0.5, 0), yawed HIPS_YAW_DEG about +Y. Column-major."""
	import math
	a = math.radians(HIPS_YAW_DEG)
	c, s = math.cos(a), math.sin(a)
	return [c, 0, -s, 0, 0, 1.0, 0, 0, s, 0, c, 0, 0, 0.5, 0, 1.0]


def _inverse_rigid(m: list) -> tuple:
	"""Inverse of a rotation+translation matrix: R^T and -R^T t."""
	r = [[m[0], m[4], m[8]], [m[1], m[5], m[9]], [m[2], m[6], m[10]]]
	t = [m[12], m[13], m[14]]
	rt = [[r[c][rw] for c in range(3)] for rw in range(3)]
	tt = [-sum(rt[rw][k] * t[k] for k in range(3)) for rw in range(3)]
	return (rt[0][0], rt[1][0], rt[2][0], 0, rt[0][1], rt[1][1], rt[2][1], 0,
		rt[0][2], rt[1][2], rt[2][2], 0, tt[0], tt[1], tt[2], 1.0)


def _ibms() -> bytes:
	"""Inverse binds for Hips and LeftUpLeg, computed from the same hierarchy the nodes declare."""
	hips = _hips_world()
	leg = tail.mat_mul(hips, [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0.1, -0.05, 0, 1.0])
	return struct.pack("<16f", *_inverse_rigid(hips)) + struct.pack("<16f", *_inverse_rigid(leg))


def _glb(root_scale: float = 1.0, hips_name: str = "Hips", primitives: int = 1, nudge: float = 0.0) -> bytes:
	"""A Meshy-shaped skinned GLB: Armature(root) -> Hips -> LeftUpLeg, plus the skinned mesh."""
	pos, tris, bind, _ = _mesh()
	pos = [(p[0] + nudge, p[1], p[2]) for p in pos]
	blobs = [b"".join(struct.pack("<3f", *p) for p in pos),
		b"".join(struct.pack("<3H", *t) for t in tris),
		b"".join(struct.pack("<4B", j, 0, 0, 0) for j, _w in bind),
		b"".join(struct.pack("<4f", w, 0, 0, 0) for _j, w in bind),
		_ibms()]
	binary, views = b"", []
	for blob in blobs:
		binary += b"\x00" * (-len(binary) % 4)
		views.append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(blob)})
		binary += blob
	prim = {"attributes": {"POSITION": 0, "JOINTS_0": 2, "WEIGHTS_0": 3}, "indices": 1}
	doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [3]}],
		"nodes": [{"name": hips_name, "translation": [0, 0.5, 0], "rotation": HIPS_ROTATION, "children": [1]},
			{"name": "LeftUpLeg", "translation": [0.1, -0.05, 0]},
			{"name": "char1", "mesh": 0, "skin": 0},
			{"name": "Armature", "scale": [root_scale] * 3, "children": [2, 0]}],
		"skins": [{"joints": [0, 1], "inverseBindMatrices": 4}],
		"meshes": [{"primitives": [prim] * primitives}],
		"accessors": [{"bufferView": 0, "componentType": 5126, "count": len(pos), "type": "VEC3",
				"min": [-0.06, 0.5, -0.46], "max": [0.06, 0.6, 0.11]},
			{"bufferView": 1, "componentType": 5123, "count": 3 * len(tris), "type": "SCALAR"},
			{"bufferView": 2, "componentType": 5121, "count": len(bind), "type": "VEC4"},
			{"bufferView": 3, "componentType": 5126, "count": len(bind), "type": "VEC4"},
			{"bufferView": 4, "componentType": 5126, "count": 2, "type": "MAT4"}],
		"bufferViews": views, "buffers": [{"byteLength": len(binary)}]}
	return write_glb(doc, binary)


ENTRY = {"radius": RADIUS, "centreline": CENTRELINE}


def _plan(data: bytes, bones: int = 8) -> tuple[dict, str]:
	"""Plan a chain from a fixture the way rig_creature does."""
	doc, binary = read_glb(data)
	primitive, positions, indices = tail.mesh_arrays(doc, binary)
	sha = __import__("hashlib").sha256(tail.accessor_bytes(doc, binary, primitive["attributes"]["POSITION"])).hexdigest()
	return tail.plan_chain(positions, indices, ENTRY, bones), sha


# --- negative tests ---------------------------------------------------------------------

def test_n01_an_empty_capsule_refuses() -> None:
	"""A centreline nowhere near the mesh finds no tail, and says so."""
	doc, binary = read_glb(_glb())
	_p, positions, indices = tail.mesh_arrays(doc, binary)
	_refuses("N01 empty capsule refuses",
		lambda: tail.segment_tail(positions, indices, [[5, 5, 5], [5, 5, 6]], RADIUS))


def test_n02_a_different_mesh_refuses() -> None:
	"""A file whose positions differ by 1 mm is not the mesh the plan was made on."""
	plan, sha = _plan(_glb())
	_refuses("N02 different POSITION data refuses", lambda: tail.rig_file(_glb(nudge=0.001), plan, sha))


def test_n03_a_chained_file_refuses() -> None:
	"""Chaining an output would append a second tail."""
	plan, sha = _plan(_glb())
	once, _ = tail.rig_file(_glb(), plan, sha)
	_refuses("N03 already-chained file refuses", lambda: tail.rig_file(once, plan, sha))


def test_n04_no_hips_refuses() -> None:
	"""The chain hangs from Hips; a skin without one is refused."""
	data = _glb(hips_name="Pelvis")
	plan, sha = _plan(data)
	_refuses("N04 skin without Hips refuses", lambda: tail.rig_file(data, plan, sha))


def test_n05_the_socket_reserve_is_kept() -> None:
	"""2 joints + 60 tail bones would leave no room for socket_main/off/head within 64."""
	plan, sha = _plan(_glb())
	plan["bones"] = 60
	plan["stations"] = (plan["stations"] * 8)[:60]
	plan["radii"] = [0.01] * 60
	_refuses("N05 chain that eats the socket reserve refuses", lambda: tail.rig_file(_glb(), plan, sha))


def test_n08_a_chain_longer_than_its_tail_refuses() -> None:
	"""60 segments on a 25-vertex tail leaves segments with no surface to measure a radius from."""
	_refuses("N08 a segment with no vertices refuses", lambda: _plan(_glb(), bones=60))


def test_n06_verify_bind_catches_a_moved_joint() -> None:
	"""Move one new joint's node after the fact: hierarchy and inverse bind now disagree."""
	plan, sha = _plan(_glb())
	out, _ = tail.rig_file(_glb(), plan, sha)
	doc, binary = read_glb(out)
	node = next(n for n in doc["nodes"] if n.get("name") == "tail_03")
	node["translation"] = [node["translation"][0] + 0.01, node["translation"][1], node["translation"][2]]
	_refuses("N06 verify_bind catches a joint moved off its bind pose", lambda: tail.verify_bind(doc, binary))


def test_n07_two_primitives_refuse() -> None:
	"""Half-rigging a two-primitive mesh would tear it."""
	doc, binary = read_glb(_glb(primitives=2))
	_refuses("N07 two primitives refuse", lambda: tail.mesh_arrays(doc, binary))


# --- positive tests ---------------------------------------------------------------------

def test_segmentation_welds_the_seam_and_takes_the_fringe() -> None:
	"""All 24 strip vertices across the seam, the 1.2r fringe; not the 1.6r one, the front or the body."""
	_pos, _tris, _bind, roles = _mesh()
	plan, _ = _plan(_glb())
	chosen = plan["tail"]
	check("every strip vertex, across the UV seam", roles["strip"] <= chosen)
	check("the fringe vertex at 1.2x radius is taken", roles["near"] in chosen)
	check("the vertex at 1.6x radius is not", roles["far"] not in chosen)
	check("the vertex before the root plane is not", roles["front"] not in chosen)
	check("the separate body triangle is not", not (roles["body"] & chosen))
	check("exactly 25 vertices", len(chosen) == 25)


def test_a_thin_tail_can_opt_out_of_refit_and_growth() -> None:
	"""With "grow": false the 1.2x fringe stays out: a mouse tail beside a dress must not walk onto it."""
	_pos, _tris, _bind, roles = _mesh()
	doc, binary = read_glb(_glb())
	_p, positions, indices = tail.mesh_arrays(doc, binary)
	plan = tail.plan_chain(positions, indices, {**ENTRY, "refit": False, "grow": False}, 8)
	check("growth off: the 1.2x fringe vertex is not taken", roles["near"] not in plan["tail"])
	check("growth off: the whole strip still is", roles["strip"] <= plan["tail"])


def test_refit_off_means_one_capture_pass() -> None:
	"""The refit is a feedback loop beside clothing: with "refit": false the tail is captured ONCE."""
	doc, binary = read_glb(_glb())
	_p, positions, indices = tail.mesh_arrays(doc, binary)
	real, calls = tail.segment_tail, []
	def counting(*args, **kwargs):
		calls.append(1)
		return real(*args, **kwargs)
	tail.segment_tail = counting
	try:
		tail.plan_chain(positions, indices, {**ENTRY, "refit": False}, 8)
		once = len(calls)
		calls.clear()
		tail.plan_chain(positions, indices, ENTRY, 8)
		twice = len(calls)
	finally:
		tail.segment_tail = real
	check("refit off: one capture pass", once == 1)
	check("refit on (the default): two capture passes", twice == 2)


def test_the_chain_hangs_from_hips_in_order() -> None:
	"""tail_00..tail_07, tail_00 under Hips, each under the one before, all in the skin."""
	plan, sha = _plan(_glb())
	doc, _ = read_glb(tail.rig_file(_glb(), plan, sha)[0])
	names = [n.get("name") for n in doc["nodes"]]
	chain = [names.index(f"tail_{i:02d}") for i in range(8)]
	check("eight tail joints exist", all(f"tail_{i:02d}" in names for i in range(8)))
	check("tail_00 is a child of Hips", chain[0] in doc["nodes"][names.index("Hips")]["children"])
	check("each tail joint is the child of the one before",
		all(chain[i + 1] in doc["nodes"][chain[i]].get("children", []) for i in range(7)))
	check("the skin has 2 + 8 = 10 joints", len(doc["skins"][0]["joints"]) == 10)


def test_weights_cut_the_thigh_and_blend_at_the_root() -> None:
	"""No tail vertex follows the thigh any more; the root blends from the hips; the tip is tail_07."""
	_pos, _tris, _bind, roles = _mesh()
	plan, sha = _plan(_glb())
	doc, binary = read_glb(tail.rig_file(_glb(), plan, sha)[0])
	prim = doc["meshes"][0]["primitives"][0]
	joints = tail.read_accessor(doc, binary, prim["attributes"]["JOINTS_0"])
	weights = tail.read_accessor(doc, binary, prim["attributes"]["WEIGHTS_0"])
	slot = {doc["nodes"][n]["name"]: s for s, n in enumerate(doc["skins"][0]["joints"])}
	def w(v, name):
		return sum(wt for j, wt in zip(joints[v], weights[v]) if j == slot[name])
	check("no tail vertex keeps any thigh weight", all(w(v, "LeftUpLeg") == 0.0 for v in plan["tail"]))
	check("every tail vertex's weights sum to 1", all(abs(sum(weights[v]) - 1.0) < 1e-6 for v in plan["tail"]))
	check("the root vertices blend from Hips", all(w(v, "Hips") > 0.0 for v in roles["root"]))
	check("the tip vertices are entirely tail_07", all(abs(w(v, "tail_07") - 1.0) < 1e-6 for v in roles["tip"]))
	check("the body keeps its Hips binding", all(w(v, "Hips") == 1.0 for v in roles["body"]))


def test_each_joint_carries_its_measured_radius() -> None:
	"""Each segment's surface radius, stored on the node: 5 mm for the strip, wider where the fringe is."""
	plan, sha = _plan(_glb())
	doc, _ = read_glb(tail.rig_file(_glb(), plan, sha)[0])
	radii = [n["extras"]["spring_radius_m"] for n in doc["nodes"] if n.get("name", "").startswith("tail_")]
	check("eight radii, one per joint", len(radii) == 8)
	check("seven segments are the strip's 5 mm half-width", sum(1 for r in radii if abs(r - 0.005) < 1e-4) == 7)
	check("the segment holding the 1.2x fringe vertex is wider, 25-37 mm: the fringe is surface",
		0.025 <= radii[4] <= 0.037)


def test_a_sparse_segment_is_floored_at_the_tails_median_radius() -> None:
	"""A segment holding one vertex ON the axis measures 0 m; it must not tell the spring that.

	The mouse keeper's visible tail is 72 vertices over 24 cm, and two of its eight segments
	measured 0.0 and 0.002 m. A zero collision radius lets half the tail's thickness sink.
	"""
	line = [[0.0, 0.5, 0.0], [0.0, 0.5, -0.4]]
	positions = [(-0.005, 0.5, -0.05), (0.005, 0.5, -0.05), (-0.005, 0.5, -0.15), (0.005, 0.5, -0.15),
		(0.0, 0.5, -0.25),                                  # segment 2: one vertex, on the axis
		(-0.005, 0.5, -0.35), (0.005, 0.5, -0.35)]
	plan = {"tail": set(range(len(positions))), "centreline": line, "length": 0.4, "bones": 4}
	radii = tail.segment_radii(positions, plan)
	check("the on-axis segment is floored to the 5 mm median, not 0", radii[2] == 0.005)
	check("the other segments keep their own 5 mm", radii[0] == radii[1] == radii[3] == 0.005)


def test_bind_check_reports_the_repairs_root_scale() -> None:
	"""A repaired, rescaled root (x1.2) is a uniform bind scale of 1.2, not a failure."""
	plan, sha = _plan(_glb())
	_out, report = tail.rig_file(_glb(root_scale=1.2), plan, sha)
	check("bind scale 1.0 on an unscaled rig", tail.rig_file(_glb(), plan, sha)[1]["bind_scale"] == 1.0)
	check("bind scale 1.2 on a rig the repair rescaled", abs(report["bind_scale"] - 1.2) < 1e-9)


def test_the_output_is_well_formed_and_keeps_the_source() -> None:
	"""Header length, chunk alignment, and the source BIN as an intact prefix."""
	plan, sha = _plan(_glb())
	out = tail.rig_file(_glb(), plan, sha)[0]
	magic, version, total = struct.unpack_from("<III", out, 0)
	json_len = struct.unpack_from("<I", out, 12)[0]
	check("magic, version and declared length", (magic, version, total) == (0x46546C67, 2, len(out)))
	check("JSON chunk 4-byte aligned", json_len % 4 == 0)
	check("source BIN survives as a prefix", read_glb(out)[1].startswith(read_glb(_glb())[1]))
	check("stamped once", json.dumps(read_glb(out)[0]["asset"]).count("redwall_tail_rig") == 1)


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
	print("test_rig_meshy_tail: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
