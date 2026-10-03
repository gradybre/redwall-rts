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


def furniture_bridge(index: dict) -> tuple[set[str], dict]:
    """Separate four exact lease-bound observations from the unchanged permanent SpaceOwner banks."""
    source = index["underground_space_owner"].text
    declarations = dict(re.findall(r"^var (_[A-Za-z0-9_]+): (Packed[A-Za-z0-9]+Array)\b", source, re.M))
    transient = {"_furniture_input_entries", "_furniture_pins", "_furniture_entries", "_furniture_rows"}
    assert len(declarations) == 72 and transient <= declarations.keys(), "unreconciled SpaceOwner column"
    assert all(declarations[name] == "PackedInt32Array" for name in transient), "furniture bridge width drift"
    pin = source.split("func _pin_furniture_packet(", 1)[1].split("\n\nfunc ", 1)[0]
    clear = source.split("func _clear_furniture_admissions()", 1)[1].split("\n\nfunc ", 1)[0]
    expected = ("_furniture_input_entries = entries", "_furniture_pins.resize(candidates.count * 5)",
                "_furniture_entries = entries.duplicate()", "_furniture_rows.resize(_furniture_count)",
                "_furniture_count = candidates.count / 2")
    assert all(line in pin for line in expected), "furniture bridge copy or cardinality drift"
    assert "_furniture_input_entries = entries.duplicate()" not in pin, "unaccounted copied input observation"
    assert all(f"{name} = PackedInt32Array()" in clear for name in transient), "unreleased furniture image"
    assert "return 60 * pair_count + 16 if pair_count > 0 and pair_count <= MAX_REGIONS else 0" in source
    return set(declarations) - transient, {
        "members": sorted(transient), "private_bytes_per_pair": 60, "numeric_control_bytes": 16,
        "borrowed_entry_bytes_per_pair": 16,
        "scope": "Exact shared cold lease only; borrowed input is owned by the caller's separately charged packet.",
    }


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


def connector_assembly_reservation(index: dict) -> dict:
    """Count the complete immutable grouping bank and its fixed scratch in the existing reserve."""
    module = "underground_connector_assemblies"
    capacity = resolve(index, module, "MAX_GROUPS")
    rows = columns(index, module, 8, {"_capacity": capacity})
    bank = resolve(index, module, "GROUP_BYTES") * capacity + resolve(index, module, "BANK_HEADER_BYTES")
    fixed = resolve(index, module, "FIXED_BYTES")
    assert payload(rows) == bank + 68, "assembly bank or fixed packed scratch drift"
    assert bank == 16 * capacity + 152 and fixed == 512, "assembly frame/storage contract drift"
    return {"columns": rows, "group_capacity": capacity, "bank_bytes": bank,
            "fixed_bytes": fixed, "reserved_bytes": bank + fixed}


def numeric_fields(source: str, indent: str) -> int:
    """Count concrete numeric declarations; actual object references require separate native measurement."""
    widths = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
    kinds = re.findall(r"^" + re.escape(indent) + r"var \w+: (int|bool|Vector2i|Vector3i)\b", source, re.M)
    return sum(widths[kind] for kind in kinds)


def class_body(source: str, name: str) -> str:
    """Limit packet fields to the named indented class, excluding later top-level function locals."""
    tail = source.split("class " + name + " extends RefCounted:\n", 1)[1]
    lines = []
    for line in tail.splitlines():
        if line.strip() and not line.startswith(("\t", " ")):
            break
        lines.append(line)
    return "\n".join(lines)


def anchor_packet_bytes(source: str, expected: dict, member: str, allocator: str) -> int:
    """Reject extra/wider nested storage before counting each concretely reused six-coordinate box."""
    actual = dict(re.findall(r"^\tvar (\w+): (Packed\w+Array)\b", source, re.M))
    assert actual == expected, (member, "unreconciled anchor packet storage", actual)
    fields = dict(re.findall(r"^\tvar (\w+): ([\w.]+)\b", source, re.M))
    assert all(kind in {"int", "bool", "Vector2i", "Vector3i", "StringName"} or name in expected
               for name, kind in fields.items()), (member, "unreconciled packet field", fields)
    total = numeric_fields(source, "\t")
    for name, kind in actual.items():
        expression = re.escape(member + "." + name) + r"\.resize\(([^)]+)\)"
        assert re.findall(expression, allocator) == ["6"], (member, name)
        total += WIDTHS[kind] * 6
    return total


