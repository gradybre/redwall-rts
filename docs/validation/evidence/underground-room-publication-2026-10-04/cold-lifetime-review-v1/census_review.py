#!/usr/bin/env python3
"""Read-only, source-counted Room lifetime review. No engine or foreign writes.

The 1150 source is a development snapshot, not an accepted frozen candidate.
Its final implementation and full external helper closure need a later review.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

OWN = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(OWN / "tools"))
import underground_memory_budget as memory

WIDTH = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--integration", type=Path, required=True)
    parser.add_argument("--approach", type=Path, required=True)
    parser.add_argument("--tail-review", type=Path, required=True)
    args = parser.parse_args()
    inputs = {}

    def read(path):
        raw = path.read_bytes()
        inputs[str(path)] = hashlib.sha256(raw).hexdigest()
        return raw.decode()

    root_manifest_path = args.integration / "docs/validation/evidence/underground-room-tail-integration-2026-10-04/focused-2/source-sha256.json"
    root_manifest = json.loads(read(root_manifest_path))
    for relative, digest in root_manifest.items():
        read(args.integration / relative)
        assert inputs[str(args.integration / relative)] == digest, relative

    tail = load_module(args.tail_review / "numeric_frames.py", "review_tail_frames")
    read(args.tail_review / "numeric_frames.py")
    tail_report = json.loads(read(args.tail_review / "numeric-frames.json"))
    for relative, digest in tail_report["source_sha256"].items():
        read(args.integration / relative)
        assert inputs[str(args.integration / relative)] == digest, relative
    assert tail_report["combined_logical_allowance_bytes"] == 1582

    sources = {}
    def source(file, approach=False):
        key = (file, approach)
        if key not in sources:
            base = args.approach if approach else args.integration
            sources[key] = read(base / "godot/scripts/core" / file)
        return sources[key]

    def numeric(file, name, parent="RefCounted", approach=False):
        return memory.numeric_fields(memory.class_body(source(file, approach), name, parent), "\t")

    def frame(file, name, approach=False):
        signature, body = tail.function(source(file, approach), name)
        params = re.findall(r"\b(\w+)\s*:\s*(\w+)", signature.split(") ->")[0])
        clean = re.sub(r'"""[\s\S]*?"""', "", body)
        clean = re.sub(r"(?m)#.*$", "", clean)
        locals_ = re.findall(r"\b(?:var|for)\s+(\w+)\s*:\s*(\w+)", clean)
        values = [(key, typ, WIDTH[typ]) for key, typ in params + locals_ if typ in WIDTH]
        return {"file": file, "function": name, "numeric": values,
                "bytes": sum(value[2] for value in values)}

    sizes = {
        "descriptor": numeric("underground_profiles.gd", "Descriptor"),
        "box": numeric("underground_profiles.gd", "Box"),
        "record_including_two_six_i32_arrays": numeric("underground_locations.gd", "Record") + 48,
        "region_including_six_i32_array": numeric("underground_space_owner.gd", "Region") + 24,
        "domain_including_bounds": numeric("room_space.gd", "Domain") + 24,
        "face_direct": numeric("underground_work_face.gd", "Check"),
        "face_request": numeric("underground_work_face.gd", "Request"),
        "room_context": numeric("underground_locations.gd", "RoomContext"),
        "witness_direct": numeric("underground_room_approach.gd", "Witness", approach=True),
        "approach_request_extension": numeric("underground_room_approach.gd", "Request", "Orders.RoomPlan", True),
    }
    face = (sizes["face_direct"] + 2 * sizes["face_request"] + sizes["descriptor"]
            + 2 * sizes["box"] + 2 * sizes["record_including_two_six_i32_arrays"]
            + sizes["region_including_six_i32_array"] + sizes["domain_including_bounds"] + 96)
    witness = (sizes["witness_direct"] + sizes["approach_request_extension"] + 3 * sizes["descriptor"]
               + sizes["record_including_two_six_i32_arrays"] + 112 + 672 + 96 + sizes["room_context"])
    assert (face, witness) == (907, 1744)
    a_source = source("underground_room_approach.gd", True)
    assert "face.proof = null" in a_source
    a_frames = [frame("underground_room_approach.gd", name, True)
                for name in re.findall(r"^\s*(?:static )?func (\w+)\(", a_source, re.M)]

    additional = {
        "underground_locations.gd": "room_scope_leaf_refusal room_prepared_leaf_refusal _room_rows_leaf_refusal publish_room_preflighted _clear_installation_preparation",
        "underground_routes.gd": "room_prepared_leaf_refusal publish_room_preflighted _retained_paths_refusal _commit_preflighted_bank",
        "underground_world_routes.gd": "room_prepared_leaf_refusal publish_room_preflighted _prepared_masks_refusal _commit_preflighted_certificates",
        "underground_connector_source_facts.gd": "_same_actual_owners _source_storage_matches _source_digests_match",
    }
    companion_frames = [frame(file, name) for file, names in additional.items() for name in names.split()]
    companion_sum = sum(row["bytes"] for row in companion_frames)
    assert companion_sum == 154
    old_own = json.loads(read(OWN / "docs/validation/evidence/underground-room-publication-2026-10-04/census.json"))
    own_final = old_own["component_numeric_chains"]["underground_final_facts.prepared_room_refusal"]["bytes"]
    old_full = json.loads(read(OWN / "docs/validation/evidence/underground-room-publication-2026-10-04/existing-workpiece-census.json"))
    final_reader = old_full["final_source_reader_numeric_chain"]["bytes"]
    combined_tail = 1582 + companion_sum + own_final + final_reader
    assert combined_tail == 1984 and combined_tail <= 2048

    n, r, o, k, edges = 16384, 6144, 2048, 8192, 1536
    snapshot = 48 * r + 16 * o
    path = 8 * edges
    face_allowance, approach_allowance, room_allowance = 2048, 4096, 2048
    retained_extra = path + face_allowance + approach_allowance
    phases = {
        "original_survey": snapshot + 8 * n + 24 * n + room_allowance,
        "prospective_face": snapshot + 48 * 1024 + face_allowance + path + approach_allowance + 24 * n + room_allowance,
        "locations_preparation": snapshot + 24 * k + 384 + 24 * n + room_allowance + retained_extra,
        "worldroutes_preparation": snapshot + 48 * 1024 + 1024 + 24 * n + room_allowance + retained_extra,
        "sites_four_images_and_final_publication": 40 * n + room_allowance + retained_extra,
    }
    assert phases == {"original_survey": 854016, "prospective_face": 790528,
                      "locations_preparation": 938368, "worldroutes_preparation": 791552,
                      "sites_four_images_and_final_publication": 675840}
    assert max(phases.values()) < 1048960
    source_unchanged = all(hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest for path, digest in inputs.items())
    assert source_unchanged
    print(json.dumps({
        "scope": "Preparatory lifetime review; 1150 remains moving and not source-accepted by this report.",
        "source_sha256": inputs, "root_11_pins_match": True, "sources_unchanged_during_read": source_unchanged,
        "packet_components": sizes, "retained_face_without_proof_bytes": face,
        "witness_without_face_or_path_bytes": witness, "combined_retained_numeric_bytes": face + witness,
        "path_max_bytes": path, "approach_all_declared_function_frames": a_frames,
        "approach_all_declared_function_frames_sum": sum(row["bytes"] for row in a_frames),
        "additional_static_companion_frames": companion_frames,
        "additional_static_companion_frame_sum": companion_sum,
        "root_reviewed_packet_and_frames": 1582, "finalfacts_own_chain_upper": own_final,
        "core_final_reader_upper": final_reader, "combined_scoped_room_tail_upper": combined_tail,
        "room_helper_allowance": 2048,
        "caveat": "The 1984 scoped allowance excludes 1150 functions and packets, charged separately. It conservatively sums sequential kernels and alternative final-reader chains. It is not a complete native/interpreter stack measurement.",
        "conservative_proposal_allowances": {"retained_face_and_helpers": face_allowance,
             "approach_witness_and_helpers": approach_allowance, "original_room_packets_and_helpers": room_allowance},
        "sequential_cold_peaks": phases, "maximum_proposed_cold_peak": max(phases.values()),
        "cold_reserve": 1048960, "cold_headroom": 1048960 - max(phases.values()),
        "finding": "Draft 1150 omitted the larger Locations preparation peak; corrected lifetime must retain the path and Face fixed controls after proof=null.",
        "open": "Frozen 1150 exact helper/observer/source review and closure of every foreign call remain separate. No new bank/reserve is proposed or runtime qualification inferred.",
        "engine_run": False, "runtime_qualified": False,
    }, indent=2))


if __name__ == "__main__":
    main()
