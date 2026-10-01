#!/usr/bin/env python3
"""The underground pass's props with their known defects fixed, for the live demo. Decision 0371 (the underground
revamp's P7; decision 0204 lists the defects).

WHY. make_demo_props.py makes each library prop's plain L0 from its high-poly. For five of them the plain L0 cannot be
used as it is (the asset library README's "Underground revamp pass", Known problems):

  burrow_door_open   the burrow door is one solid piece, so it cannot open: its round LEAF is split from its FRAME
                     (the wall, ring and lintel), the leaf thinned to a door's thickness with its edge closed, so the
                     demo can swing it (burrow/door_swing.gd)
  tunnel_arch_open   the tunnel arch's doorway is filled by a solid dark slab, front and back: the slab is cut out, so
                     a tunnel passes through it
  hanging_stores_strung  the hanging stores' L0 is faceted lumps at 1,150 triangles: made at the furniture budget,
                     split into its bar and its five strings so a cellar's strings can show one by one as it fills
  hand_lantern_lit   the hand lantern's L0 warps its frame and mangles its candle at 1,150 triangles: made at the
                     furniture budget, its horn panes and candle a second material the demo lights from within
  large_bed          the large bed (decision 0211) was the bed stretched; this lengthens and widens the bed's own
                     model without stretching its quilt (the middle repeated, head- and footboards kept)

Each is made from the library high-poly (only ever read) by tools/demo_derived_blender.py -- the same decimation and
bake as make_demo_props.py -- into the gitignored godot/demo/assets/props/ (nothing derived from the library is
committed, decision 0188):

  props/<key>__<part>.glb   each part, rebased together (place every part with one transform)
  props/<key>.made.json     the job (stamped with both Blender scripts' SHA-256) and the source's SHA-256, so a re-run
                            remakes a key only when either changed

and returns one manifest row per key, with provenance: the source's path and SHA-256, the edits and why, every part's
path, bound and triangles, and the whole's bound (which sizes it; demo/props/demo_props.gd).

	python3 tools/make_demo_derived_props.py               # needs blender; merges the rows into the manifest
	python3 tools/make_demo_derived_props.py --only large_bed --force

stage_demo_assets.py calls this, so a full staging run already includes it. Without Blender the rows are left out and
the demo draws each one's stand-in (the plain L0, or a procedural one).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library"
OUT = ROOT / "godot/demo/assets"
TOOLS = pathlib.Path(__file__).resolve().parent
BLENDER_SCRIPTS = [TOOLS / "demo_derived_blender.py", TOOLS / "demo_props_blender.py"]
RES = "res://demo/assets"
JOBS = 3
DECISION = "0371"

## GAP-04's furniture family (lookdev_dimensions.gd FAMILY_TRIANGLE_CEILING L0): 2,000 triangles, 1,024 px maps. Every
## derived key stays inside it, its parts together.
FAMILY = "furniture_instance"
CEILING_TRIANGLES = 2000
CEILING_PX = 1024

## The burrow door's leaf, measured from its high-poly (glTF units): a disc round (x, y) of this radius, its faces
## within DOOR_LEAF_Z of the wall's middle plane (the front leaf at +0.11, the back at -0.11; the ring stands out at
## +-0.17, so it stays with the frame).
DOOR_LEAF = [0.016, -0.19, 0.448]
DOOR_LEAF_Z = 0.3
## The arch's slab: its two dark sheets (x +-0.367, from the base to y 0.339, at z +0.098 and 0) -- every face this
## dark inside this box.
ARCH_SLAB = {"box": [[-0.41, -0.8, -0.03], [0.41, 0.35, 0.13]], "dark": 0.08}
## The hanging stores: the bar (and its brackets and the strings' loops) above y 0.45; the strings by x, between the
## gaps measured in the high-poly's faces (onions, garlic, lavender, sage, marjoram, left to right).
STRING_EDGES = [-1.0, -0.56, -0.22, 0.13, 0.46, 1.0]

DERIVED = {
	"burrow_door_open": {"source": "prop/burrow_door/highpoly.glb", "texture_px": 1024, "parts": [
		{"name": "leaf", "budget": 560, "texture_px": 512,
			"region": {"cylinder": DOOR_LEAF, "box": [[-1.0, -1.0, -DOOR_LEAF_Z], [1.0, 1.0, DOOR_LEAF_Z]]},
			"thin": {"at": 0.0, "by": 0.14}, "rim": [0.02, 0.112]},
		{"name": "frame", "budget": 1340}]},
	"tunnel_arch_open": {"source": "prop/tunnel_arch/highpoly.glb", "texture_px": 1024, "drop": [ARCH_SLAB],
		"parts": [{"name": "arch", "budget": 1900}]},
	"hanging_stores_strung": {"source": "prop/hanging_stores/highpoly.glb", "texture_px": 512, "parts": [
		{"name": "bar", "budget": 520, "region": {"box": [[-1.0, 0.45, -1.0], [1.0, 1.0, 1.0]]}},
		*({"name": f"string{k}", "budget": 276,
			"region": {"box": [[STRING_EDGES[k], -1.0, -1.0], [STRING_EDGES[k + 1], 1.0, 1.0]]}} for k in range(5))]},
	"hand_lantern_lit": {"source": "prop/hand_lantern/highpoly.glb", "texture_px": 1024, "glow": True,
		"parts": [{"name": "lantern", "budget": 1900}]},
	## The bed is 1.24 x 1.9 units, drawn 1.6 m long (demo_props.gd): the large bed's 2.7 m (decision 0211) at that
	## scale is 3.21 units. Only its length is cut and filled: a cut down its length showed as a seam the length of the
	## quilt, so its width (1.04 m drawn, 0211's 1.2 m) is a plain scale (fixture_kit.gd LARGE_BED_M).
	"large_bed": {"source": "prop/bed/highpoly.glb", "texture_px": 1024, "stretch": [0.0, 1.31],
		"parts": [{"name": "bed", "budget": 1900}]},
}


def sha256(path: pathlib.Path) -> str:
	"""The file's SHA-256, streamed."""
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for block in iter(lambda: handle.read(1 << 20), b""):
			digest.update(block)
	return digest.hexdigest()


