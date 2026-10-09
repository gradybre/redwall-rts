#!/usr/bin/env python3
"""Review aid for ADR 1217 step 4d, not a proof: every unresolved approach-handoff pair and its sampled float gap.

Each pair is sampled at 9 interval shares x 41 fade shares on a 40-step barycentric grid of both triangles. The
stored output is `evidence/claw-approach-review-v1/fade-gaps.json`. Run from this directory:

    $PY measure_approach_gaps.py <out.json>
"""
import json
import sys
import numpy as np
sys.path.insert(0, ".")
import author_claw_approach as A

d = A.sources(A.SRC.PALETTE, A.SRC.PALETTE.parent / "mole-grip-v3.ugpal", A.SRC.PALETTE.parent / "world-yaw-v1.ugyaw")
sets = A.PAIRPROOF.classes(d["src"])
tri, st, wk = d["triangles"], d["stand"], d["walk"]
walk0 = st["frames"]
out = []
for h in A.approach_handoffs(d):
    for label, f, s in A.PAIRPROOF.PAIRINGS:
        for pair in A.separate_sets(d, h["corners"], sets[f], sets[s], [0]):
            out.append({"interval": h["interval"], "corners": h["corners"], "pairing": label, "pair": pair})
print("unresolved", len(out), flush=True)
n = 40
bc = np.array([(i / n, j / n, 1 - i / n - j / n) for i in range(n + 1) for j in range(n + 1 - i)])
mats = np.concatenate([st["matrices"][:, :24], wk["matrices"][:, :24]]).astype(np.float64)
grs = np.concatenate([st["grounding"], wk["grounding"]]).astype(np.float64)


def pts(m, gr):
    case = {"frames": 1, "matrices": m[None].astype(np.float32), "grounding": np.array([gr], dtype=np.float32)}
    return A.SRC.I.points_at(case, d["body"], 0)


cache = {}
worst = 1e9
for row in out:
    a, b, c = row["corners"]
    best = 1e9
    for s in np.linspace(0, 1, 9):
        for f in np.linspace(0, 1, 41):
            key = (a, b, c, round(s, 4), round(f, 4))
            if key not in cache:
                w = np.array([(1 - f) * (1 - s), (1 - f) * s, f])
                cache[key] = pts(np.tensordot(w, mats[[a, b, c]], 1), float(w @ grs[[a, b, c]]))
            p = cache[key]
            A_, B_ = bc @ p[tri[row["pair"][0]]], bc @ p[tri[row["pair"][1]]]
            best = min(best, float(np.min(np.linalg.norm(A_[:, None] - B_[None], axis=-1))))
    row["float_gap_u"] = round(best, 3)
    worst = min(worst, best)
print(json.dumps({"unresolved": len(out), "intervals": sorted({tuple(r["interval"]) for r in out}),
                  "min_float_gap_u": round(worst, 3)}))
json.dump(out, open(sys.argv[1], "w"), indent=1)
