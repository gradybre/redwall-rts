#!/usr/bin/env python3
"""Self-test for tools/make_demo_derived_props.py (decision 0371, the underground revamp's P7). Runs without Blender and
without the library: the Blender jobs are replaced by recorded results, the sources by small files in a temporary
folder.

NEGATIVE TESTS COME FIRST:

  N01  a key over GAP-04's furniture ceiling (its parts together), over its own budget, or over the 1,024 px texture
       ceiling refuses.
  N02  an unknown key refuses before any job runs.
  N03  a key whose Blender job fails is left out of the rows and reported failed; the others stand.
  N04  a cached result is not reused when the source, the job or a part's file changed or is missing.

Then: every key is the furniture family's and its parts' budgets fit the ceiling; the jobs say what each fixes (the
door's leaf a cylinder thinned and rimmed, the arch's dark slab dropped, the stores' bar and five strings, the lantern's
glow, the bed lengthened); a row carries its provenance, its parts' res:// paths and bounds, and the whole's bound; and
staging calls this tool.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_demo_derived_props as derived  # noqa: E402
import stage_demo_assets as stage  # noqa: E402

FAILURES: list[str] = []
CASES: list[str] = []


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _raises(call, kind=RuntimeError) -> bool:
	"""Whether `call()` raises `kind`."""
	try:
		call()
	except kind:
		return True
	return False


def _library(folder: pathlib.Path) -> pathlib.Path:
	"""A stand-in library: every derived key's source, its bytes naming it."""
	for spec in derived.DERIVED.values():
		source = folder / spec["source"]
		source.parent.mkdir(parents=True, exist_ok=True)
		source.write_bytes(f"source {spec['source']}".encode())
	return folder


def _result(library: pathlib.Path, out: pathlib.Path, key: str, triangles: int | None = None, texture: int = 512) -> dict:
	"""What the Blender job reports for `key`, its parts' files written: each part at its budget (or `triangles`)."""
	job = derived.job_for(library, out, key)
	parts = {}
	for part in job["parts"]:
		pathlib.Path(part["glb"]).parent.mkdir(parents=True, exist_ok=True)
		pathlib.Path(part["glb"]).write_bytes(b"glb")
		parts[part["name"]] = {"glb": part["glb"], "aabb_min": [-0.4, 0.1, -0.1], "aabb_max": [0.4, 1.0, 0.2],
			"triangles": triangles if triangles is not None else part["budget"], "method": "decimate",
			"texture_px": part.get("texture_px", texture)}
	return {"source_faces": 1000, "dropped": 10, "parts": parts, "aabb_min": [-0.95, 0.0, -0.36],
		"aabb_max": [0.95, 1.5, 0.36], "seconds": 1.0}


def _with_blender(results):
	"""Replace the Blender run by `results(job)` while a test runs (returns the real one to put back)."""
	real = derived.run_blender
	derived.run_blender = results
	return real


# --- negative ---------------------------------------------------------------------------------------

def test_n01_over_the_ceiling_or_the_budget_refuses() -> None:
	"""2,001 triangles over the furniture ceiling; one part over its budget; 2,048 px maps: each refuses."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib")
		out = base / "out"
		row = derived.manifest_row(library, out, "tunnel_arch_open", _result(library, out, "tunnel_arch_open"))
		check("the arch at its budget passes", not _raises(lambda: derived.check_row("tunnel_arch_open", row)))
		over = dict(row, triangles=2001, triangle_budget=2100)
		check("over the ceiling refuses, whatever its budget", _raises(lambda: derived.check_row("tunnel_arch_open", over)))
		check("over its budget refuses", _raises(lambda: derived.check_row("tunnel_arch_open", dict(row, triangles=1901))))
		check("2,048 px refuses", _raises(lambda: derived.check_row("tunnel_arch_open", dict(row, texture_px=2048))))


def test_n02_an_unknown_key_refuses() -> None:
	"""An unknown key refuses before any Blender job runs."""
	ran: list[str] = []
	real = _with_blender(lambda job: ran.append(job["key"]) or {})
	try:
		check("unknown refuses", _raises(lambda: derived.stage(pathlib.Path("/lib"), pathlib.Path("/tmp/p7_none"), ["dragon"])))
	finally:
		derived.run_blender = real
	check("no job ran", ran == [])


def test_n03_a_failed_job_is_left_out_and_reported() -> None:
	"""The lantern's job fails: it is reported failed and left out; the arch is made."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib")
		out = base / "out"

		def results(job: dict) -> dict:
			if job["key"] == "hand_lantern_lit":
				raise RuntimeError("blender job failed (exit 1):\nboom")
			return _result(library, out, job["key"])

		real = _with_blender(results)
		try:
			made = derived.stage(library, out, ["hand_lantern_lit", "tunnel_arch_open"])
		finally:
			derived.run_blender = real
		check("the lantern failed", list(made["failed"]) == ["hand_lantern_lit"] and made["failed"]["hand_lantern_lit"] == "boom")
		check("the arch made", list(made["rows"]) == ["tunnel_arch_open"])
		check("its record written", (out / "props" / "tunnel_arch_open.made.json").is_file())


