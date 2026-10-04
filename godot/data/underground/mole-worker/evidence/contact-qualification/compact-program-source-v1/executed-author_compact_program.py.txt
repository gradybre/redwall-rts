#!/usr/bin/env python3
"""One source-owned compact hub with down/high/low entries; no extra posture or ambiguous standing profile."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("planted_source", HERE / "author_planted_front.py")
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
C, P, S, W = A.C, A.P, A.S, A.W
NAMES = ("idle", "ground_walk", "down_work", "down_entry", "down_recovery",
         "high_work", "high_entry", "high_recovery", "front_work", "front_entry", "front_recovery")


def assemble(down, high, original, rig):
    """Reconstruct every affected source, preserve old work cycles and require exact shared endpoint bytes."""
    carried = [A.compact_carry(dict(original[index], **down[index]), rig, -45) for index in (0, 1)]
    entry = P.rig_transition(carried[0], 8, dict(original[-1], **down[6]), 0, rig)
    recovery = P.indexed_sequence(entry, list(range(entry["frames"]-1, -1, -1)), "compact_recovery", False)
    front = A.depress_upper_arm(A.plant_work(carried[0], dict(original[-1], **down[6]), rig), rig, 30)
    front_entry = A.planted_entry(carried[0], front, rig)
    front_recovery = P.indexed_sequence(front_entry, list(range(front_entry["frames"]-1, -1, -1)), "front_recovery", False)
    result = [*carried, dict(original[-1], **down[6]), entry, recovery,
              dict(original[-1], **high[6]), dict(entry), dict(recovery), front, front_entry, front_recovery]
    for index, case in enumerate(result):
        case["id"] = "mole_worker.firm_compact_v2." + NAMES[index]
        case["geometry"] = original[0]["geometry"]
    check_program(result)
    return result


def check_program(cases):
    """One ready source, finite eleven-clip layout and exact retraces; no profile switch skips a transition."""
    P.require(len(cases) == 11 and cases[0]["frames"] > 8, "COMPACT_CLIP_CENSUS")
    C.check_program(cases[:8])
    work, entry, recovery = cases[8:]
    P.require(P.rendered_timing(work)[0] == 1 and P.rendered_timing(entry)[0] == 0 and
              P.rendered_timing(recovery)[0] == 0, "COMPACT_TIMING")
    P.require(C.same_pose(cases[0], 8, entry, 0) and C.same_pose(entry, entry["frames"]-1, work, 0) and
              C.same_pose(work, 0, work, work["frames"]-1), "COMPACT_ENDPOINT")
    P.require(S.reusable_timing(recovery, entry, True) and
              recovery["matrices"].tobytes() == entry["matrices"][::-1].tobytes() and
              recovery["grounding"].tobytes() == entry["grounding"][::-1].tobytes(), "COMPACT_RECOVERY")
    P.require(sum(case["frames"] for case in cases) <= P.content.MAX_FRAMES, "COMPACT_FRAME_CAPACITY")


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "COMPACT_OUTPUT_EXISTS")
    producer_paths = (__file__, A.__file__, C.__file__, C.H.__file__, W.__file__, W.H.__file__, S.__file__,
                      P.__file__, P.content.__file__, P.envelope.__file__)
    producers = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in producer_paths}
    command = W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    def value(key):
        return command[command.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, sources, historical = W.extract_original(Path(value("source")), value("source-sha256"), proof, plan,
                                                       Path(value("import-archive")))
    parts = original[0]["geometry"]
    rig = P.content.read_json(Path(value("topology")), value("topology-sha256"), P.MAX_TOPOLOGY_BYTES)
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"), parts)
    down = S.read_image(HERE / "analysis-carry-arm-v7/result/mole-worker.ugactor", C.DOWN_SHA, parts)
    high = S.read_image(HERE / "high-wall-source-v4/mole-worker.ugactor", C.HIGH_SHA, parts)
    C.source_cases(original, down, high, rig, W.read_record(HERE / "high-wall-source-v4/candidate.json")["entry_recipe"])
    cases = assemble(down, high, original, rig)
    entry_parts = P.continuous_floor(cases[3], topology, plan["world_root_bounds_u"])
    portions = [{"kind": part["kind"], "forward": W.H.plane_portion(cases[3], part, topology[index],
                0 if index == 0 else 24, plan["world_root_bounds_u"], -536)} for index, part in enumerate(parts)]
    report = {"schema": 2, "parent_images": [C.DOWN_SHA, C.HIGH_SHA], "clips": list(NAMES),
        "profile_roles": {"stand": 0, "ground_walk": 1, "down": 2, "high": 3, "front": 4},
        "ready_clip": 0, "ready_time_q16": 8 * 65536, "compact_shoulder_yaw_degrees": -45,
        "front_upper_arm_depression_degrees": 30, "shared_down_high_entry": True,
        "entry_parts": entry_parts, "high_face_entry_portions": portions,
        "verified_source_files": sources, "historical_source_snapshot": historical, "producer_sources": producers,
        "production_qualified": False,
        "remaining": ["CONTINUOUS_REVISED_ENTRY", "COMPACT_HANDOFF_PROOF", "NATIVE_QUALITY", "VERSIONED_DRIVER",
                      "COMPLETE_PROFILE_ROLE_UNION", "ACTUAL_WORLD_AND_PRESENTATION_ADMISSION"]}
    plan = dict(plan, revision=plan["revision"]+5, clips=[case["id"] for case in cases])
    raw_report, raw_plan = (json.dumps(report, indent=2)+"\n").encode(), (json.dumps(plan, indent=2)+"\n").encode()
    image, budget = P.content.encode(cases, plan, proof, hashlib.sha256(raw_report).hexdigest(),
                                    hashlib.sha256(raw_report).hexdigest(), hashlib.sha256(raw_plan).hexdigest())
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in producers.items()), "COMPACT_SOURCE_DRIFT")
    args.out.mkdir(parents=True)
    for name, data in (("candidate.json", raw_report), ("plan.json", raw_plan), ("mole-worker.ugactor", image)):
        with (args.out/name).open("xb") as stream:
            stream.write(data)
    (args.out/"compilation.json").write_text(json.dumps({"content_sha256": hashlib.sha256(image).hexdigest(),
        "content_bytes": len(image), "presentation_budget": budget, "production_qualified": False}, indent=2)+"\n")
    print(json.dumps({"entry_parts": entry_parts, "high_face_entry_portions": portions, "budget": budget}, indent=2))


if __name__ == "__main__":
    main()
