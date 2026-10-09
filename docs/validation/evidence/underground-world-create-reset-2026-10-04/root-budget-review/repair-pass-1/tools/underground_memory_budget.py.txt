#!/usr/bin/env python3
"""Source-derived joint underground allocation pack; logical admission, never measured RAM."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re

import audit_registry_capacities as audit
import underground_motion_memory as motion_memory
import underground_session_memory as session_memory
import underground_motion_clock_memory as clock_memory
import underground_retirement_memory as retirement_memory
import underground_approach_memory as approach_memory
import underground_ui_reset_memory as ui_reset_memory

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


def class_body(source: str, name: str, parent: str = "RefCounted") -> str:
    """Limit packet fields to the named indented class, excluding later top-level function locals."""
    declaration = "class " + name + (" extends " + parent if parent else "") + ":\n"
    pieces = source.split(declaration)
    assert len(pieces) == 2, (name, "missing/changed/duplicate class declaration")
    tail = pieces[1]
    lines = []
    for line in tail.splitlines():
        if line.strip() and not line.startswith(("\t", " ")):
            break
        lines.append(line)
    return "\n".join(lines)


def anchor_packet_bytes(source: str, expected: dict, member: str, allocator: str) -> int:
    """Reject extra/wider nested storage before counting each concretely reused six-coordinate box."""
    fields = explicit_members(source, "\t")
    actual = {key: kind for key, kind in fields.items() if kind.startswith("Packed")}
    assert actual == expected, (member, "unreconciled anchor packet storage", actual)
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
        "_surface_box": "PackedInt32Array",
    }
    declarations = explicit_members(source)
    actual = {name: kind for name, kind in declarations.items() if kind not in {"int", "bool", "Vector2i", "Vector3i"}}
    assert actual == expected, ("unreconciled anchor owned/borrowed member", actual)


def surface_anchor_reservation(index: dict) -> dict:
    """Reconcile fixed provider packets and the separately pinned metadata-only surface box."""
    module = "underground_surface_anchor"
    source = index[module].text
    anchor_owned_packets(source)
    assert re.findall(r"_surface_box\.resize\(([^)]+)\)", source) == ["6"], "surface metadata box growth"
    metadata = 6 * 4
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
    assert reserved >= controls + packets + metadata + 1024, "surface anchor fixed frame allowance insufficient"
    return {"numeric_control_bytes": controls, "packet_bytes": packets,
            "surface_metadata_bytes": metadata,
            "fixed_numeric_and_packed_bytes": controls + packets + metadata, "reserved_bytes": reserved,
            "logical_helper_allowance_bytes": 1024,
            "scope": "Fixed composition references and native overhead remain unmeasured; no independent authoritative bank."}


def explicit_members(source: str, indent: str = "") -> dict:
    """Every member, including late-assigned objects, participates in the source census."""
    pattern = r"^" + re.escape(indent) + r"var (\w+): ([\w.]+)\b"
    fields = dict(re.findall(pattern, source, re.M))
    names = re.findall(r"^" + re.escape(indent) + r"var (\w+)\b", source, re.M)
    assert len(names) == len(fields), "untyped or duplicate member in memory census"
    return fields


def scalar_packet(index: dict, module: str, name: str, references: dict | None = None,
                  parent: str = "RefCounted") -> int:
    """Exact reference fields prevent a new collection/object from hiding in a numeric-only packet."""
    source = class_body(index[module].text, name, parent)
    fields = explicit_members(source, "\t")
    allowed = {"int", "bool", "Vector2i", "Vector3i", "StringName"}
    nonnumeric = {key: value for key, value in fields.items() if value not in allowed}
    assert nonnumeric == (references or {}), (module, name, "unreconciled packet member", nonnumeric)
    return numeric_fields(source, "\t")


def placement_reservation(index: dict) -> dict:
    """Charge both concrete Placement banks and the maximum simultaneous fixed packets before allocation."""
    module = "underground_connector_placements"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ["RefCounted"], "unreconciled Placement base"
    p, o = (resolve(index, module, key) for key in ("MAX_PLACEMENTS", "MAX_OPENINGS"))
    bank = class_body(source, "Bank")
    bank_fields = explicit_members(bank, "\t")
    packed = {key: kind for key, kind in bank_fields.items() if kind in WIDTHS}
    assert len(packed) == 10 and {key: value for key, value in bank_fields.items() if key not in packed} == {
        "free_count": "int", "opening_free_count": "int"}, "unreconciled Placement bank"
    rows = {}
    for name, kind in packed.items():
        expressions = re.findall(r"^\t\t" + re.escape(name) + r"\.resize\(([^)]+)\)$", bank, re.M)
        assert len(expressions) == 1, ("Placement bank resize", name, expressions)
        capacity = resolve(index, module, expressions[0], {"placements": p, "targets": o})
        rows[name] = {"width": WIDTHS[kind], "capacity": capacity, "bytes": WIDTHS[kind] * capacity,
                      "resize_expression": expressions[0]}
    assert payload(rows) == 94 * p + 44 * o + 256, "Placement bank declaration/width drift"
    controls = placement_controls(index)
    assert controls["total_bytes"] <= resolve(index, module, "CONTROL_BYTES"), "Placement fixed control ceiling exceeded"
    assert "_marks.resize(placements + openings)" in source and "_stream.resize(width)" in source
    stream = resolve(index, module, "STREAM_BYTES")
    native = resolve(index, module, "NATIVE_BYTES")
    reserved = 2 * payload(rows) + p + o + stream + resolve(index, module, "CONTROL_BYTES") + native
    formula = re.search(r"(?m)^\treturn (189 \* placements \+ 89 \* openings \+ 14848)$", source)
    assert formula is not None and reserved == resolve(index, module, formula[1], {"placements": p, "openings": o}), \
        "Placement constructor does not charge complete lifetime"
    return {"placement_capacity": p, "opening_capacity": o, "bank_columns": rows,
            "two_bank_bytes": 2 * payload(rows), "audit_marks_bytes": p + o, "stream_reserved_bytes": stream,
            "fixed_controls": controls, "control_reserve_bytes": resolve(index, module, "CONTROL_BYTES"),
            "native_reserve_bytes": native, "reserved_bytes": reserved}


def placement_controls(index: dict) -> dict:
    """Count actual retained packets and the deliberately conservative shared caller/frame overlap."""
    module = "underground_connector_placements"
    source = index[module].text
    fields = explicit_members(source)
    numeric = {"int", "bool", "Vector2i", "Vector3i"}
    expected = {"_live": "Bank", "_stage": "Bank", "_marks": "PackedByteArray", "_stream": "PackedByteArray",
        "_request": "Request", "_ids": "Directory", "_buildings": "Buildings", "_construction": "Construction",
        "_space": "Owner", "_locations": "Locations", "_routes": "Routes", "_world_routes": "WorldRoutes",
        "_sources": "Owner.CoreSources", "_inventory": "Inventory", "_transforms": "Transforms",
        "_residents": "Residents", "_jobs": "Jobs", "_work": "Work", "_profiles": "Profiles",
        "_gear": "RefCounted", "_carry": "RefCounted", "_reservations": "RefCounted", "_piles": "RefCounted",
        "_budget": "Budget", "_catalog": "Catalog", "_assemblies": "Assemblies", "_recipes": "Recipes",
        "_authority": "WeakRef", "_publisher": "WeakRef", "_router": "WeakRef", "_paid_owner": "WeakRef",
        "_last_state_hash": "String", "_context": "Locations.InstallationContext",
        "_admission_candidate": "Directory.CreateCandidate", "_admission_context": "Locations.RoomContext",
        "_admission_input": "WeakRef", "_phase_context": "Locations.PhaseContext", "_workpieces": "WeakRef"}
    assert {key: value for key, value in fields.items() if value not in numeric} == expected, \
        "unreconciled Placement owned/borrowed members"
    assert fields.get("_phase_mode") == "bool", "phase companion mode control drift"
    request = scalar_packet(index, module, "Request", {"targets": "PackedInt32Array"})
    target_expr = "4 * Catalog.MAX_OPENINGS_PER_VARIANT"
    assert f"_request.targets.resize({target_expr})" in source
    request += 4 * resolve(index, module, target_expr)
    install_refs = {key: "WeakRef" for key in ("issuer", "router", "paid_owner", "space", "locations")}
    install_refs.update({"construction": "Construction", "budget": "Budget"})
    room_refs = {key: "WeakRef" for key in ("orders", "space", "locations")}
    room_refs["budget"] = "Budget"
    phase_refs = {key: "WeakRef" for key in ("issuer", "authority", "sites", "space", "locations")}
    phase_refs["budget"] = "Budget"
    phase_context = scalar_packet(index, "underground_locations", "PhaseContext", phase_refs)
    assert phase_context == 128, "phase companion numeric packet drift"
    rows = {"owner": numeric_fields(source, ""), "bank_free_counts": 2 * numeric_fields(class_body(source, "Bank"), "\t"),
        "installation_context": scalar_packet(index, "underground_locations", "InstallationContext", install_refs),
        "room_context": scalar_packet(index, "underground_locations", "RoomContext", room_refs),
        "phase_context": phase_context,
        "directory_candidate": scalar_packet(index, "entity_directory", "CreateCandidate", {"_directory": "WeakRef"}),
        "private_and_caller_requests": 2 * request,
        "shared_order_and_assembly_records": scalar_packet(index, module, "OrderRecord") +
            scalar_packet(index, "underground_connector_assemblies", "AssemblyRecord"),
        "returned_result": scalar_packet(index, module, "Result"), "final_digest": 32, "helper_frames": 576}
    return {"components": rows, "total_bytes": sum(rows.values())}


def connector_work_reservation(index: dict, placement: dict) -> dict:
    """The existing shared caller pair is counted once; this adapter adds controls and bounded stack frames."""
    source = index["underground_connector_work"].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ['"res://scripts/core/modular_project_contract.gd".Owner'], \
        "unreconciled ConnectorWork base"
    expected = {"_placements": "Placements", "_construction": "Construction", "_assemblies": "Assemblies",
        "_recipes": "Recipes", "_router": "WeakRef", "_contacts": "WeakRef", "_publication": "Publication",
        "_order": "Placements.OrderRecord", "_assembly": "Assemblies.AssemblyRecord",
        "_stage_contacts": "Contacts", "_cold_budget": "Budget", "_workpieces": "Workpieces"}
    fields = explicit_members(source)
    assert {key: value for key, value in fields.items() if value not in {"int", "bool", "Vector2i", "Vector3i"}} == expected, \
        "unreconciled ConnectorWork owned/borrowed members"
    assert explicit_members(class_body(index["modular_project_contract"].text, "Owner"), "\t") == {}, \
        "unaccounted inherited ConnectorWork member"
    assert explicit_members(class_body(index["underground_connector_placements"].text, "Publisher"), "\t") == {}, \
        "unaccounted inherited Publication member"
    publication = scalar_packet(index, "underground_connector_work", "Publication", {"owner": "WeakRef"}, "Placements.Publisher")
    own = numeric_fields(source, "") + publication
    assert own == 51, "ConnectorWork numeric lifetime drift"
    shared = placement["fixed_controls"]["components"]["shared_order_and_assembly_records"]
    assert shared == 128, "ConnectorWork shared record pair drift"
    return {"additional_numeric_bytes": own, "aliased_record_bytes_already_charged": shared,
            "helper_allowance_bytes": 512, "isolated_numeric_and_helper_bytes": own + shared + 512,
            "reserved_bytes": own + 512}


def connector_workpieces_reservation(index: dict) -> dict:
    """Count both actual rows and the one immutable source bank outside the fully assigned bindings reserve."""
    module = "underground_connector_workpieces"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ["RefCounted"], "unreconciled Workpieces base"
    p = resolve(index, module, "MAX_PLACEMENTS")
    a = resolve(index, module, "MAX_ASSEMBLIES")
    assert p == resolve(index, "underground_connector_placements", "MAX_PLACEMENTS") == 256
    assert a == resolve(index, "underground_connector_catalog", "MAX_PARTS") == 256
    bank = class_body(source, "Bank")
    assert explicit_members(bank, "\t") == {"fields": "PackedInt32Array", "present": "PackedByteArray"}, \
        "unreconciled Workpieces bank member"
    rows = {}
    for name, kind in explicit_members(bank, "\t").items():
        expressions = re.findall(r"^\t\t" + name + r"\.resize\(([^)]+)\)$", bank, re.M)
        assert len(expressions) == 1, ("Workpieces bank allocation", name, expressions)
        count = resolve(index, module, expressions[0], {"capacity": p})
        rows[name] = {"width": WIDTHS[kind], "capacity": count, "bytes": WIDTHS[kind] * count,
                      "resize_expression": expressions[0]}
    assert payload(rows) == p * resolve(index, module, "ROW_BYTES") == 21 * p
    fields = explicit_members(source)
    references = {"_live": "Bank", "_stage": "Bank", "_placements": "RefCounted", "_router": "Router",
                  "_paid_owner": "WeakRef", "_contacts": "WeakRef", "_budget": "Budget", "_catalog": "Catalog",
                  "_assemblies": "Assemblies", "_recipes": "Recipes", "_profiles": "Profiles", "_context": "RefCounted"}
    numeric = {"int", "bool", "Vector2i", "Vector3i"}
    assert {key: kind for key, kind in fields.items() if kind not in numeric and kind not in WIDTHS} == references, \
        "unreconciled Workpieces owned/borrowed member"
    arrays = columns(index, module, 6, {"assemblies": a})
    expected = {"_header": (8, 9), "_digests": (1, 160), "_parts": (4, 6 * a),
                "_profile_revisions": (8, a), "_bounds": (4, 6), "_scratch": (4, 6)}
    assert {key: (row["width"], row["capacity"]) for key, row in arrays.items()} == expected, \
        "Workpieces source or scratch allocation drift"
    for name in arrays:
        assert len(re.findall(re.escape(name) + r"\.resize\(([^)]+)\)", source)) == 1, \
            (name, "ambiguous Workpieces allocation")
    header = arrays["_header"]["bytes"] + arrays["_digests"]["bytes"]
    immutable_rows = arrays["_parts"]["bytes"] + arrays["_profile_revisions"]["bytes"]
    assert header == resolve(index, module, "SOURCE_HEADER_BYTES") == 232
    assert immutable_rows == a * resolve(index, module, "SOURCE_ROW_BYTES") == 32 * a
    fixed = numeric_fields(source, "") + arrays["_bounds"]["bytes"] + arrays["_scratch"]["bytes"]
    controls = resolve(index, module, "CONTROL_BYTES")
    assert fixed == 123 and fixed + 1024 <= controls == 2048, "Workpieces fixed/helper lifetime drift"
    # Only this exact declared integer permits an inline explanation of unmeasured native overhead.
    native_match = re.findall(r"(?m)^const NATIVE_RESERVE: int = ([0-9]+)(?:[ \t]+#.*)?$", source)
    assert native_match == ["8192"], "Workpieces provisional native reservation drift"
    stream = resolve(index, module, "STREAM_BYTES")
    assert stream == 512
    required = ("\treturn 2 * ROW_BYTES * placements + SOURCE_ROW_BYTES * assemblies + SOURCE_HEADER_BYTES \\\n"
                "\t\t+ CONTROL_BYTES + STREAM_BYTES + NATIVE_RESERVE")
    assert required in source, "Workpieces constructor lifetime charge drift"
    admission = "\tif _configured or required == 0 or required > DESIGN_CEILING or arena_bytes != required:"
    assert admission in source, "Workpieces requires exact complete admission"
    assert source.count("\t_live.allocate(placements)") == source.count("\t_stage.allocate(placements)") == 1
    for allocation in ["\t_live.allocate(placements)", "\t_stage.allocate(placements)"] + [
            "\t" + name + ".resize(" for name in arrays]:
        assert source.index(admission) < source.index(allocation), "Workpieces allocates before complete admission"
    reserved = 2 * payload(rows) + header + immutable_rows + controls + stream + int(native_match[0])
    assert reserved == 29928 and reserved <= resolve(index, module, "DESIGN_CEILING") == 32768
    return {"placement_capacity": p, "assembly_capacity": a, "bank_columns": rows,
            "source_and_scratch_columns": arrays, "two_bank_bytes": 2 * payload(rows),
            "immutable_header_bytes": header, "immutable_rows_bytes": immutable_rows,
            "fixed_numeric_and_packed_bytes": fixed, "logical_helper_allowance_bytes": 1024,
            "control_reserve_bytes": controls, "stream_reserved_bytes": stream,
            "native_reserve_bytes": int(native_match[0]), "reserved_bytes": reserved,
            "scope": "Separate explicit joint contribution; source-counted logical admission only. Native memory and composed persistence remain unqualified."}


def haul_transfer_reservation(index: dict) -> dict:
    """Charge Pool's two fixed packets once; Delivery borrows the public view, never another bank."""
    module = "haul_transfer_contract"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ["RefCounted"], "unreconciled hauling protocol base"
    assert not explicit_members(source), "hauling protocol gained retained state"
    assert re.findall(r"(?m)^class (\w+) extends RefCounted:", source) == ["Transfer"], \
        "unreconciled hauling protocol packet"
    fields = explicit_members(class_body(source, "Transfer"), "\t")
    assert len(fields) == 27 and list(fields.values()).count("Vector2i") == 8 \
        and list(fields.values()).count("int") == 19, "hauling transfer declaration drift"
    packet = scalar_packet(index, module, "Transfer")
    assert packet == resolve(index, module, "TRANSFER_BYTES") == 216
    for owner in ("reservations", "inventory"):
        assert re.findall(r"(?m)^extends (.+)$", index[owner].text) == ["RefCounted"], \
            (owner, "unreconciled inherited hauling state")
    pool_source = index["reservations"].text
    pool_fields = explicit_members(pool_source)
    expected = {"_haul_original": "HaulContract.Transfer", "_haul_view": "HaulContract.Transfer",
                "_haul_active": "bool", "_haul_inventory": "Inventory", "_haul_guard": "HaulContract",
                "_haul_error": "StringName"}
    assert {name: kind for name, kind in pool_fields.items() if name.startswith("_haul_")} == expected, \
        "unreconciled hauling scope member"
    assert {name for name, kind in pool_fields.items() if kind == "HaulContract.Transfer"} == {
        "_haul_original", "_haul_view"}, "unaccounted retained hauling packet"
    assert pool_source.count("HaulContract.Transfer.new()") == 2, "hauling packet allocation drift"
    assert not any(name.startswith("_haul_") for name in explicit_members(index["inventory"].text)), \
        "unreconciled Inventory hauling state"
    fixed = 2 * packet + 1
    assert fixed == 433 and fixed <= 512
    # ADR1141's reviewed complete lower-owner call graph peaks at466 logical bytes.
    # The512 helper and2048 native allowances stay reserved, not certified by this field census.
    return {"packet_fields": fields, "packet_bytes": packet, "retained_packets": 2,
            "pool_scope_members": expected, "fixed_numeric_bytes": fixed,
            "control_reserve_bytes": 512, "logical_helper_allowance_bytes": 512,
            "native_reserve_bytes": 2048, "reserved_bytes": 3072,
            "scope": "Separate ADR1141 per-world contribution; borrowed Delivery view already counted here. Source census and native allowances do not qualify runtime memory."}


