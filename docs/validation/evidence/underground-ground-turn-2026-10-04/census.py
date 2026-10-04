#!/usr/bin/env python3
"""Recount the reviewed turn helper paths from declared source numeric values.

This is logical payload accounting, not Godot stack/native allocation measurement.
Borrowed references and StringNames are reported separately and excluded from the
existing numeric-helper convention. No authoritative or reusable field is added.
"""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
WIDTH = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
PREFIX = ["underground_world_routes:turn_actor", "underground_world_routes:_turn_run"]
FINAL = PREFIX + ["underground_world_routes:_turn_final"]
OBSERVE = PREFIX + ["underground_world_routes:_turn_observe", "underground_routes:_current_profile_into",
                    "underground_routes:_actor_profile_into", "underground_profiles:query_into",
                    "underground_profiles:_prepare_query", "underground_profiles:_read_dynamic"]
OCCUPANT = FINAL + ["underground_world_routes:_turn_occupants"]
SELECTION = OCCUPANT + ["underground_routes:turn_selection_into", "underground_routes:_turn_dynamic_leaf"]
PATHS = {
    "observed_tool": OBSERVE + ["underground_profiles:_read_tool", "gear:owner_of",
                                "gear:_resolve_row", "gear:_resolve_row_by_lot_slot"],
    "observed_cargo": OBSERVE + ["underground_profiles:_read_cargo", "haul_carry:carried_lot",
                                 "haul_carry:satchel_of", "haul_carry:_owns_live_satchel",
                                 "inventory:is_satchel", "inventory:is_container_valid"],
    "actual_foundation": FINAL + ["underground_world_routes:_turn_body_leaf",
                                  "underground_terrain:_local_tiles_refusal", "underground_terrain:_local_tile",
                                  "underground_terrain:_local_building", "underground_terrain:_building_extent",
                                  "buildings:spatial_identity_into", "buildings:_building_row_of",
                                  "entity_directory:get_typed_row", "entity_directory:is_valid",
                                  "entity_directory:is_valid_of_kind"],
    "retained_resident_transit": FINAL + ["underground_final_facts:snapshot_refusal",
                                          "underground_final_facts:_sources_refusal",
                                          "underground_final_facts:_resident_into",
                                          "underground_final_facts:_resident_location_refusal",
                                          "underground_final_facts:_transit_refusal",
                                          "underground_routes:_interpolate"],
    "current_occupant_identity": SELECTION + ["underground_routes:_turn_identity_leaf",
                                              "underground_routes:_turn_pose_leaf"],
    "current_occupant_tool": SELECTION + ["underground_routes:_turn_tool_leaf",
                                          "gear:_resolve_row", "gear:_resolve_row_by_lot_slot"],
    "current_occupant_cargo": SELECTION + ["underground_routes:_turn_cargo_leaf"],
    "missing_occupant_registration": OCCUPANT + ["underground_world_routes:_turn_unregistered_refusal",
                                                 "underground_routes:_turn_directory_row"],
    "occupant_volume_pair": OCCUPANT + ["underground_world_routes:_turn_occupant_boxes",
                                        "underground_world_routes:_sweep_into"],
    "support_stance": FINAL + ["underground_world_routes:_turn_body_leaf",
                                "underground_world_routes:_turn_body_contained",
                                "underground_world_routes:_sweep_into"],
    "stationary_commit": PREFIX + ["underground_routes:commit_stationary_turn",
                                    "transforms:turn_stationary_preflighted", "transforms:_stationary_row"],
}


def frame(key):
    file, name = key.split(":")
    path = ROOT / "godot/scripts/core" / (file + ".gd")
    source = path.read_text()
    start = re.search(r"^(?:static )?func " + re.escape(name) + r"\(", source, re.M)
    if start is None:
        raise ValueError(key)
    following = re.search(r"^(?:static )?func ", source[start.end():], re.M)
    body = source[start.start():start.end() + following.start() if following else len(source)]
    signature = body[:body.index("->")]
    fields = re.findall(r"(\w+)\s*:\s*(\w+(?:\.\w+)*)", signature)
    fields += re.findall(r"\b(?:var|for) (\w+)\s*:\s*(\w+(?:\.\w+)*)", body)
    return {"source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "numeric_bytes": sum(WIDTH.get(kind, 0) for _, kind in fields),
            "borrowed_or_interned_values": [name for name, kind in fields if kind not in WIDTH],
            "numeric_values": {name: kind for name, kind in fields if kind in WIDTH}}


def main():
    frames = {key: frame(key) for chain in PATHS.values() for key in chain}
    paths = {name: {"chain": chain, "declared_numeric_bytes": sum(frames[key]["numeric_bytes"] for key in chain),
                    "expression_result_allowance": 48} for name, chain in PATHS.items()}
    largest = max(value["declared_numeric_bytes"] + value["expression_result_allowance"] for value in paths.values())
    result = {"retained_delta_bytes": 0, "new_banks": 0, "helper_reservation": 512,
              "largest_reviewed_numeric_path": largest, "runtime_native_qualified": False,
              "convention": "int8/bool1/Vector2i8/Vector3i12; sum all declared locals and parameters conservatively; "
                            "48 extra bytes for expression/result values; borrowed references, interned StringNames, "
                            "Variant headers, engine frames and existing OpResult native allocations are not a measured-byte claim",
              "paths": paths, "frames": frames}
    print(json.dumps(result, indent=2))
    return 0 if largest <= 512 else 1


if __name__ == "__main__":
    raise SystemExit(main())
