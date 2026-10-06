#!/usr/bin/env python3
"""Create-only ADR 1206 successor of the ADR 1202 first-entry bundle (`qualified-landing-v4`), bound to content 6.

Route composition loads the bundle's `structure.ugconn` as its single pace catalog, and every bundle file binds
the profile content revision. Content 6 (`qualified-stone-v7`, the stone haul rows 37-41) therefore needs a
successor bundle, built exactly as ADR 1200's `publish_qualified_haul.py` built content 5's:

- `mole-worker.ugprof` and `ground-pace.ugconn` are the `qualified-stone-v7` bytes (pinned);
- `structure.ugconn` is the landing-v4 structure with profile content revision 6 and the v7 ground pace table
  (the fourteen v4 rows plus a RATE_GROUND_CAP row for profile 37 CARRY stone);
- `assemblies.ugasmb`, `recipes.ugrecp`, `frontier.ugfront` and `workpieces.ugwipc` change only their profile
  content revision words and their linked catalog/grouping/recipe digests.

Every other byte must equal landing-v4; geometry, bills, stations, landings and episodes are unchanged.

    python3 godot/data/underground/first-entry-prefix-v1/publish_qualified_stone.py
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
OLD = HERE / "qualified-landing-v4"
OUTPUT = HERE / "qualified-stone-v5"
RES = "res://data/underground/first-entry-prefix-v1/qualified-stone-v5/"
RUNTIME = ROOT / "godot/data/underground/mole-worker/qualified-stone-v7"
OLD_SHA = {
    "structure.ugconn": "82dff49dc3da23383b9e22b05ee82b267378dcc801ca42931806946db8392aa3",
    "assemblies.ugasmb": "9cf6d8bbd7748f3756f766592215eb2ac836afd3fbf4b68e5bb3c1677306b7de",
    "recipes.ugrecp": "d18ac338c76a9b3d03d5aa864d1cb36ffbef815fa98b47d44f8e6219eeac27fc",
    "frontier.ugfront": "eda902ec90f2b8cede3badb7a96a91f224fccb4d42af78a2342498dda4e3e019",
    "workpieces.ugwipc": "3999e4c0064c8336a5268171c6f74ed14abd257a04c54f910c7ffdcab2f43421",
    "ground-pace.ugconn": "1ae7ffc421f2a93deac4ccde12a843652da1fd46c91f58c28c559979015422f0",
    "mole-worker.ugprof": "dc4969e4dc562e39b941a7fefa4be4b72851490f59492f0b04b3f26954bc5d8e",
}
NEW_PROFILE_SHA = "30c3dc1f5e9162f5530f410c437ed6f85d28dc6879f88dec81cb193ea87b0df5"
NEW_GROUND_SHA = "7fc1eeb45200292dd90e5659c494159485e56b0b487cbfc5c70d1346b2c6dc13"
OLD_CONTENT, NEW_CONTENT, OLD_PACES = 5, 6, 14
REVISIONS = {"CATALOG": 1, "GROUPING": 1, "RECIPE": 1, "FRONTIER": 4, "WORKPIECES": 1, "GROUND": 0}
SPEC = importlib.util.spec_from_file_location("bundle_haul", HERE / "publish_qualified_haul.py")
HAUL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HAUL)
V1 = HAUL.V1
CONTENT_WORDS, LINKS = HAUL.CONTENT_WORDS, HAUL.LINKS


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed publication fact."""
    if not value:
        raise ValueError("QUALIFIED_STONE_" + code)


def sha(raw: bytes) -> bytes:
    return hashlib.sha256(raw).digest()


def read_old() -> tuple:
    """Each landing-v4 file and the two v7 runtime inputs are pinned by SHA-256."""
    old = {}
    for name, digest in OLD_SHA.items():
        raw = (OLD / name).read_bytes()
        require(sha(raw).hex() == digest, "OLD_" + name)
        old[name] = raw
    profile = (RUNTIME / "mole-worker.ugprof").read_bytes()
    ground = (RUNTIME / "ground-pace.ugconn").read_bytes()
    require(sha(profile).hex() == NEW_PROFILE_SHA and sha(ground).hex() == NEW_GROUND_SHA, "RUNTIME_INPUT")
    return old, profile, ground