def connector_delivery_allocation_statements(source: str, arrays: dict, packets: dict) -> None:
    """Freeze the reviewed allocation entry, statements and growth vocabulary, including locals."""
    lines = []
    for raw in source.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith('"""'):
            assert line.count('"""') == 2 and line.endswith('"""'), "Delivery ambiguous docstring"
            continue
        lines.append(line)
    executable = "\n".join(lines)
    assert re.findall(r"\b_allocate\b", executable) == ["_allocate", "_allocate"], \
        "Delivery allocation entry gained another reference or call"
    configure = source.split("func configure(", 1)[1].split("\n\nfunc _allocate()", 1)[0]
    configure_lines = [line.strip() for line in configure.splitlines()
                       if line.strip() and not line.strip().startswith('"""')]
    assert configure_lines == [
        "placements: Placements, frontier: Frontier, planner: Planner,",
        "provider: WorldRoutes, work: RefCounted, clock: Clock, reserved_bytes: int) -> StringName:",
        "if _configured or _placements != null or reserved_bytes != RESERVED_BYTES or placements == null \\",
        "or frontier == null or planner == null or provider == null or work == null or clock == null:",
        "return REFUSE_BINDING", "_placements = placements", "_frontier = frontier", "_planner = planner",
        "_provider = provider", "_work = work", "_clock = clock", "var code: StringName = _binding_leaf(self)",
        'if code == &"": code = work.bind_spatial_delivery(self)', 'if code != &"":',
        "_placements = null; _frontier = null; _planner = null; _provider = null; _work = null; _clock = null",
        "return code", "_allocate()", "_configured = true", 'return &""',
    ], "Delivery allocation admission/order changed"
    allocations = [f"{name} = {kind}.new()" for name, kind in packets.items()]
    allocations += [f"{name}.resize({count})" for name, count in arrays.items()]
    allocations += ["_location.envelope.resize(6)", "_location.support.resize(6)"]
    body = executable.split("func _allocate() -> void:\n", 1)[1].split("\nstatic func ", 1)[0]
    assert body.splitlines() == allocations, "Delivery allocator has unreviewed statements"
    # Inventory result packets are the five existing helper/result sites. All other
    # constructors, copies, collection literals and growth operations require review.
    allocating = re.compile(r"\.\s*(?:new|resize|append|append_array|push_back|push_front|insert|assign|"
                            r"duplicate|slice|map|filter|split|split_floats|to_byte_array)\s*\(|"
                            r"\b(?:Packed\w+Array|Array|Dictionary|range)\s*\(")
    actual = [line for line in lines if allocating.search(line)]
    expected = [f"var {name}: PackedInt32Array = PackedInt32Array()" for name in arrays] + allocations
    expected += ['return result if result != null else Inventory.OpResult.new(false, code, NULL_REF, 0)']
    expected += ['if code != &"": return Inventory.OpResult.new(false, code, NULL_REF, 0)'] * 4
    expected += ["for z: int in range(first_z, last_z + 1):", "for x: int in range(first_x, last_x + 1):"]
    assert actual == expected, "Delivery allocation/copy/growth sites changed"
    assert not re.search(r"(?:[=+,(]|\b(?:return|in)\b)\s*[\[{]", executable), \
        "Delivery gained an unreviewed collection literal"


