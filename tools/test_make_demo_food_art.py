#!/usr/bin/env python3
"""Self-test for tools/make_demo_food_art.py (decision 0941). Runs without Blender and without the
library: GLBs are written small, the sheet is drawn here.

NEGATIVE TESTS COME FIRST:

  N01  an unknown key refuses before anything runs.
  N02  a row over its triangle target, or not standing its height on y = 0, refuses.
  N03  a GLB whose mesh node carries a transform refuses (its bounds would be wrong).

Then: every model's target is under its family's GAP-04 ceiling as lookdev_dimensions.gd states it,
and its texture under the family's edge; the infirmary is fitted to its footprint under its envelope;
an icon's background goes but a pale subject inside it stays, and the icon is 128 px with the subject
centred on its longest side; every icon names a sheet cell in the 3 x 3 grid, none twice.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_demo_food_art as art  # noqa: E402
from repair_meshy_rig import write_glb  # noqa: E402
from repair_meshy_rig import append_accessor  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOOKDEV = ROOT / "godot/assets/lookdev/lookdev_dimensions.gd"
FAILURES: list[str] = []
CASES: list[str] = []


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _raises(call) -> bool:
	"""Whether `call()` raises RuntimeError."""
	try:
		call()
	except RuntimeError:
		return True
	return False


def box_glb(path: pathlib.Path, lo: list[float], hi: list[float], triangles: int, node_extra: dict | None = None) -> None:
	"""A GLB with one primitive whose POSITION bounds are lo..hi and `triangles` triangles."""
	doc = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": 0}], "bufferViews": [], "accessors": [],
		"meshes": [], "nodes": [], "scenes": [{"nodes": [0]}], "scene": 0}
	binary = b""
	binary, position = append_accessor(doc, binary, [lo, hi, lo], 5126, "VEC3")
	doc["accessors"][position]["min"], doc["accessors"][position]["max"] = lo, hi
	binary, indices = append_accessor(doc, binary, [[i % 3] for i in range(3 * triangles)], 5125, "SCALAR")
	doc["meshes"].append({"primitives": [{"attributes": {"POSITION": position}, "indices": indices}]})
	doc["nodes"].append({"mesh": 0, **(node_extra or {})})
	path.write_bytes(write_glb(doc, binary))


def lookdev_ceilings() -> dict:
	"""FAMILY_KEY -> L0 triangle ceiling, read from lookdev_dimensions.gd."""
	text = LOOKDEV.read_text()
	keys = re.findall(r'&"(\w+)"', re.search(r"FAMILY_KEY[^=]*=\s*\[(.*?)\]", text, re.S).group(1))
	ceilings = [int(n) for n in re.findall(r"\d+", re.search(r"FAMILY_TRIANGLE_CEILING[^=]*=\s*\[(.*?)\]", text, re.S).group(1))]
	return {key: ceilings[i * 3] for i, key in enumerate(keys)}


def test_negatives(tmp: pathlib.Path) -> None:
	"""N01-N03."""
	check("N01 unknown key refuses", _raises(lambda: art.stage(tmp, tmp, ["no_such_key"])))
	glb = tmp / "world" / "apple_tree.glb"
	glb.parent.mkdir(parents=True, exist_ok=True)
	box_glb(glb, [-1.0, 0.0, -1.0], [1.0, 4.7, 1.0], 6001)
	result = {"texture_px": 2048, "method": "decimate"}
	(tmp / "environment/apple_tree").mkdir(parents=True, exist_ok=True)
	(tmp / "environment/apple_tree/highpoly.glb").write_bytes(b"x")
	check("N02 over target refuses", _raises(lambda: art.model_row(tmp, tmp, "apple_tree", glb, 4.7, result)))
	box_glb(glb, [-1.0, 0.2, -1.0], [1.0, 4.9, 1.0], 100)
	check("N02 off the ground refuses", _raises(lambda: art.model_row(tmp, tmp, "apple_tree", glb, 4.7, result)))
	box_glb(glb, [-1.0, 0.0, -1.0], [1.0, 4.7, 1.0], 100, {"scale": [2.0, 2.0, 2.0]})
	check("N03 node transform refuses", _raises(lambda: art.glb_bounds(glb)))
	box_glb(glb, [-1.0, 0.0, -1.0], [1.0, 4.7, 1.0], 100)
	row = art.model_row(tmp, tmp, "apple_tree", glb, 4.7, result)
	check("a good row is prescaled with provenance", row["prescaled"] and row["height_m"] == 4.7
		and row["path"] == "res://demo/assets/world/apple_tree.glb" and len(row["source_sha256"]) == 64)


def test_budgets() -> None:
	"""Every target under its family ceiling; the textures under the family edge."""
	ceilings = lookdev_ceilings()
	for key, spec in art.MODELS.items():
		family, ceiling, edge = art.FAMILY[spec["family"]]
		check(f"{key} family ceiling matches lookdev", ceilings.get(family) == ceiling)
		check(f"{key} target under ceiling", spec["target"] < ceiling)
		check(f"{key} texture under edge", spec["texture_px"] <= edge)
		check(f"{key} has a size", "height_m" in spec or ("plan_m" in spec and "max_height_m" in spec))


def test_footprint_fit(tmp: pathlib.Path) -> None:
	"""The infirmary takes the height at which its plan is 16 m, capped at its 5.5 m envelope."""
	glb = tmp / "infirmary.glb"
	box_glb(glb, [-0.95, -0.44, -0.95], [0.95, 0.44, 0.95], 10)
	check("footprint fit capped by envelope", art.target_height(art.MODELS["infirmary_ward"], glb) == 5.5)
	box_glb(glb, [-0.95, -0.2, -0.95], [0.95, 0.2, 0.95], 10)
	check("footprint fit under envelope", abs(art.target_height(art.MODELS["infirmary_ward"], glb) - 0.4 * 16 / 1.9) < 1e-3)


def test_icons() -> None:
	"""Background out, pale interior kept, 128 px, centred; every icon a distinct cell of a 3 x 3 sheet."""
	Image, _ = art._pil()
	sheet = Image.new("RGB", (300, 300), (224, 224, 224))
	for x in range(130, 170):
		for y in range(120, 180):
			ring = x < 135 or x >= 165 or y < 125 or y >= 175
			sheet.putpixel((x, y), (90, 60, 30) if ring else (226, 224, 222))
	cut = art.cut_cell(sheet, 1, 1)
	check("background cut", cut.getpixel((2, 2))[3] == 0)
	check("pale interior kept", cut.getpixel((50, 50))[3] == 255)
	icon = art.fit_icon(cut)
	box = icon.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
	check("icon is 128 px", icon.size == (128, 128))
	check("longest side fills inside the margin", 116 <= box[3] - box[1] <= 121 and box[1] >= 3 and abs((box[0] + box[2]) - 128) <= 2)
	cells = [(sheet_path, c, r) for sheet_path, c, r in art.ICONS.values()]
	check("every icon a distinct cell", len(set(cells)) == len(cells))
	check("cells inside the grid", all(0 <= c < 3 and 0 <= r < 3 for _, c, r in cells))
	check("24 icons", len(art.ICONS) == 24)


def main() -> int:
	"""Run every test; print and return the outcome."""
	with tempfile.TemporaryDirectory() as tmp:
		test_negatives(pathlib.Path(tmp))
		test_footprint_fit(pathlib.Path(tmp))
	test_budgets()
	test_icons()
	print(json.dumps({"cases": len(CASES), "failures": FAILURES}, indent=1))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
