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
  N08  a scale sampler shared with another channel, or cubic, refuses: resetting its keys
       would move the other channel, or turn tangents into scales.
  N10  an authored clip named like one of Meshy's refuses: both would be written to repaired/<name>.
  N09  a creature whose species has no SPECIES_HEIGHT_U row refuses, naming the creature and
       the species, before ANY creature is written -- not a bare KeyError halfway through
       (the beaver did that before DEC-041, decision 0203).

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
import tempfile

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


def _library(root: pathlib.Path, keys: list[str]) -> pathlib.Path:
	"""A creature library on disk: each key with the fixture l0.glb and rigged.glb."""
	for key in keys:
		(root / key).mkdir()
		(root / key / "l0.glb").write_bytes(_l0())
		(root / key / "rigged.glb").write_bytes(_rigged())
	return root


def test_n09_an_unknown_species_refuses_before_anything_is_written() -> None:
	"""A species with no height row refuses by name; the known creature sorted before it is untouched."""
	with tempfile.TemporaryDirectory() as tmp:
		library = _library(pathlib.Path(tmp), ["mouse_a", "wolverine_b"])
		try:
			rig.repair_library(library, {"mouse": 0.5}, dry_run=False)
		except rig.RepairRefused as refused:
			reason = str(refused)
			check("N09 an unknown species refuses", True)
			check("N09 the reason names the creature", "wolverine_b" in reason)
			check("N09 the reason names the species", "species 'wolverine'" in reason)
			check("N09 the reason says where the row belongs", "SPECIES_HEIGHT_U" in reason)
		except KeyError:
			check("N09 an unknown species refuses (raised a bare KeyError)", False)
		else:
			check("N09 an unknown species refuses (did not refuse)", False)
		check("N09 nothing was written for the known creature", not (library / "mouse_a" / "repaired").exists())
		check("N09 nor for the unknown one", not (library / "wolverine_b" / "repaired").exists())


def test_n09_the_target_lookup_refuses_alone() -> None:
	"""species_target_m on its own: the first underscore splits the key; an unknown prefix refuses."""
	check("a known species resolves to its height", rig.species_target_m("beaver_bridgewright", {"beaver": 1.4}) == 1.4)
	_refuses("N09 an unknown species refuses in the lookup", lambda: rig.species_target_m("stoat_scout", {"beaver": 1.4}))


def test_n10_an_authored_clip_clashing_with_meshys_refuses() -> None:
	"""authored/anim_walk.glb beside Meshy's anim_walk.glb."""
	with tempfile.TemporaryDirectory() as tmp:
		library = _library(pathlib.Path(tmp), ["mouse_a"])
		(library / "mouse_a" / "anim_walk.glb").write_bytes(_rigged())
		(library / "mouse_a" / "authored").mkdir()
		(library / "mouse_a" / "authored" / "anim_walk.glb").write_bytes(_rigged())
		try:
			rig.repair_library(library, {"mouse": 0.5}, dry_run=True)
		except rig.RepairRefused as refused:
			check("N10 a clash refuses, naming the clip", "anim_walk.glb" in str(refused))
		else:
			check("N10 a clash refuses (did not refuse)", False)


def test_authored_clips_are_repaired_with_meshys_and_marked() -> None:
	"""authored/anim_swim.glb is repaired into repaired/, and its row says where it came from."""
	with tempfile.TemporaryDirectory() as tmp:
		library = _library(pathlib.Path(tmp), ["mouse_a"])
		(library / "mouse_a" / "anim_walk.glb").write_bytes(_rigged())
		(library / "mouse_a" / "authored").mkdir()
		(library / "mouse_a" / "authored" / "anim_swim.glb").write_bytes(_rigged())
		rows = rig.repair_library(library, {"mouse": 0.5}, dry_run=False)
		check("Meshy's clip, the authored one, then rigged.glb", [r["file"] for r in rows] == ["anim_walk.glb", "anim_swim.glb", "rigged.glb"])
		check("the authored clip is written to repaired/", (library / "mouse_a" / "repaired" / "anim_swim.glb").exists())
		check("only its row is marked authored", [r.get("source") for r in rows] == [None, "authored", None])


