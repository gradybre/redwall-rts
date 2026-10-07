#!/usr/bin/env python3
"""ADR 1209 step 4, revision 3: the handle roll, the input domain and the stored candidates.

Stored-candidate tests read only committed files. The reconstruction test rebuilds candidate d and needs the
gitignored demo assets the accepted source closure lists; it skips without them.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install_v3", HERE / "author_tread_install_v3.py")
V3 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V3)
CANDIDATES = HERE / "tread-install-v3"
REVIEW = HERE / "tread-install-review-v3"
NAMES = ("candidate-d", "candidate-e", "candidate-f")


def stored(path: Path) -> dict:
    """One committed JSON record."""
    return json.loads(path.read_text())


class TreadInstallV3Tests(unittest.TestCase):
    def setUp(self):
        self.fit = np.eye(4)
        self.fit[:3, 3] = [.1, .02, 0]
        self.hand = np.eye(4)
        self.hand[:3, 3] = [.2, .5, -.2]
        self.ready = {"grounding": np.zeros(9, dtype=np.float32)}

    def test_roll_zero_is_the_accepted_orientation(self):
        self.assertTrue(np.array_equal(V3.rolled(self.hand, self.fit, [0, 0, 0], self.ready, 0), self.hand))

    def test_roll_turns_about_the_handle_through_the_contact_point(self):
        point = [100, 200, -300]
        turned = V3.rolled(self.hand, self.fit, point, self.ready, -30) @ self.fit
        matrix = self.hand @ self.fit
        np.testing.assert_allclose(turned[:3, 0], matrix[:3, 0], atol=1e-12)
        centre = np.asarray(point, dtype=float) / 1024
        axis = matrix[:3, 0]
        before, after = matrix[:3, 3] - centre, turned[:3, 3] - centre
        self.assertAlmostEqual(float(before @ axis), float(after @ axis), places=12)
        self.assertAlmostEqual(float(np.linalg.norm(before)), float(np.linalg.norm(after)), places=12)

    def test_roll_domain_refuses(self):
        for roll in (-91, 91):
            with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_ROLL_INPUT"):
                V3.rolled(self.hand, self.fit, [0, 0, 0], self.ready, roll)

    def test_stored_candidates_are_clear_and_pinned(self):
        for name in NAMES:
            folder = CANDIDATES / name
            proof, record = stored(folder / "proof.json"), stored(folder / "candidate.json")
            self.assertTrue(proof["clear"], name)
            self.assertTrue(all(row["clear"] for row in proof["self"].values()), name)
            self.assertTrue(all(row["clear"] for row in proof["world"].values()), name)
            recipe = record["source_recipe"]
            self.assertEqual((recipe["lean_degrees"], recipe["azimuth_degrees"]), (35, 30))
            self.assertEqual(recipe["elbow_rule"], "swivel_matching_accepted_contact_wrist")
            image = (folder / "mole-worker.ugactor").read_bytes()
            self.assertEqual(hashlib.sha256(image).hexdigest(), stored(folder / "compilation.json")["content_sha256"])
            for path, digest in record["producer_sources"].items():
                self.assertEqual(hashlib.sha256((V3.P.ROOT / path).read_bytes()).hexdigest(), digest, path)

    def test_review_images_match_their_records(self):
        for name in NAMES:
            for image, digest in stored(REVIEW / name / "review.json")["images_sha256"].items():
                self.assertEqual(hashlib.sha256((REVIEW / name / image).read_bytes()).hexdigest(), digest)
        for image, digest in stored(REVIEW / "grips.json")["images_sha256"].items():
            self.assertEqual(hashlib.sha256((REVIEW / image).read_bytes()).hexdigest(), digest)

    def test_candidate_d_holds_the_pick_as_v4(self):
        rows = stored(REVIEW / "comparison.json")["rows"]
        accepted, d = rows["accepted v4 (L0 -> T0)"], rows["d"]
        self.assertEqual((d["shaft_elevation_degrees"], d["shaft_lateral_u"]),
                         (accepted["shaft_elevation_degrees"], accepted["shaft_lateral_u"]))
        self.assertLess(abs(d["wrist_deviation_degrees"] - accepted["wrist_deviation_degrees"]), 3)

    def test_reconstruction_matches_candidate_d(self):
        if not (V3.P.ROOT / "godot/demo/assets/manifest.json").is_file():
            self.skipTest("gitignored demo assets are not staged (ADR 1192 §2)")
        V3.M.W.snapshot_sources = V3.V1.FLIGHT.historical_snapshot
        original, parts, rig, _, _, _, _ = V3.M.read_actual_source()
        folder = CANDIDATES / "candidate-d"
        cases, _, _ = V3.source_motion(original[0], parts[1], rig, stored(folder / "candidate.json")["source_recipe"], parts)
        images = V3.S.read_image(folder / "mole-worker.ugactor", stored(folder / "compilation.json")["content_sha256"], parts)
        self.assertEqual([c["matrices"].tobytes() for c in images], [c["matrices"].tobytes() for c in cases])


if __name__ == "__main__":
    unittest.main()
