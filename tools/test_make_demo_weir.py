#!/usr/bin/env python3
"""Self-test for tools/make_demo_weir.py (decision 0301, review F41). Runs without Blender and without
the library: the Blender job is replaced by a recorded result, the source by a small file.

NEGATIVE TESTS COME FIRST:

  N01  a cached result is not reused when the source, the Blender script's job or the made GLB changed
       or is missing.
  N02  a Blender run that prints no RESULT line raises, naming the failure.

Then: the cuts are godot/demo/water/weir_fit.gd's own (the structure is cut where the fit splits it); a
manifest row carries its provenance (the source path and SHA-256, the faces removed and why), its
res:// path and the stone patch; stage_demo_assets.py stages it with the world.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_demo_weir as weir  # noqa: E402
import stage_demo_assets as stage  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIT = ROOT / "godot/demo/water/weir_fit.gd"
FAILURES: list[str] = []
CASES: list[str] = []


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _library(folder: pathlib.Path) -> pathlib.Path:
	"""A stand-in library holding only the weir's L0."""
	source = folder / weir.SOURCE
	source.parent.mkdir(parents=True, exist_ok=True)
	source.write_bytes(b"the weir")
	return folder


def _recorded(job: dict) -> dict:
	"""What the Blender job reports, with its GLB written."""
	pathlib.Path(job["glb"]).parent.mkdir(parents=True, exist_ok=True)
	pathlib.Path(job["glb"]).write_bytes(b"glb")
	return {"aabb_min": [-0.91, 0.13, -0.12], "aabb_max": [0.94, 1.07, 0.72], "triangles": 4052, "bytes": 3,
		"source_faces": 6012, "removed": {"water": 747, "slab": 1783}, "stone_uv": [0.14, 0.78, 0.16, 0.8],
		"cuts": job["cuts"], "seconds": 0.7}


def _staged(library: pathlib.Path, out: pathlib.Path, runs: list[int]) -> dict:
	"""stage() with the Blender run replaced by the recorded result, counting the runs."""
	real = weir.run_blender
	weir.run_blender = lambda job: (runs.append(1), _recorded(job))[1]
	try:
		return weir.stage(library, out)
	finally:
		weir.run_blender = real


def test_n01_a_stale_cache_is_remade() -> None:
	"""N01: made once; reused; remade when the source changes, when the GLB is missing."""
	with tempfile.TemporaryDirectory() as folder:
		library = _library(pathlib.Path(folder) / "library")
		out = pathlib.Path(folder) / "out"
		runs: list[int] = []
		_staged(library, out, runs)
		_staged(library, out, runs)
		check("N01 the cached structure is reused", len(runs) == 1)
		(library / weir.SOURCE).write_bytes(b"another weir")
		_staged(library, out, runs)
		check("N01 a changed source remakes it", len(runs) == 2)
		(out / "world" / f"{weir.KEY}.glb").unlink()
		_staged(library, out, runs)
		check("N01 a missing GLB remakes it", len(runs) == 3)
		record = json.loads((out / "world" / f"{weir.KEY}.made.json").read_text())
		record["job"]["script_sha256"] = "changed"
		(out / "world" / f"{weir.KEY}.made.json").write_text(json.dumps(record))
		_staged(library, out, runs)
		check("N01 a changed Blender script remakes it", len(runs) == 4)


def test_n02_a_silent_blender_run_raises() -> None:
	"""N02: no RESULT line -- a RuntimeError naming the failure (stage_demo_assets.py reports and goes on)."""
	real = weir.shutil.which
	weir.shutil.which = lambda name: None
	try:
		weir.run_blender({"source": "x"})
		check("N02 no blender raises", False)
	except RuntimeError as error:
		check("N02 no blender raises, saying so", "blender is not on PATH" in str(error))
	finally:
		weir.shutil.which = real


def test_the_cuts_are_the_fits_own() -> None:
	"""CUTS are weir_fit.gd's CUT_LEFT, PLAIN_FROM, PLAIN_TO and CUT_RIGHT, in that order."""
	text = FIT.read_text()
	names = ["CUT_LEFT", "PLAIN_FROM", "PLAIN_TO", "CUT_RIGHT"]
	values = [float(re.search(rf"const {name}: float = (-?[0-9.]+)", text).group(1)) for name in names]
	check("the cuts match weir_fit.gd", values == weir.CUTS)
	check("the cuts run left to right", weir.CUTS == sorted(weir.CUTS))


def test_the_row_carries_its_provenance() -> None:
	"""The row: res:// path, bounds, the source and its SHA-256, what was removed, the cuts, the patch."""
	with tempfile.TemporaryDirectory() as folder:
		library = _library(pathlib.Path(folder) / "library")
		row = _staged(library, pathlib.Path(folder) / "out", [])[weir.KEY]
		check("res:// path", row["path"] == f"res://demo/assets/world/{weir.KEY}.glb")
		check("the source named", row["source"] == "building/weir/l0.glb")
		check("the source's SHA-256", row["source_sha256"] == weir.sha256(library / weir.SOURCE))
		check("what was removed", row["removed"] == {"water": 747, "slab": 1783} and row["source_faces"] == 6012)
		check("the cuts and the stone patch", row["cuts"] == weir.CUTS and len(row["stone_uv"]) == 4)
		check("the tool and the decision", row["tool"] == "tools/make_demo_weir.py" and row["decision"] == "0301")


def test_staging_makes_the_structure_with_the_world() -> None:
	"""stage_demo_assets.py's world staging includes the weir's structure (without Blender: left out)."""
	check("staging calls the weir tool", "stage_weir" in dir(stage))


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
	print("test_make_demo_weir: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
