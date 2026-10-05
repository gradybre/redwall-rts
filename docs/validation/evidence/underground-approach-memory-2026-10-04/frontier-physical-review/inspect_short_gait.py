#!/usr/bin/env python3
"""Read-only per-key diagnosis; this does not mint a shorter travel certificate."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

import numpy as np


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("raw", type=Path)
    parser.add_argument("basis", type=Path)
    args = parser.parse_args()
    contact = args.root / "godot/data/underground/mole-worker/evidence/contact-qualification"
    path = contact / "prove_cardinal_profiles.py"
    spec = importlib.util.spec_from_file_location("reviewed_cardinal_read_only", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    P, C = module.P, module.C
    S = C.H.S
    assert sha(args.raw) == "08de54533d28b1a45a2e171180a0ca68812912f67c9b7294bf26c25eec424cda"
    parts = None
    with args.raw.open("rb") as stream:
        for case in P.envelope.PaletteSource(stream, sha(args.raw)).cases():
            if case["id"] == "mole_digger.idle.plain.held_pick.firm_grip_v1":
                parts = case["geometry"]
    assert parts is not None
    image = contact / "install-program-compile-v3/result/mole-worker.ugactor"
    assert sha(image) == "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
    cases = S.read_image(image, sha(image), parts)
    plan = contact / "install-program-compile-v3/result/plan.json"
    roots = json.loads(plan.read_text())["world_root_bounds_u"]
    with args.basis.open("rb") as stream:
        basis = module.CardinalBasis(stream,
            "de8c3b04fde4bec30b0b85bf2bf82e01604e9c17cfcb3fdf4029af0f4d43ebf9",
            "e68ec74b02bb227a065d9881ca2c12fe3b1ef122f032e7bb1324213d3031813f")
    ready = P.indexed_sequence(cases[0], [8, 8], "review_exact_ready", False)
    complete = C.H.case_union([cases[1], ready], (0, 1))
    cache = module.endpoint_cache(complete, parts, roots, basis)
    rows = []
    for key in range(complete["frames"]):
        boxes = []
        for item in cache:
            local = P.outward_units(item["low"][key].min(axis=0), item["high"][key].max(axis=0))
            boxes.append(module.orient_box(local, 3))
        rows.append({"key": key, "body_u": boxes[0], "tool_u": boxes[1]})
    # A convex fade cannot exceed these complete native-residual endpoint bounds.
    def union(keys, field):
        boxes = [rows[k][field] for k in keys]
        return [min(b[a] for b in boxes) for a in range(3)] + [max(b[a] for b in boxes) for a in range(3, 6)]
    ready_keys = list(range(cases[1]["frames"], complete["frames"]))
    result = {
        "scope": "numerical whole-primitive bounds only; no phase admission, support proof, native replay or new source permission",
        "source_pins": {str(p): sha(p) for p in [path, Path(P.__file__), Path(C.__file__), Path(C.H.__file__), Path(S.__file__), args.raw, args.basis, image, plan]},
        "walk_keys": cases[1]["frames"], "ready_keys": ready_keys,
        "rows": rows,
        "first_three_forward_ticks_with_ready": {field: union([0, 1, 2, 3, *ready_keys], field) for field in ["body_u", "tool_u"]},
        # Backward starts at0; its one-Q16 seam immediately includes32, then31/30/29.
        "first_three_backward_ticks_with_ready": {field: union([0, 32, 31, 30, 29, *ready_keys], field) for field in ["body_u", "tool_u"]},
        "qualification": False,
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
