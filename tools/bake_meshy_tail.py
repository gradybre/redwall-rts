#!/usr/bin/env python3
"""Bake the tail spring into every clip, for the crowd tier, and check tails against the ground.

Decision 0192. The crowd plays baked clips (crowd architecture §9), so the tail chain added
by tools/rig_meshy_tail.py (decision 0191) only moves there if its motion is written into
each clip. This runs Godot's own SpringBoneSimulator3D headless over every tailed clip --
the same simulator the skeletal pool uses at runtime, so both tiers move alike -- and
appends the recorded tail rotations to the clip as ordinary glTF rotation channels, on the
clip's own 30 Hz key times. Output: <key>/baked/anim_*.glb.

GROUND CHECK. The spring collides with the plane the creature stands on, using each tail
segment's measured surface radius (the tail_NN node's extras.spring_radius_m). Whether the
TAIL SURFACE actually stays above that plane -- or above the feet or tail base, where the clip
itself sinks them (`ground_verdict`) -- is checked independently: `ground_report` skins
the tail's vertices itself, frame by frame, from the file's node hierarchy, animation keys,
inverse binds and weights -- no Godot, no simulator -- and reports the lowest point reached,
beside the lowest point of the feet as the reference.

    python3 tools/bake_meshy_tail.py            # bake every tailed creature, then check
    python3 tools/bake_meshy_tail.py --check    # only check the existing baked/ files
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import math
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from repair_meshy_rig import RepairRefused, read_glb, write_glb  # noqa: E402
from rig_meshy_tail import append_accessor, mat_mul, read_accessor, trs_matrix  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library/creature"
CONFIG = ROOT / "docs/art-reference/asset_library/tail_centrelines.json"
MANIFEST = ROOT / "docs/art-reference/asset_library/baked.json"
GODOT_SCRIPT = pathlib.Path(__file__).resolve().parent / "godot/bake_tail_spring.gd"
TAIL_BONES = 8
STAMP = "redwall_tail_bake"
GROUND_TOLERANCE_M = 0.005     # tail surface may dip this far below the plane and still pass
TIME_TOLERANCE_S = 1e-4
MAX_STEP_DEG = 90.0             # a tail joint turning further than this in one 30 Hz frame is reported
GODOT_TIMEOUT_S = 1800


class BakeRefused(RepairRefused):
	"""A bake or check this tool must not accept, with the reason."""


# --- Godot -------------------------------------------------------------------------------

def run_godot(args: list[str], expect: str) -> str:
	"""Run Godot and demand its own success line: an exit code of 0 proves nothing here."""
	proc = subprocess.run(["godot", *args], capture_output=True, text=True, timeout=GODOT_TIMEOUT_S)
	if expect not in proc.stdout:
		tail = (proc.stdout + proc.stderr)[-1500:]
		raise BakeRefused(f"godot did not report {expect!r}; last output:\n{tail}")
	return proc.stdout


def simulate(key_dir: pathlib.Path, spring: dict, radii: list[float], clips: list[str]) -> dict:
	"""Build a throwaway project with the creature's tailed clips, import, and run the bake."""
	with tempfile.TemporaryDirectory(prefix="tailbake_") as tmp:
		project = pathlib.Path(tmp)
		(project / "glb").mkdir()
		(project / "project.godot").write_text('config_version=5\n\n[application]\nconfig/name="tail bake"\n')
		for clip in clips:
			shutil.copyfile(key_dir / "tailed" / f"{clip}.glb", project / "glb" / f"{clip}.glb")
		shutil.copyfile(GODOT_SCRIPT, project / "bake.gd")
		spec = project / "spec.json"
		spec.write_text(json.dumps({"spring": spring, "radii": radii, "clips": clips,
			"times": {c: clip_times(key_dir / "tailed" / f"{c}.glb") for c in clips},
			"floor": {c: clip_floor(key_dir / "tailed" / f"{c}.glb") for c in clips}}))
		subprocess.run(["godot", "--headless", "--path", str(project), "--editor", "--quit"],
			capture_output=True, timeout=GODOT_TIMEOUT_S)
		missing = [c for c in clips if not (project / "glb" / f"{c}.glb.import").exists()]
		if missing:
			raise BakeRefused(f"Godot imported nothing for {missing}; the bake would read empty scenes")
		out = project / "out.json"
		run_godot(["--headless", "--path", str(project), "--script", "bake.gd", "--", str(spec), str(out)],
			"[bake] done")
		return json.loads(out.read_text())


