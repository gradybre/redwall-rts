#!/usr/bin/env python3
"""Source-counted 1135 logical lifetime, including the original cross-owner phase path."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import textwrap

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
import underground_memory_budget as memory

BASE = "ac766929"
WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
P = "underground_connector_placements"
W = "underground_connector_workpieces"
E = "underground_entry_bindings"
L = "underground_locations"
A = "underground_space_authority"
SOURCE_OVERRIDES = {}


def source_text(module):
    path = SOURCE_OVERRIDES.get(module, ROOT / "godot/scripts/core" / f"{module}.gd")
    return path.read_text()


def functions(module, nested=None):
    """Count explicit numeric parameters/locals, conservatively retaining repeated lexical declarations."""
    source = source_text(module)
    if nested:
        source = textwrap.dedent(memory.class_body(source, nested, "Sources"))
    lines = source.splitlines()
    result = {}
    for start, line in enumerate(lines):
        if not re.match(r"^(?:static )?func ", line):
            continue
        end = start + 1
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith(("\t", " "))):
            end += 1
        body = "\n".join(lines[start:end])
        name = re.search(r"func (\w+)", line).group(1)
        numeric = re.findall(r"\b(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", body)
        result[name] = (sum(WIDTHS[kind] for _, kind in numeric), body)
    return result


def own_chain(module, entry, nested=None):
    """Trace own synchronous calls; concrete foreign calls are joined explicitly below."""
    found = functions(module, nested)

    def visit(name, stack):
        size, body = found[name]
        children = sorted({child for child in re.findall(r"(?<!\.)\b(\w+)\s*\(", body)
                           if child in found and child not in stack and child != name})
        nested = [visit(child, stack | {name}) for child in children]
        best = max(nested, key=lambda row: (row[0], row[1])) if nested else (0, [])
        return size + best[0], [name] + best[1]

    size, path = visit(entry, set())
    module = module + "." + nested if nested else module
    return {"bytes": size, "path": [f"{module}.{name}" for name in path],
            "frames": {f"{module}.{name}": found[name][0] for name in path}}


def chain(entries, callback=0):
    """Join exact declared active frames; callback allowance is the five numeric Authority arguments."""
    frames = {f"{module}.{name}": functions(module)[name][0] for module, name in entries}
    if callback:
        assert callback == 40
        source = (ROOT / "godot/scripts/core" / f"{E}.gd").read_text()
        body = memory.class_body(source, "AdmissionAuthority", "Placements.Authority")
        signature = re.search(r"func stage_locations\((.*?)\) -> StringName:", body, re.S).group(1)
        assert sum(WIDTHS[k] for k in re.findall(r":\s*(int|Vector2i)\b", signature)) == callback
        frames[f"{E}.AdmissionAuthority.stage_locations"] = callback
    return {"bytes": sum(frames.values()), "frames": frames}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--workpieces-source", type=Path)
    args = parser.parse_args()
    if args.workpieces_source:
        SOURCE_OVERRIDES[W] = args.workpieces_source.resolve()
    index = memory.audit.load_source_index()
    source = index[P].text
    old = subprocess.check_output(["git", "show", f"{BASE}:godot/scripts/core/{P}.gd"], cwd=ROOT, text=True)
    before, after = memory.explicit_members(old), memory.explicit_members(source)
    assert {k: v for k, v in after.items() if k not in before} == {
        "_workpieces": "WeakRef", "_prepared_action": "int", "_prepared_obstacle": "Vector2i"}
    assert all(after[k] == v for k, v in before.items())
    install_refs = {k: "WeakRef" for k in ("issuer", "router", "paid_owner", "space", "locations")}
    install_refs.update(construction="Construction", budget="Budget")
    phase_refs = {k: "WeakRef" for k in ("issuer", "authority", "sites", "space", "locations")}
    phase_refs["budget"] = "Budget"
    room_refs = {k: "WeakRef" for k in ("orders", "space", "locations")}
    room_refs["budget"] = "Budget"
    request = memory.scalar_packet(index, P, "Request", {"targets": "PackedInt32Array"}) + 4 * 4 * 16
    assert "_request.targets.resize(4 * Catalog.MAX_OPENINGS_PER_VARIANT)" in source
    assert re.search(r"^const MAX_OPENINGS_PER_VARIANT: int = 16\b", index["underground_connector_catalog"].text, re.M)
    components = {
        "owner": memory.numeric_fields(source, ""),
        "bank_free_counts": 2 * memory.numeric_fields(memory.class_body(source, "Bank"), "\t"),
        "installation_context": memory.scalar_packet(index, L, "InstallationContext", install_refs),
        "room_context": memory.scalar_packet(index, L, "RoomContext", room_refs),
        "phase_context": memory.scalar_packet(index, L, "PhaseContext", phase_refs),
        "directory_candidate": memory.scalar_packet(index, "entity_directory", "CreateCandidate", {"_directory": "WeakRef"}),
        "private_and_caller_requests": 2 * request,
        "shared_order_and_assembly_records": memory.scalar_packet(index, P, "OrderRecord")
            + memory.scalar_packet(index, "underground_connector_assemblies", "AssemblyRecord"),
        "returned_result": memory.scalar_packet(index, P, "Result"),
        "final_digest": 32,
        "helper_frames": 576,
    }
    assert components["owner"] == 135 and components["installation_context"] == 128
    assert components["phase_context"] == 128 and sum(components.values()) == 1895
    refresh = own_chain(L, "stage_refresh")
    assert refresh["bytes"] == 360
    workpiece = chain([(W, "prepare_cancel"), (P, "prepare_workpiece_cancel"),
        (P, "_prepare_workpiece"), (P, "_prepare_workpiece_candidates"), (P, "_prepare_locations"),
        (E, "_stage_timber_locations"), (E, "_timber_refresh_locations")], callback=40)
    workpiece["frames"].update(refresh["frames"])
    workpiece["bytes"] += refresh["bytes"]
    phase = chain([(A, "operation_refusal"), (A, "_run_cold_operation"), (A, "_prepare"),
        (P, "prepare_phase_refresh"), (P, "_phase_prepare_banks"), (P, "_phase_prepare_locations")])
    phase["frames"]["phase_provider_callback_numeric_allowance"] = 40
    phase["frames"].update(refresh["frames"])
    phase["bytes"] += 40 + refresh["bytes"]
    source_bounds = chain([(W, "prepare_start"), (P, "prepare_workpiece_start"),
        (P, "_prepare_workpiece"), (P, "_workpiece_admission_leaf"),
        (W, "prepared_bounds_leaf_refusal"), (W, "_bounds_into"), (W, "_coordinate")])
    assert workpiece["bytes"] == 568 and phase["bytes"] == 572 and source_bounds["bytes"] == 376
    assert max(workpiece["bytes"], phase["bytes"], source_bounds["bytes"]) <= components["helper_frames"]
    own = {module + "." + entry: own_chain(module, entry) for module, entry in [
        (P, "prepare_workpiece_cancel"), (E, "_workpiece_refusal"),
        (W, "bind_prepared_completion"), ("underground_world_routes", "workpiece_occupancy_refusal"),
        ("underground_routes", "physical_selection_into")]}
    final_sources = own_chain("underground_space_owner", "read_final_into", "CoreSources")
    assert final_sources["bytes"] == 88
    core = functions("underground_space_owner", "CoreSources")
    packed_reads = {name: len(re.findall(r"\b\w+\._\w+\[", body))
                    for name, (_, body) in core.items() if name.startswith("_final_") or name == "read_final_into"}
    source_reads = {kind: packed_reads["read_final_into"] + packed_reads["_final_row"] + packed_reads[name]
                    + (packed_reads["_final_row"] if kind == "furniture" else 0)
                    for kind, name in [("building", "_final_building"), ("room", "_final_room"),
                                       ("furniture", "_final_furniture"), ("project", "_final_project")]}
    assert source_reads == {"building": 16, "room": 21, "furniture": 29, "project": 16}
    final_claim = chain([(W, "prepare_cancel"), (P, "prepare_workpiece_cancel"),
        (P, "_prepare_workpiece"), (P, "_prepare_workpiece_candidates"),
        (P, "prepared_workpiece_leaf_refusal"), (P, "_prepared_geometry_leaf"),
        (P, "_prepared_sources_leaf"), (P, "_prepared_claims_leaf")])
    final_claim["frames"].update(final_sources["frames"])
    final_claim["bytes"] += final_sources["bytes"]
    body = chain([(W, "prepare_cancel"), (P, "prepare_workpiece_cancel"),
        (P, "_prepare_workpiece"), (P, "_prepare_workpiece_candidates"),
        (E, "_workpiece_refusal"), (E, "_workpiece_physical"), (E, "_workpiece_occupants"),
        ("underground_world_routes", "workpiece_occupancy_refusal")])
    body["frames"]["entry_workpiece_authority_callback"] = 32
    body["bytes"] += 32
    physical = own_chain("underground_routes", "physical_selection_into")
    body["frames"].update(physical["frames"])
    body["bytes"] += physical["bytes"]
    assert final_claim["bytes"] <= 576 and body["bytes"] <= 576
    r, o = 6144, 2048
    cold = {"physical": 96 * r + 16 * o + 4096,
            "locations": 88 * r + 384 + 4096,
            "routes": 48 * r + 16 * o + 49152 + 4096}
    assert cold == {"physical": 626688, "locations": 545152, "routes": 380928}
    assert max(cold.values()) <= 1048960
    paths = [f"godot/scripts/core/{name}.gd" for name in
             (P, E, L, W, A, "underground_routes", "underground_world_routes", "underground_space_owner", "underground_final_facts")]
    print(json.dumps({
        "scope": "Logical numeric/packed payloads only; borrowed references, interpreter frames, Variant/StringName headers and native allocations remain unmeasured.",
        "base": BASE,
        "diagnostic_workpieces_source": str(SOURCE_OVERRIDES.get(W, ROOT / "godot/scripts/core" / f"{W}.gd")),
        "source_sha256": {path: hashlib.sha256(source_text(Path(path).stem).encode()).hexdigest() for path in paths},
        "fixed_components": components, "fixed_total": sum(components.values()), "fixed_reserve": 2048,
        "new_retained_numeric_bytes": 32, "new_packed_columns": 0,
        "helper_headroom_reassigned_bytes": 64,
        "weak_workpieces_binding": "One once-bound WeakRef in Placement. Workpieces is strongly borrowed across preparation/publication; its reference/header/native costs remain in the existing provisional native allowance, not declared free or qualified.",
        "cross_owner_numeric_chains": {"workpiece_endpoint_refresh": workpiece,
            "existing_phase_endpoint_refresh": phase, "immutable_preparation_bounds": source_bounds, "final_actual_source_claim": final_claim,
            "current_physical_occupancy": body},
        "own_numeric_chains": own,
        "fixed_cold_packet": "The new Region borrows the immutable bounds array. Its48 numeric bytes and Owner.Result16 are included in the existing4096 cold controls; they do not coexist with Location observation scratch.",
        "sequential_cold_peaks": cold, "original_cold_lease": 1048960,
        "cold_lifetime": "Physical fragment scratch drops before Location proof, which drops before route qualification. All candidate banks are preallocated and already reserved; no RoomPlan images coexist.",
        "workpieces_rows_and_source": "Separately owned1134 two21P banks and32A immutable source, never duplicated or charged as Placement state.",
        "final_source_reader_numeric_chain": final_sources,
        "final_source_packed_reads": source_reads,
        "source_work": "The new concrete reader has at most29 source-counted packed-column reads, including both full Directory/reverse-row checks for Furniture. Existing64-check allowance per non-Resident source/claim bounds complete Directory full-kind/reverse-row/store mirrors plus source fields and final format comparison. Source/region scans remain separately precharged; no full image is added.",
        "runtime_qualified": False,
    }, indent=2))


if __name__ == "__main__":
    main()