def test_a_known_library_repairs_every_creature() -> None:
	"""With every species known, both creatures are written, one row per file."""
	with tempfile.TemporaryDirectory() as tmp:
		library = _library(pathlib.Path(tmp), ["mouse_a", "mouse_b"])
		rows = rig.repair_library(library, {"mouse": 0.5}, dry_run=False)
		check("two creatures, one rigged.glb each", [r["key"] for r in rows] == ["mouse_a", "mouse_b"])
		check("each written to repaired/", all((library / k / "repaired" / "rigged.glb").exists() for k in ("mouse_a", "mouse_b")))
		check("each targets its species' height", all(r["target_height_m"] == 0.5 for r in rows))


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


def _ibm(doc: dict, binary: bytes) -> tuple:
	"""The first inverse bind matrix, read by hand."""
	view = doc["bufferViews"][doc["accessors"][doc["skins"][0]["inverseBindMatrices"]]["bufferView"]]
	return struct.unpack_from("<16f", binary, view["byteOffset"])


def test_a_short_rig_is_rescaled_to_its_target() -> None:
	"""Extent 0.5 m against a 0.9 m target: scale 0.01 x 1.8 = 0.018, folded out of the root."""
	source = _rigged(extent_y=0.5)
	out, report = rig.repair(source, _l0(), 0.9)
	doc, binary = _raw(out)
	check("the root is folded to scale 1", doc["nodes"][2]["scale"] == [1.0, 1.0, 1.0])
	check("Hips moves from 45 to 0.81 (45 x 0.018)", abs(doc["nodes"][0]["translation"][1] - 0.81) < 1e-9)
	check("the inverse bind becomes scale 0.018", all(abs(a - b) < 1e-7 for a, b in zip(_ibm(doc, binary),
		(0.018, 0, 0, 0, 0, 0.018, 0, 0, 0, 0, 0.018, 0, 0, 0, 0, 1))))
	check("geometry itself is untouched", doc["accessors"][0]["max"][1] == 0.5)
	check("reported height after is 0.9", report["height_after_m"] == 0.9)
	check("the folded scale is reported", abs(report["root_scale_folded"] - 0.018) < 1e-12)


def test_a_rig_already_at_height_is_not_rescaled() -> None:
	"""Within one millimetre no height factor is applied; the 0.01 is still folded."""
	out, report = rig.repair(_rigged(extent_y=0.9), _l0(), 922 / 1024)
	doc, _binary = _raw(out)
	check("reported scale is exactly 1.0", report["height_scale"] == 1.0)
	check("the root is folded to scale 1", doc["nodes"][2]["scale"] == [1.0, 1.0, 1.0])
	check("Hips moves from 45 to 0.45", abs(doc["nodes"][0]["translation"][1] - 0.45) < 1e-9)


def _animated_rig() -> bytes:
	"""Hips 45 cm up under a 0.01 root, a real inverse bind (T(0,-45,0) S(100)), and a clip that
	raises the hips to 50 cm. At that key the vertex (0, 0.45, 0) m is drawn at (0, 0.5, 0)."""
	doc, binary = _raw(_rigged(extent_y=0.9))
	ibm = struct.pack("<16f", 100, 0, 0, 0, 0, 100, 0, 0, 0, 0, 100, 0, 0, -45, 0, 1)
	times, keys = struct.pack("<2f", 0.0, 1.0), struct.pack("<6f", 0, 45, 0, 0, 50, 0)
	for blob, kind, count in ((ibm, "MAT4", 1), (times, "SCALAR", 2), (keys, "VEC3", 2)):
		binary += b"\x00" * (-len(binary) % 4)
		doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(blob)})
		doc["accessors"].append({"bufferView": len(doc["bufferViews"]) - 1, "componentType": 5126, "count": count, "type": kind})
		binary += blob
	doc["accessors"][-2].update({"min": [0.0], "max": [1.0]})
	doc["skins"][0]["inverseBindMatrices"] = len(doc["accessors"]) - 3
	doc["animations"] = [{"samplers": [{"input": len(doc["accessors"]) - 2, "output": len(doc["accessors"]) - 1}],
		"channels": [{"sampler": 0, "target": {"node": 0, "path": "translation"}}]}]
	doc["buffers"] = [{"byteLength": len(binary)}]
	return rig.write_glb(doc, binary)


