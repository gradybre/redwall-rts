#!/usr/bin/env python3
"""Tests for the tread fitting motion (ADR 1217 step 2d).

Record tests need only committed files; the rebuild test needs the staged palette and skips without it.

    $PY .../test_tread_fit.py -v
"""
from __future__ import annotations

import json
import unittest

import numpy as np

import prove_tread_fit as FIT

SEAT, SRC = FIT.SEAT, FIT.SRC
EVIDENCE = SRC.HERE / "evidence/tread-fit-v1"
CANDIDATES = ("candidate-b", "candidate-c")


def load(candidate: str, site: str, name: str) -> dict:
    """One stored JSON record."""
    return json.loads((EVIDENCE / candidate / site / name).read_text())


class StoredProofs(unittest.TestCase):
    """Both candidates clear every kept proof at both sites."""

    def test_every_kept_proof_clears(self) -> None:
        """World with sole support and self-clearance, entry and work, seat and tap, tread and sill."""
        for candidate in CANDIDATES:
            for site in FIT.SITES:
                proof = load(candidate, site, "proof.json")
                self.assertTrue(proof["clear"], (candidate, site))
                for name in ("seat", "tap"):
                    for part in ("work", "entry"):
                        self.assertTrue(proof[name][part]["self"]["clear"])
                        self.assertEqual(proof[name][part]["world"]["unresolved"], [])
                    self.assertEqual(proof[name]["recovery"], {"reused_exact_reverse_of": "entry"})

    def test_bearer_is_hard_and_contact_not_required(self) -> None:
        """The paw skin is the whole bearer (top at P), and no contact or patch is claimed."""
        for candidate in CANDIDATES:
            for site, plane in FIT.SITES.items():
                proof, record = load(candidate, site, "proof.json"), load(candidate, site, "candidate.json")
                self.assertEqual(proof["tap"]["work"]["world"]["skin_top_u"], plane)
                self.assertFalse(record["exact_bearer_contact_required"])
                self.assertNotIn("contact", proof["tap"])
                self.assertGreater(record["work_plane_u"] - SEAT.TAP_DEPTH_U, plane)

    def test_one_program_serves_tread_and_sill(self) -> None:
        """The work height is absolute, so the tread and sill clips are identical."""
        for candidate in CANDIDATES:
            tread, sill = (load(candidate, site, "candidate.json")["clips"] for site in FIT.SITES)
            self.assertEqual(tread, sill)

    def test_fixture_is_the_tread_station(self) -> None:
        """ADR 1209's 310 u station fixture plus the two trench walls; support deck first, bearer at its edge."""
        record = load("candidate-b", "tread", "candidate.json")
        solids = record["fixture"]["solids_u"]
        self.assertEqual(record["station_from_far_edge_u"], 310)
        self.assertEqual(solids[0], [-1024, -64, -310, 1024, 0, 202])
        self.assertEqual(solids[record["fixture"]["workpiece_solid"]], [-256, 0, -310, 256, 128, -182])
        self.assertEqual(len(solids), 9)


class SiteRefusals(unittest.TestCase):
    """The site refuses work points off the bearer or into it."""

    def test_refusals(self) -> None:
        """A contact z past the bearer, or a work height whose tap would enter the top, is refused."""
        good = load("candidate-b", "tread", "candidate.json")["recipe"]
        with self.assertRaisesRegex(ValueError, "OFF_BEARER"):
            FIT.site(dict(good, contact_z_u=-150), 128)
        with self.assertRaisesRegex(ValueError, "WORK_BELOW_TOP"):
            FIT.site(dict(good, work_y_u=130), 128)


@unittest.skipUnless(SRC.PALETTE.exists(), "staged palette absent (ADR 1192 §6)")
class Rebuild(unittest.TestCase):
    """The stored clips rebuild byte for byte."""

    def test_rebuild(self) -> None:
        """Candidate b's six clips at the tread site."""
        src = SEAT.corrected_source()
        record = load("candidate-b", "tread", "candidate.json")
        where, _ = FIT.site(record["recipe"], 128)
        programs = SEAT.author(src, {k: record["recipe"][k] for k in SEAT.DOMAINS}, where)
        for name, cases in programs.items():
            for part, case in zip(FIT.PARTS, cases):
                with np.load(EVIDENCE / "candidate-b/tread" / f"{name}_{part}.npz", allow_pickle=False) as image:
                    self.assertEqual(image["matrices"].tobytes(), case["matrices"].tobytes())


if __name__ == "__main__":
    unittest.main()
