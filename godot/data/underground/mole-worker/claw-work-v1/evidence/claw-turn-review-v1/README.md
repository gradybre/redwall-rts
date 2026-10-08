# Tool-free half-turn on a tread: review packet (ADR 1209 step 5, ADR 1142, ADR 1217)

After fitting T_{k+1} from T_k, the fitter has to face up the stair and stand where the ascent begins.

## The episode on each tread

| Leg | Motion | From → to (behind T_k's far edge) | Source |
|---|---|---|---|
| 1 | Descent onto T_k | ends at 169 u | M7, approved |
| 2 | Step back | 169 → 310 u | ADR 1164's short step, walk keys 0/43/42 (proved earlier) |
| 3 | Bearer delivered; paw handling and fitting | at 310 u | DEC-058 candidate b, approved |
| 4 | **Step forward** | 310 → 169 u | the same short step, walk keys 0/1/2 (`../tread-step-forward-v1/`) |
| 5 | **Half-turn and reposition** | 169 u facing down → 343 u facing up | ADR 1142 candidate 6, re-derived (`../claw-turn-v1/`) |
| 6 | Ascent to T_{k−1} | starts at 343 u | M7, approved |

An in-place turn cannot be used: on a 512 u tread the feet stay on the deck only up to 71° (step 2c).

## The half-turn (new motion for review)

**Re-derived, not re-designed.** ADR 1142's accepted author (`author_stair_handoffs.source_case("turn")`,
sha d9a71169…) runs unchanged on the approved tool-free ready. That keeps everything except the ready pose:

- the same 9 phases and 271 keys;
- the same root controls (174 u back) and heading controls (0 → 32768 over six steps);
- the same alternating footfalls with narrowed ankle stations, knee guidance and sole solve.

Self-clearance clears with **no** arm swing (0°); the bisection's first test, at 0°, was clear.

**Proofs, all clear:**

- **The accepted handoff prover** (`prove_stair_handoffs.prove`) on T0, T1, T2, T3, T4 and T5, 3,048 checks each.
  - Every Q16 phase, with the finite heading table enclosed by interval arithmetic and subdivision.
  - Every triangle against every solid of the whole derived descent: L0, T0–T5, their bearings, the T6 sill, the
    floor, and the side and end walls of the seven-row trench. It is translated so the standing tread is where
    candidate 6 stood.
  - Full-foot support with a continuous contact witness.
- **Two pick-era guards were replaced by this tool's own checks**, as M7 replaced the part census:
  - the pick ready's endpoint digest became "both endpoints equal the claw ready key";
  - "two parts, 22 solids, 1,150 tool triangles" became "one body part, 10,209 triangles, valid integer prisms".
- **Self-clearance:** each arm against the rest (legs included) and arm against arm, every interval.

**The step forward** (310 → 169) uses the step back's recipe and proofs, with the walk sampled forward and the
fitted T_{k+1} added as a solid. It is clear. As for every approved READY↔walk fade, its two fades have no
single-vertex contact witness; this is recorded.

## Images (painter renders)

| | T2 (after fitting T3) | T5 (after fitting the T6 sill) |
|---|---|---|
| Overview at key 135, mid-turn: front, side, top | `tread/overview.png` | `sill/overview.png` |
| Motion: top views at keys 0, 45, 90, 135, 180, 225, 270; side view at 270 | `tread/motion.png` | `sill/motion.png` |

## Checklist for Brendan

1. Does the stepped half-turn read well without the pick (`tread/motion.png`)?
2. Is the episode order above (step forward, then turn) acceptable?

Tests: `test_claw_turn.py` (5).
