#!/usr/bin/env python3
"""Create-only ADR 1202 successor of the ADR 1200 first-entry bundle: the T0 install names M's all-yaw selector.

Frontier install row 1 (T0) named material selector 1: M at (-832, 0, 2048) on fixed-heading source 2,
which only walks -Z. The T0 station is the installed L0 contact at x = 0, so no source-2 route can
reach it from M and `open_order` refuses ROUTE_NOT_CONNECTED. Selector 10 is the same M (kind, role,
point) on all-yaw source 12, and every episode already names it as its material endpoint (field 15).

The successor `qualified-install-v3/` changes exactly two Frontier words:

- the Frontier self revision (offset 12): 2 -> 3, because the authored install table changed;
- install row 1, field 7 (material selector): 1 -> 10.

No other Frontier byte changes. Install row 0 (L0) keeps selector 1: its approach to H runs straight
-Z on source 2, which is that selector's purpose. Every other bundle file is copied byte-identically
(nothing links the Frontier's digest), and the accessor is re-emitted from the accepted bytes.
Refuses to overwrite.

    python3 godot/data/underground/first-entry-prefix-v1/publish_qualified_install.py
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
OLD = HERE / "qualified-haul-v2"
OUTPUT = HERE / "qualified-install-v3"
RES = "res://data/underground/first-entry-prefix-v1/qualified-install-v3/"
OLD_SHA = {
    "structure.ugconn": "82dff49dc3da23383b9e22b05ee82b267378dcc801ca42931806946db8392aa3",
    "assemblies.ugasmb": "9cf6d8bbd7748f3756f766592215eb2ac836afd3fbf4b68e5bb3c1677306b7de",
    "recipes.ugrecp": "d18ac338c76a9b3d03d5aa864d1cb36ffbef815fa98b47d44f8e6219eeac27fc",
    "frontier.ugfront": "8ccac2cf0617146924619eb26b834c2bb890c3a02181ad31005d15b075c2cdc8",
    "workpieces.ugwipc": "3999e4c0064c8336a5268171c6f74ed14abd257a04c54f910c7ffdcab2f43421",
    "ground-pace.ugconn": "1ae7ffc421f2a93deac4ccde12a843652da1fd46c91f58c28c559979015422f0",
    "mole-worker.ugprof": "dc4969e4dc562e39b941a7fefa4be4b72851490f59492f0b04b3f26954bc5d8e",
}
CONTENT = 5
OLD_REVISION, NEW_REVISION = 2, 3
REVISION_AT = 12
HEADER_BYTES = 220
INSTALL_ROW_BYTES = 36  # nine int32 fields
ENDPOINT_ROW_BYTES = 40  # seven int32 fields + int32 travel profile + int64 travel revision
STATION_ROW_BYTES = 80  # nine int32 fields + 44 bytes of per-rotation profile revisions
T0_MATERIAL_AT = HEADER_BYTES + INSTALL_ROW_BYTES + 7 * 4
OLD_SELECTOR, NEW_SELECTOR = 1, 10
SPEC = importlib.util.spec_from_file_location("bundle_v1", HERE / "publish_qualified_handling.py")
V1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V1)


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed publication fact."""
    if not value:
        raise ValueError("QUALIFIED_INSTALL_" + code)


def sha(raw: bytes) -> bytes:
    """Raw SHA256 digest."""
    return hashlib.sha256(raw).digest()


def read_old() -> dict:
    """Each ADR 1200 bundle file is pinned by SHA-256."""
    old = {}
    for name, digest in OLD_SHA.items():
        raw = (OLD / name).read_bytes()
        require(sha(raw).hex() == digest, "OLD_" + name)
        old[name] = raw
    return old


def endpoint_at(raw: bytes, index: int) -> int:
    """Byte offset of one ENDPOINT row: header, then the INSTALL/STATION/CUT/BEARING tables in wire order."""
    counts = struct.unpack_from("<6I", raw, 68)
    start = HEADER_BYTES + counts[0] * INSTALL_ROW_BYTES + counts[1] * STATION_ROW_BYTES
    start += counts[2] * 28 + counts[3] * 36
    return start + index * ENDPOINT_ROW_BYTES


def selectors_agree(raw: bytes) -> None:
    """Selector 10 is selector 1's M (kind, assembly, datum, role, point) on all-yaw source 12."""
    old, new = endpoint_at(raw, OLD_SELECTOR), endpoint_at(raw, NEW_SELECTOR)
    require(raw[old:old + 28] == raw[new:new + 28], "SELECTOR_IDENTITY")
    require(struct.unpack_from("<iq", raw, old + 28) == (2, 1), "OLD_SELECTOR_PROFILE")
    require(struct.unpack_from("<iq", raw, new + 28) == (12, 1), "NEW_SELECTOR_PROFILE")


def frontier(raw: bytes) -> bytes:
    """Change only the self revision and the T0 install material selector; refuse any other drift."""
    require(struct.unpack_from("<q", raw, REVISION_AT)[0] == OLD_REVISION, "OLD_REVISION")
    require(struct.unpack_from("<9i", raw, HEADER_BYTES + INSTALL_ROW_BYTES) == (1, 1, 1, 1, 1, 6, 4, 1, 3),
            "OLD_T0_INSTALL_ROW")
    selectors_agree(raw)
    out = bytearray(raw)
    struct.pack_into("<q", out, REVISION_AT, NEW_REVISION)
    struct.pack_into("<i", out, T0_MATERIAL_AT, NEW_SELECTOR)
    spans = ((REVISION_AT, REVISION_AT + 8), (T0_MATERIAL_AT, T0_MATERIAL_AT + 4))
    require(all(a == b or any(lo <= i < hi for lo, hi in spans) for i, (a, b) in enumerate(zip(raw, out))),
            "FOREIGN_DELTA")
    return bytes(out)


def build() -> dict:
    """All bundle files plus the accessor and manifest, in memory."""
    old = read_old()
    new = dict(old)
    new["frontier.ugfront"] = frontier(old["frontier.ugfront"])
    V1.RES = RES
    revisions = {"FRONTIER": NEW_REVISION, "PROFILE": CONTENT}
    V1.INPUTS = {role: (Path(path).name, sha(new[Path(path).name]).hex(), revisions.get(role, rev))
                 for role, (path, _, rev) in V1.INPUTS.items()}
    roles = {role: new[name] for role, (name, _, _) in V1.INPUTS.items()}
    counts = V1.frontier_census(new["frontier.ugfront"], roles)
    text = V1.accessor(roles, counts).replace("## Generated by publish_qualified_handling.py (ADR 1190). Do not edit.",
                                              "## Generated by publish_qualified_install.py (ADR 1202). Do not edit.")
    require(f"const FRONTIER_REVISION: int = {NEW_REVISION}" in text and f"const CONTENT_REVISION: int = {CONTENT}" in text,
            "ACCESSOR_REVISIONS")
    manifest = {"schema": 1, "decision": "1202", "predecessor": "qualified-haul-v2 (ADR 1200)",
                "content_revision": CONTENT, "frontier_revision": NEW_REVISION, "census": counts, "files": {}}
    for role, (name, digest, _) in V1.INPUTS.items():
        manifest["files"][name] = {"role": role, "sha256": digest, "predecessor_sha256": OLD_SHA[name],
                                   "change": "self revision 3; T0 install material selector 1 -> 10"
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
