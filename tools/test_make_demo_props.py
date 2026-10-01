#!/usr/bin/env python3
"""Self-test for tools/make_demo_props.py and the staging it adds to tools/stage_demo_assets.py
(decision 0196, the live demo's asset pass). Runs without Blender and without the library: the
Blender jobs are replaced by recorded results, the sources by small files in a temporary folder.

NEGATIVE TESTS COME FIRST:

  N01  a row over its triangle budget refuses, and so does one over the 1,024 px texture ceiling.
  N02  an unknown key refuses before any job runs.
  N03  a key whose Blender job fails is left out of the rows and reported failed; the others stand.
  N04  a cached result is not reused when the source, the job or a made file changed or is missing.

Then: every family's budget is under its GAP-04 ceiling as lookdev_dimensions.gd states it; the
jobs ask for icons and tops exactly where they should; a manifest row carries its provenance (the
source path and SHA-256), res:// paths and cards; the recorded gait speed wins over the estimate,
which is kept; the beaver is staged only once its grounded clips exist.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_demo_props as props  # noqa: E402
import stage_demo_assets as stage  # noqa: E402
from repair_meshy_rig import write_glb  # noqa: E402
from rig_meshy_tail import append_accessor  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOOKDEV = ROOT / "godot/assets/lookdev/lookdev_dimensions.gd"
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


def _library(folder: pathlib.Path, keys: list[str]) -> pathlib.Path:
	"""A stand-in library: a small 'highpoly.glb' per key, its bytes naming the key."""
	for key in keys:
		source = props.source_of(folder, key)
		source.parent.mkdir(parents=True, exist_ok=True)
		source.write_bytes(f"source of {key}".encode())
	return folder


def _result(out: pathlib.Path, key: str, triangles: int = 1000, texture: int = 512) -> dict:
	"""What the Blender job reports for `key`, with its files written."""
	job = props.job_for(pathlib.Path("/nowhere"), out, key)
	pathlib.Path(job["glb"]).parent.mkdir(parents=True, exist_ok=True)
	pathlib.Path(job["glb"]).write_bytes(b"glb")
	result = {"glb": job["glb"], "aabb_min": [-0.5, 0.0, -0.4], "aabb_max": [0.5, 1.9, 0.4],
		"triangles": triangles, "texture_px": texture, "method": "decimate", "seconds": 1.0}
	if "icon" in job:
		pathlib.Path(job["icon"]["path"]).parent.mkdir(parents=True, exist_ok=True)
		pathlib.Path(job["icon"]["path"]).write_bytes(b"png")
		result["icon"] = {"icon": job["icon"]["path"], "px": props.ICON_PX}
	if key in props.PLANTS:
		result.update({"axis": [0.01, -0.02], "half_width": 0.7, "height": 1.2})
		cards = {"cell_m": [1.4, 1.2], "cells": ["full", "side", "thinned", "sparse"],
			"atlas": {"path": job["cards"]["atlas"], "variants": 4, "px": [1400, 300]}}
		pathlib.Path(job["cards"]["atlas"]).write_bytes(b"png")
		if "tops" in job["cards"]:
			cards["tops"] = {"path": job["cards"]["tops"], "variants": 3, "px": [1000, 350]}
			cards["top_cell_m"] = [1.4, 1.4]
			pathlib.Path(job["cards"]["tops"]).write_bytes(b"png")
		result["cards"] = cards
	return result


# --- negative ------------------------------------------------------------------------------------

def test_n01_over_budget_or_texture_ceiling_refuses() -> None:
	"""check_row refuses a row one triangle over, and one texture pixel over 1,024."""
	row = {"triangles": 1151, "triangle_budget": 1150, "texture_px": 512}
	check("N01 one triangle over its budget refuses", _raises(lambda: props.check_row("k", row)))
	row = {"triangles": 1150, "triangle_budget": 1150, "texture_px": 2048}
	check("N01 a 2,048 px texture refuses", _raises(lambda: props.check_row("k", row)))
	row = {"triangles": 1150, "triangle_budget": 1150, "texture_px": 1024}
	check("N01 exactly at budget and ceiling passes", not _raises(lambda: props.check_row("k", row)))


def test_n02_an_unknown_key_refuses() -> None:
	"""stage() refuses a key it does not know before running anything."""
	with tempfile.TemporaryDirectory() as folder:
		out = pathlib.Path(folder)
		check("N02 an unknown key refuses", _raises(lambda: props.stage(out, out, ["item_dragon"])))


def test_n03_a_failed_job_is_left_out_and_reported() -> None:
	"""One of two keys fails in Blender: the other's row is made, the failure named."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib", ["item_carrot", "find_flint"])
		out = base / "out"
		real = props.run_blender

		def fake(job: dict) -> dict:
			if "item_carrot" in job["glb"]:
				raise RuntimeError("blender job failed (exit 1):\nstill over 1150 triangles")
			return _result(out, "find_flint")
		props.run_blender = fake
		try:
			made = props.stage(library, out, ["item_carrot", "find_flint"])
		finally:
			props.run_blender = real
		check("N03 the good key's row is made", list(made["rows"]) == ["find_flint"])
		check("N03 the failed key is reported with its reason", made["failed"] == {"item_carrot": "still over 1150 triangles"})