def connector_delivery_reservation(index: dict) -> dict:
    """Count the complete fixed Delivery packet; its borrowed Transfer belongs only to ADR1141."""
    module = "underground_connector_delivery"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ['"res://scripts/core/haul_transfer_contract.gd"'], \
        "unreconciled Delivery base"
    arrays = {"_frame": 9, "_install": 9, "_endpoint": 7, "_bounds": 6, "_support": 6, "_remaining": 1}
    references = {"_placements": "Placements", "_frontier": "Frontier", "_planner": "Planner",
                  "_provider": "WorldRoutes", "_work": "RefCounted", "_clock": "Clock"}
    packets = {"_order": "Placements.OrderRecord", "_selection": "Profiles.Selection",
               "_location": "Locations.Record", "_box": "Profiles.Box", "_number": "IntMath.IntResult"}
    numbers = dict.fromkeys(("_decision_tick", "_action", "_quantity", "_grams", "_expiry",
                            "_geometry_revision", "_frontier_revision", "_location_receipt",
                            "_route_receipt", "_job_remaining", "_job_state", "_claim_row", "_checks"), "int")
    numbers.update(dict.fromkeys(("_configured", "_busy", "_poisoned", "_work_tick"), "bool"))
    numbers.update(dict.fromkeys(("_job", "_worker", "_project", "_placement", "_source_lot",
                                 "_source_container", "_destination", "_source_location",
                                 "_destination_location"), "Vector2i"))
    expected = {**references, **packets, **numbers, **dict.fromkeys(arrays, "PackedInt32Array")}
    assert explicit_members(source) == expected, "unreconciled Delivery retained member"
    resizes = re.findall(r"(?m)^\t([\w.]+)\.resize\(([^\n]+)\)$", source)
    expected_resizes = {**{name: str(count) for name, count in arrays.items()},
                        "_location.envelope": "6", "_location.support": "6"}
    assert len(resizes) == len(expected_resizes) and dict(resizes) == expected_resizes, \
        "Delivery packed allocation drift"
    for name, kind in packets.items():
        assert source.count(f"{name} = {kind}.new()") == 1, "Delivery packet allocation drift"
    connector_delivery_allocation_statements(source, arrays, packets)
    packet_bytes = {
        "order": scalar_packet(index, "underground_connector_placements", "OrderRecord"),
        "selection": scalar_packet(index, "underground_profiles", "Selection"),
        "location": scalar_packet(index, "underground_locations", "Record",
                                  {"envelope": "PackedInt32Array", "support": "PackedInt32Array"}) + 48,
        "box": scalar_packet(index, "underground_profiles", "Box"),
        "number": scalar_packet(index, "int_math", "IntResult", {"error": "String"}, parent=""),
    }
    assert packet_bytes == {"order": 96, "selection": 168, "location": 116, "box": 32, "number": 9}
    fixed = numeric_fields(source, "") + 4 * sum(arrays.values()) + sum(packet_bytes.values())
    assert fixed == 753
    work_source = index["work"].text
    planner_source = index["haul_planner"].text
    for owner in ("work", "haul_planner"):
        assert re.findall(r"(?m)^extends (.+)$", index[owner].text) == ["RefCounted"], \
            (owner, "unreconciled inherited Delivery state")
    work_bindings = {"_delivery_script": "Script", "_spatial_delivery": "WeakRef", "_handling_tick": "bool"}
    assert {name: kind for name, kind in explicit_members(work_source).items()
            if name.startswith(("_delivery_", "_spatial_delivery", "_handling_"))} == work_bindings, \
        "unreconciled Work Delivery binding"
    planner_fields = {"_inventory": "InventoryScript", "_reservations": "ReservationsScript",
                      "_residents": "ResidentsScript", "_buildings": "BuildingsScript",
                      "_piles": "GroundPilesScript", "_store_policy": "StorePolicyScript",
                      "_job_generation": "PackedInt32Array", "_dest_slot": "PackedInt32Array",
                      "_dest_generation": "PackedInt32Array", "_dest_tile": "PackedInt32Array",
                      "_reserved_g": "PackedInt64Array", "_footprint": "PackedByteArray",
                      "_outside": "PackedByteArray", "_seeds": "PackedInt32Array",
                      "_seed_count": "int", "_spec": "PackedInt64Array", "_claim": "PackedInt64Array",
                      "_one_seed": "PackedInt32Array", "_math": "IntMath.IntResult",
                      "_place": "GroundPilesScript.PlaceResult", "_chosen": "Destination"}
    assert explicit_members(planner_source) == planner_fields, "unreconciled Planner retained member"
    helper = resolve(index, module, "HELPER_BYTES")
    native_values = re.findall(r"(?m)^const NATIVE_RESERVE: int = ([0-9]+)(?:[ \t]+#[^\n]*)?$", source)
    assert len(native_values) == 1, "Delivery native reservation declaration drift"
    native = int(native_values[0])
    reserved = resolve(index, module, "RESERVED_BYTES")
    assert (helper, native, reserved) == (1024, 2048, 4096)
    assert fixed + 1 + helper + native == 3826 and fixed + 1 + helper + native <= reserved
    return {"retained_members": expected, "packed_cells": arrays, "packet_bytes": packet_bytes,
            "fixed_numeric_and_packed_bytes": fixed, "work_new_numeric_bytes": 1,
            "work_bindings": work_bindings, "logical_helper_allowance_bytes": helper,
            "native_reserve_bytes": native, "declared_bytes": fixed + 1 + helper + native,
            "reserved_bytes": reserved,
            "scope": "Separate ADR1140 per-world contribution. Reviewed coupled logical helper census817 fits1024; the borrowed216-byte Transfer is already charged in1141. No new gameplay bank; runtime memory remains unqualified."}


