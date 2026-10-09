#!/usr/bin/env python3
"""ADR 1216 step 1: the curled paw's deformation rules and its stored record (committed files only)."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("author_curled_paw", HERE / "author_curled_paw.py")
C = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(C)
OUT = HERE / "curled-paw-v1"
REVIEW = HERE / "curled-paw-review-v1"


class CurledPawTests(unittest.TestCase):
    def setUp(self):
        rng = np.random.default_rng(1216)
        self.points = rng.uniform([-0.1, -0.04, -0.07], [0.09, 0.17, 0.08], size=(400, 3))
        self.weight = rng.uniform(0, 1, size=400)

    def test_accepted_contraction_inverts_exactly(self):
        closed = C.accepted_closed(self.points, self.weight)
        recovered, error = C.recover_original(closed, self.weight)
        self.assertLess(error, 1e-9)
        np.testing.assert_allclose(recovered, self.points, atol=1e-9)

    def test_thinning_moves_thickness_only(self):
        thinned = C.thin(self.points, self.weight, 0.0)
        np.testing.assert_array_equal(thinned[:, :2], self.points[:, :2])
        self.assertTrue(np.all(np.abs(thinned[:, 2]) <= np.abs(self.points[:, 2]) + 1e-15))

    def test_curl_is_continuous_and_bends_toward_the_palm(self):
        axis = np.array([0.078, 0.07])
        at_line = np.array([[0.0, 0.078, 0.01], [0.0, 0.0779, 0.01]])
        ones = np.ones(2)
        np.testing.assert_allclose(C.curl(at_line, ones, axis, 0.05), at_line, atol=1e-12)
        beyond = np.array([[0.02, 0.078 + 0.05 * np.pi / 2, 0.01]])
        bent = C.curl(beyond, np.ones(1), axis, 0.05)
        np.testing.assert_allclose(bent[0], [0.02, 0.078 + 0.06, 0.07], atol=1e-12)
        unweighted = C.curl(beyond, np.zeros(1), axis, 0.05)
        np.testing.assert_array_equal(unweighted, beyond)

    def test_stored_record(self):
        record = json.loads((OUT / "paw.json").read_text())
        raw = (OUT / "curled-rest-points.npy").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), record["curled_rest_points_sha256"])
        self.assertLess(record["inversion_round_trip_error_m"], 1e-9)
        self.assertGreater(record["witness"]["wrap_degrees"], 90)
        for path, digest in record["producer_sources"].items():
            self.assertEqual(hashlib.sha256((C.P.ROOT / path).read_bytes()).hexdigest(), digest, path)
        images = json.loads((REVIEW / "images.json").read_text())["images_sha256"]
        for name, digest in images.items():
            self.assertEqual(hashlib.sha256((REVIEW / name).read_bytes()).hexdigest(), digest)


if __name__ == "__main__":
    unittest.main()