def clip_times(path: pathlib.Path) -> list[float]:
	"""The clip's own key times, from the file -- what the bake must step and be written on."""
	doc, binary = read_glb(path.read_bytes())
	return [row[0] for row in read_accessor(doc, binary, rotation_time_accessor(doc))]


# --- writing the keys --------------------------------------------------------------------

def spring_radii(doc: dict) -> list[float]:
	"""The measured surface radius on each tail_NN node, in chain order."""
	by_name = {n.get("name"): n for n in doc["nodes"]}
	try:
		return [by_name[f"tail_{i:02d}"]["extras"]["spring_radius_m"] for i in range(TAIL_BONES)]
	except KeyError as missing:
		raise BakeRefused(f"no measured radius on the chain ({missing}); re-run rig_meshy_tail.py") from None


def rotation_time_accessor(doc: dict) -> int:
	"""The clip's full timeline: the LINEAR rotation input with the most keys.

	Meshy compresses a channel that never changes to two keys (start and end) on a timeline of
	its own, and one of those is a rotation. The first rotation channel is therefore not the
	clip's timeline; the longest one is.
	"""
	anim = doc["animations"][0]
	inputs = {anim["samplers"][c["sampler"]]["input"] for c in anim["channels"]
		if c["target"]["path"] == "rotation"
		and anim["samplers"][c["sampler"]].get("interpolation", "LINEAR") == "LINEAR"}
	if not inputs:
		raise BakeRefused("the clip has no LINEAR rotation channel to share a timeline with")
	return max(inputs, key=lambda i: doc["accessors"][i]["count"])


def write_keys(data: bytes, baked: dict) -> bytes:
	"""Append one rotation channel per tail joint, on the clip's own time accessor."""
	doc, binary = read_glb(data)
	if STAMP in doc.get("asset", {}).get("extras", {}):
		raise BakeRefused("already baked; bake the tailed file, not an output")
	anim = doc["animations"][0]
	if any(doc["nodes"][c["target"]["node"]].get("name", "").startswith("tail_") for c in anim["channels"]):
		raise BakeRefused("the clip already animates a tail joint")
	times_index = rotation_time_accessor(doc)
	times = [row[0] for row in read_accessor(doc, binary, times_index)]
	if len(times) != len(baked["times"]) or any(abs(a - b) > TIME_TOLERANCE_S for a, b in zip(times, baked["times"])):
		raise BakeRefused("Godot's player was not at the clip's own key times when it recorded")
	if len(baked["rotations"]) != len(times):
		raise BakeRefused("the bake recorded a different number of frames than the clip has keys")
	original = binary
	nodes = {n.get("name"): i for i, n in enumerate(doc["nodes"])}
	for b in range(TAIL_BONES):
		rows = [tuple(_unit(frame[b])) for frame in baked["rotations"]]
		binary, output = append_accessor(doc, binary, rows, 5126, "VEC4")
		anim["samplers"].append({"input": times_index, "output": output, "interpolation": "LINEAR"})
		anim["channels"].append({"sampler": len(anim["samplers"]) - 1,
			"target": {"node": nodes[f"tail_{b:02d}"], "path": "rotation"}})
	doc["asset"].setdefault("extras", {})[STAMP] = {"version": 1, "frames": len(times),
		"source_sha256": hashlib.sha256(data).hexdigest()}
	out = write_glb(doc, binary)
	if not read_glb(out)[1].startswith(original):
		raise BakeRefused("original BIN data did not survive intact")
	return out


def _unit(q: list) -> list:
	"""Normalise a quaternion; refuse one that is not a rotation."""
	n = math.sqrt(sum(c * c for c in q))
	if not 0.99 < n < 1.01:
		raise BakeRefused(f"recorded rotation is not a unit quaternion (norm {n:.4f})")
	return [c / n for c in q]


def _angle(a: list, b: list) -> float:
	"""Degrees between two unit quaternions, either sign."""
	return math.degrees(2.0 * math.acos(min(1.0, abs(sum(x * y for x, y in zip(a, b))))))


def max_step_degrees(baked: dict) -> float:
	"""Largest turn of any tail joint between consecutive recorded frames."""
	frames = baked["rotations"]
	return max((_angle(a, b) for f in range(len(frames) - 1) for a, b in zip(frames[f], frames[f + 1])), default=0.0)


