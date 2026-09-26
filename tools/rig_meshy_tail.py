#!/usr/bin/env python3
"""Give a Meshy-rigged creature a tail bone chain, in the glTF itself. Decision 0191.

Meshy's auto-rig is a 24-joint humanoid with no tail. Its skinning binds the tail to
whatever bone was nearest: the hips, and for three creatures a THIGH, so a squirrel's
tail swings with one leg. This appends a chain of `bones` joints (`tail_00`... parented to
Hips) along the tail and re-weights the tail's vertices onto it, blending into the hips
at the root. Driving the chain -- a spring simulation for the skeletal pool, baked keys for
the crowd -- is a separate step; this makes the tail a tail.

THE TAIL IS FOUND FROM AUTHORED DATA, NOT GUESSED. `tail_centrelines.json` gives each
creature a rough centreline and a capsule radius. The tail is every vertex, welded across
UV seams, that the mesh surface connects to the tail tip without leaving the capsule or
crossing the root plane. The centreline is then refitted to the selected vertices' own
centroids before the joints are placed.

Every file of a creature (rigged.glb and each anim_*.glb) must carry the same mesh; the
segmentation is computed once and a file whose POSITION data differs is refused. Reads the
repaired output of tools/repair_meshy_rig.py and writes <key>/tailed/.

    python3 tools/rig_meshy_tail.py              # chain every creature the config names
    python3 tools/rig_meshy_tail.py --dry-run    # segment and report, write nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from repair_meshy_rig import RepairRefused, read_glb, write_glb  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library/creature"
CONFIG = ROOT / "docs/art-reference/asset_library/tail_centrelines.json"
MANIFEST = ROOT / "docs/art-reference/asset_library/tailed.json"

BONE_BUDGET = 64
SOCKET_RESERVE = 3          # socket_main, socket_off, socket_head (crowd doc §9.1)
REFINE_BINS = 12
ROOT_BLEND_SEGMENTS = 1.0   # the first segment blends from the hips into tail_00: a tail base is its stiffest part
WELD_DECIMALS = 5
GROW_RINGS = 3              # rings of neighbours added past the capsule, to take the clipped surface
GROW_RADIUS_FACTOR = 1.35   # ...but never beyond this multiple of the capsule radius
RADIUS_PERCENTILE = 0.95   # a segment's collision radius: this share of its surface lies within it
STAMP = "redwall_tail_rig"
STAMP_VERSION = 1

COMPONENTS = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class TailRefused(RepairRefused):
	"""A creature or file this tool must not rig, with the reason."""


# --- accessors ---------------------------------------------------------------------------

def read_accessor(doc: dict, binary: bytes, index: int) -> list[tuple]:
	"""Every element of one accessor, honouring stride and normalisation."""
	accessor = doc["accessors"][index]
	view = doc["bufferViews"][accessor["bufferView"]]
	code, size = COMPONENTS[accessor["componentType"]]
	width = WIDTHS[accessor["type"]]
	stride = view.get("byteStride", size * width)
	base = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
	scale = {"B": 255.0, "H": 65535.0}.get(code) if accessor.get("normalized") else None
	rows = []
	for k in range(accessor["count"]):
		row = struct.unpack_from("<" + code * width, binary, base + k * stride)
		rows.append(tuple(v / scale for v in row) if scale else row)
	return rows


def accessor_bytes(doc: dict, binary: bytes, index: int) -> bytes:
	"""The raw bytes one accessor spans, for exact comparison between files."""
	accessor = doc["accessors"][index]
	view = doc["bufferViews"][accessor["bufferView"]]
	start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
	code, size = COMPONENTS[accessor["componentType"]]
	return binary[start:start + accessor["count"] * size * WIDTHS[accessor["type"]]]


def append_accessor(doc: dict, binary: bytes, rows: list, component: int, kind: str) -> tuple[bytes, int]:
	"""Pack rows into a new tightly-packed bufferView and accessor at the end of the BIN."""
	code, size = COMPONENTS[component]
	data = b"".join(struct.pack("<" + code * WIDTHS[kind], *row) for row in rows)
	binary = binary + b"\x00" * (-len(binary) % 4)
	doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(data)})
	doc["accessors"].append({"bufferView": len(doc["bufferViews"]) - 1, "componentType": component,
		"count": len(rows), "type": kind})
	return binary + data, len(doc["accessors"]) - 1


# --- geometry ----------------------------------------------------------------------------

def _sub(a, b):
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def _dot(a, b):
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def closest_on_polyline(poly: list, point) -> tuple[float, float, bool]:
	"""(distance, arc length t of the closest point, lies before the root plane)."""
	best = (math.inf, 0.0, False)
	travelled = 0.0
	for i in range(len(poly) - 1):
		a, b = poly[i], poly[i + 1]
		ab = _sub(b, a)
		length = math.sqrt(_dot(ab, ab))
		u = _dot(_sub(point, a), ab) / (length * length)
		clamped = min(max(u, 0.0), 1.0)
		foot = [a[k] + ab[k] * clamped for k in range(3)]
		distance = math.dist(point, foot)
		if distance < best[0]:
			best = (distance, travelled + clamped * length, i == 0 and u < 0.0)
		travelled += length
	return best


def polyline_length(poly: list) -> float:
	"""Total arc length."""
	return sum(math.dist(poly[i], poly[i + 1]) for i in range(len(poly) - 1))


def point_at(poly: list, t: float) -> list:
	"""The point at arc length t, clamped to the polyline."""
	for i in range(len(poly) - 1):
		length = math.dist(poly[i], poly[i + 1])
		if t <= length or i == len(poly) - 2:
			u = min(max(t / length, 0.0), 1.0)
			return [poly[i][k] + (poly[i + 1][k] - poly[i][k]) * u for k in range(3)]
		t -= length
	return list(poly[-1])


def weld(positions: list) -> list[int]:
	"""A shared id for every vertex at the same position: glTF splits them at UV seams."""
	ids: dict = {}
	return [ids.setdefault(tuple(round(c, WELD_DECIMALS) for c in p), len(ids)) for p in positions]


def segment_tail(positions: list, indices: list, poly: list, radius: float) -> set[int]:
	"""Vertices the surface connects to the tail tip inside the capsule, past the root plane."""
	info = [closest_on_polyline(poly, p) for p in positions]
	inside = [i for i, (d, _t, before) in enumerate(info) if d < radius and not before]
	if not inside:
		raise TailRefused("no vertex lies inside the authored tail capsule")
	ids = weld(positions)
	members: dict = {}
	for i in inside:
		members.setdefault(ids[i], []).append(i)
	neighbours: dict = {w: set() for w in members}
	for k in range(0, len(indices), 3):
		tri = [ids[v] for v in indices[k:k + 3]]
		for a in tri:
			for b in tri:
				if a != b and a in neighbours and b in neighbours:
					neighbours[a].add(b)
	tip = ids[max(inside, key=lambda i: info[i][1])]
	seen, stack = {tip}, [tip]
	while stack:
		for nxt in neighbours[stack.pop()]:
			if nxt not in seen:
				seen.add(nxt)
				stack.append(nxt)
	core = {i for w in seen for i in members[w]}
	return _grow(core, positions, indices, ids, info, radius)


def _grow(core: set[int], positions: list, indices: list, ids: list, info: list, radius: float) -> set[int]:
	"""Take the tail surface the capsule clipped: a few rings of neighbours, still past the root.

	A capsule sized to the tail's axis cuts through a bushy tail's outer surface. Vertices left
	outside keep their old binding -- a thigh, for three creatures -- and the triangles between
	them and the chain stretch into spikes once the tail moves. The growth is ring-limited and
	radius-capped so it takes the clipped fringe and cannot flood into a leg.
	"""
	limit = radius * GROW_RADIUS_FACTOR
	by_weld: dict = {}
	for i, w in enumerate(ids):
		by_weld.setdefault(w, []).append(i)
	selected = {ids[i] for i in core}
	for _ring in range(GROW_RINGS):
		ring = set()
		for k in range(0, len(indices), 3):
			tri = [ids[v] for v in indices[k:k + 3]]
			if any(w in selected for w in tri):
				ring.update(w for w in tri if w not in selected)
		ring = {w for w in ring if all(info[i][0] < limit and not info[i][2] for i in by_weld[w])}
		if not ring:
			break
		selected |= ring
	return {i for w in selected for i in by_weld[w]}


def refit_centreline(positions: list, tail: set[int], poly: list) -> list:
	"""The authored root, then the centroid of the selected vertices in equal arc-length bins."""
	length = polyline_length(poly)
	sums: dict = {}
	for i in tail:
		t = closest_on_polyline(poly, positions[i])[1]
		b = min(int(t / length * REFINE_BINS), REFINE_BINS - 1)
		acc = sums.setdefault(b, [0.0, 0.0, 0.0, 0])
		for k in range(3):
			acc[k] += positions[i][k]
		acc[3] += 1
	centroids = [[s[0] / s[3], s[1] / s[3], s[2] / s[3]] for _b, s in sorted(sums.items())]
	return [list(poly[0])] + centroids


# --- matrices (column-major, as glTF stores them) ----------------------------------------

def mat_mul(a: list, b: list) -> list:
	"""a @ b for column-major 4x4 matrices."""
	return [sum(a[k * 4 + r] * b[c * 4 + k] for k in range(4)) for c in range(4) for r in range(4)]


def trs_matrix(node: dict) -> list:
	"""A node's local matrix from its TRS (or its matrix)."""
	if "matrix" in node:
		return list(node["matrix"])
	x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
	sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
	tx, ty, tz = node.get("translation", [0.0, 0.0, 0.0])
	r = [1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w),
		2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w),
		2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y)]
	return [r[0] * sx, r[1] * sx, r[2] * sx, 0.0, r[3] * sy, r[4] * sy, r[5] * sy, 0.0,
		r[6] * sz, r[7] * sz, r[8] * sz, 0.0, tx, ty, tz, 1.0]


