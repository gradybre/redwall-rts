#!/usr/bin/env python3
"""Decision 2044 (P-2044-16 (a)): body clearance at every landing, for M2 and M5, before anything is built on it.

Every edge P-2044-16 (a) publishes at a landing is checked against every installed part of the flight (each module's
treads, posts and sill, the next module's T0 included), from the published profile wire and stair motion tables:

- ground rows (42 all-yaw claw WALK, 43/45 approaches, 47 retreat): each BODY and TURN box swept along the edge's
  polyline must meet no part (WorldRoutes needs that air void; an installed part is SUPPORT, not void);
- the same rows' stops: each BODY and TURN box at the stop (the Locations air the bindings prove);
- decision 2045 (P-2045-11 (a)): the turning spot R' at D's point, sized by 42 and published with module j's T0, and
  U0' sized by 45; the way up U0' -> R' on 45, the turn at R' on 42, R' -> F' on 47 (M5's bundle; M2 keeps its own
  published design, and R' is checked on its geometry too);
- rooted rows (53 onto the floor, 54 off it, 55 the floor turn, 71 walk-off, 72 back-up): every fixture deck must be
  covered by the Room's support at that landing (parts, retained natural bearings and the retained floor). Their
  bodies may meet the Room's own SUPPORT, and every part here is SUPPORT, so no body test applies to them.

A collision is reported with its row, its stop or segment, the part and the overlap in u on each axis.

    python3 godot/data/underground/first-entry-prefix-v1/test_landing_clearance.py -v
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import struct
import sys
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("publish_m5_flight", HERE / "publish_m5_flight.py")
PUB = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PUB)
V10 = PUB.V10
MOTION = V10.ROOT / "godot/data/underground/mole-worker"
BODY_ROLES = (0, 2)  # BODY (BODY_HELD_LOAD) and TURN (TURN_RECOVERY), as WorldRoutes sweeps them.
WALK, APPROACH, ASCENT_APPROACH, RETREAT = 42, 43, 45, 47
DESCENT, ASCENT, TURN, WALK_OFF, BACK_UP = 53, 54, 55, 71, 72
T0_STATION_Z = -1536  # tread_geometry.gd T0_STATION: L0's station, H (and each module's H').
L0_U, L0_P = 343, 310  # Behind L0's far edge: its U (ascent end) and P (walk-in stop), as v10's stops.


def profile_boxes() -> dict:
    """Every profile's boxes [lo x, lo y, lo z, hi x, hi y, hi z, role], from the pinned content 12 wire."""
    raw = V10.pinned(V10.RUNTIME / "mole-worker.ugprof", V10.PROFILE_SHA)
    _, _, count, boxes, sources = struct.unpack_from("<IqIII", raw, 8)
    at = 32 + 32 * sources
    rows = []
    for _ in range(count):
        fields = struct.unpack_from("<18i", raw, at)
        rows.append((fields[14], fields[15]))
        at += 98
    table = [list(struct.unpack_from("<7i", raw, at + 28 * box)) for box in range(boxes)]
    return {row: table[first:first + n] for row, (first, n) in enumerate(rows)}


def motion_decks() -> dict:
    """Each stair row's fixture decks, in its start root's frame, from both stair motion wires."""
    out = {}
    for name, programs, keys, decks in (("qualified-claw-stair-motion-v1", 5, 457, 7),
                                        ("qualified-stair-carry-motion-v1", 14, 1634, 18)):
        raw = (MOTION / name / "stair-motion.ugstair").read_bytes()
        words = struct.unpack_from("<%di" % (12 * programs), raw, 64)
        deck_words = struct.unpack_from("<%di" % (6 * decks), raw, 64 + 48 * programs + 20 * keys)
        for program in range(programs):
            fields = words[12 * program:12 * program + 12]
            out[fields[0]] = [list(deck_words[6 * d:6 * d + 6]) for d in range(fields[5], fields[5] + fields[4])]
    return out


def overlap(a: list, b: list) -> list | None:
    """The overlap of two boxes on each axis in u, or None when they do not overlap (touching is clear)."""
    widths = [min(a[i + 3], b[i + 3]) - max(a[i], b[i]) for i in range(3)]
    return widths if all(w > 0 for w in widths) else None


def swept(box: list, first: list, last: list) -> list:
    """WorldRoutes' `_sweep_into`: the box swept along one straight segment."""
    return [min(first[i], last[i]) + box[i] for i in range(3)] + [max(first[i], last[i]) + box[i + 3] for i in range(3)]


