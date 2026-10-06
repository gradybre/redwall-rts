#!/usr/bin/env python3
"""Checks for derive_haul_rows.py: pinned inputs, byte-identical output, sampled containment, sweep and stance."""
from __future__ import annotations

import argparse
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import unittest
from unittest import mock

import numpy as np

import derive_haul_rows as D

ARGS = None
ROLE = D.ROLE_IDS


def contained(points: np.ndarray, boxes: list) -> np.ndarray:
    """Per point: inside at least one closed integer box."""
    inside = np.zeros(len(points), dtype=bool)
    for box in boxes:
        low, high = np.asarray(box[:3], dtype=np.float64), np.asarray(box[3:], dtype=np.float64)
        inside |= np.all((points >= low) & (points <= high), axis=1)
    return inside


def role_boxes(row: dict, role: str) -> list:
    return [b["bounds_u"] for b in row["boxes"] if b["role"] == role]


class DerivedRows(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = D.encode(D.derive(ARGS.palette, ARGS.grip_palette, ARGS.world_basis))
        cls.committed = D.OUT.read_bytes()
        cls.report = json.loads(cls.committed)
        cls.rows = {row["name"]: row for row in cls.report["rows"]}
        cls.body, cls.wood, cls.cases, cls.body_tri, cls.wood_tri = D.load_sources(ARGS.palette, ARGS.grip_palette)
        cls.samples = {}
        for name, case in cls.cases.items():
            body = np.stack([D.I.points_at(case, cls.body, f) for f in range(case["frames"])])
            wood = np.stack([D.I.points_at(case, cls.wood, f, 24) for f in range(case["frames"])])
            cls.samples[name] = (body, wood)

    def points(self, clip: str, part: int, every: int = 1) -> np.ndarray:
        return self.samples[clip][part][::every].reshape(-1, 3)

    def test_input_pins_are_unchanged(self):
        for relative, digest in self.report["input_sha256"].items():
            self.assertEqual(hashlib.sha256((D.ROOT / relative).read_bytes()).hexdigest(), digest, relative)
        for relative, digest in self.report["producer_sha256"].items():
            self.assertEqual(hashlib.sha256((D.ROOT / relative).read_bytes()).hexdigest(), digest, relative)
        external = self.report["external_inputs_sha256"]
        self.assertEqual(external, {"palette": D.I.PALETTE_SHA, "grip_palette": D.I.GRIP_SHA,
                                    "world_basis_v1": D.WORLD_V1_SHA})
        self.assertEqual(hashlib.sha256(ARGS.world_basis.read_bytes()).hexdigest(), D.WORLD_V1_SHA)
        self.assertEqual(len(self.report["input_sha256"]), 16)

    def test_changed_input_refuses(self):
        with mock.patch.object(D, "WOOD_TOPOLOGY_SHA", "0" * 64):
            with self.assertRaisesRegex(ValueError, "HAUL_ROWS_INPUT_PIN"):
                D.input_pins()

    def test_output_reproduces_byte_identically(self):
        self.assertEqual(self.raw, self.committed)

    def test_every_box_contains_the_sampled_source_vertices_it_claims(self):
        checked = 0
        for row in self.report["rows"]:
            for claim in row["coverage"]:
                every = 1 if row["yaw_kind"] == 0 else 2
                points = self.points(claim["clip"], claim["part"], every)
                boxes = role_boxes(row, claim["role"])
                if row["yaw_kind"] == 1:
                    canonical = row["canonical_u"]
                    own = [canonical["stock_u"]] if claim["part"] else [canonical["body_above_u"], canonical["body_floor_u"]]
                    self.assertTrue(np.all(contained(points, own)), (row["name"], claim))
                self.assertTrue(np.all(contained(points, boxes)), (row["name"], claim))
                checked += len(points)
        self.assertGreater(checked, 10_000_000)

    def test_box_check_is_not_vacuous(self):
        row = self.rows["haul_load_wood_1000"]
        boxes = [list(b) for b in role_boxes(row, "WORK_STROKE")]
        boxes[0][4] -= 2
        self.assertFalse(np.all(contained(self.points("lift", 1), boxes)))
        body = [list(b) for b in role_boxes(row, "BODY_HELD_LOAD")]
        body[0][2] += 2
        self.assertFalse(np.all(contained(self.points("lift", 0), body)))

    def test_turn_recovery_contains_full_rotational_sweep(self):
        row = self.rows["haul_carry_wood_1000"]
        boxes = role_boxes(row, "TURN_RECOVERY")
        self.assertEqual(role_boxes(row, "BODY_HELD_LOAD"), boxes)
        for box in boxes + role_boxes(row, "STANCE_SUPPORT"):
            self.assertEqual((box[0], box[2]), (-box[3], -box[5]))
            self.assertEqual(box[3], box[5])
        clouds = [self.points(clip, part) for clip in row["clips"] for part in (0, 1)]
        cloud = np.concatenate(clouds)
        radius, height = np.hypot(cloud[:, 0], cloud[:, 2]), cloud[:, 1]
        fits = np.zeros(len(cloud), dtype=bool)
        for box in boxes:
            fits |= (radius <= box[3]) & (height >= box[1]) & (height <= box[4])
        self.assertTrue(np.all(fits))  # A rotation about the root preserves radius and height: every yaw.
        raw = D.NATIVE.BASIS.read_bytes()
        size = int.from_bytes(raw[16:20], "little")
        table = np.frombuffer(raw, dtype="<f4", count=131072, offset=20 + size).reshape(-1, 2).astype(np.float64)
        sample = np.concatenate([self.points(clip, part, 8) for clip in row["clips"] for part in (0, 1)])
        for yaw in range(0, 65536, 2048):
            c, s = table[yaw]
            turned = np.stack([c * sample[:, 0] + s * sample[:, 2], sample[:, 1], -s * sample[:, 0] + c * sample[:, 2]], 1)
            self.assertTrue(np.all(contained(turned, boxes)), yaw)
        for clip in row["clips"]:
            stock = self.samples[clip][1]
            self.assertGreater(float(stock[..., 1].min()), 0)

    def test_stance_top_plane_is_zero_and_covers_soles(self):
        influenced = np.any(np.isin(self.body["geometry"][0]["ids"], [3, 4, 7, 8]) &
                            (self.body["geometry"][0]["weights"] > 0), axis=1)
        feet = np.unique(self.body_tri[np.any(influenced[self.body_tri], axis=1)])
        for row in self.report["rows"]:
            support = role_boxes(row, "STANCE_SUPPORT")
            self.assertEqual(len(support), 1)
            box = support[0]
            self.assertEqual((box[1], box[4]), (-1, 0), row["name"])
            for other in row["boxes"]:
                b = other["bounds_u"]
                # Body floor portions stand on R's support; the stock's own rest contact is at S, not R.
                if other["role"] not in ("STANCE_SUPPORT", "WORK_STROKE") and b[4] == 0:
                    self.assertTrue(all(box[a] <= b[a] and b[a + 3] <= box[a + 3] for a in range(3)), (row["name"], b))
            for clip in row["clips"]:
                soles = self.samples[clip][0][:, feet].reshape(-1, 3)
                self.assertGreater(float(soles[:, 1].min()), 0)
                near = soles[soles[:, 1] <= 1]
                if row["yaw_kind"] == 1:
                    self.assertTrue(np.all(np.hypot(near[:, 0], near[:, 2]) <= box[3]))
                else:
                    flat = near.copy()
                    flat[:, 1] = 0
                    self.assertTrue(np.all(contained(flat, [box])), (row["name"], clip))

    def test_rows_meet_profile_admission_shape(self):
        required = {2: 1 | 4 | 64 | 128 | 256, 3: 1 | 8 | 64 | 256}
        for row in self.report["rows"]:
            boxes = row["boxes"]
            self.assertTrue(3 <= len(boxes) <= D.MAX_BOXES)
            mask = 0
            for box in boxes:
                bounds = box["bounds_u"]
                self.assertEqual(ROLE[box["role"]], box["role_id"])
                self.assertTrue(all(type(v) is int for v in bounds) and all(bounds[a] < bounds[a + 3] for a in range(3)))
                mask |= 1 << box["role_id"]
            self.assertEqual(row["states"] & required[row["mode"]], required[row["mode"]])
            self.assertEqual((row["tool"], row["tool_variant"]), (-1, -1))
            if row["mode"] == D.MODE["WORK"]:
                self.assertEqual(mask, 31)
                self.assertEqual((row["yaw_kind"], row["yaw"] % 16384), (0, 0))
            else:
                self.assertEqual(mask, 7)
                self.assertEqual((row["yaw_kind"], row["yaw"]), (1, 0))
            low, high = row["quantity_milli"]
            self.assertTrue((row["cargo"] is None and high == 0) or (row["cargo"] == "wood" and low == high == 1000))

    def test_station_offsets_and_both_grip_contacts(self):
        station = self.report["station"]
        packet = json.loads((D.STATIC_DIR / "station-contact-packet.json").read_text())
        self.assertEqual(station["R_minus_S_u"], [0, 0, 576])
        self.assertEqual(station["S_u"], packet["S_u"])
        self.assertEqual(len(station["grip_contacts"]), 2)
        stroke = role_boxes(self.rows["haul_load_wood_1000"], "WORK_STROKE")
        held = role_boxes(self.rows["haul_load_wood_1000"], "BODY_HELD_LOAD")
        for contact, reviewed in zip(station["grip_contacts"], packet["hand_contacts"]):
            c_s = [Fraction(*v) for v in contact["C_minus_S_u"]]
            c_r = [Fraction(*v) for v in contact["C_minus_R_u"]]
            self.assertEqual(c_r, [a - b for a, b in zip(c_s, station["R_minus_S_u"])])
            self.assertEqual(contact["hand_bone"], reviewed["hand"])
            self.assertEqual(contact["C_minus_S_cell_u"], reviewed["enclosing_contact_cell_relative_S_u"])
            self.assertTrue(all(abs(float(a) - b) < 1e-9 for a, b in zip(c_s, reviewed["C_minus_S_u"])))
            for exact, key in ((c_s, "C_minus_S_cell_u"), (c_r, "C_minus_R_cell_u")):
                box = contact[key]
                self.assertTrue(all(box[a] <= exact[a] <= box[a + 3] <= box[a] + 1 for a in range(3)))
            point = np.asarray([[float(v) for v in c_r]])
            self.assertTrue(contained(point, stroke)[0] and contained(point, held)[0])

    def test_clip_encloses_every_plane_crossing(self):
        # Two triangles cross Y=0 at X=5 and X=2; every other corner is at X<=0.
        low = np.array([[[0, -1, 0], [10, 1, 0], [-1, 1, 0], [0, -1, 1], [4, 1, 1], [-1, 1, 1]]] * 2, dtype=np.int64)
        triangles = np.array([[0, 1, 2], [3, 4, 5]])
        box = D.clip_below(low, low.copy(), triangles)
        self.assertEqual((box[1], box[3], box[4]), (-1, 5, 0))


def main() -> None:
    global ARGS
    parser = argparse.ArgumentParser(add_help=False)
    for name in ("palette", "grip-palette", "world-basis"):
        parser.add_argument("--" + name, type=Path, required=True)
    ARGS, remaining = parser.parse_known_args()
    unittest.main(argv=[__file__, *remaining])


if __name__ == "__main__":
    main()
