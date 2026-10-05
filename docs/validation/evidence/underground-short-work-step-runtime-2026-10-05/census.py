#!/usr/bin/env python3
"""1168 complete logical source/helper coexistence; native interpreter allocations remain provisional."""
from __future__ import annotations
import ast
import hashlib
import json
from pathlib import Path
import re
import types

ROOT = Path(__file__).resolve().parents[4]
E = Path(__file__).resolve().parent
PINS = {
    "docs/validation/evidence/underground-work-approach-2026-10-04/census.py": "dc9ae8a01583d44391ef95ae9b0314064dd6ac6ea6a38a8164f83bba39019b75",
    "docs/validation/evidence/underground-room-itinerary-census-2026-10-05/census.py": "c4a4d714b85806db0eb6d670fd2284753c70bcf7bf070bf7863114b5df04d708",
    "docs/validation/evidence/underground-ground-turn-2026-10-04/census.py": "3d531ce5ba7329ffd8641344304f42abd2c952cb87b86e2425e24fa08e15d278",
}
PREDECESSOR_SHA = "30a9b190e543e30dbe53f9c1b42f15a29878788bbaa91bc52703bd63693a31c1"
CALL_CONTRACT_SHA = "ab3d24c07a7e8fcca8c259dace66399282081bee5bc01f4e67f7175585ad7475"
P = "underground_profiles"
R = "underground_routes"
W = "underground_world_routes"
D = "mole_profile_driver"
S = "short_program"
NONCORE = {
    D: "godot/data/underground/mole-worker/mole_profile_driver.gd",
    "source_program": "godot/data/underground/mole-worker/work-approach-v1/source_program.gd",
    S: "godot/data/underground/mole-worker/work-step-v1/source_program.gd",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def path(module):
    return ROOT / NONCORE.get(module, "godot/scripts/core/" + module + ".gd")


def load(relative, name):
    raw = (ROOT / relative).read_bytes()
    require(sha(raw) == PINS[relative], "immutable census producer changed")
    imports = []
    for node in ast.walk(ast.parse(raw)):
        if isinstance(node, ast.Import): imports.extend(n.name for n in node.names)
        elif isinstance(node, ast.ImportFrom): imports.append(node.module)
    require(set(imports) <= {"__future__", "argparse", "ast", "hashlib", "importlib", "importlib.util",
                           "importlib.machinery", "json", "pathlib", "re", "subprocess", "textwrap"}, "census import closure")
    module = types.ModuleType(name)
    module.__file__ = str(ROOT / relative)
    exec(compile(raw, module.__file__, "exec", optimize=0), module.__dict__)
    return module


L = load(next(k for k in PINS if "work-approach" in k), "_reviewed_profile_census")
A = load(next(k for k in PINS if "itinerary" in k), "_reviewed_frame_parser")
T = load(next(k for k in PINS if "ground-turn" in k), "_reviewed_turn_paths")
A.ROOT, A.E, A.path = ROOT, E, path
A.NATIVE |= {"has", "find"} # Existing bounded packed/member lookups, no new container.
A.BUILTINS |= {"String", "StringName"} # Existing Terrain/Resident conversion frames remain explicitly native/provisional.


class Audit(A.Audit):
    """Keep two equally named source_program files distinct; resolve nested Script aliases explicitly."""
    def _scope(self, module, scope, source, aliases):
        aliases = dict(aliases)
        original = self.sources[module]
        for name, relative in re.findall(r'^const (\w+)\s*:?= preload\("res://([^"\n]+)"\)', original, re.M):
            if relative.endswith("work-step-v1/source_program.gd"):
                aliases[name] = S
        super()._scope(module, scope, source, aliases)
        # Retain complete code for lexical closure. The older generic parser
        # deliberately strips comments with a regex; that must not erase a '#'
        # inside a real String/collection literal from this allocation guard.
        lines = source.splitlines()
        for start, line in enumerate(lines):
            hit = re.match(r'^(?:static )?func (\w+)\(', line)
            if not hit: continue
            end = start + 1
            while end < len(lines) and (not lines[end].strip() or lines[end].startswith(('\t', ' ', ')'))):
                end += 1
            self.functions[scope+":"+hit[1]]["raw_body"] = "\n".join(lines[start:end])

    def method(self, key, expression):
        parts = expression.split(".")
        scope = self.functions[key]["scope"]
        if len(parts) == 3 and parts[0] in self.scopes[scope]["aliases"]:
            module = self.scopes[scope]["aliases"][parts[0]]
            self.load(module)
            target = self.scopes[module]["aliases"].get(parts[1])
            if target is not None:
                self.load(target)
                return target + ":" + parts[2] if target + ":" + parts[2] in self.functions else None
        return super().method(key, expression)


def predecessors():
    raw = (E / "supporting/predecessors.json").read_bytes()
    require(sha(raw) == PREDECESSOR_SHA, "predecessor manifest changed")
    data = json.loads(raw)
    require(set(data["sources"]) == {P, R, W, D}, "predecessor module set")
    result = {}
    for name, row in data["sources"].items():
        raw = (E / row["snapshot"]).read_bytes()
        require(sha(raw) == row["sha256"] and row["path"] == str(path(name).relative_to(ROOT)), "predecessor bytes changed")
        result[name] = raw.decode()
    return data["base"], result


def const_payload(source):
    ints = re.findall(r'^const (\w+): int = ([^\n]+)$', source, re.M)
    strings = re.findall(r'^const (\w+): String = "([^"\n]+)"$', source, re.M)
    declarations = re.findall(r'^const \w+[^\n]*$', source, re.M)
    borrowed = [line for line in declarations if 'preload("res://' in line]
    require(len(declarations) == len(ints) + len(strings) + len(borrowed), "unaccounted SourceProgram constant")
    return {"integer_constants": len(ints), "integer_bytes": 8 * len(ints),
            "UTF32_characters_and_terminators": sum(len(value) + 1 for _, value in strings),
            "string_bytes": 4 * sum(len(value) + 1 for _, value in strings),
            "numeric_payload": 8 * len(ints) + 4 * sum(len(value) + 1 for _, value in strings),
            "borrowed_script_aliases": borrowed}


def tokens(source):
    """Preserve complete literal bytes; discard only whitespace and real comments."""
    pattern = r'"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|\#[^\n]*|[A-Za-z_]\w*|\d+|[^\s]'
    return [token for token in re.findall(pattern, source) if not token.startswith("#")]


def collection_literals(source):
    """Distinguish literal '[' from indexing/type syntax and retain every nested payload.

    The complete raw-body token hash below also closes multiplication, slicing,
    concatenation, alias calls and other expression changes outside the literal.
    """
    lex = tokens(source)
    result = []
    keywords = {"return", "in", "if", "else", "elif", "and", "or", "not", "match"}
    for index, token in enumerate(lex):
        if token not in ("[", "{"): continue
        before = lex[index-1] if index else ""
        if token == "[" and (before in (")", "]") or
                (re.fullmatch(r'[A-Za-z_]\w*', before) and before not in keywords)):
            continue
        stack, end = [token], index + 1
        while stack and end < len(lex):
            value = lex[end]
            if value in ("[", "{", "("): stack.append(value)
            elif value in ("]", "}", ")"):
                require(stack[-1] == {"]":"[", "}":"{", ")":"("}[value], "unbalanced collection syntax")
                stack.pop()
            end += 1
        require(not stack, "unterminated collection literal")
        result.append(lex[index:end])
    return result


def call_contract(audit, measured):
    """Freeze declared frames and complete call expressions, including duplicate calls.

    This portable witness does not infer a new branch is covered merely because
    its callee already exists elsewhere in the repository.
    """
    modules = (P, R, W, D, "source_program", S)
    owned = {module: sorted(k for k,v in audit.functions.items() if v["module"] == module)
             for module in modules}
    keys = set(measured) | {k for rows in owned.values() for k in rows}
    return {"owned_function_names": owned,
        "owned_module_tokens_sha256":{module:sha(json.dumps(tokens(audit.sources[module])).encode()) for module in modules},
        "functions": {key:{
        "numeric_fields":audit.functions[key]["numeric_fields"],
        "borrowed_or_interned":audit.functions[key]["borrowed_or_interned"],
        "complete_code_tokens_sha256":sha(json.dumps(tokens(audit.functions[key]["raw_body"])).encode()),
        "calls":re.findall(r'(?<![\w.])([A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)\s*\(', audit.functions[key]["code"])
        } for key in sorted(keys)}}


def build(overrides=None):
    base, old = predecessors()
    audit = Audit(overrides)
    for module in (P, R, W, D, "source_program", S): audit.load(module)
    retained = {}
    for module in (P, R, W, D):
        before, now = old[module], audit.sources[module]
        require(L.members(before) == L.members(now), "retained field topology " + module)
        bases = lambda text: re.findall(r'^(?:extends .+|class \w+(?: extends [\w.]+)?:)$', text, re.M)
        require(bases(before) == bases(now), "inherited storage " + module)
        resizes = lambda text: re.findall(r'\b(\w+)\.resize\(([^\n]*)', text)
        require(resizes(before) == resizes(now), "packed resize topology " + module)
        # Reject a new temporary constructor or copy even if no retained field or resize changes.
        allocs = lambda text: re.findall(r'\b(?:Packed\w+Array|Array|Dictionary)\s*\(|\.new\(|\.duplicate\(', A.executable(text))
        require(allocs(before) == allocs(now), "temporary allocation topology " + module)
        require(collection_literals(before) == collection_literals(now), "collection literal allocation topology " + module)
        retained[module] = {"member_count": len(L.members(now)), "numeric_or_packed_delta": 0,
                            "resize_calls": resizes(now), "constructor_copy_calls": len(allocs(now))}
    for module, constants in {P:{"I32_FIELDS":18,"I64_FIELDS":3,"BYTE_FIELDS":2,"PROFILE_WIRE_BYTES":98},
                              R:{"RESIDENT_FIELDS":27,"RESIDENT_LONGS":6}}.items():
        for name, value in constants.items():
            require(re.search(r'^const '+name+r': int = '+str(value)+r'$', audit.sources[module], re.M),
                    "reviewed packed field width " + module + ":" + name)
    source_payloads = {}
    for module in ("source_program", S):
        source = audit.sources[module]
        require(source.startswith("extends RefCounted\n") and not L.members(source), "SourceProgram retained state")
        require(not re.search(r'Packed\w+Array\(|\.(?:new|duplicate|resize|hex_decode)\(', A.executable(source)), "SourceProgram allocation")
        require(not collection_literals(source), "SourceProgram collection allocation")
        source_payloads[module] = const_payload(source)
    require(source_payloads["source_program"]["numeric_payload"] == 648 and
            source_payloads[S]["numeric_payload"] == 348, "reviewed SourceProgram constant capacity")
    require(sha(audit.sources["source_program"].encode()) == "bc79fbe61bfd23641d6602070d132df724f9975ac36c1555cef701b14d6ab2c4", "unchanged programme5")

    def frame(key):
        audit.load(key.split(":")[0])
        require(key in audit.functions, "missing frame " + key)
        return audit.functions[key]["numeric_bytes"]

    def chain(keys):
        return {"chain": keys, "declared_numeric_bytes": sum(frame(key) for key in keys), "expression_return_allowance": 48}

    hot = {name: chain(keys) for name, keys in L.PATHS.items()}
    # The new profile/clock checks occur after the dynamic observer returns. They
    # coexist with the actual outer caller, not with already returned query frames.
    for label, prefix in {
        "admit_new_source": [R+":admit_travel_actor", R+":_admit_actor", R+":_qualify_actor_at"],
        "refresh_new_source": [R+":refresh_travel_actor", R+":_refresh_actor", R+":_qualify_actor_at"],
        "driver_new_source": [D+":read_route_into", D+":_canonical_profile_refusal"],
    }.items():
        keys = prefix + ([R+":_source_profile_refusal"] if label != "driver_new_source" else [])
        hot[label] = chain(keys + [S+":profile_refusal", S+":_actor_refusal"])
    hot["short_request"] = chain([R+":request_route", R+":_short_path_refusal", S+":span_refusal"])
    hot["short_actual_mask"] = chain([W+":edge_refusal", W+":_compile_edge", W+":_profile_edge_refusal", S+":span_refusal"])
    hot["driver_new_frames"] = chain([D+":read_route_into", D+":_source_route_frames", S+":mapped"])

    # Actual moving callbacks still own their outer numeric frames while another
    # Resident's current source/load is read. Do not substitute the shallower
    # stationary/admission query lifetime or add already-returned observations.
    moving = [R+":advance_tick", R+":_advance_actor", R+":_compute_motion",
              R+":_advance_motion_segment", R+":_motion_segment_refusal",
              W+":motion_refusal", W+":_motion_refusal", W+":_moving_box_refusal"]
    occupant = moving + [R+":occupancy_refusal", R+":_query_occupants",
                         R+":_query_cell", R+":_occupant_refusal"]
    query = [R+":_current_profile_into", R+":_actor_profile_into", P+":query_travel_profile_into",
             P+":_prepare_query", P+":_read_dynamic"]
    for label, tail in (("cargo", L.CARGO), ("tool", L.TOOL)):
        hot["moving_occupant_"+label] = chain(occupant + query + tail)
        hot["moving_selection_"+label] = chain([R+":advance_tick", R+":_advance_actor",
            R+":_prepare_motion", R+":_select_motion_profile", R+":_edge_profile_into"] + query[1:] + tail)
        hot["moving_final_"+label] = chain([R+":advance_tick", R+":_advance_actor",
            R+":_final_motion_refusal", R+":_edge_profile_into"] + query[1:] + tail)
    # The existing live Terrain path is sequential with the occupant query.
    hot["moving_foundation"] = chain(moving + ["underground_terrain:exclusions_refusal",
        "underground_terrain:_local_tiles_refusal", "underground_terrain:_local_tile",
        "underground_terrain:_local_building", "underground_terrain:_building_extent",
        "buildings:spatial_identity_into", "buildings:_building_row_of",
        "entity_directory:get_typed_row", "entity_directory:is_valid",
        "entity_directory:is_valid_of_kind"])

    pure = {}
    for key in (R+":source_work_leaf_refusal", R+":source_ready_leaf_refusal", R+":actor_phase_in",
                R+":source_state_leaf_into", W+":_turn_actor_scope", W+":_reach_stores_refusal",
                W+":_turn_final", W+":workpiece_occupancy_refusal"):
        audit.visit(key)
        require(not any(audit.unresolved.values()), "unresolved static child " + str({k:v for k,v in audit.unresolved.items() if v}))
        longest = audit.longest(key)
        pure[key] = longest | {"expression_return_allowance": 48}
    audit.visit(R+":_source_clock_leaf")
    hot["moving_occupant_clock"] = chain(occupant + [R+":read_actor_into"] +
                                         audit.longest(R+":_source_clock_leaf")["chain"])
    turns = {name: chain([key.replace(P+":query_into", P+":query_travel_profile_into") for key in keys])
             for name, keys in T.PATHS.items()}
    prefix = [W+":turn_actor", W+":_turn_run"]
    for name, key in (("canonical_source_scope", W+":_turn_actor_scope"), ("final_static", W+":_turn_final")):
        turns[name] = chain(prefix + pure[key]["chain"])
    require(max(row["declared_numeric_bytes"] + 48 for row in turns.values()) <= 512, "WorldRoutes512 helper overflow")
    require(max(row["bytes"] + 48 for key, row in pure.items() if key.startswith(R+":")) <= 512, "Routes pure512 helper overflow")

    # Profile loading has the same record widths and sequential read buffers.
    cold = {P+":"+name: frame(P+":"+name) for name in L.COLD}
    cold_numeric = sum(cold.values()) + 48
    cold_payload = {"header":32,"header_slice":8,"header_ascii":32,"source_old_new":64,
                    "profile_old_new":196,"box_old_new":56,"footer":8,"footer_ascii":32,
                    "hash_result":32,"hex_string":256,"expected_lowercase":256,"key_literal":16}
    require(sum(cold_payload.values()) == 988, "Profile complete decode payload")
    fixed = sum(L.WIDTH.get(t,0) for k,t in L.members(audit.sources[P]).items() if k.startswith(("module.", "Selection.")))
    fixed += 64 + 9 + 12 + 40
    require(fixed == 326, "existing Profile packets")
    profile_constants = len(re.findall(r'^const \w+: int = ',audit.sources[P],re.M))*8 + 8
    hot_peak = max([row["declared_numeric_bytes"] + 48 for row in hot.values()] + [row["bytes"]+48 for row in pure.values()])
    payload = sum(row["numeric_payload"] for row in source_payloads.values())
    counted = fixed + payload + profile_constants + 16 + max(hot_peak, cold_numeric + 1024)
    require(counted <= 4096, "Profile4096 logical control overflow")
    wire = (E/"profile-diagnostic-1/mole-worker.ugprof").read_bytes()
    require(sha(wire) == "830ee531a432f9cef8a24a85f1c017be21253301bc46bf55e0a6b97807a4ec4e", "actual diagnostic source rows")
    paired = 2*(29*98+271*28+32+32)
    require(paired == 20988 and paired - 19224 == 1764, "paired source delta")
    # Current accepted root joint terms, not independent maximum configurations.
    # Session and all 1163/1167/1171 owner composition use the one retained 8192
    # retirement contribution; this packet cannot duplicate that reservation.
    joint = {"paired_profiles": paired, "profile_controls":32768, "levels":2292,
             "paired_motion":141720, "motion_decode":4096, "motion_caller":176,
             "motion_logical_helper":4096, "motion_native_provisional":32768,
             "session":1536, "retirement_and_composition":8192}
    require(sum(joint.values()) == 248632 and sum(joint.values()) <= 262144, "joint Profile arena")
    measured = {k for k in audit.functions if k in audit.edges or
        any(k in row["chain"] for row in list(hot.values())+list(turns.values()))}
    contract = call_contract(audit, measured)
    raw_contract = (E / "supporting/call-contract.json").read_bytes()
    require(sha(raw_contract) == CALL_CONTRACT_SHA, "immutable call contract changed")
    require(json.loads(json.dumps(contract)) == json.loads(raw_contract), "unreviewed numeric frame or nested call")
    return {"base":base,"retained":retained,"source_programs_counted_once":source_payloads,
        "hot_paths":hot,"pure_static_paths":pure,"actual_turn_paths":turns,
        "frames":{k:A.frame_summary(audit,k) for k in sorted(measured)},
        "call_contract":{"sha256":CALL_CONTRACT_SHA,"functions":len(contract["functions"]),
                         "path":"supporting/call-contract.json"},
        "static_call_edges":audit.edges,"native_calls":audit.native,
        "profile_control":{"existing_fixed_packets":fixed,"complete_constant_payloads":payload,
            "Profile_integer_and_NULL_constants":profile_constants,"two_driver_version_constants":16,
            "complete_hot_numeric_peak":hot_peak,"cold_numeric":cold_numeric,"cold_frames":cold,
            "cold_payloads":cold_payload,"cold_payload_ceiling":1024,
            "counted_logical":counted,"logical_slice":4096,"unchanged_control_reservation":32768,
            "remaining_provisional_native_slice":28672},
        "paired_profiles":{"profiles":29,"boxes":271,"sources":1,"bytes":paired,"predecessor_bytes":19224,"delta":1764},
        "joint":{"terms":joint,"total":sum(joint.values()),"reservation":262144,
                 "remaining":262144-sum(joint.values()),"predecessor_total":246868,
                 "production_publication_and_shared_census":"root-owned integration prerequisite"},
        "source_sha256":{str(path(k).relative_to(ROOT)):sha(v.encode()) for k,v in sorted(audit.sources.items())},
        "new_actor_columns":0,"new_banks":0,"native_memory_qualified":False,
        "scope":"Complete source clock and changed-call helpers; World/graph/Space banks, existing dynamic Profile query and turn scratch are reused. Provider/Itinerary callers and root-owned joint admission require their independent integration census."}


if __name__ == "__main__":
    print(json.dumps(build(), indent=2))