def structure(old_catalog: bytes, old_ground: bytes, ground: bytes) -> bytes:
    """Same variant, regions, parts, vertices and material; content 6 and the v7 ground pace table."""
    head = struct.unpack_from("<8sIq7I3q", old_catalog)
    require(head == (b"UGCONN01", 1, 1, 1, 2, 26, 14, 56, 1, OLD_PACES, OLD_CONTENT, 1, 0), "STRUCTURE_HEADER")
    require(old_catalog[-8 - OLD_PACES * 36:-8] == old_ground[136:-8], "STRUCTURE_PACES")
    new_paces = struct.unpack_from("<I", ground, 44)[0]
    require(new_paces == OLD_PACES + 1 and ground[136:136 + OLD_PACES * 36] == old_ground[136:-8] and
            len(ground) == 144 + 36 * new_paces, "GROUND_PREFIX")
    out = bytearray(old_catalog[:-8 - OLD_PACES * 36])
    struct.pack_into("<I", out, 44, new_paces)
    struct.pack_into("<q", out, 48, NEW_CONTENT)
    return bytes(out) + ground[136:-8] + b"UGCEND01"


def relink(name: str, raw: bytes, old: dict, new: dict) -> bytes:
    """Change only the content revision word and the linked digests; refuse any other drift."""
    out = bytearray(raw)
    changed = []
    if name in CONTENT_WORDS:
        at = CONTENT_WORDS[name]
        require(struct.unpack_from("<q", raw, at)[0] == OLD_CONTENT, "CONTENT_WORD_" + name)
        struct.pack_into("<q", out, at, NEW_CONTENT)
        changed.append((at, at + 8))
    for at, target in LINKS.get(name, {}).items():
        require(raw[at:at + 32] == sha(old[target]), "LINK_" + name + "_" + target)
        out[at:at + 32] = sha(new[target])
        changed.append((at, at + 32))
    require(all(a == b or any(lo <= i < hi for lo, hi in changed) for i, (a, b) in enumerate(zip(raw, out))),
            "FOREIGN_DELTA_" + name)
    return bytes(out)


def build() -> dict:
    """All bundle files plus the accessor and manifest, in memory."""
    old, profile, ground = read_old()
    new = {"mole-worker.ugprof": profile, "ground-pace.ugconn": ground,
           "structure.ugconn": structure(old["structure.ugconn"], old["ground-pace.ugconn"], ground)}
    for name in ("assemblies.ugasmb", "recipes.ugrecp", "frontier.ugfront", "workpieces.ugwipc"):
        new[name] = relink(name, old[name], old, new)
    V1.RES = RES
    V1.INPUTS = {role: (Path(path).name, sha(new[Path(path).name]).hex(),
                        NEW_CONTENT if role == "PROFILE" else REVISIONS[role])
                 for role, (path, _, _) in V1.INPUTS.items()}
    roles = {role: new[name] for role, (name, _, _) in V1.INPUTS.items()}
    counts = V1.frontier_census(new["frontier.ugfront"], roles)
    text = V1.accessor(roles, counts).replace("## Generated by publish_qualified_handling.py (ADR 1190). Do not edit.",
                                              "## Generated by publish_qualified_stone.py (ADR 1206). Do not edit.")
    require(f"const CONTENT_REVISION: int = {NEW_CONTENT}" in text and "const FRONTIER_REVISION: int = 4" in text,
            "ACCESSOR_CONTENT")
    manifest = {"schema": 1, "decision": "1206", "predecessor": "qualified-landing-v4 (ADR 1202)",
                "content_revision": NEW_CONTENT, "frontier_revision": 4, "census": counts,
                "added_ground_pace_profiles": [37], "files": {}}
    for role, (name, digest, _) in V1.INPUTS.items():
        manifest["files"][name] = {"role": role, "sha256": digest, "predecessor_sha256": OLD_SHA[name],
                                   "change": "copied from qualified-stone-v7" if role in ("PROFILE", "GROUND")
                                   else ("content 6 + v7 ground pace table" if role == "CATALOG"
                                         else "content revision word and linked digests only")}
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
