#!/usr/bin/env python3
"""Lift Meshy's clips so the creature's support never goes below the ground. Decisions 0193, 0195, 0197, 0201, 0202.

Every repaired bind pose stands exactly on y = 0, but Meshy's retargeted clips sink the feet:
1-10 cm at idle, 17 cm in the otter boatwright's walk, 35 cm in the squirrels' pull_radish.
This lifts the hips, key by key, by exactly as much as the lowest SUPPORT point is below the
ground -- max(0, -lowest) -- and never lowers them, so a run keeps its flight phase and a chair
clip keeps its seat height.

The one exception is a STANDING clip whose support never reaches the ground on any key: it is
SEATED, lowered as a whole by that constant gap so its lowest key just touches. Once the repair
step resets Meshy's idle Hips scale (1.1765 on every creature) to rest, the idle's hips stand
where they held a 17.65% larger body, and its feet float 3 mm - 20 cm (decision 0197). Every clip
stands except those in OFF_THE_GROUND, whose height is their own: a chair's seat.

SUPPORT is every vertex whose strongest influence is a foot, toe or leg joint: the feet when
standing, the knees when kneeling. Arms are not support (they reach into the soil to dig or pull
a radish), nor is the body (a dress hem hangs; it does not bear weight), nor the tail (the
spring handles it, decision 0192).

Only the Hips translation keys change: they are rewritten on the clip's full timeline with the
lift added, as a new accessor appended to the BIN. Everything else survives byte for byte, and
the source BIN is an exact prefix of the output. The result is re-skinned independently and
refused unless every key's lowest support point is at or above -GROUND_TOLERANCE_M.

Before any of that, an in-place clip whose Hips swing round more than TWIST_SWING_DEG -- Meshy's idle,
on every creature -- is UNTWISTED: held at the walk's heading with its feet pinned (decision 0201; see
the heading section below). Then every planted foot that drifts across the ground is PINNED where it is
planted (decision 0202; see the feet section).

Source: <key>/tailed/ where the creature has a tail chain, else <key>/repaired/.
Output: <key>/grounded/ -- every clip, plus rigged.glb copied unchanged.

	python3 tools/ground_meshy_clips.py              # ground the whole creature library
	python3 tools/ground_meshy_clips.py --dry-run    # measure and report, write nothing
"""

from __future__ import annotations

import argparse
import concurrent.futures
import copy
import hashlib
import json
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bake_meshy_tail import _channels, _sample, _skin, _skinning, _worlds_at, rotation_time_accessor  # noqa: E402
from repair_meshy_rig import SCALE_TOLERANCE, RepairRefused, read_glb, write_glb  # noqa: E402
from rig_meshy_tail import append_accessor, mat_mul, node_worlds, read_accessor  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library/creature"
MANIFEST = ROOT / "docs/art-reference/asset_library/grounded.json"
STAMP = "redwall_clip_ground"
STAMP_VERSION = 3          # 2: root motion extracted (decision 0195); 3: floating standing clips seated (0197)
ROOT_MOTION_MIN_M = 0.01   # a clip travelling less than this over its loop is already in place
ROOT_WINDOW_S = 1.0        # one gait cycle: Meshy's walk loop is 1.03 s
SUPPORT_JOINTS = ("Foot", "Toe", "Leg")
GROUND_TOLERANCE_M = 0.001
OFF_THE_GROUND = ("anim_chair_sit_idle",)   # clips whose support may hover: never seated
## Clips played in water, and where they sit against its surface (decision 0203). The waterline is y = 0.
## A water clip is never lifted, seated, pinned or untwisted -- it has no ground -- and is checked against
## the waterline instead: a SURFACE clip holds the Head above it and the Hips below it on every key; a
## SUBMERGED clip keeps every vertex below it.
WATER_CLIPS = {"anim_swim": "surface", "anim_tread_water": "surface", "anim_dive": "submerged"}
WATERLINE_Y_M = 0.0


class GroundRefused(RepairRefused):
	"""A clip this tool must not ground, with the reason."""


def support_vertices(names: list, jnt: list, wgt: list) -> list[int]:
	"""Vertices whose strongest influence is a foot, toe or leg joint.

	A chained tail's vertices are never among them: their strongest influence is a tail joint,
	and rig_meshy_tail.py strips the thigh weights Meshy gave them (decision 0191)."""
	support = []
	for v in range(len(jnt)):
		strongest = names[jnt[v][max(range(4), key=lambda q: wgt[v][q])]]
		if any(part in strongest for part in SUPPORT_JOINTS):
			support.append(v)
	if not support:
		raise GroundRefused("no vertex is weighted to a foot, toe or leg joint")
	return support


def lowest_support(doc: dict, binary: bytes) -> tuple[list[float], list[float]]:
	"""The clip's timeline, and at each key the lowest skinned height of any support vertex."""
	skin, names, ibm, pos, jnt, wgt = _skinning(doc, binary)
	support = support_vertices(names, jnt, wgt)
	times, animated = _channels(doc, binary)
	lows = []
	for k in range(len(times)):
		worlds = _worlds_at(doc, animated, k)
		mats = [mat_mul(worlds[node], list(ibm[s])) for s, node in enumerate(skin["joints"])]
		lows.append(min(_skin(mats, jnt[v], wgt[v], pos[v]) for v in support))
	return times, lows