def node_worlds(doc: dict) -> dict[int, list]:
	"""World matrix of every node reachable from the scene, from the node hierarchy alone."""
	worlds: dict = {}
	stack = [(n, [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0])
		for n in doc["scenes"][doc.get("scene", 0)]["nodes"]]
	while stack:
		node, parent = stack.pop()
		worlds[node] = mat_mul(parent, trs_matrix(doc["nodes"][node]))
		stack.extend((c, worlds[node]) for c in doc["nodes"][node].get("children", []))
	return worlds


def transform_point(m: list, p) -> list:
	"""m applied to a point."""
	return [m[r] * p[0] + m[4 + r] * p[1] + m[8 + r] * p[2] + m[12 + r] for r in range(3)]


# --- the chain ---------------------------------------------------------------------------

def mesh_arrays(doc: dict, binary: bytes) -> tuple[dict, list, list]:
	"""The single primitive, its positions, and its triangle indices."""
	if len(doc["meshes"]) != 1 or len(doc["meshes"][0]["primitives"]) != 1:
		raise TailRefused("expected exactly one mesh with one primitive")
	primitive = doc["meshes"][0]["primitives"][0]
	positions = read_accessor(doc, binary, primitive["attributes"]["POSITION"])
	indices = [row[0] for row in read_accessor(doc, binary, primitive["indices"])]
	return primitive, positions, indices