def entry_frontier_reservation(index: dict) -> dict:
    """Reserve the reader's whole admitted ceiling and reject drift between each wire row and its packed bank."""
    module = "underground_entry_frontier"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ["RefCounted"], "unreconciled Frontier base"
    expected = {
        "_capacities": ("PackedInt32Array", "TABLE_COUNT"),
        "_header": ("PackedInt64Array", "HEADER_FIELDS"),
        "_digests": ("PackedByteArray", "DIGEST_BYTES"),
        "_install": ("PackedInt32Array", "9 * _capacities[INSTALL]"),
        "_station": ("PackedInt32Array", "9 * _capacities[STATION]"),
        "_profile_revision": ("PackedInt64Array", "4 * _capacities[STATION]"),
        "_rotation_profile": ("PackedInt32Array", "3 * _capacities[STATION]"),
        "_cut": ("PackedInt32Array", "7 * _capacities[CUT]"),
        "_bearing": ("PackedInt32Array", "9 * _capacities[BEARING]"),
        "_endpoint": ("PackedInt32Array", "7 * _capacities[ENDPOINT]"),
        "_travel_profile": ("PackedInt32Array", "_capacities[ENDPOINT]"),
        "_travel_revision": ("PackedInt64Array", "_capacities[ENDPOINT]"),
        "_episode": ("PackedInt32Array", "19 * _capacities[EPISODE]"),
    }
    fields = explicit_members(source)
    assert {k: v for k, v in fields.items() if v in WIDTHS} == {k: v[0] for k, v in expected.items()}, \
        "unreconciled Frontier packed members"
    assert {k: v for k, v in fields.items() if v not in WIDTHS} == {
        "_catalog": "Catalog", "_assemblies": "Assemblies", "_recipes": "Recipes", "_profiles": "Profiles",
        "_configured": "bool", "_loaded": "bool", "_busy": "bool"}, "unreconciled Frontier controls"
    for name, (_, count) in expected.items():
        assert re.findall(re.escape(name) + r"\.resize\(([^)]+)\)", source) == [count], (name, "Frontier resize drift")
    assert [resolve(index, module, n) for n in ("TABLE_COUNT", "HEADER_FIELDS", "DIGEST_BYTES", "FIXED_BYTES")] == [6, 14, 160, 2048]
    assert "return row_fields(table) * 4 + (44 if table == STATION else (12 if table == ENDPOINT else 0))" in source
    assert "INSTALL, STATION, BEARING:\n\t\t\treturn 9" in source and "CUT, ENDPOINT:\n\t\t\treturn 7" in source
    assert "EPISODE:\n\t\t\treturn 19" in source and "return total if total <= MAX_BYTES else 0" in source
    assert "total += capacities[table] * wire_row_bytes(table)" in source
    assert "var total: int = FIXED_BYTES" in source, "Frontier fixed initialization charge omitted"
    return {"reserved_bytes": resolve(index, module, "MAX_BYTES"), "fixed_bytes": 2048,
            "wire_row_bytes": [36, 80, 28, 36, 40, 76],
            "scope": "One immutable configured reader; the whole ceiling includes its fixed header and controls. Native growth remains unqualified."}


