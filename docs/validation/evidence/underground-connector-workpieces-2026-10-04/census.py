#!/usr/bin/env python3
"""Reproduce1134's logical packed/numeric coexistence; this is not native allocation profiling."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
WIDTH = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
W = "underground_connector_workpieces"
C = "underground_connector_contacts"
P = "underground_connector_work"


def source(module):
    return (ROOT / "godot/scripts/core" / (module + ".gd")).read_text()


def members(text, indent=""):
    """Enumerate every concrete declaration at precisely the selected ownership depth."""
    found = {}
    for line in text.splitlines():
        if not re.match(r"^" + indent + r"var\b", line):
            continue
        match = re.fullmatch(indent + r"var\s+(\w+)\s*:\s*([\w.]+)(?:\s*=.*)?", line)
        assert match, line
        assert match[1] not in found, line
        found[match[1]] = match[2]
    return found


def class_body(module, name):
    lines = source(module).splitlines()
    start = next(i for i, line in enumerate(lines) if re.match(r"^class " + name + r"\b", line))
    end = start + 1
    while end < len(lines) and (not lines[end].strip() or lines[end].startswith("\t")):
        end += 1
    return "\n".join(lines[start + 1:end])


def record(module, name, packed=None):
    packed = packed or {}
    fields = members(class_body(module, name), "\t")
    numeric = {key: WIDTH[kind] for key, kind in fields.items() if kind in WIDTH}
    assert set(packed) <= fields.keys()
    for key, kind in fields.items():
        if kind.startswith("Packed"):
            assert key in packed, (module, name, key)
    return sum(numeric.values()) + sum(packed.values())


def numeric_members(module):
    fields = members(source(module))
    return {key: WIDTH[kind] for key, kind in fields.items() if kind in WIDTH}


def functions(module):
    text = re.sub(r'""".*?"""', '""', source(module), flags=re.S)
    starts = list(re.finditer(r"^(?:static )?func (\w+)\(", text, re.M))
    found = {}
    for i, match in enumerate(starts):
        body = text[match.start():starts[i + 1].start() if i + 1 < len(starts) else len(text)]
        signature, rest = body.split("->", 1)
        declared = re.findall(r"\b(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", signature)
        declared += re.findall(r"\b(?:var|for)\s+(\w+)\s*:\s*(int|bool|Vector2i|Vector3i)\b", rest)
        found[match[1]] = {"bytes": sum(WIDTH[kind] for _, kind in declared), "fields": declared,
                           "calls": set(re.findall(r"(?<![\w.])([A-Za-z_]\w*)\s*\(", rest))}
    return found


def chain(module):
    found = functions(module)

    def walk(name, seen):
        assert name not in seen, (module, name)
        children = [walk(c, seen | {name}) for c in found[name]["calls"] if c in found]
        tail = max(children, default=(0, []))
        return found[name]["bytes"] + tail[0], [name] + tail[1]

    size, path = max(walk(name, set()) for name in found)
    return {"bytes": size, "path": path,
            "frames": {name: {"bytes": found[name]["bytes"], "fields": found[name]["fields"]} for name in path}}


def main():
    w = source(W)
    declared = members(w)
    numeric = numeric_members(W)
    assert sum(numeric.values()) == 75
    packed = {"_header": (9, 8), "_digests": (160, 1), "_bounds": (6, 4), "_scratch": (6, 4)}
    for name, (length, _) in packed.items():
        assert w.count(f"{name}.resize({length})") == 1
    assert "_parts.resize(6 * assemblies)" in w and "_profile_revisions.resize(assemblies)" in w
    assert "fields.resize(5 * capacity)" in class_body(W, "Bank")
    assert "present.resize(capacity)" in class_body(W, "Bank")
    assert sum(record("underground_connector_placements", "OrderRecord") for _ in [0]) == 96
    controls = sum(numeric.values()) + 48
    assert controls == 123
    bank = {"fields": 5 * 4, "present": 1}
    immutable = {"header": 9 * 8, "digests": 160, "rows_per_assembly": 6 * 4 + 8}
    assert sum(bank.values()) == 21 and immutable["header"] + immutable["digests"] == 232

    c = source(C)
    lengths = dict((name, int(length)) for name, length in re.findall(r"^\t(_\w+)\.resize\((\d+)\)$", c, re.M))
    c_packed = {name: 4 * lengths[name] for name, kind in members(c).items() if kind == "PackedInt32Array"}
    fragments = record(C, "Fragments", {"first": 6 * 32 * 4, "second": 6 * 32 * 4,
                                        "core": 24, "cut": 24, "slab": 24})
    assert "FRAGMENT_CAPACITY: int = 32" in c and fragments == 1633
    c_packet = {"numeric_members": sum(numeric_members(C).values()), "packed_members": sum(c_packed.values()),
                "order": record("underground_connector_placements", "OrderRecord"),
                "locations": 2 * record("underground_locations", "Record", {"envelope": 24, "support": 24}),
                "descriptor": record("underground_profiles", "Descriptor"),
                "selection": record("underground_profiles", "Selection"),
                "boxes": 2 * record("underground_profiles", "Box"),
                "number": record("int_math", "IntResult"), "fragments": fragments}
    assert sum(c_packet.values()) == 3059
    p_packet = sum(numeric_members(P).values()) + record("underground_connector_placements", "OrderRecord") \
        + record("underground_connector_assemblies", "AssemblyRecord")
    assert p_packet == 179
    chains = {module: chain(module) for module in (W, C, P, "underground_entry_frontier")}
    # Existing foreign source/physical/companion chains are separately reproduced by1135 census.py.
    # Conservatively sum a complete own chain and that full576B envelope, although maxima are on different branches.
    nested = 576
    assert controls + chains[W]["bytes"] + nested <= 2048
    assert chains[C]["bytes"] + nested <= 1024
    assert p_packet + chains[P]["bytes"] <= 512
    assert chains["underground_entry_frontier"]["bytes"] <= nested
    maximum = 42 * 256 + 32 * 256 + 232 + 2048 + 512 + 8192
    assert maximum == 29928
    report = {
        "scope": "Logical numeric/packed payload only. References, headers, expression temporaries, interpreter/native frames and HashingContext/FileAccess/String storage are not measured.",
        "source_sha256": {module: hashlib.sha256(source(module).encode()).hexdigest() for module in chains},
        "workpieces": {"all_top_level_members": declared, "numeric_fields": numeric, "fixed_controls": controls,
            "two_banks_per_placement": 42, "immutable_source": immutable,
            "stream_peak": {"source_header_and_digest_and_magic_slice": 212 + 32 + 8,
                            "source_row_and_digest_and_trailer": 32 + 32 + 8,
                            "capture_header_and_row": 60 + 21, "admitted_stream_allowance": 512},
            "control_helper_allowance": 2048, "provisional_native_reserve": 8192,
            "parametric_bytes": "42P + 32A + 10,984", "maximum_256_each": maximum,
            "design_ceiling": 32768, "whole_capture_wire_bytes": "60 + 21P (streamed, never retained)"},
        "contacts": {"fixed_components": c_packet, "fixed_total": 3059, "packed_fields": c_packed,
                     "helper_allowance": 1024, "total": 4083, "reservation": 4096, "retained_delta": 0},
        "connector_work": {"fixed_total": p_packet, "numeric_fields": numeric_members(P), "retained_numeric_delta": 0,
                           "new_reference": "Strong exact Workpieces owner, native/header cost remains unmeasured"},
        "own_numeric_chains": chains, "existing_foreign_helper_envelope": nested,
        "conservative_contacts_helper_peak": chains[C]["bytes"] + nested,
        "conservative_workpieces_controls_helper_peak": controls + chains[W]["bytes"] + nested,
        "lifetime": "Both row banks and immutable source coexist. Streaming uses one bounded row/header, never a full wire. Shared InstallationContext and companion banks are counted once by Placement; Workpieces borrows them. All scratch drops before original Budget release.",
        "runtime_qualified": False}
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