def anchor_owned_packets(source: str) -> None:
    """Census every nonnumeric member, regardless of initializer, allocation location or trailing comment."""
    expected = {
        "_world": "World", "_terrain": "Terrain", "_space": "Owner", "_sources": "Owner.CoreSources",
        "_locations": "Locations", "_routes": "Routes", "_budget": "Budget", "_ids": "Directory",
        "_buildings": "Routes.Buildings", "_construction": "Owner.Construction", "_inventory": "Routes.Inventory",
        "_transforms": "Routes.Transforms", "_residents": "Routes.Residents", "_jobs": "Routes.Jobs",
        "_work": "Routes.Work", "_profiles": "Routes.Profiles", "_bindings": "Routes.Bindings",
        "_gear": "Routes.Gear", "_carry": "Routes.Carry", "_reservations": "Routes.Reservations",
        "_piles": "Routes.Piles", "_record": "Locations.Record", "_region": "Owner.Region",
    }
    declarations = re.findall(r"^var (\w+): ([\w.]+)\b", source, re.M)
    actual = {name: kind for name, kind in declarations if kind not in {"int", "bool", "Vector2i", "Vector3i"}}
    assert actual == expected, ("unreconciled anchor owned/borrowed member", actual)


def surface_anchor_reservation(index: dict) -> dict:
    """Reconcile actual fixed provider/packet numerics and their three admitted reused packed boxes."""
    module = "underground_surface_anchor"
    source = index[module].text
    assert not re.search(r"^var \w+: Packed", source, re.M), "unreconciled surface anchor column"
    anchor_owned_packets(source)
    retained = re.findall(r"^var (\w+): [\w.]+ = ([\w.]+)\.new\(\)$", source, re.M)
    assert retained == [("_record", "Locations.Record"), ("_region", "Owner.Region")], retained
    record = class_body(index["underground_locations"].text, "Record")
    region = class_body(index["underground_space_owner"].text, "Region")
    result = class_body(source, "Result")
    controls = numeric_fields(source, "")
    packets = anchor_packet_bytes(record, {"envelope": "PackedInt32Array", "support": "PackedInt32Array"}, "_record", source)
    packets += anchor_packet_bytes(region, {"box": "PackedInt32Array"}, "_region", source)
    packets += anchor_packet_bytes(result, {}, "Result", source)
    reserved = resolve(index, module, "RESERVED_BYTES")
    assert reserved >= controls + packets + 1024, "surface anchor fixed frame allowance insufficient"
    return {"numeric_control_bytes": controls, "packet_bytes": packets,
            "fixed_numeric_and_packed_bytes": controls + packets, "reserved_bytes": reserved,
            "logical_helper_allowance_bytes": 1024,
            "scope": "Fixed composition references and native overhead remain unmeasured; no independent authoritative bank."}


def connector_recipe_reservation(index: dict, binding_reserve: int) -> dict:
    """Count the exact immutable recipe bank inside, not in addition to, the shared binding reserve."""
    # The shared audit parser intentionally keeps inline comments. Strip comments
    # only from integer arithmetic declarations in these two local read views;
    # original source hashes remain in the returned whole-pack provenance.
    index = dict(index)
    for name in ("underground_connector_catalog", "underground_world_routes"):
        source = index[name]
        clean = re.sub(r"(?m)^(const [A-Z][A-Z0-9_]*: int = [A-Z0-9_ .+*()-]+?)[ \t]+#.*$",
                       r"\1", source.text)
        # Expand this exact authored product into the audit's sums-of-products
        # grammar; other parentheses/operators continue to fail closed.
        if name == "underground_world_routes":
            clean = re.sub(
                r"(?m)^const CERTIFICATE_BYTES: int = 2 \* EDGE_CAPACITY \* \(MASK_BYTES \+ 4 \+ 16\)$",
                "const CERTIFICATE_BYTES: int = 2 * EDGE_CAPACITY * MASK_BYTES + 2 * EDGE_CAPACITY * 4 + 2 * EDGE_CAPACITY * 16",
                clean)
        index[name] = audit.parse_module(name, source.relative_path, clean)
    module = "underground_connector_recipes"
    capacity = resolve(index, module, "MAX_PARTS")
    inputs = capacity * resolve(index, "modular_project_contract", "INPUT_CAPACITY")
    rows = columns(index, module, 9, {"_capacity": capacity, "_input_capacity": inputs})
    bank = resolve(index, module, "PART_BYTES") * capacity + resolve(index, module, "BANK_HEADER_BYTES")
    fixed = resolve(index, module, "FIXED_BYTES")
    assert payload(rows) == bank + 68, "recipe bank or fixed packed scratch drift"
    assert bank == 64 * capacity + 128 and fixed == 512, "recipe frame/storage contract drift"
    assemblies = connector_assembly_reservation(index)
    anchor = surface_anchor_reservation(index)
    consumers = {
        "connector_catalog": resolve(index, "underground_connector_catalog", "RESERVED_BYTES"),
        "world_routes": resolve(index, "underground_world_routes", "RESERVED_BYTES"),
        "connector_recipes": bank + fixed,
        "connector_assemblies": assemblies["reserved_bytes"],
        "surface_anchor": anchor["reserved_bytes"],
    }
    used = sum(consumers.values())
    assert used <= binding_reserve, "known binding consumers exceed their shared reserve"
    return {"columns": rows, "part_capacity": capacity, "bank_bytes": bank,
            "fixed_bytes": fixed, "assembly_reservation": assemblies, "surface_anchor_reservation": anchor,
            "known_binding_consumers": consumers,
            "known_binding_used_bytes": used,
            "remaining_binding_reserve_bytes": binding_reserve - used,
            "scope": "Known logical consumers only; actual placement, other controls and native growth still require joint admission."}


