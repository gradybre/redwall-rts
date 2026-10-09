#!/usr/bin/env python3
"""Self-test for tools/stage_art_passes.py (decision 0903). Runs without Blender and without the library: the staged
folder is a temporary one, its GLBs written small.

NEGATIVE TESTS COME FIRST:

  N01  a folder that is not the project's never runs a pass's tool (they write only to the project's folder).
  N02  a record row whose staged file is missing writes no manifest row (the demo then draws its stand-in).
  N03  an empty folder stages nothing: no world, icon or UI rows.
  N04  an icon record lacking a key make_art_pass3.py cuts is stale, as is an unreadable one or one that is not a map
       (decision 1831: a restage then recuts it); a models record is never stale for that reason.

Then: a pass-2 model's row is measured through its node's placement and names its window mask; a pass-3 row is
copied from its record with its category; flax gets a plant row with its cards and soil line; icons are keyed; the
UI rows carry the nine-patch margins and the page's text area, and only files that exist. Every dish in dish_book.gd has
a `dish_<key>` icon that pass 1's cutter or make_art_pass3.py cuts (decision 1831), and 1831's eleven are on their
sheets' cells, marked 1831.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_art_pass3  # noqa: E402
import make_demo_food_art  # noqa: E402
import stage_art_passes as passes  # noqa: E402
from repair_meshy_rig import append_accessor, write_glb  # noqa: E402

FAILURES: list[str] = []
CASES: list[str] = []


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def glb(path: pathlib.Path, lo: list[float], hi: list[float], node_extra: dict | None = None) -> None:
	"""A one-triangle GLB whose POSITION bounds are lo..hi, its node carrying `node_extra`."""
	path.parent.mkdir(parents=True, exist_ok=True)
	doc = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": 0}], "bufferViews": [], "accessors": [],
		"meshes": [], "nodes": [], "scenes": [{"nodes": [0]}], "scene": 0}
	binary, position = append_accessor(doc, b"", [lo, hi, lo], 5126, "VEC3")
	doc["accessors"][position]["min"], doc["accessors"][position]["max"] = lo, hi
	doc["meshes"].append({"primitives": [{"attributes": {"POSITION": position}}]})
	doc["nodes"].append({"mesh": 0, **(node_extra or {})})
	path.write_bytes(write_glb(doc, binary))


def touch(path: pathlib.Path) -> None:
	"""An empty staged file."""
	path.parent.mkdir(parents=True, exist_ok=True)
	path.write_bytes(b"x")


def test_negatives(tmp: pathlib.Path) -> None:
	"""N01-N03."""
	check("N01 a foreign folder runs no tool", passes.run_tools(tmp) == [])
	(tmp / "art_pass3_models.json").write_text(json.dumps({"rock_face": {"path": "res://demo/assets/props/rock_face.glb"}}))
	(tmp / "art_pass3_icons.json").write_text(json.dumps({"find_coins": {"icon": "res://demo/assets/icons/find_coins.png"}}))
	check("N02 no staged model, no row", "rock_face" not in passes.world_rows(tmp))
	check("N02 no staged icon, no row", passes.icon_rows(tmp) == {})
	empty = tmp / "empty"
	empty.mkdir()
	made = passes.stage(empty)
	check("N03 nothing staged", made["world"] == {} and made["icons"] == {} and made["ui"] == {})


def test_icon_record_staleness(tmp: pathlib.Path) -> None:
	"""N04: which records a restage remakes."""
	record = tmp / passes.ICON_RECORD
	check("N04 a missing icon record is stale", passes.record_stale(tmp, passes.ICON_RECORD))
	every = {key: {"icon": f"res://demo/assets/icons/{key}.png"} for key in make_art_pass3.ICONS}
	record.write_text(json.dumps(every))
	check("N04 a record with every key is not stale", not passes.record_stale(tmp, passes.ICON_RECORD))
	record.write_text(json.dumps({key: row for key, row in every.items() if key != "dish_vole_stew"}))
	check("N04 a record lacking one key is stale", passes.record_stale(tmp, passes.ICON_RECORD))
	record.write_text("{not json")
	check("N04 an unreadable record is stale", passes.record_stale(tmp, passes.ICON_RECORD))
	record.write_text(json.dumps(sorted(every)))
	check("N04 a record that is not a map is stale", passes.record_stale(tmp, passes.ICON_RECORD))
	(tmp / "art_pass3_models.json").write_text("{}")
	check("N04 a models record is not judged by icon keys", not passes.record_stale(tmp, "art_pass3_models.json"))


def test_dish_icons() -> None:
	"""Every dish has an icon key a cutter cuts; 1831's eleven on their cells."""
	book = (passes.ROOT / "godot/demo/kitchen/dish_book.gd").read_text()
	dishes = re.findall(r'\{"key": &"(\w+)"', book)
	cut = set(make_demo_food_art.ICONS) | set(make_art_pass3.ICONS)
	check("dishes: the book was read", len(dishes) >= 24)
	check("dishes: every one has an icon", [key for key in dishes if f"dish_{key}" not in cut] == [])
	feasts, suppers = make_art_pass3.DISH_SHEET_FEASTS, make_art_pass3.DISH_SHEET_SUPPERS
	want = {"dish_feast_fish": (feasts, 0, 0), "dish_berry_tart": (feasts, 1, 0), "dish_nut_roast": (feasts, 2, 0),
		"dish_orchard_crumble": (feasts, 0, 1), "dish_porridge": (feasts, 1, 1), "dish_barleymeal": (feasts, 2, 1),
		"dish_soup": (suppers, 0, 0), "dish_beetroot_soup": (suppers, 1, 0), "dish_vole_stew": (suppers, 2, 0),
		"dish_fish_stew": (suppers, 0, 1), "dish_poached_dace": (suppers, 1, 1)}
	check("1831: the eleven on their cells", {key: make_art_pass3.ICONS.get(key) for key in want} == want)
	check("1831: no spare cell is keyed", sum(1 for sheet, _, _ in make_art_pass3.ICONS.values()
		if sheet in (feasts, suppers)) == 11)
	check("1831: both sheets marked 1831", make_art_pass3.SHEET_DECISIONS[feasts] == "1831"
		and make_art_pass3.SHEET_DECISIONS[suppers] == "1831")
	check("1831: no key cut twice", not set(make_demo_food_art.ICONS) & set(make_art_pass3.ICONS))


