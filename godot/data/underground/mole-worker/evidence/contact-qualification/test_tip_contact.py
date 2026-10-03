"""Synthetic adversarial source-witness fixtures; these do not qualify game content."""
from pathlib import Path
import importlib.util
import unittest

import numpy as np

SPEC = importlib.util.spec_from_file_location("tip_proof", Path(__file__).with_name("prove_tip_contact.py"))
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)


class TipContact(unittest.TestCase):
    def fixture(self):
        part = {"kind": "attachment", "name": "synthetic_tool", "binds": 0, "surface_formats": [1],
                "geometry": [{"points": np.array([[0, 0, 0]], dtype=np.float32),
                              "ids": np.zeros((1, 0), dtype=np.int64), "weights": np.empty((1, 0), dtype=np.float32)}]}
        matrix = np.array([[[1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0]],
                           [[1, 0, 0, 0, 1, 0, 0, 0, 1, 1, -1, -1]]], dtype=np.float32)
        return part, matrix, np.zeros(2, dtype=np.float32), [0, -32256, 0, 262144, 16896, 262144]

    def test_robust_opposite_endpoints_produce_separate_integer_focus_and_exact_crossing(self):
        part, matrix, ground, roots = self.fixture()
        result = T.crossing(part, matrix, ground, 0, 0, 1, roots)
        self.assertEqual(result["authored_anchor_u"], [512, 0, -512])
        self.assertEqual(result["ideal_crossing_share"], {"numerator": 1, "denominator": 2})
        self.assertGreater(result["endpoint_intervals_q24"][0][0][1], 0)
        self.assertLess(result["endpoint_intervals_q24"][1][1][1], 0)

    def test_uncertain_or_wrong_direction_endpoints_cannot_be_declared_contact(self):
        part, matrix, ground, roots = self.fixture()
        for first, last in ((1, 2), (-1, 1), (1e-6, -1e-6)):
            matrix[:, 0, 10] = [first, last]
            with self.assertRaises(T.P.envelope.Refused):
                T.crossing(part, matrix, ground, 0, 0, 1, roots)

    def test_missing_vertex_skinning_or_nonadjacent_source_refuses(self):
        part, matrix, ground, roots = self.fixture()
        for vertex, first, last in ((1, 0, 1), (True, 0, 1), (0, 0, 2), (0, 1, 0)):
            with self.assertRaises(T.P.envelope.Refused):
                T.crossing(part, matrix, ground, vertex, first, last, roots)
        part["binds"] = 1
        with self.assertRaises(T.P.envelope.Refused):
            T.crossing(part, matrix, ground, 0, 0, 1, roots)


if __name__ == "__main__":
    unittest.main()
