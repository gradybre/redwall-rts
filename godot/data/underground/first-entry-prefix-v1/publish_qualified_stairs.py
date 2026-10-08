#!/usr/bin/env python3
"""Create-only T1-T6 successor of the claw first-entry bundle (`qualified-claw-v6`), bound to content 10 (ADR 1229).

ADR 1209's descent past T0 (D1 the sill, D2 the seventh row, D3 T0's bill per tread), fitted by paw (DEC-058), on
content 10's rows. Nothing is chosen: every number below is read from a pinned input or derived by ADR 1209's
rules (`TreadGeometry` mirrors them at runtime).

- **Profiles and ground caps:** content 10's `mole-worker.ugprof` and `ground-pace.ugconn`.
- **Structure** (the one EARTH_TIMBER variant a Placement binds, L0 -> T0 unchanged as its start and end):
  - parts: L0's and T0's fourteen, then T_k = T0 moved by (0, -128k, -512k) for k = 1..5 with posts shortened to
    the cut floor, and the T6 sill (deck and both bearers, the bearers cut to 64 u, no posts): 52 parts;
  - natural bearings under every post and under the sill's bearers (y -1152..-1024, never cut);
  - one LANDING per standing deck: L0, T0..T5 (T6 carries no stop);
  - the envelope spans every part, bearing and cut group, down to the seventh row (z -7168);
  - paces: content 10's 26 ground caps, then DEC-050's authored connector rows on variant 0: descent 53 and ascent
    54 at 528 u/s over the 528 u tread edge (30 ticks), the half-turn 55 at 116 u/s over its 174 u span (45 ticks).
- **Grouping and recipes:** eight assemblies (L0, T0..T6); each of T1..T6 carries T0's wood (1,000 milli, D3) and
  DEC-059's fastening, 12,000 x 0.47 = 5,640 mWU (v9; v8 carried 12,000). L0 and T0 keep their bills.
- **Workpieces** (set-down source 5): L0/T0 on paw handling 65; T_k's staged left bearer (`TreadGeometry`) on the
  tread handling row 66.
- **Frontier** (revision 8 since v9, source 4):
  - claw-v6's rows with content 10's row ids (tap 52 -> 57, dig 57 -> 62 and 53 -> 58);
  - eight more cube episodes (rows 4-7, two cubes each) from surface stations at +-1,430 u, cut with T0's
    prefix installed (before T1), each retaining the natural bearings under it;
  - four more CUT groups (rows 4-7: the entry plan claims exactly the cubes the episodes cut, so the seventh row
    has its own group though no tread names it), the bearings (each tread's forward strip of the deck above, its
    posts');
  - the stair stops: on L0 the walk-in stop 310 u behind its far edge (narrow approach 43), the descent's start
    169 u behind (53), the ascent's end 343 u behind (row 45 leaves it); on T_j (j = 0..5) the arrival 169 u (53), the
    tread station 310 u (WORK; travel 51, station profile 64) and the ascent's start 343 u (54); and the crossing
    arrival (0, 0, -664) with the yaw-32768 approach 45, the way back from the stair;
  - INSTALL rows for T1..T6: the station on the tread above, its forward strip as the primary bearing, its own cut
    group and bearings, M as material and the crossing arrival (45) as the retreat.

    python3 godot/data/underground/first-entry-prefix-v1/publish_qualified_stairs.py
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = HERE / "qualified-claw-v6"
OUTPUT = HERE / "qualified-stairs-v9"
RES = "res://data/underground/first-entry-prefix-v1/qualified-stairs-v9/"
RUNTIME = ROOT / "godot/data/underground/mole-worker/qualified-claw-stairs-v11"
SPEC = ROOT / "docs/design/underground-planning/first-entry-prefix-v1.json"
SPEC_SHA = "edd562056b12f732fbf60f0536207ba2afd1dce650d19df552ecf1e75ff9cf81"
OLD_SHA = {
    "structure.ugconn": "e13ce51dbf394c825fbd7a240ef2568dc9ea4ec5df58b7fa19e02794a72a89e6",
    "frontier.ugfront": "0d81d4f439912f737a5848d29cbfce4ad612da30b85f2d7fe38b5c23e0e8dfc7",
}
PROFILE_SHA = "9791eb59b778cf9fe0b4c66dfd7181c58706abd6ed1a8e6a90a73daafa7f3317"
GROUND_SHA = "e155bf5dfbbde5ddda7702b510d8e299ad8516154c69e024efb1a77f591bc081"
CONTENT, FRONTIER_REVISION, CLAW_SOURCE, PAW_SOURCE = 10, 8, 4, 5
TREADS, SILL = 6, 6
RISE, RUN, L0_FAR, T0_FAR = 128, 512, -2048, -2560
ARRIVAL, STATION, ASCENT_START = 169, 310, 343
CLAW_X = 1430  # DEC-052 follow-up 1 (Brendan, ADR 1217 step 1)
# Content 10 row ids (qualified-claw-stairs-v11/catalog_source.gd).
TAP, DIG_RIGHT, DIG_LEFT, WALK, APPROACH, RETREAT = 57, 58, 62, 42, 43, 47
APPROACH_UP, STEP_BACK, DESCENT, ASCENT, TURN, TREAD_TAP, HANDLING, TREAD_HANDLING = 45, 51, 53, 54, 55, 64, 65, 66
OLD_PROFILE = {52: TAP, 53: DIG_RIGHT, 57: DIG_LEFT}
OLD_TRAVEL = {43: APPROACH, 47: RETREAT, 42: WALK}
# DEC-050: one second a tread, a second and a half a half-turn; the edge lengths are Routes' exact ceil lengths.
TREAD_EDGE_U, TURN_EDGE_U = 528, 174
STAIR_PACES = ((DESCENT, TREAD_EDGE_U), (ASCENT, TREAD_EDGE_U), (TURN, TURN_EDGE_U * 2 // 3))
MOVEMENT = 1  # the adult mole's Movement profile, as every ground cap of content 10 names it
# D3: T0's bill per tread (1,000 milli wood); DEC-059 (P3): T1-T6's fastening 12,000 x 0.47 = 5,640 mWU.
WOOD_MILLI, BUILD_MWU = 1000, 5640
FACE = 3
LANDING, ENVELOPE, SUPPORT_REQUIRED, OPENING, SOLID = 17, 16, 18, 19, 20
TREAD_KIND, POST_KIND = 0, 3
ROLE_TRANSIT, ROLE_STORAGE, ROLE_WORK = 0, 1, 2
INSTALLED_CONTACT, SURFACE_CONTACT = 1, 2
CONSTANTS = importlib.util.spec_from_file_location("entry_constants", HERE / "entry_source_constants.py")
K = importlib.util.module_from_spec(CONSTANTS)
CONSTANTS.loader.exec_module(K)


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed publication fact."""
    if not value:
        raise ValueError("QUALIFIED_STAIRS_" + code)


