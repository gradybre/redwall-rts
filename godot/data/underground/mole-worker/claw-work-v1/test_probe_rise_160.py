#!/usr/bin/env python3
"""Tests for the 160 u rise probe (decision 2041 P-DF-1 (b), decision 2043). No art needed.

    $PY .../test_probe_rise_160.py -v
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import unittest

import probe_rise_160 as PROBE

FOLDER = PROBE.SRC.HERE / "evidence/rise-probe-v1"


def load(rise: int) -> dict:
    """One stored probe result."""
    return json.loads((FOLDER / f"rise-{rise}/result.json").read_text())


class Fixture(unittest.TestCase):
    """The pitched flight fixture."""

    def test_at_128_it_is_the_accepted_flight(self) -> None:
        """At 128 u the fixture's treads, bearings and trench are prove_descent_flight's own for T0-T4."""
        spec = PROBE.FLIGHT.read_prefix()
        accepted = PROBE.FLIGHT.derivation(spec)
        mine = PROBE.fixture(spec, 128)
        for k in range(1, PROBE.TREADS_IN_TRENCH):
            self.assertEqual(PROBE.moved_tread(spec, k, 128), PROBE.FLIGHT.tread(spec, k))
        self.assertEqual(mine["solids"][-5:], accepted["solids"][-5:])
        self.assertEqual([s["origin_u"] for s in mine["segments"]["descent"]],
                         [s["origin_u"] for s in PROBE.FLIGHT.segments(accepted["decks"], "descent")[:5]])

    def test_at_160_every_deck_is_one_pitch_lower(self) -> None:
        """T_k's top is -160(k + 1); the posts keep their feet on the floor; T5 would leave the floor."""
        spec = PROBE.FLIGHT.read_prefix()
        fixture = PROBE.fixture(spec, 160)
        decks = [segment["support_solids"][0] for segment in fixture["segments"]["descent"]]
        decks.append(fixture["segments"]["descent"][-1]["support_solids"][1])
        self.assertEqual([fixture["solids"][d][4] for d in decks], [0, -160, -320, -480, -640, -800])
        with self.assertRaises(ValueError):
            PROBE.moved_tread(spec, 5, 160)
        ascent = fixture["segments"]["ascent"]
        self.assertEqual(ascent[0]["origin_u"], [0, -800, PROBE.FLIGHT.ASCENT_START[2] - 512 * 4])

    def test_widen_refuses_a_missing_literal(self) -> None:
        """A widening that does not find its literal exactly once refuses."""
        with self.assertRaises(ValueError):
            PROBE.widen(PROBE.ASC, "tracks", "rise in (-1, 1)", "x")

    def test_widened_restores_the_accepted_functions(self) -> None:
        """Inside the block 160 is admitted; after it the original function objects, and the refusal, are back."""
        originals = [getattr(m, n) for m, n in PROBE.WHITELISTS()]
        with PROBE.widened(160) as names:
            self.assertEqual(len(names), 6)
            PROBE.TERRAIN.fixture_boxes(160)
        self.assertEqual([getattr(m, n) for m, n in PROBE.WHITELISTS()], originals)
        with self.assertRaises(ValueError):
            PROBE.TERRAIN.fixture_boxes(160)


class Records(unittest.TestCase):
    """The stored control and probe."""

    def test_the_records_pin_this_probe_and_the_current_sources(self) -> None:
        """Each record was made by this probe file, against today's accepted sources."""
        probe = hashlib.sha256(Path(PROBE.__file__).read_bytes()).hexdigest()
        for rise in (128, 160):
            record = load(rise)
            self.assertEqual(record["probe_source_sha256"], probe)
            self.assertEqual(record["accepted_sources_unchanged"], PROBE.accepted_hashes())

    def test_the_control_reproduces_m7(self) -> None:
        """At 128 u: M7's terrain pairs (674, 781) and five flight steps of each (3,370 = 5 x 674, 3,905 = 5 x 781)."""
        record = load(128)
        self.assertTrue(record["clear"])
        self.assertEqual(record["widened_whitelists"], [])
        rows = record["proofs"]
        self.assertEqual([rows["descent"]["terrain"]["pairs"], rows["ascent"]["terrain"]["pairs"]], [674, 781])
        self.assertEqual([rows["descent"]["flight"]["pairs"], rows["ascent"]["flight"]["pairs"]], [3370, 3905])

    def test_160_authors_but_its_terrain_proofs_refuse(self) -> None:
        """At 160 u both gaits author (no leg-reach refusal); both two-deck proofs refuse on the right leg; the
        ascent's right arm meets the body with M7's 3 degree swing; nothing is clear."""
        record = load(160)
        self.assertFalse(record["clear"])
        self.assertEqual(record["authoring_refusals"], {})
        rows = record["proofs"]
        self.assertFalse(rows["descent"]["terrain"]["clear"] or rows["ascent"]["terrain"]["clear"])
        self.assertEqual([rows["descent"]["terrain"]["unresolved"], rows["ascent"]["terrain"]["unresolved"]], [32, 32])
        self.assertNotIn("flight", rows["descent"])
        self.assertFalse(rows["ascent"]["self"]["right_arm_vs_rest"])
        self.assertTrue(rows["descent"]["self"]["right_arm_vs_rest"])
        self.assertEqual(len(record["widened_whitelists"]), 6)


if __name__ == "__main__":
    unittest.main()