def entry_bindings_reservation(index: dict) -> dict:
    """Census the additional concrete provider only; its RoomBindings base and variable cold packets are shared."""
    module = "underground_entry_bindings"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ['"res://scripts/core/underground_room_bindings.gd"']
    fields = explicit_members(source)
    expected = {"_entry_frontier": "Frontier", "_entry_placements": "Placements", "_entry_authority": "AdmissionAuthority",
        "_entry_request": "EntryPlan.Request", "_entry_pin": "EntryPlan.Request", "_placement_request": "Placements.Request",
        "_entry_candidate": "Directory.CreateCandidate", "_entry_anchor": "Locations.Record", "_entry_contact": "Locations.Record",
        "_entry_transform": "Connectors.Placement", "_entry_row": "PackedInt32Array", "_entry_bearing": "PackedInt32Array"}
    assert {k: v for k, v in fields.items() if v not in {"int", "bool", "Vector2i", "Vector3i"}} == expected, \
        "unreconciled EntryBindings retained member"
    record = class_body(index["underground_locations"].text, "Record")
    boxes = {"envelope": "PackedInt32Array", "support": "PackedInt32Array"}
    packets = sum(anchor_packet_bytes(record, boxes, name, source) for name in ("_entry_anchor", "_entry_contact"))
    transform = {"endpoint_refs": "PackedInt32Array", "endpoint_revisions": "PackedInt64Array",
                 "opening_refs": "PackedInt32Array", "opening_revisions": "PackedInt64Array"}
    packets += scalar_packet(index, "room_connectors", "Placement", transform)
    assert not re.search(r"_entry_transform\.(?:endpoint|opening)_(?:refs|revisions)\s*(?:=|\.)", source), \
        "unreconciled nonempty entrance transform arrays"
    authority = class_body(source, "AdmissionAuthority", "Placements.Authority")
    assert explicit_members(authority, "\t") == {"host": "WeakRef"}, "entrance authority retained growth"
    assert explicit_members(class_body(index["underground_connector_placements"].text, "Authority"), "\t") == {}, \
        "unreconciled inherited entrance authority fields"
    rows = 0
    for name, constant in (("_entry_row", "ENTRY_EPISODE_FIELDS"), ("_entry_bearing", "ENTRY_BEARING_FIELDS")):
        assert re.findall(re.escape(name) + r"\.resize\(([^)]+)\)", source) == [constant]
        rows += 4 * resolve(index, module, constant)
    assert rows == 112, "entrance row-width drift"
    fixed = numeric_fields(source, "") + packets + rows
    reserved = resolve(index, module, "ENTRY_FIXED_BYTES")
    assert fixed + 2048 <= reserved, "entrance fixed/helper allowance exceeded"
    return {"numeric_controls": numeric_fields(source, ""), "packet_bytes": packets, "packed_rows": rows,
            "fixed_numeric_and_packed_bytes": fixed, "logical_helper_allowance_bytes": 2048,
            "reserved_bytes": reserved,
            "scope": "Admission-only extension; borrowed references, native headers/frames and actual peaks still require measurement."}


def connector_contacts_reservation(index: dict) -> dict:
    """Census every concrete contact packet and both finite fragment banks inside the earmarked4096 bytes."""
    module = "underground_connector_contacts"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ['"res://scripts/core/underground_connector_work.gd".Contacts'], \
        "unreconciled ConnectorContacts base"
    assert explicit_members(class_body(index["underground_connector_work"].text, "Contacts"), "\t") == {}, \
        "unaccounted inherited Contacts member"
    packets = {"_order": "Placements.OrderRecord", "_location": "Locations.Record", "_other": "Locations.Record",
        "_descriptor": "Profiles.Descriptor", "_selection": "Profiles.Selection", "_box": "Profiles.Box",
        "_stance": "Profiles.Box", "_number": "IntMath.IntResult", "_fragments": "Fragments"}
    borrowed = {"_placements": "Placements", "_router": "WeakRef", "_frontier": "Frontier", "_sites": "Sites", "_terrain": "Terrain"}
    fields = explicit_members(source)
    numeric = {"int", "bool", "Vector2i", "Vector3i"}
    arrays = {"_frame": 9, "_install": 9, "_station": 9, "_episode": 19, "_endpoint": 7, "_cut": 7, "_bearing": 9,
              "_part": 9, "_region": 8, "_pair": 2, "_remaining": 1,
              "_bounds": 6, "_support": 6, "_target": 6, "_scratch": 6}
    expected = {**packets, **borrowed, **{key: "PackedInt32Array" for key in arrays}}
    assert {key: kind for key, kind in fields.items() if kind not in numeric} == expected, \
        "unreconciled ConnectorContacts retained member"
    packed = 0
    for name, count in arrays.items():
        assert re.findall(re.escape(name) + r"\.resize\(([^)]+)\)", source) == [str(count)], \
            (name, "Contacts resize drift")
        packed += count * 4
    fragment = class_body(source, "Fragments")
    fragment_arrays = {"first": "6 * FRAGMENT_CAPACITY", "second": "6 * FRAGMENT_CAPACITY",
                       "core": "6", "cut": "6", "slab": "6"}
    fragment_fields = explicit_members(fragment, "\t")
    assert {key: kind for key, kind in fragment_fields.items() if kind not in numeric} == \
        {key: "PackedInt32Array" for key in fragment_arrays}, "unreconciled Contacts fragment bank"
    fragment_bytes = numeric_fields(fragment, "\t")
    for name, expression in fragment_arrays.items():
        assert re.findall(r"(?m)^\t\t" + re.escape(name) + r"\.resize\(([^)]+)\)$", fragment) == [expression], \
            (name, "fragment resize drift")
        fragment_bytes += 4 * resolve(index, module, expression)
    assert fragment_bytes == 1633, "Contacts fragment capacity or numeric lifetime drift"
    record = class_body(index["underground_locations"].text, "Record")
    boxes = {"envelope": "PackedInt32Array", "support": "PackedInt32Array"}
    owned = sum(anchor_packet_bytes(record, boxes, name, source) for name in ("_location", "_other"))
    owned += scalar_packet(index, "underground_connector_placements", "OrderRecord")
    owned += sum(scalar_packet(index, "underground_profiles", name) for name in ("Descriptor", "Selection", "Box", "Box"))
    number_source = index["int_math"].text.split("class IntResult:\n")
    assert len(number_source) == 2, "unreconciled Contacts integer-result base"
    number = number_source[1].split("\nclass ", 1)[0]
    assert explicit_members(number, "\t") == {"ok": "bool", "value": "int", "error": "String"}, \
        "unreconciled Contacts integer-result packet"
    owned += numeric_fields(number, "\t")
    fixed = numeric_fields(source, "") + packed + fragment_bytes + owned
    reserved = resolve(index, module, "CONTROL_BYTES")
    assert reserved == 4096 and fixed + 1024 <= reserved, "Contacts fixed/helper allowance exceeded"
    return {"numeric_controls": numeric_fields(source, ""), "packed_rows": packed,
            "fragment_banks_and_controls": fragment_bytes, "owned_packet_bytes": owned,
            "fixed_numeric_and_packed_bytes": fixed, "logical_helper_allowance_bytes": 1024,
            "reserved_bytes": reserved,
            "scope": "Exact finite source census; borrowed references, native headers and composed helper/native peaks remain unmeasured."}