def subtract(box: list, cover: list) -> list:
    """`box` minus `cover`, as disjoint boxes."""
    if overlap(box, cover) is None:
        return [box]
    out, rest = [], list(box)
    for axis in range(3):
        if rest[axis] < cover[axis]:
            out.append(rest[:axis + 3] + [cover[axis]] + rest[axis + 4:])
            rest[axis] = cover[axis]
        if rest[axis + 3] > cover[axis + 3]:
            out.append(rest[:axis] + [cover[axis + 3]] + rest[axis + 1:])
            rest[axis + 3] = cover[axis + 3]
    return out


def uncovered(box: list, covers: list) -> int:
    """The volume of `box` no cover holds, in u^3."""
    pieces = [box]
    for cover in covers:
        pieces = [part for piece in pieces for part in subtract(piece, cover)]
    return sum((p[3] - p[0]) * (p[4] - p[1]) * (p[5] - p[2]) for p in pieces)


def turning() -> bool:
    """Decision 2045 (P-2045-11 (a)): whether the selected layout's published bundle has the turning spot R' (M5's
    `qualified-stairs-m5-v2`; M2's interim bundle keeps P-2044-16 (a)'s U0' -> F' on 47)."""
    return PUB.MODULES == 5


class Landing:
    """The stops and edges P-2044-16 (a) puts on landing j, in the source frame."""

    def __init__(self, landing: int) -> None:
        """Derive every stop from the publisher's own helpers."""
        self.landing = landing
        self.sill_a = PUB.stop_point(landing - 1, V10.SILL, V10.ARRIVAL)
        self.f = PUB.floor_point(landing, PUB.FLOOR_ARRIVAL)
        self.u = PUB.floor_point(landing, PUB.FLOOR_ASCENT)
        self.fp = PUB.floor_point(landing, PUB.FLOOR_WALK_OFF)
        self.last = landing == PUB.MODULES
        if self.last:
            return
        module = landing
        self.h = [0, -PUB.MODULE_DROP * module, T0_STATION_Z - PUB.MODULE_RUN * module]
        self.p = PUB.stop_point(module, -1, L0_P)
        self.u0 = PUB.stop_point(module, -1, L0_U)
        self.d = PUB.stop_point(module, -1, PUB.DEEP_INSIDE)  # The deep hub: the landing row's station, centred.
        self.r = self.d  # Decision 2045: the turning spot R', at D's point once D has gone with T0's last leg.
        rows = PUB.deep_rows(landing)
        first = rows[0] - 1 if len(rows) else None
        self.deep = {} if first is None else {
            (row, column): PUB.deep_station_point(landing, row, column)
            for row in range(first, PUB.ROWS - 1) for column in (0, 1)}
        self.first_row = first

    def ground_edges(self) -> list:
        """(row, polyline) for every ground edge: the joins at F' and the claw WALK from P' to the deep stations."""
        if self.last:
            return []
        edges = [(APPROACH, [self.fp, self.p]), (APPROACH, [self.fp, self.h]), (RETREAT, [self.h, self.fp]),
                 (RETREAT, [self.p, self.fp]), (APPROACH, [self.fp, self.d]), (RETREAT, [self.d, self.fp])]
        edges += [(ASCENT_APPROACH, [self.u0, self.r])] if turning() else [(RETREAT, [self.u0, self.fp])]
        if self.first_row is not None:
            top = self.deep[(self.first_row, 1)]
            edges += [(WALK, self.l_walk(self.d, top)), (WALK, self.l_walk(top, self.d))]
            for row in range(self.first_row, PUB.ROWS - 1):
                edges += [(WALK, [self.deep[(row, 0)], self.deep[(row, 1)]]),
                          (WALK, [self.deep[(row, 1)], self.deep[(row, 0)]])]
                if row + 1 < PUB.ROWS - 1:
                    edges += [(WALK, [self.deep[(row, 1)], self.deep[(row + 1, 1)]]),
                              (WALK, [self.deep[(row + 1, 1)], self.deep[(row, 1)]])]
        return edges

    @staticmethod
    def l_walk(first: list, last: list) -> list:
        """The stair path's floor walk: an L along the slot's centre line first (from a floor stop) or last."""
        if first[0] == last[0] or first[2] == last[2]:
            return [first, last]
        corner = [first[0], first[1], last[2]] if first[0] == 0 else [last[0], first[1], first[2]]
        return [first, corner, last]

    def ground_stops(self) -> list:
        """(row, point) for every ground stop's air, by the profile of its first selector (which sizes the Location):
        F' and U0' on the retreat 47, H' and P' on 43, the deep hub D and the deep stations on the claw WALK 42."""
        if self.last:
            return []
        return [(RETREAT, self.fp), (ASCENT_APPROACH if turning() else RETREAT, self.u0), (APPROACH, self.h),
                (APPROACH, self.p), (WALK, self.d)] \
            + [(WALK, point) for point in self.deep.values()]

    def air_row(self, point: list) -> int:
        """The profile sizing the stop at `point`."""
        return next(row for row, at in self.ground_stops() if at == point)

    def rooted(self) -> list:
        """(row, start root) of every rooted motion on the landing."""
        return [(DESCENT, self.sill_a), (TURN, self.f), (ASCENT, self.u), (WALK_OFF, self.f), (BACK_UP, self.fp)]

    def rooted_on_floor(self) -> list:
        """(row, start root, clipped) of every rooted motion that starts on the landing floor."""
        return [(TURN, self.f, False), (ASCENT, self.u, False), (WALK_OFF, self.f, False), (BACK_UP, self.fp, False)]

    def next_module_rooted(self) -> list:
        """(row, start root, clipped) of the next module's descents, ascents and half-turns (A0' to its sill), whose
        bodies may reach back under the landing's deck rows."""
        if self.last:
            return []
        out = []
        for level in range(-1, V10.SILL + 1):
            if level < V10.SILL: out.append((DESCENT, PUB.stop_point(self.landing, level, V10.ARRIVAL), True))
            if level >= 0: out.append((ASCENT, PUB.stop_point(self.landing, level, V10.ASCENT_START), True))
            out.append((TURN, PUB.stop_point(self.landing, level, V10.ARRIVAL), True))
        return out


