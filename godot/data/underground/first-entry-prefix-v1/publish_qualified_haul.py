#!/usr/bin/env python3
"""Create-only ADR 1200 successor of the ADR 1190 first-entry source bundle, bound to profile content 5.

Route composition loads the bundle's `structure.ugconn` as its single pace catalog, and every bundle
file binds the profile content revision. Content 5 therefore needs a successor bundle:

- `mole-worker.ugprof` and `ground-pace.ugconn` are the `qualified-haul-v6` bytes (pinned);
- `structure.ugconn` is the v1 structure with profile content revision 5 and the v6 ground pace
  table (the twelve v1 rows plus RATE_GROUND_CAP rows for profiles 31 WALK and 32 CARRY);
- `assemblies.ugasmb`, `recipes.ugrecp`, `frontier.ugfront` and `workpieces.ugwipc` change only
  their profile content revision words and their linked catalog/grouping/recipe digests.

Every other byte must equal the v1 bundle; the geometry, bills, stations and episodes are unchanged.
Refuses to overwrite.

    python3 godot/data/underground/first-entry-prefix-v1/publish_qualified_haul.py
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
OLD = HERE / "qualified-handling-v1"
OUTPUT = HERE / "qualified-haul-v2"
RES = "res://data/underground/first-entry-prefix-v1/qualified-haul-v2/"
RUNTIME = ROOT / "godot/data/underground/mole-worker/qualified-haul-v6"
OLD_SHA = {
    "structure.ugconn": "eda41ce78d4a798e2160250e2d6760ec7507f0c651c1e7b9b8ad462ff65ab520",
    "assemblies.ugasmb": "3bb788bf250f4628cc4ab6a0c1a5748478d7909753cb5d1a8056d5eb7a8f4a54",
    "recipes.ugrecp": "3019f92d56713317550c417e732b057d238fe0b70adadca8b56289a1362391a8",
    "frontier.ugfront": "1068db6b1217e6542f6489cd56add7af52db663c756e572c86c1128e8227a058",
    "workpieces.ugwipc": "e68a7d9340675c495d875d97f5c51b063ba2a20b17041dc881b25a3e8b0f79ee",
    "ground-pace.ugconn": "877be0982eb6945c4c4f014e9de428b3ab278d1fddc630080e9c6bfe341a1ea8",
    "mole-worker.ugprof": "17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9",
}
NEW_PROFILE_SHA = "dc4969e4dc562e39b941a7fefa4be4b72851490f59492f0b04b3f26954bc5d8e"
NEW_GROUND_SHA = "1ae7ffc421f2a93deac4ccde12a843652da1fd46c91f58c28c559979015422f0"
OLD_CONTENT, NEW_CONTENT = 4, 5
# (file, byte offset of its int64 profile content revision); the catalogs use 48, Frontier/Workpieces 52.
CONTENT_WORDS = {"structure.ugconn": 48, "frontier.ugfront": 52, "workpieces.ugwipc": 52}
# Linked digests: Frontier 92/124/156, Workpieces 84/116/148 (catalog, grouping, recipe); see their loaders.
LINKS = {"assemblies.ugasmb": {56: "structure.ugconn"},
         "recipes.ugrecp": {52: "structure.ugconn", 84: "assemblies.ugasmb"},
         "frontier.ugfront": {92: "structure.ugconn", 124: "assemblies.ugasmb", 156: "recipes.ugrecp"},
         "workpieces.ugwipc": {84: "structure.ugconn", 116: "assemblies.ugasmb", 148: "recipes.ugrecp"}}
SPEC = importlib.util.spec_from_file_location("bundle_v1", HERE / "publish_qualified_handling.py")
V1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V1)


def require(value: bool, code: str) -> None:
    """Every refusal names its exact failed publication fact."""
    if not value:
        raise ValueError("QUALIFIED_HAUL_" + code)


def sha(raw: bytes) -> bytes:
    """Raw SHA256 digest."""
    return hashlib.sha256(raw).digest()


def read_old() -> dict:
    """Each v1 bundle file and the two v6 runtime inputs are pinned by SHA-256."""
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
    """Same variant, regions, parts, vertices and material; content 5 and the v6 ground pace table."""
    head = struct.unpack_from("<8sIq7I3q", old_catalog)
    require(head == (b"UGCONN01", 1, 1, 1, 2, 26, 14, 56, 1, 12, OLD_CONTENT, 1, 0), "STRUCTURE_HEADER")
    require(old_catalog[-8 - 12 * 36:-8] == old_ground[136:-8], "STRUCTURE_PACES")
    new_paces = struct.unpack_from("<I", ground, 44)[0]
    require(ground[136:136 + 12 * 36] == old_ground[136:-8] and len(ground) == 144 + 36 * new_paces, "GROUND_PREFIX")
    out = bytearray(old_catalog[:-8 - 12 * 36])
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
    V1.INPUTS = {role: (Path(path).name, sha(new[Path(path).name]).hex(), NEW_CONTENT if role == "PROFILE" else rev)
                 for role, (path, _, rev) in V1.INPUTS.items()}
    roles = {role: new[name] for role, (name, _, _) in V1.INPUTS.items()}
    counts = V1.frontier_census(new["frontier.ugfront"], roles)
    text = V1.accessor(roles, counts).replace("## Generated by publish_qualified_handling.py (ADR 1190). Do not edit.",
                                              "## Generated by publish_qualified_haul.py (ADR 1200). Do not edit.")
    require(f"const CONTENT_REVISION: int = {NEW_CONTENT}" in text, "ACCESSOR_CONTENT")
    manifest = {"schema": 1, "decision": "1200", "predecessor": "qualified-handling-v1 (ADR 1190)",
                "content_revision": NEW_CONTENT, "census": counts,
                "added_ground_pace_profiles": [31, 32], "files": {}}
    for role, (name, digest, _) in V1.INPUTS.items():
        manifest["files"][name] = {"role": role, "sha256": digest, "predecessor_sha256": OLD_SHA[name],
                                   "change": "copied from qualified-haul-v6" if role in ("PROFILE", "GROUND")
                                   else ("content 5 + v6 ground pace table" if role == "CATALOG"
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