def connector_recipe_reservation(index: dict, binding_reserve: int) -> dict:
    """Count the exact immutable recipe bank inside, not in addition to, the shared binding reserve."""
    # The shared audit parser intentionally keeps inline comments. Strip comments
    # only from integer arithmetic declarations in these two local read views;
    # original source hashes remain in the returned whole-pack provenance.
    index = dict(index)
    for name in ("underground_connector_catalog", "underground_world_routes", "underground_connector_placements", "underground_entry_frontier"):
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
    settlement = funding_settlement_reservation(index)
    placement = placement_reservation(index)
    work = connector_work_reservation(index, placement)
    frontier = entry_frontier_reservation(index)
    entry = entry_bindings_reservation(index)
    contacts = connector_contacts_reservation(index)
    consumers = {
        "connector_catalog": resolve(index, "underground_connector_catalog", "RESERVED_BYTES"),
        "world_routes": resolve(index, "underground_world_routes", "RESERVED_BYTES"),
        "connector_recipes": bank + fixed,
        "connector_assemblies": assemblies["reserved_bytes"],
        "surface_anchor": anchor["reserved_bytes"],
        "connector_settlement": settlement["reserved_bytes"],
        "connector_placements": placement["reserved_bytes"],
        "connector_work": work["reserved_bytes"],
        "entry_frontier": frontier["reserved_bytes"],
        "entry_bindings": entry["reserved_bytes"],
        "connector_contacts": contacts["reserved_bytes"],
    }
    used = sum(consumers.values())
    assert used <= binding_reserve, "known binding consumers exceed their shared reserve"
    return {"columns": rows, "part_capacity": capacity, "bank_bytes": bank,
            "fixed_bytes": fixed, "assembly_reservation": assemblies, "surface_anchor_reservation": anchor,
            "funding_settlement_reservation": settlement, "placement_reservation": placement,
            "connector_work_reservation": work,
            "entry_frontier_reservation": frontier, "entry_bindings_reservation": entry,
            "connector_contacts_reservation": contacts,
            "known_binding_consumers": consumers,
            "known_binding_used_bytes": used,
            "remaining_binding_reserve_bytes": binding_reserve - used,
            "scope": "Known logical consumers include concrete Frontier, EntryBindings and Contacts. The shared bindings reserve is fully assigned; whole native memory qualification remains open."}


def funding_settlement_reservation(index: dict) -> dict:
    """Charge the two actual synchronous full refs without recounting the existing Funding buffers."""
    source = index["excavation_inventory"].text
    names = re.findall(r"^var[ \t]+(_settling_\w+)\b", source, re.M)
    declarations = re.findall(r"^var[ \t]+(_settling_\w+)[ \t]*:[ \t]*([\w.]+)\b", source, re.M)
    fields = dict(declarations)
    expected = {"_settling_project": "Vector2i", "_settling_job": "Vector2i"}
    assert len(names) == len(declarations) == len(fields) and fields == expected, \
        ("unreconciled connector settlement control", names, fields)
    return {"fields": fields, "reserved_bytes": 8 * len(fields),
            "scope": "Same-stack input settlement only; existing refund scratch is reused. Native references and helper frames remain unmeasured."}


def excavation_start_controls(index: dict) -> dict:
    """Charge exact START and terminal guards, not a second Funding or receipt bank."""
    source = index["excavation_sites"].text
    names = re.findall(r"^var[ \t]+(_start(?:ing|_\w+)|_settl(?:ing|ement_\w+))\b", source, re.M)
    declarations = re.findall(r"^var[ \t]+(_start(?:ing|_\w+)|_settl(?:ing|ement_\w+))[ \t]*:[ \t]*([\w.]+)\b", source, re.M)
    fields = dict(declarations)
    assert len(names) == len(declarations) == len(fields) and fields == {
        "_starting": "bool", "_start_poisoned": "bool", "_settling": "bool", "_settlement_poisoned": "bool"}, "unreconciled excavation START control"
    return {"fields": fields, "numeric_bytes": len(fields),
            "scope": "Same-stack START and settlement guards only; no packed or saved state. Existing native/frame qualification remains open."}


def entry_structure_reservation(index: dict) -> dict:
    """Charge the entry-only packet outside the fully assigned shared binding envelope."""
    module = "underground_entry_structure"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ['"res://scripts/core/underground_phase_structure.gd"']
    expected = {"_entry_placements": "WeakRef", "_entry_frontier": "WeakRef",
                "_entry_source_revision": "int", "_entry_ref": "Vector2i", "_entry_payload": "int",
                "_entry_prefix": "int", "_entry_episode_row": "int", "_entry_selected": "bool",
                "_entry_frame": "PackedInt32Array", "_entry_episode": "PackedInt32Array"}
    assert explicit_members(source) == expected, "unreconciled entry structure member"
    rows = columns(index, module, 2, {})
    for name, count in (("_entry_frame", 9), ("_entry_episode", 19)):
        assert re.findall(re.escape(name) + r"\.resize\(([^)]+)\)", source) == [str(count)], \
            (name, "entry structure resize drift")
    assert payload(rows) == 112 and rows["_entry_frame"]["capacity"] == 9 \
        and rows["_entry_episode"]["capacity"] == 19, "entry structure packet drift"
    numeric = numeric_fields(source, "")
    reserve = resolve(index, module, "ENTRY_CONTROL_BYTES")
    assert numeric == 41 and reserve == 384, "entry structure reserve or control drift"
    assert "BaseStructure.cold_peak_bytes(_mode, _capacity) + ENTRY_CONTROL_BYTES > Budget.COLD_BYTES" in source, \
        "entry structure cold coexistence admission missing"
    structure_peak_statements(index["underground_phase_structure"].text)
    base_check = 2 * (48 * resolve(index, "underground_budget", "PHASE_VOLUME_CAPACITY")
                     + 16 * resolve(index, "underground_budget", "SOURCE_CAPACITY")) \
        + 144 * resolve(index, "underground_phase_structure", "PLAN_ROWS") \
        + 8 * resolve(index, "underground_budget", "REGION_CAPACITY") \
        + resolve(index, "underground_phase_structure", "CONTROL_BYTES")
    assert base_check + reserve <= resolve(index, "underground_budget", "COLD_BYTES"), "entry CHECK exceeds original cold peak"
    return {"columns": rows, "numeric_control_bytes": numeric,
            "fixed_numeric_and_packed_bytes": payload(rows) + numeric,
            "logical_helper_allowance_bytes": reserve - payload(rows) - numeric,
            "reserved_bytes": reserve, "check_peak_bytes": base_check + reserve,
            "scope": "Additional binding reserve; inherited structure counted once. No native-memory qualification."}


