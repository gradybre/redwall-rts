#!/usr/bin/env python3
"""Art pass 2's game-ready files, made from the library (decision 0951). Nothing here is wired in.

Brendan approved art pass 2 on 2026-10-02 (decision 0951; paid calls delegated under decision 0961). Its
Meshy outputs live in the gitignored library (decision 0188); this tool makes everything the game would load
from them, free, and writes it where the existing staging puts its own files:

  models     every new model's game-budget L0, by tools/demo_props_blender.py's own decimate-and-bake
             (the same job format make_demo_props.py writes), into the LIBRARY as <family>/<key>/l0.glb, and
             copied to the gitignored godot/demo/assets/ (world/, props/, wildlife/):
               pine_scots, yew_ancient   tree family, 5,800 of 6,000 triangles, 1,024 px  (the evergreen kind)
               hall_stage2               building family, 30,000 of 32,000, 2,048 px     (the stone Great Hall)
               hall_banner               furniture, 1,900 of 2,000, 1,024 px            (the hall's banners)
               wild_*                    small prop, 1,150 of 1,200, 512 px              (wildlife bodies)
             plus plant_flax through the plant job: cards and the 580-triangle close-up (the farm's crops)
  ui         the portraits, tapestry and chronicle art cut from their sheets (tools/art_pass2_ui.py)
  post       the Blender post-steps (tools/art_pass2_blender.py): the hall's stage-2 turn and fit, the banner's
             cloth/wood split, the pine's needle tint, the wildlife clips, the window glow masks and the bare oak

The keys, sizes, budgets and code each file serves are in docs/art-reference/art_pass2_mapping.md.

	python3 tools/make_art_pass2.py models [--only KEY ...]
	python3 tools/make_art_pass2.py post [--only STEP ...]
	python3 tools/make_art_pass2.py ui
	python3 tools/make_art_pass2.py all
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLS = pathlib.Path(__file__).resolve().parent
## The library is the main checkout's (worktrees have none): decision 0188 keeps it outside git.
LIBRARY_CANDIDATES = [ROOT / "assets/library", pathlib.Path.home() / "Developer/redwall-rts/assets/library"]
OUT = ROOT / "godot/demo/assets"
PROPS_SCRIPT = TOOLS / "demo_props_blender.py"
POST_SCRIPT = TOOLS / "art_pass2_blender.py"
JOBS = 4

## key: (library family, job kind, target triangles, texture px, staged sub-folder)
MODELS = {
	"pine_scots": ("environment", "prop", 5800, 1024, "world"),
	"yew_ancient": ("environment", "prop", 5800, 1024, "world"),
	"hall_stage2": ("building", "prop", 30000, 2048, "world"),
	"hall_banner": ("prop", "prop", 1900, 1024, "props"),
	"wild_songbird": ("wildlife", "prop", 1150, 512, "wildlife"),
	"wild_songbird_flight": ("wildlife", "prop", 1150, 512, "wildlife"),
	"wild_butterfly": ("wildlife", "prop", 1150, 512, "wildlife"),
	"wild_frog": ("wildlife", "prop", 1150, 512, "wildlife"),
	## The leaping fish is the 2026-09-29 pass's trout, reused: no new generation (decision 0951).
	"wild_trout_leaping": ("prop/item_trout", "prop", 1150, 512, "wildlife"),
	"plant_flax": ("environment", "plant", 580, 512, "plants"),
}
## plant_flax's soil line, MEASURED as make_demo_props.PLANTS' are: the 95th percentile height of the
## soil-coloured faces of the clump (z < -0.5; the brown seed bolls high up are soil-coloured too).
FLAX_SOIL_Y = -0.797
POST_STEPS = ["hall_stage2", "hall_banner", "pine_tint", "wildlife", "windows", "oak_bare"]
## Keys whose decimated L0 is only an input to a post step (written as l0_raw.glb; the post step writes l0.glb).
RAW_FIRST = {"hall_stage2", "hall_banner", "pine_scots"}
## Keys whose unwrap is tightened (art_pass2_blender.py run_tight_low): the default left ~98% of their texture
## empty, measured.
TIGHT_UV = {"pine_scots", "yew_ancient", "hall_stage2"}


def library() -> pathlib.Path:
	"""The asset library: this checkout's, else the main checkout's."""
	for candidate in LIBRARY_CANDIDATES:
		if candidate.is_dir():
			return candidate
	raise SystemExit("no assets/library (decision 0188: it is local to the main checkout)")


def folder_of(lib: pathlib.Path, key: str) -> pathlib.Path:
	"""The library folder a key's source is read from."""
	family = MODELS[key][0]
	return lib / family if "/" in family else lib / family / key


