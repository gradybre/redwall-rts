#!/usr/bin/env python3
"""Self-test for tools/repair_meshy_rig.py (decision 0190).

NEGATIVE TESTS COME FIRST AND OUTNUMBER THE POSITIVE ONES. The repair edits 110 files
of paid-for art; the ways it must refuse matter more than the way it succeeds:

  N01  a colour map that is not the L0's, byte for byte, refuses. The L0's roughness and
       normal maps are only valid on a shared UV atlas, and that is the only proof of one.
  N02  an already-repaired file refuses, so an output can never be repaired twice.
  N03  two scene roots refuse: scaling one would leave the other creature behind.
  N04  a matrix-transformed root refuses rather than being guessed at.
  N05  a non-uniform root scale refuses; a uniform repair cannot be proved on it.
  N06  SPECIES_KEY and SPECIES_HEIGHT_U disagreeing in length refuses.
  N07  a missing SPECIES_HEIGHT_U refuses rather than falling back to a copied number.

EXPECTED VALUES ARE LITERALS, NOT RECOMPUTATIONS. The rescaled root is checked against
0.018, not against `0.01 * factor` -- a test that recomputes the factor agrees with the
code by construction, the symmetric blindness this project has hit seven times. The
written GLB is read back with `struct`, not with the module's own `read_glb`.

EVERY FIXTURE IS SYNTHETIC. The one real file read is lookdev_dimensions.gd, and only read.
"""

from __future__ import annotations

import json
import pathlib
import struct
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import repair_meshy_rig as rig  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
CASES: list[str] = []
FAILURES: list[str] = []

BASE = b"\x89PNG-fixture-colour-map-bytes"
MR = b"\x89PNG-fixture-roughness-bytes!"
NORMAL = b"\x89PNG-fixture-normal-map-bytes"


def check(name: str, condition: bool) -> None:
	"""Record one named check."""
	CASES.append(name)
	if not condition:
		FAILURES.append(name)


def _glb(doc: dict, blobs: list[bytes]) -> bytes:
	"""Pack `blobs` into one BIN as consecutive 4-aligned bufferViews, then write a GLB."""
	binary = b""
	doc["bufferViews"] = []
	for blob in blobs:
		binary += b"\x00" * (-len(binary) % 4)
		doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(blob)})
		binary += blob
	doc["buffers"] = [{"byteLength": len(binary)}]
	return rig.write_glb(doc, binary)


def _rigged(colour: bytes = BASE, extent_y: float = 0.5, roots: int = 1, root: dict | None = None) -> bytes:
	"""A Meshy-shaped rigged GLB: metal by default, colour doubled as emission, specular x2."""
	root_node = root if root is not None else {"name": "Armature", "scale": [0.01, 0.01, 0.01], "children": [0, 1]}
	nodes = [{"name": "Hips", "translation": [0.0, 45.0, 0.0]}, {"name": "char1", "mesh": 0, "skin": 0}, root_node]
	scene_nodes = [2] if roots == 1 else [2, 0]
	doc = {
		"asset": {"version": "2.0", "generator": "fixture"}, "scene": 0,
		"scenes": [{"nodes": scene_nodes}], "nodes": nodes,
		"skins": [{"joints": [0]}],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "material": 0}]}],
		"accessors": [{"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3",
			"min": [-0.1, 0.0, -0.1], "max": [0.1, extent_y, 0.1]}],
		"images": [{"bufferView": 0, "mimeType": "image/png", "name": "texture_0"}],
		"samplers": [{"magFilter": 9729, "minFilter": 9987}],
		"textures": [{"sampler": 0, "source": 0}, {"sampler": 0, "source": 0}],
		"materials": [{"name": "Material_1", "emissiveFactor": [1, 1, 1], "emissiveTexture": {"index": 0},
			"extensions": {"KHR_materials_specular": {"specularColorFactor": [2.0, 2.0, 2.0]},
				"KHR_materials_ior": {"ior": 1.45}},
			"pbrMetallicRoughness": {"baseColorTexture": {"index": 1}}}],
		"extensionsUsed": ["KHR_materials_specular", "KHR_materials_ior"],
	}
	return _glb(doc, [colour, b"\x00" * 36])