def plan_chain(positions: list, indices: list, entry: dict, bones: int) -> dict:
	"""Segment, refit, and place `bones` joint stations along the tail. File-independent."""
	## Two passes: the authored line is rough, so segment against it, refit the line to what was
	## found, then segment again against the refitted line, which sits in the tail's real centre.
	first = segment_tail(positions, indices, entry["centreline"], entry["radius"])
	rough = refit_centreline(positions, first, entry["centreline"])
	tail = segment_tail(positions, indices, rough, entry["radius"])
	refit = refit_centreline(positions, tail, rough)
	length = polyline_length(refit)
	stations = [point_at(refit, i * length / bones) for i in range(bones)]
	plan = {"tail": tail, "centreline": refit, "length": length, "stations": stations, "bones": bones}
	plan["radii"] = segment_radii(positions, plan)
	return plan


def segment_radii(positions: list, plan: dict) -> list[float]:
	"""Each segment's surface radius about the centreline, in metres.

	A spring's collision radius must be the tail's SURFACE, not its axis: a bushy squirrel tail is
	about twice as thick as a single guessed radius, and with the axis held off the ground the fur
	still sinks through it. A high percentile, not the maximum, so one stray fringe vertex cannot
	inflate a whole segment.
	"""
	segment = plan["length"] / plan["bones"]
	buckets: list[list[float]] = [[] for _ in range(plan["bones"])]
	for v in plan["tail"]:
		distance, t, _before = closest_on_polyline(plan["centreline"], positions[v])
		buckets[min(int(t / segment), plan["bones"] - 1)].append(distance)
	radii = []
	for bucket in buckets:
		if not bucket:
			raise TailRefused("a tail segment has no vertices; the chain is longer than the tail")
		bucket.sort()
		radii.append(round(bucket[min(int(len(bucket) * RADIUS_PERCENTILE), len(bucket) - 1)], 4))
	return radii


