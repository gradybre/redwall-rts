#!/usr/bin/env python3
"""ADR 1212: recount the current retained storage the reviewed room census no longer sees.

`underground_room_memory.py` replays frozen, independently reviewed census
producers. They pin the exact bytes of every source they read (manifest 3).
Work after 94dca0a3 changed 21 of those inputs. The room census now replays the
archived reviewed bytes of those inputs (historical projection), and this module
is the current-source half: for every projected input it compares the reviewed
and current storage structure, and every difference must appear in the reviewed
delta table below with its byte charge and the reserve that carries it. For every
owner that did not exist at manifest 3 and is mounted at 256 residents, it counts
the owner's complete retained declaration.

What is counted, exactly from source: retained members (top-level and nested
packet classes), packed resizes resolved through module constants, integer
capacity constants, and allocation-site counts (`.new(`, packed constructors,
`.duplicate(`, `.slice(`). What is not re-proved here: numeric helper frames of
changed call chains and native object/Variant overhead. Those stay inside each
owner's declared helper/native allowance, as the original reviews stated; they
are logical allowances, not measurements.
"""
from __future__ import annotations

from collections import Counter
import hashlib
import json
from pathlib import Path
import re

import audit_registry_capacities as audit

ROOT = Path(__file__).resolve().parents[1]
WIDTH = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
PACKED = {"PackedByteArray": 1, "PackedInt32Array": 4, "PackedInt64Array": 8}
NONCORE = {
    "mole_profile_catalog": "godot/data/underground/mole-worker/mole_profile_catalog.gd",
    "short_program": "godot/data/underground/mole-worker/work-step-v1/source_program.gd",
    "settlement_system": "godot/scripts/systems/settlement_system.gd",
}


def require(condition, message):
    if not condition:
        raise ValueError("current census: " + message)


def executable(text: str) -> str:
    """Code without docstrings or comments; string literals other than docstrings are kept."""
    text = re.sub(r'"""[\s\S]*?"""', '""', text)
    return "\n".join(re.sub(r"\s+#[^\n]*$|^\s*#[^\n]*$", "", line) for line in text.splitlines())


def facts(text: str) -> dict:
    """The storage structure of one GDScript source: what a retained-memory review must see change."""
    code = executable(text)
    classes = {}
    for match in re.finditer(r"^class (\w+)[^\n]*:\n((?:(?:\t[^\n]*|[ \t]*)\n)*)", code, re.M):
        classes[match[1]] = sorted(re.findall(r"^\tvar (\w+)\s*:\s*([\w.\[\]]+)", match[2], re.M))
    return {
        "members": sorted(re.findall(r"^(?:static )?var (\w+)\s*:\s*([\w.\[\]]+)", code, re.M)),
        "classes": classes,
        "resizes": sorted(re.sub(r"\s+", " ", m) for m in re.findall(r"([\w.\[\]]+\.resize\([^\n]*?\))", code)),
        "int_constants": sorted(re.findall(r"^const (\w+)\s*:\s*int\s*=\s*([^\n]+?)\s*$", code, re.M)),
        "allocation_sites": dict(sorted(Counter(re.sub(r"\s+", "", site) for site in re.findall(
            r"\.new\(|\bPacked\w+Array\(|\.duplicate\(|\.slice\(|\bArray\(|\bDictionary\(|\brange\(|"
            r"(?:[=(,]|\breturn|\bin)\s*[\[{]", code)).items())),
    }


def delta(before: str, after: str) -> dict:
    """Added/removed storage facts; an empty dict means the storage structure is unchanged."""
    old, new = facts(before), facts(after)
    result = {}
    for key in ("members", "resizes", "int_constants"):
        a, b = Counter(map(tuple, old[key]) if key != "resizes" else old[key]), \
            Counter(map(tuple, new[key]) if key != "resizes" else new[key])
        added, removed = sorted((b - a).elements()), sorted((a - b).elements())
        if added:
            result[key + "_added"] = [list(x) if isinstance(x, tuple) else x for x in added]
        if removed:
            result[key + "_removed"] = [list(x) if isinstance(x, tuple) else x for x in removed]
    for name in sorted(set(old["classes"]) | set(new["classes"])):
        if old["classes"].get(name) != new["classes"].get(name):
            result.setdefault("classes", {})[name] = [old["classes"].get(name), new["classes"].get(name)]
    sites = {k: new["allocation_sites"].get(k, 0) - old["allocation_sites"].get(k, 0)
             for k in set(old["allocation_sites"]) | set(new["allocation_sites"])}
    sites = {k: v for k, v in sorted(sites.items()) if v}
    if sites:
        result["allocation_sites"] = sites
    return result


EVIDENCE = Path("docs/validation/evidence/underground-memory-census-2026-10-06")
REVIEWED = EVIDENCE / "reviewed-deltas.json"
REVIEWED_SHA = "b1d2dbc78a73b48fd716c3b4a35eb6f2ec69226348d0170fb519f3195202fd3a"
# ADR1217 step 5: the runtime Frontier is the claw bundle's (same row census as qualified-stone-v5's).
# ADR1229: the mounted T1-T6 bundle's Frontier (ADR1217 step 5 mounted qualified-claw-v6's).
# DEC-059 (P3): qualified-stairs-v9, the same rows with T1-T6 fastened in 5,640 mWU.
# Decision 1972: qualified-stairs-v10 (the same install and episode counts; two more sill stops).
FRONTIER = Path("godot/data/underground/first-entry-prefix-v1/qualified-stairs-v10/frontier.ugfront")
FRONTIER_SHA = "8ee90bbff55e11c45604af294cb47fb21e2b097c99484f000310464b48d0d006"
CORE = "godot/scripts/core/"


def module(index: dict, relative: str):
    """The current parsed source for a repository path, loading owners outside the core index on demand."""
    for parsed in index.values():
        if parsed.relative_path == relative:
            return parsed
    name = Path(relative).stem
    if name not in index:
        index[name] = audit.parse_module(name, relative, (ROOT / relative).read_text())
    require(index[name].relative_path == relative, "module identity: " + relative)
    return index[name]


def packet(memory, index: dict, relative: str, name: str, parent: str = "RefCounted") -> int:
    """Numeric payload of one nested packet class; references and Variant headers are native, not counted."""
    return memory.numeric_fields(memory.class_body(module(index, relative).text, name, parent), "\t")


def frontier_counts() -> dict:
    """Row counts of the pinned runtime Frontier; they bound the foreman's planned task list."""
    raw = (ROOT / FRONTIER).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == FRONTIER_SHA, "runtime Frontier changed")
    names = ("INSTALL", "STATION", "CUT", "BEARING", "ENDPOINT", "EPISODE")
    return {name: int.from_bytes(raw[68 + 4 * table:72 + 4 * table], "little") for table, name in enumerate(names)}


