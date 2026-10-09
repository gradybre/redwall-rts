#!/usr/bin/env python3
"""Create-only successor of the ADR 1202 bundle (blocker 3): split the L0 landing into a narrow WORK contact and an arrival.

ADR 1193 widened the installed L0 WORK contact (selector 3) to hold its travel profile, all-yaw source 12, whose
body and turn sweep reach 1256 u. The pending T0 bearer lies inside that air, so T0 START refused
LOCATION_ENVELOPE_BLOCKED (ADR 1202 blocker 3). Brendan chose to split the landing:

- selector 3 keeps the WORK contact and now names the narrow approach profile of install row 0's station
  endpoint (H, source 2), so the ADR 1193 union gives the contact H's shape: profiles 2/6/16 (and 29's foot);
- a new arrival behind it, on the same LANDING datum and x line, sized by the old selector 3 travel profile
  (all-yaw 12): selector 12, TRANSIT, travel 12;
- the same arrival on install row 0's retreat profile (R, backward source 6): selector 13, TRANSIT, travel 6;
- install row 1 (T0) retreats to selector 13 instead of standing on its own station.

The arrival's z is derived, never chosen: the nearest point behind the contact whose complete source-12 air
(every BODY/TURN/APPROACH box) stops at the T0 bearer's far face, i.e. bearer high z minus the lowest source-12
air z. The publisher proves its whole source-12 stance lies on the LANDING datum and clear of the contact's
footing. The T0 bearer footprint is install row 1's Frontier bearing target.

Frontier words that change: self revision 3 -> 4, ENDPOINT count 12 -> 14, selector 3's travel profile,
install row 1 field 8 (retreat 3 -> 13), and the two appended ENDPOINT rows. Every other bundle file is copied
byte-identically; the accessor is re-emitted from the accepted bytes. Refuses to overwrite.

    python3 godot/data/underground/first-entry-prefix-v1/publish_qualified_landing.py
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
OLD = HERE / "qualified-install-v3"
OUTPUT = HERE / "qualified-landing-v4"
RES = "res://data/underground/first-entry-prefix-v1/qualified-landing-v4/"
OLD_SHA = {
    "structure.ugconn": "82dff49dc3da23383b9e22b05ee82b267378dcc801ca42931806946db8392aa3",
    "assemblies.ugasmb": "9cf6d8bbd7748f3756f766592215eb2ac836afd3fbf4b68e5bb3c1677306b7de",
    "recipes.ugrecp": "d18ac338c76a9b3d03d5aa864d1cb36ffbef815fa98b47d44f8e6219eeac27fc",
    "frontier.ugfront": "609605ea40d14529cbc8eed4f61bf4ed3dd569c2184e35481c22517de67b9382",
    "workpieces.ugwipc": "3999e4c0064c8336a5268171c6f74ed14abd257a04c54f910c7ffdcab2f43421",
    "ground-pace.ugconn": "1ae7ffc421f2a93deac4ccde12a843652da1fd46c91f58c28c559979015422f0",
    "mole-worker.ugprof": "dc4969e4dc562e39b941a7fefa4be4b72851490f59492f0b04b3f26954bc5d8e",
}
CONTENT = 5
OLD_REVISION, NEW_REVISION = 3, 4
REVISION_AT = 12
COUNTS_AT = 68
HEADER_BYTES = 220
INSTALL_ROW_BYTES = 36  # nine int32 fields
STATION_ROW_BYTES = 80  # nine int32 fields + 44 bytes of per-rotation profile revisions
ENDPOINT_ROW_BYTES = 40  # seven int32 fields + int32 travel profile + int64 travel revision
OLD_ENDPOINTS = 12
CONTACT = 3  # the installed L0 WORK contact
INSTALLED_CONTACT, ROLE_TRANSIT, ROLE_WORK = 1, 0, 2
LANDING = 17
AIR_ROLES = (0, 2, 3)  # BODY_HELD_LOAD, TURN_RECOVERY, WORK_APPROACH: the roles a Location's air holds
STANCE = 1
CATALOG_REGIONS_AT = 280  # header, two digests, the 26-word variant + revision, start and end points
SPEC = importlib.util.spec_from_file_location("bundle_v1", HERE / "publish_qualified_handling.py")
V1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V1)


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed publication fact."""
    if not value:
        raise ValueError("QUALIFIED_LANDING_" + code)


def sha(raw: bytes) -> bytes:
    """Raw SHA256 digest."""
    return hashlib.sha256(raw).digest()


