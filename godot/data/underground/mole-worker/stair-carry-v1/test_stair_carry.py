#!/usr/bin/env python3
"""Tests for the basic stair carry's offline evidence (decision 1981).

The record tests read the committed evidence only. The rebuild tests re-author every clip and re-derive the rows and
the tables byte for byte; they need the staged palettes (ADR 1192 §6) and skip without them. The 15-minute proof run
(`prove_stair_carry.py`) is not repeated here; its record is checked.

    $PY .../test_stair_carry.py -v
"""
from __future__ import annotations

import json
from pathlib import Path
import unittest

import numpy as np

import author_stair_carry as AUTHOR
import stair_carry_source as SC

HERE = Path(__file__).resolve().parent
EVIDENCE = HERE / "evidence"
CLIPS = EVIDENCE / "clips-v1"
STAGED = SC.PALETTE.exists() and SC.GRIP.exists()


def load(name: str) -> dict:
    """One stored record."""
    return json.loads((EVIDENCE / name).read_text())


def walk(rows: dict) -> list:
    """Every leaf proof row of a nested proof record: (path, clear)."""
    found = []
    for key, value in rows.items():
        if isinstance(value, dict) and "clear" in value:
            found.append((key, value["clear"]))
        elif isinstance(value, dict):
            found += [(key + "." + k, v) for k, v in walk(value)]
    return found


class Records(unittest.TestCase):
    """The committed candidate, proofs, rows, tables and native verifications."""

    def test_recipes_are_the_accepted_ones(self) -> None:
        """M7's descent and ascent recipes; no arm swing; the handoff author pinned."""
        record = load("clips-v1/candidate.json")
        d, a = record["accepted_recipes"]["descent"], record["accepted_recipes"]["ascent"]
        self.assertEqual((d["root_advance_u"], d["root_drop_u"], d["leading_foot_advance_u"]), (256, 128, 360))
        self.assertEqual((a["lead_root_advance_u"], a["lead_root_lift_u"]), (68, 50))
        self.assertEqual(record["arm_swing_degrees"], {"right": 0, "left": 0})
        self.assertEqual(record["handoff_author_sha256"], AUTHOR.AH_SHA)

    def test_endpoint_support_is_derived_from_the_ready(self) -> None:
        """P-1981-7 (a): the hold stands on both feet, the stand on the left alone (the author's own value)."""
        clips = load("clips-v1/candidate.json")["clips"]
        for item in ("wood", "stone"):
            for name in ("approach", "turn", "retreat", "back_up"):
                self.assertEqual(clips[item][name]["endpoint_planted_mask"], 3, f"{item}.{name}")
        for name in ("empty_walk_off", "empty_back_up"):
            self.assertEqual(clips["empty"][name]["endpoint_planted_mask"], 1, name)

    def test_every_proof_clears(self) -> None:
        """Every leaf of the proof record is clear, and nothing is missing."""
        record = load("proof-v1.json")["proofs"]
        self.assertTrue(record["clear"])
        rows = walk({k: v for k, v in record.items() if k != "clear"})
        self.assertEqual(len(rows), 62)  # 27 per item (self, load, every fixture run and its endpoints), 8 at the foot.
        self.assertTrue(all(clear for _, clear in rows), [path for path, clear in rows if not clear])
        for item in ("wood", "stone"):
            self.assertEqual(set(record[item]["descent"]), {"self", "load", "terrain", "flight", "bottom"})
            self.assertEqual(set(record[item]["approach"]), {"self", "load", "L0", "L0_endpoints", "floor_approach",
                                                             "floor_approach_endpoints"})
            self.assertEqual(set(record[item]["turn"]), {"self", "load", "floor_turn", "floor_turn_endpoints"})

    def test_endpoint_feet_are_supported(self) -> None:
        """P-1981-7: the hold's two feet are checked at both endpoint keys of every loaded handoff run (the prover
        witnesses a foot only where it is planted at both keys of an interval): in the contact cell, over the deck."""
        record = load("proof-v1.json")["proofs"]
        for item in ("wood", "stone"):
            for clip, run in (("approach", "L0"), ("approach", "floor_approach"), ("retreat", "L0"),
                              ("turn", "floor_turn")):
                feet = record[item][clip][run + "_endpoints"]["feet"]
                self.assertEqual(sorted((f["key"] > 0, f["foot"]) for f in feet),
                                 [(False, 0), (False, 1), (True, 0), (True, 1)], f"{item}.{clip}.{run}")
                self.assertTrue(all(0 <= f["min_gap_u"] < 1 and f["margin_u"] > 0 for f in feet))
        self.assertEqual(set(record["floor_end"]), {"empty_walk_off", "empty_back_up", "claw_turn_55", "claw_ascent_54"})

    def test_rows_census(self) -> None:
        """Fourteen rows, at most twelve boxes each, at their headings, all EARTH_TIMBER."""
        rows = load("rows-v1.json")["rows"]
        self.assertEqual(len(rows), 14)
        self.assertEqual([r["yaw"] for r in rows], [0, 0] + [0, 0, 32768, 0, 32768, 0] * 2)
        self.assertTrue(all(r["family_mask"] == 1 and sum(map(len, r["roles"].values())) <= 12 for r in rows))

    def test_back_up_rows_are_the_approach_rebased(self) -> None:
        """A back-up's boxes are its approach's, moved into the frame of the approach's end."""
        rows = {(r["group"], r["name"]): r for r in load("rows-v1.json")["rows"]}
        for group, forward, back in (("wood", "approach", "back_up"), ("empty", "empty_walk_off", "empty_back_up")):
            a, b = rows[(group, forward)], rows[(group, back)]
            end = a["root_end_u"]
            self.assertEqual(b["root_end_u"], [-v for v in end])
            for role, boxes in a["roles"].items():
                self.assertEqual(b["roles"][role], [[box[k] - end[k % 3] for k in range(6)] for box in boxes])

    def test_native_images_verified(self) -> None:
        """Both images: no coefficient mismatch, a floor gap, every loaded row's two-hand witness, every join."""
        for image, clips in (("wood", 9), ("stone", 7)):
            record = load(f"native-stair-carry-v1/{image}-verification.json")
            self.assertEqual(record["coefficient_mismatches"], 0)
            self.assertEqual(len(record["clips"]), clips)
            self.assertGreaterEqual(record["minimum_visible_floor_gap_u"]["body"], 0)
            self.assertGreater(record["exact_rational_two_hand_witnesses"], 0)
            self.assertEqual(record["joins"]["hub_joins"], 3 * 2 * clips)