def _l0() -> bytes:
	"""An L0 the way Meshy's remesh writes it: normal, colour and metallic-roughness maps."""
	doc = {
		"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"mesh": 0}],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "material": 0}]}],
		"accessors": [{"bufferView": 3, "componentType": 5126, "count": 3, "type": "VEC3",
			"min": [0, 0, 0], "max": [1, 1, 1]}],
		"images": [{"bufferView": 0, "mimeType": "image/png", "name": "normal"},
			{"bufferView": 1, "mimeType": "image/png", "name": "texture_0"},
			{"bufferView": 2, "mimeType": "image/png", "name": "texture_0_metallic_roughness"}],
		"samplers": [{}],
		"textures": [{"sampler": 0, "source": 0}, {"sampler": 0, "source": 1}, {"sampler": 0, "source": 2}],
		"materials": [{"normalTexture": {"index": 0}, "pbrMetallicRoughness":
			{"baseColorTexture": {"index": 1}, "metallicRoughnessTexture": {"index": 2}}}],
	}
	return _glb(doc, [NORMAL, BASE, MR, b"\x00" * 36])


def _refuses(name: str, action) -> None:
	"""Check that `action` raises RepairRefused, and nothing else."""
	try:
		action()
	except rig.RepairRefused:
		check(name, True)
		return
	check(name + " (did not refuse)", False)


def _raw(glb: bytes) -> tuple[dict, bytes]:
	"""Read a GLB back with struct alone -- independent of the module under test."""
	json_len = struct.unpack_from("<I", glb, 12)[0]
	doc = json.loads(glb[20:20 + json_len])
	bin_len = struct.unpack_from("<I", glb, 20 + json_len)[0]
	return doc, glb[28 + json_len:28 + json_len + bin_len]


def _image(doc: dict, binary: bytes, texture_ref: dict) -> bytes:
	"""Resolve a texture reference to its bytes, by hand."""
	view = doc["bufferViews"][doc["images"][doc["textures"][texture_ref["index"]]["source"]]["bufferView"]]
	return binary[view["byteOffset"]:view["byteOffset"] + view["byteLength"]]


# --- negative tests ---------------------------------------------------------------------

def test_n01_a_different_colour_map_refuses() -> None:
	"""The L0's maps only fit a shared atlas; one differing byte is enough to refuse."""
	_refuses("N01 colour map differing by one byte refuses",
		lambda: rig.repair(_rigged(colour=BASE[:-1] + b"?"), _l0(), 0.5))


def test_n02_an_output_cannot_be_repaired_again() -> None:
	"""Repairing an output would append the maps twice and rescale twice."""
	once, _ = rig.repair(_rigged(), _l0(), 0.5)
	_refuses("N02 an already-repaired file refuses", lambda: rig.repair(once, _l0(), 0.5))


def test_n03_two_scene_roots_refuse() -> None:
	"""Scaling one of two roots would leave half the creature behind."""
	_refuses("N03 two scene roots refuse", lambda: rig.repair(_rigged(extent_y=0.3, roots=2), _l0(), 0.9))


def test_n04_a_matrix_root_refuses() -> None:
	"""A matrix root is not scaled by guesswork."""
	root = {"name": "Armature", "matrix": [0.01, 0, 0, 0, 0, 0.01, 0, 0, 0, 0, 0.01, 0, 0, 0, 0, 1], "children": [0, 1]}
	_refuses("N04 matrix root refuses", lambda: rig.repair(_rigged(extent_y=0.3, root=root), _l0(), 0.9))


def test_n05_a_non_uniform_root_refuses() -> None:
	"""A non-uniform root has no single height scale to prove."""
	root = {"name": "Armature", "scale": [0.01, 0.02, 0.01], "children": [0, 1]}
	_refuses("N05 non-uniform root refuses", lambda: rig.repair(_rigged(extent_y=0.3, root=root), _l0(), 0.9))


def test_n06_mismatched_species_columns_refuse() -> None:
	"""Five keys and four heights is a broken table, not a partial one."""
	text = 'const SPECIES_KEY: Array[StringName] = [&"a", &"b"]\nconst SPECIES_HEIGHT_U: Array[int] = [1024]\n'
	_refuses("N06 SPECIES_KEY/SPECIES_HEIGHT_U length mismatch refuses", lambda: rig.species_heights_m(text))


