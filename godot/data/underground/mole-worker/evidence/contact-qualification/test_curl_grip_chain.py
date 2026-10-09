#!/usr/bin/env python3
"""ADR 1216 steps 2–5 and ADR 1209 step 4 revision 4: the stored curled-paw chain, checked from committed files.

The bake verification, the envelope, topology and native records, the grip proof and the three tap candidates
are checked for identity, pins and results. The reconstruction test re-reads the v4 closure and needs the
gitignored demo assets; it skips without them.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
CURL = ROOT / "godot/data/underground/mole-worker/mole_grip_curl_source.gd"
NAMES = ("candidate-s", "candidate-t", "candidate-u")


def stored(path: Path) -> dict:
    """One committed JSON record."""
    return json.loads(path.read_text())


def sha(path: Path) -> str:
    """SHA-256 of one committed file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CurlGripChainTests(unittest.TestCase):
    def test_bake_binds_the_pinned_curled_derivative(self):
        verification = stored(HERE / "grip-source-v4" / "verification.json")
        self.assertEqual(verification["derived_geometry_sha256"],
                         "2a8517bb448a6e6f0a4136ffad314357559b6c8b5dae05d5779511eb03d003af")
        self.assertIn(verification["derived_geometry_sha256"], CURL.read_text())
        self.assertEqual([verification["cases"], verification["unexpected_diagnostics"], verification["leaked_objects"]], [7, 0, 0])
        self.assertEqual(sha(HERE / "grip-source-v4" / "content" / "mole-grip-v4.ugpal"), verification["content_sha256"])

    def test_envelopes_topology_and_native_replay(self):
        self.assertEqual(stored(HERE / "grip-proof-v3" / "envelopes.json")["source_sha256"],
                         stored(HERE / "grip-source-v4" / "verification.json")["content_sha256"])
        topology = stored(HERE / "topology-curl-v1" / "topology.json")
        self.assertEqual([topology["failures"], topology["derived_body_sha256"]],
                         [[], stored(HERE / "grip-source-v4" / "verification.json")["derived_geometry_sha256"]])
        invocation = stored(HERE / "topology-curl-v1" / "invocation.json")
        self.assertTrue(invocation["source_unchanged"] and not invocation["unexpected_diagnostics"])
        native = stored(HERE / "curl-native-v1" / "report.json")
        self.assertEqual(native["failures"], [])
        self.assertGreaterEqual(native["poses"], 500)

    def test_grip_proof(self):
        proof = stored(HERE / "curl-grip-proof-v1" / "proof.json")
        self.assertTrue(proof["clear"])
        self.assertTrue(proof["no_penetration_beyond_grip_exclusion"]["clear"])
        self.assertEqual(proof["no_penetration_beyond_grip_exclusion"]["intentional_grip_triangles"], 448)
        self.assertGreater(proof["palm_and_claw_contact"]["unseparated_pairs_found"], 0)
        self.assertGreaterEqual(proof["wrap"]["wrap_degrees"], 90)

    def test_tap_candidates_are_clear_upright_and_pinned(self):
        for name in NAMES:
            folder = HERE / "tread-install-v4" / name
            proof, record = stored(folder / "proof.json"), stored(folder / "candidate.json")
            self.assertTrue(proof["clear"], name)
            self.assertTrue(all(row["clear"] for row in proof["self"].values()), name)
            self.assertTrue(all(row["clear"] for row in proof["world"].values()), name)
            recipe = record["source_recipe"]
            self.assertEqual(recipe["torso_degrees"], 0)
            self.assertTrue(25 <= recipe["lean_degrees"] <= 50)
            self.assertEqual(sha(folder / "mole-worker.ugactor"), stored(folder / "compilation.json")["content_sha256"])
            for path, digest in record["producer_sources"].items():
                self.assertEqual(sha(ROOT / path), digest, path)
            review = stored(HERE / "tread-install-review-v4" / name / "review.json")
            for image, digest in review["images_sha256"].items():
                self.assertEqual(sha(HERE / "tread-install-review-v4" / name / image), digest)

    def test_reconstruction_of_candidate_s(self):
        if not (ROOT / "godot/demo/assets/manifest.json").is_file():
            self.skipTest("gitignored demo assets are not staged (ADR 1192 §2)")
        spec = importlib.util.spec_from_file_location("author_tread_install_v4", HERE / "author_tread_install_v4.py")
        author = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(author)
        cases_in, parts, rig, _, _, _, _ = author.C.read_curl_source()
        folder = HERE / "tread-install-v4" / "candidate-s"
        cases, _ = author.source_motion(cases_in[0], parts[1], rig, stored(folder / "candidate.json")["source_recipe"])
        images = author.I.M.S.read_image(folder / "mole-worker.ugactor", stored(folder / "compilation.json")["content_sha256"], parts)
        self.assertEqual([c["matrices"].tobytes() for c in images], [c["matrices"].tobytes() for c in cases])


if __name__ == "__main__":
    unittest.main()
