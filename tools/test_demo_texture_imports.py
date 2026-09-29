#!/usr/bin/env python3
"""Self-test for tools/demo_texture_imports.py (decision 0196, the Windows demo build). Runs without
Godot and without staged assets: the GLBs are JSON-only files and the images bare headers, written into
a temporary folder with literal values.

NEGATIVE TESTS COME FIRST:

  N01  an image named like a normal map but used by its GLB as colour is compressed as colour, and one
       named `Image_2` that the material uses as its normal map is a normal map: the role is the GLB's.
  N02  a PNG no GLB embeds (a card atlas, an icon) is never VRAM-compressed: its importer is `keep`.
  N03  an extracted image with no .import yet is left alone (Godot has not extracted it; run again).
  N04  --check writes nothing and reports what would change.

Then: normal maps get compress/normal_map=1; the roughness map gets the green-channel limiter fed by
its material's normal map and is capped at its colour map's size (and not capped when it is no
larger); every other key of an existing .import survives; a second run changes nothing; a file
previously `keep` that is now a GLB image becomes a texture import again.
"""

from __future__ import annotations

import json
import pathlib
import struct
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import demo_texture_imports as dti  # noqa: E402

FAILURES: list[str] = []
CASES: list[str] = []

EXISTING_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://btest"
path="res://.godot/imported/x.ctex"

[deps]

source_file="res://x.png"

[params]

compress/mode=0
compress/high_quality=false
compress/normal_map=0
mipmaps/generate=true
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/size_limit=0
detect_3d/compress_to=1
"""


def check(name: str, condition: bool) -> None:
	"""Record one check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def glb(path: pathlib.Path, images: list[str], material: dict) -> None:
	"""A GLB holding only a JSON chunk: `images` by name, one texture per image, one material."""
	doc = {"asset": {"version": "2.0"}, "images": [{"name": name, "mimeType": "image/png"} for name in images],
		"textures": [{"source": index} for index in range(len(images))], "materials": [material]}
	data = json.dumps(doc).encode()
	data += b" " * (-len(data) % 4)
	header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(data)) + struct.pack("<I4s", len(data), b"JSON")
	path.write_bytes(header + data)


def png(path: pathlib.Path, width: int, height: int) -> None:
	"""A PNG signature and IHDR, enough for a size read."""
	path.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I4sII", 13, b"IHDR", width, height) + b"\x08\x06\x00\x00\x00")


def params(path: pathlib.Path) -> dict[str, str]:
	"""The [params] of a .import file."""
	text = path.read_text()
	body = text.split("[params]", 1)[1] if "[params]" in text else ""
	return dict(line.split("=", 1) for line in body.splitlines() if "=" in line)


