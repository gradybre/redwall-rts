#!/usr/bin/env python3
"""1151 source-derived unchanged storage and bounded numeric helper frames."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools"))
import underground_memory_budget as memory

BASE = "e2f76f5484efff2af629f1ae2283232a3c73576d"
MODULES = ["underground_space_owner", "underground_locations", "underground_final_facts"]
WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}


def functions(source):
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
        result[name] = {"bytes": sum(WIDTHS[kind] for _, kind in numeric), "body": body}
    return result


def own_chain(module, entry, sources):
    found = functions(sources[module])
    def visit(name, prior):
        body = found[name]["body"]
        children = sorted({child for child in re.findall(r"(?<!\.)\b(\w+)\s*\(", body)
                           if child in found and child not in prior and child != name})
        candidates = [visit(child, prior | {name}) for child in children]
        best = max(candidates, key=lambda row: (row[0], row[1])) if candidates else (0, [])
        return found[name]["bytes"] + best[0], [name] + best[1]
    size, path = visit(entry, set())
    return {"bytes": size, "frames": {module + "." + name: found[name]["bytes"] for name in path}}


def main():
    sources = {module: (ROOT / "godot/scripts/core" / (module + ".gd")).read_text() for module in MODULES}
    for module, source in sources.items():
        old = subprocess.check_output(["git", "show", BASE + ":godot/scripts/core/" + module + ".gd"], cwd=ROOT, text=True)
        assert memory.explicit_members(source) == memory.explicit_members(old), (module, "retained members changed")
        classes = re.findall(r"^class (\w+) extends ([^:]+):", source, re.M)
        assert classes == re.findall(r"^class (\w+) extends ([^:]+):", old, re.M)
        for name, parent in classes:
            assert memory.explicit_members(memory.class_body(source, name, parent), "\t") == memory.explicit_members(memory.class_body(old, name, parent), "\t"), (module, name)
        for pattern in [r"Packed\w+Array\(", r"\.resize\(", r"\.duplicate\(", r"\.new\("]:
            assert len(re.findall(pattern, source)) == len(re.findall(pattern, old)), (module, pattern)
    context = memory.class_body(sources["underground_locations"], "RoomContext")
    assert memory.numeric_fields(context, "\t") == 80
    entries = [("underground_space_owner", "room_commit_preflighted"),
               ("underground_space_owner", "_ordinary_room_plan_matches"),
               ("underground_locations", "room_scope_leaf_refusal"),
               ("underground_locations", "room_prepared_leaf_refusal"),
               ("underground_locations", "publish_room_preflighted"),
               ("underground_final_facts", "prepared_room_refusal")]
    chains = {module + "." + name: own_chain(module, name, sources) for module, name in entries}
    comparison = chains["underground_space_owner._ordinary_room_plan_matches"]["bytes"]
    for entry in ["underground_locations.room_scope_leaf_refusal", "underground_locations.room_prepared_leaf_refusal", "underground_locations.publish_room_preflighted"]:
        # Conservatively add the shared comparison even when the greatest own chain selects the row scan.
        chains[entry]["with_shared_comparison_upper_bound"] = chains[entry]["bytes"] + comparison
    assert max(row.get("with_shared_comparison_upper_bound", row["bytes"]) for row in chains.values()) <= 512
    print(json.dumps({"base": BASE, "source_sha256": {module: hashlib.sha256(source.encode()).hexdigest() for module, source in sources.items()},
        "new_retained_bytes": 0, "new_banks": 0, "new_packed_allocations": 0, "room_context_bytes": 80,
        "component_numeric_chains": chains,
        "ordinary_request_checks": "2 * max(private.cells.size, original.cells.size), before comparison and source/claim scans",
        "cold_lifetime": "No new packet, survey, copy or bank. Original plan and exact candidate remain retained under the original full Cold Budget lease. Sealed Location/Route candidates use existing banks; allocation observers finish before Sites prepares its existing claim packet.",
        "scope": "Numeric frames only. Borrowed references and Variant/StringName/interpreter/native storage remain within existing provisional controls, not newly measured. Root and RoomBindings caller frames require combined census.",
        "runtime_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
