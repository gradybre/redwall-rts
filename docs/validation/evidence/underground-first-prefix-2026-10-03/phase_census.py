#!/usr/bin/env python3
"""Source-count the new 1119 logical packet; native allocations remain unmeasured."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "godot/scripts/core/underground_entry_world_bindings.gd"
WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
PACKED_LENGTHS = {"_entry_box": 6, "_entry_air": 6, "_entry_reach": 6}


def packet(text):
    """Every top-level declaration is counted or explicitly identified as borrowed native state."""
    retained = {}
    native = []
    for line in text.splitlines():
        if not re.match(r"^var\b", line):
            continue
        match = re.fullmatch(r"var\s+(\w+)\s*:\s*(\w+)\s*=\s*.+", line)
        if not match or match[1] in retained or match[1] in native:
            raise AssertionError(f"Uncounted or duplicate declaration: {line}")
        name, kind = match[1], match[2]
        if kind in WIDTHS:
            retained[name] = WIDTHS[kind]
        elif kind == "PackedInt32Array" and name in PACKED_LENGTHS:
            assert f"{name}.resize({PACKED_LENGTHS[name]})" in text
            retained[name] = 4 * PACKED_LENGTHS[name]
        elif name == "_entry_contacts" and kind == "WeakRef":
            native.append(name)
        else:
            raise AssertionError(f"Unknown retained member: {line}")
    assert sum(retained.values()) == 202
    assert set(PACKED_LENGTHS) <= retained.keys()
    return retained, native


def frames(text):
    """Conservatively sum all typed numeric arguments/locals along the longest own-source call chain."""
    lines = text.splitlines()
    functions = {}
    for start, line in enumerate(lines):
        match = re.match(r"^(?:static )?func (\w+)\(", line)
        if not match:
            continue
        end = start + 1
        while end < len(lines) and (not lines[end].strip() or lines[end].startswith(("\t", " "))):
            end += 1
        body = "\n".join(lines[start:end])
        values = re.findall(r"\b\w+\s*:\s*(int|bool|Vector2i|Vector3i)\b", body)
        functions[match[1]] = (sum(WIDTHS[kind] for kind in values), body)

    def visit(name, ancestors):
        size, body = functions[name]
        children = {called for called in re.findall(r"(?<!\.)\b(_?\w+)\s*\(", body)
                    if called in functions and called != name}
        if children & ancestors:
            raise AssertionError(f"Recursive numeric lifetime at {name}")
        tails = [visit(child, ancestors | {name}) for child in children]
        largest = max(tails, key=lambda row: row[0]) if tails else (0, [])
        return size + largest[0], [name] + largest[1]

    size, path = max((visit(name, set()) for name in functions), key=lambda row: row[0])
    assert size <= 1024
    return {"bytes": size, "path": path, "frames": {name: functions[name][0] for name in path}}


def main():
    text = SOURCE.read_text()
    retained, native = packet(text)
    report = {
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "fixed_bytes": sum(retained.values()),
        "fixed_fields": retained,
        "own_numeric_chain": frames(text),
        "own_helper_reserve_bytes": 1024,
        "fixed_plus_helper_bytes": sum(retained.values()) + 1024,
        "new_global_reservation_bytes": 2048,
        "remaining_inside_reservation_bytes": 2048 - sum(retained.values()) - 1024,
        "separately_accounted_contacts_bytes": 4083,
        "contacts_instances": 1,
        "borrowed_native_members": native,
        "scope": "Logical source census only. Existing Contacts/World/Authority packets remain separately charged; native frames, headers and timing are unqualified.",
        "runtime_qualified": False,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
