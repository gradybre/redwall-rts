#!/usr/bin/env python3
"""Art passes 2 and 3, staged for the live demo and written into its manifest. Decision 0903 (batch 8 integration).

Art pass 2 (decision 0951) and art pass 3 (decision 0971) each made their game-ready files with their own tool,
`tools/make_art_pass2.py all` and `tools/make_art_pass3.py` (plus `--icons`), into the gitignored godot/demo/assets/,
with a record of what each made beside them (`art_pass2_models.json`, `art_pass2_post.json`, `ui/art_pass2_ui.json`,
`art_pass3_models.json`, `art_pass3_icons.json`). Neither wrote the manifest the demo reads. This does:

  * runs a pass's tool only when its record is missing (each needs Blender; a re-run of staging reuses what is there);
  * measures every staged model the demo now draws and writes its `world` row, as stage_demo_assets.py does its own;
  * writes pass 3's nine icons into the `icons` section (by key, as pass 1's are);
  * writes the UI art (portraits, the tapestry's ground and emblems, the chronicle page) into a `ui` section.

What the demo draws from it (decision 0903): the evergreens, the stone Great Hall, the four homes' window-glow models,
the bare winter oak, the hall's banner, the tunnel's timber set and the rock face. Mapped but not drawn yet: flax has a
plant row (its card atlas is an image the demo would read itself), which no farm table names; the wildlife and the
preserving and brewing props have none (their rows stay in the passes' records).

Every image the manifest names is read raw by the demo, so tools/demo_texture_imports.py packs it as a file; that
tool refuses an image that is neither a GLB's nor the manifest's, so the passes' extra files the demo does not read
(the 24 px diagnostic portraits, the 512 px portrait crops, the standalone window masks) are named in their rows too.

    python3 tools/stage_art_passes.py          # patch the staged manifest (stage_demo_assets.py runs `stage`)
"""

from __future__ import annotations

import json
import math
import pathlib
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from repair_meshy_rig import read_glb  # noqa: E402
from rig_meshy_tail import node_worlds, transform_point  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOLS = pathlib.Path(__file__).resolve().parent
OUT = ROOT / "godot/demo/assets"
RES = "res://demo/assets"

## Pass 2's models the demo draws: key -> (category, staged file, the window mask beside it or "").
PASS2_WORLD = {
	"pine_scots": ("environment", "world/pine_scots.glb", ""),
	"yew_ancient": ("environment", "world/yew_ancient.glb", ""),
	"hall_stage2": ("building", "world/hall_stage2.glb", ""),
	"oak_mature_bare": ("environment", "world/oak_mature_bare.glb", ""),
	"hall_windows": ("building", "world/hall_windows.glb", "world/hall_window_mask.png"),
	"hall_stage2_windows": ("building", "world/hall_stage2_windows.glb", "world/hall_stage2_window_mask.png"),
	"kitchen_windows": ("building", "world/kitchen_windows.glb", "world/kitchen_window_mask.png"),
	"residence_windows": ("building", "world/residence_windows.glb", "world/residence_window_mask.png"),
	"hall_banner": ("prop", "props/hall_banner.glb", ""),
}
## Pass 3's models the demo draws (their rows come from art_pass3_models.json, prescaled).
## Flax's soil line, measured by art pass 2 (make_art_pass2.py FLAX_SOIL_Y).
FLAX_SOIL_Y = -0.797
PASS3_WORLD = ["tunnel_set", "tunnel_post", "tunnel_lintel", "rock_face"]
## Each pass's records: if one is missing, its tool is run (arguments after the script).
PASS2_RECORDS = ["art_pass2_models.json", "art_pass2_post.json", "ui/art_pass2_ui.json"]
PASS3_RECORDS = {"art_pass3_models.json": [], "art_pass3_icons.json": ["--icons"]}


def bounds(path: pathlib.Path) -> tuple[list[float], list[float]]:
	"""A GLB's world-space bounds in metres, as stage_demo_assets.py measures its own (every mesh node's POSITION
	min/max corners through the node's placement)."""
	doc, _ = read_glb(path.read_bytes())
	worlds = node_worlds(doc)
	lo, hi = [math.inf] * 3, [-math.inf] * 3
	for index, node in enumerate(doc["nodes"]):
		if "mesh" not in node:
			continue
		for primitive in doc["meshes"][node["mesh"]]["primitives"]:
			accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
			for corner in range(8):
				point = [accessor["max"][i] if corner >> i & 1 else accessor["min"][i] for i in range(3)]
				world = transform_point(worlds[index], point)
				lo, hi = [min(a, b) for a, b in zip(lo, world)], [max(a, b) for a, b in zip(hi, world)]
	return [round(v, 4) for v in lo], [round(v, 4) for v in hi]


def run_tools(out: pathlib.Path) -> list[str]:
	"""Run a pass's tool when one of its records is missing (only for the project's own folder: the tools write there).
	Returns what could not be made."""
	failed = []
	if out.resolve() != OUT.resolve():
		return failed
	if not all((out / record).is_file() for record in PASS2_RECORDS):
		if subprocess.run([sys.executable, str(TOOLS / "make_art_pass2.py"), "all"], check=False).returncode != 0:
			failed.append("art pass 2")
	for record, arguments in PASS3_RECORDS.items():
		if not (out / record).is_file():
			done = subprocess.run([sys.executable, str(TOOLS / "make_art_pass3.py"), *arguments], check=False)
			if done.returncode != 0:
				failed.append(f"art pass 3 ({record})")
	return failed