def fixture(root: pathlib.Path) -> pathlib.Path:
	"""A project with one staged world folder: a barrel GLB (named maps), a crop bed GLB (Image_N maps),
	a trick GLB whose `normal`-named image is its colour map, and a card atlas and an icon."""
	project = root / "godot"
	world = project / "demo/assets/world"
	icons = project / "demo/assets/icons"
	world.mkdir(parents=True)
	icons.mkdir(parents=True)
	glb(world / "barrel.glb", ["normal", "texture_0", "texture_0_metallic_roughness"],
		{"normalTexture": {"index": 0}, "pbrMetallicRoughness": {"baseColorTexture": {"index": 1},
		"metallicRoughnessTexture": {"index": 2}}})
	glb(world / "crop_bed.glb", ["Image_2", "Image_0", "Image_1"],
		{"normalTexture": {"index": 0}, "pbrMetallicRoughness": {"baseColorTexture": {"index": 1},
		"metallicRoughnessTexture": {"index": 2}}})
	glb(world / "trick.glb", ["normal"], {"pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}})
	png(world / "barrel_normal.png", 2048, 2048)
	png(world / "barrel_texture_0.png", 2048, 2048)
	png(world / "barrel_texture_0_metallic_roughness.png", 4096, 4096)
	png(world / "crop_bed_Image_2.png", 1024, 1024)
	png(world / "crop_bed_Image_0.png", 1024, 1024)
	png(world / "crop_bed_Image_1.png", 1024, 1024)
	png(world / "trick_normal.png", 512, 512)
	png(world / "crop_grain_ripe_cards.png", 1392, 464)
	png(icons / "find_clay.png", 128, 128)
	for image in world.glob("*.png"):
		if image.name != "crop_bed_Image_1.png":          # N03: not extracted yet
			image.with_name(image.name + ".import").write_text(EXISTING_IMPORT)
	return project


def test_n01_the_role_is_the_glbs_not_the_name() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		world = project / "demo/assets/world"
		dti.apply(project / "demo/assets", project)
		check("N01 a `normal`-named colour map is not a normal map",
			params(world / "trick_normal.png.import")["compress/normal_map"] == "2")
		check("N01 crop_bed's Image_2 is its normal map", params(world / "crop_bed_Image_2.png.import")["compress/normal_map"] == "1")
		check("N01 crop_bed's Image_0 is its colour map", params(world / "crop_bed_Image_0.png.import")["compress/normal_map"] == "2")


def test_n02_pictures_the_demo_reads_itself_are_kept_as_files() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		counts = dti.apply(project / "demo/assets", project)
		for name in ("world/crop_grain_ripe_cards.png.import", "icons/find_clay.png.import"):
			check(f"N02 {name} is keep", (project / "demo/assets" / name).read_text() == dti.KEEP_TEXT)
		check("N02 two kept", counts[dti.ROLE_RAW] == 2)


def test_n03_an_unextracted_image_is_left_for_the_next_import() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		dti.apply(project / "demo/assets", project)
		check("N03 no .import is invented for an image Godot has not extracted",
			not (project / "demo/assets/world/crop_bed_Image_1.png.import").exists())


def test_n04_check_writes_nothing() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		before = (project / "demo/assets/world/barrel_normal.png.import").read_text()
		counts = dti.apply(project / "demo/assets", project, write=False)
		check("N04 --check leaves the file", (project / "demo/assets/world/barrel_normal.png.import").read_text() == before)
		check("N04 --check reports the changes: 7 rewritten, 1 new keep", len(counts["changed"]) == 8)


def test_the_settings_by_role() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		world = project / "demo/assets/world"
		dti.apply(project / "demo/assets", project)
		normal = params(world / "barrel_normal.png.import")
		colour = params(world / "barrel_texture_0.png.import")
		orm = params(world / "barrel_texture_0_metallic_roughness.png.import")
		check("every GLB image is VRAM compressed", all(p["compress/mode"] == "2" for p in (normal, colour, orm)))
		check("S3TC, not BPTC", all(p["compress/high_quality"] == "false" for p in (normal, colour, orm)))
		check("mipmaps on", all(p["mipmaps/generate"] == "true" for p in (normal, colour, orm)))
		check("the normal map is flagged", normal["compress/normal_map"] == "1")
		check("the roughness limiter reads green", orm["roughness/mode"] == "3")
		check("fed by the material's normal map", orm["roughness/src_normal"] == '"res://demo/assets/world/barrel_normal.png"')
		check("the 4096 px roughness map is capped at its colour map's 2048", orm["process/size_limit"] == "2048")
		check("a colour map is not capped", colour["process/size_limit"] == "0")
		crop = params(world / "crop_bed_Image_1.png.import") if (world / "crop_bed_Image_1.png.import").exists() else None
		check("(fixture) crop_bed's roughness map is the unextracted one", crop is None)
		check("other keys survive", colour["process/fix_alpha_border"] == "true" and colour["detect_3d/compress_to"] == "1")
		check("the remap section survives", 'uid="uid://btest"' in (world / "barrel_texture_0.png.import").read_text())


def test_a_roughness_map_no_larger_than_its_colour_map_is_not_capped() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		world = project / "demo/assets/world"
		(world / "crop_bed_Image_1.png.import").write_text(EXISTING_IMPORT)
		dti.apply(project / "demo/assets", project)
		orm = params(world / "crop_bed_Image_1.png.import")
		check("1024 beside 1024: no cap", orm["process/size_limit"] == "0")
		check("its limiter reads crop_bed's Image_2", orm["roughness/src_normal"] == '"res://demo/assets/world/crop_bed_Image_2.png"')


def test_a_second_run_changes_nothing() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		first = dti.apply(project / "demo/assets", project)
		second = dti.apply(project / "demo/assets", project)
		check("the first run changes files", len(first["changed"]) > 0)
		check("the second changes none", second["changed"] == [])


def test_a_kept_file_that_became_a_glb_image_is_a_texture_again() -> None:
	with tempfile.TemporaryDirectory() as tmp:
		project = fixture(pathlib.Path(tmp))
		settings = project / "demo/assets/world/barrel_texture_0.png.import"
		settings.write_text(dti.KEEP_TEXT)
		dti.apply(project / "demo/assets", project)
		text = settings.read_text()
		check("importer is texture again", 'importer="texture"' in text and "keep" not in text)
		check("and compressed", params(settings)["compress/mode"] == "2")


def test_the_real_enum_values() -> None:
	"""Godot 4.7.2's option enums (editor/import/resource_importer_texture.cpp), quoted."""
	check("VRAM Compressed is 2 of Lossless,Lossy,VRAM Compressed", dti.COMPRESS_VRAM == 2)
	check("Enable is 1 of Detect,Enable,Disabled", dti.NORMAL_MAP_ENABLE == 1)
	check("Green is 3 of Detect,Disabled,Red,Green", dti.ROUGHNESS_GREEN == 3)


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
	print("test_demo_texture_imports: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
