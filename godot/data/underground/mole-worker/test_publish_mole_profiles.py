#!/usr/bin/env python3
"""Adversarial publication tests use accepted source rows, never invented replacement clearance."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("mole_publication", HERE / "publish_mole_profiles.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class PublicationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows, cls.contacts, _ = M.N.math_inputs()
        cls.current = M.bounded_json(M.CURRENT_GROUND_PATH, M.CURRENT_GROUND_SHA)

    def test_reconstruction_uses_reviewed_location_adapter_and_restores_original_reader(self):
        reader = M.M.I.M.W
        original_read, original_snapshot = reader.read_record, reader.snapshot_sources

        def observe():
            self.assertIsNot(reader.read_record, original_read)
            self.assertIsNot(reader.snapshot_sources, original_snapshot)
            raise RuntimeError("deliberate reconstruction failure")

        with patch.object(M.M, "source_program", side_effect=observe):
            with self.assertRaisesRegex(RuntimeError, "deliberate reconstruction failure"):
                M.reconstructed_source()
        self.assertIs(reader.read_record, original_read)
        self.assertIs(reader.snapshot_sources, original_snapshot)

    def test_unreviewed_adapter_refuses_before_source_reconstruction(self):
        with patch.object(M, "digest", return_value="0" * 64), \
                patch.object(M.M, "source_program", side_effect=AssertionError("must refuse first")):
            with self.assertRaisesRegex(ValueError, "ADAPTER_DRIFT"):
                M.reconstructed_source()

    def test_wire_retains_every_exact_box_role_source_and_fixed_heading(self):
        wire, mapping = M.encode_wire(self.rows)
        self.assertEqual(len(wire), 7268)
        self.assertEqual(struct.unpack_from("<8sIqIII", wire), (b"UGPROF01", 1, 1, 18, 194, 1))
        self.assertEqual(wire[32:64].hex(), M.M.IMAGE_SHA)
        at = 64 + 18 * 98
        for row in mapping:
            index = row["profile"]
            fields = struct.unpack_from("<18i3q2B", wire, 64 + 98 * index)
            self.assertEqual(fields[1:4], (6, 0, 6))
            self.assertEqual(fields[6:10], (54, 0, -1, -1))
            self.assertEqual(fields[18:], (1, 0, 0, 15, 0))
            self.assertEqual(fields[10:12], (1, 0) if index < 2 else (0, row["yaw"]))
            self.assertEqual(fields[14:16], (row["first_box"], row["box_count"]))
            for role, name in enumerate(M.M.ROLE_NAMES):
                for box in self.rows[str(index)].get(name, []):
                    self.assertEqual(struct.unpack_from("<7i", wire, at), tuple(box) + (role,))
                    at += 28
        self.assertEqual(wire[at:], b"UGPEND01")

    def test_omitted_profile_or_mandatory_body_never_borrows_recovery(self):
        bad = copy.deepcopy(self.rows)
        del bad["17"]
        with self.assertRaisesRegex(ValueError, "ROW_CENSUS"):
            M.encode_wire(bad)
        bad = copy.deepcopy(self.rows)
        del bad["5"]["BODY_HELD_LOAD"]
        with self.assertRaisesRegex(ValueError, "REQUIRED_ROLE"):
            M.encode_wire(bad)

    def test_overflow_bool_nonplanar_patch_and_truncated_primitive_refuse(self):
        for value in (True, 2147483648, -2147483649, 0.5):
            with self.assertRaisesRegex(ValueError, "BOX_INTEGER"):
                M.checked_box([0, 0, 0, value, 1, 1], 0)
        for box in ([0, 0, 0, 1, 1, 1], [0, 0, 0, 0, 0, 1]):
            with self.assertRaisesRegex(ValueError, "BOX_SHAPE"):
                M.checked_box(box, 6)
        bad = copy.deepcopy(self.rows)
        bad["3"]["BODY_HELD_LOAD"].pop()
        with self.assertRaisesRegex(ValueError, "BOX_CENSUS"):
            M.encode_wire(bad)

    def test_historical_and_current_consumer_revisions_are_not_interchangeable(self):
        blobs = M.G.source_blobs(M.CURRENT_COMMIT)
        M.current_consumer_refusal(self.current, blobs)
        altered = dict(blobs)
        altered[next(iter(altered))] += b"\n"
        with self.assertRaisesRegex(ValueError, "CONSUMER_DRIFT"):
            M.current_consumer_refusal(self.current, altered)
        old = dict(self.current, consumer_source_commit="65526c25e00fa2777d588610255103889519e32d")
        with self.assertRaisesRegex(ValueError, "CONSUMER_DRIFT"):
            M.current_consumer_refusal(old, blobs)

    def test_missing_or_claimed_ground_proof_scope_refuses(self):
        blobs = M.G.source_blobs(M.CURRENT_COMMIT)
        for key, value in (("all_yaw_handoff_proof_reused", False), ("handoff_simplices", 154),
                           ("actor_image_sha256", "0" * 64), ("certificate_bits_written", 15)):
            with self.assertRaisesRegex(ValueError, "GROUND_SCOPE"):
                M.current_consumer_refusal(dict(self.current, **{key: value}), blobs)

    def test_native_diagnostic_or_source_drift_cannot_be_overridden_by_counts(self):
        root = M.P / "native-cardinal-program-v5"
        spec = M.bounded_json(root / "spec.json")
        report = M.bounded_json(root / "report.json")
        invocation = M.bounded_json(root / "invocation.json")
        self.assertEqual(M.native_refusal(spec, report, invocation, self.contacts)["assertions"], 46852)
        for key, value in (("native_exit", 1), ("unexpected_diagnostics", True), ("source_unchanged", False),
                           ("pre_import_source_unchanged", False), ("isolated_override_unchanged", False)):
            with self.assertRaisesRegex(ValueError, "NATIVE_EXECUTION"):
                M.native_refusal(spec, report, dict(invocation, **{key: value}), self.contacts)
        with self.assertRaisesRegex(ValueError, "ACTUAL_IDENTITY"):
            M.native_refusal(spec, dict(report, actual_species_stage_rig=[0, 0, 0]), invocation, self.contacts)

    def test_review_manifest_changed_bytes_and_unbounded_json_refuse(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "proof.json"
            path.write_text('{"clear":true}\n')
            accepted = hashlib.sha256(path.read_bytes()).hexdigest()
            path.write_text('{"clear":false}\n')
            with self.assertRaisesRegex(ValueError, "PROOF_HASH"):
                M.bounded_json(path, accepted)
            with patch.object(M, "MAX_JSON", 1):
                with self.assertRaisesRegex(ValueError, "JSON_CAPACITY"):
                    M.bounded_json(path)

    def test_existing_bundle_and_dangling_symlink_refuse_before_source_reads(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "old"
            output.mkdir()
            old = output / "report.json"
            old.write_bytes(b"original proof")
            with patch.object(M, "inputs", side_effect=AssertionError("must not read sources")):
                with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                    M.publish(output)
                link = Path(folder) / "dangling"
                link.symlink_to(Path(folder) / "absent")
                with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                    M.publish(link)
            self.assertEqual(old.read_bytes(), b"original proof")

    def test_constant_pack_is_complete_bounded_and_exact(self):
        source = M.source_constants("1" * 64, self.current["consumer_sources"])
        self.assertLessEqual(len(source.encode()), 4096)
        for path, expected in self.current["consumer_sources"].items():
            self.assertIn('res://' + path.removeprefix('godot/'), source)
            self.assertIn(expected, source)
        with self.assertRaisesRegex(ValueError, "CONSUMER_CENSUS"):
            M.source_constants("1" * 64, {})


if __name__ == "__main__":
    unittest.main()
