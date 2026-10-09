"""Adversarial finite handoff math; synthetic tables and triangles confer no production source permission."""
from fractions import Fraction
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

import numpy as np

SPEC = importlib.util.spec_from_file_location("state_handoffs", Path(__file__).with_name("prove_state_handoffs.py"))
H = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(H)


def basis_fixture(pair=(0.5, 0.5), row=65535):
    metadata = {"engine": {"major": 4, "minor": 7, "patch": 2, "hash": H.P.envelope.GODOT_SOURCE_HASH,
        "build": "official", "status": "stable"}, "rendering_driver": "opengl3",
        "rendering_method": "gl_compatibility", "display_server": "macOS", "api_version": "4.1 fixture",
        "source": {"sha256": "a" * 64}}
    encoded = json.dumps(metadata).encode()
    data = bytearray(b"UGYAW001" + struct.pack("<III", 1, 65536, len(encoded)) + encoded)
    data.extend(struct.pack("<ff", 1, 0) * 65536)
    struct.pack_into("<ff", data, 20 + len(encoded) + row * 8, *pair)
    data.extend(b"UGYEND01")
    return bytes(data)


class StateHandoffs(unittest.TestCase):
    def test_complete_native_rows_bound_inverse_not_assumed_unit_norm(self):
        raw = basis_fixture()
        table = H.InverseHeading(io.BytesIO(raw), hashlib.sha256(raw).hexdigest(), "a" * 64)
        self.assertEqual(table.rows, 65536)
        self.assertEqual(table.inverse_norm, Fraction(2))
        self.assertEqual(table.inverse_yaw, 65535)
        np.testing.assert_array_equal(H.source_padding(np.array([3, 2, 4], dtype=np.int64), table.inverse_norm), [8, 2, 8])
        for raw in (basis_fixture((0, 0)), basis_fixture()[:-1], basis_fixture() + b"trailing"):
            with self.assertRaises(H.P.envelope.Refused):
                H.InverseHeading(io.BytesIO(raw), hashlib.sha256(raw).hexdigest(), "a" * 64)
        with self.assertRaisesRegex(H.P.envelope.Refused, "DIGEST"):
            H.InverseHeading(io.BytesIO(basis_fixture()), "b" * 64, "a" * 64)

    def test_padding_is_outward_and_retains_vertical_component(self):
        result = H.source_padding(np.array([2, 7, 3], dtype=np.int64), Fraction(4, 3))
        np.testing.assert_array_equal(result, [4, 7, 4])
        for bad in (Fraction(0), Fraction(5)):
            with self.assertRaises(H.P.envelope.Refused):
                H.source_padding(np.ones(3, dtype=np.int64), bad)
        with self.assertRaises(H.P.envelope.Refused):
            H.source_padding(np.array([-1, 0, 0], dtype=np.int64), Fraction(1))

    def test_clear_source_endpoints_do_not_establish_clear_cross_clip_blend(self):
        body = np.array([[0, -1000, 0], [0, 1000, 0], [0, 0, 2000]], dtype=np.int64)
        tool = np.array([[0, -10, 0], [0, 10, 0], [0, 0, 10]], dtype=np.int64)
        poses = np.stack([tool + [1000, 0, 500], tool + [-1000, 0, 500]])
        fixed_body = np.stack([body, body])
        for row in poses:
            fixed_tool = np.stack([row, row])
            self.assertTrue(H.separated_simplex(fixed_body, fixed_body, fixed_tool, fixed_tool, [0]))
        self.assertFalse(H.separated_simplex(fixed_body, fixed_body, poses, poses, [0]))

    def test_shared_translation_is_removed_only_with_common_convex_weights(self):
        body = np.array([[0, 0, 0], [0, 10, 0], [0, 0, 10]], dtype=np.int64)
        positions = np.array([[0, 0, 0], [10000, -2000, 3000], [-3000, 2000, -7000]], dtype=np.int64)
        a = body[None, :, :] + positions[:, None, :]
        b = a + [20, 0, 0]
        self.assertTrue(H.separated_simplex(a, a, b, b, [0]))
        # A different tool translation is not subtracted independently: the
        # resulting actual same-time crossing remains an explicit refusal.
        b[1] = a[1] - [20, 0, 0]
        self.assertFalse(H.separated_simplex(a, a, b, b, [0]))

    def test_barycentric_subdivision_proves_rotating_separation_without_one_global_plane(self):
        body = np.array([[0, 0, 0], [2000, 0, 0], [0, 2000, 0]], dtype=np.int64)
        tool = np.array([[3000, 0, 0], [3200, 0, 0], [3000, 200, 0]], dtype=np.int64)
        turn = np.array([[-5, -9, 0], [9, -5, 0], [0, 0, 10]], dtype=np.int64)
        a = np.stack([body * 10, body @ turn.T, body @ turn.T])
        b = np.stack([tool * 10, tool @ turn.T, tool @ turn.T])
        with patch.object(H, "MAX_DEPTH", 0):
            self.assertFalse(H.separated_simplex(a, a, b, b, [0]))
        count = [0]
        self.assertTrue(H.separated_simplex(a, a, b, b, count))
        self.assertGreater(count[0], 1)
        # Positive pose coefficients preserve the common affine map, but
        # different body/tool coefficients or exhausted subdivision cannot pass.
        b[1] = a[1]
        self.assertFalse(H.separated_simplex(a, a, b, b, [0]))

    def test_uncertainty_and_exhausted_work_cannot_be_accepted(self):
        body = np.array([[[0, 0, 0], [0, 10, 0], [0, 0, 10]]] * 2, dtype=np.int64)
        tool = body + [2, 0, 0]
        self.assertTrue(H.separated_simplex(body, body, tool, tool, [0]))
        self.assertFalse(H.separated_simplex(body - 1, body + 1, tool - 1, tool + 1, [0]))
        with patch.object(H, "MAX_CHECKS", 0), self.assertRaisesRegex(H.P.envelope.Refused, "CHECK_CAPACITY"):
            H.separated_simplex(body, body, tool, tool, [0])
        with self.assertRaisesRegex(H.P.envelope.Refused, "CAPACITY"):
            H.separated_simplex(body + (1 << 29), body + (1 << 29), tool, tool, [0])

    def test_carry_union_has_explicit_unique_clip_and_corner_budgets(self):
        cases = [{"frames": 2, "matrices": np.zeros((2, 25, 12), dtype=np.float32),
                  "grounding": np.zeros(2, dtype=np.float32)} for _ in range(3)]
        self.assertEqual(H.case_union(cases, (0, 1))["frames"], 4)
        for selected in ((), (0, 0), (4,), (False,)):
            with self.assertRaises(H.P.envelope.Refused):
                H.case_union(cases, selected)
        with patch.object(H, "MAX_CORNERS", 3), self.assertRaisesRegex(H.P.envelope.Refused, "CORNER_CAPACITY"):
            H.case_union(cases, (0, 1))

    def test_fixed_ready_program_preserves_actual_loop_edge_and_has_no_arbitrary_target(self):
        cases = [{"frames": count, "source_loop_mode": 1, "source_duration_s": Fraction(count - 1, 30)}
                 for count in (10, 4)]
        program = H.handoff_sets(cases)
        self.assertEqual(len(program), 13)
        self.assertIn({"from": "ready", "interval": [8, 8], "to": "walk-start", "corners": [8, 8, 10]}, program)
        self.assertIn({"from": "idle", "interval": [8, 0], "to": "ready", "corners": [8, 0, 8]}, program)
        self.assertIn({"from": "walk", "interval": [2, 0], "to": "ready", "corners": [12, 10, 8]}, program)
        self.assertTrue(all(row["corners"][2] in (8, 10) for row in program))
        self.assertFalse(any(row["from"] == "idle" and row["to"] == "walk-start" for row in program))
        with self.assertRaisesRegex(H.P.envelope.Refused, "READY_POSE"):
            H.handoff_sets([dict(cases[0], frames=8), cases[1]])


if __name__ == "__main__":
    unittest.main()
