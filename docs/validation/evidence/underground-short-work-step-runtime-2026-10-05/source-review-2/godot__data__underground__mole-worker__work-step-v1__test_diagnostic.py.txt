#!/usr/bin/env python3
"""Exact-input and complete-row checks for the create-only diagnostic assembler."""
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("step_diagnostic", Path(__file__).with_name("assemble_diagnostic.py"))
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)


def rows(raw, count):
    result = []
    for index in range(count):
        fields = list(A.ROW.unpack_from(raw, 64 + index * A.ROW.size))
        first, amount = fields[14:16]
        start = 64 + count * A.ROW.size + first * A.BOX.size
        result.append((fields, raw[start:start + amount * A.BOX.size]))
    return result


class DiagnosticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = A.OLD.read_bytes()
        cls.report = A.REPORT.read_bytes()
        cls.wire, cls.mapping = A.encode(cls.old, cls.report)

    def test_exact_counts_and_only_intended_policy_changes(self):
        self.assertEqual(A.HEADER.unpack_from(self.wire), (b"UGPROF01", 2, 3, 29, 271, 1))
        self.assertEqual(len(self.wire), 10502)
        self.assertEqual(2 * (len(self.wire) - 8), 20988)
        self.assertEqual([r[0][22] for r in rows(self.wire, 29)], [0, 0] + [1] * 4 + [2] * 4 + [4, 5, 6] + [3] * 16)

    def test_every_unchanged_row_payload_and_whole_box_is_preserved(self):
        old, new = rows(self.old, 26), rows(self.wire, 29)
        for source, target in [(i, i if i < 10 else i + 3) for i in range(26)]:
            with self.subTest(profile=target):
                before, prior_boxes = old[source]
                after, actual_boxes = new[target]
                before[14] = after[14]
                self.assertEqual(after, before)
                self.assertEqual(actual_boxes, prior_boxes)
        prior, expected = old[1]
        actual, ground = new[12]
        prior[14], prior[22] = actual[14], 6
        self.assertEqual(actual, prior)
        self.assertEqual(ground, expected)

    def test_short_rows_include_all_seven_source_boxes_without_clipping(self):
        new = rows(self.wire, 29)
        proof = json.loads(self.report)
        for direction, index in enumerate((10, 11)):
            expected = [(tuple(box) + (role,)) for role, name in enumerate(
                ("BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY"))
                for box in proof["rows"][direction]["roles"][name]]
            self.assertEqual(list(struct.iter_unpack("<7i", new[index][1])), expected)
            self.assertEqual(len(expected), 7)

    def test_altered_geometry_or_stripped_report_refuses_even_if_self_rehashed(self):
        proof = json.loads(self.report)
        for replacement in ({"rows": proof["rows"]}, {**proof, "certificate_bits_written": 15}):
            with self.assertRaisesRegex(ValueError, "STEP_REPORT_HASH"):
                A.encode(self.old, json.dumps(replacement).encode())
        proof["rows"][0]["roles"]["BODY_HELD_LOAD"][2][5] -= 1
        with self.assertRaisesRegex(ValueError, "STEP_REPORT_HASH"):
            A.encode(self.old, json.dumps(proof).encode())

    def test_old_wire_mutation_and_truncation_refuse(self):
        changed = bytearray(self.old)
        changed[5000] ^= 1
        for raw in (bytes(changed), self.old[:-1], self.old + b"x"):
            with self.assertRaisesRegex(ValueError, "STEP_OLD_HASH"):
                A.encode(raw, self.report)

    def test_output_cannot_overwrite_or_leave_owned_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            with self.assertRaisesRegex(ValueError, "STEP_OUTPUT_EXISTS"):
                A.write_candidate(path)
            with self.assertRaisesRegex(ValueError, "STEP_DIAGNOSTIC_OUTPUT_ONLY"):
                A.write_candidate(path / "new-output")
            link = path / "dangling"
            link.symlink_to(path / "missing")
            with self.assertRaisesRegex(ValueError, "STEP_OUTPUT_EXISTS"):
                A.write_candidate(link)


if __name__ == "__main__":
    unittest.main()