def journal(memory, index: dict) -> dict:
    """The two geometry journals (ADR 1205/1207): fixed rings allocated when SpaceOwner is constructed."""
    source = module(index, CORE + "underground_geometry_journal.gd").text
    members = memory.explicit_members(source)
    require(members == {"_revisions": "PackedInt64Array", "_roles": "PackedByteArray", "_boxes": "PackedInt32Array",
                        "_box": "PackedInt32Array", "_full": "bool", "_head": "int", "_count": "int",
                        "_floor": "int"}, "unreconciled journal member")
    require(memory.resolve(index, "underground_geometry_journal", "CAPACITY") == 64, "journal ring capacity")
    resizes = re.findall(r"^\t(_\w+)\.resize\(([^)]+)\)$", source, re.M)
    require(resizes == [("_revisions", "CAPACITY"), ("_roles", "CAPACITY"), ("_boxes", "6 * CAPACITY"),
                        ("_box", "6")], "journal allocation drift")
    packed = sum(memory.WIDTHS[members[name]] * memory.resolve(index, "underground_geometry_journal", count)
                 for name, count in resizes)
    numeric = memory.numeric_fields(source, "")
    owner = module(index, CORE + "underground_space_owner.gd").text
    require(re.findall(r"^var (_\w+): Journal = Journal\.new\(\)", owner, re.M) == ["_journal", "_location_journal"]
            and owner.count("\t_journal.allocate()") == 1 and owner.count("\t_location_journal.allocate(true)") == 1,
            "SpaceOwner owns exactly two journals, each allocated once")
    return {"packed_bytes_per_instance": packed, "numeric_bytes_per_instance": numeric, "instances": 2,
            "bytes": 2 * (packed + numeric)}


def locations_controls(memory, index: dict) -> dict:
    """Locations' carried-row controls (ADR 1207) and the borrowed contact-retirement packet (ADR 1202)."""
    relative = CORE + "underground_locations.gd"
    source = module(index, relative).text
    members = memory.explicit_members(source)
    added = {"_carried_locations": "int", "_carry_content": "int", "_carry_geometry": "bool", "_air_slots": "int"}
    require(all(members.get(name) == kind for name, kind in added.items())
            and members.get("_contact_retirement") == "ContactRetirementContext"
            and members.get("_air_box") == "PackedInt32Array", "Locations control members")
    require(re.findall(r"^\t_air_box\.resize\((\d+)\)$", source, re.M) == ["6"], "ADR1215 air scratch box")
    # ADR1229 increment 6b: the witness pass's prism cache (six int32 per Catalog part), its five-word key and the
    # pass counters.
    passes = {"_witness_pass": "int", "_in_witness_pass": "bool", "_sources_pass": "int"}
    require(all(members.get(name) == kind for name, kind in passes.items())
            and members.get("_prism_boxes") == "PackedInt32Array" and members.get("_prism_key") == "PackedInt64Array"
            and re.findall(r"^\t_prism_boxes\.resize\((.+)\)$", source, re.M) == ["6 * ConnectorCatalog.MAX_PARTS"]
            and re.findall(r"^\t_prism_key\.resize\((\d+)\)$", source, re.M) == ["5"], "ADR1229 witness-pass cache")
    parts = memory.resolve(index, "underground_connector_catalog", "MAX_PARTS")
    numeric = sum(WIDTH[kind] for kind in added.values()) + 4 * 6 \
        + sum(WIDTH[kind] for kind in passes.values()) + 4 * 6 * parts + 8 * 5
    context = packet(memory, index, relative, "ContactRetirementContext")
    return {"carry_and_air_controls_bytes": numeric, "contact_retirement_context_numeric_bytes": context,
            "bytes": numeric + context,
            "scope": "The context exists only during one cold retirement; it is charged as retained, conservatively."}


def world_routes_controls(memory, index: dict) -> dict:
    """WorldRoutes' fixed numeric and small packed controls must still fit its CONTROL_RESERVE."""
    relative = CORE + "underground_world_routes.gd"
    source = module(index, relative).text
    small = re.findall(r"^\t(_\w+)\.resize\((\d+)\)$", source, re.M)
    require(small == [("_bounds", "6"), ("_support", "6"), ("_scratch", "6"), ("_first_point", "3"),
                      ("_last_point", "3"), ("_envelope", "6")], "WorldRoutes small packed controls")
    packets = {"Profiles.Descriptor": packet(memory, index, CORE + "underground_profiles.gd", "Descriptor"),
               "Profiles.Box": 2 * packet(memory, index, CORE + "underground_profiles.gd", "Box"),
               "Locations.Record": packet(memory, index, CORE + "underground_locations.gd", "Record") + 48 + 72,
               "Owner.Region": packet(memory, index, CORE + "underground_space_owner.gd", "Region") + 24,
               "Routes.Edge": packet(memory, index, CORE + "underground_routes.gd", "Edge"),
               "IntMath.IntResult": packet(memory, index, CORE + "int_math.gd", "IntResult", "")}
    # Decision 1952: the itinerary edge-profile memo and its input stamp, two fixed int64 packets.
    require(re.findall(r"^\t(_edge_memo\w*)\.resize\((\w+(?: \* \w+)?)\)$", source, re.M)
            == [("_edge_memo", "EDGE_MEMO_SLOTS * EDGE_MEMO_STRIDE"), ("_edge_memo_stamp", "EDGE_MEMO_STAMP")],
            "WorldRoutes edge memo packets")
    memo = 8 * (memory.resolve(index, "underground_world_routes", "EDGE_MEMO_SLOTS")
                * memory.resolve(index, "underground_world_routes", "EDGE_MEMO_STRIDE")
                + memory.resolve(index, "underground_world_routes", "EDGE_MEMO_STAMP"))
    fixed = memory.numeric_fields(source, "") + 4 * sum(int(count) for _, count in small) + sum(packets.values()) + memo
    reserve = memory.resolve(index, "underground_world_routes", "CONTROL_RESERVE")
    require(fixed <= reserve, "WorldRoutes controls exceed CONTROL_RESERVE")
    return {"numeric_bytes": memory.numeric_fields(source, ""), "small_packed_bytes": 4 * sum(int(c) for _, c in small),
            "edge_memo_bytes": memo,
            "packet_numeric_bytes": packets, "fixed_bytes": fixed, "control_reserve_bytes": reserve,
            "added_by_adr_1205_bytes": 24 + 4 * 8 + 2}


