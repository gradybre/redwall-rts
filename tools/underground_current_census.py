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
REVIEWED_SHA = "dc8ebdea728a436d2393e7df2bdf94feae83a09d64f9c6cfb27fce27658c3e42"
# ADR1217 step 5: the runtime Frontier is the claw bundle's (same row census as qualified-stone-v5's).
# ADR1229: the mounted T1-T6 bundle's Frontier (ADR1217 step 5 mounted qualified-claw-v6's).
FRONTIER = Path("godot/data/underground/first-entry-prefix-v1/qualified-stairs-v8/frontier.ugfront")
FRONTIER_SHA = "fcbd4a0719bd2752b08957908025d50efaacdf7032a313e406bc1828ccb4eff3"
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
    numeric = sum(WIDTH[kind] for kind in added.values()) + 4 * 6
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
    fixed = memory.numeric_fields(source, "") + 4 * sum(int(count) for _, count in small) + sum(packets.values())
    reserve = memory.resolve(index, "underground_world_routes", "CONTROL_RESERVE")
    require(fixed <= reserve, "WorldRoutes controls exceed CONTROL_RESERVE")
    return {"numeric_bytes": memory.numeric_fields(source, ""), "small_packed_bytes": 4 * sum(int(c) for _, c in small),
            "packet_numeric_bytes": packets, "fixed_bytes": fixed, "control_reserve_bytes": reserve,
            "added_by_adr_1205_bytes": 24 + 4 * 8 + 2}


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
                   "_hauler": "Hauler", "_haul_mwu": "int", "_haul_trips": "int"}
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
               "\t+ HAULER_FIXED_BYTES + MAX_QUEUE * 4 + MAX_LEGS * LEG_BYTES\n")
    require(formula in source, "entry progress wire bound formula")
    const = lambda name: int(re.search(r"^const " + name + r": int = (\d+)\b", source, re.M).group(1))
    wire = sum(const(name) for name in PROGRESS_TERMS) + 8 * const("MAX_ENDPOINTS") + const("MAX_TASKS") * const("TASK_BYTES") \
        + const("MAX_QUOTE_LINES") * const("QUOTE_LINE_BYTES") + 4 * const("MAX_QUEUE") + const("MAX_LEGS") * const("LEG_BYTES")
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
    queue, legs = 2, 3
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


STAIR_MOTION = {"_programs": "PackedInt32Array", "_keys": "PackedInt32Array", "_decks": "PackedInt32Array",
                "_digest": "PackedByteArray", "_loaded": "bool"}


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
    return {"rows": {"tables": 4 * words, "profile_digest": 32}, "bytes": 4 * words + 32}


def cold_load_images(memory, index: dict) -> dict:
    """ADR 1221: the cold-load images that are not charged to the shared cold lease. Routes and WorldRoutes images
    are the caller's leased cold image; the Contacts scope and the Planner's admission record are one caller image
    each, recomputed from their codecs' own constants and charged as retained, conservatively."""
    contacts = memory.resolve(index, "underground_connector_contacts", "SCOPE_WIRE_BYTES")
    planner = memory.resolve(index, "haul_planner", "ADMISSION_WIRE_BYTES")
    require(contacts == 6 * 4 + 2 + 6 * 8, "Contacts scope image changed")
    require(planner == 12 + 24 * memory.resolve(index, "reservations", "JOB_CAPACITY"), "admission image changed")
    return {"rows": {"contact_scope": contacts, "haul_admissions": planner}, "bytes": contacts + planner}


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
    new = {"geometry_journals": journals["bytes"], "locations_carry_and_retirement_controls": locations["bytes"],
           "first_entry_runtime_chain": entry["bytes"], "cold_load_images": images["bytes"],
           "claw_stair_tables": stairs["bytes"]}
    charged = {}
    for relative, row in rows.items():
        for charge in row["charges"]:
            charged.setdefault(charge["carried_by"], 0)
            charged[charge["carried_by"]] += charge["bytes"]
    require(charged.get("new contribution", 0) == journals["bytes"] + locations["bytes"],
            "reviewed new-contribution rows disagree with the recount")
    require(motion["joint"]["total"] + 1536 + 8192 <= 278528, "PROFILE_BYTES joint") # ADR1217 step 5
    return {"scope": __doc__.strip().splitlines()[0], "reviewed_inputs": rows, "charged_by_carrier": charged,
            "geometry_journals": journals, "locations_controls": locations, "first_entry_runtime": entry,
            "world_routes_controls": controls, "world_routes_cold": cold, "contact_retirement_cold": retirement,
            "location_air_pool": pool, "room_publication_controls": publication,
            "room_planner_cold": planner, "cold_load_images": images, "claw_stair_tables": stairs,
            "new_retained_bytes": new, "new_contribution_bytes": sum(new.values()),
            "runtime_qualified": False, "native_measured": False}