def read_old() -> dict:
    """Each ADR 1202 bundle file is pinned by SHA-256."""
    old = {}
    for name, digest in OLD_SHA.items():
        raw = (OLD / name).read_bytes()
        require(sha(raw).hex() == digest, "OLD_" + name)
        old[name] = raw
    return old


def counts(raw: bytes) -> tuple:
    """The six Frontier table counts in wire order."""
    return struct.unpack_from("<6I", raw, COUNTS_AT)


def install_at(index: int) -> int:
    """Byte offset of one INSTALL row."""
    return HEADER_BYTES + index * INSTALL_ROW_BYTES


def bearing_at(raw: bytes, index: int) -> int:
    """Byte offset of one BEARING row: after the INSTALL, STATION and CUT tables."""
    c = counts(raw)
    return HEADER_BYTES + c[0] * INSTALL_ROW_BYTES + c[1] * STATION_ROW_BYTES + c[2] * 28 + index * 36


def endpoint_at(raw: bytes, index: int) -> int:
    """Byte offset of one ENDPOINT row (index == count is the first EPISODE byte)."""
    return bearing_at(raw, counts(raw)[3]) + index * ENDPOINT_ROW_BYTES


def endpoint(raw: bytes, index: int) -> tuple:
    """Seven selector words, travel profile and travel revision."""
    return struct.unpack_from("<7iiq", raw, endpoint_at(raw, index))


def station_endpoint(raw: bytes, station: int) -> int:
    """Field 0 of one STATION row names its endpoint selector."""
    c = counts(raw)
    return struct.unpack_from("<i", raw, HEADER_BYTES + c[0] * INSTALL_ROW_BYTES + station * STATION_ROW_BYTES)[0]


def profile_boxes(raw: bytes, row: int) -> list:
    """Every published box of one content-5 profile row, with the row's own revision word."""
    _, count, boxes, sources = struct.unpack_from("<qIII", raw, 12)
    require(raw[:8] == b"UGPROF01" and 0 <= row < count, "PROFILE_ROW")
    base = 32 + sources * 32
    fields = struct.unpack_from("<18i3q2B", raw, base + row * 98)
    first, n = fields[14], fields[15]
    require(n > 0 and first + n <= boxes, "PROFILE_BOXES")
    return [struct.unpack_from("<7i", raw, base + count * 98 + 28 * k) for k in range(first, first + n)]


def profile_revision(raw: bytes, row: int) -> int:
    """The profile row's own quantity word, which a Frontier travel revision must equal."""
    _, count, _, sources = struct.unpack_from("<qIII", raw, 12)
    return struct.unpack_from("<18i3q2B", raw, 32 + sources * 32 + row * 98)[18]


def landing(catalog: bytes, ordinal: int) -> list:
    """The authored LANDING floor box that the contact's datum names."""
    envelope = struct.unpack_from("<8i", catalog, CATALOG_REGIONS_AT)
    require(envelope[6] == 16, "CATALOG_REGIONS")
    region = struct.unpack_from("<8i", catalog, CATALOG_REGIONS_AT + 32 * ordinal)
    require(region[6] == LANDING, "LANDING_DATUM")
    return list(region[:6])


def arrival_point(old: dict) -> tuple:
    """Behind the contact on its own line: source-12 air ends exactly at the T0 bearer; the stance stays on the deck."""
    raw = old["frontier.ugfront"]
    contact = endpoint(raw, CONTACT)
    boxes = profile_boxes(old["mole-worker.ugprof"], contact[7])
    t0 = struct.unpack_from("<9i", raw, install_at(1))
    bearer = struct.unpack_from("<9i", raw, bearing_at(raw, t0[2]))[3:]
    air_low = min(b[2] for b in boxes if b[6] in AIR_ROLES)
    z = bearer[5] - air_low
    point = (contact[4], contact[5], z)
    deck = landing(old["structure.ugconn"], contact[2])
    stance = [b for b in boxes if b[6] == STANCE]
    require(len(stance) == 1 and bearer[0] < point[0] < bearer[3] and z > contact[6], "ARRIVAL_LINE")
    foot = [stance[0][a] + point[a % 3] for a in range(6)]
    require(deck[0] <= foot[0] and foot[3] <= deck[3] and deck[2] <= foot[2] and foot[5] <= deck[5]
            and point[1] == deck[1], "ARRIVAL_OFF_DECK")
    contact_foot = max(b[5] for b in profile_boxes(old["mole-worker.ugprof"], endpoint(raw, 0)[7]) if b[6] == STANCE)
    require(foot[2] >= contact[6] + contact_foot, "ARRIVAL_ON_CONTACT_FOOT")
    return point