def sha(raw: bytes) -> bytes:
    """Raw SHA-256."""
    return hashlib.sha256(raw).digest()


def words(values: list, revision: int | None = None) -> bytes:
    """Little-endian int32 words, then an optional int64."""
    require(all(type(v) is int and -(1 << 31) <= v < (1 << 31) for v in values), "INTEGER")
    raw = struct.pack("<" + "i" * len(values), *values)
    return raw if revision is None else raw + struct.pack("<q", revision)


def pinned(path: Path, digest: str) -> bytes:
    """One pinned input."""
    raw = path.read_bytes()
    require(sha(raw).hex() == digest, "INPUT_" + path.name)
    return raw


def top(level: int) -> int:
    """The walking surface of L0 (-1) or T_level."""
    return 0 if level < 0 else -RISE * (level + 1)


def far(level: int) -> int:
    """The far edge of L0 (-1) or T_level."""
    return L0_FAR if level < 0 else T0_FAR - RUN * level


def moved(box: list, k: int) -> list:
    """T0's box moved down k pitches."""
    return [box[0], box[1] - RISE * k, box[2] - RUN * k, box[3], box[4] - RISE * k, box[5] - RUN * k]


def tread_parts(spec: dict) -> list:
    """52 part boxes: L0, T0, T1..T5 (posts shortened to the floor), the T6 sill (deck and 64 u bearers)."""
    t0 = [p["bounds_u"] for p in spec["parts"][7:14]]
    parts = [p["bounds_u"] for p in spec["parts"]]
    for k in range(1, TREADS):
        for index, box in enumerate(t0):
            box = moved(box, k)
            if index >= 3:
                box[1] = -1024  # a post stands on the cut floor (ADR 1209 derivation)
            require(box[1] < box[4], "POST_BELOW_FLOOR")
            parts.append(box)
    deck, left, right = (moved(t0[i], SILL) for i in range(3))
    for bearer in (left, right):
        bearer[1], bearer[4] = -1024, -1024 + (bearer[4] - bearer[1]) // 2  # D1: cut to 64 u, resting on the floor
    require(deck[1] == left[4] == right[4] == -960, "SILL_GEOMETRY")
    return parts + [deck, left, right]