def test_world(tmp: pathlib.Path) -> None:
	"""Pass 2 measured, pass 3 copied, flax's plant row."""
	glb(tmp / "world/hall_windows.glb", [-1.0, 0.0, -0.5], [1.0, 1.2, 0.5], {"translation": [0.0, 0.5, 0.0]})
	touch(tmp / "world/hall_window_mask.png")
	glb(tmp / "world/pine_scots.glb", [-0.5, 0.0, -0.5], [0.5, 1.9, 0.5])
	touch(tmp / "props/rock_face.glb")
	(tmp / "art_pass3_models.json").write_text(json.dumps({"rock_face": {"path": "res://demo/assets/props/rock_face.glb",
		"prescaled": True}}))
	glb(tmp / "plants/plant_flax.glb", [-0.6, 0.0, -0.6], [0.6, 1.7, 0.6])
	touch(tmp / "plants/plant_flax_cards.png")
	(tmp / "art_pass2_models.json").write_text(json.dumps({"plant_flax": {"triangles": 482, "texture_px": 512,
		"method": "decimate", "axis": [0.0, 0.0], "half_width": 0.78, "height": 1.75,
		"cards": {"cell_m": [1.6, 1.8], "cells": ["full", "side", "thinned", "sparse"], "atlas": {"variants": 4}}}}))
	rows = passes.world_rows(tmp)
	check("pass 2: measured through its node", rows["hall_windows"]["aabb_min"] == [-1.0, 0.5, -0.5]
		and rows["hall_windows"]["aabb_max"] == [1.0, 1.7, 0.5])
	check("pass 2: its window mask", rows["hall_windows"]["window_mask"] == "res://demo/assets/world/hall_window_mask.png")
	check("pass 2: no mask where none is staged", "window_mask" not in rows["pine_scots"])
	check("pass 2: its category", rows["pine_scots"]["category"] == "environment")
	check("pass 3: copied from its record", rows["rock_face"]["category"] == "prop"
		and rows["rock_face"]["path"] == "res://demo/assets/props/rock_face.glb")
	cards = rows["plant_flax"]["cards"]
	check("flax: its cards", cards["texture"] == "res://demo/assets/plants/plant_flax_cards.png" and cards["variants"] == 4)
	check("flax: its soil line", cards["soil_y"] == passes.FLAX_SOIL_Y)
	check("not staged: no row", "yew_ancient" not in rows and "hall_stage2" not in rows)


