#!/usr/bin/env python3
"""Adversarial tests of source-bound measurement; fixtures are synthetic, not creature profiles."""
from __future__ import annotations

from fractions import Fraction
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from measure_underground_profiles import (
    Source, MeasurementRefused, STATES, MAX_SAMPLE_POSES, continuous_radius,
    bounded_bytes, coverage_refusals, hash_bytes, hierarchy_bounds, measure_bytes, measure_file,
    norm_upper_um, pose_worlds, sample_bounds, sampled_vertex,
)
from repair_meshy_rig import append_accessor, write_glb


def fixture(attachment: bool = True) -> tuple[dict, bytes]:
    """A skinned triangle rotating continuously, plus an independently transformed rigid attachment."""
    doc = {"asset": {"version": "2.0"}, "buffers": [{"byteLength": 0}], "bufferViews": [], "accessors": [],
           "nodes": [{"children": [1, 2]}, {}, {"mesh": 0, "skin": 0}], "scene": 0,
           "scenes": [{"nodes": [0]}], "meshes": [{"primitives": [{"attributes": {}}]}],
           "skins": [{"joints": [1]}], "animations": [{"samplers": [], "channels": []}]}
    binary = b""
    primitive = doc["meshes"][0]["primitives"][0]
    for name, values, component, kind in [
        ("POSITION", [(1., 0., 0.), (1., 1., 0.), (0., 0., 0.)], 5126, "VEC3"),
        ("JOINTS_0", [(0, 0, 0, 0)] * 3, 5121, "VEC4"),
        ("WEIGHTS_0", [(1., 0., 0., 0.)] * 3, 5126, "VEC4"),
    ]:
        binary, index = append_accessor(doc, binary, values, component, kind)
        primitive["attributes"][name] = index
    binary, times = append_accessor(doc, binary, [(0.,), (1.,)], 5126, "SCALAR")
    binary, rotations = append_accessor(doc, binary, [(0., 0., 0., 1.), (0., 1., 0., 0.)], 5126, "VEC4")
    doc["animations"][0]["samplers"].append({"input": times, "output": rotations, "interpolation": "LINEAR"})
    doc["animations"][0]["channels"].append({"sampler": 0, "target": {"node": 1, "path": "rotation"}})
    if attachment:
        doc["nodes"][0]["children"].append(3)
        doc["nodes"].append({"mesh": 1, "translation": [3., 0., 0.]})
        binary, position = append_accessor(doc, binary, [(0., 0., 0.), (1., 0., 0.), (0., 1., 0.)], 5126, "VEC3")
        doc["meshes"].append({"primitives": [{"attributes": {"POSITION": position}}]})
    return doc, binary


def source(doc: dict, binary: bytes) -> Source:
    """Parse exact fixture bytes through the same source gate as actual GLBs."""
    data = write_glb(doc, binary)
    return Source(data, hash_bytes(data))


