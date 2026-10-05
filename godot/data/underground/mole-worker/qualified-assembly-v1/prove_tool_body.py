#!/usr/bin/env python3
"""Complete held-pick/non-gripping-body proof for the exact assembly source intervals."""
import argparse
import json
from pathlib import Path

import prove_assembly as B


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    B.P.require(not args.out.exists() and not args.out.is_symlink(), "ASSEMBLY_OUTPUT_EXISTS")
    report, clips = B.sources(args.candidate)
    images = B.candidate_pins(args.candidate)
    producers = {str(p.relative_to(B.I.ROOT)): B.I.A.digest(p) for p in
                 (Path(__file__), Path(B.__file__), Path(B.A.__file__), Path(B.I.__file__),
                  Path(B.I.A.S.__file__))}
    _, parts, rig, topology, roots, count, _, _, pins = B.I.source_inputs()
    results = []
    for row, clip in zip(report["clips"], clips):
        result = B.I.A.S.prove(clip, parts, topology, rig["rig_binding"], roots, "body")
        results.append({"clip": row["clip"], **result})
        print(json.dumps({"clip": row["clip"], "clear": result["clear"], "checks": result["checks"]}), flush=True)
    result = {"schema": 1, "source_inputs": pins, "verified_source_files": count,
              "candidate_inputs": images, "producer_sources": producers,
              "results": results, "all_clear": all(row["clear"] for row in results),
              "scope": "The full held pick against all body/clothing triangles except the exact existing intentional right palm grip; all triangles remain in world-air/wood proof. This does not prove limb-versus-limb separation.",
              "production_qualified": False}
    B.P.require(B.candidate_pins(args.candidate) == images and
                all(B.I.A.digest(B.I.ROOT/path) == digest for path, digest in producers.items()),
                "ASSEMBLY_PRODUCER_DRIFT")
    with args.out.open("x") as stream:
        json.dump(result, stream, indent=2); stream.write("\n")
    if not result["all_clear"]:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
