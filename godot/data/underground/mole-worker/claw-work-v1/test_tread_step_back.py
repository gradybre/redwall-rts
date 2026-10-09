#!/usr/bin/env python3
"""Tests for the tool-free step back on a tread (ADR 1209 step 5).

    $PY .../test_tread_step_back.py -v
"""
from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

import prove_tread_step_back as SB

SRC = SB.SRC
RECORD = SRC.HERE / "evidence/tread-step-back-v1/step_back.json"


def record() -> dict:
    """The stored record."""
    return json.loads(RECORD.read_text())


class Derivation(unittest.TestCase):
    """Published numbers."""

    def test_span_is_derived(self) -> None:
        """Descent end 169 u and station 310 u behind the far edge: a 141 u step in two ticks at 3277 u/s."""
        where = SB.distances()
        self.assertEqual(where, {"arrival_from_far_edge_u": 169, "station_from_far_edge_u": 310, "span_u": 141})
        row = record()
        self.assertEqual((row["moves"], row["walk_keys"], row["pace_u_per_s"]), (2, [0, 43, 42], 3277))

    def test_fixture_spans_the_path(self) -> None:
        """Support is the deck shrunk by the span; every collision solid is extended by it; no bearer."""
        row = record()
        self.assertEqual(row["fixture"]["support_u"], [-1024, -64, -169, 1024, 0, 202])
        for solid, swept in zip(row["fixture"]["solids_u"], row["fixture"]["swept_u"]):
            self.assertEqual(swept[:5], solid[:5])
            self.assertEqual(swept[5], solid[5] + 141)
        self.assertFalse(any(label.startswith("paid WIP") for label in row["fixture"]["labels"]))
        self.assertFalse(row["bearer_present"])


class StoredProof(unittest.TestCase):
    """The step clears; only the two READY fades lack a contact witness, as every approved fade does."""

    def test_clear(self) -> None:
        """World and self-clearance clear; the fade list names only intervals 0 and 3."""
        row = record()
        self.assertTrue(row["clear"])
        self.assertEqual(row["world"]["unresolved"], [])
        self.assertTrue(row["self"]["clear"])
        self.assertEqual(sorted(f["interval"] for f in row["world"]["ready_fade_without_contact_witness"]), [0, 3])
        self.assertGreater(row["ready_fade_hover_float"]["smallest_u"], 1.0)


@unittest.skipUnless(SRC.PALETTE.exists(), "staged palette absent (ADR 1192 §6)")
class Rebuild(unittest.TestCase):
    """Byte-for-byte rebuild."""

    def test_rebuild(self) -> None:
        """A fresh derivation writes the same clip and record."""
        with tempfile.TemporaryDirectory() as folder:
            out = Path(folder) / "step"
            SB.derive(out)
            for name in ("step_back.npz", "step_back.json"):
                self.assertEqual((out / name).read_bytes(), (RECORD.parent / name).read_bytes(), name)


if __name__ == "__main__":
    unittest.main()
