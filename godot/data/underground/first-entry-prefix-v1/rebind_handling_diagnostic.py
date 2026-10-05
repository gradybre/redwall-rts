#!/usr/bin/env python3
"""Create-only diagnostic rebind to the exact appended handling profile.

No accepted v4 artifact or production publisher changes. The new source is
unqualified for live activation until real owner execution and review pass.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct

HERE = Path(__file__).resolve().parent
loader = importlib.util.spec_from_file_location("frontier", HERE / "compile_entry_frontier.py")
F = importlib.util.module_from_spec(loader)
loader.loader.exec_module(F)
S = F.STRUCTURE
DIAGNOSTIC_SHA = "17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9"
HANDLING_ACTOR_SHA = "b94d676e999c87dd399a4dc110674620a4fbc66f0ca07e494b8bedadac683b66"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require(ok, code):
    if not ok:
        raise ValueError("DIAGNOSTIC_ENTRY_" + code)


def build(profile):
    """Require the exact appended packet and byte-identical predecessor geometry before re-binding hashes."""
    require(sha(profile) == DIAGNOSTIC_SHA and len(profile) == 10912, "PROFILE_SHA")
    require(struct.unpack_from("<8sIqIII", profile) == (b"UGPROF01", 2, 4, 30, 281, 2), "PROFILE_HEADER")
    old = S.read(S.ROOT, S.PROFILE, S.PROFILE_SHA, 131072)
    require(profile[32:64] == old[32:64] and profile[64:96].hex() == HANDLING_ACTOR_SHA, "SOURCE_IDENTITY")
    require(profile[96:96+29*98] == old[64:64+29*98], "OLD_ROWS_CHANGED")
    require(profile[96+30*98:96+30*98+271*28] == old[64+29*98:-8], "OLD_BOXES_CHANGED")
    accepted = F.build()
    for name, raw in accepted.items():
        require((S.ROOT / F.OUTPUT / name).read_bytes() == raw, "ACCEPTED_FRONTIER_DRIFT:" + name)
    original = S.build()
    spec = json.loads(S.read(S.ROOT, S.SPEC, S.SPEC_SHA, 131072))
    cat = bytearray(original["structure.ugconn"])
    struct.pack_into("<q", cat, 48, 4)
    group = S.grouping(cat)
    recipe = S.recipes(spec, cat, group)
    wire = bytearray(accepted["frontier.ugfront"])
    struct.pack_into("<q", wire, 52, 4)
    for offset, raw in ((92, cat), (124, group), (156, recipe)):
        wire[offset:offset+32] = hashlib.sha256(raw).digest()
    require(wire[220:] == accepted["frontier.ugfront"][220:], "FRONTIER_GEOMETRY_CHANGED")
    ground = bytearray(S.read(S.ROOT, S.GROUND, S.GROUND_SHA, 131072))
    struct.pack_into("<q", ground, 48, 4)
    outputs = {"mole-worker.ugprof": profile, "structure.ugconn": bytes(cat),
               "assemblies.ugasmb": group, "recipes.ugrecp": recipe,
               "frontier.ugfront": bytes(wire), "ground-pace.ugconn": bytes(ground)}
    manifest = {"schema": 1, "scope": "Exact diagnostic content4 rebind; source geometry unchanged",
                "production_qualified": False, "world_activation_qualified": False,
                "paid_execution_qualified": False, "profile_content_revision": 4,
                "source_count": 2, "profile_count": 30, "box_count": 281,
                "predecessor_profile": S.PROFILE_SHA, "diagnostic_profile": DIAGNOSTIC_SHA,
                "producer_sha256": sha(Path(__file__).read_bytes()),
                "predecessor_frontier_manifest": sha(accepted["manifest.json"]),
                "predecessor_structural_manifest": sha(original["manifest.json"]),
                "unchanged_profile_rows": [0, 28], "unchanged_profile_boxes": [0, 270],
                "frontier_payload_unchanged": True,
                "inputs": json.loads(accepted["manifest.json"])["inputs"],
                "outputs": {name: {"bytes": len(raw), "sha256": sha(raw)} for name, raw in outputs.items()}}
    outputs["manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    return outputs


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--profile", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    require(args.profile.is_file() and not args.profile.is_symlink() and args.profile.stat().st_size == 10912, "PROFILE_PATH")
    require(not args.out.exists() and args.out.resolve().is_relative_to(S.ROOT / "docs/validation/evidence"), "OUTPUT_PATH")
    outputs = build(args.profile.read_bytes())
    args.out.mkdir(parents=True)
    for name, raw in outputs.items():
        (args.out / name).write_bytes(raw)
    print(json.dumps({name: sha(raw) for name, raw in outputs.items()}, indent=2))


if __name__ == "__main__":
    main()
