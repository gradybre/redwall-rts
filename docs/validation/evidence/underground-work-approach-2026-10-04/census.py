#!/usr/bin/env python3
"""1156 logical source census, including existing caller frames; never a native RAM measurement."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[4]
BASE = "84acf74036484bd8ec4930895b7d0a96f8567937"
WIDTH = {"int": 8, "bool": 1, "Vector2i": 8, "Vector3i": 12}
EXISTING = ["underground_profiles", "underground_routes", "underground_world_routes", "mole_profile_driver"]


def path(module):
    if module in ("source_program", "mole_profile_driver"):
        return ROOT / "godot/data/underground/mole-worker" / ("work-approach-v1/source_program.gd" if module == "source_program" else "mole_profile_driver.gd")
    return ROOT / "godot/scripts/core" / (module + ".gd")


def source(module, old=False):
    file = path(module)
    return subprocess.check_output(["git", "show", BASE + ":" + str(file.relative_to(ROOT))], cwd=ROOT, text=True) if old else file.read_text()


def members(text):
    result = {}
    scope = "module"
    for line in text.splitlines():
        match = re.match(r"^class (\w+)(?: extends [\w.]+)?:", line)
        if match:
            scope = match[1]
        elif line.strip() and not line.startswith(("\t", " ", "#")):
            scope = "module"
        declared = re.match(r"^(\t?)var (\w+)\b", line)
        match = re.match(r"^(\t?)var (\w+): ([\w.]+)", line)
        if declared and ((scope == "module" and not declared[1]) or (scope != "module" and declared[1])):
            assert match is not None, ("untyped retained member", line)
        if match and ((scope == "module" and not match[1]) or (scope != "module" and match[1])):
            assert scope + "." + match[2] not in result, ("duplicate retained member", line)
            result[scope + "." + match[2]] = match[3]
    return result


def function(key, old=False):
    module, name = key.split(":")
    text = source(module, old)
    start = re.search(r"^(?:static )?func " + re.escape(name) + r"\(", text, re.M)
    if start is None:
        return None
    following = re.search(r"^(?:static )?func ", text[start.end():], re.M)
    return text[start.start():start.end() + following.start() if following else len(text)]


def frame(key, old=False):
    body = function(key, old)
    if body is None:
        return None
    fields = re.findall(r"(\w+)\s*:\s*([\w.]+)", body[:body.index("->")])
    fields += re.findall(r"\b(?:var|for) (\w+)\s*:\s*([\w.]+)", body)
    return {"numeric_bytes": sum(WIDTH.get(kind, 0) for _, kind in fields),
            "numeric_values": [[name, kind] for name, kind in fields if kind in WIDTH],
            "borrowed_native_or_interned": [[name, kind] for name, kind in fields if kind not in WIDTH]}


QUERY = ["underground_routes:_qualify_actor_at", "underground_routes:_actor_profile_into",
         "underground_profiles:query_travel_profile_into", "underground_profiles:_prepare_query", "underground_profiles:_read_dynamic"]
TOOL = ["underground_profiles:_read_tool", "gear:owner_of", "gear:_resolve_row", "gear:_resolve_row_by_lot_slot"]
CARGO = ["underground_profiles:_read_cargo", "haul_carry:carried_lot", "haul_carry:satchel_of",
         "haul_carry:_owns_live_satchel", "inventory:is_satchel", "inventory:is_container_valid"]
PURE = ["underground_routes:_source_tuple_row", "underground_routes:_source_clock_leaf",
        "source_program:profile_refusal", "underground_profiles:selection_policy_leaf"]
TICK = ["underground_routes:advance_tick", "underground_routes:_advance_actor", "underground_routes:_advance_stationary_source"]
PATHS = {
    "admit_cargo": ["underground_routes:admit_travel_actor", "underground_routes:_admit_actor"] + QUERY + CARGO,
    "admit_tool": ["underground_routes:admit_travel_actor", "underground_routes:_admit_actor"] + QUERY + TOOL,
    "refresh_cargo": ["underground_routes:refresh_travel_actor", "underground_routes:_refresh_actor"] + QUERY + CARGO,
    "stationary_tick_cargo": TICK + QUERY + CARGO,
    "stationary_tick_tool": TICK + QUERY + TOOL,
    "stationary_clock_commit": TICK + ["source_program:advance", "source_program:work_duration"],
    "root_source_commit": ["underground_routes:advance_tick", "underground_routes:_advance_actor", "underground_routes:_commit_motion", "underground_routes:_advance_source_motion_clock", "source_program:clock"],
    "pure_work_ready": ["underground_routes:source_work_leaf_refusal"] + PURE,
    "pure_ready": ["underground_routes:source_ready_leaf_refusal"] + PURE,
    "pure_actor_phase": ["underground_routes:actor_phase_in", "underground_routes:_source_clock_leaf", "source_program:profile_refusal", "underground_profiles:selection_policy_leaf"],
    "observed_work_cargo": ["underground_routes:source_work_observation_refusal", "underground_routes:_current_profile_into", "underground_routes:_actor_profile_into", "underground_profiles:query_work_profile_into", "underground_profiles:_prepare_query", "underground_profiles:_read_dynamic"] + CARGO,
    "visual_source_read": ["mole_profile_driver:read_route_into", "underground_routes:source_state_leaf_into"] + PURE,
    "visual_dynamic_cargo": ["mole_profile_driver:read_route_into", "underground_profiles:query_travel_profile_into", "underground_profiles:_prepare_query", "underground_profiles:_read_dynamic"] + CARGO,
    "visual_resolver": ["mole_profile_driver:read_route_into", "mole_profile_driver:_source_route_frames", "source_program:walk_time"],
}
COLD = ["load_file", "_decode", "_decode_rows", "_read", "_validate_stage", "_profile_refusal",
        "_key_refusal", "_roles_refusal", "_box_shape_refusal", "_contact_patch_refusal", "_field",
        "_long", "_compare_rows", "_overlap_keys", "_required_states", "content_revision", "_key_field"]


def main():
    retained, allocations = {}, {}
    for module in EXISTING:
        old, now = source(module, True), source(module)
        before, after = members(old), members(now)
        assert before == after, (module, "retained field/schema type change")
        bases = lambda value: re.findall(r"^(?:extends .+|class \w+(?: extends [\w.]+)?:)$", value, re.M)
        assert bases(old) == bases(now), (module, "inherited owner or packet state")
        # New source policy reuses existing packed columns and already allocated caller scratch.
        resizes = lambda value: re.findall(r"\b(\w+)\.resize\(([^\n]*)", value)
        assert resizes(old) == resizes(now), (module, "packed allocation changed")
        retained[module] = {"member_count": len(after), "added_members": [], "numeric_packed_delta": 0}
        allocations[module] = {"unchanged_resize_calls": resizes(now)}
    assert members(source("source_program")) == {}, "SourceProgram must be stateless"
    assert source("source_program").splitlines()[0] == "extends RefCounted", "SourceProgram exact base"
    assert not re.search(r"Packed\w+Array\(|\.new\(|\.duplicate\(|\.resize\(|\.hex_decode\(", source("source_program")), "SourceProgram allocating path"
    constant_types = re.findall(r"^const \w+(?:: ([\w.\[\]]+))?\s*:?=", source("source_program"), re.M)
    assert all(kind in ("", "int", "String") for kind in constant_types), "unexpected SourceProgram constant storage"
    for name, value in {"I32_FIELDS": 18, "I64_FIELDS": 3, "BYTE_FIELDS": 2, "PROFILE_WIRE_BYTES": 98}.items():
        assert re.search(r"^const " + name + r": int = " + str(value) + r"$", source("underground_profiles"), re.M)
    for name, value in {"RESIDENT_FIELDS": 27, "RESIDENT_LONGS": 6}.items():
        assert re.search(r"^const " + name + r": int = " + str(value) + r"$", source("underground_routes"), re.M)
    constants = re.findall(r"^const (\w+): int = ([^\n]+)$", source("source_program"), re.M)
    string_payload = sum(len(v) for v in re.findall(r'^const \w+: String = "([^"\n]+)"$', source("source_program"), re.M))
    # String uses32-bit characters; count the complete two64-character constants, not only UTF8 source text.
    shared_source = 8 * len(constants) + string_payload * 4
    frames = {key: frame(key) for chain in PATHS.values() for key in chain}
    assert all(value is not None for value in frames.values())
    paths = {name: {"chain": chain, "declared_numeric_bytes": sum(frames[key]["numeric_bytes"] for key in chain),
                    "expression_return_allowance": 48} for name, chain in PATHS.items()}
    maximum = max(value["declared_numeric_bytes"] + 48 for value in paths.values())
    pure = {name: value["declared_numeric_bytes"] + 48 for name, value in paths.items() if name.startswith("pure_")}
    assert max(pure.values()) <= 512 and maximum <= 1024
    # The complete query stack is charged to the existing Profiles helper/native envelope;
    # it is not squeezed into the older512-byte path-search/turn-only slice.
    profile_members = members(source("underground_profiles"))
    profile_fixed = sum(WIDTH.get(kind, 0) for key, kind in profile_members.items() if key.startswith("module."))
    profile_fixed += sum(WIDTH.get(kind, 0) for key, kind in profile_members.items() if key.startswith("Selection."))
    profile_fixed += 64 + 9 + 12 + 40 # actual Pose, IntResult, identity I32[3], query I64[5].
    assert profile_fixed == 326
    # Include the complete existing Profile cold call set, conservatively summing sequential frames.
    cold_frames = {"underground_profiles:" + name: frame("underground_profiles:" + name) for name in COLD}
    assert all(v is not None for v in cold_frames.values())
    for name in COLD:
        calls = re.findall(r"(?<![\w.])(_[a-z_]+)\(", function("underground_profiles:" + name))
        assert set(calls) <= set(COLD), ("unaccounted cold child", name, calls)
    cold_stack = sum(v["numeric_bytes"] for v in cold_frames.values()) + 48
    # Two generations of each loop buffer include initializer-before-assignment overlap.
    # Hash/hex/lowercase temporaries and decode buffers are sequential but all are charged together.
    cold_payloads = {"header": 32, "header_slice": 8, "header_ascii_string": 32,
                     "source_old_new": 64, "profile_old_new": 196, "box_old_new": 56,
                     "footer": 8, "footer_ascii_string": 32, "hash_result": 32,
                     "hex_string": 256, "expected_lowercase_string": 256, "key_literal": 16}
    assert sum(cold_payloads.values()) == 988
    assert "_read(file, digest_context, PROFILE_WIRE_BYTES)" in function("underground_profiles:_decode_rows")
    assert "_read(file, digest_context, 28)" in function("underground_profiles:_decode_rows")
    profile_constants = re.findall(r"^const (\w+): int = ([^\n]+)$", source("underground_profiles"), re.M)
    logical_peak = max(maximum, cold_stack + 1024)
    # All Profile constants include the four policy constants once. Only the new Driver constant adds8.
    counted = profile_fixed + shared_source + len(profile_constants) * 8 + 8 + 8 + logical_peak
    assert counted <= 4096 <= 32768
    baseline = ["underground_routes:admit_work_actor", "underground_routes:_admit_actor",
                "underground_routes:_qualify_actor_at", "underground_routes:_actor_profile_into",
                "underground_profiles:query_work_profile_into", "underground_profiles:_prepare_query",
                "underground_profiles:_read_dynamic"] + CARGO
    baseline_frames = {key: frame(key, True) for key in baseline}
    assert all(v is not None for v in baseline_frames.values())
    retirement_path = Path(__file__).parent / "supporting/retirement-source.gd.txt"
    retirement_source = retirement_path.read_text()
    assert re.search(r"^const RETIREMENT_RESERVED_BYTES: int = 8192$", retirement_source, re.M)
    terms = {"paired_profiles": 19224, "profile_controls": 32768, "levels": 2292,
             "paired_motion": 141720, "decode": 4096, "motion_caller": 176,
             "motion_helpers": 4096, "motion_native_provisional": 32768, "session": 1536,
             "retirement": 8192}
    assert sum(terms.values()) == 246868
    result = {"base": BASE, "retained": retained, "allocations": allocations,
        "new_actor_columns": 0, "new_banks": 0, "runtime_native_qualified": False,
        "source_program": {"integer_constants": len(constants), "integer_payload": 8 * len(constants),
                           "two_sha256_string_characters": string_payload, "string_payload_bytes": string_payload * 4,
                           "shared_counted_once": shared_source,
                           "cached_script_reference_native_headers": "within original provisional native/reference accounting; unmeasured"},
        "paths": paths, "frames": frames, "pure_api_inclusive_bytes": pure,
        "whole_numeric_peak_including_expression_allowance": maximum,
        "baseline_work_admission_numeric_bytes": sum(v["numeric_bytes"] for v in baseline_frames.values()) + 48,
        "baseline_work_admission_chain": baseline,
        "cold_profiles": {"frames": cold_frames, "sequential_frames_conservatively_summed": True,
                          "numeric_with_expression_allowance": cold_stack,
                          "all_buffer_generations_and_string_payloads": cold_payloads,
                          "payload_ceiling": 1024, "total": cold_stack + 1024},
        "profile_control": {"existing_fixed_packets": profile_fixed, "new_shared_source_payload": shared_source,
                            "complete_profile_integer_constants": len(profile_constants) * 8,
                            "profile_null_ref_constant": 8, "new_driver_constant": 8,
                            "complete_numeric_stack": maximum, "cold_or_hot_peak": logical_peak,
                            "counted_subtotal": counted, "bounded_logical_slice": 4096,
                            "unchanged_helper_native_reserve": 32768, "remaining_provisional_native_slice": 28672},
        "joint": {"terms": terms, "total": sum(terms.values()), "reservation": 262144, "remaining": 15276,
                  "profiles": 26, "boxes": 250, "source_count": 1, "current_consumer_scripts": 9,
                  "retirement_source_sha256": hashlib.sha256(retirement_path.read_bytes()).hexdigest(),
                  "coherent_current_catalog_motion_binding": "root-owned integration prerequisite; not inferred from this arithmetic"},
        "presentation": {"one_existing_actor_content_admitted_peak": 7141920, "actor_content_delta": 0,
                         "driver_pin_scalars": 54, "driver_duration_scalars": 14, "live_and_stage_scalars": 24,
                         "caller_source_state_reuses_driver_stage": True, "new_actor_or_content_copy": False,
                         "unchanged_cold_descriptor_bytes_each": sum(WIDTH.get(kind, 0) for key, kind in profile_members.items() if key.startswith("Descriptor.")),
                         "source_profile_matches_nested_descriptor": "existing184B actual ActorContent descriptor plus32B digest and64-character hex output; unchanged presentation/foreign caller lifetime"},
        "source_sha256": {str(path(m).relative_to(ROOT)): hashlib.sha256(path(m).read_bytes()).hexdigest()
                          for m in sorted({key.split(":")[0] for key in frames} | set(EXISTING))},
        "limits": ["Logical scalar/payload accounting only; StringName/Variant/native frames remain provisional.",
                   "The512 pure API slice does not account a foreign Contacts/provider caller; its owner adds those frames.",
                   "No new total reservation; full new Profile caller chain is counted inside existing32768 controls.",
                   "Graph/Space proof arenas and cold lifetimes are unchanged; no new snapshot or search cache."]}
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
