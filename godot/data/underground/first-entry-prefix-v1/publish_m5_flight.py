#!/usr/bin/env python3
"""Create-only M5 successor of the first-entry stair bundle (decisions 2043 P-2043-1 (a) and 2044).

M5 is today's qualified 1 m module (`qualified-stairs-v10`) five times in a straight line, module j translated by
(0, -1024j, -5120j), each module after the first standing on the previous module's natural run-out. Module 4's floor is
level 1's floor. Nothing is chosen that v10 does not already fix; every M5 number below is v10's moved by a module
translation, or follows from 2043 §3's construction order and 2044's rulings:

- **Structure** (one 232-part variant, P-2044-5 (a)): v10's 52 parts, then modules 1-4 as v10's parts 7-51 (T0..T5 and
  the sill, 45 parts) translated. Natural bearings likewise. LANDING regions: v10's eight, then each module's T0..T6,
  then one floor LANDING per landing (the previous module's run-out and every row past it at that depth, to the end
  wall), on which that module's floor stops and the next stage's deep stations stand.
- **Grouping and recipes:** 36 assemblies: L0, then T0..T6 a module. Every module's T0 carries T0's bill (wood 1,000,
  12,000 mWU; P-DF-4 (a), installed from a landing); every other tread v10's (wood 1,000, DEC-059's 5,640 mWU).
- **Workpieces:** each assembly's staged left bearer, v10's transform moved by d - R(d) for the module offset d.
- **Frontier** (revision 10, source 4):
  - v10's rows unchanged and first (every v10 index is kept);
  - the top metre of rows 7-26 from land stations at +-1430 u (row centres), prefix 2, as v10's rows 3-6;
  - each module's tread stops, T0..T6 stations and INSTALL rows, translated;
  - per landing (module j-1's floor, depth j): the floor stops F, U and F' of decision 1972's inventory, the next
    module's H' (its T0 station), P', A0' and U0' (L0's stops translated), the deep stations of layer j + 1 (2044:
    dig row 56 at yaw 0 from the uphill row, x -300 and +300, z 406 u inside the row's downhill edge, travel on the
    all-yaw claw WALK 42), and one support strip per row of that floor (x +-768, 128 u deep);
  - the deep episodes of layer j + 1 in 2044's cut order (row-major from the end wall, column 0 then 1), prefix
    8 + 7(j - 1), each retaining the next module's post bearings under it as v10's episodes do.
- **The strip kind** (P-2044-12 (a)): a BEARING of kind 2 whose second field names the episode whose BRACE start
  retires it (-1: never; a landing's own rows). A deep row's strip is retired by the first cube cut in that row.

    python3 godot/data/underground/first-entry-prefix-v1/publish_m5_flight.py [--m2]

Decision 2044 (P-2044-15, "Land M2 now"): `--m2` publishes `qualified-stairs-m2-v1`, the same construction with the
first two modules only (12 rows, 15 assemblies, 97 parts), ending on module 1's floor 2,048 u down. M2 is an interim;
M5 stays the target.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent


def _load(name: str, path: Path):
    """Import a sibling publisher by path (create-only bundles are never edited in place)."""
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


V10 = _load("publish_qualified_stairs_v10", HERE / "publish_qualified_stairs.py")
K = V10.K
ROOT = V10.ROOT
FRONTIER_REVISION = 10
MODULE_DROP, MODULE_RUN = 1024, 5120
## The layout is chosen by `select`: M5 (five modules, the target) or M2 (2044's P-2044-15 interim: the first two,
## ending on module 1's floor 2,048 u down). Every count below follows from MODULES.
MODULES = 5
ROWS = 27
END_WALL = -1024 * ROWS
## Decision 2045 (P-2045-11 (a)): M5's successor `qualified-stairs-m5-v2` adds the turning spot R' on each landing and
## sizes U0' by the approach 45; M2's interim `qualified-stairs-m2-v1` keeps P-2044-16 (a)'s design.
OUTPUT = HERE / "qualified-stairs-m5-v2"
RES = "res://data/underground/first-entry-prefix-v1/qualified-stairs-m5-v2/"


def select(modules: int) -> None:
    """Bind the module-count globals for M5 (5) or the M2 interim (2); nothing else is ruled."""
    global MODULES, ROWS, END_WALL, OUTPUT, RES
    V10.require(modules in (2, 5), "LAYOUT")
    MODULES = modules
    ROWS = 2 + 5 * modules
    END_WALL = -1024 * ROWS
    name = "qualified-stairs-m5-v2" if modules == 5 else "qualified-stairs-m2-v1"
    OUTPUT = HERE / name
    RES = "res://data/underground/first-entry-prefix-v1/%s/" % name


def turning() -> bool:
    """Decision 2045 (P-2045-11 (a)): whether the selected layout publishes the turning spot R' (M5's v2 only)."""
    return MODULES == 5


def part_count() -> int:
    """v10's 52 parts and 45 a later module."""
    return 52 + 45 * (MODULES - 1)