def part_glb(out: pathlib.Path, key: str, part: str) -> pathlib.Path:
	"""Where part `part` of derived key `key` is written."""
	return out / "props" / f"{key}__{part}.glb"


def job_for(library: pathlib.Path, out: pathlib.Path, key: str) -> dict:
	"""The Blender job for `key`, stamped with both Blender scripts' SHA-256 so a changed script remakes it."""
	spec = DERIVED[key]
	parts = [{**part, "glb": str(part_glb(out, key, part["name"]))} for part in spec["parts"]]
	job = {**spec, "key": key, "source": str(library / spec["source"]), "parts": parts}
	job["scripts_sha256"] = [sha256(script) for script in BLENDER_SCRIPTS]
	return job


## The longest one job may take (s): the slowest, the hanging stores in six parts, takes about two minutes.
BLENDER_TIMEOUT_S = 900


def run_blender(job: dict) -> dict:
	"""Run one job headless; return what it printed on its RESULT line."""
	blender = shutil.which("blender")
	if blender is None:
		raise RuntimeError("blender is not on PATH (see docs/ENVIRONMENT.md)")
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
		json.dump(job, handle)
	command = [blender, "--background", "--factory-startup", "--python", str(BLENDER_SCRIPTS[0]), "--", handle.name]
	try:
		done = subprocess.run(command, capture_output=True, text=True, timeout=BLENDER_TIMEOUT_S)
	finally:
		pathlib.Path(handle.name).unlink(missing_ok=True)
	for line in done.stdout.splitlines():
		if line.startswith("RESULT "):
			return json.loads(line[len("RESULT "):])
	raise RuntimeError(f"blender job failed (exit {done.returncode}):\n{done.stdout[-3000:]}\n{done.stderr[-2000:]}")


def res_path(out: pathlib.Path, path: str) -> str:
	"""A staged file's res:// path."""
	return f"{RES}/{pathlib.Path(path).relative_to(out).as_posix()}"


def manifest_row(library: pathlib.Path, out: pathlib.Path, key: str, result: dict) -> dict:
	"""The manifest row for a made key: its parts, the whole's bound, and where it came from."""
	spec = DERIVED[key]
	parts = {name: {"path": res_path(out, made["glb"]), "aabb_min": made["aabb_min"], "aabb_max": made["aabb_max"],
		"triangles": made["triangles"], "method": made["method"], "texture_px": made["texture_px"],
		**({"glow_faces": made["glow_faces"]} if "glow_faces" in made else {})}
		for name, made in result["parts"].items()}
	first = next(iter(parts.values()))
	return {"category": "prop", "path": first["path"], "parts": parts, "aabb_min": result["aabb_min"],
		"aabb_max": result["aabb_max"], "family": FAMILY, "triangles": sum(p["triangles"] for p in parts.values()),
		"triangle_budget": sum(p["budget"] for p in spec["parts"]),
		"texture_px": max(p["texture_px"] for p in parts.values()), "facing": "+Z",
		"tool": "tools/make_demo_derived_props.py", "source": spec["source"],
		"source_sha256": sha256(library / spec["source"]), "edits": edits_of(spec), "source_faces": result["source_faces"],
		"dropped_faces": result["dropped"], "decision": DECISION}