def build(index: dict | None = None) -> dict:
    index = audit.load_source_index() if index is None else index
    budget = index["underground_budget"]
    keys = ("REGION_CAPACITY", "SOURCE_CAPACITY", "PROOF_CAPACITY", "PHASE_VOLUME_CAPACITY",
            "TIP_CAPACITY", "LAYOUT_ROOM_CAPACITY", "LAYOUT_PLACEMENT_CAPACITY",
            "LOCATION_CAPACITY", "INVENTORY_ENDPOINT_CAPACITY")
    pack = {key: resolve(index, budget.name, key) for key in keys}
    r, o, p, k, t, rooms, placements, locations, endpoints = pack.values()
    assert 0 < o <= r <= k <= 16384 and p <= 256 and locations <= 1024 and endpoints <= 1024
    owner_members, bridge = furniture_bridge(index)
    groups = {
        "underground_space_owner": columns(index, "underground_space_owner", 68,
                                          {"_region_capacity": r, "_source_capacity": o}, owner_members),
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
    assert payload(loss) == 1024 * 8 # Decision1102: four historical purpose domains.
    quote = quote_payload(index)
    reserve_names = ("LOCATION_AND_TOPOLOGY_BYTES", "INVENTORY_EXTENSION_BYTES", "PROFILE_BYTES",
                     "TERRAIN_BYTES", "LAYOUT_COLD_BYTES", "BINDINGS_AND_GROWTH_BYTES")
    reserves = {key: resolve(index, budget.name, key) for key in reserve_names}
    recipes = connector_recipe_reservation(index, reserves["BINDINGS_AND_GROWTH_BYTES"])
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
    assert contributions["shared_router_and_funding_increment"] == 275099
    registry = json.loads((ROOT / "docs/planning/canonical_state_registry.json").read_text())
    owners = registry["owners"]
    fields = [field for owner in owners for field in owner["fields"]]
    keys_bytes = sum(len(owner["owner_key"].encode()) for owner in owners) + sum(len(field["field_key"].encode()) for field in fields)
    declaration = len(owners) * 16 + len(fields) * 15 + keys_bytes
    added = sum(contributions.values())
    total = 86601769 + added + declaration - 21185 + 8388608
    assert total < 100000000, ("joint pack exceeds unchanged memory limit", total)
    sources = set(groups) - {"inventory_spatial"}
    sources.update(("inventory", "excavation_inventory", "construction", "modular_project_contract", "underground_budget",
                    "underground_connector_recipes", "underground_connector_catalog", "underground_world_routes",
                    "underground_connector_assemblies", "underground_surface_anchor", "underground_locations"))
    return {"schema": 1, "scope": "source-derived logical allocation pack; runtime qualification remains open",
            "runtime_qualified": False, "pack": pack, "columns": groups, "quote": quote,
            "furniture_bridge_cold": bridge, "connector_recipe_reservation": recipes,
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
