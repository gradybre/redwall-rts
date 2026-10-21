#!/usr/bin/env python3
"""Decision 2091 (stair-leg Delivery, phase 1, gate G0): the loaded way down, checked on M2 and M5 before any loaded
edge is published (P-2091-4 (a) publishes them when the way in binds; that is phase 2's).

The loaded way down (decision 1981's W1/W2 and S1/S2, P-2091-5 (a) down-only) is, at every landing j:

- rooted rows: the descent (74 wood, 80 stone) from module j-1's sill onto F, the walk-off on the approach row (73/79,
  decision 1981 W1/S1) from F to F', and, but for the last landing, module j's approach (73/79) from H' to A0' and
  its seven descents (74/80) from A0' to its sill. As `test_landing_clearance.py` checks the empty rooted rows, every
  fixture deck must lie in the Room's support (parts, natural bearings, the retained floor), and every body reaching
  below the landing floor must be held by support or a cut cube (a rooted body may meet the Room's own SUPPORT, so no
  body-against-part test applies to it);
- the loaded ground join F'(j) -> H'(j) on the item's ground CARRY row (32 wood, 37 stone): every BODY and TURN box,
  swept along it and standing at either end, must meet no installed part, and its stance must lie on the deck rows,
  which are never cut deeper;
- the surface join from R's haul stand to the stair's H on the same rows (`underground_entry_work_area.gd` STAND_R;
  phase 2 publishes it): clear of every part but the deck it stands on (a footing box 1 u deep in a part's top face
  is the footing on its support, not a collision).

**No turn.** A loaded mole cannot turn on the ground (no loaded turn is authored; `_carry_approach`), so every loaded
leg from the sill's descent to the next module's approach runs straight down the flight's centre line at one height,
and the surface join's last segment runs down the flight into H.

**Recorded, not a gate:** the ground rows' bodies (32: +-714 u, 37: +-598 u) are wider than the air F' and H' are
sized by today (47 and 43: x -485..479, z -521..412). One box bounding wood's would reach 28 u into the sill deck at
F'; an envelope over the grounded boxes and ADR 1215's one extra air box over the raised load clear every part, so
phase 2 sizes the two stops' air that way.

    python3 godot/data/underground/first-entry-prefix-v1/test_loaded_landing_clearance.py -v
"""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("test_landing_clearance", HERE / "test_landing_clearance.py")
BASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BASE)
PUB, V10 = BASE.PUB, BASE.V10
APPROACH = {"wood": 73, "stone": 79}
DESCENT = {"wood": 74, "stone": 80}
GROUND = {"wood": 32, "stone": 37}
FAMILIES = ("wood", "stone")
STANCE = 1
## `underground_entry_work_area.gd`: R's stock point and the grip stand offset (576, 0, 0) beside it.
R_STAND = [-832 + 576, 0, 1536]
## The stair path's H on L0: tread_geometry.gd T0_STATION (`test_landing_clearance.py` T0_STATION_Z).
H_TOP = [0, 0, BASE.T0_STATION_Z]


def layout(modules: int) -> tuple:
    """Select a layout and return its parts and its two cover lists (decks: parts, bearings and retained floor;
    bodies: those and the cut cubes)."""
    PUB.select(modules)
    spec = V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))
    parts = PUB.parts_all(spec)
    decks = parts + PUB.bearings_all(spec, parts) + [box for j in range(1, PUB.MODULES + 1)
                                                     for _, box in PUB.strip_boxes(j)]
    return parts, decks, decks + PUB.cut_groups()


def rooted_decks(site: BASE.Landing, family: str) -> list:
    """(row, start root) of every loaded rooted motion whose decks lie at or around landing j."""
    out = [(DESCENT[family], site.sill_a), (APPROACH[family], site.f)]
    if not site.last:
        out.append((APPROACH[family], site.h))
        out += [(DESCENT[family], PUB.stop_point(site.landing, level, V10.ARRIVAL)) for level in range(-1, V10.SILL)]
    return out


def rooted_bodies(site: BASE.Landing, family: str) -> list:
    """(row, start root, clipped) of every loaded rooted motion whose body may reach below landing j's floor; the
    next module's descents are clipped to the part under the landing's deck rows (its own rows are cut)."""
    out = [(DESCENT[family], site.sill_a, False), (APPROACH[family], site.f, False)]
    if not site.last:
        out.append((APPROACH[family], site.h, False))
        out += [(DESCENT[family], PUB.stop_point(site.landing, level, V10.ARRIVAL), True)
                for level in range(-1, V10.SILL)]
    return out


def footing(sweep: list, part: list, hit: list) -> bool:
    """A footing box standing on a part's top face: 1 u deep in it, no more (the stance's support contact)."""
    return hit[1] == 1 and sweep[1] == part[4] - 1