def assembly_count() -> int:
    """L0 and seven a module."""
    return 1 + 7 * MODULES
NATURAL_KIND, STRIP_KIND = 0, 2
STRIP_HALF_X = 768  # Inside every post bearing (|x| >= 768): strips never meet a bearing.
STRIP_DEPTH = 128  # NATURAL_DEPTH_U, decision 1972.
DECK_DEPTH = 258  # P-2044-16 (a): the deepest rooted body under a landing's deck rows, the ascent from T1' to T0'
# (its body reaches 161 u back under the landing row, 258 u below the floor), past the decks' 128;
# test_landing_clearance.py derives it from the profile wire.
DEEP_X = (-300, 300)  # 2044: row 56's contact (224, 0, -544) lands in the column; turns (+-712) stay in the slot.
DEEP_INSIDE = 406  # The land stations' stand-off (1430 - 1024).
DIG_FORWARD = 56  # Claw dig row at yaw 0 (CLAW_DIG_ROWS[0]).
DEEP_TRAVEL = V10.WALK  # 42, the all-yaw claw WALK.
FLOOR_ARRIVAL, FLOOR_ASCENT, FLOOR_WALK_OFF = 343, 169, 686  # Decision 1972's F, U and F' beyond the sill's far edge.
FIXTURE_WOOD = 39000
MAX_FRONTIER_BYTES = 56000  # P-2044-2 (a): the raised Frontier bound; set to the measured size once final.


def offset(module: int) -> tuple:
    """Module j's translation."""
    return (0, -MODULE_DROP * module, -MODULE_RUN * module)


def moved(box: list, module: int) -> list:
    """A source box translated to module `module`."""
    d = offset(module)
    return [box[0] + d[0], box[1] + d[1], box[2] + d[2], box[3] + d[0], box[4] + d[1], box[5] + d[2]]


def part_base(module: int) -> int:
    """The first part of module j's T0 (v10's 7 for module 0)."""
    return 7 if module == 0 else 52 + 45 * (module - 1)


def assembly_of(module: int, k: int) -> int:
    """Module j's T_k assembly (k = 0..6; L0 is 0)."""
    return 1 + 7 * module + k


def floor_landing_ordinal(landing: int) -> int:
    """Region ordinal of landing j's floor LANDING (j = 1..5): after v10's eight and modules 1-4's 28 tread
    LANDINGs (region 0 is the envelope)."""
    return 1 + 8 + 7 * (MODULES - 1) + (landing - 1)


def tread_landing_ordinal(module: int, k: int) -> int:
    """Region ordinal of module j's T_k LANDING (k = 0..6)."""
    return 2 + k if module == 0 else 9 + 7 * (module - 1) + k


def parts_all(spec: dict) -> list:
    """v10's 52 parts, then modules 1-4 (v10's parts 7-51 translated)."""
    base = V10.tread_parts(spec)
    out = list(base)
    for module in range(1, MODULES):
        out += [moved(box, module) for box in base[7:]]
    return out


def bearings_all(spec: dict, parts: list) -> list:
    """v10's natural bearings, then each module's (T0's spec bearings 4-7 and v10's tread bearings) translated."""
    base = V10.natural_bearings(spec, V10.tread_parts(spec))
    out = list(base)
    for module in range(1, MODULES):
        out += [moved(box, module) for box in base[4:]]
    return out


def landings_all() -> list:
    """v10's eight LANDINGs, modules 1-4's T0..T6 tops, then each landing's floor (to the end wall)."""
    base = V10.landings()
    out = list(base)
    for module in range(1, MODULES):
        out += [moved(box, module) for box in base[1:]]
    for landing in range(1, MODULES + 1):
        y = -MODULE_DROP * landing
        out.append([-1024, y, END_WALL, 1024, y + 1, V10.far(V10.SILL) - MODULE_RUN * (landing - 1)])
    return out


def cut_groups() -> list:
    """v10's six groups, then each later module's five rows at its full depth (2043 §3)."""
    out = [c["bounds_u"] for c in V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))["cut_groups"]] \
        + V10.cut_rows()
    for module in range(1, MODULES):
        for row in range(2 + 5 * module, 7 + 5 * module):
            out.append([-1024, -1024 * (module + 1), -1024 * (row + 1), 1024, 0, -1024 * row])
    return out