def test_icons_and_ui(tmp: pathlib.Path) -> None:
	"""Icons by key; the UI rows with their numbers, only for staged files."""
	touch(tmp / "icons/find_coins.png")
	(tmp / "art_pass3_icons.json").write_text(json.dumps({"find_coins": {"icon": "res://demo/assets/icons/find_coins.png"},
		"item_ale": {"icon": "res://demo/assets/icons/item_ale.png"}}))
	check("icons: keyed", list(passes.icon_rows(tmp)) == ["find_coins"])
	for name in ("ui/portraits/mole_digger_48.png", "ui/portraits/mole_digger_source.png",
			"ui/tapestry/emblem_hall_24.png", "ui/tapestry/tapestry_ground.png", "ui/chronicle/chronicle_page.png"):
		touch(tmp / name)
	(tmp / "ui/art_pass2_ui.json").write_text(json.dumps({
		"portraits": {"mole_digger": {"files": {"48": "ui/portraits/mole_digger_48.png",
			"64": "ui/portraits/mole_digger_64.png"}}},
		"emblems": {"hall": {"files": {"24": "ui/tapestry/emblem_hall_24.png"}},
			"winter": {"files": {"24": "ui/tapestry/emblem_winter_24.png"}}},
		"tapestry": {"full": {"file": "ui/tapestry/tapestry_ground.png", "size": [896, 1200],
			"patch_margins_ltrb": [180, 226, 178, 232]}},
		"chronicle": {"file": "ui/chronicle/chronicle_page.png", "size": [752, 1048],
			"text_area_ltrb": [130, 150, 622, 898]}}))
	ui = passes.ui_rows(tmp)
	check("ui: a portrait's staged sizes only", ui["portraits"]["mole_digger"] == {
		"48": "res://demo/assets/ui/portraits/mole_digger_48.png",
		"source": "res://demo/assets/ui/portraits/mole_digger_source.png"})
	check("ui: an emblem with no file is left out", list(ui["emblems"]) == ["hall"])
	check("ui: the tapestry's margins", ui["tapestry_full"]["patch_margins_ltrb"] == [180, 226, 178, 232])
	check("ui: the page's text area", ui["chronicle_page"]["text_area_ltrb"] == [130, 150, 622, 898])


def main() -> int:
	"""Run every test; print each failure and the tally."""
	with tempfile.TemporaryDirectory() as folder:
		tmp = pathlib.Path(folder)
		for part in ("n", "r", "w", "u"):
			(tmp / part).mkdir()
		test_negatives(tmp / "n")
		test_icon_record_staleness(tmp / "r")
		test_dish_icons()
		test_world(tmp / "w")
		test_icons_and_ui(tmp / "u")
	for name in FAILURES:
		print(f"FAIL {name}")
	print(f"test_stage_art_passes: {len(CASES) - len(FAILURES)}/{len(CASES)} passed")
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