def world_routes_endpoint_memo(memory, index: dict) -> dict:
    """Decision 1952: WorldRoutes' endpoint-proof memo, four fixed packed columns retained for the World's life."""
    source = module(index, CORE + "underground_world_routes.gd").text
    require(re.findall(r"^\t(_endpoint_(?:memo|entr)\w*)\.resize\((.+)\)$", source, re.M)
            == [("_endpoint_memo", "ENDPOINT_MEMO_ENTRIES * Profiles.MAX_PROFILES"),
                ("_endpoint_entries", "ENDPOINT_MEMO_ENTRIES * ENDPOINT_ENTRY_WORDS"),
                ("_endpoint_entry_tags", "2 * ENDPOINT_MEMO_ENTRIES"),
                ("_endpoint_memo_stamp", "ENDPOINT_MEMO_STAMP")], "WorldRoutes endpoint memo packets")
    entries = memory.resolve(index, "underground_world_routes", "ENDPOINT_MEMO_ENTRIES")
    words = memory.resolve(index, "underground_world_routes", "ENDPOINT_ENTRY_WORDS")
    stamp = memory.resolve(index, "underground_world_routes", "ENDPOINT_MEMO_STAMP")
    profiles = memory.resolve(index, "underground_profiles", "MAX_PROFILES")
    rows = {"results": 8 * entries * profiles, "entries": 4 * entries * words, "entry_tags": 8 * 2 * entries,
            "stamp": 8 * stamp}
    return {"rows": rows, "bytes": sum(rows.values()),
            "scope": "Runtime only, never saved; allocated once with WorldRoutes' fixed scratch."}


def world_routes_compile_memos(memory, index: dict) -> dict:
    """Decision 1953: WorldRoutes' per-compile endpoint observations and per-preparation pace memo, fixed packets
    retained for the World's life (their contents live for one compile or one preparation)."""
    source = module(index, CORE + "underground_world_routes.gd").text
    require(re.findall(r"^\t(_observed_key|_pace_memo|_pace_codes|_pace_inputs)\.resize\((.+)\)$", source, re.M)
            == [("_observed_key", "2 * OBSERVED_KEY"), ("_pace_memo", "PACE_SLOTS * PACE_WORDS"),
                ("_pace_codes", "PACE_SLOTS"), ("_pace_inputs", "PACE_INPUT_WORDS")], "WorldRoutes compile memo packets")
    require("var _observed: Array[Locations.Record] = [Locations.Record.new(), Locations.Record.new()]" in source,
            "two kept observation records")
    key = memory.resolve(index, "underground_world_routes", "OBSERVED_KEY")
    slots = memory.resolve(index, "underground_world_routes", "PACE_SLOTS")
    words = memory.resolve(index, "underground_world_routes", "PACE_WORDS")
    inputs = memory.resolve(index, "underground_world_routes", "PACE_INPUT_WORDS")
    require(inputs == 2 + 2 * memory.resolve(index, "movement", "PROFILE_COUNT"), "pace input stamp words")
    record = packet(memory, index, CORE + "underground_locations.gd", "Record") + 48 + 72
    # An Array element is one Variant (24 B on the 64-bit qualification build); the StringName codes are interned.
    rows = {"observation_keys": 8 * 2 * key, "observation_slots": 24 * 2, "observation_records": 2 * record,
            "pace_words": 8 * slots * words, "pace_codes": 24 * slots, "pace_inputs": 8 * inputs}
    return {"rows": rows, "bytes": sum(rows.values()),
            "scope": "Runtime only, never saved; allocated once with WorldRoutes' fixed scratch."}


def world_routes_cold(memory, index: dict) -> dict:
    """The staged-change sides (ADR 1205) widen WorldRoutes' cold lease, which the shared cold arena admits."""
    source = module(index, CORE + "underground_world_routes.gd").text
    require("\t\tchanges.resize(Journal.STAGED_STRIDE * CHANGE_CAPACITY)" in source, "staged-change allocation")
    require("_budget.covers(cold_token, Budget.COLD_BYTES)" in source, "WorldRoutes runtime cold admission")
    stride = memory.resolve(index, "underground_geometry_journal", "STAGED_STRIDE")
    changes = 4 * stride * memory.resolve(index, "underground_geometry_journal", "CAPACITY")
    cold = memory.resolve(index, "underground_world_routes", "COLD_BYTES")
    shared = memory.resolve(index, "underground_budget", "COLD_BYTES")
    require(changes == 1792 and cold == 379648 and cold <= shared, "WorldRoutes cold lease inside the shared arena")
    return {"staged_change_bytes": changes, "world_routes_cold_bytes": cold, "shared_cold_bytes": shared}


def exact_members(memory, index: dict, relative: str, expected: dict) -> str:
    """A new owner's complete retained declaration; any added member refuses until it is counted."""
    source = module(index, relative).text
    require(memory.explicit_members(source) == expected, "unreconciled retained member: " + relative)
    return source


ENTRY_RUNTIME = {"_step": "int", "_error": "StringName", "_origin": "Vector3i", "_published": "WorkArea.Published",
                 "_storage": "Vector2i", "_output": "Vector2i", "_crew": "Foreman.Crew", "_foreman": "Foreman",
                 "_jobs": "RefCounted", "_worker_row": "int", "_transforms": "Transforms", "_anchor": "Vector3i",
                 "_walk_left": "int", "_arrival_yaw": "int", "_scratch": "IntMath.IntResult"}
ENTRY_FOREMAN = {"_owners": "Owners", "_crew": "Crew", "_tasks": "Array", "_index": "int", "_stage": "int",
                 "_stage_ticks": "int", "_job": "int", "_error": "StringName", "_content": "int",
                 "_accepted_mwu": "int", "_math": "IntMath.IntResult", "_actor": "Routes.Actor",
                 "_installer": "Installer", "_paid": "Installer.Paid", "_install_count": "int", "_install_mwu": "int",
                 "_last_install_stage": "int", "_placement": "Vector2i", "_leg_target": "Vector2i",
                 "_leg_profile": "int", "_leg_revision": "int", "_retreat": "Vector2i", "_retreat_profile": "int",
                 "_retreat_revision": "int", "_pending_retreat": "Vector2i", "_hauler": "Hauler",
                 "_haul_mwu": "int", "_haul_trips": "int", "_haul_marker": "int", "_arrival_profile": "int",
                 "_arrival_revision": "int", "_arrival_retreat": "Vector2i", "_arrival_retreat_profile": "int",
                 "_arrival_retreat_revision": "int", "_station_paths": "Callable"}
ENTRY_HAULER = {"_o": "RefCounted", "_crew": "RefCounted", "_project": "Vector2i", "_home": "int",
                "_queue": "PackedInt32Array", "_legs": "Array", "_leg": "int", "_trip": "int", "_job": "int",
                "_stage": "int", "_content": "int", "_store": "Vector2i", "_stand_source": "Vector2i",
                "_stand_store": "Vector2i", "_haul_mwu": "int", "_trips": "int", "_actor": "Routes.Actor"}
ENTRY_INSTALLER = {"_o": "RefCounted", "_crew": "RefCounted", "_paid": "Paid", "_plan": "Plan", "_content": "int",
                   "_stage": "int", "_project": "Vector2i", "_job": "int", "_accepted_mwu": "int",
                   "_math": "IntMath.IntResult", "_actor": "Routes.Actor", "_quote": "Modular.Quote",
                   "_hauler": "Hauler", "_haul_mwu": "int", "_haul_trips": "int", "_stair_leg": "int"}
STATELESS = ("underground_entry_composition", "underground_entry_site", "underground_entry_contact_path",
             "underground_entry_contact_retirement", "underground_entry_work_area", "underground_entry_progress")
