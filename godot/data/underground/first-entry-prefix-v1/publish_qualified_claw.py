#!/usr/bin/env python3
"""Create-only claw successor of the first-entry bundle (`qualified-stone-v5`), bound to content 9 (ADR 1217 step 4e).

DEC-052 (claws and paws, no tools) with Brendan's step-1 station choice and his step-4d review:

- `mole-worker.ugprof` and `ground-pace.ugconn` are content 9's bytes (`qualified-claw-approach-v10`, pinned).
- `structure.ugconn` is the stone-v5 structure bound to content 9 and to **source 4** (the claw image): header words
  content 9, source 4, the source digest, and content 9's 24 ground caps. Variants, regions, parts, vertices and the
  material are unchanged.
- `frontier.ugfront` (revision 4 -> 5) binds source 4:
  - the six cut stations (rows 2-7) and their endpoints 4-9 move from x = +-1,536 to +-1,430 (Brendan, step 1);
  - stations name the claw rows: INSTALL tap 52 (yaw 0) for L0/T0, dig 57 (yaw 49152) left, dig 53 (16384) right;
  - endpoint travel, like for like (step 4d): row 2 -> narrow approach 43 (endpoints 0, 1, 3), row 6 -> narrow
    retreat 47 (2, 13), row 12 -> canonical ground 42 (4-12).
- `workpieces.ugwipc` binds source 5 (paw handling): program source 5, both set-down rows 59.
- `assemblies.ugasmb` and `recipes.ugrecp` change only their linked digests.

Every other byte equals stone-v5. The publisher checks each endpoint's new travel boxes against the geometry the
mapping relies on (see `endpoint_checks`), and runs the ADR 1190 formatter (`entry_source_constants`) on the packet.

    python3 godot/data/underground/first-entry-prefix-v1/publish_qualified_claw.py
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
OLD = HERE / "qualified-stone-v5"
OUTPUT = HERE / "qualified-claw-v6"
RES = "res://data/underground/first-entry-prefix-v1/qualified-claw-v6/"
RUNTIME = ROOT / "godot/data/underground/mole-worker/qualified-claw-approach-v10"
OLD_SHA = {
    "structure.ugconn": "7ea0d26c6420075536ab3e542273b13dd2b45a7f1f0cc8cdd11e620af77907d6",
    "assemblies.ugasmb": "c185a5c4ff0e256f7af134d26cd25d077951276853ab5fcb02f08c0b3c202904",
    "recipes.ugrecp": "2009f54ca7059b4cbc52486bc2fe2962eeda6cca1b69729bb994cafe04ccb5ef",
    "frontier.ugfront": "2d5c36163ed5e5f8e96a3f1b0611d85937c075abcb8b02c7d7f01f7cf0738660",
    "workpieces.ugwipc": "ba98db4330ead65cdda4a5bc2d66ce72271621699ca960b272911a53140d246e",
    "ground-pace.ugconn": "7fc1eeb45200292dd90e5659c494159485e56b0b487cbfc5c70d1346b2c6dc13",
    "mole-worker.ugprof": "30c3dc1f5e9162f5530f410c437ed6f85d28dc6879f88dec81cb193ea87b0df5",
}
NEW_PROFILE_SHA = "c8e34f12865e05b735772bd9db1a836c65720db2d3a03e84e617a7c8c2589e3b"
NEW_GROUND_SHA = "7bcaec942694"  # prefix; the full digest is read from the pinned publication manifest
OLD_CONTENT, NEW_CONTENT, OLD_PACES, NEW_PACES = 6, 9, 15, 24
OLD_FRONTIER, NEW_FRONTIER = 4, 5
CLAW_SOURCE, PAW_SOURCE = 4, 5
STATION_BYTES, ENDPOINT_BYTES, INSTALL_BYTES = 80, 40, 36
CUT_X = 1536
CLAW_X = 1430  # Brendan, ADR 1217 step 1: moved in by 106 u
STATION_PROFILE = {16: 52, 17: 53, 25: 57}  # pick -> claw at the same exact heading
TRAVEL = {2: 43, 6: 47, 12: 42}  # step 4d: like for like
SET_DOWN = {29: 59}
REVISIONS = {"CATALOG": 1, "GROUPING": 1, "RECIPE": 1, "FRONTIER": NEW_FRONTIER, "WORKPIECES": 1, "GROUND": 0}
SPEC = importlib.util.spec_from_file_location("bundle_haul", HERE / "publish_qualified_haul.py")
HAUL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HAUL)
V1 = HAUL.V1
CONSTANTS_SPEC = importlib.util.spec_from_file_location("entry_constants", HERE / "entry_source_constants.py")
K = importlib.util.module_from_spec(CONSTANTS_SPEC)
CONSTANTS_SPEC.loader.exec_module(K)
LINKS = HAUL.LINKS


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed publication fact."""
    if not value:
        raise ValueError("QUALIFIED_CLAW_" + code)


