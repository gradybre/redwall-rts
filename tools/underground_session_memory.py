#!/usr/bin/env python3
"""Enforce the additive Session slice against the current source-derived joint Profile arena."""
import hashlib
import re

SOURCE = "godot/scripts/core/underground_session.gd"
REFS = {
    "_world": "World", "_directory": "Directory", "_buildings": "Buildings",
    "_construction": "Construction", "_inventory": "Inventory", "_items": "Items",
    "_residents": "Residents", "_jobs": "Jobs", "_work": "Work", "_reservations": "Reservations",
    "_transforms": "Transforms", "_gear": "Gear", "_carry": "Carry", "_piles": "Piles",
    "_content": "Content", "_budget": "Budget", "_routes": "Routes", "_sources": "Owner.CoreSources",
    "_space": "Owner", "_terrain": "Terrain", "_levels": "Levels", "_profiles": "Profiles",
    "_domain": "Space.Domain", "_profile_bank": "Profiles.Bank",
}
RETIREMENT_REFS = {"_retirement_owners": "Retirement.Owners", "_retirement_scope": "Retirement.Scope"}
SCALARS = {"_world_ref": "Vector2i", "_world_pid": "int", "_seed": "int",
           "_ready": "bool", "_busy": "bool", "_poisoned": "bool"}
WIDTHS = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12, "StringName": 8}
ALLOCATIONS = {"Space.Domain": 1, "Budget": 1, "Routes": 1, "Owner.CoreSources": 1,
               "Owner": 1, "Terrain": 1, "Levels": 1, "Profiles": 1}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def functions(source):
    pattern = re.compile(r"^func (\w+)\((.*?)\) -> ([\w.]+):\n(.*?)(?=^func |\Z)", re.M | re.S)
    result = {}
    for match in pattern.finditer(source):
        name, parameters, returns, body = match.groups()
        args = re.findall(r"(\w+):\s*([\w.]+)", parameters)
        locals_ = re.findall(r"^\t+var (\w+):\s*([\w.]+)", body, re.M)
        require(len(args) == parameters.count(":"), f"untyped argument in {name}")
        require(len(locals_) == len(re.findall(r"^\t+var ", body, re.M)), f"untyped local in {name}")
        values = args + locals_
        require(all(kind in WIDTHS or kind in (*REFS.values(), *RETIREMENT_REFS.values(), "Object") for _, kind in values),
                f"unaccounted caller/local shape in {name}")
        result[name] = {
            "numeric_and_name_bytes": sum(WIDTHS.get(kind, 0) for _, kind in values),
            "borrowed_reference_values": sum(kind not in WIDTHS for _, kind in values),
            "own_calls": sorted(set(re.findall(r"(?<![.\w])([_a-zA-Z]\w*)\(", body))),
            "returns": returns,
        }
    for frame in result.values():
        frame["own_calls"] = [name for name in frame["own_calls"] if name in result]
    return result


def longest(frames, metric):
    def visit(name, active):
        require(name not in active, "recursive Session helper allocation is not admitted")
        children = [visit(child, active + [name]) for child in frames[name]["own_calls"]]
        extra, chain = max(children, default=(0, []), key=lambda value: value[0])
        return frames[name][metric] + extra, [name] + chain
    return max((visit(name, []) for name in frames), key=lambda value: value[0])