@unittest.skipUnless(STAGED, "staged palettes absent (ADR 1192 §6)")
class Rebuild(unittest.TestCase):
    """The clips rebuild byte for byte; the derived support rule and the reversal hold."""

    @classmethod
    def setUpClass(cls) -> None:
        """Author once."""
        cls.closure = SC.closure()
        cls.table, _ = AUTHOR.AH.read_basis()
        cls.clips = AUTHOR.author(cls.closure, cls.table)

    def test_clips_rebuild(self) -> None:
        """Every clip equals its stored bytes."""
        import prove_stair_carry as PROVE
        PROVE.check_stored(CLIPS, self.clips)

    def test_planted_mask(self) -> None:
        """Both hold feet lie in the contact cell; the stand's right foot does not."""
        for item in SC.ITEMS:
            ready = dict(self.closure["items"][item]["ready"], triangles=self.closure["body_triangles"])
            self.assertEqual(AUTHOR.planted_mask(ready), 3, item)
        empty = dict(self.closure["empty"], triangles=self.closure["body_triangles"])
        self.assertEqual(AUTHOR.planted_mask(empty), 1)

    def test_endpoint_support_leaves_the_author_restored(self) -> None:
        """The wrapper changes only the two endpoint masks and restores the accepted author afterwards."""
        accepted = AUTHOR.AH.frame_track
        with AUTHOR.endpoint_support(3):
            self.assertIsNot(AUTHOR.AH.frame_track, accepted)
        self.assertIs(AUTHOR.AH.frame_track, accepted)
        keys = self.clips["wood"]["approach"]["handoff_recipe"]["keys"]
        self.assertEqual((keys[0]["planted_mask"], keys[-1]["planted_mask"]), (3, 3))
        stand = self.clips["empty"]["empty_walk_off"]["handoff_recipe"]["keys"]
        self.assertEqual([k["planted_mask"] for k in keys[1:-1]], [k["planted_mask"] for k in stand[1:-1]])

    def test_upper_body_and_load_are_the_hold(self) -> None:
        """Hips, bones 9-23 and the load column equal the hold on every key of every loaded clip."""
        for item in SC.ITEMS:
            for name, case in self.clips[item].items():
                self.assertTrue(AUTHOR.invariant(case, self.closure["items"][item]["hold"]), f"{item}.{name}")

    def test_back_up_is_the_exact_reverse(self) -> None:
        """Keys reversed, grounding reversed."""
        a, b = self.clips["stone"]["approach"], self.clips["stone"]["back_up"]
        np.testing.assert_array_equal(b["matrices"], a["matrices"][::-1])
        np.testing.assert_array_equal(b["grounding"], a["grounding"][::-1])

    def test_rows_and_tables_rebuild(self) -> None:
        """The rows and the tables re-derive byte for byte from the clips and the proof record."""
        import derive_stair_carry_rows as ROWS
        import derive_stair_carry_tables as TABLES
        basis = SC.ROOT / "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw"
        rows = ROWS.derive(CLIPS, EVIDENCE / "proof-v1.json", basis)
        self.assertEqual(rows["rows"], load("rows-v1.json")["rows"])
        tables = TABLES.derive(CLIPS, EVIDENCE / "proof-v1.json")
        self.assertEqual(tables["programs"], load("tables-v1.json")["programs"])

    def test_refusals(self) -> None:
        """An unsupported ready, a sunk ready and a clip that leaves its hold are refused."""
        ready = dict(self.closure["empty"], triangles=self.closure["body_triangles"])
        lifted = dict(ready, grounding=ready["grounding"] + np.float32(0.01))
        with self.assertRaisesRegex(ValueError, "STAIR_CARRY_READY_UNSUPPORTED"):
            AUTHOR.planted_mask(lifted)
        hold = dict(self.closure["items"]["wood"]["ready"], triangles=self.closure["body_triangles"])
        above = dict(hold, grounding=hold["grounding"] + np.float32(1.5 / 1024))
        with self.assertRaisesRegex(ValueError, "STAIR_CARRY_READY_UNSUPPORTED"):
            AUTHOR.planted_mask(above)  # 1.5 u up: both feet leave the [0, 1) u contact cell.
        sunk = dict(ready, grounding=ready["grounding"] - np.float32(0.01))
        with self.assertRaisesRegex(ValueError, "STAIR_CARRY_READY_BELOW_FLOOR"):
            AUTHOR.planted_mask(sunk)
        with self.assertRaisesRegex(ValueError, "STAIR_CARRY_HOLD_ENDPOINT"):
            closure = dict(self.closure, items={**self.closure["items"], "wood": dict(
                self.closure["items"]["wood"], hold=self.closure["items"]["stone"]["hold"])})
            AUTHOR.loaded_clips(closure, "wood", self.table)


if __name__ == "__main__":
    unittest.main()
