#!/usr/bin/env python3
"""Source-count the additive Session only; foundation and native reservations remain explicitly scoped."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[4]
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
        require(all(kind in WIDTHS or kind in REFS.values() for _, kind in values),
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


def foundation_census(root):
    """Keep the referenced unchanged arena contracts explicit instead of assuming their maxima compose."""
    catalog = (root / "godot/data/underground/mole-worker/mole_profile_catalog.gd").read_text()
    levels = (root / "godot/scripts/core/underground_level_catalog.gd").read_text()
    budget = (root / "godot/scripts/core/underground_budget.gd").read_text()
    for name, value in (("PROFILE_COUNT", 18), ("BOX_COUNT", 194), ("PAIRED_BANK_BYTES", 14520),
                        ("CONTROL_RESERVE", 32768)):
        require(re.search(rf"^const {name}: int = {value}(?:\s|$)", catalog, re.M), f"current Catalog {name} changed")
    for name, value in (("MAX_RETAINED_BYTES", 244), ("CONTROL_RESERVE", 2048)):
        require(re.search(rf"^const {name}: int = {value}(?:\s|$)", levels, re.M), f"current Levels {name} changed")
    require("const RESERVED_BYTES: int = MAX_RETAINED_BYTES + CONTROL_RESERVE" in levels, "Level lifetime formula changed")
    require(re.search(r"^const PROFILE_BYTES: int = 262144$", budget, re.M), "global Profile reserve changed")
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in (
        "godot/data/underground/mole-worker/mole_profile_catalog.gd",
        "godot/scripts/core/underground_level_catalog.gd",
        "godot/scripts/core/underground_budget.gd",
        "godot/scripts/core/underground_routes.gd",
        "godot/scripts/core/underground_space_owner.gd",
        "godot/scripts/core/underground_terrain.gd",
        "godot/scripts/core/underground_profiles.gd",
        "godot/demo/cast/underground_actor_content.gd")}


def census(source):
    require(source.startswith("extends RefCounted\n"), "Session inherited storage changed")
    require(not re.search(r"^class ", source, re.M), "nested Session owner/bank is not admitted")
    members = re.findall(r"^var (\w+):\s*([\w.]+)\s*=", source, re.M)
    require(len(members) == len(re.findall(r"^var ", source, re.M)), "untyped retained field")
    require(len(dict(members)) == len(members), "duplicate retained member")
    require(dict(members) == REFS | SCALARS, "Session retained member census changed")
    require(not re.search(r"\b(?:Packed\w+Array|Array|Dictionary)\s*\(|\.resize\(|\.duplicate\(", source),
            "Session cannot allocate another retained or temporary bank")
    allocations = {}
    for kind in re.findall(r"\b([A-Z][\w.]*)\.new\(", source):
        allocations[kind] = allocations.get(kind, 0) + 1
    require(allocations == ALLOCATIONS, "foundation allocation topology changed")
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
    frames = functions(source)
    numeric, chain = longest(frames, "numeric_and_name_bytes")
    refs, reference_chain = longest(frames, "borrowed_reference_values")
    require(numeric <= 512, "Session own numeric stack exceeds helper reservation")
    fixed = sum(WIDTHS[kind] for kind in SCALARS.values())
    return {
        "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "retained_numeric_bytes": fixed,
        "strong_reference_or_alias_members": len(REFS),
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
        "existing_profile_paired_plus_control_bytes": 14520 + 32768,
        "existing_level_bytes": 2292,
        "foundation_profile_level_session_bytes": 14520 + 32768 + 2292 + 1536,
        "accepted_motion_joint_before_session_bytes": 232436,
        "profile_level_motion_session_joint_bytes": 232436 + 1536,
        "profile_envelope_bytes": 262144,
        "joint_remaining_bytes": 262144 - 232436 - 1536,
        "sequential_foundation_allocations": allocations,
        "frames": frames,
        "native_memory_qualified": False,
        "runtime_activation_qualified": False,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    result = census((args.root / SOURCE).read_text())
    result["unchanged_foundation_sources"] = foundation_census(args.root)
    text = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.out:
        args.out.write_text(text)
    else:
        print(text, end="")


if __name__ == "__main__":
    main()