def tail_weights(plan: dict, positions: list, hips: int, first: int, joints: list, weights: list) -> None:
	"""Rewrite each tail vertex's influences: hips at the root, then two adjacent chain joints."""
	bones, segment = plan["bones"], plan["length"] / plan["bones"]
	blend = ROOT_BLEND_SEGMENTS * segment
	for v in plan["tail"]:
		t = closest_on_polyline(plan["centreline"], positions[v])[1]
		u = t / segment
		a = min(int(u), bones - 1)
		f = u - a if a < bones - 1 else 0.0
		h = max(0.0, 1.0 - t / blend)
		influence: dict = {}
		for slot, w in ((hips, h), (first + a, (1.0 - f) * (1.0 - h)), (first + min(a + 1, bones - 1), f * (1.0 - h))):
			if w > 0.0:
				influence[slot] = influence.get(slot, 0.0) + w
		total = sum(influence.values())
		pairs = sorted(influence.items(), key=lambda kv: -kv[1])[:4]
		pairs += [(0, 0.0)] * (4 - len(pairs))
		joints[v] = tuple(p[0] for p in pairs)
		weights[v] = tuple(p[1] / total for p in pairs)


def add_joints(doc: dict, binary: bytes, plan: dict) -> tuple[bytes, int, int]:
	"""Append tail_00.. under Hips, with inverse binds sharing the hips' basis. Returns slots."""
	skin = doc["skins"][0]
	names = [doc["nodes"][n].get("name") for n in skin["joints"]]
	if "Hips" not in names:
		raise TailRefused("the skin has no Hips joint")
	if len(names) + plan["bones"] > BONE_BUDGET - SOCKET_RESERVE:
		raise TailRefused(f"{len(names)} + {plan['bones']} joints would leave no room for the three sockets")
	hips = names.index("Hips")
	ibm = read_accessor(doc, binary, skin["inverseBindMatrices"])
	a = ibm[hips]
	basis = [a[0], a[1], a[2], 0.0, a[4], a[5], a[6], 0.0, a[8], a[9], a[10], 0.0, 0.0, 0.0, 0.0, 1.0]
	parent_node, previous = skin["joints"][hips], None
	for i, p in enumerate(plan["stations"]):
		local = transform_point(a, p) if previous is None else transform_point(basis, _sub(p, previous))
		doc["nodes"].append({"name": f"tail_{i:02d}", "translation": local,
			"extras": {"spring_radius_m": plan["radii"][i]}})
		node = len(doc["nodes"]) - 1
		doc["nodes"][parent_node].setdefault("children", []).append(node)
		skin["joints"].append(node)
		t = transform_point(basis, p)
		ibm.append(tuple(basis[:12]) + (-t[0], -t[1], -t[2], 1.0))
		parent_node, previous = node, p
	binary, index = append_accessor(doc, binary, ibm, 5126, "MAT4")
	skin["inverseBindMatrices"] = index
	return binary, hips, len(names)


def verify_bind(doc: dict, binary: bytes) -> float:
	"""world(node hierarchy) @ inverse_bind must be the same uniform scale c for EVERY joint.

	The worlds come from walking the node TRS chain; the inverse binds come from the skin.
	add_joints writes the two by different arithmetic, so an error in either breaks this.
	Returns c (1.0, or the repair's height scale for a rescaled creature).
	"""
	worlds = node_worlds(doc)
	skin = doc["skins"][0]
	ibm = read_accessor(doc, binary, skin["inverseBindMatrices"])
	scale = None
	for slot, node in enumerate(skin["joints"]):
		m = mat_mul(worlds[node], list(ibm[slot]))
		c = m[0] if scale is None else scale
		expected = [c, 0, 0, 0, 0, c, 0, 0, 0, 0, c, 0, 0, 0, 0, 1.0]
		if max(abs(m[k] - expected[k]) for k in range(16)) > 1e-4 * max(1.0, abs(c)):
			raise TailRefused(f"joint {doc['nodes'][node].get('name')} is not at its bind pose")
		scale = c
	return scale


