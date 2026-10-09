#!/usr/bin/env python3
"""Read-only source census and proposed joint admission arithmetic; no runtime allocation."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

P = "godot/data/underground/mole-worker/evidence/contact-qualification/"
HEADER = [
    "format_version", "joint_content_revision", "profiles_content_revision", "level_revision",
    "catalog_revision", "grouping_revision", "frontier_revision", "basis_contract_revision",
    "numerical_proof_revision", "presentation_proof_revision", "consumer_contract_revision",
    "equation_contract_revision", "gait_table_revision", "handoff_table_revision", "program_count",
    "actor_source_count", "primitive_map_count", "join_count", "backend_id", "qualification_mask",
]
DIGESTS = [
    "profile_wire", "level_wire", "connector_catalog", "assemblies", "frontier", "world_basis",
    "basis_producer", "numerical_proof_manifest", "presentation_proof_manifest",
    "consumer_closure_manifest", "shared_ready_pose", "canonical_fixture",
]
PROGRAM_I32 = [
    "component", "component_program", "actor_source", "clip", "equation", "fixed_quarter_turn",
    "origin_x", "origin_y", "origin_z", "profile_id", "catalog_variant", "first_assembly",
    "assembly_count", "first_primitive_map", "primitive_map_count", "entry_key", "terminal_key",
    "entry_yaw", "terminal_yaw", "flags",
]
PROGRAM_I64 = [
    "profile_revision", "variant_revision", "program_revision", "source_phase_duration_q16",
    "tick_phase_numerator", "tick_phase_denominator", "tick_rate_revision",
]
SOURCE_I64 = ["source_revision", "clip_count", "certificate_revision", "flags"]
PRIMITIVE_MAP = ["component", "source_solid", "canonical_fixture_id", "kind", "authored_id", "assembly"]
JOINS = ["from_program", "to_program", "from_terminal_key", "to_entry_key"]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def constant(text, name):
    match = re.search(r"^const " + name + r": int = (\d+)\b", text, re.M)
    require(match is not None, "constant " + name)
    return int(match[1])


def source_profile_bytes(p, b, s):
    require(1 <= p <= 256 and 1 <= b <= 3072 and 1 <= s <= 64, "global Profiles bounds")
    return 2 * (98 * p + 28 * b + 32 * s + 32) + 32768


def decode_gait(raw):
    require(raw[:16] == b"UGSTEP01" + struct.pack("<II", 1, 0), "gait header")
    shapes = [("DESC", 12, 2), ("ROOT", 3, 182), ("STEP", 4, 180), ("BOXE", 6, 348),
              ("SUPP", 8, 122), ("SIDX", 1, 180), ("SOLI", 6, 44)]
    at, tables = 48, {}
    for name, width, count in shapes:
        require(raw[at:at+4] == name.encode() and struct.unpack_from("<II", raw, at+4) == (width, count), name)
        at += 12
        tables[name] = [list(struct.unpack_from("<" + "i" * width, raw, at + i * width * 4)) for i in range(count)]
        at += count * width * 4
    require(raw[at:] == b"UGSEND01", "gait exact footer")
    return tables


def transformed_box(box, origin, turn):
    require(turn in (0, 2), "only actual gait fixture turns, not general yaw permission")
    if turn == 0:
        result = list(box)
    else:
        result = [-box[3], box[1], -box[5], -box[0], box[4], -box[2]]
    return [v + origin[i % 3] for i, v in enumerate(result)]


def endpoint(root, origin, turn):
    require(turn in (0, 2), "fixture orientation")
    return [origin[0] + (root[0] if turn == 0 else -root[0]), origin[1] + root[1],
            origin[2] + (root[2] if turn == 0 else -root[2])]


def actor_clips(raw):
    require(raw[:8] == b"UGACNT01", "actual ActorContent image")
    parts, clips, frames = struct.unpack_from("<3I", raw, 16)
    require(parts == 2, "body and held tool")
    rows = [list(struct.unpack_from("<4i", raw, 184 + parts*72 + index*48)) for index in range(clips)]
    next_frame = 0
    for first, count, loop, duration in rows:
        require(first == next_frame and loop == 0 and duration == (count-1)*65536, "exact nonloop full-interval source timing")
        next_frame += count
    require(next_frame == frames, "all presentation frames counted, including unselectable comparison clip")
    require(list(struct.unpack_from("<6i", raw, 32)) == [0, -32256, 0, 262144, 16896, 262144], "image numerical Domain")
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    roots = {"runtime": args.runtime.resolve(), "source": args.source.resolve()}
    pins = {}

    def read(root, name):
        path = roots[root] / name
        require(path.is_file() and not path.is_symlink(), "exact ordinary source " + name)
        raw = path.read_bytes()
        pins[root + ":" + name] = sha(raw)
        return raw

    def data(root, name):
        return json.loads(read(root, name))

    profiles = read("runtime", "godot/scripts/core/underground_profiles.gd").decode()
    levels = read("runtime", "godot/scripts/core/underground_level_catalog.gd").decode()
    budget = read("runtime", "godot/scripts/core/underground_budget.gd").decode()
    catalog = read("runtime", "godot/data/underground/mole-worker/mole_profile_catalog.gd").decode()
    read("runtime", "godot/data/underground/mole-worker/profile-publication-v2/catalog_source.gd")
    read("runtime", "godot/scripts/core/underground_routes.gd")
    read("runtime", "godot/demo/cast/underground_actor_content.gd")
    read("runtime", "docs/decisions/1080-source-bound-underground-profile-catalog.md")
    read("source", "docs/decisions/1112-source-phase-route-motion.md")
    live_pack = data("runtime", "docs/planning/underground_memory_pack.json")
    wire = read("runtime", "godot/data/underground/mole-worker/profile-publication-v2/mole-worker.ugprof")
    require(wire[:8] == b"UGPROF01" and struct.unpack_from("<III", wire, 20) == (18, 194, 1), "actual profile wire census")
    require(len(wire) == constant(catalog, "WIRE_BYTES") == 7268, "actual profile wire length")
    require(sha(wire) == "b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac", "profile source")
    require([constant(profiles, key) for key in ("MAX_PROFILES", "MAX_BOXES", "MAX_SOURCES", "CONTROL_RESERVE")] == [256, 3072, 64, 32768], "unchanged global caps")
    require("2 * (profiles * PROFILE_WIRE_BYTES + boxes * 28 + sources * 32 + 32)" in profiles, "actual allocation expression")
    profile_reserve = constant(budget, "PROFILE_BYTES")
    level_bytes = constant(levels, "MAX_RETAINED_BYTES") + constant(levels, "CONTROL_RESERVE")
    profile_bytes = source_profile_bytes(18, 194, 1)
    require(profile_bytes == constant(catalog, "PAIRED_BANK_BYTES") + constant(catalog, "CONTROL_RESERVE"), "actual catalog paired bytes")

    gait = data("source", P + "stair-program-v1/candidate-4/result/program.json")
    raw = read("source", P + "stair-program-v1/candidate-4/result/stair-program.ugstep")
    require(sha(raw) == gait["wire_sha256"], "gait wire source")
    gt = decode_gait(raw)
    require(raw[16:48].hex() == gait["source_input_sha256"], "gait aggregate source digest")
    handoff = data("source", P + "stair-handoffs-v1/column-proposal-v2/result/program.json")
    ht = handoff["tables"]
    require({k: (len(v), len(v[0])) for k, v in ht.items()} == {
        "PROGRAM": (3, 8), "KEY": (453, 5), "INTERVAL": (450, 6), "BOX": (681, 6),
        "SUPPORT": (306, 8), "SUPPORT_REF": (450, 1), "SOLID": (22, 6)}, "handoff exact complete table shapes")
    require(all(len(row) == handoff["memory"]["i32_widths"][name] for name, rows in ht.items() for row in rows), "no shortened or widened handoff row")
    hc = data("source", P + "stair-handoffs-v1/candidate-6/result/candidate.json")
    hp = data("source", P + "stair-handoffs-v1/candidate-6/result/plan.json")
    hcomp = data("source", P + "stair-handoffs-v1/candidate-6/result/compilation.json")
    himage = read("source", P + "stair-handoffs-v1/candidate-6/result/mole-worker.ugactor")
    require(sha(himage) == hcomp["content_sha256"] and len(himage) == hcomp["content_bytes"], "handoff image")
    read("source", P + "compile_stair_program.py")
    read("source", P + "stair-handoffs-v1/summarize_program.py")
    fixture = data("source", "docs/design/underground-planning/first-entry-prefix-v1.json")
    require([p["id"] for p in fixture["parts"]] == list(range(14)), "canonical timber IDs")
    require([b["part"] for b in fixture["natural_bearings"]] == [3, 4, 5, 6, 10, 11, 12, 13], "canonical bearing order")
    canonical = [p["bounds_u"] for p in fixture["parts"]] + [b["bounds_u"] for b in fixture["natural_bearings"]]
    require(ht["SOLID"] == canonical, "complete fixed-frame handoff primitives")
    require(hp["world_root_bounds_u"] == [0, -32256, 0, 262144, 16896, 262144], "handoff numerical Domain")
    states, images = {}, []
    for n, program in enumerate(gait["programs"]):
        source = program["source"]
        image = read("source", source["paths"]["image"])
        require(sha(image) == source["sha256"]["image"], "gait image")
        plan = data("source", source["paths"]["plan"])
        require(plan["world_root_bounds_u"] == hp["world_root_bounds_u"], "same actual numerical Domain")
        images.append({"name": program["direction"], "sha256": sha(image), "wire_bytes": len(image),
                       "clip": source["clip"], "image_clip_count": len(plan["clips"]), "actual_clip_metadata": actor_clips(image)})
        origin, turn = program["fixture_placement"]["origin_u"], program["fixture_placement"]["quarter_turn"]
        require([transformed_box(box, origin, turn) for box in gt["SOLI"][n*22:(n+1)*22]] == canonical, "all gait primitives mapped to exact canonical geometry")
        require(gt["ROOT"][n*91:(n+1)*91] == program["root_u"], "all root keys retained")
        stationary = [i for i in range(90) if program["root_u"][i] == program["root_u"][i+1]]
        require(stationary == program["stationary_intervals"], "stationary phase preserved")
        require(gt["DESC"][n] == [n, (128, -128)[n], n*91, 91, n*90, 90, n*22, 22, 90*65536, 0, 0, 0], "descriptor meaning")
        states[program["direction"]] = {
            "entry": [endpoint(program["root_u"][0], origin, turn), turn*16384, program["pose_entry_sha256"]],
            "exit": [endpoint(program["root_u"][-1], origin, turn), turn*16384, program["pose_exit_sha256"]],
        }
    images.append({"name": "handoffs", "sha256": sha(himage), "wire_bytes": len(himage), "clips": [0, 1, 2], "image_clip_count": len(hp["clips"]), "actual_clip_metadata": actor_clips(himage)})
    recipes = hc["attempts"]
    for n, descriptor in enumerate(ht["PROGRAM"]):
        recipe = recipes[n]
        first, count, first_interval, intervals, _, clip, one, zero = descriptor
        require(clip == n and one == 65536 and zero == 0 and count == intervals + 1, "handoff descriptor")
        keys = ht["KEY"][first:first+count]
        require(keys == [[*r["root_u"], r["yaw"], r["planted_mask"]] for r in recipe["keys"]], "all handoff keys preserved")
        require(len(ht["INTERVAL"][first_interval:first_interval+intervals]) == intervals, "all handoff intervals preserved")
        states[recipe["name"]] = {"entry": [keys[0][:3], keys[0][3], recipe["endpoint_pose_sha256"]],
                                  "exit": [keys[-1][:3], keys[-1][3], recipe["endpoint_pose_sha256"]]}
    joins = handoff["source_joins"]
    for j in joins["joins"]:
        require(states[j["from"]]["exit"] == states[j["to"]]["entry"] == j["state"], "exact join state")
    require(states["approach"]["entry"] == joins["initial"] and states["retreat"]["exit"] == joins["terminal"], "episode endpoints")
    require(joins["initial"][1] == 0 and joins["terminal"][1] == 32768, "no hidden heading reset")
    raw_gait = sum(len(r)*4 for rows in gt.values() for r in rows) + 32
    raw_handoff = sum(len(r)*4 for rows in ht.values() for r in rows) + 128
    require(raw_gait == gait["memory"]["packed_with_source_digest"] == 19224, "gait source census")
    require(raw_handoff == handoff["memory"]["one_numeric_bank"] == 48548, "handoff source census")
    decode = max(gait["memory"]["bounded_stream_decode_scratch"], handoff["memory"]["decode_scratch_proposal"])
    caller = max(gait["memory"]["proposed_reusable_caller_numeric_bytes"], handoff["memory"]["caller_numeric_proposal"])
    identity = {
        "header": {"fields_i64": HEADER, "bytes": 8*len(HEADER)},
        "digests": {"fields_sha256": DIGESTS, "bytes": 32*len(DIGESTS)},
        "actor_sources": {"count": 3, "fields_i64": SOURCE_I64, "sha256_per_row": 1, "bytes": 3*(32+8*len(SOURCE_I64))},
        "programs": {"count": 5, "fields_i32": PROGRAM_I32, "fields_i64": PROGRAM_I64, "bytes": 5*(4*len(PROGRAM_I32)+8*len(PROGRAM_I64))},
        "primitives": {"count": 66, "fields_i32": PRIMITIVE_MAP, "bytes": 66*4*len(PRIMITIVE_MAP)},
        "joins": {"count": 4, "fields_i32": JOINS, "bytes": 4*4*len(JOINS)},
        "numerical_domain": {"i32": hp["world_root_bounds_u"], "bytes": 24},
    }
    extra = sum(row["bytes"] for row in identity.values())
    require(extra == 3088, "proposed identity arithmetic")
    bank = raw_gait + raw_handoff + extra
    fixed_helper_ceiling, native_ceiling = 4096, 32768
    both = profile_bytes + level_bytes + 2*bank + decode + caller + fixed_helper_ceiling + native_ceiling
    once = both-bank
    maxima = both-profile_bytes+source_profile_bytes(256, 3072, 64)
    require(both <= profile_reserve and maxima > profile_reserve, "joint configuration must fit and independent maxima must refuse")

    ground = data("source", P + "install-program-compile-v3/result/compilation.json")
    presentation = [ground["presentation_budget"], *gait["memory"]["source_presentation"]["existing_images"], hcomp["presentation_budget"]]
    retained = sum(p["retained_palette_bytes"] + p["packed_tables_bytes"] for p in presentation)
    conservative = sum(p["admitted_peak_bytes"] for p in presentation) + 544768
    sequential = retained + max(p["decode_staging_bytes"] for p in presentation) + 4396032 + 2097152 + 544768
    for key, digest in pins.items():
        root, name = key.split(":", 1)
        require(sha((roots[root]/name).read_bytes()) == digest, "source changed during census")
    report = {
        "status": "read-only design; no runtime allocation or qualification",
        "sources_unchanged": True, "pins": pins,
        "heads_observed": {k: subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=v, text=True).strip() for k, v in roots.items()},
        "actual_profiles": {"rows": 18, "boxes": 194, "sources": 1, "paired_and_control_bytes": profile_bytes,
                            "level_bytes_in_same_reserve": level_bytes, "profile_reserve": profile_reserve,
                            "global_caps": [256, 3072, 64], "population_cap": 256},
        "raw_tables": {"gait_rows": {k: len(v) for k, v in gt.items()}, "handoff_rows": {k: len(v) for k, v in ht.items()},
                       "gait_bank": raw_gait, "handoff_bank": raw_handoff, "combined_bank": raw_gait+raw_handoff,
                       "shared_decode": decode, "shared_caller": caller, "paired_raw_peak": 2*(raw_gait+raw_handoff)+decode+caller},
        "joint_source_counts": {"programs": 5, "images": 3, "keys": 635, "intervals": 630, "boxes": 1029,
                                "support_rows": 428, "support_refs": 630, "original_solid_rows": 66, "canonical_fixture_primitives": 22},
        "images": images, "exact_joins": joins, "additional_identity_proposal": identity,
        "proposed_configuration": {"additional_identity_per_bank": extra, "motion_bank_with_identity": bank,
            "logical_fixed_and_helper_ceiling_unimplemented": fixed_helper_ceiling,
            "native_control_ceiling_unmeasured": native_ceiling,
            "source_once_total": once, "source_once_remaining": profile_reserve-once,
            "paired_replacement_total": both, "paired_remaining": profile_reserve-both,
            "independent_max_profiles_with_paired_motion": maxima, "independent_maxima_refuse": True,
            "global_budget_reservation_delta": 0, "per_resident_column_delta_proposed": 0,
            "rate_adopted": False, "runtime_admitted": False},
        "separate_coupled_presentation": {"images_including_current_ground": 4,
            "retained_palettes_and_tables": retained, "sum_existing_reader_peaks_one_basis": conservative,
            "unimplemented_single_sequential_reader_peak": sequential,
            "unimplemented_replacement_old_plus_new_retained_peak": sequential+retained,
            "native_measured": False, "profile_arena_covers_this": False,
            "mesh_texture_per_actor_rids_whole_client_excluded": True},
        "current_global_ledger_context": {"total": live_pack["live_with_reserve_bytes"], "headroom": live_pack["headroom_bytes"],
                                          "delivery_4096_included": False},
    }
    encoded = json.dumps(report, indent=2) + "\n"
    if args.check:
        require(args.out.read_text() == encoded, "recorded design census differs")
    else:
        require(not args.out.exists(), "refuse to overwrite evidence")
        args.out.write_text(encoded)
    print(json.dumps({"source_pins": len(pins), "raw_motion_peak": report["raw_tables"]["paired_raw_peak"],
                      "identity_per_bank": extra, "paired_total": both, "remaining": profile_reserve-both,
                      "source_once_total": once, "profile_maxima_total_refused": maxima, "runtime_admitted": False}))


if __name__ == "__main__":
    main()