PROGRESS_TERMS = ("HEADER_BYTES", "RUNTIME_FIXED_BYTES", "CREW_BYTES", "FOREMAN_FIXED_BYTES", "INSTALLER_FIXED_BYTES",
                  "HAULER_FIXED_BYTES")


def entry_progress(memory, index: dict) -> dict:
    """ADR 1218: the saved entry progress record exists only during one capture or restore. Its bound is
    recomputed from the codec's own block constants, and two whole images (the writer's and its returned copy,
    or the caller's input and the canonical re-encode) are charged as retained, conservatively."""
    source = module(index, CORE + "underground_entry_progress.gd").text
    formula = ("const MAX_WIRE_BYTES: int = HEADER_BYTES + RUNTIME_FIXED_BYTES + MAX_ENDPOINTS * 8 + CREW_BYTES + FOREMAN_FIXED_BYTES \\\n"
               "\t+ MAX_TASKS * TASK_BYTES + INSTALLER_FIXED_BYTES + MAX_QUOTE_LINES * QUOTE_LINE_BYTES \\\n"
               "\t+ HAULER_FIXED_BYTES + MAX_QUEUE * 4 + MAX_LEGS * LEG_BYTES + 3 * MAX_STAIR_LEGS * LEG_BYTES\n")
    require(formula in source, "entry progress wire bound formula")
    const = lambda name: int(re.search(r"^const " + name + r": int = (\d+)\b", source, re.M).group(1))
    wire = sum(const(name) for name in PROGRESS_TERMS) + 8 * const("MAX_ENDPOINTS") + const("MAX_TASKS") * const("TASK_BYTES") \
        + const("MAX_QUOTE_LINES") * const("QUOTE_LINE_BYTES") + 4 * const("MAX_QUEUE") + const("MAX_LEGS") * const("LEG_BYTES") \
        + 3 * const("MAX_STAIR_LEGS") * const("LEG_BYTES")
    packets = packet(memory, index, CORE + "underground_entry_progress.gd", "Writer") \
        + packet(memory, index, CORE + "underground_entry_progress.gd", "Reader")
    return {"max_wire_bytes": wire, "images": 2, "packet_numeric_bytes": packets, "bytes": 2 * wire + packets}


def entry_chain(memory, index: dict) -> dict:
    """ADR 1195-1197 first-entry runtime, retained by SettlementSystem while the entry runs (ADR 1212)."""
    for name in STATELESS:
        require(not memory.explicit_members(module(index, CORE + name + ".gd").text), "stateless entry module: " + name)
    runtime = exact_members(memory, index, CORE + "underground_entry_runtime.gd", ENTRY_RUNTIME)
    foreman = exact_members(memory, index, CORE + "underground_entry_foreman.gd", ENTRY_FOREMAN)
    installer = exact_members(memory, index, CORE + "underground_entry_installer.gd", ENTRY_INSTALLER)
    hauler = exact_members(memory, index, CORE + "underground_entry_hauler.gd", ENTRY_HAULER)
    contract = module(index, CORE + "excavation_contract.gd").text
    require("const BRACE_WOOD_MILLI: int = 250" in contract and "const BRACE_STONE_MILLI: int = 250" in contract
            and "Grip.QUANTITY_MILLI" in hauler, "haul queue bound: one whole unit per BRACE input line")
    # ADR1210: ceil(250/1000) wood + stone units; ADR1219 adds the arrival leg before the retreat and storage legs.
    # ADR1229 increment 6b: a tread order's haul climbs four stair legs before M (Progress.MAX_LEGS).
    queue, legs = 2, memory.resolve(index, "underground_entry_progress", "MAX_LEGS")
    stair_legs = memory.resolve(index, "underground_entry_progress", "MAX_STAIR_LEGS")
    counts = frontier_counts()
    endpoints = memory.resolve(index, "underground_entry_work_area", "ENDPOINTS")
    tasks = 3 * counts["EPISODE"] + counts["INSTALL"]
    actor = packet(memory, index, CORE + "underground_routes.gd", "Actor")
    result = packet(memory, index, CORE + "int_math.gd", "IntResult", "")
    quote = memory.quote_payload(index)
    rows = {
        # ADR1223: the dispatcher's one IntResult of read scratch (the Jobs-side binding is reviewed in jobs.gd's row).
        "runtime_numeric": memory.numeric_fields(runtime, "") + result,
        "work_area_published": packet(memory, index, CORE + "underground_entry_work_area.gd", "Published") + 8 * endpoints,
        "crew": packet(memory, index, CORE + "underground_entry_foreman.gd", "Crew"),
        "foreman_numeric": memory.numeric_fields(foreman, "") + result + actor,
        "foreman_tasks": tasks * packet(memory, index, CORE + "underground_entry_foreman.gd", "Task"),
        "installer_numeric": memory.numeric_fields(installer, "") + result + actor,
        "installer_plan": packet(memory, index, CORE + "underground_entry_installer.gd", "Plan"),
        # ADR1229 increment 6b: the plan's down and up stair legs, [slot, generation, profile, revision] int64 rows.
        "installer_stair_legs": 3 * stair_legs * 4 * 8, # DEC-059: the chain list too
        "installer_quote": memory.payload(quote["columns"]) + quote["numeric_control_bytes"],
        # The foreman and the installer each retain one Hauler; both are charged.
        "haulers": 2 * (memory.numeric_fields(hauler, "") + actor + 4 * queue)
            + 2 * legs * packet(memory, index, CORE + "underground_entry_hauler.gd", "Leg"),
        "progress_record": entry_progress(memory, index)["bytes"],
    }
    return {"rows": rows, "bytes": sum(rows.values()), "frontier_counts": counts, "planned_task_bound": tasks,
            "work_area_endpoints": endpoints,
            "scope": "Numeric and packed payload only. Object, Array and Variant headers (about 30 RefCounted packets and "
                     "the task and endpoint arrays) are native overhead, unmeasured, as in every other row."}


def location_air_pool(memory, index: dict) -> dict:
    """ADR 1215: the session's per-motion air pool lives in the Location banks Routes admits inside
    LOCATION_AND_TOPOLOGY_BYTES; its wire image is charged against the same unassigned remainder."""
    composition = module(index, CORE + "underground_room_composition.gd").text
    require("228 * Budget.LOCATION_CAPACITY + 256 + Locations.AIR_ARENA_BYTES_PER_SLOT * LOCATION_AIR_SLOTS)"
            in composition, "Locations arena admits exactly the session air pool")
    slots = memory.resolve(index, "underground_room_composition", "LOCATION_AIR_SLOTS")
    per_slot = memory.resolve(index, "underground_locations", "AIR_ARENA_BYTES_PER_SLOT")
    wire = memory.resolve(index, "underground_locations", "AIR_SLOT_BYTES") * slots
    n = memory.resolve(index, "underground_budget", "LOCATION_CAPACITY")
    routes = module(index, CORE + "underground_routes.gd").text
    require("return location_bytes + 180 * edges + 24 * vertices + 312 * RESIDENT_CAPACITY + 40 * links \\\n"
            "\t\t+ 12 * vertices + 33 * nodes + 48 * RESIDENT_CAPACITY + HEADER_RESERVE" in routes, "Routes arena formula")
    r = lambda name: memory.resolve(index, "underground_routes", name)
    topology = 180 * r("MAX_EDGES") + 36 * r("MAX_VERTICES") + 360 * r("RESIDENT_CAPACITY") + 40 * r("MAX_LINKS") + 33 * n + r("HEADER_RESERVE")
    banks = 228 * n + 256 + per_slot * slots
    reserve = memory.resolve(index, "underground_budget", "LOCATION_AND_TOPOLOGY_BYTES")
    require(banks + topology + wire <= reserve, "air pool exceeds LOCATION_AND_TOPOLOGY_BYTES")
    return {"slots": slots, "bank_bytes": per_slot * slots, "wire_bytes": wire,
            "routes_admission_bytes": banks + topology, "reserve_bytes": reserve,
            "remaining_bytes": reserve - banks - topology - wire}