def test_n04_a_stale_cache_is_not_reused() -> None:
	"""A made record is reused only while the job, the source and every made file are unchanged."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib", ["item_carrot"])
		out = base / "out"
		row = props.manifest_row(library, out, "item_carrot", _result(out, "item_carrot"))
		record = out / "props" / "item_carrot.made.json"
		record.write_text(json.dumps({"job": props.job_for(library, out, "item_carrot"),
			"source_sha256": row["source_sha256"], "row": row}))
		check("N04 an unchanged record is reused", props.cached_row(library, out, "item_carrot") == row)
		(out / "icons" / "item_carrot.png").unlink()
		check("N04 a missing icon is not reused", props.cached_row(library, out, "item_carrot") is None)
		(out / "icons" / "item_carrot.png").write_bytes(b"png")
		props.source_of(library, "item_carrot").write_bytes(b"a new source")
		check("N04 a changed source is not reused", props.cached_row(library, out, "item_carrot") is None)
		props.source_of(library, "item_carrot").write_bytes(b"source of item_carrot")
		stale = json.loads(record.read_text())
		stale["job"]["script_sha256"] = "an older script"
		record.write_text(json.dumps(stale))
		check("N04 a record from another Blender script is not reused", props.cached_row(library, out, "item_carrot") is None)


# --- budgets and jobs ------------------------------------------------------------------------------

def _lookdev_ceilings() -> dict[str, tuple[int, int]]:
	"""{family key: (L0 triangle ceiling, texture edge ceiling)} read from lookdev_dimensions.gd."""
	text = LOOKDEV.read_text()
	keys = re.findall(r'&"(\w+)"', re.search(r"FAMILY_KEY: Array\[StringName\] = \[(.*?)\]", text, re.S).group(1))
	tris = [int(v) for v in re.findall(r"\d+", re.search(r"FAMILY_TRIANGLE_CEILING: Array\[int\] = \[(.*?)\]", text, re.S).group(1))]
	edges = [int(v) for v in re.findall(r"\d+", re.search(r"FAMILY_TEXTURE_EDGE_CEILING: Array\[int\] = \[(.*?)\]", text).group(1))]
	return {key: (tris[k * 3], edges[k]) for k, key in enumerate(keys)}


def test_every_budget_is_under_its_gap04_ceiling() -> None:
	"""small_prop 1,150 of 1,200; furniture 1,900 of 2,000; a plant 580 of 600; textures within."""
	ceilings = _lookdev_ceilings()
	check("the three families are GAP-04's", {f[0] for f in props.FAMILIES.values()} <= set(ceilings))
	for name, (family, target, texture) in props.FAMILIES.items():
		check(f"{name}: {target} triangles under {ceilings[family][0]}", target < ceilings[family][0])
		check(f"{name}: {texture} px within {ceilings[family][1]}", texture <= ceilings[family][1])
	check("small props target 1,150", props.FAMILIES["small_prop"][1] == 1150)
	check("furniture targets 1,900", props.FAMILIES["furniture"][1] == 1900)
	check("a plant targets 580", props.FAMILIES["plant"][1] == 580)


def test_the_pass_has_its_56_assets_and_eight_rebuilt() -> None:
	"""53 props -- the pass's 44 (18 items, 5 finds, 21 others), the 8 older props rebuilt (basket,
	lantern, bed, jars, shelf and four tools) and the burrow home's hearth (decision 0210: its L0's maps are
	2,048 px) -- and 12 plants; icons for the items, finds and relics."""
	check("53 props", len(props.PROPS) == 53)
	check("the hearth is furniture", props.PROPS["hearth"] == "furniture")
	rebuilt = {"basket", "wall_lantern", "bed", "clay_jars", "pantry_shelf", "spade", "hoe", "sickle", "axe"}
	check("the older props rebuilt", rebuilt <= set(props.PROPS))
	check("the bed and shelf are furniture", props.PROPS["bed"] == props.PROPS["pantry_shelf"] == "furniture")
	check("the buildings stay library L0s", stage.DRESSING == {"building": ["cellar", "composter"]})
	check("12 plants", len(props.PLANTS) == 12)
	check("18 items", sum(1 for k in props.PROPS if k.startswith("item_")) == 18)
	check("icons: the items and the finds", props.ICONS == set(props.ITEMS) | set(props.FINDS))
	check("every family known", all(f in props.FAMILIES for f in props.PROPS.values()))


def test_jobs_ask_for_icons_and_tops_where_they_should() -> None:
	"""An item's job renders an icon; a boat's does not. A rosette plant renders tops, an upright
	one does not; each plant's soil line is the table's; every job is stamped with the script."""
	out = pathlib.Path("/out")
	lib = pathlib.Path("/lib")
	carrot = props.job_for(lib, out, "item_carrot")
	check("an item gets a 128 px icon", carrot["icon"] == {"path": "/out/icons/item_carrot.png", "px": 128})
	check("a small prop bakes 512 px at 1,150", (carrot["target_triangles"], carrot["texture_px"]) == (1150, 512))
	boat = props.job_for(lib, out, "boat_rowboat")
	check("a boat gets no icon, 1,024 px at 1,900", "icon" not in boat and (boat["target_triangles"], boat["texture_px"]) == (1900, 1024))
	lettuce = props.job_for(lib, out, "plant_lettuce")
	check("lettuce (a rosette) gets tops", lettuce["cards"]["tops"] == "/out/plants/plant_lettuce_tops.png")
	check("leek (upright) gets none", "tops" not in props.job_for(lib, out, "plant_leek")["cards"])
	check("turnip's soil line is its measured -0.186", props.job_for(lib, out, "plant_turnip")["soil_y"] == -0.186)
	check("stamped with the Blender script", carrot["script_sha256"] == props.sha256(props.BLENDER_SCRIPT))


def test_a_row_carries_its_provenance_and_paths() -> None:
	"""The row names its source and its SHA-256, its family and budget, the triangles and texture
	reached, res:// paths for the model and icon, and a plant's cards."""
	with tempfile.TemporaryDirectory() as folder:
		base = pathlib.Path(folder)
		library = _library(base / "lib", ["item_carrot", "plant_turnip"])
		out = base / "out"
		row = props.manifest_row(library, out, "item_carrot", _result(out, "item_carrot"))
		check("its source", row["source"] == "prop/item_carrot/highpoly.glb")
		check("its SHA-256", row["source_sha256"] == hashlib.sha256(b"source of item_carrot").hexdigest())
		check("its family and budget", (row["family"], row["triangle_budget"], row["triangles"]) == ("small_prop", 1150, 1000))
		check("its model's res:// path", row["path"] == "res://demo/assets/props/item_carrot.glb")
		check("its icon's res:// path", row["icon"] == "res://demo/assets/icons/item_carrot.png")
		check("facing +Z", row["facing"] == "+Z")
		plant = props.manifest_row(library, out, "plant_turnip", _result(out, "plant_turnip"))
		cards = plant["cards"]
		check("a plant's atlas", cards["texture"] == "res://demo/assets/plants/plant_turnip_cards.png" and cards["variants"] == 4)
		check("its tops", cards["tops"]["texture"] == "res://demo/assets/plants/plant_turnip_tops.png")
		check("its soil line and crown", cards["soil_y"] == -0.186 and cards["crown"] == [0.01, -0.02])
		check("a plant is ground cover at 580", (plant["family"], plant["triangle_budget"]) == ("ground_cover_cluster", 580))


