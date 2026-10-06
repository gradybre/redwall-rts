# Stone motion: human review packet (ADR 1206)

This packet is for **Brendan's motion review**, the counterpart of wood's program and loaded-gait reviews. It
covers the stone's whole source motion:

- the empty stand joins;
- approach, lift, place and recovery;
- the loaded hold, entry, 219-key carry loop and exit.

Nothing after it has been built: no native image v9, rows, runtime content or certificate. Those wait for this
review.

## What was authored

| Step | Clips (keys) | Recipe | Exact proof |
|---|---|---|---|
| Program (`../stone-program-v1`) | approach, lift, place, recovery (61 each) | Wood's lift with the stone path **staged**: it eases 48 u out over keys 0–30, rises 448 u over keys 7–45, and is drawn in to z −384 u over keys 30–60. The hub lean is 15° (wood used 20°). | All four pass `prove_program.prove`, with two-hand certificates on lift and place, plus exact star containment. |
| Loaded gait (`../stone-gait-v1`) | hold 2, enter 65, carry 219 (loop), exit 65 | Wood's gait recipe unchanged: supplied carry legs, the held upper body, sole-transfer keys. | All four pass `prove_loaded_gait.prove`, including the rotating-stock grip certificates and the loop wrap. |
| Joins (`../stone-joins-v1`) | enter_haul_stone, leave_haul_stone (31 each) | Wood's join recipe from stand key 8. | Floor, one-foot support and stone separation pass. |

**Why the lift is staged.** Wood's single-path lift drives the lump into the snout. It penetrates up to 57 u
around mid-lift, and a test keeps that counterexample. The approved grip starts with the snout 1.7 mm from the
stone, so the stone must ease out and rise before it is drawn in to the chest.

## Closest approach (float, keys only; `motion-review.json`)

| Clip | Smallest gap between the body and the stone | Where |
|---|---|---|
| approach / lift / place / recovery | 1.7 u | the snout at the pickup key, which is the approved grip pose |
| hold / enter / carry / exit | 26 u | the left hand's wrist side, at chest height |
| stand joins | 292 u | the right hand; the stone stays on the floor |

## Images: wood's views (front, side, top), plus `hands.png` zooms

- Lift:
  - `../stone-program-v1/render-lift-0/overview.png` (pickup)
  - `lift-20/overview.png`
  - `../stone-program-v1/render-lift-30/overview.png`
  - `lift-40/overview.png`
  - `../stone-program-v1/render-lift-60/overview.png` (the loaded hub)
- Carry loop:
  - `../stone-gait-v1/render-carry-0/overview.png`
  - `../stone-gait-v1/render-carry-54/overview.png`
  - `../stone-gait-v1/render-carry-110/overview.png`
  - `carry-164/overview.png`
- Join: `enter-haul-stone-15/overview.png`, halfway from the stand to the approach.

## What to judge

1. **The lift reads as picking up a stone.** The stone first eases away, then rises with the body, then is drawn
   to the chest.
2. **The carry hold.** The stone is held at chest height in front, about 0.45–0.70 m up. The arms are on its
   flanks, and the snout and wrists are clear.
3. **The carry walk.** The supplied carry legs swing the stone with the spine. Do the hands stay convincingly on
   it?
4. **The join.** From standing empty-handed, the mole bends into the reach toward the floor stone.

## Reproduce

`invocation.json` lists every command and SHA-256 pin. The test logs are `tests.log` in each step folder.

## Verdict

Brendan approved the stone motion on 2026-10-06; see `review-acceptance.md`.
