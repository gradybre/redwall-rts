#!/usr/bin/env python3
"""ADR 1216: the successor pick fit's derivation rules and its stored records (committed files only)."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("author_pick_refit", HERE / "author_pick_refit.py")
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)
OUT = HERE / "pick-fit-v1"


def stored(name: str) -> dict:
    """One stored fit record."""
    return json.loads((OUT / name / "fit.json").read_text())


class PickRefitTests(unittest.TestCase):
    def setUp(self):
        self.accepted = np.diag([0.2892, 0.2892, 0.2892, 1.])
        self.local = np.array([[-0.098, 0.05, 0.], [0.094, 0.09, 0.], [0., 0.12, 0.03]])
        self.patch = np.ones(3, dtype=bool)
        self.section = {"centre_y": 0.1948, "centre_z": 0.0, "diameter": 0.195, "end_x": 0.9509}

    def test_shaft_crosses_the_paw_through_the_socket_with_the_handle_end_out(self):
        for side, sign in (("medial", 1), ("lateral", -1)):
            fit, record = F.derive_fit(self.accepted, self.local, self.patch, self.section, side, 1)
            rotation = fit[:3, :3] / 0.2892
            self.assertAlmostEqual(float(np.linalg.det(rotation)), 1.0, places=12)
            np.testing.assert_allclose(rotation @ [1, 0, 0], [-sign, 0, 0], atol=1e-12)
            np.testing.assert_allclose(rotation @ [0, 0, 1], [0, 1, 0], atol=1e-12)
            grip = fit @ [record["grip_tool_x"], 0.1948, 0., 1.]
            np.testing.assert_allclose(grip[:3], F.SOCKET_M, atol=1e-12)
            butt = (fit @ [0.9509, 0.1948, 0., 1.])[0]
            self.assertAlmostEqual(butt, record["butt_hand_x_m"], places=12)
            self.assertGreater(-sign * (butt - record["paw_edge_hand_x_m"]), 0)

    def test_fit_input_refuses(self):
        with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_FIT_INPUT"):
            F.derive_fit(self.accepted, self.local, self.patch, self.section, "up", 1)
        with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_FIT_INPUT"):
            F.derive_fit(self.accepted, self.local, self.patch, self.section, "lateral", 4)

    def test_stored_successors(self):
        lateral, medial = stored("lateral-1"), stored("medial-1")
        self.assertTrue(lateral["ready_self_clearance"]["clear"])
        self.assertFalse(medial["ready_self_clearance"]["clear"])
        for record in (lateral, medial):
            self.assertLess(record["derivation"]["grip_tool_x"], 0.6846)
            self.assertEqual(record["grip_witness"]["wrap_sectors_covered"], 17)
            for path, digest in record["producer_sources"].items():
                self.assertEqual(hashlib.sha256((F.P.ROOT / path).read_bytes()).hexdigest(), digest, path)


if __name__ == "__main__":
    unittest.main()