def sha(raw: bytes) -> bytes:
    """Raw SHA-256."""
    return hashlib.sha256(raw).digest()


def read_inputs() -> tuple:
    """Each stone-v5 file and content 9's wire and ground caps, pinned."""
    old = {}
    for name, digest in OLD_SHA.items():
        raw = (OLD / name).read_bytes()
        require(sha(raw).hex() == digest, "OLD_" + name)
        old[name] = raw
    profile = (RUNTIME / "mole-worker.ugprof").read_bytes()
    ground = (RUNTIME / "ground-pace.ugconn").read_bytes()
    manifest = json.loads((RUNTIME / "manifest.json").read_text())
    require(sha(profile).hex() == NEW_PROFILE_SHA and sha(ground).hex() == manifest["ground_sha256"]
            and manifest["ground_sha256"].startswith(NEW_GROUND_SHA), "RUNTIME_INPUT")
    return old, profile, ground


def source_digest(profile: bytes, source: int) -> bytes:
    """One source digest of a UGPROF01 wire."""
    return profile[32 + 32 * source:64 + 32 * source]


def structure(old_catalog: bytes, ground: bytes, profile: bytes) -> bytes:
    """Content 9, source 4 and its digest, and content 9's ground caps; geometry unchanged."""
    head = struct.unpack_from("<8sIq7I3q", old_catalog)
    require(head == (b"UGCONN01", 1, 1, 1, 2, 26, 14, 56, 1, OLD_PACES, OLD_CONTENT, 1, 0), "STRUCTURE_HEADER")
    require(struct.unpack_from("<I", ground, 44)[0] == NEW_PACES and len(ground) == 144 + 36 * NEW_PACES and
            ground[104:136] == old_catalog[104:136], "GROUND_SHAPE")
    out = bytearray(old_catalog[:-8 - OLD_PACES * 36])
    struct.pack_into("<I", out, 44, NEW_PACES)
    struct.pack_into("<q", out, 48, NEW_CONTENT)
    struct.pack_into("<q", out, 64, CLAW_SOURCE)
    out[72:104] = source_digest(profile, CLAW_SOURCE)
    result = bytes(out) + ground[136:-8] + b"UGCEND01"
    require(result[48:136] == ground[48:136], "STRUCTURE_GROUND_HEADER")
    return result


def relink(name: str, raw: bytes, old: dict, new: dict, edits: dict) -> bytearray:
    """Replace the linked digests; `edits` (offset -> bytes) are the only other changes allowed."""
    out = bytearray(raw)
    changed = []
    for at, target in LINKS.get(name, {}).items():
        require(raw[at:at + 32] == sha(old[target]), "LINK_" + name + "_" + target)
        out[at:at + 32] = sha(new[target])
        changed.append((at, at + 32))
    for at, value in edits.items():
        out[at:at + len(value)] = value
        changed.append((at, at + len(value)))
    require(all(a == b or any(lo <= i < hi for lo, hi in changed) for i, (a, b) in enumerate(zip(raw, out))),
            "FOREIGN_DELTA_" + name)
    return out


def counts(raw: bytes) -> tuple:
    """The six Frontier table counts."""
    return struct.unpack_from("<6I", raw, 68)


def station_at(raw: bytes, index: int) -> int:
    """Byte offset of one STATION row."""
    return 220 + counts(raw)[0] * INSTALL_BYTES + index * STATION_BYTES


def endpoint_at(raw: bytes, index: int) -> int:
    """Byte offset of one ENDPOINT row."""
    c = counts(raw)
    return 220 + c[0] * INSTALL_BYTES + c[1] * STATION_BYTES + c[2] * 28 + c[3] * 36 + index * ENDPOINT_BYTES