def entry_world_storage_statements(source: str) -> None:
    """Freeze actual array growth/alias sites and the single borrowed getter, not just resulting dimensions."""
    assert not re.search(r"\.new\s*\(", source), "entry World must not construct another owned packet"
    assert re.findall(r"\b(Packed[A-Za-z0-9]+Array)\s*\(", source) == ["PackedInt32Array"] * 3, \
        "entry World has unaccounted local or retained packed allocation"
    statements = [line.strip() for line in source.splitlines()
                  if not line.lstrip().startswith(("#", '"""'))
                  and re.search(r"\b_entry_(?:box|air|reach)\b", line)]
    expected = [
        'var _entry_box: PackedInt32Array = PackedInt32Array()',
        'var _entry_air: PackedInt32Array = PackedInt32Array()',
        'var _entry_reach: PackedInt32Array = PackedInt32Array()',
        '_entry_box.resize(6)',
        '_entry_air.resize(6)',
        '_entry_reach.resize(6)',
        'code = actual._profile_bounds(actual._box, _entry_box)',
        'var code: StringName = actual._profile_bounds(actual._box, _entry_box)',
        '_entry_append_row(out.volumes, _entry_box, role, actual._location.level, _entry_room, out.owner_revision)',
        '_entry_air[axis] = maxi(_entry_box[axis], actual._location.envelope[axis])',
        '_entry_air[axis + 3] = mini(_entry_box[axis + 3], actual._location.envelope[axis + 3])',
        'if _entry_air[axis] >= _entry_air[axis + 3]: return false',
        '_entry_reach[axis] = mini(_entry_air[axis], _entry_point[axis])',
        '_entry_reach[axis + 3] = maxi(_entry_air[axis + 3], int(_entry_point[axis]) + 1)',
        '_entry_append_row(out.contacts.approach, _entry_air, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision)',
        '_entry_append_row(out.contacts.reach, _entry_reach, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision)',
        'code = actual._profile_bounds(actual._box, _entry_box)',
        'if not _entry_row_matches(plan.volumes, row, _entry_box, role, actual._location.level, _entry_room, plan.owner_revision):',
        'return _entry_row_matches(plan.contacts.approach, row, _entry_air, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision) \\',
        'and _entry_row_matches(plan.contacts.reach, row, _entry_reach, Space.ENVELOPE, actual._location.level, _entry_contact_ref, _entry_contact_revision) \\',
    ]
    assert statements == expected, "entry World allocation/writer/borrowed-array alias drift"
    signature = "func _entry_actual() -> PhaseContacts:"
    assert source.count(signature) == 1, "entry World borrowed getter missing or duplicated"
    body = source.split(signature + "\n", 1)[1].split("\n\nfunc ", 1)[0]
    actual = [line.strip() for line in body.splitlines()
              if line.strip() and not line.lstrip().startswith(("#", '"""'))]
    assert actual == ["return _entry_contacts.get_ref() as PhaseContacts if _entry_contacts != null else null"], \
        "entry World must borrow exactly the original weak Contacts packet"


def entry_world_reservation(index: dict) -> dict:
    """Charge the additional actual phase composer once, outside the fully assigned binding reserve."""
    module = "underground_entry_world_bindings"
    source = index[module].text
    assert re.findall(r"(?m)^extends (.+)$", source) == ['"res://scripts/core/underground_world_bindings.gd"']
    integers = ("_entry_contact_revision", "_entry_operation", "_entry_stage", "_entry_episode",
                "_entry_revision", "_entry_payload", "_entry_cold_token", "_entry_remaining")
    refs = ("_entry_placement", "_entry_site", "_entry_room", "_entry_project", "_entry_contact_ref")
    arrays = ("_entry_box", "_entry_air", "_entry_reach")
    expected = {"_entry_contacts": "WeakRef", "_entry_reading": "bool", "_entry_poisoned": "bool",
                "_entry_origin": "Vector3i", "_entry_point": "Vector3i",
                **{name: "int" for name in integers}, **{name: "Vector2i" for name in refs},
                **{name: "PackedInt32Array" for name in arrays}}
    assert explicit_members(source) == expected, "unreconciled entry World member"
    entry_world_storage_statements(source)
    rows = columns(index, module, 3, {})
    for name in arrays:
        assert re.findall(re.escape(name) + r"\.resize\(([^)]+)\)", source) == ["6"], \
            (name, "entry World resize drift")
    assert payload(rows) == 72 and all(row["capacity"] == 6 for row in rows.values()), "entry World packet drift"
    numeric = numeric_fields(source, "")
    reserve = resolve(index, module, "ENTRY_CONTROL_BYTES")
    assert numeric == 130 and reserve == 2048, "entry World reserve or control drift"
    assert numeric + payload(rows) + 1024 <= reserve, "entry World helper allowance exceeded"
    return {"columns": rows, "numeric_control_bytes": numeric,
            "fixed_numeric_and_packed_bytes": numeric + payload(rows),
            "logical_helper_allowance_bytes": 1024, "reserved_bytes": reserve,
            "scope": "Additional phase composer only; one borrowed Contacts and existing World base counted once. Native headers and composed peak remain unqualified."}


def structure_peak_statements(source: str) -> None:
    """Check complete unique statements, so prefix matches and comment-only formula witnesses cannot pass."""
    signature = "static func cold_peak_bytes(mode: int, region_rows: int) -> int:"
    bodies = re.findall(r"(?ms)^" + re.escape(signature) + r"\n(.*?)(?=^\S|\Z)", source)
    assert len(bodies) == 1, "missing or duplicate structure peak function"
    lines = bodies[0].splitlines()
    assert lines and lines[0].strip().startswith('"""') and lines[0].strip().endswith('"""'), \
        "structure peak docstring shape changed"
    statements = [line.rstrip() for line in lines[1:] if line.strip() and not line.lstrip().startswith("#")]
    expected = [
        "\tif region_rows < 1 or region_rows > Budget.REGION_CAPACITY:",
        "\t\treturn -1",
        "\tvar plans: int = 144 * PLAN_ROWS",
        "\tvar sources: int = 16 * Budget.SOURCE_CAPACITY",
        "\tif mode == CHECK:",
        "\t\treturn 2 * (48 * Budget.PHASE_VOLUME_CAPACITY + sources) + plans + 8 * region_rows + CONTROL_BYTES",
        "\tif mode == STAGE:",
        "\t\treturn 48 * Budget.PHASE_VOLUME_CAPACITY + sources + plans + 56 * region_rows + CONTROL_BYTES",
        "\tif mode == PREPARED:",
        "\t\treturn 56 * region_rows + sources + plans + CONTROL_BYTES",
        "\treturn -1",
    ]
    assert statements == expected, "inherited structure peak statement drift"


