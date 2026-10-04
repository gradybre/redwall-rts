#!/usr/bin/env python3
"""Bind the reviewed complete-tool/non-palm-body proof to the exact stair source; no locomotion permission."""
import argparse
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("stair_source", HERE/"assess_stair_rig.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
P, S = M.P, M.S


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--rise", type=int, default=128, choices=(-256, -128, 128, 256))
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "STEP_SELF_OUTPUT_EXISTS")
    _, parts, rig, topology, roots, sources, historical = M.read_actual_source()
    compilation = M.W.read_record(args.preview/"compilation.json")
    image = args.preview/"mole-worker.ugactor"
    cases = S.read_image(image, compilation["content_sha256"], parts)
    with image.open("rb") as stream:
        header = stream.read(184)
    candidate = P.content.read_json(args.preview/"candidate.json", header[120:152].hex(), 1048576)
    recipes = [row for row in candidate["attempts"] if row["status"] == "SOURCE_CANDIDATE_ONLY"]
    P.require(len(recipes) == len(cases) and 0 < len(cases) <= 4, "STEP_SELF_CENSUS")
    selected = [index for index, row in enumerate(recipes) if row["rise_u"] == args.rise]
    P.require(len(selected) == 1 and recipes[selected[0]].get("root_contract") == "separate_integer_ceil_v1",
              "STEP_SELF_SELECTION")
    paths = (__file__, M.__file__, M.D.__file__, M.A.__file__, M.C.__file__, M.C.H.__file__, M.W.__file__, M.W.H.__file__,
             S.__file__, P.__file__, P.content.__file__, P.envelope.__file__, image, args.preview/"candidate.json")
    pins = {str(Path(path).resolve().relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    result = S.prove(cases[selected[0]], parts, topology, rig["rig_binding"], roots, "body")
    report = {"schema": 1, "content_sha256": compilation["content_sha256"], "rise_u": args.rise, "result": result,
              "producer_sources": pins, "verified_source_files": sources, "historical_source_snapshot": historical,
              "root_scope": "exact same integer root is added once after both body skin and static tool; common translation cancels; independent native arithmetic errors remain enclosed",
              "scope": "complete original tool against every body/clothing triangle except the existing exact intentional palm grip patch, source-local yaw0; not leg/body self-contact, terrain, paid support or gameplay",
              "production_qualified": False}
    P.require(all(P.content.file_hash(P.ROOT/path) == digest for path, digest in pins.items()), "STEP_SELF_SOURCE_DRIFT")
    with args.out.open("x") as output:
        json.dump(report, output, indent=2)
        output.write("\n")
    print(json.dumps({"clear": result["clear"], "checks": result["checks"], "production_qualified": False}))
    if not result["clear"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
