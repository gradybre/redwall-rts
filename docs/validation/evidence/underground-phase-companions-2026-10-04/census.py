#!/usr/bin/env python3
"""Source-counted 1121 logical lifetime; no native allocation or runtime admission claim."""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
import underground_memory_budget as memory

BASE = "6830c2b4"
WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}


def frame(module, function):
    """Count typed numeric parameters and locals, retaining simultaneous lexical locals conservatively."""
    lines = (ROOT / "godot/scripts/core" / f"{module}.gd").read_text().splitlines()
    start = next(i for i, line in enumerate(lines)
                 if re.match(rf"^(?:static )?func {re.escape(function)}\(", line))
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or lines[end].startswith(("\t", " "))):
        end += 1
    body = "\n".join(lines[start:end])
    return sum(WIDTHS[kind] for _, kind in re.findall(r"\b(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", body))


def main():
    index = memory.audit.load_source_index()
    module = "underground_connector_placements"
    source = index[module].text
    old = subprocess.check_output(["git", "show", f"{BASE}:godot/scripts/core/{module}.gd"], cwd=ROOT, text=True)
    before, after = memory.explicit_members(old), memory.explicit_members(source)
    assert {k: v for k, v in after.items() if k not in before} == {
        "_phase_context": "Locations.PhaseContext", "_phase_mode": "bool"}
    assert all(after[k] == v for k, v in before.items())
    phase_refs = {k: "WeakRef" for k in ("issuer", "authority", "sites", "space", "locations")}
    phase_refs["budget"] = "Budget"
    install_refs = {k: "WeakRef" for k in ("issuer", "router", "paid_owner", "space", "locations")}
    install_refs.update(construction="Construction", budget="Budget")
    room_refs = {k: "WeakRef" for k in ("orders", "space", "locations")}
    room_refs["budget"] = "Budget"
    request = memory.scalar_packet(index, module, "Request", {"targets": "PackedInt32Array"})
    openings = re.search(r"(?m)^const MAX_OPENINGS_PER_VARIANT: int = (\d+)\b", index["underground_connector_catalog"].text)
    assert openings and int(openings.group(1)) == 16
    assert "_request.targets.resize(4 * Catalog.MAX_OPENINGS_PER_VARIANT)" in source
    request += 4 * 4 * int(openings.group(1))
    components = {
        "owner": memory.numeric_fields(source, ""),
        "bank_free_counts": 2 * memory.numeric_fields(memory.class_body(source, "Bank"), "\t"),
        "installation_context": memory.scalar_packet(index, "underground_locations", "InstallationContext", install_refs),
        "room_context": memory.scalar_packet(index, "underground_locations", "RoomContext", room_refs),
        "phase_context": memory.scalar_packet(index, "underground_locations", "PhaseContext", phase_refs),
        "directory_candidate": memory.scalar_packet(index, "entity_directory", "CreateCandidate", {"_directory": "WeakRef"}),
        "private_and_caller_requests": 2 * request,
        "shared_order_and_assembly_records": memory.scalar_packet(index, module, "OrderRecord")
            + memory.scalar_packet(index, "underground_connector_assemblies", "AssemblyRecord"),
        "returned_result": memory.scalar_packet(index, module, "Result"),
        "final_digest": 32,
        "helper_frames": 512,
    }
    assert components["owner"] == 119 and components["phase_context"] == 128
    assert sum(components.values()) == 1799
    spec = importlib.util.spec_from_file_location("timber_census", ROOT /
        "docs/validation/evidence/underground-installed-timber-2026-10-04/census.py")
    previous = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(previous)
    authority = "underground_space_authority"
    locations = "underground_locations"
    outer = {name: frame(authority, name) for name in ("operation_refusal", "_run_cold_operation", "_prepare")}
    assert sum(outer.values()) == 108
    row_refresh = previous.own_chain(module, "phase")
    installed_refresh = previous.own_chain(locations, "stage_refresh")
    installed_leaf = previous.own_chain(locations, "installed")
    assert row_refresh["bytes"] == 177 and installed_refresh["bytes"] == 272 and installed_leaf["bytes"] == 248
    chains = {
        "source_row_refresh": sum(outer.values()) + 40 + row_refresh["bytes"],
        "installed_endpoint_refresh": sum(outer.values()) + 40 + frame(module, "prepare_phase_refresh")
            + frame(module, "_phase_prepare_banks") + frame(module, "_phase_prepare_locations") + installed_refresh["bytes"],
        "terminal_installed_leaf": frame(authority, "final_settlement_leaf_refusal")
            + frame(authority, "_final_phase_leaf") + frame(authority, "_concrete_phase_leaf")
            + frame(module, "prepared_phase_leaf_refusal") + installed_leaf["bytes"],
    }
    assert chains == {"source_row_refresh": 325, "installed_endpoint_refresh": 484, "terminal_installed_leaf": 360}
    assert max(chains.values()) <= components["helper_frames"]
    r, o, two_plans, controls = 6144, 2048, 145872, 4096
    cold = {
        "locations_and_two_plans": 88 * r + 384 + two_plans + controls,
        "world_routes_and_two_plans": 48 * r + 16 * o + 49152 + two_plans + controls,
    }
    assert cold == {"locations_and_two_plans": 691024, "world_routes_and_two_plans": 526800}
    assert max(cold.values()) <= 1048960
    print(json.dumps({
        "scope": "Logical numeric/packed census; reference headers, StringNames, native stack/capacity and runtime peaks are unmeasured.",
        "base": BASE,
        "fixed_components": components,
        "fixed_total": sum(components.values()),
        "existing_fixed_reserve": 2048,
        "new_numeric_bytes": 129,
        "new_packed_columns": 0,
        "borrowed_contexts": "Owner has one weak reference; Locations borrows the same actual PhaseContext; no second packet.",
        "phase_context_reference_lifetime": "Five weak owner refs and one strong original Budget remain bound; per-operation numeric scope clears only after own candidates drop.",
        "outer_authority_frames": outer,
        "provider_callback_numeric_allowance": 40,
        "source_refresh_chain": row_refresh,
        "installed_refresh_chain": installed_refresh,
        "installed_leaf_chain": installed_leaf,
        "cross_owner_numeric_chains": chains,
        "cold_peaks": cold,
        "cold_scope": "1093 P1013 two-Plan ceiling; original survey dropped before companions; Locations image dropped before WorldRoutes. Preallocated banks are already reserved, never charged twice.",
        "controls_cold_allowance": controls,
        "whole_original_cold_lease": 1048960,
        "runtime_qualified": False,
    }, indent=2))


if __name__ == "__main__":
    main()