def assembly_of(part: int) -> int:
    """Assembly index of a part: seven per assembly, the sill last."""
    return min(part // 7, 7)


def natural_bearings(spec: dict, parts: list) -> list:
    """L0's and T0's retained natural ground, then under every post of T1..T5 and the sill's bearers (y -1152..-1024)."""
    bearings = [b["bounds_u"] for b in spec["natural_bearings"]]
    for part, box in enumerate(parts[14:], start=14):
        post = part < 49 and (part - 14) % 7 >= 3
        if post or part in (50, 51):
            bearings.append([box[0], -1152, box[2], box[3], -1024, box[5]])
    return bearings


def landings() -> list:
    """LANDING metadata of L0 and T0..T5: each deck's top face."""
    out = [[-1024, 0, L0_FAR, 1024, 1, 0]]
    for level in range(TREADS):
        out.append([-1024, top(level), far(level), 1024, top(level) + 1, far(level) + RUN])
    return out


def ground_rows(ground: bytes) -> list:
    """Content 10's ground caps, verbatim."""
    count = struct.unpack_from("<I", ground, 44)[0]
    return [ground[136 + 36 * row:172 + 36 * row] for row in range(count)]


def structure(spec: dict, old: bytes, ground: bytes, profile: bytes) -> tuple:
    """The structure catalog and its part census."""
    parts = tread_parts(spec)
    bearings = natural_bearings(spec, parts)
    cuts = [c["bounds_u"] for c in spec["cut_groups"]] + cut_rows()
    bounds = parts + bearings + cuts
    envelope = [min(b[a] for b in bounds) for a in range(3)] + [max(b[a + 3] for b in bounds) for a in range(3)]
    old_regions = regions_of(old)
    envelope[4] = old_regions[0][4]  # the tallest authored profile, as compile_entry_prefix derives it (1,192 u)
    regions = [envelope + [ENVELOPE, 0]] + [box + [LANDING, 0] for box in landings()]
    regions += [old_regions[3]] + [b + [SUPPORT_REQUIRED, 0] for b in bearings] + [b + [SOLID, 0] for b in parts]
    require(old_regions[3][6] == OPENING and regions[1][:6] == old_regions[1][:6]
            and regions[2][:6] == old_regions[2][:6], "OLD_REGIONS")
    paces = ground_rows(ground) + [words([row, 0, 0, MOVEMENT, 1, rate, 1], 1) for row, rate in STAIR_PACES]
    out = b"UGCONN01" + struct.pack("<Iq7I3q", 1, 1, 1, 2, len(regions), len(parts), 4 * len(parts), 1, len(paces),
                                    CONTENT, 1, CLAW_SOURCE)
    out += profile[32 + 32 * CLAW_SOURCE:64 + 32 * CLAW_SOURCE] + old[104:136]
    variant = list(struct.unpack_from("<26i", old, 136))
    variant[16], variant[18], variant[20] = len(regions), len(parts), 4 * len(parts)
    out += words(variant, 1) + old[136 + 112:136 + 112 + 32]
    out += b"".join(words(r) for r in regions)
    for index, box in enumerate(parts):
        local = index % 7 if index < 49 else index - 49
        kind = POST_KIND if index < 49 and local >= 3 else TREAD_KIND
        out += words([kind, box[4] - box[1], 0, -1, 0, 0, 0, index * 4, 4])
    for box in parts:
        for x, z in ((box[0], box[2]), (box[3], box[2]), (box[3], box[5]), (box[0], box[5])):
            out += words([x, box[4], z])
    out += words([1024]) + b"".join(paces) + b"UGCEND01"
    return out, parts, bearings


def regions_of(catalog: bytes) -> list:
    """Every region row of a catalog."""
    counts = struct.unpack_from("<7I", catalog, 20)
    at = 136 + counts[0] * 112 + counts[1] * 16
    return [list(struct.unpack_from("<8i", catalog, at + 32 * r)) for r in range(counts[2])]


def cut_rows() -> list:
    """The four new cut groups (rows 4-7). No tread stands in the seventh row (D2), but the entry plan's claims are
    the CUT rows and the bindings require them to be exactly the cubes the episodes cut."""
    return [[-1024, -1024, -1024 * (row + 1), 1024, 0, -1024 * row] for row in (3, 4, 5, 6)]


def grouping(catalog: bytes, parts: int) -> bytes:
    """Eight assemblies: L0, T0..T5 seven parts each, the sill three; the anchor is each first part."""
    rows = [[0, 0, 7, 0]] + [[1, 7 * a, 7, 7 * a] for a in range(1, 7)] + [[1, 49, 3, 49]]
    out = b"UGASMB01" + struct.pack("<IqqqiqII", 1, 1, 1, 1, 0, 1, len(rows), parts) + sha(catalog)
    return out + b"".join(words(r) for r in rows) + b"UGAEND01"


def recipes(catalog: bytes, group: bytes, old_recipe: bytes) -> bytes:
    """L0's and T0's bills unchanged; T0's wood for every tread (D3), fastened in 5,640 mWU (DEC-059)."""
    out = b"UGRECP01" + struct.pack("<IqqqiqI", 1, 1, 1, 1, 0, 1, 8) + sha(catalog) + sha(group)
    out += old_recipe[116:116 + 160]
    for anchor in [7 * a for a in range(2, 7)] + [49]:
        out += struct.pack("<iiq8sq", anchor, 1, BUILD_MWU, b"wood", WOOD_MILLI) + bytes(48)
    return out + b"UGREND01"


def bearer_transform(assembly: int) -> tuple:
    """The staged left bearer of T_{assembly-1}: part, turn 3, translation (TreadGeometry's rule)."""
    k = assembly - 1
    part = 7 * assembly + 1  # the assembly's first part (seven per assembly from L0's 0) plus one; the sill's is 50
    rise = 0 if k < SILL else 64
    return part, 3, (2304 + RUN * k, 320 - rise, -2816 - RUN * k)


def workpieces(catalog: bytes, group: bytes, recipe: bytes, profile: bytes) -> bytes:
    """Set-down source 5: L0/T0 on 65, the treads on 66 with their derived staged bearers."""
    head = struct.pack("<9q", 1, 1, 1, 1, 1, CONTENT, 8, 0, PAW_SOURCE)
    out = b"UGWIPC01" + struct.pack("<I", 1) + head + sha(catalog) + sha(group) + sha(recipe)
    out += profile[32 + 32 * PAW_SOURCE:64 + 32 * PAW_SOURCE]
    rows = [(1, 3, (1024, 192, -768), HANDLING), (8, 3, (2304, 320, -2816), HANDLING)]
    rows += [bearer_transform(a) + (TREAD_HANDLING,) for a in range(2, 8)]
    for part, turn, (x, y, z), row in rows:
        out += words([part, turn, x, y, z, row], 1)
    return out + b"UGWEND01"


def read_frontier(raw: bytes) -> list:
    """claw-v6's six tables as int lists, endpoint travel pairs alongside."""
    counts = struct.unpack_from("<6I", raw, 68)
    fields, at, tables = (9, 9, 7, 9, 7, 19), 220, []
    for t, n in enumerate(counts):
        rows = []
        for _ in range(n):
            row = list(struct.unpack_from("<%di" % fields[t], raw, at))
            at += 4 * fields[t]
            if t == 1:
                at += 44
            elif t == 4:
                row.append(struct.unpack_from("<i", raw, at)[0])
                at += 12
            rows.append(row)
        tables.append(rows)
    return tables


def stop(level: int, behind: int) -> list:
    """A stop's point on L0 (-1) or T_level."""
    return [0, top(level), far(level) + behind]


def stair_endpoints() -> list:
    """[kind, assembly, landing, role, x, y, z, travel] for every stair stop and the way back."""
    out = [[INSTALLED_CONTACT, 1, 1, ROLE_TRANSIT] + stop(-1, STATION) + [APPROACH],
           [INSTALLED_CONTACT, 1, 1, ROLE_TRANSIT] + stop(-1, ARRIVAL) + [DESCENT],
           [INSTALLED_CONTACT, 1, 1, ROLE_TRANSIT] + stop(-1, ASCENT_START) + [APPROACH_UP],
           [INSTALLED_CONTACT, 0, 1, ROLE_TRANSIT, 0, 0, -664, APPROACH_UP]]
    for level in range(TREADS):
        landing = 2 + level
        out += [[INSTALLED_CONTACT, level + 1, landing, ROLE_TRANSIT] + stop(level, ARRIVAL) + [DESCENT],
                [INSTALLED_CONTACT, level + 1, landing, ROLE_WORK] + stop(level, STATION) + [STEP_BACK],
                [INSTALLED_CONTACT, level + 1, landing, ROLE_TRANSIT] + stop(level, ASCENT_START) + [ASCENT]]
    return out


def cube_cuts() -> list:
    """The eight new cubes (rows 4-7, left then right) and their surface stations."""
    out = []
    for row in range(3, 7):
        for left in (True, False):
            x = -1024 if left else 0
            box = [x, -1024, -1024 * (row + 1), x + 1024, 0, -1024 * row]
            station = [-CLAW_X if left else CLAW_X, 0, -1024 * row - 512]
            out.append((box, station, 49152 if left else 16384, DIG_LEFT if left else DIG_RIGHT))
    return out


def frontier(old_raw: bytes, catalog: bytes, group: bytes, recipe: bytes, profile: bytes, parts: list,
             bearings: list) -> bytes:
    """claw-v6's rows on content 10, then the treads' cuts, bearings, stops, stations and installs."""
    install, stations, cuts, bearing_rows, endpoints, episodes = read_frontier(old_raw)
    for row in stations:
        require(row[5] in OLD_PROFILE, "OLD_STATION_PROFILE")
        row[5] = OLD_PROFILE[row[5]]
    for row in endpoints:
        require(row[7] in OLD_TRAVEL, "OLD_ENDPOINT_TRAVEL")
        row[7] = OLD_TRAVEL[row[7]]
    first_new_bearing = len(bearing_rows)
    bearing_rows += tread_bearings(parts, bearings)
    cuts += [box + [8] for box in cut_rows()]
    cube_station_first = len(stations)
    for box, point, yaw, profile_row in cube_cuts():
        endpoints.append([SURFACE_CONTACT, -1, 0, ROLE_WORK] + point + [WALK])
        stations.append([len(endpoints) - 1] + point + [yaw, profile_row, 0, FACE, 1])
    stair_first = len(endpoints)
    endpoints += stair_endpoints()
    tread_station_first = len(stations)
    for level in range(TREADS):
        index = stair_first + 4 + 3 * level + 1
        stations.append([index] + endpoints[index][4:7] + [0, TREAD_TAP, 0, FACE, 1])
    episodes += cube_episodes(stations, cube_station_first, first_new_bearing)
    install += tread_installs(tread_station_first, first_new_bearing, stair_first + 3)
    return serialize_frontier([install, stations, cuts, bearing_rows, endpoints, episodes], catalog, group, recipe,
                              profile)


def tread_bearings(parts: list, bearings: list) -> list:
    """Each tread's primary bearing (the deck above's forward strip, as T0's is L0's), then every new natural one."""
    out = []
    for assembly in range(2, 8):
        level = assembly - 2
        deck_part = 7 * (assembly - 1)
        box = [-256, top(level) - 64, far(level), 256, top(level), far(level) + 128]
        out.append([1, assembly - 1, deck_part] + box)
    return out + [[0, -1, -1] + box for box in bearings[8:]]


def cube_episodes(stations: list, station_first: int, first_bearing: int) -> list:
    """Brace, cut and finish each new cube from its station, after T0 is installed (prefix 2), keeping the
    natural bearings under it: rows 4 and 5 hold two treads' posts each, row 6 the sill's bearers, row 7 none."""
    naturals = first_bearing + 6
    ranges = {3: (naturals + 4, 8), 4: (naturals + 12, 8), 5: (naturals + 20, 2), 6: (0, 0)}
    out = []
    for index, (box, _, _, _) in enumerate(cube_cuts()):
        row = -box[2] // 1024 - 1
        station = station_first + index
        first, count = ranges[row]
        out.append(box + [7, 2, station, station, station, 0, 0, first, count, 10, 11, stations[station][0], FACE])
    return out


def tread_installs(station_first: int, first_bearing: int, way_back: int) -> list:
    """T1..T6: station on the tread above, primary bearing, cut group, own natural bearings, M and the way back."""
    naturals = first_bearing + 6
    out = []
    for assembly in range(2, 8):
        k = assembly - 1
        cut = 1 if k == 1 else (2 if k <= 3 else (3 if k <= 5 else 4))
        first, count = (naturals + 4 * (k - 1), 4) if k < SILL else (naturals + 20, 2)
        out.append([assembly, station_first + assembly - 2, first_bearing + assembly - 2, cut, 1, first, count, 10,
                    way_back])
    return out


def serialize_frontier(tables: list, catalog: bytes, group: bytes, recipe: bytes, profile: bytes) -> bytes:
    """UGFRNT01 with content 10 on source 4."""
    counts = [len(t) for t in tables]
    out = b"UGFRNT01" + struct.pack("<I6q2i6I", 1, FRONTIER_REVISION, 1, 1, 1, 1, CONTENT, 0, CLAW_SOURCE, *counts)
    out += sha(catalog) + sha(group) + sha(recipe) + profile[32 + 32 * CLAW_SOURCE:64 + 32 * CLAW_SOURCE]
    for index, rows in enumerate(tables):
        for row in rows:
            if index == 1:
                out += words(row) + struct.pack("<qiqiqiq", 1, -1, 0, -1, 0, -1, 0)
            elif index == 4:
                out += words(row[:7]) + struct.pack("<iq", row[7], 1)
            else:
                out += words(row)
    return out + b"UGFEND01"


def rebound_ground(ground: bytes, profile: bytes) -> bytes:
    """Content 10's ground caps under the source-4 digest they are bound to. The published content-10 file still names
    content 9's claw image (v1) in its header digest; no runtime reads that file (the structure carries the caps), so
    the bundle's copy carries the v2 digest its structure binds, and every row stays byte for byte."""
    require(struct.unpack_from("<3q", ground, 48) == (CONTENT, 1, CLAW_SOURCE), "GROUND_HEADER")
    return ground[:72] + profile[32 + 32 * CLAW_SOURCE:64 + 32 * CLAW_SOURCE] + ground[104:]


def build() -> dict:
    """Every bundle file, the accessor and the manifest, in memory."""
    spec = json.loads(pinned(SPEC, SPEC_SHA))
    old = {name: pinned(OLD / name, digest) for name, digest in OLD_SHA.items()}
    old["recipes.ugrecp"] = (OLD / "recipes.ugrecp").read_bytes()
    profile = pinned(RUNTIME / "mole-worker.ugprof", PROFILE_SHA)
    ground = rebound_ground(pinned(RUNTIME / "ground-pace.ugconn", GROUND_SHA), profile)
    catalog, parts, bearings = structure(spec, old["structure.ugconn"], ground, profile)
    group = grouping(catalog, len(parts))
    bill = recipes(catalog, group, old["recipes.ugrecp"])
    pieces = workpieces(catalog, group, bill, profile)
    front = frontier(old["frontier.ugfront"], catalog, group, bill, profile, parts, bearings)
    files = {"structure.ugconn": catalog, "assemblies.ugasmb": group, "recipes.ugrecp": bill,
             "frontier.ugfront": front, "workpieces.ugwipc": pieces, "ground-pace.ugconn": ground,
             "mole-worker.ugprof": profile}
    linked = K._linked(files)
    files["catalog_source.gd"] = accessor(files, linked, profile)
    files["manifest.json"] = (json.dumps(manifest(files, linked), indent=2) + "\n").encode()
    return files


def accessor(files: dict, linked: dict, profile: bytes) -> bytes:
    """ADR 1190's accessor shape (claw-v6's), for this bundle."""
    lines = ["extends RefCounted", "## Generated by publish_qualified_stairs.py (ADR 1229). Do not edit.", ""]
    names = (("CATALOG", "structure.ugconn"), ("GROUPING", "assemblies.ugasmb"), ("RECIPE", "recipes.ugrecp"),
             ("FRONTIER", "frontier.ugfront"), ("WORKPIECES", "workpieces.ugwipc"), ("GROUND", "ground-pace.ugconn"),
             ("PROFILE", "mole-worker.ugprof"))
    for name, file in names:
        lines.append(f'const {name}_PATH: String = "{RES}{file}"')
        lines.append(f'const {name}_SHA: String = "{sha(files[file]).hex()}"')
        if name not in ("GROUND", "PROFILE"):
            lines.append(f"const {name}_REVISION: int = {linked[name + '_REVISION']}")
    lines.append(f"const CONTENT_REVISION: int = {CONTENT}")
    lines.append(f'const ACTOR_SHA: String = "{profile[32 + 32 * CLAW_SOURCE:64 + 32 * CLAW_SOURCE].hex()}"')
    for table in K.TABLES:
        lines.append(f"const {table}_COUNT: int = {linked[table + '_COUNT']}")
    for name, file in (("CATALOG", "structure.ugconn"), ("GROUND", "ground-pace.ugconn")):
        for index, value in enumerate(struct.unpack("<4q", sha(files[file]))):
            lines.append(f"const {name}_DIGEST_{index}: int = {value}")
    return ("\n".join(lines) + "\n").encode()


def manifest(files: dict, linked: dict) -> dict:
    """What was derived, from what."""
    return {"schema": 1, "decision": ["1229", "1209", "DEC-058", "DEC-059"], "predecessor": "qualified-claw-v6 (ADR 1217 step 4e)",
            "content_revision": CONTENT, "frontier_revision": FRONTIER_REVISION, "frontier_source": CLAW_SOURCE,
            "workpieces_source": PAW_SOURCE, "assemblies": 8, "parts": 52,
            "stair_paces_u_per_s": {str(row): rate for row, rate in STAIR_PACES},
            "entry_source_constants": linked,
            "files": {name: sha(raw).hex() for name, raw in files.items() if name not in ("manifest.json",)},
            "inputs": {str(SPEC.relative_to(ROOT)): SPEC_SHA,
                       **{str((OLD / n).relative_to(ROOT)): d for n, d in OLD_SHA.items()},
                       str((RUNTIME / "mole-worker.ugprof").relative_to(ROOT)): PROFILE_SHA,
                       str((RUNTIME / "ground-pace.ugconn").relative_to(ROOT)): GROUND_SHA},
            "runtime_admitted": False}


def main() -> int:
    """Create the successor bundle exactly once."""
    require(not OUTPUT.exists(), "OUTPUT_EXISTS")
    outputs = build()
    OUTPUT.mkdir()
    for name, raw in outputs.items():
        (OUTPUT / name).write_bytes(raw)
    print("published", OUTPUT.relative_to(ROOT), {n: sha(r).hex()[:12] for n, r in outputs.items()})
    return 0


if __name__ == "__main__":
    sys.exit(main())