def publication_controls(memory, index: dict) -> dict:
    """ADR 1161's Room-frontier publication control census (8,050 B reviewed), recounted for ADR 1215:
    the caller and private Requests each gain the fixed air shape, and the four Query Records gain air."""
    source = module(index, CORE + "underground_room_frontier_publication.gd").text
    request = memory.class_body(source, "Request")
    require(re.findall(r"^\t\tair\.resize\(([^)]+)\)$", request, re.M) == ["MAX_STATIONS * AIR_BOXES * 6"]
            and "var air_counts: PackedInt32Array = PackedInt32Array([0, 0, 0])" in request, "Request air shape")
    stations = memory.resolve(index, "underground_room_frontier_publication", "MAX_STATIONS")
    request_air = 4 * stations * (1 + memory.resolve(index, "underground_locations", "MAX_AIR_EXTRA")) * 6 + 4 * stations
    require(source.count("var request: Request = Request.new()") == 1 and "var input: Request = null" in source
            and source.count("Locations.Record.new()") == 2, "two Requests and four Query Records")
    controls = 8050 + 2 * request_air + 4 * 80
    ceiling = memory.resolve(index, "underground_room_frontier_publication", "CONTROL_BYTES")
    require(controls <= ceiling, "publication controls exceed CONTROL_BYTES")
    require("if CONTROL_BYTES + maxi(config.locations.cold_peak_bytes(), maxi(Face.COLD_BYTES, WorldRoutes.COLD_BYTES)) > Budget.COLD_BYTES:"
            in source, "publication control charged inside the shared cold arena at runtime")
    return {"reviewed_controls": 8050, "request_air_bytes": request_air, "record_air_bytes": 80,
            "controls": controls, "control_bytes": ceiling}


PLANNER_FORMULA = ("const CONTROL_BYTES: int = 4 * 6 * MAX_REGIONS * 4 + 2 * MAX_REGIONS * 4 + 2 * 6 * MAX_FRAGMENTS * 4 \\\n"
    "\t+ MAX_CANDIDATES * 8 + 2 * MAX_EDGES * 4 + MAX_CHAIN * (3 * 4 + 4 * 8 + 2 * 4 + 4 + AIR_BOXES * 6 * 4) \\\n"
    "\t+ MAX_PRIMITIVES * 6 * 4 + 8 * 6 * 4 + 1024\n")


def room_planner_cold(memory, index: dict) -> dict:
    """ADR 1213/1215 Room-station planner: a stateless cold query admitted inside an existing cold lease."""
    name = "underground_room_station_planner"
    source = module(index, CORE + name + ".gd").text
    require(not memory.explicit_members(source) and PLANNER_FORMULA in source
            and "Frontier._guard(actual, cold, CONTROL_BYTES, max_checks)" in source, "planner cold slice")
    clean = re.sub(r"(?m)^(const [A-Z][A-Z0-9_]*: int = [^#\n]+?)[ \t]+#.*$", r"\1", source)
    index = dict(index, **{name: audit.parse_module(name, CORE + name + ".gd", clean)})
    c = {key: memory.resolve(index, name, key) for key in
         ("MAX_REGIONS", "MAX_FRAGMENTS", "MAX_CANDIDATES", "MAX_EDGES", "MAX_CHAIN", "MAX_PRIMITIVES")}
    boxes = 1 + memory.resolve(index, "underground_locations", "MAX_AIR_EXTRA")
    total = (4 * 6 * c["MAX_REGIONS"] * 4 + 2 * c["MAX_REGIONS"] * 4 + 2 * 6 * c["MAX_FRAGMENTS"] * 4
             + c["MAX_CANDIDATES"] * 8 + 2 * c["MAX_EDGES"] * 4 + c["MAX_CHAIN"] * (56 + boxes * 24)
             + c["MAX_PRIMITIVES"] * 24 + 192 + 1024)
    shared = memory.resolve(index, "underground_budget", "COLD_BYTES")
    require(total == 45752 and total <= shared, "planner cold slice inside the shared cold arena")
    return {"control_bytes": total, "lease_bytes": shared,
            "scope": "Cold and released before publish_into admits its own lifetime in the same lease."}


def contact_retirement_cold(memory, index: dict) -> dict:
    """The retirement scope's private packets live inside the whole shared cold lease it acquires."""
    source = module(index, CORE + "underground_entry_contact_retirement_scope.gd").text
    sizes = dict(re.findall(r"^\t(_\w+)\.resize\(([^)]+)\)$", source, re.M))
    kinds = memory.explicit_members(source)
    retirement = module(index, CORE + "underground_entry_contact_retirement.gd").text
    require("var cold: int = owners.budget.acquire(Budget.COLD_BYTES)" in retirement, "retirement leases whole cold arena")
    edges = memory.resolve(index, "underground_routes", "MAX_EDGES")
    total = 0
    for name, expression in sizes.items():
        count = edges if expression == "_routes._edge_capacity" else \
            memory.resolve(index, "underground_entry_contact_retirement_scope", expression)
        total += memory.WIDTHS[kinds[name]] * count
    shared = memory.resolve(index, "underground_budget", "COLD_BYTES")
    require(total <= shared, "retirement private packets exceed the shared cold lease")
    return {"private_packet_bytes": total, "lease_bytes": shared,
            "scope": "Cold, exclusive and released; the graph/Locations candidate images it publishes through are the "
                     "owners' existing paired banks. Coexistence inside one lease is runtime-enforced, not re-proved here."}


# Decision 1972: `_carry_loaded` and `_program_count` track the optional stair-carry bank, appended into the same three
# columns; the route composition loads it at mount, so every Session retains it (decision 1972).
STAIR_MOTION = {"_programs": "PackedInt32Array", "_keys": "PackedInt32Array", "_decks": "PackedInt32Array",
                "_digest": "PackedByteArray", "_loaded": "bool", "_carry_loaded": "bool", "_program_count": "int"}


