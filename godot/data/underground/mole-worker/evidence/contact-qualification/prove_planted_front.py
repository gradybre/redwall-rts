#!/usr/bin/env python3
"""Check the actual planted source, every finite body/tool interval and the exact target-plane portions."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("planted_author", HERE / "author_planted_front.py")
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
P, W, S = A.P, A.W, A.S


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "PLANTED_PROOF_OUTPUT_EXISTS")
    paths = (__file__, A.__file__, A.C.__file__, A.C.H.__file__, W.__file__, W.H.__file__, S.__file__,
             P.__file__, P.content.__file__, P.envelope.__file__)
    pins = {str(Path(path).relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    command = W.read_record(HERE / "analysis-carry-arm-v7/invocation.json")["command"]
    def value(key):
        return command[command.index("--" + key) + 1]
    proof = P.content.read_json(Path(value("proof")), value("proof-sha256"))
    plan = P.content.read_json(Path(value("plan")), value("plan-sha256"), 65536)
    original, sources, historical = W.extract_original(Path(value("source")), value("source-sha256"), proof, plan,
                                                       Path(value("import-archive")))
    parts = original[0]["geometry"]
    topology = P.read_topology(Path(value("topology")), value("topology-sha256"), value("content-sha256"), parts)
    rig = P.content.read_json(Path(value("topology")), value("topology-sha256"), P.MAX_TOPOLOGY_BYTES)
    candidate = W.read_record(args.preview / "candidate.json", 1048576)
    produced = W.read_record(args.preview / "compilation.json")
    for path, digest in candidate["producer_sources"].items():
        P.require(P.content.file_hash(P.ROOT / path) == digest, "PLANTED_PROOF_PRODUCER_DRIFT")
    down = S.read_image(HERE / "analysis-carry-arm-v7/result/mole-worker.ugactor", A.C.DOWN_SHA, parts)
    cases = S.read_image(args.preview / "mole-worker.ugactor", produced["content_sha256"], parts)
    carried = [A.compact_carry(dict(original[index], **down[index]), rig,
               candidate["compact_ready"]["ready_clavicle_yaw_degrees"]) for index in (0, 1)]
    work = A.depress_upper_arm(A.plant_work(carried[0], dict(original[-1], **down[6]), rig), rig,
                              candidate["recipe"]["right_upper_arm_depression_degrees"])
    entry = A.planted_entry(carried[0], work, rig)
    recovery = P.indexed_sequence(entry, list(range(entry["frames"]-1, -1, -1)), "recovery", False)
    for actual, wanted in zip([cases[index] for index in (0, 1, 6, 7, 8)], [*carried, work, entry, recovery]):
        P.require(P.rendered_timing(actual) == P.rendered_timing(wanted) and
                  actual["matrices"].tobytes() == wanted["matrices"].tobytes() and
                  actual["grounding"].tobytes() == wanted["grounding"].tobytes(), "PLANTED_PROOF_SOURCE_MOTION")
    results = {}
    for index in (6, 7, 0, 1):
        results[str(index)] = S.prove(cases[index], parts, topology, rig["rig_binding"], plan["world_root_bounds_u"], "body")
        if not results[str(index)]["clear"]:
            break
    report = {"schema": 1, "content_sha256": produced["content_sha256"], "source_rederived": True,
        "clips": results, "exact_recovery": True, "orientation_scope": "source-local/yaw0 only; other yaws and cross-clip handoffs absent",
        "verified_source_files": sources, "historical_source_snapshot": historical,
        "producer_sources": pins, "production_qualified": False}
    P.require(all(P.content.file_hash(P.ROOT / path) == digest for path, digest in pins.items()), "PLANTED_PROOF_SOURCE_DRIFT")
    with args.out.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"clips": results, "production_qualified": False}, indent=2))


if __name__ == "__main__":
    main()
