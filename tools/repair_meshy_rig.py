#!/usr/bin/env python3
"""Repair the rigged and animated GLBs Meshy's auto-rigger produces. Decision 0190.

Meshy's rig step damages two things that its own L0 remesh got right:

  * THE MATERIAL. It keeps only the colour map, then sets no metallic value (glTF's
	default is metallic 1.0), wires the colour map in a second time as full emission,
	sets KHR_materials_specular to 2.0, and drops the L0's roughness and normal maps.
	Every creature renders as glossy, self-lit metal.
  * THE HEIGHT. `height_meters` scales the LONGEST rest-pose dimension, not the height,
	so a creature wider than tall in T-pose comes out short -- both moles by ~18%.

This edits the glTF directly rather than round-tripping it through Blender, which would
re-encode textures and re-sample animation. Everything already in the file survives
byte for byte; the L0's two maps are appended, the material is rewritten, and the scene's
single root is scaled. The source file is never modified.

SAFETY. The L0's maps are only valid if the rigged mesh shares the L0's UV atlas. That
is PROVED, not assumed: the rigged colour texture must be byte-identical to the L0's, or
the file is refused.

	python3 tools/repair_meshy_rig.py              # repair the whole creature library
	python3 tools/repair_meshy_rig.py --dry-run    # measure and report, write nothing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "assets/library/creature"
MANIFEST = ROOT / "docs/art-reference/asset_library/repaired.json"
DIMENSIONS = ROOT / "godot/assets/lookdev/lookdev_dimensions.gd"

GLB_MAGIC = 0x46546C67  # "glTF"
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942
UNITS_PER_METRE = 1024
HEIGHT_TOLERANCE_M = 0.001
STAMP = "redwall_rig_repair"
STAMP_VERSION = 1
DROPPED_EXTENSIONS = ("KHR_materials_specular", "KHR_materials_ior")


class RepairRefused(Exception):
	"""A file this tool must not touch, with the reason."""


def read_glb(data: bytes) -> tuple[dict, bytes]:
	"""Split a binary glTF into its JSON document and its BIN chunk."""
	magic, version, length = struct.unpack_from("<III", data, 0)
	if magic != GLB_MAGIC or version != 2 or length != len(data):
		raise RepairRefused("not a glTF 2.0 binary of the declared length")
	json_len, json_type = struct.unpack_from("<II", data, 12)
	if json_type != CHUNK_JSON:
		raise RepairRefused("first chunk is not JSON")
	doc = json.loads(data[20:20 + json_len])
	offset = 20 + json_len
	bin_len, bin_type = struct.unpack_from("<II", data, offset)
	if bin_type != CHUNK_BIN:
		raise RepairRefused("second chunk is not BIN")
	return doc, data[offset + 8:offset + 8 + bin_len]


def write_glb(doc: dict, binary: bytes) -> bytes:
	"""Assemble a binary glTF, padding JSON with spaces and BIN with zeros to 4 bytes."""
	binary = binary + b"\x00" * (-len(binary) % 4)
	doc["buffers"][0]["byteLength"] = len(binary)
	text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
	text += b" " * (-len(text) % 4)
	total = 12 + 8 + len(text) + 8 + len(binary)
	header = struct.pack("<III", GLB_MAGIC, 2, total)
	return (header + struct.pack("<II", len(text), CHUNK_JSON) + text
			+ struct.pack("<II", len(binary), CHUNK_BIN) + binary)


def image_bytes(doc: dict, binary: bytes, image: int) -> bytes:
	"""The encoded bytes of one embedded image."""
	view = doc["bufferViews"][doc["images"][image]["bufferView"]]
	start = view.get("byteOffset", 0)
	return binary[start:start + view["byteLength"]]


def texture_image(doc: dict, texture_ref: dict) -> int:
	"""The image index behind a material's texture reference."""
	return doc["textures"][texture_ref["index"]]["source"]


def append_texture(doc: dict, binary: bytes, data: bytes, mime: str,
				   name: str) -> tuple[bytes, int]:
	"""Append one image to the BIN chunk as a new bufferView, image and texture."""
	binary = binary + b"\x00" * (-len(binary) % 4)
	doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(data)})
	doc["images"].append({"bufferView": len(doc["bufferViews"]) - 1, "mimeType": mime,
						  "name": name})
	sampler = {"sampler": 0} if doc.get("samplers") else {}
	doc["textures"].append({**sampler, "source": len(doc["images"]) - 1})
	return binary + data, len(doc["textures"]) - 1