def stair_tables(memory, index: dict) -> dict:
    """ADR 1229: the claw stair tables (StairMotion), loaded once per Session by the route composition and lent to
    Routes for the Session's life. Their fixed census is the pinned wire's, recomputed from the owner's constants."""
    exact_members(memory, index, CORE + "underground_stair_motion.gd", STAIR_MOTION)
    name = "underground_stair_motion"
    words = sum(memory.resolve(index, name, fields) * memory.resolve(index, name, count) for fields, count in
                (("PROGRAM_FIELDS", "PROGRAMS"), ("KEY_FIELDS", "KEYS"), ("DECK_FIELDS", "DECKS")))
    require("const RESERVED_BYTES: int = 4 * (PROGRAM_FIELDS * PROGRAMS + KEY_FIELDS * KEYS + DECK_FIELDS * DECKS) + 32"
            in module(index, CORE + "underground_stair_motion.gd").text, "stair tables reservation")
    require("motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA)"
            in module(index, CORE + "underground_route_composition.gd").text, "one table load per route composition")
    # Decision 1972: the stair-carry bank (decision 1981's rooted rows 71-84) is appended once per Session too; its
    # profile digest is checked at load and not kept.
    carry = sum(memory.resolve(index, name, fields) * memory.resolve(index, name, count) for fields, count in
                (("PROGRAM_FIELDS", "CARRY_PROGRAMS"), ("KEY_FIELDS", "CARRY_KEYS"), ("DECK_FIELDS", "CARRY_DECKS")))
    require("motion.load_carry_file(CarryPins.WIRE_PATH, CarryPins.WIRE_SHA)"
            in module(index, CORE + "underground_route_composition.gd").text, "one carry table load per composition")
    require(4 * carry == memory.resolve(index, name, "CARRY_RESERVED_BYTES") == 33784, "stair-carry reservation")
    return {"rows": {"tables": 4 * words, "profile_digest": 32, "carry_tables": 4 * carry},
            "bytes": 4 * words + 32 + 4 * carry}


def cold_load_images(memory, index: dict) -> dict:
    """ADR 1221: the cold-load images that are not charged to the shared cold lease. Routes and WorldRoutes images
    are the caller's leased cold image; the Contacts scope and the Planner's admission record are one caller image
    each, recomputed from their codecs' own constants and charged as retained, conservatively."""
    contacts = memory.resolve(index, "underground_connector_contacts", "SCOPE_WIRE_BYTES")
    planner = memory.resolve(index, "haul_planner", "ADMISSION_WIRE_BYTES")
    require(contacts == 6 * 4 + 2 + 6 * 8, "Contacts scope image changed")
    require(planner == 12 + 24 * memory.resolve(index, "reservations", "JOB_CAPACITY"), "admission image changed")
    return {"rows": {"contact_scope": contacts, "haul_admissions": planner}, "bytes": contacts + planner}


ROOM_RUNTIME = {"_directory": "Directory", "_room_row": "PackedInt32Array", "_generation": "PackedInt32Array", "_state": "PackedByteArray",
                "_storage": "PackedInt32Array", "_output": "PackedInt32Array", "_staging": "PackedInt32Array",
                "_crew": "PackedInt32Array", "_release_out": "PackedByteArray", "_builder_rows": "PackedByteArray",
                "_filter_count": "int", "_filter_last": "int",
                "_foremen": "Array", "_foreman_rows": "PackedInt32Array", "_refusals": "Array", "_owners": "Builder.Owners",
                "_math": "IntMath.IntResult", "_face": "WorkFace", "_contact_access": "Vector2i", "_contact_travel": "int"}
ROOM_FOREMAN = {"_ctx": "Builder.Context", "_room": "Vector2i", "_builders": "Array", "_order": "DigOrder.Order",
                "_cube": "PackedByteArray", "_state": "int", "_error": "StringName", "_abandon_error": "StringName",
                "_last_refusal": "StringName", "_done": "int", "_registered": "bool", "_epoch": "int",
                "_blocked_at": "PackedInt64Array", "_blocked": "PackedByteArray", "_blocked_ticks": "int",
                "_column_tries": "int"}
ROOM_BUILDER = {"_ctx": "Context", "_crew": "Crew", "_stage": "int", "_stage_ticks": "int", "_error": "StringName",
                "_index": "int", "_site": "Vector2i", "_operation": "int", "_job": "int", "_station": "Vector2i",
                "_work_profile": "int", "_at": "Vector2i", "_legs": "PackedInt32Array", "_plan": "Claim",
                "_foot": "Footprint", "_leg_profiles": "PackedInt32Array", "_leg": "int", "_leg_state": "int",
                "_leg_job": "bool", "_finished": "int", "_cubes": "int", "_column_cubes": "int", "_accepted_mwu": "int",
                "_math": "IntMath.IntResult", "_actor": "Routes.Actor", "_tick": "Work.TickResult",
                "_queue": "PackedInt32Array", "_hauler": "Hauler", "_departed": "bool", "_haul_store": "Vector2i",
                "_haul_source": "Vector2i", "_haul_marker": "int", "_haul_trips": "int", "_haul_mwu": "int",
                "_walk": "Walk", "_failed_from": "int", "_resuming": "bool", "_release_pending": "bool"}
ROOM_CLAIM = {"home_legs": "PackedInt32Array", "home_profiles": "PackedInt32Array", "approach_legs": "PackedInt32Array",
              "approach_profiles": "PackedInt32Array", "store_legs": "PackedInt32Array", "store_profiles": "PackedInt32Array",
              "start": "Vector2i", "store": "Vector2i", "trips": "PackedInt32Array", "stands": "PackedInt32Array",
              "carries": "PackedInt32Array"}
ROOM_WALK = {"ticks_left": "int", "leaving": "bool", "origin": "Vector3i", "_math": "IntMath.IntResult"}
ROOM_FOOTPRINT = {"_profiles": "Profiles", "_boxes": "PackedInt32Array", "_body": "PackedInt32Array",
                  "_rows": "RowExtents", "_serial": "int", "_overflow": "bool"}
ROOM_ROW_EXTENTS = {"table": "PackedInt32Array", "revision": "int"}
# Decision 1937 (P-1937-1): the source facts the four engineering cuts rest on.
ROOM_SHARED_EXTENTS = ("if owners.extents == null: owners.extents = Builder.Footprint.RowExtents.new()",
                       "_foot.configure(ctx.owners.profiles, ctx.owners.extents)")
ROOM_ORDER_ROWS_ONLY = ("planned.keys.clear()", "planned.distance.clear()")
ROOM_ONE_IMAGE = ("w.bytes = out", "var c: Progress.Checker = Progress.check(bytes)")
ROOM_DISPATCH = {"_entry": "Callable", "_rooms": "Callable"}
ROOM_STATELESS = ("underground_room_composer", "underground_room_parking", "underground_room_progress",
                  "underground_room_dig_order")