def structure(spec: dict, old: bytes, ground: bytes, profile: bytes) -> tuple:
    """The 232-part structure catalog, as v10's builder lays it out."""
    parts = parts_all(spec)
    bearings = bearings_all(spec, parts)
    cuts = cut_groups()
    bounds = parts + bearings + cuts + [box for landing in range(1, MODULES + 1) for _, box in strip_boxes(landing)]
    envelope = [min(b[a] for b in bounds) for a in range(3)] + [max(b[a + 3] for b in bounds) for a in range(3)]
    old_regions = V10.regions_of(old)
    envelope[4] = old_regions[0][4]
    regions = [envelope + [V10.ENVELOPE, 0]] + [box + [V10.LANDING, 0] for box in landings_all()]
    regions += [old_regions[3]] + [b + [V10.SUPPORT_REQUIRED, 0] for b in bearings] \
        + [b + [V10.SOLID, 0] for b in parts]
    V10.require(regions[1][:6] == old_regions[1][:6] and regions[2][:6] == old_regions[2][:6], "OLD_REGIONS")
    paces = V10.ground_rows(ground) + [V10.words([row, 0, 0, V10.MOVEMENT, 1, rate, V10.RATE_AUTHORED_MILLI], 1)
                                       for row, rate in V10.STAIR_PACES]
    out = b"UGCONN01" + struct.pack("<Iq7I3q", 1, 1, 1, 2, len(regions), len(parts), 4 * len(parts), 1, len(paces),
                                    V10.CONTENT, 1, V10.CLAW_SOURCE)
    out += profile[32 + 32 * V10.CLAW_SOURCE:64 + 32 * V10.CLAW_SOURCE] + old[104:136]
    variant = list(struct.unpack_from("<26i", old, 136))
    variant[16], variant[18], variant[20] = len(regions), len(parts), 4 * len(parts)
    out += V10.words(variant, 1) + old[136 + 112:136 + 112 + 32]
    out += b"".join(V10.words(r) for r in regions)
    for index, box in enumerate(parts):
        local = part_local(index)
        kind = V10.POST_KIND if local >= 3 and not is_sill_part(index) else V10.TREAD_KIND
        out += V10.words([kind, box[4] - box[1], 0, -1, 0, 0, 0, index * 4, 4])
    for box in parts:
        for x, z in ((box[0], box[2]), (box[3], box[2]), (box[3], box[5]), (box[0], box[5])):
            out += V10.words([x, box[4], z])
    out += V10.words([1024]) + b"".join(paces) + b"UGCEND01"
    return out, parts, bearings


def part_local(index: int) -> int:
    """A part's index within its seven-part assembly (the sill's within its three)."""
    if index < 52: return index % 7 if index < 49 else index - 49
    return (index - 52) % 45 % 7 if (index - 52) % 45 < 42 else (index - 52) % 45 - 42


def is_sill_part(index: int) -> bool:
    """One of a module's three sill parts."""
    return 49 <= index < 52 or (index >= 52 and (index - 52) % 45 >= 42)


def grouping(catalog: bytes, parts: int) -> bytes:
    """36 assemblies: L0, then each module's T0..T5 (seven parts) and sill (three)."""
    rows = [[0, 0, 7, 0]]
    for module in range(MODULES):
        base = part_base(module)
        rows += [[1, base + 7 * k, 7, base + 7 * k] for k in range(6)] + [[1, base + 42, 3, base + 42]]
    V10.require(len(rows) == assembly_count() and rows[7] == [1, 49, 3, 49], "GROUPING")
    out = b"UGASMB01" + struct.pack("<IqqqiqII", 1, 1, 1, 1, 0, 1, len(rows), parts) + V10.sha(catalog)
    return out + b"".join(V10.words(r) for r in rows) + b"UGAEND01"


def recipes(catalog: bytes, group: bytes, old_recipe: bytes) -> bytes:
    """L0's bill, then per module T0's bill and DEC-059's tread bill for T1..T6."""
    out = b"UGRECP01" + struct.pack("<IqqqiqI", 1, 1, 1, 1, 0, 1, assembly_count()) + V10.sha(catalog) + V10.sha(group)
    out += old_recipe[116:116 + 80]
    t0 = old_recipe[116 + 80:116 + 160]
    for module in range(MODULES):
        base = part_base(module)
        out += struct.pack("<i", base) + t0[4:]
        for k in range(1, 7):
            out += struct.pack("<iiq8sq", base + 7 * k, 1, V10.BUILD_MWU, b"wood", V10.WOOD_MILLI) + bytes(48)
    return out + b"UGREND01"