def station_edits(raw: bytes) -> dict:
    """Claw profiles at every station; the cut stations move in to x = +-1,430."""
    edits = {}
    for index in range(counts(raw)[1]):
        at = station_at(raw, index)
        words = struct.unpack_from("<9iq", raw, at)
        require(words[5] in STATION_PROFILE and words[9] == 1, "STATION_PROFILE")
        if abs(words[1]) == CUT_X:
            edits[at + 4] = struct.pack("<i", CLAW_X if words[1] > 0 else -CLAW_X)
        edits[at + 20] = struct.pack("<i", STATION_PROFILE[words[5]])
    return edits


def endpoint_edits(raw: bytes) -> dict:
    """Mapped travel at every endpoint; endpoints at the cut stations move with them."""
    edits = {}
    for index in range(counts(raw)[4]):
        at = endpoint_at(raw, index)
        words = struct.unpack_from("<7iiq", raw, at)
        require(words[7] in TRAVEL and words[8] == 1, "ENDPOINT_TRAVEL")
        if abs(words[4]) == CUT_X:
            edits[at + 16] = struct.pack("<i", CLAW_X if words[4] > 0 else -CLAW_X)
        edits[at + 28] = struct.pack("<i", TRAVEL[words[7]])
    return edits


def frontier(old: dict, new: dict, profile: bytes) -> bytes:
    """Revision 5, content 9, source 4, relinked digests, claw stations at +-1,430 and mapped travel."""
    raw = old["frontier.ugfront"]
    require(struct.unpack_from("<q", raw, 12)[0] == OLD_FRONTIER and struct.unpack_from("<q", raw, 52)[0] == OLD_CONTENT
            and struct.unpack_from("<i", raw, 64)[0] == 0 and counts(raw) == (2, 8, 2, 10, 14, 6), "OLD_FRONTIER")
    edits = {12: struct.pack("<q", NEW_FRONTIER), 52: struct.pack("<q", NEW_CONTENT),
             64: struct.pack("<i", CLAW_SOURCE), 188: source_digest(profile, CLAW_SOURCE)}
    edits.update(station_edits(raw))
    edits.update(endpoint_edits(raw))
    return bytes(relink("frontier.ugfront", raw, old, new, edits))


def workpieces(old: dict, new: dict, profile: bytes) -> bytes:
    """Content 9, set-down program source 5 (paw handling), row 59 for both assemblies."""
    raw = old["workpieces.ugwipc"]
    head = struct.unpack_from("<9q", raw, 12)
    require(head[5] == OLD_CONTENT and head[8] == 1 and head[6] == 2, "OLD_WORKPIECES")
    edits = {52: struct.pack("<q", NEW_CONTENT), 76: struct.pack("<q", PAW_SOURCE), 180: source_digest(profile, PAW_SOURCE)}
    for row in range(head[6]):
        at = 212 + 32 * row  # a 212-byte header; rows of six int32 fields and an int64 revision
        words = struct.unpack_from("<6iq", raw, at)
        require(words[5] in SET_DOWN and words[6] == 1, "SET_DOWN_ROW")
        edits[at + 20] = struct.pack("<i", SET_DOWN[words[5]])
    return bytes(relink("workpieces.ugwipc", raw, old, new, edits))


def profile_rows(profile: bytes) -> tuple:
    """(fields, boxes) of every row of a UGPROF01 wire."""
    _, count, boxes, sources = struct.unpack_from("<qIII", profile, 12)
    base = 32 + 32 * sources
    fields = [struct.unpack_from("<18i3q2B", profile, base + 98 * r) for r in range(count)]
    rows = [[struct.unpack_from("<7i", profile, base + 98 * count + 28 * k) for k in range(f[14], f[14] + f[15])]
            for f in fields]
    return fields, rows


def box_of(rows: list, row: int, role: int, above: bool = True) -> list:
    """Union of one row's boxes of a role (above the floor, or all)."""
    boxes = [b for b in rows[row] if b[6] == role and (not above or b[1] >= 0)]
    return [min(b[a] for b in boxes) for a in range(3)] + [max(b[a + 3] for b in boxes) for a in range(3)]


def contains(outer: list, inner: list) -> bool:
    """Closed box containment."""
    return all(outer[a] <= inner[a] and inner[a + 3] <= outer[a + 3] for a in range(3))