def seam_degrees(baked: dict) -> float:
	"""Largest tail-joint rotation jump between the last and first frame: the loop seam."""
	first, last = baked["rotations"][0], baked["rotations"][-1]
	worst = 0.0
	for a, b in zip(first, last):
		d = min(1.0, abs(sum(x * y for x, y in zip(a, b))))
		worst = max(worst, math.degrees(2.0 * math.acos(d)))
	return worst


# --- the independent ground check ---------------------------------------------------------

def _channels(doc: dict, binary: bytes) -> tuple[list[float], dict]:
	"""The clip's full timeline, and every animated node's T/R/S sampled on it.

	Channels keep their own key times (Meshy's constant channels have two), so each is sampled
	at every timeline time: STEP holds the previous key, LINEAR interpolates.
	"""
	anim = doc["animations"][0]
	times = [row[0] for row in read_accessor(doc, binary, rotation_time_accessor(doc))]
	values: dict = {}
	for channel in anim["channels"]:
		sampler = anim["samplers"][channel["sampler"]]
		keys = [row[0] for row in read_accessor(doc, binary, sampler["input"])]
		outs = read_accessor(doc, binary, sampler["output"])
		step = sampler.get("interpolation", "LINEAR") == "STEP"
		values.setdefault(channel["target"]["node"], {})[channel["target"]["path"]] = \
			[_sample(keys, outs, t, step, channel["target"]["path"] == "rotation") for t in times]
	return times, values


def _sample(keys: list[float], outs: list, t: float, step: bool, rotation: bool) -> list:
	"""One channel's value at time t: clamped at the ends, held (STEP) or blended (LINEAR)."""
	if t <= keys[0]:
		return list(outs[0])
	if t >= keys[-1]:
		return list(outs[-1])
	i = max(k for k in range(len(keys) - 1) if keys[k] <= t)
	if step:
		return list(outs[i])
	u = (t - keys[i]) / (keys[i + 1] - keys[i])
	a, b = outs[i], outs[i + 1]
	if rotation and sum(x * y for x, y in zip(a, b)) < 0.0:
		b = [-x for x in b]          # take the short way round
	v = [x + (y - x) * u for x, y in zip(a, b)]
	if rotation:
		n = math.sqrt(sum(c * c for c in v))
		v = [c / n for c in v]
	return v


def _worlds_at(doc: dict, animated: dict, k: int) -> dict[int, list]:
	"""World matrix of every node at key k: the node's own TRS, overridden by its channels."""
	identity = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0]
	worlds: dict = {}
	stack = [(n, identity) for n in doc["scenes"][doc.get("scene", 0)]["nodes"]]
	while stack:
		index, parent = stack.pop()
		node = dict(doc["nodes"][index])
		for path, rows in animated.get(index, {}).items():
			node[path] = list(rows[k])
		worlds[index] = mat_mul(parent, trs_matrix(node))
		stack.extend((c, worlds[index]) for c in doc["nodes"][index].get("children", []))
	return worlds


def _skin(m_list: list, joints: tuple, weights: tuple, v: tuple) -> float:
	"""The skinned Y of one vertex: the sum of each influence's matrix applied to it."""
	y = 0.0
	for j, w in zip(joints, weights):
		if w > 0.0:
			m = m_list[j]
			y += w * (m[1] * v[0] + m[5] * v[1] + m[9] * v[2] + m[13])
	return y


def _skinning(doc: dict, binary: bytes) -> tuple:
	"""Skin, joint names, inverse binds, and the mesh's positions, joints and weights."""
	skin = doc["skins"][0]
	names = [doc["nodes"][n].get("name", "") for n in skin["joints"]]
	ibm = read_accessor(doc, binary, skin["inverseBindMatrices"])
	prim = doc["meshes"][0]["primitives"][0]
	return (skin, names, ibm, read_accessor(doc, binary, prim["attributes"]["POSITION"]),
		read_accessor(doc, binary, prim["attributes"]["JOINTS_0"]), read_accessor(doc, binary, prim["attributes"]["WEIGHTS_0"]))


def _foot_vertices(names: list, jnt: list, wgt: list) -> list[int]:
	"""Every third vertex whose strongest influence is a foot or toe joint."""
	foot_slots = {s for s, n in enumerate(names) if "Foot" in n or "Toe" in n}
	return [v for v in range(len(jnt)) if jnt[v][max(range(4), key=lambda q: wgt[v][q])] in foot_slots][::3]