def room_world_reservation(index: dict) -> dict:
    """Admit only the complete independently reviewed provider census and its unchanged source closure."""
    path = ROOT / "docs/validation/evidence/underground-room-phases-2026-10-04/census.json"
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == "74ece6f13efd76842751f8153faf912eba0b26c78c40497a5abaaa3a5478bea9", \
        "reviewed ordinary Room provider census changed"
    result = json.loads(raw)
    for name, expected in result["source_sha256"].items():
        assert name in index and hashlib.sha256(index[name].text.encode()).hexdigest() == expected, \
            ("ordinary Room provider source changed; independent census required", name)
    assert result["new_global_reservation"] == 1024 and result["control_accounted"] == 986
    assert result["prospective_shared_total"] == 99999806
    return {"reserved_bytes": 1024, "logical_helper_and_included_native_bytes": 986,
            "census_path": str(path.relative_to(ROOT)), "census_sha256": hashlib.sha256(raw).hexdigest(),
            "current_source_sha256": result["source_sha256"], "native_measured": False,
            "maximum_shared_phase_bytes": max(result["sequential_cold_peaks"].values())}


def build(index: dict | None = None) -> dict:
    index = audit.load_source_index() if index is None else index
    index = dict(index)
    extra_sources = {
        "mole_profile_catalog": "godot/data/underground/mole-worker/mole_profile_catalog.gd",
        "mole_profile_driver": "godot/data/underground/mole-worker/mole_profile_driver.gd",
        "source_program": "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
        "settlement_system": "godot/scripts/systems/settlement_system.gd",
        "ui_manager": "godot/scripts/systems/ui_manager.gd",
        "ui_world_session": "godot/scripts/ui/ui_world_session.gd",
    }
    for name, path in extra_sources.items():
        if name not in index:
            index[name] = audit.parse_module(name, path, (ROOT / path).read_text())
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
    start = excavation_start_controls(index)
    entry_structure = entry_structure_reservation(index)
    entry_world = entry_world_reservation(index)
    room_world = room_world_reservation(index)
    workpieces = connector_workpieces_reservation(index)
    haul_transfer = haul_transfer_reservation(index)
    delivery = connector_delivery_reservation(index)
    reserve_names = ("LOCATION_AND_TOPOLOGY_BYTES", "INVENTORY_EXTENSION_BYTES", "PROFILE_BYTES",
                     "TERRAIN_BYTES", "LAYOUT_COLD_BYTES", "BINDINGS_AND_GROWTH_BYTES")
    reserves = {key: resolve(index, budget.name, key) for key in reserve_names}
    try:
        motion = motion_memory.build(index)
        approach = approach_memory.build(index, motion["joint"])
        clock = clock_memory.build(index, motion)
        session = session_memory.build(index, motion, reserves["PROFILE_BYTES"])
        retirement = retirement_memory.build(index, session, reserves["PROFILE_BYTES"])
        ui_reset = ui_reset_memory.build(index, retirement, reserves["PROFILE_BYTES"])
    except ValueError as error:
        raise AssertionError(str(error)) from error
    assert motion["joint"]["total"] <= reserves["PROFILE_BYTES"], "Motion/Profile/Level joint overbooking"
    recipes = connector_recipe_reservation(index, reserves["BINDINGS_AND_GROWTH_BYTES"])
    assert 56 * endpoints <= reserves["INVENTORY_EXTENSION_BYTES"], "endpoint live/raw/conversion exceeds reserve"
    assert 228 * locations + 256 + 106 * locations + 128 <= reserves["LOCATION_AND_TOPOLOGY_BYTES"]
    contributions = {
        "excavation_start_controls": start["numeric_bytes"],
        "entry_structure_bindings": entry_structure["reserved_bytes"],
        "entry_world_bindings": entry_world["reserved_bytes"],
        "room_world_bindings": room_world["reserved_bytes"],
        "connector_workpieces": workpieces["reserved_bytes"],
        "guarded_haul_transfers": haul_transfer["reserved_bytes"],
        "connector_delivery": delivery["reserved_bytes"],
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
    sources.update(("inventory", "excavation_inventory", "excavation_sites", "construction", "modular_project_contract", "underground_budget",
                    "underground_connector_recipes", "underground_connector_catalog", "underground_world_routes",
                    "underground_connector_assemblies", "underground_surface_anchor", "underground_locations",
                    "underground_connector_placements", "underground_connector_work", "underground_connector_workpieces", "entity_directory",
                    "underground_entry_frontier", "underground_entry_bindings", "underground_entry_plan", "room_connectors",
                    "underground_connector_contacts", "underground_profiles", "int_math", "reservations", "haul_transfer_contract",
                    "underground_connector_delivery", "work", "haul_planner",
                    "underground_motion_catalog", "underground_level_catalog", "mole_profile_catalog",
                    "underground_session", "underground_terrain", "underground_routes", "room_space", "underground_motion_clock",
                    "underground_entry_structure", "underground_phase_structure", "underground_entry_world_bindings",
                    "underground_room_world_bindings", "underground_work_face", "underground_world_retirement",
                    "source_program", "mole_profile_driver", "settlement_system"))
    return {"schema": 1, "scope": "source-derived logical allocation pack; runtime qualification remains open",
            "runtime_qualified": False, "pack": pack, "columns": groups, "quote": quote,
            "furniture_bridge_cold": bridge, "connector_recipe_reservation": recipes,
            "excavation_start_controls": start,
            "entry_structure_reservation": entry_structure,
            "entry_world_reservation": entry_world,
            "room_world_reservation": room_world,
            "connector_workpieces_reservation": workpieces,
            "haul_transfer_reservation": haul_transfer,
            "connector_delivery_reservation": delivery,
            "profile_motion_reservation": motion,
            "source_approach_reservation": approach,
            "motion_clock_reservation": clock,
            "session_reservation": session,
            "host_retirement_reservation": retirement,
            "ui_reset_reservation": ui_reset,
            "contributions": contributions, "new_mutable_and_reserved_bytes": added,
            "declaration_bytes": declaration, "declaration_delta_bytes": declaration - 21185,
            "live_with_reserve_bytes": total, "headroom_bytes": 100000000 - total,
            "source_sha256": {index[name].relative_path: index[name].sha256 for name in sorted(sources)},
            "registry_sha256": hashlib.sha256((ROOT / "docs/planning/canonical_state_registry.json").read_bytes()).hexdigest(),
            "limitations": ["Constructor limits alone are not joint runtime admission.",
                            "Actual consumers must share the exact cold arena and charge nested coexistence before allocating.",
                            "Location/topology, terrain, layout cold work and binding/native growth envelopes are reserved, not measured or implemented by this checker.",
                            "One source-only Motion/Profile/Level/Session composition is source-counted inside PROFILE_BYTES; native ceilings and actual host admission remain unqualified.",
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