def rig_file(data: bytes, plan: dict, positions_sha: str) -> tuple[bytes, dict]:
	"""Add the planned chain to one rigged or animated GLB."""
	doc, binary = read_glb(data)
	if STAMP in doc.get("asset", {}).get("extras", {}):
		raise TailRefused("already has a tail chain; rig the repaired file, not an output")
	primitive = doc["meshes"][0]["primitives"][0]
	if hashlib.sha256(accessor_bytes(doc, binary, primitive["attributes"]["POSITION"])).hexdigest() != positions_sha:
		raise TailRefused("POSITION data differs from rigged.glb; the segmentation does not apply")
	original = binary
	positions = read_accessor(doc, binary, primitive["attributes"]["POSITION"])
	joints = list(read_accessor(doc, binary, primitive["attributes"]["JOINTS_0"]))
	weights = list(read_accessor(doc, binary, primitive["attributes"]["WEIGHTS_0"]))
	binary, hips, first = add_joints(doc, binary, plan)
	tail_weights(plan, positions, hips, first, joints, weights)
	binary, primitive["attributes"]["JOINTS_0"] = append_accessor(doc, binary, joints, 5121, "VEC4")
	binary, primitive["attributes"]["WEIGHTS_0"] = append_accessor(doc, binary, weights, 5126, "VEC4")
	scale = verify_bind(doc, binary)
	doc["asset"].setdefault("extras", {})[STAMP] = {"version": STAMP_VERSION, "bones": plan["bones"],
		"tail_vertices": len(plan["tail"]), "source_sha256": hashlib.sha256(data).hexdigest()}
	out = write_glb(doc, binary)
	if not read_glb(out)[1].startswith(original):
		raise TailRefused("original BIN data did not survive intact")
	return out, {"joints": len(doc["skins"][0]["joints"]), "bind_scale": round(scale, 6)}


def rig_creature(key_dir: pathlib.Path, entry: dict, bones: int, dry_run: bool) -> list[dict]:
	"""Plan once from repaired/rigged.glb, then chain every repaired file of the creature."""
	source = key_dir / "repaired" / "rigged.glb"
	doc, binary = read_glb(source.read_bytes())
	primitive, positions, indices = mesh_arrays(doc, binary)
	sha = hashlib.sha256(accessor_bytes(doc, binary, primitive["attributes"]["POSITION"])).hexdigest()
	plan = plan_chain(positions, indices, entry, bones)
	rows = []
	for path in sorted((key_dir / "repaired").glob("*.glb")):
		data = path.read_bytes()
		out, report = rig_file(data, plan, sha)
		if not dry_run:
			(key_dir / "tailed").mkdir(exist_ok=True)
			(key_dir / "tailed" / path.name).write_bytes(out)
		rows.append({"key": key_dir.name, "file": path.name, "tail_vertices": len(plan["tail"]),
			"tail_length_m": round(plan["length"], 4), "joint_radius_m": plan["radii"], **report,
			"source_sha256": hashlib.sha256(data).hexdigest(), "output_sha256": hashlib.sha256(out).hexdigest()})
	return rows


def main() -> int:
	"""Chain every creature the config names, and write the manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--config", type=pathlib.Path, default=CONFIG)
	parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
	parser.add_argument("--dry-run", action="store_true")
	args = parser.parse_args()
	config = json.loads(args.config.read_text(encoding="utf-8"))
	rows = []
	try:
		for key, entry in sorted(config["chains"].items()):
			rows += rig_creature(args.library / key, entry, config["bones"], args.dry_run)
	except RepairRefused as refused:
		print(f"rig_meshy_tail: REFUSED -- {refused}")
		return 1
	for key in sorted({r["key"] for r in rows}):
		r = next(x for x in rows if x["key"] == key)
		print(f"  {key:18} {r['tail_vertices']:5} tail vertices, {r['tail_length_m']:.3f} m, {r['joints']} joints, bind scale {r['bind_scale']}, radii {r['joint_radius_m']}")
	print(f"rig_meshy_tail: {len(rows)} files chained{' (dry run)' if args.dry_run else ''}; "
		f"no chain by design: {sorted(config.get('no_chain', {}))}")
	if not args.dry_run:
		args.manifest.write_text(json.dumps({"tool": "tools/rig_meshy_tail.py", "decision": "0191",
			"count": len(rows), "files": rows}, indent=1) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
