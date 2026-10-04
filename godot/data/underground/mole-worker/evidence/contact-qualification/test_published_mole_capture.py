#!/usr/bin/env python3
"""Negative published-artifact report cases; modified historical reports are deliberate synthetic test inputs."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("published_mole_native", HERE / "run_published_mole_capture.py")
R = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(R)


class PublishedNativeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads((HERE / "native-cardinal-program-v5/spec.json").read_text())
        cls.report = json.loads((HERE / "native-cardinal-program-v5/report.json").read_text())
        cls.report["published_catalog"] = dict(wire_sha256=R.WIRE_SHA, actor_sha256=R.M.IMAGE_SHA,
                basis_sha256=R.BASIS_SHA, content_revision=1, profile_count=18,
                pins=[value for index in range(18) for value in (index, 1, 1)], certificate_flags=[15] * 18,
                rendering_driver="opengl3", rendering_method="gl_compatibility", world_activation_qualified=False)
        cls.table = R.BASE.wire_timing(cls.spec)
        _, cls.contacts, _ = R.N.math_inputs()

    def test_actual_reviewed_publication_inputs_are_pinned(self):
        pins = R.publication_pins()
        self.assertEqual(pins[str(R.PUBLICATION / "mole-worker.ugprof")], R.WIRE_SHA)
        self.assertGreaterEqual(len(pins), 35)

    def test_review_packet_drift_refuses(self):
        with patch.object(R.BASE, "digest", return_value="0" * 64), self.assertRaisesRegex(ValueError, "REVIEW_PACKET"):
            R.publication_pins()

    def test_exact_accepted_vertex_facts_do_not_reexecute_historical_source_proof(self):
        with patch.object(R.M, "source_program", side_effect=AssertionError("no historical source relaxation")):
            points, pins = R.contact_source_points()
        self.assertEqual(points, self.spec["source_points"])
        self.assertEqual(len(pins), 2)
        self.assertEqual(set(pins.values()), {R.CONTACT_MANIFEST_SHA, R.CONTACT_SPEC_SHA})

    def test_runtime_manifest_has_only_recorded_current_core_changes(self):
        bake, pins = R.runtime_bake_spec()
        new = json.loads(bake.read_text())
        old = json.loads((HERE / "high-wall-runtime-sources-v1/bake-spec.json").read_text())
        changes = new["runtime_closure_refresh"]["changed_sources"]
        expected = {row["path"]: row for row in changes}
        self.assertEqual(len(expected), 10)
        for before, after in zip(old["sources"], new["sources"], strict=True):
            if before["path"] in expected:
                row = expected[before["path"]]
                self.assertTrue(before["path"].startswith("res://scripts/core/"))
                self.assertEqual(before["sha256"], row["prior_sha256"])
                self.assertEqual(after, {**before, "sha256": row["current_sha256"]})
            else:
                self.assertEqual(before, after)
        self.assertEqual({k: v for k, v in old.items() if k not in ("sources", "runtime_closure_refresh")},
                         {k: v for k, v in new.items() if k not in ("sources", "runtime_closure_refresh")})
        self.assertEqual(set(pins.values()), {R.RUNTIME_BAKE_SHA, R.RUNTIME_CHANGES_SHA})

    def test_runtime_spec_or_change_record_byte_drift_refuses(self):
        original = R.BASE.digest
        for ending in ("bake-spec.json", "changes.json"):
            with patch.object(R.BASE, "digest", side_effect=lambda path:
                    "0" * 64 if str(path).endswith(ending) else original(path)):
                with self.assertRaisesRegex(ValueError, "RUNTIME_MANIFEST"):
                    R.runtime_bake_spec()

    def test_contact_manifest_and_spec_byte_drift_refuse(self):
        original = R.BASE.digest
        for ending, error in (("output-sha256.json", "CONTACT_MANIFEST"), ("spec.json", "CONTACT_SPEC")):
            with patch.object(R.BASE, "digest", side_effect=lambda path:
                    "0" * 64 if str(path).endswith(ending) else original(path)):
                with self.assertRaisesRegex(ValueError, error):
                    R.contact_source_points()

    def test_contact_manifest_must_pin_exact_spec_record(self):
        original = R.R.bounded_json
        manifest = original(HERE / "review-cardinal-native-v2/output-sha256.json", 65536)
        relative = str((HERE / "native-cardinal-program-v5/spec.json").relative_to(R.BASE.ROOT))
        for value in ({}, {**manifest, relative: "0" * 64}):
            with patch.object(R.R, "bounded_json", side_effect=lambda path, limit:
                    value if path.name == "output-sha256.json" else original(path, limit)):
                with self.assertRaisesRegex(ValueError, "CONTACT_MANIFEST_RECORD"):
                    R.contact_source_points()

    def test_vertex_shape_identity_nonfinite_and_missing_values_refuse(self):
        original = R.R.bounded_json
        mutations = [("source_points", {}, "VERTICES"), ("source_points", {"148": [0, 0, 0]}, "VERTICES"),
                     ("source_points", {"148": [0, 0], "478": [0, 0, 0]}, "POINT"),
                     ("content_sha256", "0" * 64, "SOURCE")]
        for bad in (True, "0", float("nan"), float("inf"), 1025):
            mutations.append(("source_points", {"148": [bad, 0, 0], "478": [0, 0, 0]}, "POINT"))
        for field, value, error in mutations:
            synthetic = {**self.spec, field: value}
            with patch.object(R.R, "bounded_json", side_effect=lambda path, limit:
                    synthetic if path.name == "spec.json" else original(path, limit)):
                with self.assertRaisesRegex(ValueError, "CONTACT_" + error):
                    R.contact_source_points()

    def test_complete_report_checks_keep_world_unqualified(self):
        result = R.validate_report(self.report, self.spec, self.table, self.contacts)
        self.assertEqual(result["driver_poses"], 7648)
        self.assertEqual(result["contact_poses"], 144)
        self.assertEqual(result["actual_catalog_profiles"], 18)
        self.assertFalse(result["world_activation_qualified"])

    def test_wrong_source_basis_revision_and_catalog_count_refuse(self):
        for key, value in (("wire_sha256", "0" * 64), ("actor_sha256", "0" * 64), ("basis_sha256", "0" * 64),
                           ("content_revision", True), ("content_revision", 2), ("profile_count", 17)):
            row = copy.deepcopy(self.report)
            row["published_catalog"][key] = value
            with self.assertRaisesRegex(ValueError, "CATALOG_IDENTITY"):
                R.published_refusal(row)

    def test_missing_wrong_or_boolean_role_pins_and_flags_refuse(self):
        for key, value in (("pins", [0, 1, 1]), ("pins", [True] * 54),
                           ("certificate_flags", [0] * 18), ("certificate_flags", [15.0] * 18)):
            row = copy.deepcopy(self.report)
            row["published_catalog"][key] = value
            with self.assertRaisesRegex(ValueError, "CATALOG_MAP"):
                R.published_refusal(row)
        row = copy.deepcopy(self.report)
        row["actual_species_stage_rig"] = [6.0, 0, 6]
        with self.assertRaisesRegex(ValueError, "BINDING_SCOPE"):
            R.published_refusal(row)

    def test_other_backend_and_world_permission_refuse(self):
        for key, value in (("rendering_driver", "vulkan"), ("rendering_method", "forward_plus"),
                           ("world_activation_qualified", True)):
            row = copy.deepcopy(self.report)
            row["published_catalog"][key] = value
            with self.assertRaisesRegex(ValueError, "BINDING_SCOPE"):
                R.published_refusal(row)

    def test_catalog_metadata_does_not_replace_event_or_contact_oracle(self):
        for key in ("events", "native_contacts"):
            row = copy.deepcopy(self.report)
            row[key].pop()
            with self.assertRaises(ValueError):
                R.validate_report(row, self.spec, self.table, self.contacts)

    def test_existing_output_and_dangling_symlink_preserve_bytes_before_any_proof(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp) / "prior"
            out.mkdir()
            (out / "report.json").write_bytes(b"historical")
            link = Path(temp) / "dangling"
            link.symlink_to(Path(temp) / "missing")
            with patch.object(R, "publication_pins", side_effect=AssertionError("must preflight first")):
                for path in (out, link):
                    with self.assertRaises(ValueError):
                        R.run(path)
            self.assertEqual((out / "report.json").read_bytes(), b"historical")
            self.assertTrue(link.is_symlink())


if __name__ == "__main__":
    unittest.main()
