#!/usr/bin/env python3
"""Tests for the side-on tread station record (ADR 1217 step 2c).

The record and geometry tests need only committed files; the rebuild test needs the staged palette and skips
without it.

    $PY .../test_tread_side_station.py -v
"""
from __future__ import annotations

from fractions import Fraction
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

import derive_tread_side_station as SIDE

SRC = SIDE.SRC
RECORD = SRC.HERE / "evidence/tread-side-station-v1/station.json"


def record() -> dict:
    """The stored station record."""
    return json.loads(RECORD.read_text())


class QuarterTurn(unittest.TestCase):
    """The frame change is the published quarter turn, exactly."""

    def test_box_to_local_inverts_to_world(self) -> None:
        """A box mapped into the mole frame and its corners placed back land on the original box."""
        box, station = [-256, 0, -310, 256, 128, -182], (448, -42)
        local = SIDE.box_to_local(box, station)
        corners = np.array([[x, y, z] for x in local[0::3] for y in local[1::3] for z in local[2::3]], dtype=float)
        back = SIDE.to_world(corners, station)
        self.assertEqual(np.round(back.min(0)).tolist() + np.round(back.max(0)).tolist(),
                         [box[0], box[1], box[2], box[3], box[4], box[5]])

    def test_yaw_16384_faces_minus_x(self) -> None:
        """Local forward (-z) maps to world -x, as `claw_source.quarter` maps boxes (x' = z, z' = -x)."""
        forward = SIDE.to_world(np.array([[0., 0., -1.]]), (0, 0))[0]
        np.testing.assert_allclose(forward, [-1., 0., 0.], atol=1e-12)
        self.assertEqual(SRC.quarter([1, 2, 3, 4, 5, 6]), [3, 2, -4, 6, 5, -1])


class StoredRecord(unittest.TestCase):
    """The refusal and its numbers."""

    def test_footing_refused_exactly(self) -> None:
        """The narrowest exact foot span over every played key exceeds the 512 u deck depth."""
        row = record()
        span = Fraction(*row["footing"]["narrowest"]["span_u"])
        self.assertEqual(row["deck_depth_u"], 512)
        self.assertGreater(span, 512)
        low, high = (Fraction(*row["footing"]["narrowest"][k]) for k in ("left_x_u", "right_x_u"))
        self.assertEqual(high - low, span)
        self.assertIn("TREAD_SIDE_FOOTING", row["refusals"])
        self.assertFalse(row["station_admitted"])

    def test_paw_spread_exceeds_the_bearer_top(self) -> None:
        """The approved contacts are 256 u apart; the bearer's top is 128 u across the turned mole."""
        row = record()
        self.assertEqual((row["contact_spread_u"], row["bearer_top_width_across_mole_u"]), (256, 128))
        self.assertIn("TREAD_SIDE_PAW_SPREAD", row["refusals"])
        for site in row["sites"].values():
            self.assertFalse(all(c["on_bearer_top"] for c in site["contacts"].values()))

    def test_accepted_prover_refuses_both_sites(self) -> None:
        """At the best side-on station the accepted world prover refuses the seat and the tap, tread and sill."""
        row = record()
        self.assertEqual({k: v["plane_u"] for k, v in row["sites"].items()}, {"tread": 128, "sill": 64})
        for site in row["sites"].values():
            self.assertGreater(site["feet_over_far_edge_u"], 0)
            self.assertGreater(site["feet_over_riser_u"], 0)
            for proof in site["world_proof"].values():
                self.assertFalse(proof["clear"])
                self.assertGreater(proof["support_failures"], 0)

    def test_turn_fits_only_short_of_a_quarter(self) -> None:
        """The ready feet fit the deck's depth at yaw 0 and stop fitting before 90 degrees."""
        turn = record()["turn"]
        self.assertLessEqual(turn["z_extent_at_0_u"], 512)
        self.assertGreater(turn["z_extent_at_90_u"], 512)
        self.assertLess(turn["largest_yaw_that_fits_degrees"], 90)


@unittest.skipUnless(SRC.PALETTE.exists(), "staged palette absent (ADR 1192 §6)")
class Rebuild(unittest.TestCase):
    """The record rebuilds byte for byte from the staged inputs."""

    def test_rebuild(self) -> None:
        """A fresh derivation writes the same station.json."""
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "station"
            SIDE.derive(out)
            self.assertEqual((out / "station.json").read_bytes(), RECORD.read_bytes())


if __name__ == "__main__":
    unittest.main()