def collisions(layout: int, boxes: dict) -> list:
    """Every body/part overlap on every landing of a layout, as readable lines."""
    PUB.select(layout)
    spec = V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))
    parts = PUB.parts_all(spec)
    found = []
    for landing in range(1, PUB.MODULES + 1):
        site = Landing(landing)
        for row, line in site.ground_edges():
            for segment in range(len(line) - 1):
                for box in (b for b in boxes[row] if b[6] in BODY_ROLES):
                    sweep = swept(box, line[segment], line[segment + 1])
                    found += ["M%d landing %d row %d %s->%s part %d: %s" % (
                        layout, landing, row, line[segment], line[segment + 1], index, hit)
                        for index, part in enumerate(parts) if (hit := overlap(sweep, part))]
        for row, point in site.ground_stops():
            for box in (b for b in boxes[row] if b[6] in BODY_ROLES):
                stance = swept(box, point, point)
                found += ["M%d landing %d stop %s on %d part %d: %s" % (layout, landing, point, row, index, hit)
                          for index, part in enumerate(parts) if (hit := overlap(stance, part))]
    return found


def bounds(boxes: list) -> list:
    """The bounding box of a profile's BODY and TURN boxes (the Location air its selector sizes)."""
    air = [b for b in boxes if b[6] in BODY_ROLES]
    return [min(b[i] for b in air) for i in range(3)] + [max(b[i + 3] for b in air) for i in range(3)]


def uncontained(layout: int, boxes: dict) -> list:
    """Every ground edge whose row's body at either end leaves that stop's air (WorldRoutes' endpoint body test)."""
    PUB.select(layout)
    found = []
    for landing in range(1, PUB.MODULES):
        site = Landing(landing)
        for row, line in site.ground_edges():
            need = bounds(boxes[row])
            for end in (line[0], line[-1]):
                have = bounds(boxes[site.air_row(end)])
                if not all(have[i] <= need[i] and need[i + 3] <= have[i + 3] for i in range(3)):
                    found.append("M%d landing %d row %d at %s: needs %s, stop air %s" % (
                        layout, landing, row, end, need, have))
    return found


