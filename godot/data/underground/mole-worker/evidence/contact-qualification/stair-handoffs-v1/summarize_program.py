#!/usr/bin/env python3
"""Compile proved handoff column proposals and exact source joins; allocate no runtime owner."""
import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("handoff_author", HERE.parent/"author_stair_handoffs.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)
D, P = A.D, A.P


def intern(rows, row):
    P.require(type(row) is list and all(type(v) is int and -(1 << 31) <= v < (1 << 31) for v in row),
              "HANDOFF_COLUMNS_I32")
    if row not in rows:
        rows.append(row)
    return rows.index(row)


def columns(recipes, reports, solids):
    tables = {key: [] for key in ("PROGRAM", "KEY", "INTERVAL", "BOX", "SUPPORT", "SUPPORT_REF", "SOLID")}
    tables["SOLID"] = solids
    for program, recipe in enumerate(recipes):
        terrain, self_ = reports[program]
        count = len(recipe["keys"])-1
        P.require(terrain["clear"] is self_["clear"] is True and terrain["unresolved"] == [] and
                  terrain["intervals"] == self_["intervals"] == count and terrain["solids"] == 22 and
                  [p["triangles"] for p in terrain["parts"]] == [10209, 1150] and
                  all(len(p["full_interval_boxes_program_u"]) == count for p in terrain["parts"]), "HANDOFF_COLUMNS_PROOF")
        first_key, first_interval = len(tables["KEY"]), len(tables["INTERVAL"])
        tables["KEY"].extend([*r["root_u"], r["yaw"], r["planted_mask"]] for r in recipe["keys"])
        expected = {(i, side) for i in range(count) for side in (0, 1)
                    if recipe["keys"][i]["planted_mask"] & recipe["keys"][i+1]["planted_mask"] & (1 << side)}
        actual = [(r["interval"], r["foot"]) for r in terrain["supports"]]
        P.require(len(actual) == len(set(actual)) and set(actual) == expected, "HANDOFF_COLUMNS_SUPPORT")
        for interval in range(count):
            bounds = [intern(tables["BOX"], p["full_interval_boxes_program_u"][interval]) for p in terrain["parts"]]
            first_support = len(tables["SUPPORT_REF"])
            for row in terrain["supports"]:
                if row["interval"] != interval:
                    continue
                P.require(row["projection_inside"] and row["source_above_plane"] and row["vertex"] >= 0,
                          "HANDOFF_COLUMNS_SUPPORT")
                b = row["full_foot_u"]
                support = [row["foot"], row["primitive"], row["plane_u"], b[0], b[2], b[3], b[5], row["vertex"]]
                tables["SUPPORT_REF"].append([intern(tables["SUPPORT"], support)])
            amount = len(tables["SUPPORT_REF"])-first_support
            P.require(1 <= amount <= 2, "HANDOFF_COLUMNS_SUPPORT")
            tables["INTERVAL"].append([program, interval, *bounds, first_support, amount])
        tables["PROGRAM"].append([first_key, count+1, first_interval, count, recipe["keys"][0]["support_primitive"], program, A.ONE, 0])
    P.require(len(tables["KEY"]) == 453 and len(tables["INTERVAL"]) == 450, "HANDOFF_COLUMNS_CENSUS")
    return tables


def memory(tables, presentation):
    widths = {"PROGRAM": 8, "KEY": 5, "INTERVAL": 6, "BOX": 6, "SUPPORT": 8, "SUPPORT_REF": 1, "SOLID": 6}
    byte_counts = {name: len(rows)*widths[name]*4 for name, rows in tables.items()}
    packed = sum(byte_counts.values())+128  # Three program digests plus one immutable column/source manifest digest.
    total = 2*packed+4096+176  # simultaneous old/new, proposed bounded stream buffer, caller including heading/phase.
    dense = sum(byte_counts.values())+128-byte_counts["BOX"]-byte_counts["SUPPORT"]
    dense += 450*2*24+len(tables["SUPPORT_REF"])*32
    return {"schema_status": "offline column proposal only; no live reader, reservation or native admission",
            "rows": {name: len(rows) for name, rows in tables.items()}, "i32_widths": widths, "column_bytes": byte_counts,
            "digest_bytes": 128, "one_numeric_bank": packed, "dense_bank_without_exact_dedup": dense,
            "exact_dedup_bytes_saved": dense-packed, "simultaneous_live_candidate": 2*packed,
            "decode_scratch_proposal": 4096, "caller_numeric_proposal": 176,
            "numeric_peak_proposal_before_native": total, "remaining_joint_headroom_reference": 5314,
            "headroom_scope": "root-reported after accepted1141 controls, excluding pending1140; no allocation grant",
            "unreserved_numeric_shortfall": max(0, total-5314), "runtime_allocation_bytes": 0,
            "existing_1139_numeric_proposal_not_replaced": 42704,
            "combined_separate_proposals_before_native": total+42704,
            "source_presentation": presentation, "native_peak_measured": False,
            "lifetimes": "JSON/triangle/NumPy arrays are offline; old/new program banks must coexist during replacement. No third JSON image in the proposed runtime. Palette raw decode and retained copy coexist; borrowed mesh/texture ownership, shared Basis, per-Actor RIDs and native controls still need actual coupled-owner admission."}


def joins(recipes, old):
    states = {r["name"]: {"entry": [r["keys"][0]["root_u"], r["keys"][0]["yaw"], r["endpoint_pose_sha256"]],
                           "exit": [r["keys"][-1]["root_u"], r["keys"][-1]["yaw"], r["endpoint_pose_sha256"]]}
              for r in recipes}
    states.update(old)
    order = ["approach", "descent", "turn", "ascent", "retreat"]
    links = []
    for first, last in zip(order, order[1:]):
        P.require(states[first]["exit"] == states[last]["entry"], "HANDOFF_ENDPOINT_JOIN")
        links.append({"from": first, "to": last, "state": states[first]["exit"]})
    return {"episode": order, "joins": links, "initial": states["approach"]["entry"],
            "terminal": states["retreat"]["exit"], "intervals_with_accepted_gaits": 630,
            "no_heading_reset_at_terminal": True, "source_endpoint_values_and_float32_bytes_match": True,
            "scope": "source joining only; prior gait fixture quarter-turn proofs are not native yaw permissions. No new gait/runtime/paid-world qualification."}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("proofs", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "HANDOFF_COLUMNS_OUTPUT_EXISTS")
    records, pins = D.load_inputs()
    _, parts, _, topology, _, _, _, boundary = D.actual_source(pins)
    add = lambda path: D.add_pins(pins, {str(path.resolve().relative_to(D.ROOT)): D.sha(path)})
    add(Path(__file__))
    candidate = D.read_json(args.source/"candidate.json", D.sha(args.source/"candidate.json"))
    compilation = D.read_json(args.source/"compilation.json", D.sha(args.source/"compilation.json"))
    D.add_pins(pins, candidate["producer_sources"])
    for name in ("candidate.json", "compilation.json", "plan.json", "mole-worker.ugactor"):
        add(args.source/name)
    P.require(D.sha(args.source/"mole-worker.ugactor") == compilation["content_sha256"], "HANDOFF_COLUMNS_IMAGE")
    recipes, reports, old = candidate["attempts"], [], {}
    P.require([r["name"] for r in recipes] == ["approach", "turn", "retreat"] and
              all(r["status"] == "SOURCE_CANDIDATE_ONLY" for r in recipes), "HANDOFF_COLUMNS_PROGRAMS")
    for recipe in recipes:
        pair = []
        for kind in ("terrain", "tool-body"):
            path = args.proofs/recipe["name"]/kind/"result/proof.json"
            proof = D.read_json(path, D.sha(path)); add(path)
            D.add_pins(pins, proof["producer_sources"])
            P.require(proof["source_sha256"] == compilation["content_sha256"] and proof["name"] == recipe["name"] and
                      proof["proof_kind"] == kind and proof["production_qualified"] is False, "HANDOFF_COLUMNS_PROOF_SOURCE")
            pair.append(proof["result"])
        reports.append(pair)
    for item, files, data in records:
        case, recipe, _ = D.select_source(item, files, data, parts, topology)
        _, segments = D.Q.validate_fixture(data["fixture"], recipe)
        segment = segments[0]
        old[item["direction"]] = {key: [D.Q.endpoint(segment, recipe["root_u"][frame]),
            segment["quarter_turn"]*16384, D.pose_digest(case, frame)] for key, frame in (("entry", 0), ("exit", 90))}
    tables = columns(recipes, reports, records[1][2]["fixture"]["solids_u"])
    report = {"schema": 1, "tables": tables, "memory": memory(tables, compilation["presentation_budget"]),
              "source_joins": joins(recipes, old), "producer_sources": pins, "production_qualified": False,
              "source_heading_root_equation": A.ROOT_EQUATION, "no_gameplay_rate_adopted": True}
    D.add_pins({}, pins); D.check_current_sources(boundary)
    args.out.mkdir(parents=True)
    (args.out/"program.json").write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({"rows": report["memory"]["rows"], "numeric_peak": report["memory"]["numeric_peak_proposal_before_native"],
                      "source_joins": len(report["source_joins"]["joins"]), "production_qualified": False}))


if __name__ == "__main__":
    main()