ROOM_WIRE_NAMES = ("HEADER_BYTES", "CODE_BYTES", "RUNTIME_FIXED_BYTES", "ROW_BYTES", "FOREMAN_FIXED_BYTES", "SITE_BYTES",
                   "BUILDER_FIXED_BYTES", "LEG_LIST_BYTES", "TRIP_LIST_BYTES", "HAUL_PLAN_BYTES", "HAULER_BYTES",
                   "BUILDER_BYTES", "MAX_KEPT", "MAX_SITES", "MAX_BUILDERS", "MAX_WIRE_BYTES")


def room_index(index: dict) -> dict:
    """The index with the room dig's constant sources re-read without their inline comments."""
    index = dict(index)
    for name in ("underground_entry_progress", "underground_room_claim", "underground_room_runtime",
                 "underground_room_footprint", "underground_profiles", "excavation_sites", "residents"):
        source = module(index, CORE + name + ".gd")
        clean = re.sub(r"(?m)^(const [A-Z][A-Z0-9_]*: int = [^#\n]+?)[ \t]+#.*$", r"\1", source.text)
        index[name] = audit.parse_module(name, source.relative_path, clean)
    return index


def room_wire_bound(memory, index: dict) -> dict:
    """Decision 1936: the room-dig record's bound, recomputed from the codec's own constant expressions. Each is read
    whole (continuation lines joined); the only names it may use are its earlier constants and the entry codec's and
    the cube plan's, resolved from their sources; anything else refuses."""
    index = room_index(index)
    source = module(index, CORE + "underground_room_progress.gd").text
    joined = re.sub(r"\\\n\s*", " ", source)
    known = {"EntryProgress." + name: memory.resolve(index, "underground_entry_progress", name) for name in
             ("CODE_BYTES", "HAULER_FIXED_BYTES", "MAX_QUEUE", "MAX_LEGS", "LEG_BYTES")}
    known.update({"Claim." + name: memory.resolve(index, "underground_room_claim", name) for name in
                  ("MAX_LEGS", "MAX_TRIP_EDGES")})
    values = {}
    for name in ROOM_WIRE_NAMES:
        found = re.search(r"^const " + name + r": int = ([^\n#]+)", joined, re.M)
        require(found is not None, "room wire constant " + name)
        expression = found.group(1).strip()
        for key in sorted(list(known) + list(values), key=len, reverse=True):
            expression = re.sub(r"(?<![\w.])" + re.escape(key) + r"\b", str({**known, **values}[key]), expression)
        require(re.fullmatch(r"[0-9xA-Fa-f+* ()]+", expression) is not None, "room wire term " + name + ": " + expression)
        values[name] = eval(expression, {"__builtins__": {}}, {})
    require(values["MAX_KEPT"] == memory.resolve(index, "underground_room_runtime", "MAX_KEPT")
            and values["MAX_SITES"] == memory.resolve(index, "excavation_sites", "MAX_SITE_CAPACITY"),
            "room wire bounds follow the runtime and Sites")
    return values


def room_dig_runtime(memory, index: dict) -> dict:
    """Decision 1936: the room-dig runtime the host composes with the Session's room owners and retains while it is
    mounted, at its worst case for 256 residents. The record pool (MAX_KEPT slots) is allocated whole; at most
    MAX_KEPT foremen are kept,
    their orders together cover each Site at most once (one foreman a room) and each resident builds in one dig: a
    finished or stopped dig forgets each builder once it is out (`shed_crew`, decision 1937), so no resident is held
    by two foremen."""
    index = room_index(index)
    for name in ROOM_STATELESS:
        require(not memory.explicit_members(module(index, CORE + name + ".gd").text), "stateless room module: " + name)
    runtime = exact_members(memory, index, CORE + "underground_room_runtime.gd", ROOM_RUNTIME)
    foreman = exact_members(memory, index, CORE + "underground_room_foreman.gd", ROOM_FOREMAN)
    builder = exact_members(memory, index, CORE + "underground_room_builder.gd", ROOM_BUILDER)
    exact_members(memory, index, CORE + "underground_room_claim.gd", ROOM_CLAIM)
    walk = exact_members(memory, index, CORE + "underground_room_walk.gd", ROOM_WALK)
    foot = exact_members(memory, index, CORE + "underground_room_footprint.gd", ROOM_FOOTPRINT)
    require(memory.explicit_members(memory.class_body(foot, "RowExtents"), "\t") == ROOM_ROW_EXTENTS,
            "unreconciled retained member: RowExtents")
    texts = {name: module(index, CORE + name + ".gd").text for name in
             ("underground_room_runtime", "underground_room_builder", "underground_room_foreman", "underground_room_progress")}
    require(ROOM_SHARED_EXTENTS[0] in texts["underground_room_runtime"]
            and texts["underground_room_builder"].count(ROOM_SHARED_EXTENTS[1]) == 2, "one shared row-extent table")
    require(all(fact in texts["underground_room_foreman"] for fact in ROOM_ORDER_ROWS_ONLY), "dig orders keep rows only")
    require(ROOM_ONE_IMAGE[0] in texts["underground_room_progress"] and ROOM_ONE_IMAGE[1] in texts["underground_room_runtime"],
            "one record image")
    exact_members(memory, index, CORE + "underground_dispatch.gd", ROOM_DISPATCH)
    hauler = exact_members(memory, index, CORE + "underground_entry_hauler.gd", ENTRY_HAULER)
    r = lambda name, key: memory.resolve(index, name, key)
    rooms, kept, sites = r("underground_room_runtime", "ROOM_CAPACITY"), r("underground_room_runtime", "MAX_KEPT"), \
        r("excavation_sites", "MAX_SITE_CAPACITY")
    builders, legs, trips = r("residents", "RESIDENT_LIVING_CAP"), r("underground_room_claim", "MAX_LEGS"), \
        r("underground_room_claim", "MAX_TRIP_EDGES")
    boxes, profiles = r("underground_room_footprint", "MAX_BOXES"), r("underground_profiles", "MAX_PROFILES")
    queue, haul_legs = r("underground_entry_progress", "MAX_QUEUE"), r("underground_entry_progress", "MAX_LEGS")
    columns = memory.columns(index, "underground_room_runtime", 8, {}, {"_room_row", "_generation", "_state", "_storage",
                                                                       "_output", "_staging", "_crew", "_release_out"})
    # Decision 1991: each slot also names its crew (4 resident references, 32 B) and a release-once-out byte.
    require(memory.payload(columns) == 66 * kept, "the record pool is 66 B a kept record")
    result = packet(memory, index, CORE + "int_math.gd", "IntResult", "")
    actor = packet(memory, index, CORE + "underground_routes.gd", "Actor")
    b = CORE + "underground_room_builder.gd"
    rows = {
        "runtime_record": memory.payload(columns),
        "runtime_numeric": memory.numeric_fields(runtime, "") + result + 4 * kept
            + r("residents", "RESIDENT_CAPACITY") # Decision 1991 (review M7): one byte a Resident row
            + memory.numeric_fields(module(index, CORE + "underground_work_face.gd").text, ""),
        "foremen_numeric": kept * (memory.numeric_fields(foreman, "") + packet(memory, index, b, "Context")),
            "orders_and_marks": 5 * sites, # Decision 1937 (P-1937-1 E): each Site's row and mark.
        "row_extents": 24 * profiles, # P-1937-1 B: one table the builders share.
        "builders": builders * (memory.numeric_fields(builder, "") + packet(memory, index, b, "Context")
            + packet(memory, index, b, "Crew") + packet(memory, index, b, "HaulCrew") + result + actor
            + packet(memory, index, CORE + "work.gd", "TickResult", "")
            + 9 # the foreman's blocked epoch (8) and flag (1) for it
            + 4 * (3 * legs + legs) + 4 * queue # its current legs and profiles, and its haul queue
            + memory.numeric_fields(module(index, CORE + "underground_room_claim.gd").text, "")
            + 4 * (3 * 3 * legs + 3 * trips + 4 + 2) # the cube plan's three leg lists, trip edges, stands, carries
            + memory.numeric_fields(foot, "") + 24 * boxes + 24 # footprint and body
            + memory.numeric_fields(walk, "") + result
            + memory.numeric_fields(hauler, "") + actor
            + haul_legs * packet(memory, index, CORE + "underground_entry_hauler.gd", "Leg")),
    }
    wire = room_wire_bound(memory, index)
    require(wire["MAX_BUILDERS"] == builders, "the record's builder bound is the living cap")
    packets = packet(memory, index, CORE + "underground_entry_progress.gd", "Writer") \
        + packet(memory, index, CORE + "underground_entry_progress.gd", "Reader")
    rows["progress_record"] = wire["MAX_WIRE_BYTES"] + packets # P-1937-1 C: one image, checked in place.
    return {"rows": rows, "bytes": sum(rows.values()), "wire": wire,
            "bounds": {"rooms": rooms, "kept_foremen": kept, "sites": sites, "builders": builders, "boxes": boxes,
                       "profile_rows": profiles},
            "scope": "Numeric and packed payload only, at every bound at once (MAX_KEPT foremen, every Site in an order, "
                     "256 builders each with a full plan, footprint and haul). Object, Array and Variant headers are "
                     "native overhead, unmeasured, as in every other row. The record is one image (decision 1937): a capture "
                     "writes into the caller's buffer and a restore checks its re-encode against the record in place."}


