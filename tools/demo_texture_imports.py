#!/usr/bin/env python3
"""Set the import settings of the live demo's staged textures: VRAM-compressed in 3D, lossless for
what the demo reads as a picture. Decision 0196 (the Windows demo build).

WHY THIS EXISTS. Godot extracts every image a staged GLB embeds to a PNG beside it and imports it
with `compress/mode=0` (lossless, uncompressed in VRAM). The editor's "detect 3D" switch would turn
that into VRAM compression the first time the texture is drawn in 3D -- but a headless import
never draws, so it never fires, and the demo's default view held ~6 GB of RGBA8 textures. This
writes the settings the editor would have reached, by rule, into the `.import` files. The source
images are never touched. It is idempotent: a second run changes nothing.

THE RULE. A staged image is either one a GLB embeds (Godot names it `<glb stem>_<image name>.<ext>`)
or one the demo reads itself with `Image.load_from_file` (the card atlases, the tops and the icons).

  * GLB images get their ROLE from the GLB's own materials, never from the file name (crop_bed's
    `Image_2` is its normal map):
      colour  baseColorTexture / emissiveTexture -> VRAM compressed, mipmaps
      normal  normalTexture                       -> VRAM compressed as a normal map (RG, Z rebuilt)
      orm     metallicRoughnessTexture / occlusionTexture
                                                  -> VRAM compressed, roughness limiter on the
                                                     green channel (glTF's roughness) fed by the
                                                     material's normal map, and never larger than
                                                     the material's colour map (Meshy's 4096 px
                                                     roughness maps sit beside 2048 px colour maps)
  * Images no staged GLB embeds are read raw at run time, so the importer is set to `keep`: the PNG
    itself is exported, byte for byte (lossless), and `Image.load_from_file("res://...")` finds it in
    the pack. Without `keep` an exported build contains only the `.ctex`, and every icon and card
    atlas would be missing.

`high_quality` stays false, so desktop builds use S3TC (DXT1/DXT5, BC5 for normal maps). UI art
outside `godot/demo/assets/` (godot/assets/ui/, the woodland skin, which is generated at run time) is
never touched.

    python3 tools/demo_texture_imports.py                 # rewrite the .import files
    python3 tools/demo_texture_imports.py --check         # exit 1 if any would change
    python3 tools/demo_texture_imports.py --godot godot   # import, rewrite, reimport until stable
"""

from __future__ import annotations

import argparse
import json
import pathlib
import struct
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot"
ASSETS = PROJECT / "demo/assets"
IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg")

ROLE_COLOUR = "colour"
ROLE_NORMAL = "normal"
ROLE_ORM = "orm"
ROLE_RAW = "raw"
# Where one image serves two roles, the stricter handling wins.
ROLE_PRIORITY = {ROLE_NORMAL: 3, ROLE_ORM: 2, ROLE_COLOUR: 1}

COMPRESS_VRAM = 2
NORMAL_MAP_ENABLE = 1
ROUGHNESS_GREEN = 3       # "Detect,Disabled,Red,Green,..." -- glTF keeps roughness in G
IMPORT_PASSES = 3


# --- GLB reading ------------------------------------------------------------------------------

def glb_json(path: pathlib.Path) -> dict:
	"""The JSON chunk of a binary glTF, read without reading its (large) binary chunk."""
	with path.open("rb") as handle:
		header = handle.read(20)
		if header[:4] != b"glTF":
			raise ValueError(f"not a GLB: {path}")
		length = struct.unpack("<I", header[12:16])[0]
		return json.loads(handle.read(length))