def l0_maps(l0_doc: dict, l0_bin: bytes) -> dict:
	"""The L0's colour, roughness and normal images, found through its material, not names."""
	material = l0_doc["materials"][0]
	pbr = material["pbrMetallicRoughness"]
	out = {}
	for key, ref in (("base", pbr["baseColorTexture"]),
					 ("mr", pbr["metallicRoughnessTexture"]),
					 ("normal", material["normalTexture"])):
		image = texture_image(l0_doc, ref)
		out[key] = (image_bytes(l0_doc, l0_bin, image),
					l0_doc["images"][image].get("mimeType", "image/png"))
	return out


def prove_shared_atlas(doc: dict, binary: bytes, maps: dict) -> None:
	"""Refuse unless every material's colour map is the L0's colour map, byte for byte."""
	for material in doc["materials"]:
		ref = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
		if ref is None:
			raise RepairRefused("a material has no colour map to compare")
		if image_bytes(doc, binary, texture_image(doc, ref)) != maps["base"][0]:
			raise RepairRefused("colour map differs from the L0's; the UV atlas is not proved shared")


def repair_materials(doc: dict, mr_texture: int, normal_texture: int) -> None:
	"""Dielectric rough cloth: the L0's roughness and normal maps, no emission, no extensions."""
	for material in doc["materials"]:
		pbr = material.setdefault("pbrMetallicRoughness", {})
		pbr["metallicFactor"] = 0.0
		pbr["roughnessFactor"] = 1.0
		pbr["metallicRoughnessTexture"] = {"index": mr_texture}
		material["normalTexture"] = {"index": normal_texture}
		material.pop("emissiveTexture", None)
		material.pop("emissiveFactor", None)
		for name in DROPPED_EXTENSIONS:
			material.get("extensions", {}).pop(name, None)
		if material.get("extensions") == {}:
			del material["extensions"]
	_prune_extensions_used(doc)


def _prune_extensions_used(doc: dict) -> None:
	"""Drop declared extensions nothing in the document uses any more."""
	used = doc.get("extensionsUsed", [])
	live = [name for name in used if name not in DROPPED_EXTENSIONS
			or any(name in m.get("extensions", {}) for m in doc["materials"])]
	if live:
		doc["extensionsUsed"] = live
	else:
		doc.pop("extensionsUsed", None)


def geometry_height_m(doc: dict) -> float:
	"""Y extent of every mesh's POSITION accessor: the bind-pose height at the export's root scale."""
	lows, highs = [], []
	for mesh in doc["meshes"]:
		for primitive in mesh["primitives"]:
			accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
			lows.append(accessor["min"][1])
			highs.append(accessor["max"][1])
	return max(highs) - min(lows)


def root_scale(doc: dict) -> float:
	"""The scene root's uniform scale. Refuses a non-uniform one."""
	node = doc["nodes"][doc["scenes"][doc.get("scene", 0)]["nodes"][0]]
	sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
	if abs(sx - sy) > 1e-9 * abs(sx) or abs(sx - sz) > 1e-9 * abs(sx):
		raise RepairRefused("scene root scale is not uniform")
	return sx


def drawn_height_m(output: bytes, source: bytes) -> float:
	"""The output's bind-pose height, measured from the two FILES, not from the recorded factor.

	The geometry is untouched by the repair, so the drawn height is the source extent times the
	ratio of the output's root scale to the source's. Reading both back from their bytes keeps
	this check independent of the number the repair decided to write.
	"""
	out_doc, _ = read_glb(output)
	src_doc, _ = read_glb(source)
	return geometry_height_m(src_doc) * root_scale(out_doc) / root_scale(src_doc)


def scale_root(doc: dict, factor: float) -> None:
	"""Uniformly scale the scene's single root, which carries the skeleton and the skinned mesh.

	A skinned vertex is drawn at joint_world * inverse_bind * v. Scaling the common root
	multiplies every joint_world by the same S(k), and at bind pose joint_world * inverse_bind
	is the identity, so the whole creature scales by k about the origin -- its feet.
	"""
	roots = doc["scenes"][doc.get("scene", 0)]["nodes"]
	if len(roots) != 1:
		raise RepairRefused(f"expected one scene root, found {len(roots)}")
	node = doc["nodes"][roots[0]]
	if "matrix" in node:
		raise RepairRefused("scene root uses a matrix, not TRS")
	node["scale"] = [s * factor for s in node.get("scale", [1.0, 1.0, 1.0])]


