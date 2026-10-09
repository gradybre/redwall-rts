#!/usr/bin/env python3
"""Bounded floating source-authoring study at the first split plant; never prove absence of collision."""
import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("actual_descent_author", HERE / "author_stair_descent.py")
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    D.P.require(not args.out.exists() and not args.out.is_symlink(), "DESCENT_STUDY_OUTPUT_EXISTS")
    paths = [Path(__file__), Path(D.__file__), Path(D.A.__file__), Path(D.M.__file__)]
    pins = {str(p.resolve().relative_to(D.P.ROOT)): D.P.content.file_hash(p) for p in paths}
    cases, parts, rig, topology, _, _, _ = D.M.read_actual_source()
    ready = cases[0]
    ready["geometry"] = parts
    parents, inverse, inverse_inverse = D.A.A.hierarchy(rig)
    actual, _, _ = D.A.A.joints(ready, 8, parents, inverse_inverse)
    feet = [np.unique(topology[0][0][D.M.anatomical_foot_triangles(parts[0], topology[0][0], (ankle, toe))])
            for _, _, _, ankle, toe in D.M.LEGS]
    results = []
    for advance in (180, 200, 220, 240):
        for drop in (64, 96, 128):
            for lead in (347, 368, 400):
                for guide in (0., .5, 1.):
                    row = {"advance": advance, "drop": drop, "lead": lead, "guide": guide}
                    root, targets, plant = D.tracks(30, -128, advance, drop, lead)
                    try:
                        palette, _, _, _ = D.solve_frame(ready, actual, inverse, root, targets, parts[0], feet,
                                                         plant, D.bend_strength(30, guide))
                        points = D.A.source_positions(parts[0], palette, ready["grounding"][8]) + root
                        inside = np.flatnonzero((points[:, 1] < 0) & (points[:, 1] > -64) &
                                                (points[:, 2] > -169) & (points[:, 2] < 343))
                        row.update(status="POSE_ONLY", lower_deck_vertex_intrusions=len(inside),
                                   worst_vertex=int(inside[np.argmin(points[inside, 1])]) if len(inside) else None,
                                   worst_y=float(points[inside, 1].min()) if len(inside) else None)
                    except ValueError as error:
                        row.update(status="REFUSED", error=str(error))
                    results.append(row)
    D.P.require(all(D.P.content.file_hash(D.P.ROOT/p) == digest for p, digest in pins.items()), "DESCENT_STUDY_DRIFT")
    report = {"schema": 1, "producer_sources": pins, "frame": 30, "rise_u": -128, "candidates": results,
              "scope": "108 bounded floating pose-authoring trials against lower deck vertices only; zero hits never proves whole-triangle/continuous/stance/terrain success",
              "production_qualified": False}
    with args.out.open("x") as stream:
        json.dump(report, stream, indent=2)
        stream.write("\n")
    print(json.dumps([row for row in results if row.get("lower_deck_vertex_intrusions") == 0]))


if __name__ == "__main__":
    main()
