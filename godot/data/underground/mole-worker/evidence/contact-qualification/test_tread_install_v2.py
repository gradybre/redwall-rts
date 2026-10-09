#!/usr/bin/env python3
"""ADR 1209 step 4, revision 2: the swivel elbow, the input domain and the stored candidates.

Stored-candidate tests read only committed files. The reconstruction test rebuilds candidate a and needs the
gitignored demo assets the accepted source closure lists; it skips without them.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install_v2", HERE / "author_tread_install_v2.py")
V2 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V2)
CANDIDATES = HERE / "tread-install-v2"
REVIEW = HERE / "tread-install-review-v2"
NAMES = ("candidate-a", "candidate-b", "candidate-c")


def stored(path: Path) -> dict:
    """One committed JSON record."""
    return json.loads(path.read_text())


class TreadInstallV2Tests(unittest.TestCase):
    def test_swivel_keeps_both_links_and_prefers_the_wanted_forearm(self):
        shoulder, target = np.array([0., 0., 0.]), np.array([.3, -.2, -.1])
        wanted = np.array([0., -1., 0.])
        elbow, deviation = V2.swivel_elbow(shoulder, target, .25, .2, wanted)
        self.assertAlmostEqual(float(np.linalg.norm(elbow - shoulder)), .25, places=9)
        self.assertAlmostEqual(float(np.linalg.norm(target - elbow)), .2, places=9)
        other, _ = V2.swivel_elbow(shoulder, target, .25, .2, -wanted)
        self.assertLess(deviation, float(np.degrees(np.arccos(np.clip((target - other) / .2 @ wanted, -1, 1)))))

    def test_swivel_refuses_an_unreachable_hand(self):
        with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_ARM_REACH"):
            V2.swivel_elbow(np.zeros(3), np.array([1., 0., 0.]), .25, .2, np.array([1., 0., 0.]))

    def test_input_domain_keeps_the_accepted_lean_ceiling(self):
        for lean, azimuth in ((24, 30), (51, 30), (35, -1), (35, 91)):
            with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_POSE_INPUT"):
                V2.tool_and_hand({}, {}, {}, [208, 126, -300], lean, azimuth)

    def test_stored_candidates_are_clear_and_pinned(self):
        for name in NAMES:
            folder = CANDIDATES / name
            proof, record = stored(folder / "proof.json"), stored(folder / "candidate.json")
            self.assertTrue(proof["clear"], name)
            self.assertTrue(all(row["clear"] for row in proof["self"].values()), name)
            self.assertTrue(all(row["clear"] for row in proof["world"].values()), name)
            self.assertEqual(record["source_recipe"]["elbow_rule"], "wrist_preserving_swivel")
            self.assertLessEqual(record["source_recipe"]["lean_degrees"], 50)
            image = (folder / "mole-worker.ugactor").read_bytes()
            self.assertEqual(hashlib.sha256(image).hexdigest(), stored(folder / "compilation.json")["content_sha256"])
            for path, digest in record["producer_sources"].items():
                self.assertEqual(hashlib.sha256((V2.P.ROOT / path).read_bytes()).hexdigest(), digest, path)

    def test_review_images_match_their_record(self):
        for name in NAMES:
            numbers = stored(REVIEW / name / "review.json")
            for image, digest in numbers["images_sha256"].items():
                self.assertEqual(hashlib.sha256((REVIEW / name / image).read_bytes()).hexdigest(), digest)

    def test_comparison_shows_the_revision(self):
        rows = stored(REVIEW / "comparison.json")["rows"]
        self.assertGreater(rows["v3"]["shaft_elevation_degrees"], 85)
        self.assertLess(rows["v3"]["shaft_lateral_u"], 0)
        self.assertEqual(rows["a"]["shaft_elevation_degrees"], rows["accepted v4 (L0 -> T0)"]["shaft_elevation_degrees"])
        self.assertTrue(all(rows[n]["shaft_lateral_u"] > 0 for n in "abc"))

    def test_reconstruction_matches_candidate_a(self):
        if not (V2.P.ROOT / "godot/demo/assets/manifest.json").is_file():
            self.skipTest("gitignored demo assets are not staged (ADR 1192 §2)")
        V2.M.W.snapshot_sources = V2.V1.FLIGHT.historical_snapshot
        original, parts, rig, _, _, _, _ = V2.M.read_actual_source()
        folder = CANDIDATES / "candidate-a"
        cases, _ = V2.source_motion(original[0], parts[1], rig, stored(folder / "candidate.json")["source_recipe"])
        images = V2.I.M.S.read_image(folder / "mole-worker.ugactor", stored(folder / "compilation.json")["content_sha256"], parts)
        self.assertEqual([c["matrices"].tobytes() for c in images], [c["matrices"].tobytes() for c in cases])


if __name__ == "__main__":
    unittest.main()