def species_heights_m(source: str) -> dict[str, float]:
	"""DEC-039's heights from lookdev_dimensions.gd, the one authoritative copy (1/1024 m)."""
	keys = re.search(r"const SPECIES_KEY:[^=]*=\s*\[(.*?)\]", source, re.S)
	units = re.search(r"const SPECIES_HEIGHT_U:[^=]*=\s*\[(.*?)\]", source, re.S)
	if keys is None or units is None:
		raise RepairRefused("lookdev_dimensions.gd no longer declares SPECIES_KEY/SPECIES_HEIGHT_U")
	names = re.findall(r'&"(\w+)"', keys.group(1))
	values = [int(v) for v in re.findall(r"\d+", units.group(1))]
	if len(names) != len(values):
		raise RepairRefused("SPECIES_KEY and SPECIES_HEIGHT_U disagree in length")
	return {name: value / UNITS_PER_METRE for name, value in zip(names, values)}


def repair(rigged: bytes, l0: bytes, target_m: float) -> tuple[bytes, dict]:
	"""Repair one rigged or animated GLB against its L0. Returns the new file and a report."""
	doc, binary = read_glb(rigged)
	if STAMP in doc.get("asset", {}).get("extras", {}):
		raise RepairRefused("already repaired; repair the original, not an output")
	maps = l0_maps(*read_glb(l0))
	prove_shared_atlas(doc, binary, maps)
	original_bin = binary
	binary, mr = append_texture(doc, binary, *maps["mr"], "l0_metallic_roughness")
	binary, normal = append_texture(doc, binary, *maps["normal"], "l0_normal")
	repair_materials(doc, mr, normal)
	before = geometry_height_m(doc)
	factor = 1.0 if abs(before - target_m) <= HEIGHT_TOLERANCE_M else target_m / before
	if factor != 1.0:
		scale_root(doc, factor)
	doc.setdefault("asset", {}).setdefault("extras", {})[STAMP] = {
		"version": STAMP_VERSION, "height_scale": factor, "target_height_m": target_m,
		"source_sha256": hashlib.sha256(rigged).hexdigest()}
	out = write_glb(doc, binary)
	if not read_glb(out)[1].startswith(original_bin):
		raise RepairRefused("original BIN data did not survive intact")
	after = drawn_height_m(out, rigged)
	if abs(after - target_m) > HEIGHT_TOLERANCE_M:
		raise RepairRefused(f"repaired height {after:.4f} m misses the target {target_m:.4f} m")
	return out, {"height_before_m": round(before, 4), "height_after_m": round(after, 4),
				 "height_scale": factor}


def _sha(data: bytes) -> str:
	"""SHA-256 of a byte string, hex."""
	return hashlib.sha256(data).hexdigest()


def repair_library(library: pathlib.Path, heights: dict[str, float], dry_run: bool) -> list[dict]:
	"""Repair every rigged.glb and anim_*.glb under each creature, writing to <key>/repaired/."""
	rows = []
	for key_dir in sorted(p for p in library.iterdir() if (p / "l0.glb").exists()):
		sources = sorted(key_dir.glob("anim_*.glb")) + sorted(key_dir.glob("rigged.glb"))
		if not sources:
			continue
		target = heights[key_dir.name.split("_")[0]]
		l0 = (key_dir / "l0.glb").read_bytes()
		for source in sources:
			data = source.read_bytes()
			out, report = repair(data, l0, target)
			dest = key_dir / "repaired" / source.name
			if not dry_run:
				dest.parent.mkdir(exist_ok=True)
				dest.write_bytes(out)
			rows.append({"key": key_dir.name, "file": source.name, "target_height_m": round(target, 4),
						 **report, "source_sha256": _sha(data), "output_sha256": _sha(out),
						 "output_bytes": len(out)})
	return rows


def main() -> int:
	"""Repair the library and write the manifest, or report what would change."""
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("--library", type=pathlib.Path, default=LIBRARY)
	parser.add_argument("--manifest", type=pathlib.Path, default=MANIFEST)
	parser.add_argument("--dry-run", action="store_true", help="measure and report; write nothing")
	args = parser.parse_args()
	heights = species_heights_m(DIMENSIONS.read_text(encoding="utf-8"))
	try:
		rows = repair_library(args.library, heights, args.dry_run)
	except RepairRefused as refused:
		print(f"repair_meshy_rig: REFUSED -- {refused}")
		return 1
	rescaled = sorted({(r["key"], r["height_scale"]) for r in rows if r["height_scale"] != 1.0})
	print(f"repair_meshy_rig: {len(rows)} files repaired{' (dry run)' if args.dry_run else ''}; "
		  f"rescaled: {[(k, round(f, 4)) for k, f in rescaled] or 'none'}")
	if not args.dry_run:
		args.manifest.write_text(json.dumps({"tool": "tools/repair_meshy_rig.py", "decision": "0190",
											 "count": len(rows), "files": rows}, indent=1) + "\n")
	return 0


if __name__ == "__main__":
	sys.exit(main())