def clip_floor(path: pathlib.Path) -> list[float]:
	"""Per clip key, the spring's ground: y = 0, lowered only where the clip buries the tail's base.

	min(0, tail_00's height less its radius). Kneeling clips carry the base below the ground; with
	the plane left at 0 the chain started inside it, and a thin tail folded into hairpins. The
	FEET are deliberately not followed: Meshy's clips sink them 1-10 cm in most clips, and a plane
	following them took the tail down with them -- 27 of 60 clips then failed against y = 0,
	against 9 with the base alone. The tail keeps to the real ground wherever its base allows.
	"""
	doc, binary = read_glb(path.read_bytes())
	skin = doc["skins"][0]
	root = next(n for n in skin["joints"] if doc["nodes"][n].get("name") == "tail_00")
	root_radius = doc["nodes"][root].get("extras", {}).get("spring_radius_m", 0.0)
	times, animated = _channels(doc, binary)
	floors = []
	for k in range(len(times)):
		worlds = _worlds_at(doc, animated, k)
		floors.append(round(min(0.0, worlds[root][13] - root_radius), 5))
	return floors


def ground_report(data: bytes) -> dict:
	"""Lowest skinned Y reached by the tail's vertices, and by the feet, over every key of the clip."""
	doc, binary = read_glb(data)
	skin, names, ibm, pos, jnt, wgt = _skinning(doc, binary)
	tail_slots = {s for s, n in enumerate(names) if n.startswith("tail_")}
	tail_v = [v for v in range(len(pos)) if any(w > 0 and j in tail_slots for j, w in zip(jnt[v], wgt[v]))]
	foot_v = _foot_vertices(names, jnt, wgt)
	if not tail_v:
		raise BakeRefused("no vertex is weighted to a tail joint")
	times, animated = _channels(doc, binary)
	root = next(n for n in skin["joints"] if doc["nodes"][n].get("name") == "tail_00")
	root_radius = doc["nodes"][root].get("extras", {}).get("spring_radius_m", 0.0)
	tail_low, foot_low, root_low, worst_key = math.inf, math.inf, math.inf, 0
	for k in range(len(times)):
		worlds = _worlds_at(doc, animated, k)
		root_low = min(root_low, worlds[root][13])
		mats = [mat_mul(worlds[node], list(ibm[s])) for s, node in enumerate(skin["joints"])]
		low = min(_skin(mats, jnt[v], wgt[v], pos[v]) for v in tail_v)
		if low < tail_low:
			tail_low, worst_key = low, k
		foot_low = min(foot_low, min(_skin(mats, jnt[v], wgt[v], pos[v]) for v in foot_v))
	return {"tail_min_y_m": round(tail_low, 4), "feet_min_y_m": round(foot_low, 4),
		"root_floor_y_m": round(root_low - root_radius, 4),
		"worst_time_s": round(times[worst_key], 4), "tail_vertices": len(tail_v), "keys": len(times)}


def ground_verdict(tail_low: float, feet_low: float, root_floor: float) -> dict:
	"""Is the tail's lowest point acceptable? Judged only against what the spring controls.

	The spring moves tail_01..07; the CLIP places the tail's base. Two clip faults are therefore
	not the spring's, and lower the bar to match:
	- Meshy's clips sink the feet (1-10 cm even at idle; 34 cm in the squirrels' pull_radish);
	- crouching clips carry tail_00 so low that its own thickness (`root_floor`: the base's lowest
	  height minus its measured radius) is already in the ground.
	The tail may go no lower than the lowest of the ground, the feet and that base floor.
	Either fault is reported as `clip_below_ground`.
	"""
	floor = min(0.0, feet_low, root_floor)
	return {"ground_ok": tail_low >= floor - GROUND_TOLERANCE_M,
		"clip_below_ground": min(feet_low, root_floor) < -GROUND_TOLERANCE_M}


def _report_file(path: str) -> tuple[str, dict]:
	"""Worker: one file's ground report (run in parallel; pure Python skinning is slow)."""
	return path, ground_report(pathlib.Path(path).read_bytes())


# --- the batch ---------------------------------------------------------------------------