def test_n04_a_stale_cache_is_not_reused() -> None:
	"""A made key is reused as it is; its source changed, its job changed, or a part's file gone, it is remade."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib")
		out = base / "out"
		jobs: list[str] = []

		def results(job: dict) -> dict:
			jobs.append(job["key"])
			return _result(library, out, job["key"])

		real = _with_blender(results)
		try:
			derived.stage(library, out, ["burrow_door_open"])
			check("cached: no job", derived.cached_row(library, out, "burrow_door_open") is not None)
			(library / derived.DERIVED["burrow_door_open"]["source"]).write_bytes(b"changed")
			check("a changed source: stale", derived.cached_row(library, out, "burrow_door_open") is None)
			derived.stage(library, out, ["burrow_door_open"])
			(out / "props" / "burrow_door_open__leaf.glb").unlink()
			check("a part's file gone: stale", derived.cached_row(library, out, "burrow_door_open") is None)
			derived.stage(library, out, ["burrow_door_open"])
			record = out / "props" / "burrow_door_open.made.json"
			made = json.loads(record.read_text())
			made["job"]["parts"][0]["budget"] = 1
			record.write_text(json.dumps(made))
			check("a changed job: stale", derived.cached_row(library, out, "burrow_door_open") is None)
		finally:
			derived.run_blender = real
		check("made three times", jobs == ["burrow_door_open"] * 3)


# --- the table and its rows -------------------------------------------------------------------------

def test_every_key_fits_the_furniture_family() -> None:
	"""Each key's parts' budgets sum under GAP-04's furniture ceiling (2,000) and its maps within 1,024 px."""
	for key, spec in derived.DERIVED.items():
		check(f"{key}: {sum(p['budget'] for p in spec['parts'])} under the ceiling",
			sum(p["budget"] for p in spec["parts"]) < derived.CEILING_TRIANGLES)
		check(f"{key}: its maps within 1,024 px",
			max(p.get("texture_px", spec["texture_px"]) for p in spec["parts"]) <= derived.CEILING_PX)
	check("the five fixes", set(derived.DERIVED) == {"burrow_door_open", "tunnel_arch_open", "hanging_stores_strung",
		"hand_lantern_lit", "large_bed"})