def reviewed_table() -> dict:
    raw = (ROOT / REVIEWED).read_bytes()
    require(hashlib.sha256(raw).hexdigest() == REVIEWED_SHA, "reviewed delta table changed")
    return json.loads(raw)


def projected_deltas(index: dict, projected: list, table: dict) -> dict:
    """Every projected input's storage delta must equal its reviewed row, and no reviewed row may go unused."""
    rows = table["inputs"]
    require(sorted(projected) == sorted(rows), "projected inputs and reviewed rows differ: "
            + json.dumps(sorted(set(projected) ^ set(rows))))
    projection = json.loads((ROOT / EVIDENCE / "projection.json").read_text())["inputs"]
    for relative, row in rows.items():
        if not relative.endswith(".gd"):
            require(row["delta"] is None, "data input carries no storage delta: " + relative)
            continue
        before = (ROOT / projection[relative]["locator"]).read_text()
        after = module(index, relative).text
        require(json.loads(json.dumps(delta(before, after))) == row["delta"], "unreviewed storage delta: " + relative)
    return rows


def build(index: dict, projected: list, motion: dict) -> dict:
    """The current-source half of the joint pack: reviewed deltas plus every newly mounted owner."""
    import underground_memory_budget as memory
    index = dict(index)
    for name in ("underground_geometry_journal", "underground_world_routes", "underground_entry_work_area",
                 "underground_entry_contact_retirement_scope", "underground_budget", "underground_routes",
                 "underground_locations", "underground_room_composition", "underground_room_frontier_publication"):
        # The shared audit parser keeps inline comments; read integer declarations without them.
        source = module(index, CORE + name + ".gd")
        clean = re.sub(r"(?m)^(const [A-Z][A-Z0-9_]*: int = [^#\n]+?)[ \t]+#.*$", r"\1", source.text)
        index[name] = audit.parse_module(name, source.relative_path, clean)
    rows = projected_deltas(index, projected, reviewed_table())
    session = module(index, CORE + "underground_session.gd").text
    # The reviewed Session census proved the Domain is borrowed; a copy is not a storage-shape change, so
    # the projection would not see it. Keep that one semantic contract on the current source.
    require(re.findall(r"^\t_domain = (.+?)(?:\s+#[^\n]*)?$", session, re.M)
            == ["Space.Domain.new()", "_space._domain", "null"],
            "Session must borrow the Owner's Domain")
    journals = journal(memory, index)
    locations = locations_controls(memory, index)
    entry = entry_chain(memory, index)
    controls = world_routes_controls(memory, index)
    cold = world_routes_cold(memory, index)
    retirement = contact_retirement_cold(memory, index)
    pool = location_air_pool(memory, index)
    publication = publication_controls(memory, index)
    planner = room_planner_cold(memory, index)
    images = cold_load_images(memory, index)
    stairs = stair_tables(memory, index)
    rooms = room_dig_runtime(memory, index)
    endpoint = world_routes_endpoint_memo(memory, index)
    compile_memos = world_routes_compile_memos(memory, index)
    new = {"geometry_journals": journals["bytes"], "locations_carry_and_retirement_controls": locations["bytes"],
           "first_entry_runtime_chain": entry["bytes"], "cold_load_images": images["bytes"],
           "claw_stair_tables": stairs["bytes"], "room_dig_runtime": rooms["bytes"],
           "world_routes_endpoint_memo": endpoint["bytes"], "world_routes_compile_memos": compile_memos["bytes"]}
    charged = {}
    for relative, row in rows.items():
        for charge in row["charges"]:
            charged.setdefault(charge["carried_by"], 0)
            charged[charge["carried_by"]] += charge["bytes"]
    require(charged.get("new contribution", 0) == journals["bytes"] + locations["bytes"],
            "reviewed new-contribution rows disagree with the recount")
    require(motion["joint"]["total"] + 1536 + 8192 <= 282624, "PROFILE_BYTES joint") # ADR1217 step 5; decision 1972
    return {"scope": __doc__.strip().splitlines()[0], "reviewed_inputs": rows, "charged_by_carrier": charged,
            "geometry_journals": journals, "locations_controls": locations, "first_entry_runtime": entry,
            "world_routes_controls": controls, "world_routes_cold": cold, "contact_retirement_cold": retirement,
            "location_air_pool": pool, "room_publication_controls": publication,
            "room_planner_cold": planner, "cold_load_images": images, "claw_stair_tables": stairs,
            "room_dig_runtime": rooms, "world_routes_endpoint_memo": endpoint, "world_routes_compile_memos": compile_memos,
            "new_retained_bytes": new, "new_contribution_bytes": sum(new.values()),
            "runtime_qualified": False, "native_measured": False}

