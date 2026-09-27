#!/usr/bin/env python3
"""Lift Meshy's clips so the creature's support never goes below the ground. Decision 0193.

Every repaired bind pose stands exactly on y = 0, but Meshy's retargeted clips sink the feet:
1-10 cm at idle, 17 cm in the otter boatwright's walk, 35 cm in the squirrels' pull_radish.
This lifts the hips, key by key, by exactly as much as the lowest SUPPORT point is below the
ground -- max(0, -lowest) -- and never lowers them, so a run keeps its flight phase and a chair
clip keeps its seat height.

SUPPORT is every vertex whose strongest influence is a foot, toe or leg joint: the feet when
standing, the knees when kneeling. Arms are not support (they reach into the soil to dig or pull
a radish), nor is the body (a dress hem hangs; it does not bear weight), nor the tail (the
spring handles it, decision 0192).

Only the Hips translation keys change: they are rewritten on the clip's full timeline with the
lift added, as a new accessor appended to the BIN. Everything else survives byte for byte, and
the source BIN is an exact prefix of the output. The result is re-skinned independently and
refused unless every key's lowest support point is at or above -GROUND_TOLERANCE_M.

Source: <key>/tailed/ where the creature has a tail chain, else <key>/repaired/.
Output: <key>/grounded/ -- every clip, plus rigged.glb copied unchanged.

	python3 tools/ground_meshy_clips.py              # ground the whole creature library
	python3 tools/ground_meshy_clips.py --dry-run    # measure and report, write nothing
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from bake_meshy_tail import _channels, _sample, _skin, _skinning, _worlds_at, rotation_time_accessor  # noqa: E402
from repair_meshy_rig import RepairRefused, read_glb, write_glb  # noqa: E402
from rig_meshy_tail import append_accessor, mat_mul, node_worlds, read_accessor  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library/creature"
MANIFEST = ROOT / "docs/art-reference/asset_library/grounded.json"
STAMP = "redwall_clip_ground"
SUPPORT_JOINTS = ("Foot", "Toe", "Leg")
GROUND_TOLERANCE_M = 0.001


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


def lift_in_parent_space(doc: dict, hips: int) -> list[float]:
	"""The Hips-local translation that moves the hips 1 m straight up in the world."""
	parents = {c: i for i, n in enumerate(doc["nodes"]) for c in n.get("children", [])}
	if hips not in parents:
		return [0.0, 1.0, 0.0]
	m = node_worlds(doc)[parents[hips]]
	a, b, c = [m[0], m[1], m[2]], [m[4], m[5], m[6]], [m[8], m[9], m[10]]   # the parent's basis columns
	det = a[0] * (b[1] * c[2] - b[2] * c[1]) + a[1] * (b[2] * c[0] - b[0] * c[2]) + a[2] * (b[0] * c[1] - b[1] * c[0])
	if abs(det) < 1e-12:
		raise GroundRefused("the Hips parent's basis is singular")
	## Solve [a b c] x = (0, 1, 0). The inverse's rows are (b x c, c x a, a x b) / det, so x is their y
	## components. The basis may be scaled (Meshy's armature is 0.01) or rotated.
	return [(b[2] * c[0] - b[0] * c[2]) / det, (c[2] * a[0] - c[0] * a[2]) / det, (a[2] * b[0] - a[0] * b[2]) / det]


def apply_lift(doc: dict, binary: bytes, times_index: int, times: list[float], lifts: list[float]) -> bytes:
	"""Rewrite the Hips translation on the clip's full timeline, lifted by `lifts` (world metres) per key."""
	hips, channel = _hips(doc)
	anim = doc["animations"][0]
	sampler = anim["samplers"][channel["sampler"]]
	keys = [row[0] for row in read_accessor(doc, binary, sampler["input"])]
	values = read_accessor(doc, binary, sampler["output"])
	step = sampler.get("interpolation", "LINEAR") == "STEP"
	up = lift_in_parent_space(doc, hips)
	rows = []
	for t, lift in zip(times, lifts):
		v = _sample(keys, values, t, step, False)
		rows.append(tuple(v[i] + up[i] * lift for i in range(3)))
	binary, output = append_accessor(doc, binary, rows, 5126, "VEC3")
	anim["samplers"].append({"input": times_index, "output": output, "interpolation": "LINEAR"})
	channel["sampler"] = len(anim["samplers"]) - 1
	return binary


def ground_clip(data: bytes) -> tuple[bytes, dict]:
	"""Lift one clip so its support is never below the ground; verify by re-skinning the output."""
	doc, binary = read_glb(data)
	if STAMP in doc.get("asset", {}).get("extras", {}):
		raise GroundRefused("already grounded; ground the source, not an output")
	if not doc.get("animations"):
		raise GroundRefused("the file has no animation to ground")
	times, lows = lowest_support(doc, binary)
	lifts = [max(0.0, -low) for low in lows]
	original = binary
	binary = apply_lift(doc, binary, rotation_time_accessor(doc), times, lifts)
	doc["asset"].setdefault("extras", {})[STAMP] = {"version": 1, "max_lift_m": round(max(lifts), 4),
		"source_sha256": hashlib.sha256(data).hexdigest()}
	out = write_glb(doc, binary)
	out_doc, out_binary = read_glb(out)
	if not out_binary.startswith(original):
		raise GroundRefused("original BIN data did not survive intact")
	_after_times, after = lowest_support(out_doc, out_binary)
	if min(after) < -GROUND_TOLERANCE_M:
		raise GroundRefused(f"after grounding the support still reaches {min(after):+.4f} m")
	if any(lift == 0.0 and abs(a - b) > 1e-5 for lift, a, b in zip(lifts, lows, after)):
		raise GroundRefused("a key that needed no lift moved")
	return out, {"keys": len(times), "keys_lifted": sum(1 for x in lifts if x > 0.0),
		"max_lift_m": round(max(lifts), 4), "support_min_before_m": round(min(lows), 4),
		"support_min_after_m": round(min(after), 4), "support_max_after_m": round(max(after), 4)}


def _source_dir(key_dir: pathlib.Path) -> pathlib.Path:
	"""tailed/ where the creature has a tail chain, else repaired/."""
	return key_dir / "tailed" if (key_dir / "tailed").is_dir() else key_dir / "repaired"


def _ground_one(job: tuple[str, str, bool]) -> dict:
	"""Worker: ground one clip file and, unless dry-running, write it."""
	source, target, dry_run = job
	data = pathlib.Path(source).read_bytes()
	out, row = ground_clip(data)
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
	print(f"ground_meshy_clips: {len(rows)} clips; {sum(1 for r in rows if r['keys_lifted'])} lifted; "
		f"largest lift {max(r['max_lift_m'] for r in rows):.3f} m")
	if not args.dry_run:
		args.manifest.write_text(json.dumps({"tool": "tools/ground_meshy_clips.py", "decision": "0193",
			"support_joints": list(SUPPORT_JOINTS), "ground_tolerance_m": GROUND_TOLERANCE_M,
			"count": len(rows), "clips": rows}, indent=1) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