def bearer_transform(module: int, k: int) -> tuple:
    """Module j's T_k staged left bearer: v10's, moved by d - R(d) for the module offset d (R(x, z) = (z, -x))."""
    if module == 0 and k == 0:
        part, turn, t = 8, 3, (2304, 320, -2816)
    elif module == 0:
        part, turn, t = V10.bearer_transform(k + 1)
    else:
        base_part, turn, t = (8, 3, (2304, 320, -2816)) if k == 0 else V10.bearer_transform(k + 1)
        part = part_base(module) + 7 * k + 1
        d = offset(module)
        t = (t[0] - d[2], t[1], t[2] + d[2])
    return part, turn, t


def workpieces(catalog: bytes, group: bytes, recipe: bytes, profile: bytes) -> bytes:
    """Set-down source 5: L0 and every T0 on paw handling 65, every other tread on 66."""
    head = struct.pack("<9q", 1, 1, 1, 1, 1, V10.CONTENT, assembly_count(), 0, V10.PAW_SOURCE)
    out = b"UGWIPC01" + struct.pack("<I", 1) + head + V10.sha(catalog) + V10.sha(group) + V10.sha(recipe)
    out += profile[32 + 32 * V10.PAW_SOURCE:64 + 32 * V10.PAW_SOURCE]
    rows = [(1, 3, (1024, 192, -768), V10.HANDLING)]
    for module in range(MODULES):
        for k in range(7):
            part, turn, t = bearer_transform(module, k)
            rows.append((part, turn, t, V10.HANDLING if k == 0 else V10.TREAD_HANDLING))
    for part, turn, (x, y, z), row in rows:
        out += V10.words([part, turn, x, y, z, row], 1)
    return out + b"UGWEND01"


def strip_rows() -> list:
    """(landing, row) for every deep row a landing's per-row strips cover: module j's rows (5j + 2 on), each retired
    by its own first cube (P-2044-12 (a))."""
    return [(landing, row) for landing in range(1, MODULES + 1) for row in range(5 * landing + 2, ROWS)]


def deck_rows(landing: int) -> range:
    """P-2044-16 (a): the rows under landing j's walk-off and back-up decks (71: F - 1,193 to F + 5,975; 72: F' - 850
    to F' + 6,318), module j-1's seven rows from its L0 position to its run-out: 5(j - 1) .. 5j + 1. Never cut deeper."""
    return range(5 * (landing - 1), 5 * landing + 2)


def strip_boxes(landing: int) -> list:
    """(row, box) for landing j's retained floor (kind 2) under the floor: the deck rows (`DECK_DEPTH` deep) at full slot
    width as a centre slab (x +-768) and two side bands (768 <= |x| <= 1,024, where the posts' natural bearings already
    are, so staging keeps only what they leave), row -1 (never retired); then module j's rows at x +-768, one each."""
    y = -MODULE_DROP * landing
    rows = deck_rows(landing)
    near, far = -1024 * rows[0], -1024 * (rows[-1] + 1)
    out = [(-1, [-STRIP_HALF_X, y - DECK_DEPTH, far, STRIP_HALF_X, y, near]),
           (-1, [-1024, y - DECK_DEPTH, far, -STRIP_HALF_X, y, near]),
           (-1, [STRIP_HALF_X, y - DECK_DEPTH, far, 1024, y, near])]
    return out + [(row, strip_box(landing, row)) for row in range(5 * landing + 2, ROWS)]


def strip_box(landing: int, row: int) -> list:
    """One floor row's strip under landing j's floor: x +-768, 128 u deep, the row's full length."""
    y = -MODULE_DROP * landing
    return [-STRIP_HALF_X, y - STRIP_DEPTH, -1024 * (row + 1), STRIP_HALF_X, y, -1024 * row]


def deep_rows(landing: int) -> range:
    """The rows layer landing + 1 cuts: the next module's first row to the end wall (none from the last floor)."""
    return range(2 + 5 * landing, ROWS) if landing < MODULES else range(0)


def deep_order(landing: int) -> list:
    """2044's cut order for layer landing + 1: row-major from the end wall, column 0 then column 1."""
    return [(row, column) for row in reversed(deep_rows(landing)) for column in (0, 1)]