def world_rows(out: pathlib.Path) -> dict:
	"""The staged models' rows: pass 2's measured here, pass 3's from its record."""
	rows = {}
	for key, (category, staged, mask) in PASS2_WORLD.items():
		path = out / staged
		if not path.is_file():
			continue
		lo, hi = bounds(path)
		rows[key] = {"category": category, "path": f"{RES}/{staged}", "aabb_min": lo, "aabb_max": hi,
			"tool": "tools/make_art_pass2.py", "decision": "0951"}
		if mask and (out / mask).is_file():
			rows[key]["window_mask"] = f"{RES}/{mask}"
	record = out / "art_pass3_models.json"
	made = json.loads(record.read_text()) if record.is_file() else {}
	for key in PASS3_WORLD:
		if key in made and (out / made[key]["path"][len(RES) + 1:]).is_file():
			rows[key] = {"category": "prop", **made[key]}
	rows.update(flax_row(out))
	return rows


def flax_row(out: pathlib.Path) -> dict:
	"""Flax's plant row, as make_demo_props.py writes a plant's (mapped for the farm; no crop table names it yet)."""
	record = out / "art_pass2_models.json"
	made = json.loads(record.read_text()).get("plant_flax", {}) if record.is_file() else {}
	glb, cards = out / "plants/plant_flax.glb", out / "plants/plant_flax_cards.png"
	if not made or not glb.is_file() or not cards.is_file():
		return {}
	lo, hi = bounds(glb)
	return {"plant_flax": {"category": "environment", "path": f"{RES}/plants/plant_flax.glb", "aabb_min": lo,
		"aabb_max": hi, "triangles": made["triangles"], "texture_px": made["texture_px"], "method": made["method"],
		"facing": "+Z", "tool": "tools/make_art_pass2.py", "decision": "0951", "cards": {
		"texture": f"{RES}/plants/plant_flax_cards.png", "variants": made["cards"]["atlas"]["variants"],
		"cell_m": made["cards"]["cell_m"], "cells": made["cards"]["cells"], "soil_y": FLAX_SOIL_Y,
		"crown": made["axis"], "half_width": made["half_width"], "height": made["height"]}}}


def icon_rows(out: pathlib.Path) -> dict:
	"""Pass 3's nine icons, by key."""
	record = out / "art_pass3_icons.json"
	made = json.loads(record.read_text()) if record.is_file() else {}
	return {key: row for key, row in made.items() if (out / row["icon"][len(RES) + 1:]).is_file()}


def _files(out: pathlib.Path, files: dict) -> dict:
	"""{size: res path} for every file of a UI row that is staged."""
	return {size: f"{RES}/{name}" for size, name in files.items() if (out / name).is_file()}


def ui_rows(out: pathlib.Path) -> dict:
	"""The UI art (art_pass2_ui.json's crops): portraits by cast key, the tapestry's ground and emblems by entry kind,
	and the chronicle page, each with the numbers its panel needs (nine-patch margins, the page's text area)."""
	record = out / "ui/art_pass2_ui.json"
	if not record.is_file():
		return {}
	made = json.loads(record.read_text())
	portraits = {}
	for key, row in made.get("portraits", {}).items():
		files = _files(out, row["files"])
		source = f"ui/portraits/{key}_source.png"
		if (out / source).is_file():
			files["source"] = f"{RES}/{source}"
		if files:
			portraits[key] = files
	emblems = {kind: _files(out, row["files"]) for kind, row in made.get("emblems", {}).items()}
	ui = {"portraits": portraits, "emblems": {kind: files for kind, files in emblems.items() if files}}
	for name, row in made.get("tapestry", {}).items():
		if (out / row["file"]).is_file():
			ui[f"tapestry_{name}"] = {"path": f"{RES}/{row['file']}", "size": row["size"],
				"patch_margins_ltrb": row["patch_margins_ltrb"]}
	page = made.get("chronicle", {})
	if page and (out / page["file"]).is_file():
		ui["chronicle_page"] = {"path": f"{RES}/{page['file']}", "size": page["size"],
			"text_area_ltrb": page["text_area_ltrb"]}
	return ui


def stage(out: pathlib.Path = OUT) -> dict:
	"""Make what is missing, then {"world": rows, "icons": rows, "ui": {...}, "failed": [...]}."""
	failed = run_tools(out)
	return {"world": world_rows(out), "icons": icon_rows(out), "ui": ui_rows(out), "failed": failed}


def main() -> int:
	"""Stage and patch the existing manifest."""
	made = stage()
	path = OUT / "manifest.json"
	manifest = json.loads(path.read_text()) if path.is_file() else {"world": {}, "cast": {}}
	manifest.setdefault("world", {}).update(made["world"])
	manifest.setdefault("icons", {}).update(made["icons"])
	manifest["ui"] = made["ui"]
	path.write_text(json.dumps(manifest, indent=1) + "\n")
	print(f"stage_art_passes: {len(made['world'])} models, {len(made['icons'])} icons, "
		f"{len(made['ui'].get('portraits', {}))} portraits; failed: {made['failed'] or 'none'}")
	return 1 if made["failed"] else 0


if __name__ == "__main__":
	sys.exit(main())
