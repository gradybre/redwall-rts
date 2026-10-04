#!/usr/bin/env python3
"""Reproduce decision1133's logical census; no native allocation claim is made."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
BASE = "1a754780"
sys.path.insert(0, str(ROOT / "tools"))
import underground_memory_budget as memory

WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
MODULES = ("underground_entry_bindings", "underground_locations", "underground_surface_anchor")


def frames(module):
    """Count explicit numeric parameters/locals; retain conservative repeated loop declarations."""
    lines = (ROOT / "godot/scripts/core" / (module + ".gd")).read_text().splitlines()
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


def own_chain(module, selected):
    """Find a deterministic longest own-function chain; borrowed-owner allowance is added separately."""
    functions = frames(module)

    def visit(name, stack):
        size, body = functions[name]
        children = sorted({child for child in re.findall(r"(?<!\.)\b(\w+)\s*\(", body)
                           if child in functions and child not in stack and child != name})
        nested = [visit(child, stack | {name}) for child in children]
        best = max(nested, key=lambda row: (row[0], row[1])) if nested else (0, [])
        return size + best[0], [name] + best[1]

    size, path = max((visit(name, set()) for name in functions if selected in name),
                     key=lambda row: (row[0], row[1]))
    return {"bytes": size, "path": path, "frames": {name: functions[name][0] for name in path}}


def main():
    pins = json.loads((HERE / "source-sha256.json").read_text())
    for name, expected in pins.items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected, name
    for module in MODULES:
        name = f"godot/scripts/core/{module}.gd"
        before = subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT, text=True)
        after = (ROOT / name).read_text()
        assert memory.explicit_members(before) == memory.explicit_members(after), module
    index = memory.audit.load_source_index()
    retained = memory.entry_bindings_reservation(index)
    assert retained["numeric_controls"] == 74
    assert retained["fixed_numeric_and_packed_bytes"] == 486
    body = memory.class_body(index["underground_entry_bindings"].text,
                             "TimberClearance", "WorldRoutes.Clearance")
    assert memory.explicit_members(body, "\t") == {}
    assert body.count(".resize(6 * capacity)") == 2 and body.count(".resize(6)") == 4
    entry = own_chain("underground_entry_bindings", "timber")
    installed = own_chain("underground_locations", "installed")
    record = own_chain("underground_locations", "record_geometry")
    surface = own_chain("underground_surface_anchor", "create")
    assert entry["bytes"] == 253 and installed["bytes"] == 336
    assert record["bytes"] == 344 and surface["bytes"] == 113
    root_leaf = frames("underground_locations")["support_covers_root"][0]
    assert root_leaf == 12
    # The foreign Space/Value.valid_box leaf and all arithmetic intermediates are
    # inside the unchanged nested-owner allowance. No record or box is copied.
    nested = 512
    outer = 40 + 24 + 96 + nested
    helper = entry["bytes"] + outer
    assert helper == 925 and helper <= 2048 and record["bytes"] <= nested
    report = {
        "scope": "Source-derived logical numeric/control census only. Object/reference/StringName/native frame allocation remains unmeasured.",
        "baseline_commit": BASE,
        "retained_members_match_baseline": list(MODULES),
        "retained_delta_bytes": 0,
        "existing_record_box_bytes": 48,
        "retained_entry": retained,
        "entry_numeric_chain": entry,
        "installed_location_numeric_chain": installed,
        "record_geometry_numeric_chain": record,
        "surface_numeric_chain": surface,
        "support_root_leaf_numeric_bytes": root_leaf,
        "entry_outer_clearance_and_nested_allowance_bytes": outer,
        "entry_total_helper_bytes": helper,
        "entry_helper_reserve_bytes": 2048,
        "location_nested_helper_ceiling_bytes": nested,
        "surface_existing_reserve_bytes": 2048,
        "cold_variable_delta_bytes": 0,
        "runtime_qualified": False,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
