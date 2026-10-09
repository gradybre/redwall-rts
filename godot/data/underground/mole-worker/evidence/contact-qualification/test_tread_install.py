#!/usr/bin/env python3
"""ADR 1209 step 4: the tread-install fixture, the author's input domain and the stored candidates.

The stored-candidate tests read only committed files. The reconstruction test rebuilds candidate v3 from its
recipe and needs the gitignored demo assets that the accepted source closure lists; it skips without them.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("tread_install", HERE / "author_tread_install.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)
CANDIDATES = HERE / "tread-install-v1"
REVIEW = HERE / "tread-install-review-v1"
NAMES = ("candidate-v1", "candidate-v2", "candidate-v3")


def stored(path: Path) -> dict:
    """One committed JSON record."""
    return json.loads(path.read_text())


class TreadInstallTests(unittest.TestCase):
    def setUp(self):
        self.packet = T.P.content.read_json(T.PREFIX, T.I.PREFIX_SHA, 65536)

    def test_fixture_puts_the_workpiece_on_the_far_edge_and_the_riser_behind(self):
        station = T.fixture(self.packet, 310)
        solids = station["solids_u"]
        self.assertEqual(solids[0], [-1024, -64, -310, 1024, 0, 202])
        self.assertEqual(solids[-1], [-256, 0, -310, 256, 128, -182])
        self.assertEqual(solids[3], [-1024, 64, 202, 1024, 128, 2250])
        self.assertEqual([station["support_solid"], station["workpiece_solid"], station["workpiece_support"]], [0, 6, False])

    def test_fixture_sides_contain_the_real_bearers_and_posts(self):
        with_t0 = T.fixture(self.packet, 310)["solids_u"]
        shift = (0, 128, 2560 - 310)
        for part, side in ((8, 1), (10, 1), (11, 1), (9, 2), (12, 2), (13, 2)):
            box = [v + shift[a % 3] for a, v in enumerate(self.packet["parts"][part]["bounds_u"])]
            self.assertTrue(all(with_t0[side][a] <= box[a] and box[a + 3] <= with_t0[side][a + 3] for a in range(3)))

    def test_input_domain_refuses_outside_its_bounds(self):
        for lean, azimuth in ((24, 30), (61, 30), (50, -1), (50, 61)):
            with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_POSE_INPUT"):
                T.poll_pose({}, {}, {}, [128, 126, -246], lean, azimuth)
        for torso in (1, -36):
            with self.assertRaisesRegex(ValueError, "TREAD_INSTALL_TORSO_INPUT"):
                T.pitched_ready({}, {}, torso)

    def test_stored_candidates_are_clear_and_pinned(self):
        for name in NAMES:
            folder = CANDIDATES / name
            proof, record = stored(folder / "proof.json"), stored(folder / "candidate.json")
            compiled = stored(folder / "compilation.json")
            self.assertTrue(proof["clear"], name)
            self.assertTrue(all(row["clear"] for row in proof["self"].values()), name)
            self.assertTrue(all(row["clear"] for row in proof["world"].values()), name)
            image = (folder / "mole-worker.ugactor").read_bytes()
            self.assertEqual(hashlib.sha256(image).hexdigest(), compiled["content_sha256"])
            target = record["fixture"]["solids_u"][-1]
            for contact in proof["contacts"]:
                patch = contact["patch_u"]
                self.assertTrue(target[0] <= patch[0] and patch[3] <= target[3] and target[2] <= patch[2]
                                and patch[5] <= target[5] and patch[1] == patch[4] == 128)
            for path, digest in record["producer_sources"].items():
                self.assertEqual(hashlib.sha256((T.P.ROOT / path).read_bytes()).hexdigest(), digest, path)

    def test_review_images_match_their_record(self):
        for name in NAMES:
            numbers = stored(REVIEW / name / "review.json")
            for image, digest in numbers["images_sha256"].items():
                self.assertEqual(hashlib.sha256((REVIEW / name / image).read_bytes()).hexdigest(), digest)

    def test_probe_finds_no_upright_recipe(self):
        probe = stored(CANDIDATES / "probe.json")["grids"]
        self.assertEqual(probe["upright"]["counts"]["CLEAR"], 0)
        self.assertGreater(probe["pitched_back"]["counts"]["CLEAR"], 0)

    def test_reconstruction_matches_candidate_v3(self):
        assets = T.P.ROOT / "godot/demo/assets/manifest.json"
        if not assets.is_file():
            self.skipTest("gitignored demo assets are not staged (ADR 1192 §2)")
        T.M.W.snapshot_sources = T.FLIGHT.historical_snapshot
        original, parts, rig, _, _, _, _ = T.M.read_actual_source()
        record = stored(CANDIDATES / "candidate-v3" / "candidate.json")
        cases, _ = T.source_motion(original[0], parts[1], rig, record["source_recipe"])
        compiled = stored(CANDIDATES / "candidate-v3" / "compilation.json")
        images = T.I.M.S.read_image(CANDIDATES / "candidate-v3" / "mole-worker.ugactor", compiled["content_sha256"], parts)
        self.assertEqual([c["matrices"].tobytes() for c in images], [c["matrices"].tobytes() for c in cases])


if __name__ == "__main__":
    unittest.main()