def edits_of(spec: dict) -> dict:
	"""What was done to the source, as the manifest records it."""
	edits = {"parts": [p["name"] for p in spec["parts"]]}
	for field in ("drop", "stretch", "glow"):
		if field in spec:
			edits[field] = spec[field]
	for part in spec["parts"]:
		for field in ("region", "thin", "rim"):
			if field in part:
				edits.setdefault(part["name"], {})[field] = part[field]
	return edits


def check_row(key: str, row: dict) -> None:
	"""Refuse a row over GAP-04's furniture ceiling, its parts together, or over its texture ceiling."""
	if row["triangles"] > CEILING_TRIANGLES:
		raise RuntimeError(f"{key}: {row['triangles']} triangles over the furniture ceiling {CEILING_TRIANGLES}")
	if row["triangles"] > row["triangle_budget"]:
		raise RuntimeError(f"{key}: {row['triangles']} triangles over its budget {row['triangle_budget']}")
	if row["texture_px"] > CEILING_PX:
		raise RuntimeError(f"{key}: {row['texture_px']} px textures over the family ceiling {CEILING_PX}")


def cached_row(library: pathlib.Path, out: pathlib.Path, key: str) -> dict | None:
	"""The row of a key made before from the same source by the same job, if every part's file is there."""
	record = out / "props" / f"{key}.made.json"
	if not record.is_file():
		return None
	made = json.loads(record.read_text())
	if made.get("job") != job_for(library, out, key) or made.get("source_sha256") != sha256(library / DERIVED[key]["source"]):
		return None
	row = made["row"]
	if not all((out / part["path"][len(RES) + 1:]).is_file() for part in row["parts"].values()):
		return None
	return row


def make_one(library: pathlib.Path, out: pathlib.Path, key: str, force: bool) -> tuple[str, dict]:
	"""Make one key (or reuse its cached row) and return its checked row."""
	row = None if force else cached_row(library, out, key)
	if row is not None:
		print(f"  {key:22} cached ({row['triangles']} tris)", flush=True)
		return key, row
	job = job_for(library, out, key)
	result = run_blender(job)
	row = manifest_row(library, out, key, result)
	check_row(key, row)
	(out / "props" / f"{key}.made.json").write_text(json.dumps(
		{"job": job, "source_sha256": row["source_sha256"], "row": row}, indent=1) + "\n")
	print(f"  {key:22} {row['triangles']:5} tris in {len(row['parts'])} part(s), {result['seconds']} s", flush=True)
	return key, row


def stage(library: pathlib.Path, out: pathlib.Path, keys: list[str] | None = None, force: bool = False) -> dict:
	"""Make every key (or `keys`), JOBS at a time; {"rows": {key: row}, "failed": {key: reason}}."""
	(out / "props").mkdir(parents=True, exist_ok=True)
	wanted = keys if keys else list(DERIVED)
	unknown = [key for key in wanted if key not in DERIVED]
	if unknown:
		raise RuntimeError(f"unknown keys: {', '.join(unknown)}")
	rows, failed = {}, {}
	with concurrent.futures.ThreadPoolExecutor(max_workers=JOBS) as pool:
		futures = {pool.submit(make_one, library, out, key, force): key for key in wanted}
		for future in concurrent.futures.as_completed(futures):
			try:
				key, row = future.result()
				rows[key] = row
			except RuntimeError as error:
				failed[futures[future]] = str(error).splitlines()[-1] if str(error) else "failed"
	for key, reason in failed.items():
		print(f"make_demo_derived_props: {key} FAILED: {reason}")
	return {"rows": rows, "failed": failed}


def patch_manifest(out: pathlib.Path, rows: dict) -> None:
	"""Merge these rows into an existing manifest.json's world, leaving everything else."""
	path = out / "manifest.json"
	manifest = json.loads(path.read_text()) if path.exists() else {"world": {}, "cast": {}}
	manifest.setdefault("world", {}).update(rows)
	path.write_text(json.dumps(manifest, indent=1) + "\n")


def main() -> int:
	"""Make the derived props and patch the staged manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--only", nargs="+", help="make only these keys")
	parser.add_argument("--force", action="store_true", help="remake keys whose cached result still matches")
	args = parser.parse_args()
	made = stage(args.library, args.out, args.only, args.force)
	patch_manifest(args.out, made["rows"])
	print(f"make_demo_derived_props: {len(made['rows'])} keys -> {args.out}; {len(made['failed'])} failed")
	return 1 if made["failed"] else 0


if __name__ == "__main__":
	sys.exit(main())
