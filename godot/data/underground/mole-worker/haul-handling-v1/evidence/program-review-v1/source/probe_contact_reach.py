#!/usr/bin/env python3
"""Bounded authoring search; fixed arm lengths are requirements, never relaxed after a refusal."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import author_handling as A


def main() -> None:
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--palette", type=Path, required=True)
    parser.add_argument("--grip-palette", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--grip-raise", type=int, default=0)
    args = parser.parse_args()
    A.require(not args.out.exists(), "HANDLING_OUTPUT_EXISTS")
    rows, body, log, _, topology, compact, _, _ = A.I.current_inputs(args.palette, args.grip_palette)
    hub, inverse, hub_log, _ = A.planted_carry(compact[0], rows[A.I.CASE_IDS[2]], topology)
    grounding = float(compact[0]["grounding"][8])
    results = []
    for lean, ahead, drop in ((lean, ahead, drop) for drop in (64, 96, 128, 160)
                             for lean in range(30, 101, 5) for ahead in range(256, 897, 32)):
            row = {"lean_degrees": lean, "station_R_minus_S_u": [0, 0, ahead], "hip_drop_u": drop}
            try:
                pose, stock, recipe = A.contact_pose(hub, hub_log, inverse, grounding, lean, ahead, log, drop,
                                                      args.grip_raise)
            except (ValueError, A.I.ENVELOPE.Refused) as error:
                row["refusal"] = str(error)
            else:
                case = A.one_case(pose, stock, inverse, grounding, [body, log])
                row.update({"link_lengths_pass": True, "recipe": recipe,
                            "sampled_diagnostics": A.assess(case, body, log, topology)})
            results.append(row)
    result = {"schema": 1, "production_qualified": False, "purpose": "bounded exact-link authoring probe",
              "candidate_count": len(results), "reachable_count": sum(r.get("link_lengths_pass", False) for r in results),
              "inputs": {"native_palette": A.I.PALETTE_SHA, "current_body": A.I.BODY, "wood": A.I.LOG},
              "producer_sources": {str(Path(p).relative_to(A.I.ROOT)): hashlib.sha256(Path(p).read_bytes()).hexdigest()
                                   for p in (__file__, A.__file__, A.I.__file__, A.RIG.__file__)},
              "results": results,
              "limitations": ["Reach is necessary, not contact/clearance/support or motion proof.",
                              "Every actual body/clothing and wood vertex is retained for following proofs."]}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"output": str(args.out), "candidates": len(results), "reachable": result["reachable_count"]}))


if __name__ == "__main__":
    main()
