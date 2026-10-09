#!/usr/bin/env python3
"""Independent wire/geometry and rejection checks for the diagnostic-only serializer."""
from __future__ import annotations

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("diagnostic_serializer", HERE / "assemble_approach_candidate.py")
SERIALIZER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(SERIALIZER)
FIXTURE = HERE / "approach-profile-diagnostic-2"


class DiagnosticWireTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.legacy = SERIALIZER.LEGACY.read_bytes()
        cls.report_raw = (FIXTURE / "approach-program.json").read_bytes()
        cls.report = json.loads(cls.report_raw)
        cls.expected = (FIXTURE / "mole-worker.ugprof").read_bytes()
        cls.manifest = json.loads((FIXTURE / "manifest.json").read_text())

    def rejected(self, edit, code):
        """Exercise the individual syntax guards independently of the complete report identity gate."""
        changed = copy.deepcopy(self.report)
        edit(changed)
        with self.assertRaisesRegex(ValueError, "^" + code + "$"):
            for row in SERIALIZER.approach_rows(changed):
                SERIALIZER.encode_boxes(row["roles"])

    def test_complete_source_proof_is_pinned(self):
        for key in ("handoffs", "work_joins", "source_inputs", "producer_sources"):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.report)
                changed.pop(key)
                with self.assertRaisesRegex(ValueError, "APPROACH_REPORT_PROOF"):
                    SERIALIZER.encode_candidate(self.legacy, changed)
        changed = copy.deepcopy(self.report)
        changed["rows"][0]["roles"]["BODY_HELD_LOAD"][0] = [0, 1, 0, 1, 2, 1]
        with self.assertRaisesRegex(ValueError, "APPROACH_REPORT_PROOF"):
            SERIALIZER.encode_candidate(self.legacy, changed)

    def test_reproduction_and_wire_census(self):
        wire, mapping = SERIALIZER.encode_candidate(self.legacy, self.report)
        self.assertEqual(wire, self.expected)
        self.assertEqual(SERIALIZER.sha(wire), self.manifest["wire_sha256"])
        self.assertEqual(SERIALIZER.HEADER.unpack_from(wire), (b"UGPROF01", 2, 2, 26, 250, 1))
        self.assertEqual((len(wire), 2 * (len(wire) - 8)), (9620, 19224))
        self.assertEqual(mapping, self.manifest["mapping"])
        self.assertEqual([r["profile"] for r in mapping], list(range(26)))
        self.assertEqual(wire[-8:], b"UGPEND01")

    def test_legacy_geometry_and_descriptors_are_preserved(self):
        old = SERIALIZER.legacy_rows(self.legacy)
        wire = self.expected
        for original_index, (fields, boxes) in enumerate(old):
            index = original_index if original_index < 2 else original_index + 8
            actual = list(SERIALIZER.ROW.unpack_from(wire, 64 + index * SERIALIZER.ROW.size))
            normalized = list(actual)
            normalized[14] = fields[14]  # Only relocation into the combined box bank differs.
            normalized[22] = fields[22]  # Old WORK rows receive the explicit source-clock policy.
            self.assertEqual(normalized, fields)
            offset = 64 + 26 * SERIALIZER.ROW.size + actual[14] * SERIALIZER.BOX.size
            self.assertEqual(wire[offset:offset + len(boxes)], boxes)
            self.assertEqual(actual[22], 0 if original_index < 2 else 3)

    def test_approach_complete_boxes_and_cardinal_policies(self):
        for row in self.report["rows"]:
            index = row["profile"]
            actual = SERIALIZER.ROW.unpack_from(self.expected, 64 + index * SERIALIZER.ROW.size)
            self.assertEqual((actual[10], actual[11], actual[22]), (0, row["yaw"], row["selection_policy"]))
            self.assertEqual((actual[15], actual[18]), (7, 1))
            offset = 64 + 26 * SERIALIZER.ROW.size + actual[14] * SERIALIZER.BOX.size
            decoded = [SERIALIZER.BOX.unpack_from(self.expected, offset + i * SERIALIZER.BOX.size) for i in range(7)]
            expected = [tuple(bounds) + (role,) for role, name in enumerate(SERIALIZER.ROLES[:3])
                        for bounds in row["roles"][name]]
            self.assertEqual(decoded, expected)

    def test_legacy_changed_byte_refuses(self):
        changed = bytearray(self.legacy)
        changed[-10] ^= 1
        with self.assertRaisesRegex(ValueError, "APPROACH_LEGACY_HASH"):
            SERIALIZER.encode_candidate(bytes(changed), self.report)

    def test_source_identity_protocol_or_census_refuses(self):
        for key, value in (("actor_sha256", "0" * 64), ("source_program_sha256", "0" * 64),
                           ("source_program", 4), ("verified_source_files", 536), ("certificate_bits_written", 15)):
            with self.subTest(key=key):
                self.rejected(lambda d: d.__setitem__(key, value), "APPROACH_SOURCE_REPORT")

    def test_source_domain_or_timing_refuses(self):
        for key, value in (("root_domain_u", [0] * 6), ("ready_time_q16", 0), ("fade_time_q16", 0)):
            with self.subTest(key=key):
                self.rejected(lambda d: d.__setitem__(key, value), "APPROACH_SOURCE_PROGRAM")

    def test_missing_duplicate_reordered_rows_refuse(self):
        self.rejected(lambda d: d["rows"].pop(), "APPROACH_ROW_CENSUS")
        self.rejected(lambda d: d["rows"].__setitem__(1, copy.deepcopy(d["rows"][0])), "APPROACH_ROW_IDENTITY")
        self.rejected(lambda d: d["rows"].reverse(), "APPROACH_ROW_IDENTITY")

    def test_identity_and_reverse_path_refuse(self):
        for key, value in (("profile", 99), ("selection_policy", 0), ("yaw", 1),
                           ("path_yaw", 0), ("mode", 0), ("posture", 1), ("yaw_kind", 1)):
            with self.subTest(key=key):
                self.rejected(lambda d: d["rows"][4].__setitem__(key, value), "APPROACH_ROW_IDENTITY")

    def test_role_loss_or_extra_role_refuses(self):
        self.rejected(lambda d: d["rows"][0]["roles"].pop("BODY_HELD_LOAD"), "APPROACH_REQUIRED_ROLES")
        self.rejected(lambda d: d["rows"][0]["roles"].__setitem__("WORK_STROKE", []), "APPROACH_REQUIRED_ROLES")
        self.rejected(lambda d: d["rows"][0]["roles"]["BODY_HELD_LOAD"].pop(), "APPROACH_ROLE_COUNT")

    def test_noninteger_reversed_and_overflow_boxes_refuse(self):
        for value in (True, 0.1, 1 << 31, -(1 << 31) - 1):
            with self.subTest(value=value):
                self.rejected(lambda d: d["rows"][0]["roles"]["BODY_HELD_LOAD"][0].__setitem__(0, value), "APPROACH_BOX")
        self.rejected(lambda d: d["rows"][0]["roles"]["BODY_HELD_LOAD"].__setitem__(0, [0] * 6), "APPROACH_BOX")

    def test_cli_hash_output_boundary_and_create_only(self):
        script = str(HERE / "assemble_approach_candidate.py")
        with tempfile.TemporaryDirectory(prefix="serializer-test-", dir=HERE) as directory:
            parent = Path(directory)
            output = parent / "candidate"
            args = [sys.executable, "-B", script, "--report", str(FIXTURE / "approach-program.json"),
                    "--report-sha", SERIALIZER.sha(self.report_raw), "--out", str(output)]
            wrong = list(args)
            wrong[wrong.index("--report-sha") + 1] = "0" * 64
            result = subprocess.run(wrong, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("APPROACH_REPORT_HASH", result.stderr)
            self.assertFalse(output.exists())
            changed = copy.deepcopy(self.report)
            changed.pop("producer_sources")
            forged = parent / "forged-report.json"
            forged.write_text(json.dumps(changed))
            wrong[wrong.index("--report") + 1] = str(forged)
            wrong[wrong.index("--report-sha") + 1] = SERIALIZER.sha(forged.read_bytes())
            result = subprocess.run(wrong, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("APPROACH_REPORT_HASH", result.stderr)
            self.assertFalse(output.exists())
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((output / "mole-worker.ugprof").read_bytes(), self.expected)
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertTrue(manifest["diagnostic_only"])
            self.assertFalse(any(manifest[k] for k in ("production_qualified", "native_qualified", "world_activation_qualified")))
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("APPROACH_OUTPUT_EXISTS", result.stderr)
            args[-1] = str(SERIALIZER.ROOT / "godot/data/underground/mole-worker/serializer-forbidden-output")
            result = subprocess.run(args, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("APPROACH_DIAGNOSTIC_OUTPUT_ONLY", result.stderr)


if __name__ == "__main__":
    unittest.main()