def endpoint_checks(new_frontier: bytes, profile: bytes) -> dict:
    """The facts the like-for-like mapping relies on (step 4d), from the published words."""
    fields, rows = profile_rows(profile)
    for row, yaw in ((52, 0), (53, 16384), (57, 49152), (43, 0), (47, 0)):
        require(fields[row][11] == yaw and fields[row][0] == CLAW_SOURCE, "CLAW_ROW_HEADING")
    narrow = [box_of(rows, 43, role, False) for role in (0, 1, 2)]
    wide = [box_of(rows, 42, role, False) for role in (0, 1, 2)]
    require(all(contains(w, n) for w, n in zip(wide, narrow)), "NARROW_INSIDE_ROW_42")
    points = {i: struct.unpack_from("<7iiq", new_frontier, endpoint_at(new_frontier, i)) for i in range(14)}
    require(points[1][4:7] == points[10][4:7] and points[2][4:7] == points[11][4:7] and
            points[13][4:7] == points[12][4:7] and points[10][7] == points[11][7] == points[12][7] == 42, "ALIASES")
    t0_far = -1920  # the T0 bearer's far face z, Frontier bearing 1 and the certificate prism
    arrival_clear = points[13][6] + narrow[0][2] > t0_far
    stance = box_of(rows, 42, 1, False)
    edge = all(abs(points[i][4]) - abs(stance[0]) == 1024 for i in range(4, 10))
    require(arrival_clear and edge, "ENDPOINT_GEOMETRY")
    return {"narrow_inside_row_42": True, "aliases": {"1 (M)": 10, "2 (R)": 11, "13 (T0 arrival)": 12},
            "arrival_body_low_z": points[13][6] + narrow[0][2], "t0_bearer_far_z": t0_far,
            "cut_station_stance_edge_x": 1024}


def build() -> dict:
    """All bundle files, the accessor and the manifest, in memory."""
    old, profile, ground = read_inputs()
    new = {"mole-worker.ugprof": profile, "ground-pace.ugconn": ground,
           "structure.ugconn": structure(old["structure.ugconn"], ground, profile)}
    for name in ("assemblies.ugasmb", "recipes.ugrecp"):
        new[name] = bytes(relink(name, old[name], old, new, {}))
    new["frontier.ugfront"] = frontier(old, new, profile)
    new["workpieces.ugwipc"] = workpieces(old, new, profile)
    checks = endpoint_checks(new["frontier.ugfront"], profile)
    linked = K._linked({name: new[name] for name in K.FILES.values() if name in new} | {"mole-worker.ugprof": profile})
    V1.RES, V1.ACTOR_SHA = RES, source_digest(profile, CLAW_SOURCE).hex()
    V1.INPUTS = {role: (Path(path).name, sha(new[Path(path).name]).hex(),
                        NEW_CONTENT if role == "PROFILE" else REVISIONS[role])
                 for role, (path, _, _) in V1.INPUTS.items()}
    roles = {role: new[name] for role, (name, _, _) in V1.INPUTS.items()}
    census = V1.frontier_census(new["frontier.ugfront"], roles)
    text = V1.accessor(roles, census).replace("## Generated by publish_qualified_handling.py (ADR 1190). Do not edit.",
                                              "## Generated by publish_qualified_claw.py (ADR 1217 step 4e). Do not edit.")
    require(f"const CONTENT_REVISION: int = {NEW_CONTENT}" in text and
            f"const FRONTIER_REVISION: int = {NEW_FRONTIER}" in text, "ACCESSOR")
    manifest = {"schema": 1, "decision": "1217", "predecessor": "qualified-stone-v5 (ADR 1206)",
                "content_revision": NEW_CONTENT, "frontier_revision": NEW_FRONTIER, "frontier_source": CLAW_SOURCE,
                "workpieces_source": PAW_SOURCE, "census": census, "cut_station_x": CLAW_X,
                "station_profiles": {str(k): v for k, v in STATION_PROFILE.items()},
                "endpoint_travel": {str(k): v for k, v in TRAVEL.items()}, "set_down": {str(k): v for k, v in SET_DOWN.items()},
                "endpoint_checks": checks, "entry_source_constants": linked, "files": {}}
    for role, (name, digest, _) in V1.INPUTS.items():
        manifest["files"][name] = {"role": role, "sha256": digest, "predecessor_sha256": OLD_SHA[name]}
    new["catalog_source.gd"] = text.encode()
    new["manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    return new


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