class MeasurementTests(unittest.TestCase):
    """No test enables a gameplay profile or assumes fixture dimensions are production content."""

    def test_actual_bytes_required_hash_cannot_be_replaced_by_filename(self) -> None:
        doc, binary = fixture()
        data = write_glb(doc, binary)
        with self.assertRaisesRegex(MeasurementRefused, "SOURCE_HASH_MISMATCH"):
            Source(data, "0" * 64)
        with self.assertRaisesRegex(MeasurementRefused, "SOURCE_HASH_MISMATCH"):
            Source(data[:-1] + bytes([data[-1] ^ 1]), hash_bytes(data))

    def test_exact_norm_rounds_outward_at_and_between_integer_boundaries(self) -> None:
        self.assertEqual(norm_upper_um([Fraction(3), Fraction(4), Fraction(0)]), 5000000)
        self.assertEqual(norm_upper_um([Fraction(1, 1000001), Fraction(0), Fraction(0)]), 1)
        self.assertEqual(norm_upper_um([Fraction(1), Fraction(1), Fraction(0)]), 1414214)

    def test_rigid_attachment_is_included_and_extends_complete_bound(self) -> None:
        s = source(*fixture())
        radius, parts = continuous_radius(s)
        self.assertEqual(len(parts), 2)
        self.assertTrue(parts[0]["skinned"])
        self.assertFalse(parts[1]["skinned"])
        self.assertGreaterEqual(radius, 4000000)
        self.assertGreater(radius, continuous_radius(source(*fixture(False)))[0])

    def test_continuous_rotation_covers_pose_extrema_absent_from_endpoints(self) -> None:
        s = source(*fixture(False))
        radius, _ = continuous_radius(s)
        samples = sample_bounds(s, 2)["bounds_micrometres"]
        self.assertEqual(samples["z"], [0, 0])
        worlds = pose_worlds(s, .5)
        point = sampled_vertex(s.parts[0], 0, (1., 0., 0.), worlds, [worlds[1]])
        self.assertLess(point[2], -.99)
        self.assertLessEqual(math.sqrt(sum(v * v for v in point)) * 1000000, radius)

    def test_translation_scale_endpoint_enclosure_and_dense_pose_witness(self) -> None:
        doc, binary = fixture(False)
        animation = doc["animations"][0]
        for path, values in [("translation", [(0., 0., 0.), (2., -1., 0.)]), ("scale", [(1., 1., 1.), (2., 2., 2.)])]:
            binary, index = append_accessor(doc, binary, values, 5126, "VEC3")
            animation["samplers"].append({"input": animation["samplers"][0]["input"], "output": index})
            animation["channels"].append({"sampler": len(animation["samplers"]) - 1, "target": {"node": 1, "path": path}})
        s = source(doc, binary)
        radius, _ = continuous_radius(s)
        self.assertEqual(hierarchy_bounds(s)[1][0], 2)
        for step in range(101):
            worlds = pose_worlds(s, step / 100)
            for vertex, position in enumerate(s.parts[0]["positions"]):
                point = sampled_vertex(s.parts[0], vertex, position, worlds, [worlds[1]])
                self.assertLessEqual(math.sqrt(sum(v * v for v in point)) * 1000000, radius)

    def test_stored_nonunit_quaternion_gets_exact_operator_norm_allowance(self) -> None:
        doc, binary = fixture()
        doc["nodes"][3]["rotation"] = [0., 2., 0., 0.]
        s = source(doc, binary)
        self.assertEqual(hierarchy_bounds(s)[3][0], 7)
        self.assertGreaterEqual(continuous_radius(s)[0], 10000000)

    def test_actual_read_is_bounded_and_accepts_exact_capacity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "bytes"
            path.write_bytes(b"12345")
            with self.assertRaisesRegex(MeasurementRefused, "TEST_CAPACITY"):
                bounded_bytes(path, 4, "TEST_CAPACITY")
            self.assertEqual(bounded_bytes(path, 5, "TEST_CAPACITY"), b"12345")

    def test_glb_chunk_length_and_wrong_magic_are_named_refusals(self) -> None:
        doc, binary = fixture()
        data = write_glb(doc, binary)
        for corrupted in (b"BAD!" + data[4:], data + b"\0\0\0\0"):
            with self.assertRaisesRegex(MeasurementRefused, "GLB_FORMAT"):
                Source(corrupted, hash_bytes(corrupted))

    def test_fractional_normalization_refuses_instead_of_certifying_float_division(self) -> None:
        for component, maximum in ((5121, 255), (5123, 65535)):
            with self.subTest(component=component):
                doc, binary = fixture(False)
                binary, index = append_accessor(doc, binary, [(1, maximum - 1, 0, 0)] * 3, component, "VEC4")
                doc["accessors"][index]["normalized"] = True
                doc["meshes"][0]["primitives"][0]["attributes"]["WEIGHTS_0"] = index
                with self.assertRaisesRegex(MeasurementRefused, "NORMALIZATION_UNSUPPORTED"):
                    source(doc, binary)

    def test_cli_output_cannot_overwrite_read_only_source_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            original = b'{"clips": []}\n'
            path.write_bytes(original)
            completed = subprocess.run([sys.executable, str(Path(__file__).with_name("measure_underground_profiles.py")),
                                        "--asset-root", str(Path(directory) / "library"), "--manifest", str(path),
                                        "--output", str(path.parent / "." / path.name)],
                                       capture_output=True, text=True, check=False, timeout=10)
            self.assertEqual(completed.returncode, 1)
            self.assertIn("OUTPUT_OVERWRITES_SOURCE_MANIFEST", completed.stdout)
            self.assertEqual(path.read_bytes(), original)

    def test_additional_influence_sets_are_not_silently_dropped(self) -> None:
        doc, binary = fixture(False)
        doc["nodes"][0]["children"].append(3)
        doc["nodes"].append({"translation": [8., 0., 0.]})
        doc["skins"][0]["joints"].append(3)
        attrs = doc["meshes"][0]["primitives"][0]["attributes"]
        binary, attrs["JOINTS_1"] = append_accessor(doc, binary, [(1, 0, 0, 0)] * 3, 5121, "VEC4")
        binary, attrs["WEIGHTS_1"] = append_accessor(doc, binary, [(.5, 0., 0., 0.)] * 3, 5126, "VEC4")
        s = source(doc, binary)
        self.assertEqual(len(s.parts[0]["influences"]), 2)
        self.assertGreaterEqual(continuous_radius(s)[0], 12000000)

    def test_inverse_bind_matrix_is_part_of_the_proof(self) -> None:
        doc, binary = fixture(False)
        matrix = [1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 4., 0., 0., 1.]
        binary, index = append_accessor(doc, binary, [matrix], 5126, "MAT4")
        doc["skins"][0]["inverseBindMatrices"] = index
        self.assertGreaterEqual(continuous_radius(source(doc, binary))[0], 5000000)

    def test_sample_count_cannot_weaken_continuous_bounds(self) -> None:
        doc, binary = fixture()
        data = write_glb(doc, binary)
        one, two = measure_bytes(data, hash_bytes(data), 1), measure_bytes(data, hash_bytes(data), 2)
        self.assertEqual(one["continuous_bounds_micrometres"], two["continuous_bounds_micrometres"])
        self.assertFalse(one["admission_qualified"])
        self.assertEqual(one["status"], "PARTIAL_SOURCE_GEOMETRY")
        self.assertEqual(one["target_envelope_schema"], 2)
        self.assertIn("ERROR_OR_MARGIN_UNAUTHORED", one["not_ready_reasons"])

    def test_missing_legal_state_cannot_be_relabelled_as_complete(self) -> None:
        evidence, requirements = self._complete_coverage()
        evidence["qualified_states"].remove("RETREAT")
        self.assertIn("LEGAL_STATE_MAPPING_INCOMPLETE", coverage_refusals(evidence, requirements))
        requirements["states"].remove("RETREAT")
        self.assertIn("REQUIRED_STATE_SET_INCOMPLETE", coverage_refusals(evidence, requirements))

    def test_omitted_embedded_or_external_attachment_refuses(self) -> None:
        evidence, requirements = self._complete_coverage()
        evidence["included_primitives"].remove("attachment")
        self.assertIn("EMBEDDED_GEOMETRY_OMITTED", coverage_refusals(evidence, requirements))
        evidence["included_external_attachments"].clear()
        self.assertIn("EXTERNAL_ATTACHMENT_OMITTED", coverage_refusals(evidence, requirements))

    def test_understated_margin_fails_even_if_other_axes_cover_residual(self) -> None:
        evidence, requirements = self._complete_coverage()
        evidence["residual_error_units"] = 2
        requirements["margin_units"] = {"x": 2, "y": 1, "z": 2}
        self.assertIn("UNCOVERED_INTERPOLATION_ERROR", coverage_refusals(evidence, requirements))
        requirements["margin_units"]["y"] = 2
        self.assertNotIn("UNCOVERED_INTERPOLATION_ERROR", coverage_refusals(evidence, requirements))
        self.assertIn("RUNTIME_PROFILE_OWNER_BINDING_MISSING", coverage_refusals(evidence, requirements))

    def _complete_coverage(self) -> tuple[dict, dict]:
        """Synthetic metadata can pass local coverage rules but still never enables runtime admission."""
        return ({"qualified_states": list(STATES), "included_primitives": ["body", "attachment"],
                 "included_external_attachments": ["tool"], "residual_error_units": 0},
                {"states": list(STATES), "embedded_primitives": ["body", "attachment"],
                 "external_attachments": ["tool"], "margin_units": dict.fromkeys("xyz", 0), "source_asset_approved": True})

    def test_cubic_morph_and_external_extensions_refuse(self) -> None:
        for mutation, code in [
            (lambda d: d["animations"][0]["samplers"][0].update(interpolation="CUBICSPLINE"), "INTERPOLATION_UNSUPPORTED"),
            (lambda d: d["meshes"][0]["primitives"][0].update(targets=[{"POSITION": 0}]), "PRIMITIVE_UNSUPPORTED"),
            (lambda d: d.update(extensionsUsed=["EXT_mesh_gpu_instancing"]), "EXTENSION_UNSUPPORTED"),
        ]:
            doc, binary = fixture()
            mutation(doc)
            with self.assertRaisesRegex(MeasurementRefused, code):
                source(doc, binary)

    def test_cycle_and_scene_omission_refuse(self) -> None:
        doc, binary = fixture()
        doc["nodes"][1]["children"] = [0]
        with self.assertRaises(MeasurementRefused):
            source(doc, binary)
        doc, binary = fixture()
        doc["nodes"].append({})
        with self.assertRaisesRegex(MeasurementRefused, "SCENE_OMITS_NODES"):
            source(doc, binary)

    def test_accessor_range_and_capacity_refuse_before_decode(self) -> None:
        for field, value, code in [("count", 3000000, "ACCESSOR_COUNT"), ("byteOffset", 1000000, "ACCESSOR_BYTE_BOUNDS")]:
            doc, binary = fixture()
            doc["accessors"][0][field] = value
            with self.assertRaisesRegex(MeasurementRefused, code):
                source(doc, binary)

    def test_skin_pair_negative_weight_and_nonfinite_geometry_refuse(self) -> None:
        doc, binary = fixture()
        attrs = doc["meshes"][0]["primitives"][0]["attributes"]
        del attrs["WEIGHTS_0"]
        with self.assertRaisesRegex(MeasurementRefused, "SKIN_SET_PAIR"):
            source(doc, binary)
        for values, code in [([(-1., 0., 0., 0.)] * 3, "SKIN_NEGATIVE_WEIGHT"),
                             ([(float("nan"), 0., 0., 0.)] * 3, "NONFINITE_OR_EXTREME_GEOMETRY")]:
            doc, binary = fixture()
            binary, index = append_accessor(doc, binary, values, 5126, "VEC4")
            doc["meshes"][0]["primitives"][0]["attributes"]["WEIGHTS_0"] = index
            with self.assertRaisesRegex(MeasurementRefused, code):
                source(doc, binary)

    def test_file_measurement_never_writes_source(self) -> None:
        doc, binary = fixture()
        data = write_glb(doc, binary)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.glb"
            path.write_bytes(data)
            result = measure_file(path, hash_bytes(data), 1)
            self.assertEqual(path.read_bytes(), data)
            self.assertEqual(result["sha256"], hash_bytes(data))

    def test_invalid_source_and_sampling_budgets_refuse(self) -> None:
        with self.assertRaisesRegex(MeasurementRefused, "SOURCE_BYTE_CAPACITY"):
            Source(b"glTF", "0" * 64)
        s = source(*fixture())
        with self.assertRaisesRegex(MeasurementRefused, "SAMPLE_CAPACITY"):
            sample_bounds(s, MAX_SAMPLE_POSES + 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
