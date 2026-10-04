#!/usr/bin/env python3
"""Sample-only authoring diagnosis; clipping here never certifies continuous clearance."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("handoff_author", HERE.parent/"author_stair_handoffs.py")
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)


def clip(points, box):
    polygon = list(points)
    for axis, sign, edge in [(a, s, box[a if s > 0 else a+3]) for a in range(3) for s in (1, -1)]:
        output = []
        for first, last in zip(polygon, polygon[1:]+polygon[:1]):
            a, b = sign*(first[axis]-edge), sign*(last[axis]-edge)
            if a >= 0:
                output.append(first)
            if (a < 0) != (b < 0):
                output.append(first+(last-first)*(-a)/(b-a))
        polygon = output
    return [list(map(float, p)) for p in polygon]


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("proof", type=Path)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    A.P.require(not args.out.exists() and not args.out.is_symlink(), "DIAGNOSTIC_OUTPUT_EXISTS")
    records, pins = A.D.load_inputs()
    _, parts, _, topology, _, _, _, boundary = A.D.actual_source(pins)
    compilation = json.loads((args.source/"compilation.json").read_text())
    cases = A.S.read_image(args.source/"mole-worker.ugactor", compilation["content_sha256"], parts)
    proof = json.loads(args.proof.read_text())
    candidate = json.loads((args.source/"candidate.json").read_text())
    recipes = [r for r in candidate["attempts"] if r["status"] == "SOURCE_CANDIDATE_ONLY"]
    index = next(i for i, r in enumerate(recipes) if r["name"] == proof["name"])
    case, recipe = cases[index], recipes[index]
    table, _ = A.read_basis()
    cache, output = {}, []
    for row in proof["result"]["unresolved"]:
        if row["kind"] != "SOLID" or row["part"] != 0:
            continue
        vertices = topology[0][0][row["triangle"]]
        samples = []
        for share in (0, A.ONE//4, A.ONE//2, 3*A.ONE//4, A.ONE):
            key = row["interval"], share
            if key not in cache:
                frame = key[0]
                palette = ((A.ONE-share)*case["matrices"][frame].astype(np.float64)+share*case["matrices"][frame+1])/A.ONE
                ground = ((A.ONE-share)*case["grounding"][frame]+share*case["grounding"][frame+1])/A.ONE
                pair = recipe["keys"][frame:frame+2]
                root, yaw = A.phase_root_heading([r["root_u"] for r in pair], [r["yaw"] for r in pair], share)
                local = A.A.source_positions(parts[0], palette, ground)
                cache[key] = A.program_points(local, root, yaw, table)
            points = cache[key][vertices]
            polygon = clip(points, records[1][2]["fixture"]["solids_u"][row["primitive"]])
            samples.append({"share": share, "points": points.tolist(), "intersection_polygon": polygon})
        geometry = parts[0]["geometry"][0]
        weights = [{str(int(b)): float(w) for b, w in zip(geometry["ids"][v], geometry["weights"][v]) if w} for v in vertices]
        output.append({**row, "vertices": vertices.tolist(), "weights": weights, "samples": samples})
    A.D.check_current_sources(boundary)
    result = {"scope": "sampled diagnosis only, not a continuous or exact intersection certificate", "rows": output,
              "sampled_nonempty_intersections": sum(bool(s["intersection_polygon"]) for r in output for s in r["samples"])}
    args.out.write_text(json.dumps(result, indent=2)+"\n")
    print(json.dumps({k: result[k] for k in ("scope", "sampled_nonempty_intersections")}))


if __name__ == "__main__":
    main()