def _hips(doc: dict) -> tuple[int, dict]:
	"""The Hips node index and its translation channel; refuse if an ancestor of Hips is animated."""
	hips = next((i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Hips"), None)
	if hips is None:
		raise GroundRefused("no Hips node")
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	ancestors, node = set(), hips
	while node in parents:
		node = parents[node]
		ancestors.add(node)
	anim = doc["animations"][0]
	if any(c["target"]["node"] in ancestors for c in anim["channels"]):
		raise GroundRefused("an ancestor of Hips is animated; a Hips lift would not be a world lift")
	channel = next((c for c in anim["channels"] if c["target"]["node"] == hips and c["target"]["path"] == "translation"), None)
	if channel is None:
		raise GroundRefused("the clip does not animate the Hips translation")
	return hips, channel


def world_in_parent_space(doc: dict, hips: int, world: list[float]) -> list[float]:
	"""The Hips-local translation that moves the hips by `world` (metres) in the world."""
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	if hips not in parents:
		return list(world)
	m = node_worlds(doc)[parents[hips]]
	a, b, c = [m[0], m[1], m[2]], [m[4], m[5], m[6]], [m[8], m[9], m[10]]   # the parent's basis columns
	det = a[0] * (b[1] * c[2] - b[2] * c[1]) + a[1] * (b[2] * c[0] - b[0] * c[2]) + a[2] * (b[0] * c[1] - b[1] * c[0])
	if abs(det) < 1e-12:
		raise GroundRefused("the Hips parent's basis is singular")
	## Solve [a b c] x = world. The inverse's rows are (b x c, c x a, a x b) / det. The basis may be
	## scaled or rotated.
	rows = ([b[1] * c[2] - b[2] * c[1], b[2] * c[0] - b[0] * c[2], b[0] * c[1] - b[1] * c[0]],
		[c[1] * a[2] - c[2] * a[1], c[2] * a[0] - c[0] * a[2], c[0] * a[1] - c[1] * a[0]],
		[a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]])
	return [sum(r[i] * world[i] for i in range(3)) / det for r in rows]


def lift_in_parent_space(doc: dict, hips: int) -> list[float]:
	"""The Hips-local translation that moves the hips 1 m straight up in the world."""
	return world_in_parent_space(doc, hips, [0.0, 1.0, 0.0])


def root_path(doc: dict, binary: bytes) -> tuple[list[float], list[list[float]]]:
	"""The clip's timeline, and the world horizontal hips position (x, z) at every key."""
	hips, _channel = _hips(doc)
	times, animated = _channels(doc, binary)
	return times, [[_worlds_at(doc, animated, k)[hips][12], _worlds_at(doc, animated, k)[hips][14]] for k in range(len(times))]


def extract_root(times: list[float], path: list[list[float]]) -> list[list[float]] | None:
	"""The root trajectory to take out of the hips, relative to the first key, or None if in place.

	The root is the hips' horizontal path averaged over ROOT_WINDOW_S -- one gait cycle -- so a
	stride's own sway stays in the clip and only the net progression leaves it. The average runs
	past the clip's ends as the loop would continue: one loop further on is the same pose, moved
	by the whole travel. Its first key is 0 and its last is the travel, so the clip closes."""
	n = len(path)
	travel = [path[-1][0] - path[0][0], path[-1][1] - path[0][1]]
	if math.hypot(*travel) < ROOT_MOTION_MIN_M:
		return None
	dt = (times[-1] - times[0]) / (n - 1)
	half = max(1, round(ROOT_WINDOW_S / (2.0 * dt)))
	def at(k: int) -> list[float]:
		loops, i = divmod(k, n - 1)
		return [path[i][0] + loops * travel[0], path[i][1] + loops * travel[1]]
	average = []
	for k in range(n):
		window = [at(j) for j in range(k - half, k + half + 1)]
		average.append([sum(w[0] for w in window) / len(window), sum(w[1] for w in window) / len(window)])
	return [[a[0] - average[0][0], a[1] - average[0][1]] for a in average]


def apply_lift(doc: dict, binary: bytes, times_index: int, times: list[float], lifts: list[float],
		roots: list[list[float]] | None = None) -> bytes:
	"""Rewrite the Hips translation on the clip's full timeline: lifted by `lifts` (world metres) per
	key and, when `roots` is given, moved back by that key's root (x, z) so the clip plays in place."""
	hips, channel = _hips(doc)
	anim = doc["animations"][0]
	sampler = anim["samplers"][channel["sampler"]]
	keys = [row[0] for row in read_accessor(doc, binary, sampler["input"])]
	values = read_accessor(doc, binary, sampler["output"])
	step = sampler.get("interpolation", "LINEAR") == "STEP"
	up = lift_in_parent_space(doc, hips)
	east, north = world_in_parent_space(doc, hips, [1.0, 0.0, 0.0]), world_in_parent_space(doc, hips, [0.0, 0.0, 1.0])
	rows = []
	for k, (t, lift) in enumerate(zip(times, lifts)):
		v = _sample(keys, values, t, step, False)
		rx, rz = roots[k] if roots is not None else (0.0, 0.0)
		rows.append(tuple(v[i] + up[i] * lift - east[i] * rx - north[i] * rz for i in range(3)))
	binary, output = append_accessor(doc, binary, rows, 5126, "VEC3")
	anim["samplers"].append({"input": times_index, "output": output, "interpolation": "LINEAR"})
	channel["sampler"] = len(anim["samplers"]) - 1
	return binary


def refuse_stray_scale(doc: dict, binary: bytes) -> None:
	"""Refuse a clip that animates any bone's scale away from its rest: the creature would grow and
	shrink as the clip blends in and out. repair_meshy_rig.py resets Meshy's (decision 0197); one
	still here means the clip skipped the repair, or Meshy found a new way to do it."""
	for anim in doc["animations"]:
		for channel in anim["channels"]:
			if channel["target"]["path"] != "scale":
				continue
			node = doc["nodes"][channel["target"]["node"]]
			rest = node.get("scale", [1.0, 1.0, 1.0])
			rows = read_accessor(doc, binary, anim["samplers"][channel["sampler"]]["output"])
			if any(abs(v - r) > SCALE_TOLERANCE for row in rows for v, r in zip(row, rest)):
				raise GroundRefused(f"{node.get('name')} is scaled away from its rest; repair the clip first")


def ground_lifts(lows: list[float], stands: bool) -> list[float]:
	"""Each key's world lift: its support's depth below the ground, or -- for a standing clip whose
	support never comes within GROUND_TOLERANCE_M of it -- the whole clip lowered by that gap."""
	if stands and min(lows) > GROUND_TOLERANCE_M:
		return [-min(lows)] * len(lows)
	return [max(0.0, -low) for low in lows]


# --- heading: an in-place clip faces the way the creature walks (decision 0201) --------------
#
# Meshy's idle stands turned about -43 deg from the walk, then swings the whole body through
# 72-92 deg of yaw and back (all ten creatures). The creature appears to spin on the spot, and every
# blend between walk and idle turns it about 50 deg. UNTWIST holds such a clip at the walk's heading:
#   - the Hips' yaw about the vertical is removed on every key, so the pelvis faces FORWARD_DEG;
#     everything above the hips (spine, arms, neck, head, tail) keeps its own motion;
#   - the feet are PINNED where they stand on the first key, turned to that heading, and the legs are
#     re-solved to reach them (two-bone IK, knee in the first key's bend plane);
#   - the hips stand over the rest pose's hips, as the walk's do (Meshy's idle stands up to 26 cm to one
#     side), at the clip's own height, lowered only where a leg would otherwise have to be straighter
#     than the clip ever holds it;
#   - the head gets a constant twist, so on the first key it too faces FORWARD_DEG: Meshy's idle looks
#     at the viewer with the body turned, and turning the body alone would leave it looking aside.

TWIST_SWING_DEG = 45.0     # an in-place clip whose Hips yaw ranges wider than this is untwisted
TWIST_NET_DEG = 10.0       # ...unless it ends further than this from where it began: it turns on purpose
FORWARD_DEG = 0.0          # +Z, glTF's front: the rest pose's facing and every travelling clip's direction
HEADING_TOLERANCE_DEG = 0.1
SLIDE_TOLERANCE_M = 0.001  # a pinned foot may move no further than this across the clip
LEG_REACH_MAX = 0.99       # a leg is never straighter than this share of its length, whatever the clip did
LEG_SIDES = ("Left", "Right")


def _basis(m: list) -> list[list[float]]:
	"""The rotation of a 4x4 column-major matrix, as three unit columns (a uniform scale divided out)."""
	columns = []
	for c in range(3):
		v = m[c * 4:c * 4 + 3]
		n = math.sqrt(sum(x * x for x in v))
		columns.append([x / n for x in v])
	return columns


def _apply(r: list, v: list) -> list[float]:
	"""A rotation (columns) applied to a vector."""
	return [r[0][i] * v[0] + r[1][i] * v[1] + r[2][i] * v[2] for i in range(3)]


def _compose(a: list, b: list) -> list[list[float]]:
	"""The rotation a @ b, as columns."""
	return [_apply(a, column) for column in b]


def _transpose(r: list) -> list[list[float]]:
	"""The inverse of a rotation."""
	return [[r[0][i], r[1][i], r[2][i]] for i in range(3)]


def _yaw(radians: float) -> list[list[float]]:
	"""The rotation by `radians` about the world vertical: +Z turns towards +X."""
	c, s = math.cos(radians), math.sin(radians)
	return [[c, 0.0, -s], [0.0, 1.0, 0.0], [s, 0.0, c]]


def _quat(r: list) -> list[float]:
	"""A rotation (columns) as a glTF quaternion (x, y, z, w)."""
	m = [[r[c][row] for c in range(3)] for row in range(3)]
	trace = m[0][0] + m[1][1] + m[2][2]
	if trace > 0.0:
		s = 2.0 * math.sqrt(trace + 1.0)
		return [(m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s, 0.25 * s]
	i = max(range(3), key=lambda d: m[d][d])
	j, k = (i + 1) % 3, (i + 2) % 3
	s = 2.0 * math.sqrt(1.0 + m[i][i] - m[j][j] - m[k][k])
	q = [0.0, 0.0, 0.0, (m[k][j] - m[j][k]) / s]
	q[i], q[j], q[k] = 0.25 * s, (m[j][i] + m[i][j]) / s, (m[k][i] + m[i][k]) / s
	return q


def _yaw_of(r: list) -> float:
	"""Degrees of the twist about the world vertical in a rotation (its swing-twist decomposition).
	Turning a rotation by a yaw adds exactly that yaw; a tilt adds none."""
	q = _quat(r)
	if math.hypot(q[1], q[3]) < 1e-6:
		raise GroundRefused("a Hips key is turned upside down; its heading is undefined")
	return math.degrees(2.0 * math.atan2(q[1], q[3]))


def _unwrap(degrees: list[float]) -> list[float]:
	"""A heading series made continuous across +-180 deg."""
	out = [degrees[0]]
	for d in degrees[1:]:
		out.append(d + 360.0 * round((out[-1] - d) / 360.0))
	return out


def _towards(a: list, b: list) -> list[list[float]]:
	"""The smallest rotation taking direction a onto direction b (Rodrigues)."""
	na, nb = math.sqrt(sum(x * x for x in a)), math.sqrt(sum(x * x for x in b))
	a, b = [x / na for x in a], [x / nb for x in b]
	axis = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
	c = sum(x * y for x, y in zip(a, b))
	if c < -0.999999:
		raise GroundRefused("a leg bone would have to reverse")
	k = 1.0 / (1.0 + c)
	x, y, z = axis
	return [[c + k * x * x, k * x * y + z, k * x * z - y], [k * x * y - z, c + k * y * y, k * y * z + x],
		[k * x * z + y, k * y * z - x, c + k * z * z]]


def hips_headings(doc: dict, binary: bytes) -> list[float]:
	"""The Hips' heading on every key, in degrees, unwrapped: the yaw of its world rotation away from
	its rest (the T-pose faces +Z, so 0 is facing +Z)."""
	hips, _channel = _hips(doc)
	rest = _basis(node_worlds(doc)[hips])
	times, animated = _channels(doc, binary)
	return _unwrap([_yaw_of(_compose(_basis(_worlds_at(doc, animated, k)[hips]), _transpose(rest))) for k in range(len(times))])


def _named(doc: dict, name: str, parent: int) -> int:
	"""The node called `name`, which must be a child of `parent`."""
	node = next((i for i, n in enumerate(doc["nodes"]) if n.get("name") == name), None)
	if node is None or node not in doc["nodes"][parent].get("children", []):
		raise GroundRefused(f"re-solving the legs needs {name} under {doc['nodes'][parent].get('name')}")
	return node


def _legs(doc: dict, hips: int) -> dict[str, tuple[int, int, int]]:
	"""Each side's (UpLeg, Leg, Foot) nodes, parented in a chain under the Hips."""
	legs = {}
	for side in LEG_SIDES:
		up = _named(doc, side + "UpLeg", hips)
		knee = _named(doc, side + "Leg", up)
		legs[side] = (up, knee, _named(doc, side + "Foot", knee))
	return legs


def _head(doc: dict, hips: int) -> tuple[int, int]:
	"""The Head node and its parent, which must descend from the Hips through neither leg."""
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	head = next((i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Head"), None)
	node = head
	while node is not None and node in parents and parents[node] != hips:
		node = parents[node]
	if head is None or node is None or parents.get(node) != hips or "Leg" in doc["nodes"][node].get("name", ""):
		raise GroundRefused("untwisting needs a Head above the Hips")
	return head, parents[head]


def _sub(a: list, b: list) -> list[float]:
	"""a - b for 3-vectors."""
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


def _dist(a: list, b: list) -> float:
	"""The distance between two points."""
	return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def _chain_lengths(worlds: list[dict], chain: tuple[int, int, int]) -> tuple[float, float, float]:
	"""A leg's thigh and shin lengths, and the most of their sum the clip ever straightens it to.
	Refuses a leg whose bones change length: the solve keeps each bone's length."""
	up, knee, foot = chain
	l1, l2 = _dist(worlds[0][up][12:15], worlds[0][knee][12:15]), _dist(worlds[0][knee][12:15], worlds[0][foot][12:15])
	for w in worlds:
		if abs(_dist(w[up][12:15], w[knee][12:15]) - l1) > 1e-5 or abs(_dist(w[knee][12:15], w[foot][12:15]) - l2) > 1e-5:
			raise GroundRefused("a leg bone changes length during the clip")
	straightest = max(_dist(w[up][12:15], w[foot][12:15]) for w in worlds) / (l1 + l2)
	return l1, l2, min(LEG_REACH_MAX, straightest) * (l1 + l2)


def _hip_drop(hip: list, foot: list, reach: float) -> float:
	"""How far the hip joint must come down for the foot to be within `reach` of it."""
	h = math.hypot(hip[0] - foot[0], hip[2] - foot[2])
	if h >= reach:
		raise GroundRefused("a pinned foot is beyond its leg's reach")
	return max(0.0, (hip[1] - foot[1]) - math.sqrt(reach * reach - h * h))


def _solve_leg(hip: list, foot: list, l1: float, l2: float, pole: list) -> list[float]:
	"""Where the knee goes: l1 from the hip, l2 from the foot, bent towards `pole`."""
	d = _dist(hip, foot)
	u = [x / d for x in _sub(foot, hip)]
	along = sum(p * q for p, q in zip(pole, u))
	w = [p - along * q for p, q in zip(pole, u)]
	n = math.sqrt(sum(x * x for x in w))
	if n < 1e-9:
		raise GroundRefused("a leg is straight on the first key; its knee has no direction")
	cos_a = max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)))
	sin_a = math.sqrt(1.0 - cos_a * cos_a)
	return [hip[i] + l1 * (cos_a * u[i] + sin_a * w[i] / n) for i in range(3)]


def _write_channel(doc: dict, binary: bytes, node: int, path: str, rows: list, times_index: int) -> bytes:
	"""Key `node`'s `path` with `rows` on the clip's full timeline, as a new LINEAR sampler."""
	anim = doc["animations"][0]
	binary, output = append_accessor(doc, binary, rows, 5126, "VEC4" if path == "rotation" else "VEC3")
	anim["samplers"].append({"input": times_index, "output": output, "interpolation": "LINEAR"})
	channel = next((c for c in anim["channels"] if c["target"] == {"node": node, "path": path}), None)
	if channel is None:
		anim["channels"].append({"sampler": len(anim["samplers"]) - 1, "target": {"node": node, "path": path}})
	else:
		channel["sampler"] = len(anim["samplers"]) - 1
	return binary


def _quats(rotations: list) -> list[tuple]:
	"""Rotations as quaternions, each on the same side as the one before, so LINEAR keys never flip."""
	out: list[tuple] = []
	for r in rotations:
		q = _quat(r)
		if out and sum(a * b for a, b in zip(q, out[-1])) < 0.0:
			q = [-c for c in q]
		out.append(tuple(q))
	return out


def untwist(doc: dict, binary: bytes) -> tuple[bytes, dict]:
	"""Hold an in-place clip whose Hips swing round at the walk's heading (see the section comment).
	Returns the new BIN and a report; a clip that does not swing, travels, or turns for good is untouched."""
	hips, _channel = _hips(doc)
	headings = hips_headings(doc, binary)
	report = {"heading_swing_deg": round(max(headings) - min(headings), 2), "heading_net_deg": round(headings[-1] - headings[0], 2)}
	times, animated = _channels(doc, binary)
	worlds = [_worlds_at(doc, animated, k) for k in range(len(times))]
	if (max(headings) - min(headings) <= TWIST_SWING_DEG or abs(headings[-1] - headings[0]) > TWIST_NET_DEG
			or extract_root(times, [[w[hips][12], w[hips][14]] for w in worlds]) is not None):
		return binary, {**report, "untwisted": False}
	legs, (head, neck) = _legs(doc, hips), _head(doc, hips)
	turn0 = _yaw(math.radians(FORWARD_DEG - headings[0]))
	stand = node_worlds(doc)[hips][12:15]
	plan = {side: _plan_leg(worlds, chain, hips, turn0, stand) for side, chain in legs.items()}
	keys = {node: [] for node in (hips, head) + tuple(n for chain in legs.values() for n in chain)}
	positions, drops = [], []
	parent_rest = _parent_rotation(doc, hips)
	for k, w in enumerate(worlds):
		turn = _yaw(math.radians(FORWARD_DEG - headings[k]))
		hips_rot = _compose(turn, _basis(w[hips]))
		hip_joints = {side: [a + b for a, b in zip([stand[0], w[hips][13], stand[2]], _apply(turn, _sub(w[up][12:15], w[hips][12:15])))]
			for side, (up, _knee, _foot) in legs.items()}
		drop = max(_hip_drop(hip_joints[side], plan[side]["pin"], plan[side]["reach"]) for side in legs)
		drops.append(drop)
		positions.append([stand[0], w[hips][13] - drop, stand[2]])
		keys[hips].append(_compose(_transpose(parent_rest), hips_rot))
		for side, chain in legs.items():
			hip = [hip_joints[side][0], hip_joints[side][1] - drop, hip_joints[side][2]]
			for node, rotation in zip(chain, _solve_leg_keys(plan[side], hip, hips_rot)):
				keys[node].append(rotation)
		keys[head].append(_compose(_transpose(_basis(w[neck])), _basis(w[head])))
	gaze = FORWARD_DEG - (_yaw_of(_compose(_compose(turn0, _basis(worlds[0][head])), _transpose(_basis(node_worlds(doc)[head])))))
	neck0 = _compose(turn0, _basis(worlds[0][neck]))
	fix = _compose(_compose(_transpose(neck0), _yaw(math.radians(gaze))), neck0)
	keys[head] = [_compose(fix, r) for r in keys[head]]
	binary = _write_untwist(doc, binary, hips, keys, positions)
	_check_pins(doc, binary, {legs[side][2]: plan[side]["pin"] for side in legs})
	return binary, {**report, "untwisted": True, "turned_deg": round(FORWARD_DEG - headings[0], 2), "gaze_deg": round(gaze, 2),
		"hips_drop_max_m": round(max(drops), 4), "feet_slide_before_m": round(_slide(worlds, legs), 4)}


def _plan_leg(worlds: list[dict], chain: tuple[int, int, int], hips: int, turn0: list, stand: list) -> dict:
	"""One leg's first key, turned to the walk's heading about the hips and moved over the rest hips:
	where its foot is pinned, the knee's bend direction, the thigh's and shin's rotations and directions,
	and the bones' lengths and reach."""
	up, knee, foot = chain
	w = worlds[0]
	moved = _apply(turn0, _sub(w[foot][12:15], w[hips][12:15]))
	l1, l2, reach = _chain_lengths(worlds, chain)
	thigh_dir = _apply(turn0, _sub(w[knee][12:15], w[up][12:15]))
	return {"pin": [stand[0] + moved[0], w[foot][13], stand[2] + moved[2]], "pin_rotation": _compose(turn0, _basis(w[foot])),
		"pole": thigh_dir, "thigh": (thigh_dir, _compose(turn0, _basis(w[up]))),
		"shin": (_apply(turn0, _sub(w[foot][12:15], w[knee][12:15])), _compose(turn0, _basis(w[knee]))),
		"l1": l1, "l2": l2, "reach": reach}


def _solve_leg_keys(plan: dict, hip: list, hips_rot: list) -> tuple[list, list, list]:
	"""The UpLeg, Leg and Foot local rotations that put the foot on its pin from this hip joint: each
	bone is the first key's, swung the least way onto its new direction."""
	knee_at = _solve_leg(hip, plan["pin"], plan["l1"], plan["l2"], plan["pole"])
	thigh = _compose(_towards(plan["thigh"][0], _sub(knee_at, hip)), plan["thigh"][1])
	shin = _compose(_towards(plan["shin"][0], _sub(plan["pin"], knee_at)), plan["shin"][1])
	return (_compose(_transpose(hips_rot), thigh), _compose(_transpose(thigh), shin),
		_compose(_transpose(shin), plan["pin_rotation"]))


def _write_untwist(doc: dict, binary: bytes, hips: int, keys: dict, positions: list) -> bytes:
	"""Write every rewritten rotation, and the Hips translation, on the clip's full timeline."""
	times_index = rotation_time_accessor(doc)
	for node, rotations in keys.items():
		binary = _write_channel(doc, binary, node, "rotation", _quats(rotations), times_index)
	return _write_channel(doc, binary, hips, "translation", [tuple(_hips_local(doc, hips, p)) for p in positions], times_index)


def _check_pins(doc: dict, binary: bytes, pins: dict[int, list]) -> None:
	"""Refuse unless every foot, posed from the rewritten keys, is on its pin on every key -- in all three
	axes, before any lift (the output check after grounding sees only the ground plane)."""
	times, animated = _channels(doc, binary)
	for k in range(len(times)):
		worlds = _worlds_at(doc, animated, k)
		for foot, pin in pins.items():
			miss = _dist(worlds[foot][12:15], pin)
			if miss > SLIDE_TOLERANCE_M:
				raise GroundRefused(f"{doc['nodes'][foot].get('name')} misses its pin by {miss:.4f} m on key {k}")


def _parent_rotation(doc: dict, node: int) -> list[list[float]]:
	"""The rest world rotation of `node`'s parent (identity at the scene root)."""
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	return _basis(node_worlds(doc)[parents[node]]) if node in parents else _yaw(0.0)


def _hips_local(doc: dict, hips: int, world: list) -> list[float]:
	"""The Hips-local translation that puts the hips at the world point `world`."""
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	origin = node_worlds(doc)[parents[hips]][12:15] if hips in parents else [0.0, 0.0, 0.0]
	return world_in_parent_space(doc, hips, _sub(world, origin))


def feet_slide(doc: dict, binary: bytes) -> float:
	"""The furthest either foot joint moves across the ground from where it stands on the first key."""
	hips, _channel = _hips(doc)
	times, animated = _channels(doc, binary)
	return _slide([_worlds_at(doc, animated, k) for k in range(len(times))], _legs(doc, hips))


def _slide(worlds: list[dict], legs: dict) -> float:
	"""The furthest any leg's foot moves horizontally from its first-key position."""
	feet = [chain[2] for chain in legs.values()]
	return max(math.hypot(w[f][12] - worlds[0][f][12], w[f][14] - worlds[0][f][14]) for w in worlds for f in feet)


# --- feet: a planted foot stays where it is planted (decision 0202) -----------------------------
#
# Meshy's clips let a planted foot drift across the ground: up to 9 cm while the creature crouches to
# collect an object, 13 cm while it pulls a radish, 3 cm while a mole sits; 1-9 cm in a stance of the walk,
# the run and the carry walks. PIN holds each such foot still for as long as it is planted, with 0201's IK:
#   - a foot's CONTACT POINT is its lowest skinned vertex, on that key. A foot that rolls from heel to toe
#     has its contact point still; one that slides moves it. Its SLIP is how far that vertex moves to the
#     next key, less the ground's own motion;
#   - a foot is PLANTED, in a clip that stands in place, while its contact point is within
#     CONTACT_HEIGHT_M of the ground. A step lifts it: each landing starts a new contact, which is kept
#     where the clip puts it. Only the drift within a contact is taken out;
#   - in a GAIT (GAIT_CLIPS: the walk, the run, the carry walks) a foot is planted while it moves with the
#     ground, slower than STANCE_SPEED_FRACTION of the gait's speed, for MIN_STANCE_KEYS keys. Meshy's gaits
#     drag the swinging foot along the ground and hold the planted one up to 22 cm above it, so height
#     cannot tell them apart. An in-place gait's ground moves back at the gait's own speed, found from its
#     planted feet and recorded on the Hips (`gait`); a travelling one's ground is still, as its root has
#     not yet been extracted;
#   - a contact whose foot strays more than PIN_SLIDE_M from where it is held is PINNED: the foot is moved
#     across the ground by exactly its accumulated slip, keeping its height and world rotation, and the
#     thigh and shin are re-solved in that key's own bend plane. Where a leg cannot reach, the hips come
#     down (at most PIN_DROP_MAX_M, eased). Between contacts, in the air, the move eases out and back in.
#     The loop's first and last keys keep one pose;
#   - a contact the leg cannot reach, or whose pin would move what the clip stands on (a kneeling knee) by
#     more than PIN_SUPPORT_TOLERANCE_M, is left as it is and reported in `unpinned`, with that reason.

CONTACT_HEIGHT_M = 0.02      # a standing foot this close to the ground is planted
PIN_SLIDE_M = 0.02           # a contact whose foot strays further than this across the ground is pinned
STANCE_SPEED_FRACTION = 0.5  # in a gait, a foot moving with the ground slower than this share of the gait's speed is planted
MIN_STANCE_KEYS = 3          # ...for at least this many keys
PIN_TOLERANCE_M = 0.002      # a pinned foot, posed from the rewritten keys, may stray no further than this
PIN_PASSES = 4               # the IK moves the ankle exactly; a sole vertex partly on the shin needs a pass or two more
GAIT_CLIPS = ("anim_walk", "anim_run", "anim_carry_heavy_object_walk", "anim_carry_water_bucket_walk")
GAIT_ITERATIONS = 50
GAIT_SEEDS = (0.8, 0.9, 1.0, 1.1, 1.2)   # times the median backward speed
PIN_DROP_MAX_M = 0.03        # the hips may come down this far for a leg to reach its pinned foot
DROP_EASE_KEYS = 4           # ...eased in and out over this many keys either side
PIN_SUPPORT_TOLERANCE_M = 0.01   # pinning may move what the clip stands on by half the contact height, no more
PIN_EASE_S = 0.25            # between contacts further apart than twice this, a pin eases out and in over this long


def _skin_point(mats: list, joints: tuple, weights: tuple, v: tuple) -> tuple[float, float, float]:
	"""The skinned position of one vertex."""
	x = y = z = 0.0
	for j, w in zip(joints, weights):
		if w > 0.0:
			m = mats[j]
			x += w * (m[0] * v[0] + m[4] * v[1] + m[8] * v[2] + m[12])
			y += w * (m[1] * v[0] + m[5] * v[1] + m[9] * v[2] + m[13])
			z += w * (m[2] * v[0] + m[6] * v[1] + m[10] * v[2] + m[14])
	return x, y, z


def foot_points(doc: dict, binary: bytes) -> tuple[list[float], dict[str, list[list[tuple]]]]:
	"""The clip's timeline and, for each side with a foot, the skinned position on every key of every vertex
	whose strongest influence is that side's Foot or ToeBase."""
	skin, names, ibm, pos, jnt, wgt = _skinning(doc, binary)
	feet: dict[str, list[int]] = {}
	for v in range(len(jnt)):
		strongest = names[jnt[v][max(range(4), key=lambda q: wgt[v][q])]]
		for side in LEG_SIDES:
			if strongest in (side + "Foot", side + "ToeBase"):
				feet.setdefault(side, []).append(v)
	times, animated = _channels(doc, binary)
	points: dict[str, list[list[tuple]]] = {side: [] for side in feet}
	for k in range(len(times)):
		worlds = _worlds_at(doc, animated, k)
		mats = [mat_mul(worlds[node], list(ibm[s])) for s, node in enumerate(skin["joints"])]
		for side, verts in feet.items():
			points[side].append([_skin_point(mats, jnt[v], wgt[v], pos[v]) for v in verts])
	return times, points


def _lowest(points: list[tuple]) -> int:
	"""The index of the lowest of a key's foot points: the foot's contact point."""
	return min(range(len(points)), key=lambda p: points[p][1])


def foot_slips(times: list[float], points: list[list[tuple]], ground: list[list[float]]) -> list[list[float]]:
	"""Per step between keys: how far the foot's contact point moves across the ground (x, z), less the
	ground's own motion over that step (`ground[i]`)."""
	slips = []
	for i in range(len(times) - 1):
		low = _lowest(points[i])
		a, b = points[i][low], points[i + 1][low]
		slips.append([b[0] - a[0] - ground[i][0], b[2] - a[2] - ground[i][1]])
	return slips


def gait_speed(times: list[float], feet: list[list[list[tuple]]]) -> float:
	"""An in-place gait's own ground speed: the speed v at which its planted feet -- those moving with a ground
	going back at v, slower than STANCE_SPEED_FRACTION of v -- move back on average. Found by iterating from
	seeds about the median backward speed of its feet; where more than one v holds (a run's short stance can
	settle two ways), the one nearest that median."""
	moves = []
	for points in feet:
		moves += [(s[0], s[1], times[i + 1] - times[i]) for i, s in enumerate(foot_slips(times, points, [[0.0, 0.0]] * len(times)))]
	backward = sorted(-dz / dt for _dx, dz, dt in moves if dz < 0.0)
	if not backward:
		raise GroundRefused("an in-place gait whose feet never move back has no ground speed")
	median = backward[len(backward) // 2]
	settled = [v for v in (_settle(moves, median * seed) for seed in GAIT_SEEDS) if v is not None]
	if not settled:
		raise GroundRefused("an in-place gait's ground speed does not settle")
	return min(settled, key=lambda v: abs(v - median))


def _settle(moves: list[tuple], speed: float) -> float | None:
	"""Iterate a gait speed from `speed` until its planted feet's mean backward speed is itself, or None."""
	for _ in range(GAIT_ITERATIONS):
		planted = [(dz, dt) for dx, dz, dt in moves if math.hypot(dx, dz + speed * dt) < STANCE_SPEED_FRACTION * speed * dt]
		if not planted:
			return None
		new = -sum(dz for dz, _dt in planted) / sum(dt for _dz, dt in planted)
		if abs(new - speed) < 1e-7:
			return new
		speed = new
	return None


def _runs(flags: list[bool]) -> list[tuple[int, int]]:
	"""The (first, last) indices of every run of True."""
	runs, k = [], 0
	while k < len(flags):
		if flags[k]:
			j = k
			while j + 1 < len(flags) and flags[j + 1]:
				j += 1
			runs.append((k, j))
			k = j + 1
		else:
			k += 1
	return runs


def contacts(times: list[float], slips: list[list[float]], heights: list[float], gait_ref: float | None) -> list[tuple[int, int]]:
	"""The (first key, last key) of every contact. Standing (`gait_ref` None): the contact point is within
	CONTACT_HEIGHT_M of the ground. In a gait: the foot moves with the ground at less than
	STANCE_SPEED_FRACTION of `gait_ref`, for at least MIN_STANCE_KEYS keys."""
	if gait_ref is None:
		return _runs([h <= CONTACT_HEIGHT_M for h in heights])
	planted = [math.hypot(*s) < STANCE_SPEED_FRACTION * gait_ref * (times[i + 1] - times[i]) for i, s in enumerate(slips)]
	return [(a, b + 1) for a, b in _runs(planted) if b + 2 - a >= MIN_STANCE_KEYS]


def _drift(slips: list[list[float]], a: int, b: int) -> list[list[float]]:
	"""The contact point's accumulated slip at each key of the contact [a, b], from 0 at a."""
	acc, out = [0.0, 0.0], [[0.0, 0.0]]
	for i in range(a, b):
		acc = [acc[0] + slips[i][0], acc[1] + slips[i][1]]
		out.append(list(acc))
	return out


def contact_slide(times: list[float], slips: list[list[float]], runs: list[tuple[int, int]]) -> float:
	"""The furthest any contact's foot strays from where the pin would hold it: where it lands; the loop's
	seam, for a contact touching it; for one spanning the whole clip, less the straight ramp that closes the
	loop (which the pin keeps, so the seam never moves)."""
	return max((math.hypot(*h) for a, b in runs for h in _held(times, _drift(slips, a, b), a, b, _anchors(len(times), a, b)[0])),
		default=0.0)


def loop_ramp(times: list[float], slips: list[list[float]], runs: list[tuple[int, int]]) -> float:
	"""How far a contact spanning the whole clip ends from where it began: the ramp the pin leaves in it."""
	return max((math.hypot(*_drift(slips, a, b)[-1]) for a, b in runs if (a, b) == (0, len(times) - 1)), default=0.0)


def _held(times: list[float], drift: list[list[float]], a: int, b: int, anchor: int) -> list[list[float]]:
	"""The moves that hold a contact's foot where it is on key `anchor`; a contact spanning the whole clip is
	held at both ends, less a straight ramp that closes the loop."""
	n = len(times)
	if a == 0 and b == n - 1:
		span = times[b] - times[a]
		return [[-(d[i] - (times[a + j] - times[a]) / span * drift[-1][i]) for i in range(2)] for j, d in enumerate(drift)]
	at = drift[anchor - a]
	return [[at[0] - d[0], at[1] - d[1]] for d in drift]


def _anchors(n: int, a: int, b: int) -> list[int]:
	"""The keys a contact may be held at, in order of preference: where it lands; the loop's seam, if it
	touches it (the seam never moves); else, only if the landing cannot be reached, any of its keys."""
	if b == n - 1:
		return [b]
	if a == 0:
		return [a]
	return [a] + list(range(a + 1, b + 1))


def _hold_within_reach(times: list[float], drift: list[list[float]], a: int, b: int, drop) -> list[list[float]] | None:
	"""The moves holding a drifting contact still: where it lands, if the leg reaches every key from there as it
	stands; else at whichever of its anchors (see _anchors) needs the hips lowered least, if that is within
	PIN_DROP_MAX_M; else None."""
	anchors = _anchors(len(times), a, b)
	def worst(option: list[list[float]]) -> float:
		return max(drop(a + j, h) for j, h in enumerate(option))
	landing = _held(times, drift, a, b, anchors[0])
	if worst(landing) == 0.0:
		return landing
	best = min((_held(times, drift, a, b, anchor) for anchor in anchors), key=worst)
	return best if worst(best) <= PIN_DROP_MAX_M else None


def pin_corrections(times: list[float], slips: list[list[float]], runs: list[tuple[int, int]], drop=None,
		threshold: float = PIN_SLIDE_M, eligible: list | None = None, keep: tuple | list = ()) -> tuple[list[list[float]], list[tuple[int, int]], list[tuple[int, int]]]:
	"""Per key, the (x, z) move that holds each drifting contact's foot still; the contacts pinned; and the
	drifting contacts left as they are because the leg cannot reach where they would be held.

	A contact drifts when its foot strays more than `threshold` from where it would be held (contact_slide);
	only `eligible` contacts (default all) are pinned, and never one in `keep`. `drop(k, move)` is how far the hips must come down on
	key k for the leg to reach the foot moved (inf beyond its horizontal reach). In the air between contacts
	the move eases (smoothstep) from one contact's to the next's; where the leg cannot reach a key of that
	within PIN_DROP_MAX_M, the pinned contact nearest it is given up and the rest planned again."""
	drop = drop or (lambda k, move: 0.0)
	n = len(times)
	unreachable: list[tuple[int, int]] = []
	while True:
		moves: list = [None] * n
		pinned = []
		for a, b in runs:
			drift = _drift(slips, a, b)
			held = [[0.0, 0.0]] * len(drift)
			if ((a, b) not in unreachable and (a, b) not in keep and (eligible is None or (a, b) in eligible)
					and contact_slide(times, slips, [(a, b)]) > threshold):
				option = _hold_within_reach(times, drift, a, b, drop)
				if option is None:
					unreachable.append((a, b))
				else:
					held = option
					pinned.append((a, b))
			for j, h in enumerate(held):
				moves[a + j] = h
		_ease(times, moves)
		over = next((k for k in range(n) if drop(k, moves[k]) > PIN_DROP_MAX_M), None)
		if over is None:
			return moves, pinned, sorted(unreachable)
		unreachable.append(min(pinned, key=lambda r: r[0] - over if over < r[0] else over - r[1]))


def _ease(times: list[float], moves: list) -> None:
	"""Fill the keys between contacts (None), from and to nothing at the loop's seam. A gap no longer than
	2 * PIN_EASE_S eases (smoothstep) from one contact's move to the next's; a longer one -- a kneel, a sit --
	eases out over PIN_EASE_S after the first, holds nothing, and eases in over PIN_EASE_S before the next,
	so the pose between is the clip's own."""
	n = len(times)
	for seam in (0, n - 1):
		if moves[seam] is None:
			moves[seam] = [0.0, 0.0]
	fixed = [(k, moves[k]) for k in range(n) if moves[k] is not None]
	for (k0, m0), (k1, m1) in zip(fixed, fixed[1:]):
		t0, t1 = times[k0], times[k1]
		for k in range(k0 + 1, k1):
			if t1 - t0 <= 2.0 * PIN_EASE_S:
				moves[k] = _smoothstep(m0, m1, (times[k] - t0) / (t1 - t0))
			elif times[k] - t0 < PIN_EASE_S:
				moves[k] = _smoothstep(m0, [0.0, 0.0], (times[k] - t0) / PIN_EASE_S)
			elif t1 - times[k] < PIN_EASE_S:
				moves[k] = _smoothstep([0.0, 0.0], m1, 1.0 - (t1 - times[k]) / PIN_EASE_S)
			else:
				moves[k] = [0.0, 0.0]


def _smoothstep(m0: list[float], m1: list[float], u: float) -> list[float]:
	"""The move a share `u` of the way from m0 to m1, eased in and out."""
	s = u * u * (3.0 - 2.0 * u)
	return [m0[0] + (m1[0] - m0[0]) * s, m0[1] + (m1[1] - m0[1]) * s]


def _reach(worlds: list[dict], chain: tuple[int, int, int]):
	"""`reach(k)` for one leg: the most it may reach on key k -- LEG_REACH_MAX of its length, or the clip's own
	hip-to-ankle distance there if the clip already holds it straighter."""
	up, _knee, foot = chain
	l1, l2, _straightest = _chain_lengths(worlds, chain)
	return lambda k: max(LEG_REACH_MAX * (l1 + l2), _dist(worlds[k][up][12:15], worlds[k][foot][12:15]))


def leg_drop(worlds: list[dict], chain: tuple[int, int, int]):
	"""`drop(k, move)` for one leg: how far the hips must come down on key k for it to reach its ankle moved
	across the ground by `move` (0 if it reaches as it stands; inf if the move is beyond its horizontal reach)."""
	up, _knee, foot = chain
	reach = _reach(worlds, chain)
	def drop(k: int, move: list[float]) -> float:
		if move == [0.0, 0.0]:
			return 0.0
		hip, ankle = worlds[k][up][12:15], worlds[k][foot][12:15]
		try:
			return _hip_drop(hip, [ankle[0] + move[0], ankle[1], ankle[2] + move[1]], reach(k))
		except GroundRefused:
			return math.inf
	return drop


def smooth_drops(drops: list[float]) -> list[float]:
	"""The hips' drop eased in and out: each key the mean, over DROP_EASE_KEYS either side, of the largest drop
	within DROP_EASE_KEYS of that key -- never less than the key's own. The loop's two seam keys take the larger
	of theirs, so the loop still closes."""
	n, w = len(drops), DROP_EASE_KEYS
	peak = [max(drops[max(0, k - w):k + w + 1]) for k in range(n)]
	out = [sum(peak[max(0, k - w):k + w + 1]) / len(peak[max(0, k - w):k + w + 1]) for k in range(n)]
	out[0] = out[-1] = max(out[0], out[-1])
	return out


def _source_rotations(doc: dict, animated: dict, node: int, n: int) -> list[tuple]:
	"""A node's local rotation on every key of the timeline, as the clip has it."""
	rest = tuple(doc["nodes"][node].get("rotation", [0.0, 0.0, 0.0, 1.0]))
	return [tuple(q) for q in animated.get(node, {}).get("rotation", [rest] * n)]


def _pin_leg(doc: dict, worlds: list[dict], animated: dict, hips: int, chain: tuple[int, int, int], targets: list) -> list[list[tuple]]:
	"""The UpLeg, Leg and Foot rotation keys that put the ankle on `targets[k]` (a world point, or None to keep
	the clip's key exactly), keeping the foot's world rotation; the knee bends in that key's own plane."""
	up, knee, foot = chain
	l1, l2, _reach = _chain_lengths(worlds, chain)
	keys = [_source_rotations(doc, animated, node, len(worlds)) for node in chain]
	for k, w in enumerate(worlds):
		if targets[k] is None:
			continue
		hip, ankle = w[up][12:15], w[foot][12:15]
		thigh_dir = _sub(w[knee][12:15], hip)
		plan = {"pin": targets[k], "pin_rotation": _basis(w[foot]), "pole": thigh_dir, "thigh": (thigh_dir, _basis(w[up])),
			"shin": (_sub(ankle, w[knee][12:15]), _basis(w[knee])), "l1": l1, "l2": l2}
		for column, rotation in zip(keys, _solve_leg_keys(plan, hip, _basis(w[hips]))):
			q = _quat(rotation)
			if k > 0 and sum(a * b for a, b in zip(q, column[k - 1])) < 0.0:
				q = [-c for c in q]      # on the previous key's side, so LINEAR keys never flip
			column[k] = tuple(q)
	return keys


def _ground_motion(doc: dict, binary: bytes, times: list[float], gait: bool, feet: dict) -> tuple[list[list[float]], float | None, float | None]:
	"""Per step, how far the ground moves under the clip (x, z); the in-place gait's own speed (else None);
	and the speed a gait's planted feet are judged against (else None, a standing clip)."""
	still = [[0.0, 0.0]] * len(times)
	if not gait:
		return still, None, None
	travel = extract_root(times, root_path(doc, binary)[1])
	if travel is not None:
		return still, None, math.hypot(*travel[-1]) / (times[-1] - times[0])
	speed = gait_speed(times, list(feet.values()))
	return [[0.0, -speed * (times[i + 1] - times[i])] for i in range(len(times) - 1)] + [[0.0, 0.0]], speed, speed


def _foot_contacts(doc: dict, binary: bytes, stands: bool, gait: bool) -> dict:
	"""Everything the pin needs about a clip's feet: the timeline, the ground's own motion, the in-place gait
	speed (or None), and each side's slips and contacts."""
	times, feet = foot_points(doc, binary)
	ground, speed, reference = _ground_motion(doc, binary, times, gait, feet)
	lows = lowest_support(doc, binary)[1]
	floor = [-lift for lift in ground_lifts(lows, stands)]
	sides = {}
	for side, points in feet.items():
		slips = foot_slips(times, points, ground)
		sides[side] = (slips, contacts(times, slips, [points[k][_lowest(points[k])][1] - floor[k] for k in range(len(times))], reference))
	return {"times": times, "ground": ground, "speed": speed, "sides": sides, "lows": lows}


def _worlds(doc: dict, binary: bytes) -> tuple[dict, list[dict]]:
	"""The clip's sampled channels, and every node's world matrix on every key."""
	times, animated = _channels(doc, binary)
	return animated, [_worlds_at(doc, animated, k) for k in range(len(times))]


def _targets(worlds: list[dict], foot: int, moves: list, drops: list[float]) -> list:
	"""Each key's ankle target: the ankle moved across the ground by that key's move, or None where neither the
	foot moves nor the hips drop (the key is kept exactly)."""
	return [None if moves[k] == [0.0, 0.0] and drops[k] == 0.0 else
		[w[foot][12] + moves[k][0], w[foot][13], w[foot][14] + moves[k][1]] for k, w in enumerate(worlds)]


def pin_feet(doc: dict, binary: bytes, stands: bool, gait: bool) -> tuple[bytes, dict]:
	"""Hold every drifting planted foot still (see the section comment). Returns the new BIN and a report; a
	clip whose contacts all stay within PIN_SLIDE_M is untouched. A drifting contact is left as it is, and
	reported in `unpinned` with its reason, when the leg cannot reach to hold it even with the hips lowered
	PIN_DROP_MAX_M ("reach"), or when holding it would move what the clip stands on -- a kneeling knee --
	by more than PIN_SUPPORT_TOLERANCE_M ("support"): the lift that follows would raise or lower the whole
	creature with it, and the pinned foot off the ground."""
	hips, _channel = _hips(doc)
	feet = _foot_contacts(doc, binary, stands, gait)
	saved, original = copy.deepcopy(doc), binary
	kept: dict[str, list] = {side: [] for side in feet["sides"]}
	while True:
		plans, drops, report = _plan_pins(doc, binary, hips, feet, kept, gait)
		if not plans:
			return original, report
		binary = _apply_pins(doc, original, hips, feet, plans, drops)
		moved = next((k for k, (a, b) in enumerate(zip(feet["lows"], lowest_support(doc, binary)[1])) if abs(a - b) > PIN_SUPPORT_TOLERANCE_M), None)
		if moved is None:
			return binary, report
		side, run = _support_culprit(saved, original, doc, binary, moved, plans)
		kept[side].append(run)
		doc.clear()
		doc.update(copy.deepcopy(saved))


def _lowest_support_side(doc: dict, binary: bytes, k: int) -> tuple[float, str | None]:
	"""On key k: the height of the lowest support vertex, and the side (Left, Right) of the joint it is weighted
	to most -- None for a joint of neither side."""
	skin, names, ibm, pos, jnt, wgt = _skinning(doc, binary)
	_times, animated = _channels(doc, binary)
	worlds = _worlds_at(doc, animated, k)
	mats = [mat_mul(worlds[node], list(ibm[s])) for s, node in enumerate(skin["joints"])]
	heights = {v: _skin(mats, jnt[v], wgt[v], pos[v]) for v in support_vertices(names, jnt, wgt)}
	lowest = min(heights, key=heights.get)
	strongest = names[jnt[lowest][max(range(4), key=lambda q: wgt[lowest][q])]]
	return heights[lowest], next((side for side in LEG_SIDES if strongest.startswith(side)), None)


def _support_culprit(saved: dict, original: bytes, doc: dict, binary: bytes, moved: int, plans: dict) -> tuple[str, tuple[int, int]]:
	"""The pinned contact to give up when pinning moved the support on key `moved`: one on the side of the leg
	that moved it -- the side of the new lowest point if it sank, of the old one if that rose -- nearest the key."""
	before, after = _lowest_support_side(saved, original, moved), _lowest_support_side(doc, binary, moved)
	side = after[1] if after[0] < before[0] else before[1]
	candidates = [(s, run) for s, (pinned, _moves) in plans.items() for run in pinned if s == side]
	candidates = candidates or [(s, run) for s, (pinned, _moves) in plans.items() for run in pinned]
	return min(candidates, key=lambda sr: max(sr[1][0] - moved, moved - sr[1][1], 0))


def _plan_pins(doc: dict, binary: bytes, hips: int, feet: dict, kept: dict, gait: bool) -> tuple[dict, list[float], dict]:
	"""Each side's pinned contacts and moves, the hips' drop per key, and the report, leaving `kept` alone."""
	times = feet["times"]
	report: dict = {"gait": gait, "contacts": 0, "contacts_pinned": 0, "contact_slide_before_m": 0.0, "pin_max_m": 0.0,
		"pin_hips_drop_m": 0.0, "loop_ramp_m": 0.0, "unpinned": [],
		"contact_keys": {side: [list(r) for r in runs] for side, (_s, runs) in feet["sides"].items()}}
	if feet["speed"] is not None:
		report["gait_speed_m_s"] = round(feet["speed"], 4)
	_animated, worlds = _worlds(doc, binary)
	plans, drops = {}, [0.0] * len(times)
	for side, (slips, runs) in feet["sides"].items():
		drop = leg_drop(worlds, _legs(doc, hips)[side]) if contact_slide(times, slips, runs) > PIN_SLIDE_M else None
		moves, pinned, unreachable = pin_corrections(times, slips, runs, drop, keep=kept[side])
		report["contacts"] += len(runs)
		report["contacts_pinned"] += len(pinned)
		report["unpinned"] += [{"side": side, "keys": list(r), "slide_m": round(contact_slide(times, slips, [r]), 4), "reason": reason}
			for reason, rs in (("reach", unreachable), ("support", kept[side])) for r in rs]
		report["contact_slide_before_m"] = max(report["contact_slide_before_m"], round(contact_slide(times, slips, runs), 4))
		report["loop_ramp_m"] = max(report["loop_ramp_m"], round(loop_ramp(times, slips, runs), 4))
		report["pin_max_m"] = max(report["pin_max_m"], round(max(math.hypot(*m) for m in moves), 4))
		if pinned:
			plans[side] = (pinned, moves)
			drops = [max(d, drop(k, moves[k])) for k, d in enumerate(drops)]
	drops = smooth_drops(drops) if max(drops) > 0.0 else drops
	report["pin_hips_drop_m"] = round(max(drops), 4)
	return plans, drops, report


def _apply_pins(doc: dict, binary: bytes, hips: int, feet: dict, plans: dict, drops: list[float]) -> bytes:
	"""Write the pins: one pass that lowers the hips and re-solves the legs, then up to PIN_PASSES - 1 more
	for what a sole vertex weighted partly to the shin leaves; then check every pinned contact holds."""
	times = feet["times"]
	legs = _legs(doc, hips)
	_animated, worlds = _worlds(doc, binary)
	binary = _pin_pass(doc, binary, hips, legs, worlds, {side: plans.get(side, (None, [[0.0, 0.0]] * len(times)))[1] for side in legs}, drops)
	pinned_runs = {side: pinned for side, (pinned, _moves) in plans.items()}
	for _pass in range(PIN_PASSES - 1):
		residual = _residual_moves(doc, binary, feet, pinned_runs)
		if not residual:
			break
		binary = _pin_pass(doc, binary, hips, legs, _worlds(doc, binary)[1], residual, [0.0] * len(times))
	_check_pinned(doc, binary, feet["ground"], pinned_runs)
	return binary


def _pin_pass(doc: dict, binary: bytes, hips: int, legs: dict, worlds: list[dict], moves: dict[str, list], drops: list[float]) -> bytes:
	"""Lower the hips by `drops`, then re-solve each leg so its ankle is where it was on `worlds` (before the
	drop), moved by that side's `moves`. Legs with nothing to do on a key keep it exactly."""
	times_index = rotation_time_accessor(doc)
	targets = {side: _targets(worlds, legs[side][2], moves[side], drops) for side in moves}
	if max(drops) > 0.0:
		binary = apply_lift(doc, binary, times_index, _channels(doc, binary)[0], [-d for d in drops])
	animated, lowered = _worlds(doc, binary)
	for side, side_targets in targets.items():
		if all(target is None for target in side_targets):
			continue
		for node, rows in zip(legs[side], _pin_leg(doc, lowered, animated, hips, legs[side], side_targets)):
			binary = _write_channel(doc, binary, node, "rotation", rows, times_index)
	return binary


def _residual_moves(doc: dict, binary: bytes, feet: dict, pinned_runs: dict) -> dict[str, list]:
	"""After a pass: per side, the moves still needed to hold its pinned contacts, where a foot strays more
	than a quarter of PIN_TOLERANCE_M (a sole vertex weighted partly to the shin does not move with the ankle
	exactly); {} when none does."""
	times, points = foot_points(doc, binary)
	residual = {}
	for side, pinned in pinned_runs.items():
		slips = foot_slips(times, points[side], feet["ground"])
		moves, again, _unreachable = pin_corrections(times, slips, feet["sides"][side][1], None, PIN_TOLERANCE_M / 4.0, pinned)
		if again:
			residual[side] = moves
	return residual


def _check_pinned(doc: dict, binary: bytes, ground: list, pinned: dict[str, list]) -> None:
	"""Refuse unless every pinned contact, posed from the rewritten keys, now stays within PIN_TOLERANCE_M."""
	times, feet = foot_points(doc, binary)
	for side, runs in pinned.items():
		slips = foot_slips(times, feet[side], ground)
		for a, b in runs:
			slide = contact_slide(times, slips, [(a, b)])
			if slide > PIN_TOLERANCE_M:
				raise GroundRefused(f"the {side} foot still slides {slide:.4f} m in its contact at keys {a}-{b}")


def waterline_report(doc: dict, binary: bytes, medium: str) -> dict:
	"""Check a water clip against the waterline on every key, and report its margins; refuse a clip that
	breaks its medium's rule (WATER_CLIPS). Surface: the Head joint above y = 0 and the Hips joint below it.
	Submerged: every skinned vertex below it, but a chained tail's: the spring moves those, and the bake
	checks where it takes them (bake_meshy_tail.py, decision 0203)."""
	if medium not in ("surface", "submerged"):
		raise GroundRefused(f"unknown water medium {medium!r}")
	hips, _channel = _hips(doc)
	head = next((i for i, n in enumerate(doc["nodes"]) if n.get("name") == "Head"), None)
	if head is None:
		raise GroundRefused("a water clip needs a Head to hold against the waterline")
	skin, names, ibm, pos, jnt, wgt = _skinning(doc, binary)
	body = [v for v in range(len(pos)) if not names[jnt[v][max(range(4), key=lambda q: wgt[v][q])]].startswith("tail_")]
	times, animated = _channels(doc, binary)
	head_low, hips_high, top = math.inf, -math.inf, -math.inf
	for k in range(len(times)):
		worlds = _worlds_at(doc, animated, k)
		head_low, hips_high = min(head_low, worlds[head][13]), max(hips_high, worlds[hips][13])
		if medium == "submerged":
			mats = [mat_mul(worlds[node], list(ibm[s])) for s, node in enumerate(skin["joints"])]
			top = max(top, max(_skin_point(mats, jnt[v], wgt[v], pos[v])[1] for v in body))
	if medium == "surface" and not (head_low > WATERLINE_Y_M and hips_high < WATERLINE_Y_M):
		raise GroundRefused(f"a surface clip must hold the Head above the waterline and the Hips below it "
			f"(Head as low as {head_low:+.4f} m, Hips as high as {hips_high:+.4f} m)")
	if medium == "submerged" and top >= WATERLINE_Y_M:
		raise GroundRefused(f"a submerged clip breaks the surface: its highest point reaches {top:+.4f} m")
	report = {"water": medium, "head_min_y_m": round(head_low, 4), "hips_max_y_m": round(hips_high, 4)}
	return report | ({"body_max_y_m": round(top, 4)} if medium == "submerged" else {})


def _water_clip(doc: dict, binary: bytes, data: bytes, medium: str) -> tuple[bytes, dict]:
	"""A water clip (WATER_CLIPS): nothing about the ground applies -- no lift, seat, pin or untwist. Its
	travel, if any, is taken out as a walk's is (decision 0195), and it is checked against the waterline."""
	original = binary
	headings = hips_headings(doc, binary)
	times, lows = lowest_support(doc, binary)
	roots = extract_root(times, root_path(doc, binary)[1])
	binary = apply_lift(doc, binary, rotation_time_accessor(doc), times, [0.0] * len(times), roots)
	if roots is not None:
		_record_root_motion(doc, times, roots)
	doc["asset"].setdefault("extras", {})[STAMP] = {"version": STAMP_VERSION, "max_lift_m": 0.0, "root_motion": roots is not None,
		"water": medium, "source_sha256": hashlib.sha256(data).hexdigest()}
	out = write_glb(doc, binary)
	out_doc, out_binary = read_glb(out)
	if not out_binary.startswith(original):
		raise GroundRefused("original BIN data did not survive intact")
	_after_times, after = lowest_support(out_doc, out_binary)
	if roots is None and any(abs(a - b) > 1e-5 for a, b in zip(lows, after)):
		raise GroundRefused("an in-place water clip moved")
	return out, {**_root_report(out_doc, out_binary, roots), "keys": len(times), "keys_lifted": 0, "max_lift_m": 0.0,
		"seated_m": 0.0, "support_min_before_m": round(min(lows), 4), "support_min_after_m": round(min(after), 4),
		"support_max_after_m": round(max(after), 4), "heading_swing_deg": round(max(headings) - min(headings), 2),
		"heading_net_deg": round(headings[-1] - headings[0], 2), "untwisted": False, "contacts": 0, "contacts_pinned": 0,
		"contact_slide_before_m": 0.0, "contact_slide_after_m": 0.0, "unpinned": [],
		**waterline_report(out_doc, out_binary, medium)}


def ground_clip(data: bytes, stands: bool = True, gait: bool = False, water: str | None = None) -> tuple[bytes, dict]:
	"""Ground one clip -- hold it at the walk's heading if it swings round, pin its planted feet, lift it
	out of the ground, or seat it if it stands and floats -- and verify by re-skinning the output. A water
	clip (`water` is its medium) is instead checked against the waterline (_water_clip)."""
	doc, binary = read_glb(data)
	if STAMP in doc.get("asset", {}).get("extras", {}):
		raise GroundRefused("already grounded; ground the source, not an output")
	if not doc.get("animations"):
		raise GroundRefused("the file has no animation to ground")
	refuse_stray_scale(doc, binary)
	if water is not None:
		return _water_clip(doc, binary, data, water)
	original = binary
	binary, twist = untwist(doc, binary)
	binary, pins = pin_feet(doc, binary, stands, gait)
	times, lows = lowest_support(doc, binary)
	lifts = ground_lifts(lows, stands)
	roots = extract_root(times, root_path(doc, binary)[1])
	binary = apply_lift(doc, binary, rotation_time_accessor(doc), times, lifts, roots)
	if roots is not None:
		_record_root_motion(doc, times, roots)
	stamp = {"version": STAMP_VERSION, "max_lift_m": round(max(lifts), 4), "root_motion": roots is not None,
		"source_sha256": hashlib.sha256(data).hexdigest()}
	if twist["untwisted"]:
		stamp["untwisted"] = {k: twist[k] for k in ("turned_deg", "gaze_deg", "hips_drop_max_m")} | {"decision": "0201"}
	if pins["contacts_pinned"]:
		stamp["pinned"] = {"contacts": pins["contacts_pinned"], "max_move_m": pins["pin_max_m"], "decision": "0202"}
	if "gait_speed_m_s" in pins:
		_record_gait(doc, times, pins["gait_speed_m_s"])
	doc["asset"].setdefault("extras", {})[STAMP] = stamp
	out = write_glb(doc, binary)
	out_doc, out_binary = read_glb(out)
	if not out_binary.startswith(original):
		raise GroundRefused("original BIN data did not survive intact")
	_after_times, after = lowest_support(out_doc, out_binary)
	if min(after) < -GROUND_TOLERANCE_M:
		raise GroundRefused(f"after grounding the support still reaches {min(after):+.4f} m")
	if stands and min(after) > GROUND_TOLERANCE_M:
		raise GroundRefused(f"a standing clip still floats {min(after):.4f} m above the ground")
	if any(lift == 0.0 and abs(a - b) > 1e-5 for lift, a, b in zip(lifts, lows, after)):
		raise GroundRefused("a key that needed no lift moved")
	if twist["untwisted"]:
		twist |= _untwist_report(out_doc, out_binary)
	pins |= _pin_report(out_doc, out_binary, pins.get("gait_speed_m_s"), roots, pins)
	return out, {**_root_report(out_doc, out_binary, roots), "keys": len(times), "keys_lifted": sum(1 for x in lifts if x > 0.0),
		"max_lift_m": round(max(lifts), 4), "seated_m": round(max(0.0, -min(lifts)), 4), "support_min_before_m": round(min(lows), 4),
		"support_min_after_m": round(min(after), 4), "support_max_after_m": round(max(after), 4), **twist, **pins}


def _record_gait(doc: dict, times: list[float], speed: float) -> None:
	"""Onto an in-place gait's Hips extras (Godot imports them as bone metadata): the speed its planted feet
	move back at. The game moves the creature at that speed, or plays the clip at ground_speed / speed_m_s."""
	hips, _channel = _hips(doc)
	period = times[-1] - times[0]
	doc["nodes"][hips].setdefault("extras", {})["gait"] = {"speed_m_s": round(speed, 5), "period_s": round(period, 5),
		"stride_m": round(speed * period, 5), "decision": "0202"}


def ground_scrape(slips: list[list[float]], heights: list[float], runs: list[tuple[int, int]]) -> float:
	"""The furthest a foot travels across the ground outside its contacts, within CONTACT_HEIGHT_M of it:
	a gait's swinging foot dragged along the ground. Reported, not corrected."""
	inside = {i for a, b in runs for i in range(a, b)}
	worst = run = 0.0
	for i, slip in enumerate(slips):
		if i not in inside and heights[i] <= CONTACT_HEIGHT_M and heights[i + 1] <= CONTACT_HEIGHT_M:
			run += math.hypot(*slip)
			worst = max(worst, run)
		else:
			run = 0.0
	return worst


def _pin_report(doc: dict, binary: bytes, speed: float | None, roots: list | None, pins: dict) -> dict:
	"""Read back from the written clip, on the ground it plays on (moving back at the gait's speed, or by the
	extracted root): how far the foot still strays in each contact the pin found, and how far a gait drags a
	foot along the ground outside them. Refuses a contact still sliding past PIN_SLIDE_M, unless the pin
	reported it could not reach it (`unpinned`)."""
	times, feet = foot_points(doc, binary)
	if roots is not None:
		ground = [[roots[i][0] - roots[i + 1][0], roots[i][1] - roots[i + 1][1]] for i in range(len(times) - 1)]
	else:
		ground = [[0.0, -(speed or 0.0) * (times[i + 1] - times[i])] for i in range(len(times) - 1)]
	slide = scrape = 0.0
	for side, points in feet.items():
		slips = foot_slips(times, points, ground)
		runs = [tuple(r) for r in pins["contact_keys"].get(side, [])]
		left = [tuple(u["keys"]) for u in pins["unpinned"] if u["side"] == side]
		for run in runs:
			held = contact_slide(times, slips, [run])
			slide = max(slide, held)
			if held > PIN_SLIDE_M + PIN_TOLERANCE_M and run not in left:
				raise GroundRefused(f"after pinning the {side} foot still slides {held:.4f} m at keys {run[0]}-{run[1]}")
		scrape = max(scrape, ground_scrape(slips, [points[k][_lowest(points[k])][1] for k in range(len(times))], runs))
	return {"contact_slide_after_m": round(slide, 4), **({"ground_scrape_m": round(scrape, 4)} if pins.get("gait") else {})}


def _untwist_report(doc: dict, binary: bytes) -> dict:
	"""Read back from the written clip: the Hips hold FORWARD_DEG on every key and the feet stay put."""
	headings = hips_headings(doc, binary)
	off = max(abs(h - FORWARD_DEG) for h in headings)
	if off > HEADING_TOLERANCE_DEG:
		raise GroundRefused(f"after untwisting the hips still turn {off:.2f} deg from the walk's heading")
	slide = feet_slide(doc, binary)
	if slide > SLIDE_TOLERANCE_M:
		raise GroundRefused(f"after untwisting a foot still slides {slide:.4f} m")
	return {"heading_off_after_deg": round(off, 3), "feet_slide_after_m": round(slide, 4)}



def _record_root_motion(doc: dict, times: list[float], roots: list[list[float]]) -> None:
	"""Onto the Hips node's extras (Godot imports them as bone metadata): the root path per key, the
	loop's travel and period, and its mean speed -- what gameplay needs to move the creature."""
	hips, _channel = _hips(doc)
	period = times[-1] - times[0]
	travel = roots[-1]
	doc["nodes"][hips].setdefault("extras", {})["root_motion"] = {
		"period_s": round(period, 5), "travel_m": [round(travel[0], 5), round(travel[1], 5)],
		"mean_speed_m_s": round(math.hypot(*travel) / period, 5), "window_s": ROOT_WINDOW_S,
		"keys_xz": [[round(r[0], 5), round(r[1], 5)] for r in roots]}


def _root_report(doc: dict, binary: bytes, roots: list[list[float]] | None) -> dict:
	"""Read back from the written clip: how far the hips still travel over the loop (the loop's gap)."""
	_times, path = root_path(doc, binary)
	gap = math.hypot(path[-1][0] - path[0][0], path[-1][1] - path[0][1])
	if roots is not None and gap > ROOT_MOTION_MIN_M:
		raise GroundRefused(f"the clip still travels {gap:.3f} m after its root was extracted")
	return {"root_travel_m": round(math.hypot(*roots[-1]), 4) if roots else 0.0, "loop_gap_m": round(gap, 4)}


def _source_dir(key_dir: pathlib.Path) -> pathlib.Path:
	"""tailed/ where the creature has a tail chain, else repaired/."""
	return key_dir / "tailed" if (key_dir / "tailed").is_dir() else key_dir / "repaired"


def stands(path: str) -> bool:
	"""Whether the clip file at `path` stands, and so must touch the ground: all but OFF_THE_GROUND and WATER_CLIPS."""
	return pathlib.Path(path).stem not in OFF_THE_GROUND and pathlib.Path(path).stem not in WATER_CLIPS


def water_medium(path: str) -> str | None:
	"""The medium of the clip file at `path` if it is played in water (WATER_CLIPS), else None."""
	return WATER_CLIPS.get(pathlib.Path(path).stem)


def is_gait(path: str) -> bool:
	"""Whether the clip file at `path` is a gait, whose planted feet are found by their speed: GAIT_CLIPS."""
	return pathlib.Path(path).stem in GAIT_CLIPS


def _ground_one(job: tuple[str, str, bool]) -> dict:
	"""Worker: ground one clip file and, unless dry-running, write it."""
	source, target, dry_run = job
	data = pathlib.Path(source).read_bytes()
	out, row = ground_clip(data, stands(source), is_gait(source), water_medium(source))
	if not dry_run:
		pathlib.Path(target).write_bytes(out)
	path = pathlib.Path(source)
	return {"key": path.parent.parent.name, "clip": path.stem, "source": path.parent.name,
		"output_sha256": hashlib.sha256(out).hexdigest(), **row}


def ground_library(library: pathlib.Path, dry_run: bool) -> list[dict]:
	"""Ground every rigged creature's clips, in parallel; copy each rigged.glb alongside."""
	jobs = []
	for key_dir in sorted(p for p in library.iterdir() if (p / "repaired").is_dir()):
		source = _source_dir(key_dir)
		if not dry_run:
			(key_dir / "grounded").mkdir(exist_ok=True)
			(key_dir / "grounded" / "rigged.glb").write_bytes((source / "rigged.glb").read_bytes())
		jobs += [(str(p), str(key_dir / "grounded" / p.name), dry_run) for p in sorted(source.glob("anim_*.glb"))]
	with concurrent.futures.ProcessPoolExecutor() as pool:
		return list(pool.map(_ground_one, jobs))


def main() -> int:
	"""Ground the library and write the manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
	parser.add_argument("--dry-run", action="store_true")
	args = parser.parse_args()
	try:
		rows = ground_library(args.library, args.dry_run)
	except RepairRefused as refused:
		print(f"ground_meshy_clips: REFUSED -- {refused}")
		return 1
	for r in rows:
		print(f"  {r['key']:18} {r['clip']:30} support {r['support_min_before_m']:+.4f} -> {r['support_min_after_m']:+.4f}"
			f"  lift up to {r['max_lift_m']:.3f} m on {r['keys_lifted']}/{r['keys']} keys")
	for r in (r for r in rows if r["untwisted"]):
		print(f"  untwisted {r['key']:18} {r['clip']:12} swing {r['heading_swing_deg']:5.1f} deg, turned {r['turned_deg']:+.1f}, "
			f"gaze {r['gaze_deg']:+.1f}, hips down up to {r['hips_drop_max_m']:.3f} m, feet slide {r['feet_slide_before_m']:.3f} -> {r['feet_slide_after_m']:.3f} m")
	for r in (r for r in rows if r.get("water")):
		print(f"  water     {r['key']:18} {r['clip']:30} {r['water']:9} head down to {r['head_min_y_m']:+.3f} m, hips up to "
			f"{r['hips_max_y_m']:+.3f} m" + (f", body up to {r['body_max_y_m']:+.3f} m" if "body_max_y_m" in r else ""))
	for r in (r for r in rows if r["contacts_pinned"]):
		print(f"  pinned    {r['key']:18} {r['clip']:30} {r['contacts_pinned']}/{r['contacts']} contacts, slide "
			f"{r['contact_slide_before_m']:.3f} -> {r['contact_slide_after_m']:.3f} m, moved up to {r['pin_max_m']:.3f} m")
	print(f"ground_meshy_clips: {len(rows)} clips; {sum(1 for r in rows if r['keys_lifted'])} lifted; "
		f"largest lift {max(r['max_lift_m'] for r in rows):.3f} m; {sum(1 for r in rows if r['untwisted'])} untwisted; "
		f"widest swing left alone {max((r['heading_swing_deg'] for r in rows if not r['untwisted']), default=0.0):.1f} deg; "
		f"{sum(1 for r in rows if r['contacts_pinned'])} with planted feet pinned; "
		f"worst planted slide {max(r['contact_slide_before_m'] for r in rows):.3f} -> {max(r['contact_slide_after_m'] for r in rows):.3f} m")
	if not args.dry_run:
		args.manifest.write_text(json.dumps({"tool": "tools/ground_meshy_clips.py", "decision": "0193",
			"support_joints": list(SUPPORT_JOINTS), "ground_tolerance_m": GROUND_TOLERANCE_M,
			"untwist": {"decision": "0201", "swing_deg": TWIST_SWING_DEG, "net_turn_deg": TWIST_NET_DEG, "forward_deg": FORWARD_DEG},
			"pin": {"decision": "0202", "contact_height_m": CONTACT_HEIGHT_M, "pin_slide_m": PIN_SLIDE_M,
				"stance_speed_fraction": STANCE_SPEED_FRACTION, "min_stance_keys": MIN_STANCE_KEYS, "gait_clips": list(GAIT_CLIPS)},
			"water": {"decision": "0203", "waterline_y_m": WATERLINE_Y_M, "clips": WATER_CLIPS},
			"count": len(rows), "clips": rows}, indent=1) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