def target_of(lib: pathlib.Path, key: str) -> pathlib.Path:
	"""The library folder a key's derived files are written to (the reused trout writes to its own)."""
	family = MODELS[key][0]
	return lib / "wildlife" / key if "/" in family else lib / family / key


def job_for(lib: pathlib.Path, key: str) -> dict:
	"""demo_props_blender.py's job for one key (its 'prop' or 'plant' kind)."""
	_family, kind, target, texture, _sub = MODELS[key]
	out = target_of(lib, key)
	out.mkdir(parents=True, exist_ok=True)
	job = {"kind": kind, "source": str(folder_of(lib, key) / "highpoly.glb"), "glb": str(out / ("l0_raw.glb" if key in RAW_FIRST else "l0.glb")),
		"target_triangles": target, "texture_px": texture}
	if kind == "plant":
		job["soil_y"] = FLAX_SOIL_Y
		job["cards"] = {"atlas": str(out / f"{key}_cards.png"), "px_per_unit": 256}
	return job


def run_blender(script: pathlib.Path, job: dict) -> dict:
	"""Run one headless Blender job and return its RESULT line."""
	blender = shutil.which("blender")
	if blender is None:
		raise SystemExit("blender is not on PATH (docs/ENVIRONMENT.md)")
	with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
		json.dump(job, handle)
	done = subprocess.run([blender, "--background", "--factory-startup", "--python", str(script), "--", handle.name],
		capture_output=True, text=True)
	pathlib.Path(handle.name).unlink()
	for line in done.stdout.splitlines():
		if line.startswith("RESULT "):
			return json.loads(line[len("RESULT "):])
	raise RuntimeError(f"{job.get('glb', job)}: blender failed (exit {done.returncode})\n{done.stdout[-2500:]}\n"
		f"{done.stderr[-1500:]}")


def make_model(lib: pathlib.Path, key: str) -> dict:
	"""One key's L0 into the library, then its staged copy."""
	result = run_blender(POST_SCRIPT if key in TIGHT_UV else PROPS_SCRIPT, job_for(lib, key))
	staged = OUT / MODELS[key][4]
	staged.mkdir(parents=True, exist_ok=True)
	if key not in RAW_FIRST:
		shutil.copy2(result["glb"], staged / f"{key}.glb")
	if "cards" in result:
		shutil.copy2(result["cards"]["atlas"]["path"], staged / f"{key}_cards.png")
	print(f"  {key:20} {result['triangles']:6} tris  {result['texture_px']} px  {result['method']}  "
		f"aabb {result['aabb_min']} {result['aabb_max']}  {result['seconds']} s", flush=True)
	return result


def models(lib: pathlib.Path, keys: list[str]) -> dict:
	"""Make every model (or `keys`), JOBS at a time; write the results beside the staged files."""
	results, failed = {}, {}
	with concurrent.futures.ThreadPoolExecutor(max_workers=JOBS) as pool:
		futures = {pool.submit(make_model, lib, key): key for key in keys}
		for future in concurrent.futures.as_completed(futures):
			try:
				results[futures[future]] = future.result()
			except RuntimeError as error:
				failed[futures[future]] = str(error)
	for key, reason in failed.items():
		print(f"FAILED {key}: {reason}")
	record = OUT / "art_pass2_models.json"
	merged = json.loads(record.read_text()) if record.exists() else {}
	merged.update(results)
	record.write_text(json.dumps(merged, indent=1) + "\n")
	return {"results": results, "failed": failed}


def post(lib: pathlib.Path, steps: list[str]) -> None:
	"""The Blender post-steps, one process each; every result is kept in OUT/art_pass2_post.json."""
	record = OUT / "art_pass2_post.json"
	merged = json.loads(record.read_text()) if record.exists() else {}
	for step in steps:
		result = run_blender(POST_SCRIPT, {"step": step, "library": str(lib), "out": str(OUT)})
		merged[step] = result
		record.write_text(json.dumps(merged, indent=1) + "\n")
		print(f"  post {step}: done in {result['seconds']} s", flush=True)


def main() -> int:
	"""Parse the command and run it."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("command", choices=["models", "post", "ui", "all"])
	parser.add_argument("--only", nargs="+")
	args = parser.parse_args()
	lib = library()
	if args.command in ("models", "all"):
		made = models(lib, args.only if args.command == "models" and args.only else list(MODELS))
		if made["failed"]:
			return 1
	if args.command in ("post", "all"):
		post(lib, args.only if args.command == "post" and args.only else POST_STEPS)
	if args.command in ("ui", "all"):
		subprocess.run([sys.executable, str(TOOLS / "art_pass2_ui.py")], check=True)
	return 0


if __name__ == "__main__":
	sys.exit(main())