def image_roles(doc: dict) -> dict[str, dict]:
	"""{image name: {"role", "normal", "colour"}} from a glTF's materials. `normal` and `colour` name the
	images the same material uses for those, so an ORM map can find its limiter and its size cap."""
	images = doc.get("images", [])
	textures = doc.get("textures", [])
	names = [image.get("name") or f"Image_{index}" for index, image in enumerate(images)]
	roles: dict[str, dict] = {}

	def image_of(slot: dict | None) -> str | None:
		if not slot or slot.get("index") is None or slot["index"] >= len(textures):
			return None
		source = textures[slot["index"]].get("source")
		return names[source] if source is not None and source < len(names) else None

	def claim(name: str | None, role: str, material: dict) -> None:
		if name is None:
			return
		row = roles.setdefault(name, {"role": role, "normal": None, "colour": None})
		if ROLE_PRIORITY[role] > ROLE_PRIORITY[row["role"]]:
			row["role"] = role
		row["normal"] = row["normal"] or material["normal"]
		row["colour"] = row["colour"] or material["colour"]

	for material in doc.get("materials", []):
		pbr = material.get("pbrMetallicRoughness", {})
		slots = {"colour": image_of(pbr.get("baseColorTexture")), "normal": image_of(material.get("normalTexture"))}
		claim(slots["colour"], ROLE_COLOUR, slots)
		claim(image_of(material.get("emissiveTexture")), ROLE_COLOUR, slots)
		claim(slots["normal"], ROLE_NORMAL, slots)
		claim(image_of(pbr.get("metallicRoughnessTexture")), ROLE_ORM, slots)
		claim(image_of(material.get("occlusionTexture")), ROLE_ORM, slots)
	for name in names:
		roles.setdefault(name, {"role": ROLE_COLOUR, "normal": None, "colour": None})
	return roles


def extracted_images(folder: pathlib.Path) -> dict[pathlib.Path, dict]:
	"""{image file: its role row} for every image a GLB in `folder` embeds, as Godot names the extract.
	Each row also carries the extracted file of its material's normal and colour maps."""
	found: dict[pathlib.Path, dict] = {}
	files = {path.name: path for path in folder.iterdir() if path.suffix.lower() in IMAGE_SUFFIXES}
	for glb in sorted(folder.glob("*.glb")):
		roles = image_roles(glb_json(glb))
		by_name = {}
		for name in roles:
			match = next((path for file, path in files.items()
				if pathlib.Path(file).stem == f"{glb.stem}_{name}"), None)
			if match is not None:
				by_name[name] = match
		for name, path in by_name.items():
			row = roles[name]
			found[path] = {"role": row["role"], "glb": glb.name,
				"normal": by_name.get(row["normal"]) if row["normal"] else None,
				"colour": by_name.get(row["colour"]) if row["colour"] else None}
	return found


def image_size(path: pathlib.Path) -> tuple[int, int]:
	"""(width, height) of a PNG or JPEG, read from its header."""
	data = path.read_bytes()
	if data[:8] == b"\x89PNG\r\n\x1a\n":
		return struct.unpack(">II", data[16:24])
	index = 2
	while index + 9 < len(data):
		if data[index] != 0xFF:
			index += 1
			continue
		marker = data[index + 1]
		if marker in (0xC0, 0xC1, 0xC2):
			height, width = struct.unpack(">HH", data[index + 5:index + 9])
			return width, height
		index += 2 + struct.unpack(">H", data[index + 2:index + 4])[0]
	raise ValueError(f"unreadable image header: {path}")


# --- the settings -----------------------------------------------------------------------------

def res_path(path: pathlib.Path, project: pathlib.Path) -> str:
	"""`path` as a res:// path in `project`."""
	return "res://" + path.resolve().relative_to(project.resolve()).as_posix()


def params_for(image: pathlib.Path, row: dict, project: pathlib.Path) -> dict[str, str]:
	"""The [params] values (as written in a .import file) one GLB image must carry."""
	params = {"compress/mode": str(COMPRESS_VRAM), "compress/high_quality": "false",
		"mipmaps/generate": "true", "compress/normal_map": "0", "roughness/mode": "0",
		"roughness/src_normal": '""', "process/size_limit": "0"}
	if row["role"] == ROLE_NORMAL:
		params["compress/normal_map"] = str(NORMAL_MAP_ENABLE)
		params["roughness/mode"] = "1"
	elif row["role"] == ROLE_ORM:
		params["compress/normal_map"] = "2"
		if row["normal"] is not None:
			params["roughness/mode"] = str(ROUGHNESS_GREEN)
			params["roughness/src_normal"] = '"%s"' % res_path(row["normal"], project)
		if row["colour"] is not None:
			colour = max(image_size(row["colour"]))
			if max(image_size(image)) > colour:
				params["process/size_limit"] = str(colour)
	else:
		params["compress/normal_map"] = "2"
		params["roughness/mode"] = "1"
	return params