def test_n07_a_missing_height_column_refuses() -> None:
	"""No authoritative column means no repair, never a remembered number."""
	_refuses("N07 missing SPECIES_HEIGHT_U refuses",
		lambda: rig.species_heights_m('const SPECIES_KEY: Array[StringName] = [&"a"]\n'))


# --- positive tests ---------------------------------------------------------------------

def test_material_is_repaired_with_the_l0s_own_maps() -> None:
	"""Dielectric, rough, lit only by the sun, and carrying the L0's exact map bytes."""
	doc, binary = _raw(rig.repair(_rigged(), _l0(), 0.5)[0])
	material = doc["materials"][0]
	pbr = material["pbrMetallicRoughness"]
	check("metallicFactor is 0.0", pbr.get("metallicFactor") == 0.0)
	check("roughnessFactor is 1.0, so the map decides", pbr.get("roughnessFactor") == 1.0)
	check("roughness map is the L0's bytes", _image(doc, binary, pbr["metallicRoughnessTexture"]) == MR)
	check("normal map is the L0's bytes", _image(doc, binary, material["normalTexture"]) == NORMAL)
	check("colour map is untouched", _image(doc, binary, pbr["baseColorTexture"]) == BASE)
	check("no emissive texture", "emissiveTexture" not in material)
	check("no emissive factor", "emissiveFactor" not in material)
	check("no specular or ior extension left", "extensions" not in material)
	check("extensionsUsed no longer declares them", "extensionsUsed" not in doc)


def test_a_short_rig_is_rescaled_to_its_target() -> None:
	"""Extent 0.5 m against a 0.9 m target: the root becomes 0.018, a literal, not 0.01*factor."""
	source = _rigged(extent_y=0.5)
	out, report = rig.repair(source, _l0(), 0.9)
	scale = _raw(out)[0]["nodes"][2]["scale"]
	check("root scale is 0.018 on every axis", all(abs(s - 0.018) < 1e-12 for s in scale))
	check("geometry itself is untouched", _raw(out)[0]["accessors"][0]["max"][1] == 0.5)
	check("reported height after is 0.9", report["height_after_m"] == 0.9)


def test_a_rig_already_at_height_is_not_rescaled() -> None:
	"""Within one millimetre the root is left exactly as exported."""
	out, report = rig.repair(_rigged(extent_y=0.9), _l0(), 922 / 1024)
	check("root scale stays exactly 0.01", _raw(out)[0]["nodes"][2]["scale"] == [0.01, 0.01, 0.01])
	check("reported scale is exactly 1.0", report["height_scale"] == 1.0)


def test_original_data_survives_and_the_glb_is_well_formed() -> None:
	"""Header length, 4-byte chunk alignment, and the source BIN as an intact prefix."""
	source = _rigged()
	out, _ = rig.repair(source, _l0(), 0.5)
	magic, version, total = struct.unpack_from("<III", out, 0)
	json_len = struct.unpack_from("<I", out, 12)[0]
	bin_len = struct.unpack_from("<I", out, 20 + json_len)[0]
	check("magic and version", magic == 0x46546C67 and version == 2)
	check("declared length is the file length", total == len(out))
	check("both chunks 4-byte aligned", json_len % 4 == 0 and bin_len % 4 == 0)
	check("source BIN survives as a prefix", _raw(out)[1].startswith(_raw(source)[1]))
	check("the source file's hash is stamped", json.dumps(_raw(out)[0]["asset"]["extras"]).count("source_sha256") == 1)


def test_the_real_species_table_parses_to_dec_039() -> None:
	"""The authoritative 1/1024 m column, read from the file that owns it."""
	heights = rig.species_heights_m((ROOT / "godot/assets/lookdev/lookdev_dimensions.gd").read_text(encoding="utf-8"))
	check("five species", sorted(heights) == ["badger", "mole", "mouse", "otter", "squirrel"])
	check("mouse is 1024 u", heights["mouse"] == 1024 / 1024)
	check("mole is 922 u", heights["mole"] == 922 / 1024)
	check("badger is 2611 u", heights["badger"] == 2611 / 1024)


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
	print("test_repair_meshy_rig: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