def test_the_jobs_say_what_each_fixes() -> None:
	"""The door: the leaf a cylinder round its measured middle, thinned and rimmed, the frame the rest. The arch: its
	dark slab dropped. The stores: a bar and five strings. The lantern: its glow split off. The bed: lengthened only.
	Each job names its source and is stamped with both Blender scripts."""
	lib = pathlib.Path("/lib")
	out = pathlib.Path("/out")
	door = derived.job_for(lib, out, "burrow_door_open")
	leaf = door["parts"][0]
	check("the leaf first, the frame the rest", [p["name"] for p in door["parts"]] == ["leaf", "frame"] and "region" not in door["parts"][1])
	check("the leaf a cylinder", leaf["region"]["cylinder"] == derived.DOOR_LEAF)
	check("thinned and rimmed", leaf["thin"] == {"at": 0.0, "by": 0.14} and leaf["rim"] == [0.02, 0.112])
	check("each part to its own file", leaf["glb"] == "/out/props/burrow_door_open__leaf.glb")
	arch = derived.job_for(lib, out, "tunnel_arch_open")
	check("the arch's slab dropped by darkness in its doorway", arch["drop"] == [derived.ARCH_SLAB] and derived.ARCH_SLAB["dark"] < 0.1)
	stores = derived.job_for(lib, out, "hanging_stores_strung")
	check("a bar and five strings", [p["name"] for p in stores["parts"]] == ["bar", "string0", "string1", "string2", "string3", "string4"])
	edges = [p["region"]["box"][0][0] for p in stores["parts"][1:]] + [stores["parts"][-1]["region"]["box"][1][0]]
	check("the strings side by side", edges == derived.STRING_EDGES)
	check("the lantern glows", derived.job_for(lib, out, "hand_lantern_lit").get("glow") is True)
	check("the bed lengthened only", derived.job_for(lib, out, "large_bed")["stretch"] == [0.0, 1.31])
	check("the source", door["source"] == "/lib/prop/burrow_door/highpoly.glb")
	check("stamped with both scripts", door["scripts_sha256"] == [derived.sha256(s) for s in derived.BLENDER_SCRIPTS])


def test_a_row_carries_its_parts_and_provenance() -> None:
	"""The row: the first part's path (so a parts-blind reader still finds a model), every part's res:// path, bound,
	triangles and method, the whole's bound, the family and budget, the source and its SHA-256, the edits and the
	decision."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib")
		out = base / "out"
		row = derived.manifest_row(library, out, "burrow_door_open", _result(library, out, "burrow_door_open"))
		check("its first part's path", row["path"] == "res://demo/assets/props/burrow_door_open__leaf.glb")
		check("its parts", list(row["parts"]) == ["leaf", "frame"]
			and row["parts"]["frame"]["path"] == "res://demo/assets/props/burrow_door_open__frame.glb")
		check("each part's bound", row["parts"]["leaf"]["aabb_min"] == [-0.4, 0.1, -0.1])
		check("the whole's bound", row["aabb_min"] == [-0.95, 0.0, -0.36] and row["aabb_max"] == [0.95, 1.5, 0.36])
		check("its triangles and budget", (row["triangles"], row["triangle_budget"]) == (1900, 1900))
		check("its family", row["family"] == "furniture_instance")
		check("its source and SHA-256", row["source"] == "prop/burrow_door/highpoly.glb"
			and row["source_sha256"] == hashlib.sha256(b"source prop/burrow_door/highpoly.glb").hexdigest())
		check("what was done", row["edits"]["leaf"]["thin"] == {"at": 0.0, "by": 0.14} and row["dropped_faces"] == 10)
		check("its decision", row["decision"] == "0371" and row["tool"] == "tools/make_demo_derived_props.py")
		lantern = derived.manifest_row(library, out, "hand_lantern_lit", dict(_result(library, out, "hand_lantern_lit"),
			parts={"lantern": dict(_result(library, out, "hand_lantern_lit")["parts"]["lantern"], glow_faces=80)}))
		check("a lantern's glow faces", lantern["parts"]["lantern"]["glow_faces"] == 80 and lantern["edits"]["glow"] is True)


def test_staging_makes_the_derived_props() -> None:
	"""stage_demo_assets.py stages the derived props with the props (none without Blender: an empty set)."""
	real = stage.make_demo_derived_props.stage
	stage.make_demo_derived_props.stage = lambda library, out: (_ for _ in ()).throw(RuntimeError("blender is not on PATH"))
	try:
		check("no Blender: none", stage.stage_derived(pathlib.Path("/lib"), pathlib.Path("/out")) == {})
	finally:
		stage.make_demo_derived_props.stage = real
	stage.make_demo_derived_props.stage = lambda library, out: {"rows": {"large_bed": {"path": "x"}}, "failed": {}}
	try:
		check("the rows made", stage.stage_derived(pathlib.Path("/lib"), pathlib.Path("/out")) == {"large_bed": {"path": "x"}})
	finally:
		stage.make_demo_derived_props.stage = real


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
	print("test_make_demo_derived_props: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
