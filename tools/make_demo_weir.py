#!/usr/bin/env python3
"""The weir's structure without its diorama, for the live demo. Decision 0301 (review F41).

WHY. The library weir (building/weir/l0.glb) is a diorama: the timber weir wall, its sluice gate and
its stone piers standing in their own earth slab with their own baked pool and tail water. Placed in the
demo's stream it read as a raised block in mid-stream -- a dirt slab's cut sides, an inset water patch
-- touching neither bank nor bed. godot/demo/water/weir_fit.gd now fits the STRUCTURE to the channel:
its ends out on the banks, its foot down to the bed, the demo's one water surface round it. This makes
that structure from the library model, into the gitignored godot/demo/assets/ (nothing derived from the
library is committed, decision 0188; the library original is only read):

  world/weir_structure.glb        the L0 with the baked water and the earth slab removed, cut through at
                                  CUTS (tools/demo_weir_blender.py has the rules), its own UVs and maps
  world/weir_structure.made.json  the job (stamped with the Blender script's SHA-256) and the source's
                                  SHA-256, so a re-run remakes it only when either changed

and returns its manifest row ("weir_structure"), with provenance: the source's path and SHA-256, the
faces removed and why, the cuts, and the stone patch the sill is textured from.

	python3 tools/make_demo_weir.py              # needs blender; merges the row into the manifest
	python3 tools/make_demo_weir.py --force      # remake even if the cached result still matches

stage_demo_assets.py calls this, so a full staging run already includes it. Without Blender the row is
left out and the demo draws the weir's placeholder (water_dressing.gd).
"""

from __future__ import annotations

import argparse
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
BLENDER_SCRIPT = pathlib.Path(__file__).resolve().parent / "demo_weir_blender.py"
RES = "res://demo/assets"
KEY = "weir_structure"
SOURCE = pathlib.Path("building/weir/l0.glb")
## Planes of constant x (glTF units) the structure is cut through at -- the left end's outer cut, the
## plain wall copied to fill the gaps (between the middle two), the right end's outer cut. The same
## numbers are godot/demo/water/weir_fit.gd's CUT_LEFT, PLAIN_FROM, PLAIN_TO and CUT_RIGHT.
CUTS = [-0.41, -0.38, -0.1, 0.8]


def sha256(path: pathlib.Path) -> str:
	"""The file's SHA-256, streamed."""
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for block in iter(lambda: handle.read(1 << 20), b""):
			digest.update(block)
	return digest.hexdigest()


def job_for(library: pathlib.Path, out: pathlib.Path) -> dict:
	"""The Blender job, stamped with the Blender script's SHA-256 so a changed script remakes it."""
	return {"source": str(library / SOURCE), "glb": str(out / "world" / f"{KEY}.glb"), "cuts": CUTS,
		"script_sha256": sha256(BLENDER_SCRIPT)}


def run_blender(job: dict) -> dict:
	"""Run the job headless; return what it printed on its RESULT line."""
	blender = shutil.which("blender")
	if blender is None:
		raise RuntimeError("blender is not on PATH (see docs/ENVIRONMENT.md)")
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
		json.dump(job, handle)
	command = [blender, "--background", "--factory-startup", "--python", str(BLENDER_SCRIPT), "--", handle.name]
	done = subprocess.run(command, capture_output=True, text=True)
	pathlib.Path(handle.name).unlink()
	for line in done.stdout.splitlines():
		if line.startswith("RESULT "):
			return json.loads(line[len("RESULT "):])
	raise RuntimeError(f"blender job failed (exit {done.returncode}):\n{done.stdout[-3000:]}\n{done.stderr[-2000:]}")


def manifest_row(library: pathlib.Path, result: dict) -> dict:
	"""The manifest row for the made structure: where it is, how big, and where it came from."""
	return {"category": "building", "path": f"{RES}/world/{KEY}.glb", "aabb_min": result["aabb_min"],
		"aabb_max": result["aabb_max"], "triangles": result["triangles"], "facing": "+Z",
		"tool": "tools/make_demo_weir.py", "source": SOURCE.as_posix(), "source_sha256": sha256(library / SOURCE),
		"method": "baked water and earth slab removed by texel colour and structure region; cut at cuts",
		"source_faces": result["source_faces"], "removed": result["removed"], "cuts": result["cuts"],
		"stone_uv": result["stone_uv"], "decision": "0301"}


def stage(library: pathlib.Path, out: pathlib.Path, force: bool = False) -> dict:
	"""Make the structure (or reuse the cached one); return {KEY: manifest row}."""
	(out / "world").mkdir(parents=True, exist_ok=True)
	record = out / "world" / f"{KEY}.made.json"
	job = job_for(library, out)
	if not force and record.is_file():
		made = json.loads(record.read_text())
		if made.get("job") == job and made.get("source_sha256") == sha256(library / SOURCE) \
				and pathlib.Path(job["glb"]).is_file():
			print(f"  {KEY:22} cached ({made['row']['triangles']} tris)", flush=True)
			return {KEY: made["row"]}
	result = run_blender(job)
	row = manifest_row(library, result)
	record.write_text(json.dumps({"job": job, "source_sha256": row["source_sha256"], "row": row}, indent=1) + "\n")
	print(f"  {KEY:22} {row['triangles']} tris, removed {row['removed']}, {result['seconds']} s", flush=True)
	return {KEY: row}


def patch_manifest(out: pathlib.Path, rows: dict) -> None:
	"""Merge these rows into an existing manifest.json's world, leaving everything else."""
	path = out / "manifest.json"
	manifest = json.loads(path.read_text()) if path.exists() else {"world": {}, "cast": {}}
	manifest.setdefault("world", {}).update(rows)
	path.write_text(json.dumps(manifest, indent=1) + "\n")


def main() -> int:
	"""Make the structure and patch the staged manifest."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--out", type=pathlib.Path, default=OUT)
	parser.add_argument("--force", action="store_true", help="remake even if the cached result still matches")
	args = parser.parse_args()
	patch_manifest(args.out, stage(args.library, args.out, args.force))
	return 0


if __name__ == "__main__":
	sys.exit(main())