V10_FILES_SHA = {
    "frontier.ugfront": "8ee90bbff55e11c45604af294cb47fb21e2b097c99484f000310464b48d0d006",
    "structure.ugconn": "053b14a47f9ae6f6b12ebd7c852c5690cea29d62bc6e50065d2fd19c078f1115",
}
V10_DIR = HERE / "qualified-stairs-v10"
INSTALLED, SURFACE = V10.INSTALLED_CONTACT, V10.SURFACE_CONTACT
TRANSIT, WORK = V10.ROLE_TRANSIT, V10.ROLE_WORK
RETREAT = V10.RETREAT  # 47, the narrow claw retreat.
TAP_ROW = V10.TAP  # 57, the seating tap (T0's station row).
V10_X_WAY_BACK = 25  # The crossing arrival on the approach-up row: every tread order's arrival (v10).
V10_M, V10_R = 10, 11  # M and R on the surface (v10's material and output selectors).


class Tables:
    """The six Frontier tables as int lists, v10's rows first."""

    def __init__(self, old: list) -> None:
        """Start from v10's own tables."""
        self.install, self.station, self.cut, self.bearing, self.endpoint, self.episode = (
            [list(row) for row in table] for table in old)

    def add_endpoint(self, row: list) -> int:
        """Append one selector; its index."""
        self.endpoint.append(row)
        return len(self.endpoint) - 1

    def add_station(self, endpoint: int, yaw: int, profile: int) -> int:
        """Append one WORK station on an endpoint; its index."""
        self.station.append([endpoint] + self.endpoint[endpoint][4:7] + [yaw, profile, 0, V10.FACE, 1])
        return len(self.station) - 1


def v10_tables() -> list:
    """v10's published Frontier, decoded (its digest pinned)."""
    raw = V10.pinned(V10_DIR / "frontier.ugfront", V10_FILES_SHA["frontier.ugfront"])
    return V10.read_frontier(raw)


def stop_point(module: int, level: int, behind: int) -> list:
    """A stop `behind` u behind the far edge of module j's L0 (level -1, its natural landing) or T_level."""
    d = offset(module)
    return [0, V10.top(level) + d[1], V10.far(level) + behind + d[2]]


def floor_point(landing: int, beyond: int) -> list:
    """A stop on landing j's floor, `beyond` u past module j-1's sill's far edge (decision 1972's F/U/F')."""
    return [0, -MODULE_DROP * landing, V10.far(V10.SILL) - beyond - MODULE_RUN * (landing - 1)]


def deep_station_point(landing: int, row: int, column: int) -> list:
    """2044: the station on `row`'s floor that strikes (row + 1, column)'s top face with row 56."""
    return [DEEP_X[column], -MODULE_DROP * landing, -1024 * (row + 1) + DEEP_INSIDE]


def add_land_top_metre(t: Tables, prefix_episodes: list) -> None:
    """Rows 7-26's top metre from surface stations at +-1430 u, prefix 2, as v10's rows 3-6 (no bearings)."""
    for row in range(7, ROWS):
        for left in (True, False):
            x = -V10.CLAW_X if left else V10.CLAW_X
            point = [x, 0, -1024 * row - 512]
            endpoint = t.add_endpoint([SURFACE, -1, 0, WORK] + point + [V10.WALK])
            station = t.add_station(endpoint, 49152 if left else 16384, V10.DIG_LEFT if left else V10.DIG_RIGHT)
            box = [-1024 if left else 0, -1024, -1024 * (row + 1), 0 if left else 1024, 0, -1024 * row]
            prefix_episodes.append(box + [7, 2, station, station, station, 0, 0, 0, 0, V10_M, V10_R, endpoint,
                                          V10.FACE])


def add_strips(t: Tables, landing: int) -> list:
    """Landing j's retained floor (kind 2, `strip_boxes`); the episode that retires each deep row's strip is patched in
    once the deep episodes exist. Returns [(bearing index, row)], row -1 for the deck slab and bands."""
    out = []
    for row, box in strip_boxes(landing):
        t.bearing.append([STRIP_KIND, -1, -1] + box)
        out.append((len(t.bearing) - 1, row))
    return out


