# Side-on tread fitting: review packet (ADR 1217 step 2c, ADR 1209 step 5)

**Result: the side-on station does not exist on a 512 u tread.** Two exact counts refuse it, and the accepted world
prover refuses the best side-on station at both sites. Nothing new is authored; Brendan's choice is needed.

## What was tried

Brendan's decision: on T_{k−1} the mole turns a quarter turn and stands beside T_k's bearer, so the bearer sits at
the paws' reach, as at L0/T0. `derive_tread_side_station.py` derives that station from published data only and
proves it with the approved paw clips (`paw-seat-v1/candidate-a`) **unchanged**:

| Input | Value | Source |
|---|---|---|
| T_{k−1}'s deck | `[-1024,-64,-310, 1024,0,202]`, **512 u deep** | ADR 1209 tread fixture (T0's deck in the prefix artifact) |
| T_k's bearer (staged) | `[-256,0,-310, 256,P,-182]`, P = 128 (T1…T5) or 64 (T6 sill) | same fixture; ADR 1209 D1 |
| Trench side walls | \|x\| ≥ 1024, up to the surface | `prove_descent_flight.trench` |
| Paw contacts | (±128, P, −448) | approved candidate a |
| Quarter turn | yaw 16384: local (x, z) → world (z, −x), facing −x | `claw_source.quarter` |

The best side-on station puts the contacts' 448 u reach at the bearer's centre along its length (x = 448) and
centres the feet on the deck's depth (z = −42).

## Findings (`../tread-side-station-v1/station.json`)

1. **Footing (exact): the feet are wider than the tread is deep.** The accepted sole rule needs every foot vertex
   inside the deck's projection. Turned a quarter, the feet's lateral span lies along the tread's 512 u depth. The
   exact skin equation of the outermost foot vertices gives a span of **568.68 u at its narrowest** over all 219
   played keys (the stand's 122 keys and the seat and tap entries and work; 570.72 u in every paw key). It is 56.7 u
   too wide for any position on the deck. `TREAD_SIDE_FOOTING`.
2. **Paw spread (exact): the paws straddle the bearer.** After the quarter turn the bearer runs along the mole's
   forward axis, so its top is only **128 u** across the mole. The approved contacts are **256 u** apart, so at most
   one paw lands on it. At the best station the right contact lands at z = −170, 12 u short of the bearer, and the
   left at z = +86, on the bare deck. `TREAD_SIDE_PAW_SPREAD`.
3. **The accepted prover agrees.** `prove_paw_seat.world` on the seat and tap work clips refuses at T3 and at the T6
   sill. Both feet fail support on interval 0: they overhang the far edge by 29.7 u and reach 29.0 u past the
   riser line into the deck behind (solid 3). It stops at its 32-witness limit.
4. **The turn (float).** At yaw 0 the feet occupy 341 u of the depth. They still fit at 71° (508.5 u at 70°) and
   reach 570.7 u at 90°. So the quarter turn itself also leaves the deck.

The T6 sill fails the same way: its deck is T0's deck six pitches down (D1), equally 512 u deep. Only the bearer's
height differs.

## Images (painter renders, not native captures)

The approved clips are placed at the best side-on station. Blue: feet; brown: paws; green: decks and supports;
orange: the bearer being fitted.

| Image | Representative tread (T3) | T6 sill |
|---|---|---|
| Overview: tap key 16 from the front, side and top | `tread-t3/overview.png` | `sill-t6/overview.png` |
| Hands: handling seat and tap key 16, both paws vs the bearer | `tread-t3/hands.png` | `sill-t6/hands.png` |
| Motion: the turn (feet only, 0/30/60/71/90°) and tap keys 0/8/16 | `tread-t3/motion.png` | `sill-t6/motion.png` |

In `motion.png`, the 90° panel shows one foot past the far edge (top green line) and the other past the riser
(bottom green line).

## Options for Brendan (decision aids: `options-probe.json`, float)

1. **Side-on with a narrow stance (new motion).** This keeps the side-on decision.
   - Author a stance at the station with the feet stepped in by at least 57 u, plus the accepted padding.
   - The quarter turn becomes a stepped turn that keeps both feet on the deck.
   - The paws are re-placed on the 128 u top. Side by side at ±48 or ±64 (inside the top's ±64), the float gap
     between the two arms falls to 2.6 u and 8.6 u, against 85.2 u at the approved ±128. So the paws probably have
     to stand one ahead of the other along the bearer, or one paw presses while the other braces.
   - Cost: three new motions and another review, with an uncertain outcome.
2. **Stage the bearer where the approved motion already reaches (new structure data).** From ADR 1209's 310 u
   station at yaw 0, the approved clips seat a bearer whose section is z ∈ [−512, −384], 0–128 u up: the same
   station-relative section as L0/T0. On a tread that is 74–202 u past T_{k−1}'s far edge, above T_k's site.
   - The clips would apply verbatim, with no turn. Only the world proofs re-run against the new support.
   - It needs a temporary staging support under that section, with its own bearings, bill and removal. That is
     world content, and only Brendan can add it.
3. **Seat T_k from two treads up (T_{k−2}), yaw 0, where the descent already ends.** No turn and no reposition; the
   bearer's top is level with the stance. Its near face is 553 u ahead, and the paws reach at most 576 u (lean 60–80°,
   drop 176 u). That leaves a 23 u band at full stretch over the drop. **Not recommended.**

**Recommended: option 2** if a staging support is acceptable, because it reuses the approved clips exactly.
**Option 1** if side-on is to be kept.

**Separate note for ADR 1209 step 5.** The descent ends on T_{k−1} at root far + 169. There the ready body's front
below 128 u reaches far + 0.7, inside the staged bearer, which spans far … far + 128. So in any plan the bearer must
be delivered after the fitter has descended, or the fitter must arrive before it.

## Checklist for Brendan

1. `tread-t3/motion.png` (90° panel): are the feet past both edges convincing?
2. `tread-t3/hands.png`: does it show clearly that only one paw can reach the 128 u top?
3. Which option: 1 (narrow side-on stance), 2 (staging support) or 3? Or another layout?

## Not done

No motion, rows, content or Frontier rows were authored or published. Nothing is production-qualified.
