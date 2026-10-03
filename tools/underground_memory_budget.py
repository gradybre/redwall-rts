#!/usr/bin/env python3
"""Source-derived joint underground allocation pack; logical admission, never measured RAM."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

import audit_registry_capacities as audit

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/planning/underground_memory_pack.json"
WIDTHS = {"PackedByteArray": 1, "PackedInt32Array": 4, "PackedInt64Array": 8}


def resolve(index: dict, module: str, expression: str, configuration: dict | None = None) -> int:
    """Resolve source constants after substituting only explicitly selected constructor inputs."""
    for key, value in (configuration or {}).items():
        assert type(value) is int and value > 0, (key, value)
        expression = re.sub(r"\b" + re.escape(key) + r"\b", str(value), expression)
    result = audit.resolve_expression(index, module, expression)
    assert isinstance(result, audit.Proved), (module, expression, result)
    return result.value


def columns(index: dict, module: str, count: int, configuration: dict,
            members: set | None = None) -> dict:
    """Every selected real column needs its own unambiguous source resize and integer width."""
    actual = dict(re.findall(r"^var (_[A-Za-z0-9_]+): (Packed[A-Za-z0-9]+Array)\b", index[module].text, re.M))
    if members is None:
        assert len(actual) == count, (module, "unreconciled packed column", len(actual), count)
        members = set(actual)
    assert len(members) == count and members <= actual.keys(), module
    rows = {}
    for name in sorted(members):
        binding = audit.resize_binding(index, module, name)
        assert isinstance(binding, audit.Binding), (module, name, binding)
        kind = actual[name]
        capacity = resolve(index, module, binding.expression, configuration)
        rows[name] = {"width": WIDTHS[kind], "capacity": capacity,
                      "bytes": WIDTHS[kind] * capacity,
                      "resize_expression": binding.expression, "line": binding.line}
    return rows


def payload(rows: dict) -> int:
    return sum(row["bytes"] for row in rows.values())


def quote_payload(index: dict) -> dict:
    """Resolve every nested Quote buffer and find its three real retained consumers."""
    source = index["modular_project_contract"].text
    quote = source.split("class Quote extends RefCounted:", 1)[1].split("\nclass ", 1)[0]
    declarations = dict(re.findall(r"^\tvar (\w+): (Packed\w+Array)\b", quote, re.M))
    assert len(declarations) == 8, "unreconciled nested Quote column"
    rows = {}
    for name, kind in declarations.items():
        resizes = re.findall(r"^\t\t" + re.escape(name) + r"\.resize\(([^)]+)\)$", quote, re.M)
        assert len(resizes) == 1, (name, "ambiguous Quote allocation", resizes)
        capacity = resolve(index, "modular_project_contract", resizes[0])
        rows[name] = {"width": WIDTHS[kind], "capacity": capacity,
                      "bytes": WIDTHS[kind] * capacity, "resize_expression": resizes[0]}
    integers = re.findall(r"^\tvar \w+: int\b", quote, re.M)
    refs = re.findall(r"^\tvar \w+: Vector2i\b", quote, re.M)
    assert len(integers) == 8 and len(refs) == 1, "unreconciled Quote numeric control"
    consumers = []
    for name, module in index.items():
        for member in re.findall(r"^var (\w+): (?:ModularContract\.)?Quote = (?:ModularContract\.)?Quote.new\(\)$", module.text, re.M):
            consumers.append((name, member))
    assert sorted(consumers) == [("construction", "_modular_quote"), ("excavation_inventory", "_quote"),
                                 ("modular_projects", "_quote")], consumers
    assert payload(rows) == 112, "Quote dimensions or widths changed"
    return {"columns": rows, "numeric_control_bytes": len(integers) * 8 + len(refs) * 8,
            "consumers": sorted(consumers)}


def build(index: dict | None = None) -> dict:
    index = audit.load_source_index() if index is None else index
    budget = index["underground_budget"]
    keys = ("REGION_CAPACITY", "SOURCE_CAPACITY", "PROOF_CAPACITY", "PHASE_VOLUME_CAPACITY",
            "TIP_CAPACITY", "LAYOUT_ROOM_CAPACITY", "LAYOUT_PLACEMENT_CAPACITY",
            "LOCATION_CAPACITY", "INVENTORY_ENDPOINT_CAPACITY")
    pack = {key: resolve(index, budget.name, key) for key in keys}
    r, o, p, k, t, rooms, placements, locations, endpoints = pack.values()
    assert 0 < o <= r <= k <= 16384 and p <= 256 and locations <= 1024 and endpoints <= 1024
    groups = {
        "underground_space_owner": columns(index, "underground_space_owner", 68,
                                          {"_region_capacity": r, "_source_capacity": o}),
        "underground_space_authority": columns(index, "underground_space_authority", 7, {"_capacity": p}),
        "spoil_tips": columns(index, "spoil_tips", 16, {"_capacity": t}),
        "room_layout": columns(index, "room_layout", 13,
                               {"_room_capacity": rooms, "_placement_capacity": placements}),
        "modular_projects": columns(index, "modular_projects", 5, {}),
    }
    endpoint_members = {"_spatial_container_slot", "_spatial_container_generation",
                        "_spatial_location_slot", "_spatial_location_generation",
                        "_spatial_location_revision"}
    endpoint_actual = set(re.findall(r"^var (_spatial_\w+): Packed\w+Array\b", index["inventory"].text, re.M))
    assert endpoint_actual == endpoint_members, "unreconciled spatial endpoint column"
    groups["inventory_spatial"] = columns(index, "inventory", 5, {"capacity": endpoints}, endpoint_members)
    assert payload(groups["underground_space_owner"]) == 149 * r + 92 * o + 288
    assert payload(groups["underground_space_authority"]) == 69 * p + 60
    assert payload(groups["spoil_tips"]) == 107 * t + 65536
    assert payload(groups["room_layout"]) == 13 * rooms + 33 * placements
    assert payload(groups["modular_projects"]) == 131072 + 32
    assert payload(groups["inventory_spatial"]) == 24 * endpoints
    assert resolve(index, budget.name, "SPACE_BANK_BYTES") == payload(groups["underground_space_owner"])
    assert resolve(index, budget.name, "SPACE_WIRE_BYTES") == 68 * r + 42 * o + 144
    assert resolve(index, budget.name, "PROOF_BYTES") == payload(groups["underground_space_authority"])
    assert "return 120 * volume_limit + 32 * source_capacity + COLD_BOX_SCRATCH_BYTES" in index["underground_space_authority"].text
    assert resolve(index, budget.name, "COLD_BYTES") == 120 * k + 32 * o + 384
    loss = columns(index, "excavation_inventory", 1, {}, {"_lost_milli"})
    assert payload(loss) == 768 * 8
    quote = quote_payload(index)
    reserve_names = ("LOCATION_AND_TOPOLOGY_BYTES", "INVENTORY_EXTENSION_BYTES", "PROFILE_BYTES",
                     "TERRAIN_BYTES", "LAYOUT_COLD_BYTES", "BINDINGS_AND_GROWTH_BYTES")
    reserves = {key: resolve(index, budget.name, key) for key in reserve_names}
    assert 56 * endpoints <= reserves["INVENTORY_EXTENSION_BYTES"], "endpoint live/raw/conversion exceeds reserve"
    assert 228 * locations + 256 + 106 * locations + 128 <= reserves["LOCATION_AND_TOPOLOGY_BYTES"]
    contributions = {
        "space_banks_and_indexes": payload(groups["underground_space_owner"]),
        "phase_proof_cache_and_candidate": payload(groups["underground_space_authority"]),
        "shared_geometry_cold_peak": resolve(index, budget.name, "COLD_BYTES"),
        "space_known_numeric_controls": 221 + 176 + 9 + 280,
        "tips_live_and_cold_image_peak": payload(groups["spoil_tips"]) + 48 + 119 * t,
        "layout_retained_columns": payload(groups["room_layout"]),
        "shared_router_and_funding_increment": 2 * (payload(loss) - 256 * 8)
            + len(quote["consumers"]) * (payload(quote["columns"]) + quote["numeric_control_bytes"])
            + 2 * 131072 + 32 + 67 + 16,
        **reserves,
    }
    assert contributions["shared_router_and_funding_increment"] == 271003
    registry = json.loads((ROOT / "docs/planning/canonical_state_registry.json").read_text())
    owners = registry["owners"]
    fields = [field for owner in owners for field in owner["fields"]]
    keys_bytes = sum(len(owner["owner_key"].encode()) for owner in owners) + sum(len(field["field_key"].encode()) for field in fields)
    declaration = len(owners) * 16 + len(fields) * 15 + keys_bytes
    added = sum(contributions.values())
    total = 86601769 + added + declaration - 21185 + 8388608
    assert total < 100000000, ("joint pack exceeds unchanged memory limit", total)
    sources = set(groups) - {"inventory_spatial"}
    sources.update(("inventory", "excavation_inventory", "construction", "modular_project_contract", "underground_budget"))
    return {"schema": 1, "scope": "source-derived logical allocation pack; runtime qualification remains open",
            "runtime_qualified": False, "pack": pack, "columns": groups, "quote": quote,
            "contributions": contributions, "new_mutable_and_reserved_bytes": added,
            "declaration_bytes": declaration, "declaration_delta_bytes": declaration - 21185,
            "live_with_reserve_bytes": total, "headroom_bytes": 100000000 - total,
            "source_sha256": {index[name].relative_path: index[name].sha256 for name in sorted(sources)},
            "registry_sha256": hashlib.sha256((ROOT / "docs/planning/canonical_state_registry.json").read_bytes()).hexdigest(),
            "limitations": ["Constructor limits alone are not joint runtime admission.",
                            "Actual consumers must share the exact cold arena and charge nested coexistence before allocating.",
                            "Location/topology, profile, terrain, layout cold work and binding/native growth envelopes are reserved, not measured or implemented by this checker.",
                            "All native headers, Variant/Array capacity growth, restored copies and omitted future fields must fit measured reserves before activation.",
                            "Physical phase, generic three-survey validation and wire capture are mutually exclusive cold operations unless their combined actual charge fits."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = build()
    rendered = json.dumps(result, indent=2) + "\n"
    if args.check:
        assert OUTPUT.read_text() == rendered, "underground memory pack artifact drift"
    else:
        OUTPUT.write_text(rendered)
    print(json.dumps({key: result[key] for key in ("scope", "new_mutable_and_reserved_bytes", "declaration_bytes",
                                                  "live_with_reserve_bytes", "headroom_bytes", "runtime_qualified")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