def part_hits(boxes: list, line: list, parts: list) -> list:
    """(segment, part, overlap) of every BODY or TURN box swept along `line` that meets a part, footings excepted."""
    found = []
    for segment in range(max(1, len(line) - 1)):
        first, last = line[segment], line[min(segment + 1, len(line) - 1)]
        for box in (b for b in boxes if b[6] in BASE.BODY_ROLES):
            sweep = BASE.swept(box, first, last)
            found += [(segment, index, hit) for index, part in enumerate(parts)
                      if (hit := BASE.overlap(sweep, part)) and not footing(sweep, part, hit)]
    return found


def straight_down(points: list) -> bool:
    """Each point is further down the flight (-Z) than the last, on the centre line, at one height."""
    return all(p[0] == 0 and p[1] == points[0][1] for p in points) \
        and all(points[i + 1][2] < points[i][2] for i in range(len(points) - 1))


class LoadedLandingClearance(unittest.TestCase):
    """G0: the loaded way down fits every landing before anything loaded is published on it."""

    @classmethod
    def setUpClass(cls) -> None:
        """Read the profile wire and the stair motion tables once."""
        cls.boxes = BASE.profile_boxes()
        cls.decks = BASE.motion_decks()

    @classmethod
    def tearDownClass(cls) -> None:
        """Leave the publisher on M5, its default."""
        PUB.select(5)

    def test_the_loaded_rows_are_the_carry_rows(self) -> None:
        """The rows checked here are content 12's stair carry rows (wood 73-78, stone 79-84), each with fixture decks,
        and the grip certificate's ground carry rows, which have none."""
        for family in FAMILIES:
            for row in (APPROACH[family], DESCENT[family]):
                self.assertIn(row, self.decks, "row %d has fixture decks" % row)
            self.assertNotIn(GROUND[family], self.decks, "row %d is a ground row, not rooted" % GROUND[family])
        self.assertEqual((APPROACH["wood"] + 6, DESCENT["wood"] + 6), (APPROACH["stone"], DESCENT["stone"]))

    def test_loaded_rooted_decks_are_covered_by_the_rooms_support(self) -> None:
        """Every fixture deck of the loaded descents, walk-off and approach at each landing lies in support."""
        for modules in (2, 5):
            _, covers, _ = layout(modules)
            for landing in range(1, PUB.MODULES + 1):
                site = BASE.Landing(landing)
                for family in FAMILIES:
                    for row, root in rooted_decks(site, family):
                        for deck in self.decks[row]:
                            box = [deck[i] + root[i % 3] for i in range(6)]
                            self.assertEqual(BASE.uncovered(box, covers), 0, "M%d landing %d row %d deck %s" % (
                                modules, landing, row, box))

    def test_loaded_rooted_bodies_below_a_landing_floor_are_covered(self) -> None:
        """Where a loaded rooted body dips below a landing floor, support or a cut cube holds every unit of it."""
        for modules in (2, 5):
            _, _, covers = layout(modules)
            for landing in range(1, PUB.MODULES + 1):
                site, floor, rows = BASE.Landing(landing), -PUB.MODULE_DROP * landing, PUB.deck_rows(landing)
                for family in FAMILIES:
                    for row, root, clip in rooted_bodies(site, family):
                        for body in (b for b in self.boxes[row] if b[6] in BASE.BODY_ROLES):
                            box = BASE.swept(body, root, root)
                            box[4] = min(box[4], floor)
                            if clip:
                                box[2], box[5] = max(box[2], -1024 * (rows[-1] + 1)), min(box[5], -1024 * rows[0])
                            if box[1] >= box[4] or box[2] >= box[5]: continue
                            self.assertEqual(BASE.uncovered(box, covers), 0, "M%d landing %d row %d at %s" % (
                                modules, landing, row, root))

    def test_the_loaded_joins_clear_every_part(self) -> None:
        """F'(j) -> H'(j) on 32 and 37, swept and standing at either end, meets no installed part on any landing."""
        for modules in (2, 5):
            parts, _, _ = layout(modules)
            for landing in range(1, PUB.MODULES):
                site = BASE.Landing(landing)
                for family in FAMILIES:
                    for line in ([site.fp, site.h], [site.fp, site.fp], [site.h, site.h]):
                        self.assertEqual(part_hits(self.boxes[GROUND[family]], line, parts), [],
                                         "M%d landing %d row %d %s" % (modules, landing, GROUND[family], line))

    def test_the_loaded_joins_stand_on_floor_never_cut_deeper(self) -> None:
        """The ground rows' stance at F' and H' lies on the landing's deck rows."""
        for modules in (2, 5):
            PUB.select(modules)
            for landing in range(1, PUB.MODULES):
                site, rows = BASE.Landing(landing), PUB.deck_rows(landing)
                low, high = -1024 * (rows[-1] + 1), -1024 * rows[0]
                for family in FAMILIES:
                    for point in (site.fp, site.h):
                        for box in (b for b in self.boxes[GROUND[family]] if b[6] == STANCE):
                            self.assertGreaterEqual(point[2] + box[2], low, "M%d landing %d %s" % (modules, landing, point))
                            self.assertLessEqual(point[2] + box[5], high)

    def test_the_loaded_way_down_a_landing_needs_no_turn(self) -> None:
        """The sill's descent lands on F, the walk-off runs to F', the join to H' and the approach to A0', all down the
        flight's centre line at the landing's height after the descent; the last landing ends at F'."""
        for modules in (2, 5):
            PUB.select(modules)
            for landing in range(1, PUB.MODULES + 1):
                site = BASE.Landing(landing)
                self.assertTrue(site.sill_a[2] > site.f[2] and site.sill_a[0] == 0, "M%d landing %d" % (modules, landing))
                way = [site.f, site.fp] if site.last else [site.f, site.fp, site.h,
                                                             PUB.stop_point(landing, -1, V10.ARRIVAL)]
                self.assertTrue(straight_down(way), "M%d landing %d: %s" % (modules, landing, way))

    def test_the_surface_join_clears_every_part_and_arrives_down_the_flight(self) -> None:
        """R's stand -> H: across to the centre line behind the stair, then straight down the flight onto H, meeting no
        part but the L0 deck its feet stand on."""
        line = [R_STAND, [0, 0, R_STAND[2]], H_TOP]
        self.assertTrue(straight_down(line[1:]))
        for modules in (2, 5):
            parts, _, _ = layout(modules)
            for family in FAMILIES:
                self.assertEqual(part_hits(self.boxes[GROUND[family]], line, parts), [], "M%d row %d" % (
                    modules, GROUND[family]))

    def test_a_footing_on_a_part_is_support_not_a_collision(self) -> None:
        """The footing rule is narrow: a stance 1 u in L0's deck is support, a body 2 u in it is not."""
        parts, _, _ = layout(5)
        deck = parts[0]
        foot = BASE.swept([-286, -1, -286, 286, 0, 286, 0], H_TOP, H_TOP)
        self.assertTrue(footing(foot, deck, BASE.overlap(foot, deck)))
        sunk = BASE.swept([-286, -2, -286, 286, 0, 286, 0], H_TOP, H_TOP)
        self.assertFalse(footing(sunk, deck, BASE.overlap(sunk, deck)))
        self.assertNotEqual(part_hits([[-286, -2, -286, 286, 0, 286, 0]], [H_TOP, H_TOP], parts), [])

    def test_the_ground_rows_need_wider_stop_air_at_f_and_h(self) -> None:
        """Recorded for phase 2: 32's and 37's bodies are wider than the air F' (47) and H' (43) are sized by. WorldRoutes
        holds each body box in the stop's air, its envelope or one extra air box (ADR 1215). One box bounding all of
        wood's at F' would reach 28 u into module j-1's sill deck; an envelope over the grounded boxes (with 47's air)
        and one extra box for the raised load box both clear every part, at F' and H' on every landing."""
        air = BASE.bounds(self.boxes[BASE.RETREAT])
        self.assertEqual(air, BASE.bounds(self.boxes[BASE.APPROACH]))
        self.assertEqual(air, [-485, -1, -521, 479, 930, 412])
        self.assertEqual(BASE.bounds(self.boxes[GROUND["wood"]]), [-714, -1, -714, 714, 932, 714])
        self.assertEqual(BASE.bounds(self.boxes[GROUND["stone"]]), [-598, -1, -598, 598, 937, 598])
        for modules in (2, 5):
            parts, _, _ = layout(modules)
            for landing in range(1, PUB.MODULES):
                site = BASE.Landing(landing)
                one = widened(air, BASE.bounds(self.boxes[GROUND["wood"]]))
                self.assertEqual([hit[2][2] for hit in part_hits([one + [0]], [site.fp, site.fp], parts)], [28])
                for family in FAMILIES:
                    envelope, extra = split_air(self.boxes[GROUND[family]])
                    for point in (site.fp, site.h):
                        self.assertEqual(part_hits([widened(air, envelope) + [0], extra + [0]], [point, point], parts),
                                         [], "M%d landing %d %s %s" % (modules, landing, family, point))


def widened(air: list, need: list) -> list:
    """The smallest box holding both."""
    return [min(need[i], air[i]) for i in range(3)] + [max(need[i + 3], air[i + 3]) for i in range(3)]


def split_air(boxes: list) -> tuple:
    """A ground row's BODY and TURN boxes bounded as an envelope over those standing on the floor and one extra box
    over those raised off it (the carried load)."""
    body = [b for b in boxes if b[6] in BASE.BODY_ROLES]
    grounded = [b for b in body if b[1] <= 0]
    raised = [b for b in body if b[1] > 0]
    return BASE.bounds(grounded), BASE.bounds(raised)

if __name__ == "__main__":
    sys.exit(unittest.main())
