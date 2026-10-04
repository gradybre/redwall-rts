#!/usr/bin/env python3
"""Prove the revised finite compact-hub source program without granting its pending runtime driver."""
import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact_author", HERE / "author_compact_program.py")
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)
A, C, P, S, W = D.A, D.C, D.P, D.S, D.W


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "COMPACT_PROOF_OUTPUT_EXISTS")
    paths = (__file__, D.__file__, A.__file__, C.__file__, C.H.__file__, W.__file__, W.H.__file__, S.__file__,
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
    candidate, produced = W.read_record(args.preview / "candidate.json", 1048576), W.read_record(args.preview / "compilation.json")
    for path, digest in candidate["producer_sources"].items():
        P.require(P.content.file_hash(P.ROOT / path) == digest, "COMPACT_PROOF_PRODUCER")
    cases = S.read_image(args.preview / "mole-worker.ugactor", produced["content_sha256"], parts)
    down = S.read_image(HERE / "analysis-carry-arm-v7/result/mole-worker.ugactor", C.DOWN_SHA, parts)
    high = S.read_image(HERE / "high-wall-source-v4/mole-worker.ugactor", C.HIGH_SHA, parts)
    wanted = D.assemble(down, high, original, rig)
    P.require(len(cases) == len(wanted) == 11, "COMPACT_PROOF_CENSUS")
    for actual, expected in zip(cases, wanted):
        P.require(P.rendered_timing(actual) == P.rendered_timing(expected) and
                  actual["matrices"].tobytes() == expected["matrices"].tobytes() and
                  actual["grounding"].tobytes() == expected["grounding"].tobytes(), "COMPACT_PROOF_SOURCE_MOTION")
    D.check_program(cases)
    revised_entry = S.prove(cases[3], parts, topology, rig["rig_binding"], plan["world_root_bounds_u"], "body")
    with Path(value("world-basis")).open("rb") as stream:
        basis = C.H.InverseHeading(stream, proof["world_basis"]["sha256"], proof["world_basis"]["producer_sha256"])
    handoffs = C.H.prove_handoffs(C.H.case_union(cases, (0, 1)), cases, parts, topology, rig["rig_binding"],
                                plan["world_root_bounds_u"], basis.inverse_norm)
    report = {"schema": 2, "content_sha256": produced["content_sha256"], "source_rederived": True,
        "revised_down_high_entry": revised_entry, "carry_handoffs": handoffs,
        "inverse_heading_norm": P.envelope.fraction_record(basis.inverse_norm), "world_basis_sha256": basis.digest,
        "verified_source_files": sources, "historical_source_snapshot": historical, "producer_sources": pins,
        "production_qualified": False,
        "scope": "new shared entry/retrace is source-local yaw0; compact carry handoffs include finite all-yaw inverse error",
        "remaining": ["VERSIONED_DRIVER_BINDING", "PRIOR_WORK_AND_FRONT_SOURCE_COMPOSITION", "NATIVE_QUALITY",
                      "PHYSICAL_ROLE_COMPILER", "ACTUAL_WORLD_AND_PRESENTATION_ADMISSION"]}
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "COMPACT_PROOF_SOURCE_DRIFT")
    with args.out.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"entry_clear": revised_entry["clear"], "handoffs_clear": handoffs["clear"],
                      "handoff_checks": handoffs["checks"], "production_qualified": False}))
    if not revised_entry["clear"] or not handoffs["clear"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
