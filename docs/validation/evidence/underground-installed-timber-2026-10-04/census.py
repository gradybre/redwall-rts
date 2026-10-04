#!/usr/bin/env python3
"""Reproduce the logical 1114 census; this is not native allocation measurement."""
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
import underground_memory_budget as memory

WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}


def own_chain(module, selected):
    """Count every typed numeric parameter/local, including conservative duplicate loop locals."""
    lines = (ROOT / "godot/scripts/core" / (module + ".gd")).read_text().splitlines()
    functions = {}
    for start, line in enumerate(lines):
        if not re.match(r"^(?:static )?func ", line):
            continue
        end = start + 1
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith(("\t", " "))):
            end += 1
        body = "\n".join(lines[start:end])
        name = re.search(r"func (\w+)", line).group(1)
        numeric = re.findall(r"\b(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", body)
        functions[name] = (sum(WIDTHS[kind] for _, kind in numeric), body)

    def visit(name, stack):
        size, body = functions[name]
        children = {child for child in re.findall(r"(?<!\.)\b(_\w+)\s*\(", body)
                    if child in functions and child not in stack and child != name}
        nested = [visit(child, stack | {name}) for child in children]
        best = max(nested, key=lambda row: row[0]) if nested else (0, [])
        return size + best[0], [name] + best[1]

    size, path = max((visit(name, set()) for name in functions if selected in name), key=lambda row: row[0])
    return {"bytes": size, "path": path, "frames": {name: functions[name][0] for name in path}}


def main():
    index = memory.audit.load_source_index()
    retained = memory.entry_bindings_reservation(index)
    assert retained["numeric_controls"] == 74
    assert retained["fixed_numeric_and_packed_bytes"] == 486
    source = index["underground_entry_bindings"].text
    body = memory.class_body(source, "TimberClearance", "WorldRoutes.Clearance")
    assert memory.explicit_members(body, "\t") == {}
    assert body.count(".resize(6 * capacity)") == 2
    assert body.count(".resize(6)") == 4
    own = own_chain("underground_entry_bindings", "timber")
    installed = own_chain("underground_locations", "installed")
    assert own["bytes"] == 256 and installed["bytes"] == 248
    # 40B AdmissionAuthority outer arguments; 24B Clearance counters; 96B boxes.
    # The 248B installed-witness chain remains inside the existing nested-owner ceiling512.
    # Those nested readers reuse the existing packet/arrays, with no new retained state.
    helper = own["bytes"] + 40 + 24 + 96 + 512
    assert helper == 928 and helper <= 2048
    r, o = 6144, 2048
    report = {
        "scope": "Logical source census only; borrowed references, StringNames, packed headers and native frames unmeasured.",
        "retained_entry": retained,
        "retained_delta_bytes": 32,
        "own_entry_numeric_chain": own,
        "own_installed_location_numeric_chain": installed,
        "helper_charge_bytes": helper,
        "helper_reserve_bytes": 2048,
        "geometry_variable_bytes": 48 * r,
        "geometry_with_fixed_allowance_bytes": 48 * r + 4096,
        "conservative_geometry_ceiling_bytes": 96 * r + 16 * o + 4096,
        "placement_retained_reservation_bytes": 108800,
        "placement_reservation_note": "Already charged in bindings; no additional copy during installation.",
        "phase_order": ["local geometry banks dropped", "Locations existing survey/coverage", "WorldRoutes existing certificate compiler"],
        "entry_plan_payload_during_installation_bytes": 0,
        "shared_cold_bytes": 1048960,
        "runtime_qualified": False,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