def census(source, motion_joint, envelope):
    require(source.startswith("extends RefCounted\n"), "Session inherited storage changed")
    require(not re.search(r"^class ", source, re.M), "nested Session owner/bank is not admitted")
    members = re.findall(r"^var (\w+):\s*([\w.]+)\s*=", source, re.M)
    require(len(members) == len(re.findall(r"^var ", source, re.M)), "untyped retained field")
    require(len(dict(members)) == len(members), "duplicate retained member")
    require(dict(members) == REFS | RETIREMENT_REFS | SCALARS, "Session retained member census changed")
    require(not re.search(r"\b(?:Packed\w+Array|Array|Dictionary)\s*\(|\.resize\(|\.duplicate\(", source),
            "Session cannot allocate another retained or temporary bank")
    allocations = {}
    for kind in re.findall(r"\b([A-Z][\w.]*)\.new\(", source):
        allocations[kind] = allocations.get(kind, 0) + 1
    require(allocations == ALLOCATIONS | {"Retirement.Owners": 1, "Retirement.Scope": 1}, "foundation allocation topology changed")
    for name, value in (("CONTROL_BYTES", 1024), ("HELPER_BYTES", 512), ("PROFILE_SOURCE_COUNT", 1)):
        require(re.search(rf"^const {name}: int = {value}$", source, re.M), f"{name} reservation changed")
    require("_domain = _space._domain #" in source, "second retained Domain copy")
    require("_profile_bank = _profiles._live" in source, "profile bank must be an alias")
    require("_profiles.configure(Catalog.PROFILE_COUNT, Catalog.BOX_COUNT, PROFILE_SOURCE_COUNT," in source,
            "independent Profile maxima are not admitted")
    require("Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE)" in source, "actual Profile admission changed")
    require("_space.configure(_domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY)" in source,
            "actual Space configuration changed")
    require(not re.search(r"\.(?:bind_spatial_authority|bind_modular_authority|bind_excavation_authority)\(", source),
            "one-way external authority mutation is not part of private initialization")
    require(motion_joint + 1536 <= envelope, "Session overbooks the current joint Profile envelope")
    frames = functions(source)
    numeric, chain = longest(frames, "numeric_and_name_bytes")
    refs, reference_chain = longest(frames, "borrowed_reference_values")
    require(numeric <= 512, "Session own numeric stack exceeds helper reservation")
    fixed = sum(WIDTHS[kind] for kind in SCALARS.values())
    return {
        "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "retained_numeric_bytes": fixed,
        "strong_reference_or_alias_members": len(REFS),
        "additional_retirement_reference_slots_charged_separately": len(RETIREMENT_REFS),
        "own_packed_columns": 0,
        "own_variable_bank_bytes": 0,
        "control_reservation_bytes": 1024,
        "provisional_reference_native_header_bytes_in_control": 1024 - fixed,
        "helper_reservation_bytes": 512,
        "own_longest_numeric_and_name_chain_bytes": numeric,
        "own_longest_numeric_and_name_chain": chain,
        "own_longest_borrowed_reference_chain_values": refs,
        "own_longest_borrowed_reference_chain": reference_chain,
        "references_are_not_measured_native_bytes": True,
        "own_total_slice_bytes": 1536,
        "slice_source": "existing PROFILE_BYTES; no global reserve increase",
        "existing_profile_paired_plus_control_bytes": 19224 + 32768,
        "existing_level_bytes": 2292,
        "foundation_profile_level_session_bytes": 19224 + 32768 + 2292 + 1536,
        "source_counted_motion_joint_before_session_bytes": motion_joint,
        "profile_level_motion_session_joint_bytes": motion_joint + 1536,
        "profile_envelope_bytes": envelope,
        "joint_remaining_bytes": envelope - motion_joint - 1536,
        "sequential_foundation_allocations": ALLOCATIONS,
        "retirement_allocations_charged_separately": {"Retirement.Owners": 1, "Retirement.Scope": 1},
        "frames": frames,
        "native_memory_qualified": False,
        "runtime_activation_qualified": False,
    }


def build(index, motion, envelope):
    """Add one source-counted wrapper to the ACTUAL current shared Profile/Level/Motion result."""
    source = index['underground_session'].text
    require('const RESERVED_BYTES: int = CONTROL_BYTES + HELPER_BYTES' in source,
            'actual Session reserve formula changed')
    require('const FOUNDATION_PROFILE_BYTES: int = Catalog.PAIRED_BANK_BYTES + Catalog.CONTROL_RESERVE + Levels.RESERVED_BYTES + RESERVED_BYTES' in source,
            'actual Session foundation admission changed')
    require(motion['joint']['reservation'] == envelope, 'one unchanged shared Profile envelope')
    result = census(source, motion['joint']['total'], envelope)
    result['scope'] = 'One host-lifetime Session; underlying owners charged once in their existing reservations'
    return result