def add_floor_stops(t: Tables, landing: int) -> dict:
    """Decision 1972's floor stops on landing j (module j-1's sill's selectors): F (the descent's arrival), U (the
    ascent's start) and F' (the walk-off's end, 71/72). P-2044-16 (a): F' is a ground stop too, sized by the narrow
    retreat 47, whose body (43's, facing down the flight) clears the sill by 274 u; every ground join at F' faces down
    the flight (43 out, 47 in). But for the last landing, D, the deep stations' hub (P-2044-16 (a)), is the sill's too:
    the landing row's station at the slot's centre line (`DEEP_INSIDE` past module j's L0 far edge), sized by the
    all-yaw claw WALK 42, whose stance stays on the landing row and whose body clears the sill by 870 u. It leaves with
    the landing's last deep stations, before T0' sets its bearer down where their air reaches."""
    sill = assembly_of(landing - 1, 6)
    at = floor_landing_ordinal(landing)
    out = {"F": t.add_endpoint([INSTALLED, sill, at, TRANSIT] + floor_point(landing, FLOOR_ARRIVAL) + [V10.DESCENT]),
           "U": t.add_endpoint([INSTALLED, sill, at, TRANSIT] + floor_point(landing, FLOOR_ASCENT) + [V10.ASCENT]),
           "F'": t.add_endpoint([INSTALLED, sill, at, TRANSIT] + floor_point(landing, FLOOR_WALK_OFF) + [RETREAT])}
    if landing < MODULES:
        out["D"] = t.add_endpoint([INSTALLED, sill, at, TRANSIT] + stop_point(landing, -1, DEEP_INSIDE) + [DEEP_TRAVEL])
    return out


def add_module_stops(t: Tables, module: int) -> dict:
    """Module j's stops: H' (its T0's station, the previous sill's), P'/A0'/U0' on its natural landing (its T0's, as
    L0's are T0's in v10, so P' stands only once T0's bearer is in), and every tread's A/S/U and the sill's A/U,
    translated."""
    sill = assembly_of(module - 1, 6)
    t0 = assembly_of(module, 0)
    floor = floor_landing_ordinal(module)
    out = {"H": t.add_endpoint([INSTALLED, sill, floor, WORK] + stop_point(module, -1, 512) + [V10.APPROACH]),
           "P": t.add_endpoint([INSTALLED, t0, floor, TRANSIT] + stop_point(module, -1, V10.STATION) + [V10.APPROACH]),
           "A0": t.add_endpoint([INSTALLED, t0, floor, TRANSIT] + stop_point(module, -1, V10.ARRIVAL) + [V10.DESCENT]),
           "U0": t.add_endpoint([INSTALLED, t0, floor, TRANSIT] + stop_point(module, -1, V10.ASCENT_START)
                                + [V10.APPROACH_UP if turning() else RETREAT]),
           "A": [], "S": [], "Us": []}
    # P-2044-16 (a): U0' backed down the landing to F' on 47. Decision 2045 (P-2045-11 (a)): a crew arrives at U0'
    # facing up, so U0' is sized by the approach 45 and the way on is U0' -> R' on 45, a turn at R' (D's point, sized
    # by the all-yaw walk 42, published with this module's T0 once D has gone), then R' -> F' on 47.
    if turning():
        out["R"] = t.add_endpoint([INSTALLED, t0, floor, TRANSIT] + stop_point(module, -1, DEEP_INSIDE) + [DEEP_TRAVEL])
    for level in range(V10.TREADS + 1):
        asm, at = assembly_of(module, level), tread_landing_ordinal(module, level)
        out["A"].append(t.add_endpoint([INSTALLED, asm, at, TRANSIT] + stop_point(module, level, V10.ARRIVAL)
                                       + [V10.DESCENT]))
        if level < V10.TREADS:
            out["S"].append(t.add_endpoint([INSTALLED, asm, at, WORK] + stop_point(module, level, V10.STATION)
                                           + [V10.STEP_BACK]))
        out["Us"].append(t.add_endpoint([INSTALLED, asm, at, TRANSIT] + stop_point(module, level, V10.ASCENT_START)
                                        + [V10.ASCENT]))
    return out


def add_module_bearings(t: Tables, module: int, naturals: list) -> dict:
    """Module j's primary bearings (T0': the natural landing under its near end, as L0's deck strip is T0's; T1'..T6':
    the deck strip of the tread above) and its translated natural bearings."""
    base = part_base(module)
    out = {"primary": len(t.bearing)}
    strip = moved([-256, -64, -2048, 256, 0, -1920], module)
    t.bearing.append([NATURAL_KIND, -1, -1] + strip)
    for k in range(1, 7):
        above = assembly_of(module, k - 1)
        level = k - 1
        box = moved([-256, V10.top(level) - 64, V10.far(level), 256, V10.top(level), V10.far(level) + 128], module)
        t.bearing.append([1, above, base + 7 * (k - 1)] + box)
    out["naturals"] = len(t.bearing)
    for box in naturals:
        t.bearing.append([NATURAL_KIND, -1, -1] + moved(box, module))
    return out