class LandingClearance(unittest.TestCase):
    """P-2044-16 (a)'s edges and stops at every landing are clear of every installed part."""

    @classmethod
    def setUpClass(cls) -> None:
        """Read the profile wire and the stair motion tables once."""
        cls.boxes = profile_boxes()
        cls.decks = motion_decks()

    @classmethod
    def tearDownClass(cls) -> None:
        """Leave the publisher on M5, its default."""
        PUB.select(5)

    def test_m2_bodies_clear_every_part(self) -> None:
        """M2: no ground body meets a part."""
        self.assertEqual(collisions(2, self.boxes), [])

    def test_m5_bodies_clear_every_part(self) -> None:
        """M5: no ground body meets a part."""
        self.assertEqual(collisions(5, self.boxes), [])

    def test_every_edge_fits_its_stops_air(self) -> None:
        """Each ground edge's body fits the air of the stop at either end, on both layouts."""
        self.assertEqual(uncontained(2, self.boxes) + uncontained(5, self.boxes), [])

    def test_the_published_stops_are_sized_as_tested(self) -> None:
        """The bundle's first selector at F', U0', P' and H' names the row this test sizes it by."""
        for layout in (2, 5):
            PUB.select(layout)
            t = PUB.frontier_tables(V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA)))
            for landing in range(1, PUB.MODULES):
                site = Landing(landing)
                for row, point in site.ground_stops()[:5]:
                    first = next(e for e in t.endpoint if e[0] == V10.INSTALLED_CONTACT and e[4:7] == point)
                    self.assertEqual(first[7], row, "M%d landing %d stop %s" % (layout, landing, point))

    def test_the_turning_spot_r_clears_every_part_on_every_landing(self) -> None:
        """Decision 2045 (P-2045-11 (a)), on M2's and every M5 landing's geometry: R' (D's point) sized by the all-yaw
        walk 42 meets no installed part, T0 and its bearer included, with its footing on the deck rows; U0' sized by
        the approach 45 likewise; the approach 45 swept U0' -> R' and the retreat 47 swept R' -> F' meet no part; and
        the turn at R' holds both headings' bodies (45 arriving facing up, 47 leaving facing down) in 42's air."""
        walk, up = bounds(self.boxes[WALK]), bounds(self.boxes[ASCENT_APPROACH])
        for row in (ASCENT_APPROACH, RETREAT):
            need = bounds(self.boxes[row])
            self.assertTrue(all(walk[i] <= need[i] and need[i + 3] <= walk[i + 3] for i in range(3)), "row %d in 42" % row)
        for layout in (2, 5):
            PUB.select(layout)
            parts = PUB.parts_all(V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA)))
            for landing in range(1, PUB.MODULES):
                site = Landing(landing)
                rows = PUB.deck_rows(landing)
                low, high = -1024 * (rows[-1] + 1), -1024 * rows[0]
                for row, line in ((WALK, [site.r, site.r]), (ASCENT_APPROACH, [site.u0, site.u0]),
                                  (ASCENT_APPROACH, [site.u0, site.r]), (RETREAT, [site.r, site.fp])):
                    for box in (b for b in self.boxes[row] if b[6] in BODY_ROLES):
                        sweep = swept(box, line[0], line[1])
                        self.assertEqual([i for i, part in enumerate(parts) if overlap(sweep, part)], [],
                                         "M%d landing %d row %d %s" % (layout, landing, row, line))
                for row, point in ((WALK, site.r), (ASCENT_APPROACH, site.u0)):
                    for box in (b for b in self.boxes[row] if b[6] == 1):  # STANCE
                        self.assertGreaterEqual(point[2] + box[2], low, "M%d landing %d %d" % (layout, landing, row))
                        self.assertLessEqual(point[2] + box[5], high)
                self.assertTrue(all(walk[i] <= up[i] and up[i + 3] <= walk[i + 3] for i in range(3)))

    def test_the_all_yaw_walk_cannot_stand_at_u0(self) -> None:
        """The record of P-2045-9 (a)'s failed clearance test: 42's footing at U0' reaches 63 u past the deck rows that
        are never cut, onto module j's first row (cut for layer j + 1, T0 128 u below the floor), on every landing."""
        for layout in (2, 5):
            PUB.select(layout)
            for landing in range(1, PUB.MODULES):
                site = Landing(landing)
                low = -1024 * (PUB.deck_rows(landing)[-1] + 1)
                reach = min(site.u0[2] + b[2] for b in self.boxes[WALK] if b[6] == 1)
                self.assertEqual(low - reach, 63, "M%d landing %d" % (layout, landing))

    def test_the_old_joins_at_f_and_u_collide_with_the_sill(self) -> None:
        """The record of P-2044-14 (a)'s error: at F (343 u) rows 43 and 47 reach 69 u into the sill deck, row 45
        arriving at U (169 u) 352 u, and the claw WALK 712 u wide 369 u at F and 26 u at F'."""
        PUB.select(2)
        spec = V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))
        deck = PUB.parts_all(spec)[49]  # The sill's deck (v10's part 49).
        site = Landing(1)
        reach = {row: max(b[5] for b in self.boxes[row] if b[6] in BODY_ROLES) for row in (APPROACH, ASCENT_APPROACH,
                                                                                            RETREAT, WALK)}
        self.assertEqual(reach, {APPROACH: 412, ASCENT_APPROACH: 521, RETREAT: 412, WALK: 712})
        self.assertEqual(overlap(swept(self.boxes[RETREAT][0], site.f, site.f), deck)[2], 69)
        self.assertEqual(overlap(swept(self.boxes[ASCENT_APPROACH][0], site.u, site.u), deck)[2], 352)
        self.assertEqual(overlap(swept(self.boxes[WALK][0], site.f, site.f), deck)[2], 369)
        self.assertEqual(overlap(swept(self.boxes[WALK][0], site.fp, site.fp), deck)[2], 26)
        self.assertIsNone(overlap(swept(self.boxes[ASCENT_APPROACH][0], site.fp, site.fp), deck))

    def test_the_landing_stops_stand_on_floor_never_cut_deeper(self) -> None:
        """Every stop the landing keeps while the next layer is dug (F', U0', H', P', D) has its whole stance on the
        deck rows, which are never cut deeper: a stance reaching a deep row would lose its support when that row's
        strip goes with its first cube (a 42-sized P' reached 96 u into row 7)."""
        for layout in (2, 5):
            PUB.select(layout)
            for landing in range(1, PUB.MODULES):
                site = Landing(landing)
                rows = PUB.deck_rows(landing)
                low, high = -1024 * (rows[-1] + 1), -1024 * rows[0]
                for row, point in site.ground_stops()[:5]:
                    for box in (b for b in self.boxes[row] if b[6] == 1):  # STANCE
                        self.assertGreaterEqual(point[2] + box[2], low, "M%d landing %d stop %s on %d" % (
                            layout, landing, point, row))
                        self.assertLessEqual(point[2] + box[5], high)

    def test_rooted_bodies_below_a_landing_floor_are_covered(self) -> None:
        """Where a rooted row's body dips below a landing floor (the descent onto T0' from A0' reaches 130 u down), the
        Room's support, its parts or a cut cube holds every unit of it; natural earth is not a Region, so WorldRoutes
        would otherwise need it to be exterior air, which it is not."""
        deepest = 0
        for layout in (2, 5):
            PUB.select(layout)
            spec = V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))
            parts = PUB.parts_all(spec)
            covers = parts + PUB.bearings_all(spec, parts) + PUB.cut_groups() \
                + [box for j in range(1, PUB.MODULES + 1) for _, box in PUB.strip_boxes(j)]
            for landing in range(1, PUB.MODULES + 1):
                floor = -PUB.MODULE_DROP * landing
                rows = PUB.deck_rows(landing)
                for row, root, clip in Landing(landing).rooted_on_floor() + Landing(landing).next_module_rooted():
                    for body in (b for b in self.boxes[row] if b[6] in BODY_ROLES):
                        box = swept(body, root, root)
                        box[4] = min(box[4], floor)
                        if clip:  # Only the part under the landing's deck rows (the next module's own rows are cut).
                            box[2], box[5] = max(box[2], -1024 * (rows[-1] + 1)), min(box[5], -1024 * rows[0])
                        if box[1] >= box[4] or box[2] >= box[5]: continue
                        deepest = max(deepest, floor - box[1])
                        self.assertEqual(uncovered(box, covers), 0, "M%d landing %d row %d at %s" % (
                            layout, landing, row, root))
        self.assertEqual(deepest, PUB.DECK_DEPTH, "the deck slab is exactly as deep as the deepest body")

    def test_rooted_decks_are_covered_by_the_rooms_support(self) -> None:
        """Every fixture deck of 53/54/55/71/72 at each landing lies in parts, bearings and the retained floor."""
        for layout in (2, 5):
            PUB.select(layout)
            spec = V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))
            parts = PUB.parts_all(spec)
            covers = parts + PUB.bearings_all(spec, parts) + [box for j in range(1, PUB.MODULES + 1)
                                                          for _, box in PUB.strip_boxes(j)]
            for landing in range(1, PUB.MODULES + 1):
                for row, root in Landing(landing).rooted():
                    for deck in self.decks[row]:
                        box = [deck[i] + root[i % 3] for i in range(6)]
                        self.assertEqual(uncovered(box, covers), 0, "M%d landing %d row %d deck %s" % (
                            layout, landing, row, box))


if __name__ == "__main__":
    sys.exit(unittest.main())