# --- the cast ---------------------------------------------------------------------------------------

def _clip(extras: dict | None) -> bytes:
	"""A minimal glTF with a Hips node carrying `extras` (none: no extras)."""
	hips = {"name": "Hips"}
	if extras is not None:
		hips["extras"] = extras
	doc = {"asset": {"version": "2.0"}, "nodes": [{"name": "Armature"}, hips], "buffers": [{"byteLength": 0}]}
	return write_glb(doc, b"")


def test_the_recorded_gait_speed_wins_and_the_estimate_is_kept() -> None:
	"""A walk with gait.speed_m_s 0.6821 stages 0.6821 from "gait", keeping the estimate beside it; a
	walk without the record stages the estimate from "toe_slide_estimate"."""
	with tempfile.TemporaryDirectory() as folder:
		recorded = pathlib.Path(folder) / "walk.glb"
		recorded.write_bytes(_clip({"gait": {"speed_m_s": 0.68214, "period_s": 1.03, "stride_m": 0.7}}))
		bare = pathlib.Path(folder) / "bare.glb"
		bare.write_bytes(_clip(None))
		real = stage.walk_speed
		stage.walk_speed = lambda path: 0.8279
		try:
			row = stage.walk_row(recorded)
			fallback = stage.walk_row(bare)
		finally:
			stage.walk_speed = real
		check("the gait speed, rounded to 0.1 mm/s", row["walk_speed_m_s"] == 0.6821)
		check("said to be the gait's", row["walk_speed_source"] == "gait")
		check("the old estimate kept beside it", row["walk_speed_estimate_m_s"] == 0.8279)
		check("no record: the estimate", fallback["walk_speed_m_s"] == 0.8279 and fallback["walk_speed_source"] == "toe_slide_estimate")
		check("gait_speed of a bare clip is None", stage.gait_speed(bare) is None)


