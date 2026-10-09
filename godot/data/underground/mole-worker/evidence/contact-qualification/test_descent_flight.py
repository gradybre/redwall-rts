#!/usr/bin/env python3
"""ADR 1209 step 2: the derived flight and the stored proofs, checked without the gitignored source closure."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("descent_flight", HERE / "prove_descent_flight.py")
F = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(F)
FLIGHT = HERE / "descent-flight-v1"
BOTTOM = HERE / "descent-bottom-v1"


def stored(path: Path) -> dict:
    """One committed evidence record."""
    return json.loads(path.read_text())


class DescentFlightTests(unittest.TestCase):
    def setUp(self):
        self.spec = F.read_prefix()

    def test_family_treads_shorten_only_their_posts(self):
        t0 = [self.spec["parts"][i]["bounds_u"] for i in F.T0_PARTS]
        for k in range(1, F.FAMILY_TREADS + 1):
            for before, after in zip(t0, F.tread(self.spec, k)):
                self.assertEqual(after[2] - before[2], -512 * k)
                self.assertEqual(after[0::3], before[0::3])
                if before[1] == F.FLOOR_Y:
                    self.assertEqual(after[1], F.FLOOR_Y)
                    self.assertEqual(after[4] - before[4], -128 * k)
                else:
                    self.assertEqual([after[1], after[4]], [before[1] - 128 * k, before[4] - 128 * k])
        self.assertEqual([F.tread(self.spec, k)[3][4] - F.FLOOR_Y for k in range(1, 6)], [576, 448, 320, 192, 64])

    def test_the_sixth_tread_is_refused(self):
        with self.assertRaisesRegex(ValueError, "DESCENT_FLIGHT_TREAD_6_POST_BELOW_FLOOR"):
            F.tread(self.spec, 6)

    def test_segments_chain_root_and_support(self):
        flight = F.derivation(self.spec)
        for gait, rise in (("descent", -128), ("ascent", 128)):
            rows = F.segments(flight["decks"], gait)
            recipe_end = [0, rise, -512]
            for before, after in zip(rows, rows[1:]):
                self.assertEqual(before["support_solids"][1], after["support_solids"][0])
                moved = F.SEQ.endpoint(before, recipe_end)
                self.assertEqual(moved, after["origin_u"])
            for row in rows:
                top = flight["solids"][row["support_solids"][0]][4]
                self.assertEqual(top, row["origin_u"][1])

    def test_a_tampered_prefix_refuses(self):
        spec = copy.deepcopy(self.spec)
        spec["natural_bearings"][4]["bounds_u"][4] = -1000
        with self.assertRaisesRegex(ValueError, "DESCENT_FLIGHT_BEARINGS"):
            F.bearings(spec, 1)

    def test_stored_fixtures_are_the_derivation(self):
        flight = F.derivation(self.spec)
        self.assertEqual(stored(FLIGHT / "derivation.json")["solids_u"], flight["solids"])
        for gait in ("descent", "ascent"):
            fixture = stored(FLIGHT / (gait + "-fixture.json"))
            self.assertEqual(fixture["solids_u"], flight["solids"])
            self.assertEqual(fixture["segments"], F.segments(flight["decks"], gait))
        for rows in (6, 7):
            solids, segments = F.bottom(self.spec, rows)
            fixture = stored(BOTTOM / ("rows-%d" % rows) / "descent-fixture.json")
            self.assertEqual([fixture["solids_u"], fixture["segments"]], [solids, segments])

    def test_stored_flight_proof_is_clear_and_pinned(self):
        proof = stored(FLIGHT / "proof.json")
        for path, digest in proof["producer_sources"].items():
            self.assertEqual(hashlib.sha256((F.ROOT / path).read_bytes()).hexdigest(), digest, path)
        for gait, pairs in (("descent", 4044), ("ascent", 4686)):
            result = proof["gaits"][gait]["result"]
            self.assertTrue(result["clear"])
            self.assertEqual([result["unresolved"], result["segments"], result["pairs"]], [[], 6, pairs])
            self.assertTrue(all(row["projection_inside"] for row in result["supports"]))
            self.assertEqual(len(result["supports"]), 540)

    def test_stored_bottom_needs_the_seventh_row(self):
        short = stored(BOTTOM / "rows-6" / "proof.json")["gaits"]["descent"]["result"]
        wall = stored(BOTTOM / "rows-6" / "descent-fixture.json")["solids_u"]
        self.assertFalse(short["clear"])
        self.assertEqual({(row["segment"], wall[row["solid"]][5]) for row in short["unresolved"]}, {(1, -6144)})
        full = stored(BOTTOM / "rows-7" / "proof.json")["gaits"]["descent"]["result"]
        self.assertTrue(full["clear"])
        self.assertEqual([full["unresolved"], full["segments"]], [[], 2])


if __name__ == "__main__":
    unittest.main()
