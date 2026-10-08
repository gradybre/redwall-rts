# Tool-free stair gaits (M7): review packet (ADR 1217, ADR 1209)

The accepted 128 u descent and ascent, re-run on the approved tool-free ready. No pick; open paw.

## What changed and what did not (`../claw-stairs-v1/`)

**The accepted gaits** (`stair-descent-v7` case 0, `stair-motion-v15` case 0) move only the leg bones along their
foot and root tracks. Every other joint keeps the ready key.

**Unchanged.** The same authors (`author_stair_descent.source_case`, `author_stair_motion.source_case`) were re-run
with **the same recipe values**:

- descent: advance 256, drop 128, leading foot 360, toe 20°;
- ascent: lead advance 68, lift 50.

So the feet, root tracks and timing are the accepted ones.

**The upper body** is the approved tool-free ready: corrected stand key 8 (step 1c), the pose rows 30/31/42 stand
in. It no longer holds the pick.

**One adjustment, searched.** With the pick gone the right paw hangs by the right thigh, and the accepted leg lift
brushes it. So the right upper arm swings a little further out, by step 1c's own swing (same axis and sign):

- **3°**, eased in and out over half a phase (15 keys), so both ends are exactly the ready key;
- bisection over whole degrees gave 3; 2 fails;
- the left arm is clear without any swing.

## Proofs (all clear, `../claw-stairs-v1/proof.json`)

The accepted provers were used unchanged. Only their body+tool part census was replaced, by a one-body check (the
`_WiderPoseInput` precedent).

| Proof | Descent | Ascent |
|---|---|---|
| Two-deck terrain with full-foot contact witnesses | 674 pairs, clear | 781, clear |
| The flight L0 ↔ T5: risers, treads, posts, trench | 4,044 pairs, clear | 4,686, clear |
| The bottom: T5 → T6 sill → floor, seven rows | 1,348 pairs, clear | — |
| Self-clearance: each arm against the rest (legs included), arm against arm | clear | clear |

The pair counts equal the pick-era proofs' (674, 4,044, 1,348, 4,686), which shows the legs and the geometry are
the same.

## Images (painter renders)

- `tread/overview.png`: descent T1 → T2 at key 18, where the right leg lifts past the right paw.
- `tread/motion.png`: side views of the descent at keys 0, 15, 30, 45, 60, 75, 90, then the ascent at 0, 30, 60, 90.
- `sill/overview.png` and `sill/motion.png`: the descent onto the T6 sill.

## Brendan's review (2026-10-08)

**Approved**, including the 3° right-arm swing.

## Checklist for Brendan (as put)

1. Do the arms read naturally on the stairs without the pick (`tread/motion.png`)?
2. Is the 3° extra outward swing of the right arm acceptable?

## Found while preparing the next step: the half-turn on a tread

After fitting, the mole must turn to face up the stair. The ascent starts 343 u behind the tread's far edge, facing
up. An in-place turn does not fit a 512 u tread: the ready feet stay inside the deck's depth only up to a 71° turn
(step 2c). So the half-turn needs ADR 1142's stepped half-turn/reposition (pick-era `stair-handoffs-v1`
candidate 6), re-derived tool-free. That is new motion. It comes next and stops for its own review.

## Already done in this batch (no new motion)

- **The 141 u step back** from the descent's end to the tread station is ADR 1164's finite short step on the
  approved walk, proved (`../tread-step-back-v1/`).
- **Sequence rule:** the bearer is delivered after the fitter arrives (ADR 1209 step 5).