def _sleeper() -> bytes:
	"""A tiny lying clip: joints Hips (at the origin), Head (0.8 m toward -Z) and tail_00; four body vertices on
	Hips -- the lowest at y = -0.12, every third measured (vertices 0 and 3) -- and one tail vertex far lower at
	y = -0.5; a two-key rotation on Hips."""
	doc = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0, 3]}],
		"nodes": [{"name": "Hips", "children": [1, 2]}, {"name": "Head", "translation": [0.0, 0.0, -0.8]},
			{"name": "tail_00", "translation": [0.0, 0.0, 0.5]}, {"name": "Body", "mesh": 0, "skin": 0}],
		"buffers": [{"byteLength": 0}], "bufferViews": [], "accessors": [], "skins": [], "meshes": [],
		"animations": [{"channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}], "samplers": []}]}
	binary = b""
	identity = [(1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0)] * 3
	binary, ibm = append_accessor(doc, binary, identity, 5126, "MAT4")
	doc["skins"].append({"joints": [0, 1, 2], "inverseBindMatrices": ibm})
	positions = [(0.1, -0.12, 0.3), (0.0, 0.3, 0.0), (0.0, 0.2, 0.0), (-0.1, -0.05, -0.5), (0.0, -0.5, 0.6)]
	binary, pos = append_accessor(doc, binary, positions, 5126, "VEC3")
	binary, jnt = append_accessor(doc, binary, [(0, 0, 0, 0)] * 4 + [(2, 0, 0, 0)], 5121, "VEC4")
	binary, wgt = append_accessor(doc, binary, [(1.0, 0.0, 0.0, 0.0)] * 5, 5126, "VEC4")
	doc["meshes"].append({"primitives": [{"attributes": {"POSITION": pos, "JOINTS_0": jnt, "WEIGHTS_0": wgt}}]})
	binary, times = append_accessor(doc, binary, [(0.0,), (1.0,)], 5126, "SCALAR")
	binary, turns = append_accessor(doc, binary, [(0.0, 0.0, 0.0, 1.0)] * 2, 5126, "VEC4")
	doc["animations"][0]["samplers"].append({"input": times, "output": turns, "interpolation": "LINEAR"})
	doc["buffers"][0]["byteLength"] = len(binary)
	return write_glb(doc, binary)


def test_a_sleep_clip_is_measured_by_its_body_s_lowest_point() -> None:
	"""sleep_row (decision 0210): the lowest measured body vertex (-0.12: the tail's -0.5 left out), the middle of the
	measured footprint, the way from the hips to the head (unit, toward -Z) and the footprint's length; staged as an
	optional clip where the grounded output has it."""
	with tempfile.TemporaryDirectory() as folder:
		clip = pathlib.Path(folder) / "anim_sleep_normally.glb"
		clip.write_bytes(_sleeper())
		row = stage.sleep_row(clip)
		check("the body's lowest point", row["floor_y_m"] == -0.12)
		check("the footprint's middle", row["centre_m"] == [0.0, -0.1])
		check("the head toward -Z", row["head"] == [0.0, -1.0])
		check("its length", row["length_m"] == 0.8)
	check("sleep is an optional clip", "sleep_normally" in stage.OPTIONAL_CLIPS and stage.SLEEP_CLIP == "sleep_normally")


def test_the_beaver_is_staged_only_once_grounded() -> None:
	"""Without creature/beaver_bridgewright/grounded the cast is the eight; with it, nine."""
	with tempfile.TemporaryDirectory() as folder:
		library = pathlib.Path(folder)
		check("eight without the beaver's grounded clips", stage.cast_keys(library) == stage.CAST)
		(library / "creature" / "beaver_bridgewright" / "grounded").mkdir(parents=True)
		check("the beaver joins once grounded", stage.cast_keys(library) == [*stage.CAST, "beaver_bridgewright"])
		check("its height is DEC-041's 1.40 m", stage.SPECIES_HEIGHT_M["beaver"] == 1.40)


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
	print("test_make_demo_props: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