def bake_creature(key_dir: pathlib.Path, spring: dict) -> list[dict]:
	"""Simulate every tailed clip of one creature and write <key>/baked/."""
	radii = spring_radii(read_glb((key_dir / "tailed" / "rigged.glb").read_bytes())[0])
	clips = sorted(p.stem for p in (key_dir / "tailed").glob("anim_*.glb"))
	baked = simulate(key_dir, spring, radii, clips)
	(key_dir / "baked").mkdir(exist_ok=True)
	rows = []
	for clip in clips:
		if clip not in baked:
			raise BakeRefused(f"{key_dir.name}/{clip} was not baked")
		try:
			out = write_keys((key_dir / "tailed" / f"{clip}.glb").read_bytes(), baked[clip])
		except BakeRefused as refused:
			raise BakeRefused(f"{key_dir.name}/{clip}: {refused}") from None
		step = max_step_degrees(baked[clip])
		(key_dir / "baked" / f"{clip}.glb").write_bytes(out)
		rows.append({"key": key_dir.name, "clip": clip, "frames": len(baked[clip]["times"]),
			"seam_deg": round(seam_degrees(baked[clip]), 2), "max_step_deg": round(step, 2),
			"motion_ok": step <= MAX_STEP_DEG, "output_sha256": hashlib.sha256(out).hexdigest()})
	return rows


def check_ground(library: pathlib.Path, rows: list[dict]) -> list[dict]:
	"""Ground reports for every baked clip and its rigid (tailed, unbaked) twin, in parallel."""
	jobs = []
	for r in rows:
		key_dir = library / r["key"]
		jobs += [str(key_dir / "baked" / f"{r['clip']}.glb"), str(key_dir / "tailed" / f"{r['clip']}.glb")]
	with concurrent.futures.ProcessPoolExecutor() as pool:
		reports = dict(pool.map(_report_file, jobs))
	for r in rows:
		key_dir = library / r["key"]
		baked = reports[str(key_dir / "baked" / f"{r['clip']}.glb")]
		rigid = reports[str(key_dir / "tailed" / f"{r['clip']}.glb")]
		r.update({"tail_min_y_baked_m": baked["tail_min_y_m"], "tail_min_y_rigid_m": rigid["tail_min_y_m"],
			"feet_min_y_m": baked["feet_min_y_m"], "worst_time_s": baked["worst_time_s"],
			"root_floor_y_m": baked["root_floor_y_m"],
			**ground_verdict(baked["tail_min_y_m"], baked["feet_min_y_m"], baked["root_floor_y_m"])})
	return rows


def main() -> int:
	"""Bake every chained creature, check tails against the ground, and write the manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--config", type=pathlib.Path, default=CONFIG)
	parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
	parser.add_argument("--check", action="store_true", help="only check existing baked/ files")
	args = parser.parse_args()
	config = json.loads(args.config.read_text(encoding="utf-8"))
	rows: list[dict] = []
	try:
		for key, entry in sorted(config["chains"].items()):
			if args.check:
				rows += [{"key": key, "clip": p.stem} for p in sorted((args.library / key / "baked").glob("anim_*.glb"))]
			else:
				rows += bake_creature(args.library / key, entry["spring"])
				print(f"  baked {key}: {sum(1 for r in rows if r['key'] == key)} clips")
		rows = check_ground(args.library, rows)
	except RepairRefused as refused:
		print(f"bake_meshy_tail: REFUSED -- {refused}")
		return 1
	failing = [r for r in rows if not r["ground_ok"] or not r.get("motion_ok", True)]
	for r in rows:
		print(f"  {r['key']:18} {r['clip']:30} tail low {r['tail_min_y_baked_m']:+.4f} (rigid {r['tail_min_y_rigid_m']:+.4f})"
			f"  feet low {r['feet_min_y_m']:+.4f}  seam {r.get('seam_deg', '-')}  {'ok' if r['ground_ok'] else 'TAIL BELOW GROUND'}{'' if r.get('motion_ok', True) else '  MOTION: ' + str(r['max_step_deg']) + ' deg in one frame'}{'  (clip below ground)' if r['clip_below_ground'] else ''}")
	sinking = sum(1 for r in rows if r["clip_below_ground"])
	below = sum(1 for r in rows if not r["ground_ok"])
	jumps = sum(1 for r in rows if not r.get("motion_ok", True))
	print(f"bake_meshy_tail: {len(rows)} clips; {below} with the tail more than {GROUND_TOLERANCE_M * 1000:.0f} mm below "
		f"the ground, feet and tail base; {jumps} with a tail joint turning over {MAX_STEP_DEG:.0f} deg in one frame; "
		f"{sinking} clips put the feet or tail base below ground")
	if not args.check:
		args.manifest.write_text(json.dumps({"tool": "tools/bake_meshy_tail.py", "decision": "0192",
			"ground_tolerance_m": GROUND_TOLERANCE_M, "count": len(rows), "clips": rows}, indent=1) + "\n")
	return 1 if failing else 0


if __name__ == "__main__":
	sys.exit(main())