def check_old(raw: bytes) -> None:
    """Refuse any predecessor that is not exactly the ADR 1202 shape this successor rewrites."""
    require(struct.unpack_from("<q", raw, REVISION_AT)[0] == OLD_REVISION, "OLD_REVISION")
    require(counts(raw)[4] == OLD_ENDPOINTS, "OLD_ENDPOINT_COUNT")
    require(struct.unpack_from("<9i", raw, install_at(1)) == (1, 1, 1, 1, 1, 6, 4, 10, 3), "OLD_T0_INSTALL_ROW")
    require(station_endpoint(raw, 1) == CONTACT, "OLD_T0_STATION")
    require(endpoint(raw, CONTACT) == (INSTALLED_CONTACT, 0, 1, ROLE_WORK, 0, 0, -1536, 12, 1), "OLD_CONTACT")


def new_rows(old: dict) -> tuple:
    """The contact's narrow approach, and the arrival's sizing and retreat selectors, all from published words."""
    raw = old["frontier.ugfront"]
    l0 = struct.unpack_from("<9i", raw, install_at(0))
    approach = endpoint(raw, station_endpoint(raw, l0[1]))[7:]
    retreat = endpoint(raw, l0[8])[7:]
    contact = endpoint(raw, CONTACT)
    point = arrival_point(old)
    for profile, revision in (approach, retreat, contact[7:]):
        require(profile_revision(old["mole-worker.ugprof"], profile) == revision, "TRAVEL_REVISION")
    head = (INSTALLED_CONTACT, contact[1], contact[2], ROLE_TRANSIT, *point)
    rows = struct.pack("<7iiq", *head, *contact[7:]) + struct.pack("<7iiq", *head, *retreat)
    return approach, rows


def frontier(old: dict) -> bytes:
    """Rewrite exactly the split-landing words and append the two arrival selectors; refuse any other drift."""
    raw = old["frontier.ugfront"]
    check_old(raw)
    approach, rows = new_rows(old)
    out = bytearray(raw)
    struct.pack_into("<q", out, REVISION_AT, NEW_REVISION)
    struct.pack_into("<I", out, COUNTS_AT + 16, OLD_ENDPOINTS + 2)
    struct.pack_into("<iq", out, endpoint_at(raw, CONTACT) + 28, *approach)
    struct.pack_into("<i", out, install_at(1) + 32, OLD_ENDPOINTS + 1)
    insert = endpoint_at(raw, OLD_ENDPOINTS)
    result = bytes(out[:insert]) + rows + bytes(out[insert:])
    require(len(result) == len(raw) + 2 * ENDPOINT_ROW_BYTES, "WIRE_SIZE")
    return result


def build() -> dict:
    """All bundle files plus the accessor and manifest, in memory."""
    old = read_old()
    new = dict(old)
    new["frontier.ugfront"] = frontier(old)
    V1.RES = RES
    revisions = {"FRONTIER": NEW_REVISION, "PROFILE": CONTENT}
    V1.INPUTS = {role: (Path(path).name, sha(new[Path(path).name]).hex(), revisions.get(role, rev))
                 for role, (path, _, rev) in V1.INPUTS.items()}
    roles = {role: new[name] for role, (name, _, _) in V1.INPUTS.items()}
    census = V1.frontier_census(new["frontier.ugfront"], roles)
    text = V1.accessor(roles, census).replace("## Generated by publish_qualified_handling.py (ADR 1190). Do not edit.",
                                              "## Generated by publish_qualified_landing.py (ADR 1202, split landing). Do not edit.")
    require(f"const FRONTIER_REVISION: int = {NEW_REVISION}" in text and f"const CONTENT_REVISION: int = {CONTENT}" in text,
            "ACCESSOR_REVISIONS")
    point = arrival_point(old)
    manifest = {"schema": 1, "decision": "1202", "predecessor": "qualified-install-v3 (ADR 1202)",
                "content_revision": CONTENT, "frontier_revision": NEW_REVISION, "census": census,
                "arrival_point_source_local": list(point), "files": {}}
    for role, (name, digest, _) in V1.INPUTS.items():
        manifest["files"][name] = {"role": role, "sha256": digest, "predecessor_sha256": OLD_SHA[name],
                                   "change": "self revision 4; contact travel -> install row 0 approach; arrival "
                                   "selectors 12 (travel 12) and 13 (travel 6); T0 retreat 3 -> 13"
                                   if role == "FRONTIER" else "copied unchanged"}
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