def add_module_installs(t: Tables, module: int, stops: dict, floor: dict, bearings: dict, strips: list) -> None:
    """Module j's seven INSTALL rows: T0' from H' (backing off to F'), each later tread from the station on the tread
    above (the crossing arrival as its way back, as in v10), the sill retaining landing j+1's strips."""
    groups = 6 + 5 * (module - 1)
    nat = bearings["naturals"]
    t0_station = t.add_station(stops["H"], 0, TAP_ROW)
    t.install.append([assembly_of(module, 0), t0_station, bearings["primary"], groups, 1, nat, 4, V10_M,
                      floor["F'"]])
    for k in range(1, 7):
        station = t.add_station(stops["S"][k - 1], 0, V10.TREAD_TAP)
        group = groups + (k // 2 if k < 6 else 3)
        first, count = (nat + 4 * k, 4) if k < 6 else (nat + 24, 2 + len(strips))
        t.install.append([assembly_of(module, k), station, bearings["primary"] + k, group, 1, first, count, V10_M,
                          V10_X_WAY_BACK])


def add_deep(t: Tables, landing: int, naturals: int) -> dict:
    """Layer landing+1's deep stations (landing j's floor, module j-1's sill's selectors) and its episodes in 2044's
    order; returns {(row, column): episode index}."""
    sill = assembly_of(landing - 1, 6)
    floor = floor_landing_ordinal(landing)
    stations = {}
    for row in range(deep_rows(landing)[0] - 1, ROWS - 1):
        for column in (0, 1):
            endpoint = t.add_endpoint([INSTALLED, sill, floor, WORK] + deep_station_point(landing, row, column)
                                      + [DEEP_TRAVEL])
            stations[(row, column)] = (t.add_station(endpoint, 0, DIG_FORWARD), endpoint)
    first_row = 2 + 5 * landing
    ranges = {first_row: (naturals, 4), first_row + 1: (naturals + 8, 8), first_row + 2: (naturals + 16, 8),
              first_row + 3: (naturals + 24, 2)}
    episodes = {}
    for row, column in deep_order(landing):
        station, endpoint = stations[(row - 1, column)]
        box = [-1024 + 1024 * column, -MODULE_DROP * (landing + 1), -1024 * (row + 1), 1024 * column,
               -MODULE_DROP * landing, -1024 * row]
        first, count = ranges.get(row, (0, 0))
        t.episode.append(box + [7, 8 + 7 * (landing - 1), station, station, station, 0, 0, first, count, V10_M, V10_R,
                                endpoint, V10.FACE])
        episodes[(row, column)] = len(t.episode) - 1
    return episodes


def frontier_tables(spec: dict) -> Tables:
    """v10's tables, then the top metre past row 6, every later module and every landing (see the module header)."""
    t = Tables(v10_tables())
    t.cut += [box + [8] for box in cut_groups()[len(t.cut):]]  # Each later module's rows at full depth, SUPPORTED_VOID.
    strips = {1: add_strips(t, 1)}
    t.install[7][6] += len(strips[1])  # v10's sill also retains landing 1's strips (its bearings 36-37 precede them).
    top: list = []
    add_land_top_metre(t, top)
    t.episode += top
    floors = {landing: add_floor_stops(t, landing) for landing in range(1, MODULES + 1)}
    naturals = V10.natural_bearings(spec, V10.tread_parts(spec))[4:]
    first_natural = {}
    for module in range(1, MODULES):
        stops = add_module_stops(t, module)
        bearings = add_module_bearings(t, module, naturals)
        first_natural[module] = bearings["naturals"]
        strips[module + 1] = add_strips(t, module + 1)
        add_module_installs(t, module, stops, floors[module], bearings, strips[module + 1])
    for landing in range(1, MODULES):
        episodes = add_deep(t, landing, first_natural[landing])
        for index, row in strips[landing]:
            t.bearing[index][1] = episodes[(row, 0)] if row >= 2 + 5 * landing else -1
    return t


def frontier(spec: dict, catalog: bytes, group: bytes, recipe: bytes, profile: bytes) -> bytes:
    """Serialize the M5 Frontier at revision 10 on source 4, v10's wire format."""
    t = frontier_tables(spec)
    V10.FRONTIER_REVISION = FRONTIER_REVISION
    return V10.serialize_frontier([t.install, t.station, t.cut, t.bearing, t.endpoint, t.episode], catalog, group,
                                  recipe, profile)


def _frontier_check(raw, cat, group, recipe, profile, assemblies):
    """entry_source_constants' Frontier check at the raised bound (P-2044-2 (a)); otherwise identical."""
    w = K.words
    K.require(len(raw) >= 228 and raw[:8] == b"UGFRNT01" and raw[-8:] == b"UGFEND01"
              and w(raw, 8, kind="I") == (1,), "FRONTIER_FORMAT")
    counts = w(raw, 68, 6, "I")
    K.require(counts[0] == assemblies and all(1 <= n <= 2048 for n in counts)
              and 2048 + sum(n * width for n, width in zip(counts, K.ROW_BYTES)) <= MAX_FRONTIER_BYTES,
              "FRONTIER_CAPACITY")
    K.require(len(raw) == 228 + sum(n * width for n, width in zip(counts, K.ROW_BYTES)), "FRONTIER_LENGTH")
    K.require(w(raw, 20) == w(cat, 12) and w(raw, 28) == w(group, 40) and w(raw, 36) == w(group, 12)
              and w(raw, 44) == w(recipe, 12) and w(raw, 52) == w(profile, 12) and raw[60:64] == group[36:40],
              "FRONTIER_REVISIONS")
    source = w(raw, 64, kind="i")[0]
    K.require(0 <= source < w(profile, 28, kind="I")[0]
              and raw[92:188] == K.digest(cat) + K.digest(group) + K.digest(recipe)
              and raw[188:220] == profile[32 + 32 * source:64 + 32 * source], "FRONTIER_LINK")
    return counts


def build() -> dict:
    """Every bundle file, the accessor and the manifest, in memory."""
    spec = V10.json.loads(V10.pinned(V10.SPEC, V10.SPEC_SHA))
    old = {name: V10.pinned(V10.OLD / name, digest) for name, digest in V10.OLD_SHA.items()}
    old["recipes.ugrecp"] = (V10.OLD / "recipes.ugrecp").read_bytes()
    profile = V10.pinned(V10.RUNTIME / "mole-worker.ugprof", V10.PROFILE_SHA)
    ground = V10.rebound_ground(V10.pinned(V10.RUNTIME / "ground-pace.ugconn", V10.GROUND_SHA), profile)
    catalog, parts, _ = structure(spec, old["structure.ugconn"], ground, profile)
    V10.require(len(parts) == part_count(), "PART_COUNT")
    group = grouping(catalog, len(parts))
    bill = recipes(catalog, group, old["recipes.ugrecp"])
    pieces = workpieces(catalog, group, bill, profile)
    front = frontier(spec, catalog, group, bill, profile)
    files = {"structure.ugconn": catalog, "assemblies.ugasmb": group, "recipes.ugrecp": bill,
             "frontier.ugfront": front, "workpieces.ugwipc": pieces, "ground-pace.ugconn": ground,
             "mole-worker.ugprof": profile}
    checker = K._frontier
    K._frontier = _frontier_check
    try:
        linked = K._linked(files)
    finally:
        K._frontier = checker
    V10.RES = RES
    files["catalog_source.gd"] = V10.accessor(files, linked, profile).replace(
        b"publish_qualified_stairs.py (ADR 1229, decision 1972)", b"publish_m5_flight.py (decisions 2043, 2044)")
    files["manifest.json"] = (json.dumps(manifest(files, linked), indent=2) + "\n").encode()
    return files


def manifest(files: dict, linked: dict) -> dict:
    """What was derived, from what."""
    return {"schema": 1, "decision": ["2043", "2044", "1972", "1229", "1209", "DEC-060", "DEC-059", "DEC-050"],
            "predecessor": "qualified-stairs-v10 (decision 1972)", "layout": "M%d" % MODULES,
            "content_revision": V10.CONTENT, "frontier_revision": FRONTIER_REVISION,
            "frontier_source": V10.CLAW_SOURCE, "workpieces_source": V10.PAW_SOURCE, "assemblies": assembly_count(), "parts": part_count(),
            "stair_paces_milli_u_per_s": {str(row): rate for row, rate in V10.STAIR_PACES},
            "entry_source_constants": linked,
            "files": {name: V10.sha(raw).hex() for name, raw in files.items() if name != "manifest.json"},
            "inputs": {str((V10_DIR / name).relative_to(ROOT)): digest for name, digest in V10_FILES_SHA.items()},
            "runtime_admitted": False}


def main() -> int:
    """Create the successor bundle exactly once: `--m2` publishes 2044's M2 interim, otherwise M5."""
    select(2 if "--m2" in sys.argv[1:] else 5)
    V10.require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), {n: V10.sha(r).hex()[:12] for n, r in outputs.items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
