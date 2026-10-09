#!/usr/bin/env python3
"""Retain definite source-vertex intrusion witnesses for explicit unpaid stair fixtures; absence proves nothing."""
import argparse
from fractions import Fraction
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("stair_source", HERE / "assess_stair_rig.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
P = M.P


def entirely_inside(low, high, box):
    """Only an entire numerical vertex enclosure strictly inside a solid produces a definite witness."""
    P.require(low.shape == high.shape and low.ndim == 2 and low.shape[1] == 3 and np.all(low <= high), "STEP_PROBE_INTERVAL")
    P.require(len(box) == 6 and all(type(value) is int for value in box) and
              all(box[axis] < box[axis+3] for axis in range(3)), "STEP_PROBE_BOX")
    scale = P.SCALE // 1024
    return np.all(low > np.asarray(box[:3], dtype=np.int64) * scale, axis=1) & \
           np.all(high < np.asarray(box[3:], dtype=np.int64) * scale, axis=1)


def probe(case, parts, roots, rise, thickness):
    """Examine every stored pose of both actual parts; this is deliberately not a continuous triangle certificate."""
    P.require(rise in (-256, -128, 128, 256) and type(thickness) is int and 1 <= thickness <= 256,
              "STEP_PROBE_FIXTURE")
    boxes = [[-1024, -64, -169, 1024, -2, 343],
             [-1024, rise-thickness, -681, 1024, rise-2, -169]]
    results, offset = [], 0
    for part in parts:
        count = max(1, part["binds"])
        matrices = case["matrices"][:, offset:offset+count]
        hulls = P._vertex_hulls(part, matrices, case["grounding"])
        padding, residual = P._residual_padding(part, matrices, case["grounding"], roots, hulls)
        witnesses = []
        affected = 0
        for frame in range(case["frames"]):
            low, high = P._vertex_hulls(part, matrices[frame:frame+1], case["grounding"][frame:frame+1])[0]
            low, high = low-padding, high+padding
            for section, box in enumerate(boxes):
                selected = np.flatnonzero(entirely_inside(low, high, box))
                affected += len(selected)
                if len(selected):
                    vertex = int(selected[np.argmin(high[selected, 1])])
                    witnesses.append({"frame": frame, "section": section, "vertex": vertex, "count": len(selected),
                        "enclosure_u": P.outward_units(low[vertex], high[vertex]),
                        "exact_q24_low": low[vertex].tolist(), "exact_q24_high": high[vertex].tolist()})
        results.append({"kind": part["kind"], "confirmed_vertex_pose_intrusions": affected,
            "affected_frames": len({row["frame"] for row in witnesses}), "witnesses": witnesses,
            "native_residual_m": residual, "source_padding_q24": [int(value) for value in padding]})
        offset += count
    return {"rise_u": rise, "unpaid_fixture_boxes_u": boxes, "upper_thickness_u": thickness,
            "two_unit_contact_band_omitted_from_probe_only": True, "parts": results,
            "scope": "stored source poses at yaw0, definite full vertex-enclosure intrusion only; no continuous/triangle/stance/clearance success",
            "production_qualified": False}


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("preview", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--thickness", type=int, default=32)
    args = parser.parse_args()
    P.require(not args.out.exists() and not args.out.is_symlink(), "STEP_PROBE_OUTPUT_EXISTS")
    _, parts, _, _, roots, sources, historical = M.read_actual_source()
    compiled = M.W.read_record(args.preview/"compilation.json")
    image = args.preview/"mole-worker.ugactor"
    P.require(P.content.file_hash(image) == compiled["content_sha256"], "STEP_PROBE_IMAGE")
    with image.open("rb") as stream:
        header = stream.read(184)
    candidate = P.content.read_json(args.preview/"candidate.json", header[120:152].hex(), 1048576)
    cases = M.S.read_image(image, compiled["content_sha256"], parts)
    attempts = [row for row in candidate["attempts"] if row["status"] == "SOURCE_CANDIDATE_ONLY"]
    P.require(len(attempts) == len(cases) and 0 < len(cases) <= 4, "STEP_PROBE_CENSUS")
    paths = (__file__, M.__file__, M.D.__file__, M.A.__file__, M.C.__file__, M.C.H.__file__, M.W.__file__, M.W.H.__file__,
             M.S.__file__, P.__file__, P.content.__file__, P.envelope.__file__, image, args.preview/"candidate.json")
    pins = {str(Path(path).resolve().relative_to(P.ROOT)): P.content.file_hash(Path(path)) for path in paths}
    report = {"schema": 1, "content_sha256": compiled["content_sha256"],
        "clips": [probe(case, parts, roots, row["rise_u"], args.thickness) for case, row in zip(cases, attempts)],
        "producer_sources": pins, "verified_source_files": sources, "historical_source_snapshot": historical,
        "production_qualified": False}
    P.require(all(P.content.file_hash(P.ROOT/name) == digest for name, digest in pins.items()), "STEP_PROBE_SOURCE_DRIFT")
    raw = (json.dumps(report, indent=2)+"\n").encode()
    with args.out.open("xb") as stream:
        stream.write(raw)
    print(json.dumps({"sha256": hashlib.sha256(raw).hexdigest(), "clips": [
        {"rise_u": row["rise_u"], "parts": [{"kind": part["kind"], "intrusions": part["confirmed_vertex_pose_intrusions"]}
         for part in row["parts"]]} for row in report["clips"]], "production_qualified": False}))


if __name__ == "__main__":
    main()