def test_the_fold_draws_every_vertex_where_it_was_in_every_pose() -> None:
	"""After the fold: Hips key 0.5 m, inverse bind T(0,-0.45,0), so the vertex is still drawn at 0.5 m."""
	out, _report = rig.repair(_animated_rig(), _l0(), 922 / 1024)
	doc, binary = _raw(out)
	sampler = doc["animations"][0]["samplers"][0]
	view = doc["bufferViews"][doc["accessors"][sampler["output"]]["bufferView"]]
	keys = struct.unpack_from("<6f", binary, view["byteOffset"])
	check("the translation keys are scaled to metres", all(abs(a - b) < 1e-6 for a, b in zip(keys, (0, 0.45, 0, 0, 0.5, 0))))
	ibm = _ibm(doc, binary)
	check("the inverse bind is T(0, -0.45, 0) with unit basis", all(abs(a - b) < 1e-6 for a, b in zip(ibm,
		(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, -0.45, 0, 1))))
	drawn = keys[4] + ibm[13] + 0.45            # joint world T(0, key) * IBM * (0, 0.45, 0): all translations
	check("the vertex is drawn at 0.5 m at the raised key, as before the fold", abs(drawn - 0.5) < 1e-6)


def _scaled_idle(hips_scale: float, interpolation: str = "LINEAR", shared: bool = False) -> bytes:
	"""Meshy's idle clip: two Hips scale keys held at `hips_scale`, whose rest scale is 1."""
	doc, binary = _raw(_rigged(extent_y=0.9))
	times, keys = struct.pack("<2f", 0.033, 4.033), struct.pack("<6f", *([hips_scale] * 6))
	for blob, kind in ((times, "SCALAR"), (keys, "VEC3")):
		binary += b"\x00" * (-len(binary) % 4)
		doc["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(blob)})
		doc["accessors"].append({"bufferView": len(doc["bufferViews"]) - 1, "componentType": 5126, "count": 2, "type": kind})
		binary += blob
	doc["accessors"][-2].update({"min": [0.033], "max": [4.033]})
	channels = [{"sampler": 0, "target": {"node": 0, "path": "scale"}}]
	if shared:
		channels.append({"sampler": 0, "target": {"node": 1, "path": "scale"}})
	doc["animations"] = [{"name": "Armature|idle", "channels": channels, "samplers": [{"input": len(doc["accessors"]) - 2,
		"output": len(doc["accessors"]) - 1, "interpolation": interpolation}]}]
	doc["buffers"] = [{"byteLength": len(binary)}]
	return rig.write_glb(doc, binary)


def _scale_keys(out: bytes) -> tuple:
	"""The idle clip's six scale-key floats, read by hand."""
	doc, binary = _raw(out)
	view = doc["bufferViews"][doc["accessors"][doc["animations"][0]["samplers"][0]["output"]]["bufferView"]]
	return struct.unpack_from("<6f", binary, view["byteOffset"])


def test_n08_a_shared_or_cubic_scale_sampler_refuses() -> None:
	_refuses("N08 a scale sampler shared by two channels", lambda: rig.repair(_scaled_idle(1.1765, shared=True), _l0(), 0.9))
	_refuses("N08 a cubic scale sampler", lambda: rig.repair(_scaled_idle(1.1765, "CUBICSPLINE"), _l0(), 0.9))


def test_meshy_s_idle_hips_scale_is_reset_to_rest() -> None:
	"""Every Meshy idle clip holds the Hips at 1.1765: the creature idles 17.65% too large."""
	out, report = rig.repair(_scaled_idle(1.1765), _l0(), 0.9)
	check("the Hips scale keys are 1, the rest scale", all(abs(v - 1.0) < 1e-7 for v in _scale_keys(out)))
	check("one channel is reported reset", report["scale_channels_reset"] == 1)
	check("the stamp records it", _raw(out)[0]["asset"]["extras"][rig.STAMP]["scale_channels_reset"] == 1)


def test_a_scale_within_tolerance_is_left_alone() -> None:
	"""1.005 is within 1% of rest: its keys are not rewritten."""
	out, report = rig.repair(_scaled_idle(1.005), _l0(), 0.9)
	check("the keys are still 1.005", all(abs(v - 1.005) < 1e-6 for v in _scale_keys(out)))
	check("nothing is reported reset", report["scale_channels_reset"] == 0)


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


def test_the_real_species_table_parses_to_dec_039_and_dec_041() -> None:
	"""The authoritative 1/1024 m column, read from the file that owns it."""
	heights = rig.species_heights_m((ROOT / "godot/assets/lookdev/lookdev_dimensions.gd").read_text(encoding="utf-8"))
	check("six species: DEC-039's five and DEC-041's beaver",
		sorted(heights) == ["badger", "beaver", "mole", "mouse", "otter", "squirrel"])
	check("beaver is 1434 u", heights["beaver"] == 1434 / 1024)
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