def set_params(text: str, params: dict[str, str]) -> str:
	"""`text` (a .import file) with each [params] key set, in place where present, appended where not."""
	lines = text.splitlines()
	try:
		start = lines.index("[params]") + 1
	except ValueError:
		lines += ["", "[params]"]
		start = len(lines)
	end = next((i for i in range(start, len(lines)) if lines[i].startswith("[")), len(lines))
	seen = set()
	for i in range(start, end):
		key = lines[i].split("=", 1)[0]
		if key in params:
			lines[i] = f"{key}={params[key]}"
			seen.add(key)
	missing = [f"{key}={value}" for key, value in params.items() if key not in seen]
	while end > start and lines[end - 1] == "":
		end -= 1
	lines[end:end] = missing
	return "\n".join(lines) + "\n"


KEEP_TEXT = '[remap]\n\nimporter="keep"\n'
TEXTURE_REMAP = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n'


def plan(assets: pathlib.Path, project: pathlib.Path) -> dict[pathlib.Path, tuple[str, str]]:
	"""{.import file: (role, the text it must hold)} for every staged image. A GLB image with no .import
	yet is skipped: Godot writes one when it extracts the image, on the next import (run again then)."""
	wanted: dict[pathlib.Path, tuple[str, str]] = {}
	folders = sorted({path.parent for path in assets.rglob("*") if path.suffix.lower() in IMAGE_SUFFIXES})
	for folder in folders:
		extracted = extracted_images(folder)
		for image in sorted(path for path in folder.iterdir() if path.suffix.lower() in IMAGE_SUFFIXES):
			settings = image.with_name(image.name + ".import")
			if image not in extracted:
				wanted[settings] = (ROLE_RAW, KEEP_TEXT)
			elif settings.is_file():
				current = settings.read_text()
				base = TEXTURE_REMAP if 'importer="keep"' in current else current
				wanted[settings] = (extracted[image]["role"], set_params(base, params_for(image, extracted[image], project)))
	return wanted


def apply(assets: pathlib.Path = ASSETS, project: pathlib.Path = PROJECT, write: bool = True) -> dict:
	"""Bring every staged image's .import to the rule. Returns the count per role and the files changed."""
	counts: dict = {ROLE_COLOUR: 0, ROLE_NORMAL: 0, ROLE_ORM: 0, ROLE_RAW: 0, "changed": []}
	if not assets.is_dir():
		return counts
	for settings, (role, text) in plan(assets, project).items():
		counts[role] += 1
		current = settings.read_text() if settings.is_file() else None
		if current != text:
			counts["changed"].append(settings)
			if write:
				settings.write_text(text)
	return counts


def godot_import(godot: str, project: pathlib.Path) -> None:
	"""One headless import of the project; refuses on a failed run."""
	completed = subprocess.run([godot, "--headless", "--path", str(project), "--import"],
		capture_output=True, text=True, check=False)
	if completed.returncode != 0:
		raise RuntimeError(f"godot --import failed ({completed.returncode}):\n{completed.stderr[-4000:]}")


def settle(godot: str, assets: pathlib.Path = ASSETS, project: pathlib.Path = PROJECT) -> dict:
	"""Import, rewrite, reimport, until a rewrite changes nothing. The first import extracts the GLBs'
	images (and writes their .import files); the next picks up the rewritten settings. The counts'
	`changed` lists every file rewritten on the way."""
	changed: list[pathlib.Path] = []
	for _ in range(IMPORT_PASSES):
		godot_import(godot, project)
		counts = apply(assets, project)
		if not counts["changed"]:
			counts["changed"] = changed
			return counts
		changed += counts["changed"]
	raise RuntimeError(f"texture settings did not settle after {IMPORT_PASSES} imports")


def main() -> int:
	"""Rewrite, check or settle the staged textures' import settings."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--assets", type=pathlib.Path, default=ASSETS)
	parser.add_argument("--project", type=pathlib.Path, default=PROJECT)
	parser.add_argument("--check", action="store_true", help="change nothing; exit 1 if anything would change")
	parser.add_argument("--godot", help="the Godot editor binary: import, rewrite and reimport until stable")
	args = parser.parse_args()
	if args.godot and not args.check:
		counts = settle(args.godot, args.assets, args.project)
	else:
		counts = apply(args.assets, args.project, write=not args.check)
	print(f"demo_texture_imports: {counts[ROLE_COLOUR]} colour, {counts[ROLE_NORMAL]} normal, {counts[ROLE_ORM]} "
		f"roughness (VRAM compressed); {counts[ROLE_RAW]} kept as files; {len(counts['changed'])} "
		f"{'would change' if args.check else 'changed'}")
	return 1 if args.check and counts["changed"] else 0


if __name__ == "__main__":
	sys.exit(main())
