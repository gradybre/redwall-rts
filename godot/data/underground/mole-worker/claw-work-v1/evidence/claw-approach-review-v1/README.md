# Narrow claw approach and retreat: review packet (ADR 1217 step 4d)

Nothing here is published. Content 9 and the Frontier/bundle successor wait for this review.

## What was derived

`author_claw_approach.py` derives the narrow rows with the pick's approach recipe
(`work-approach-v1/compile_work_approach.py`). It uses the claw image's own stand and walk on the open paw, with no
tool, and authors no new motion:

- **Approach (READY_FORWARD):** the walk clip plays at a fixed body heading while the root moves straight in along
  the station line. The driver's READY fade then joins it to stand key 8.
- **Retreat (READY_BACKWARD):** the same poses in reverse along the reversed path.
- **Boxes:** the whole outward hull of every walk key plus ready key 8, with no yaw sweep. They are turned
  exactly to the four headings, giving 8 rows (forward and backward × 4).

| Role | Box (u, yaw 0) |
|---|---|
| BODY_HELD_LOAD and TURN_RECOVERY | `[-485,0,-521,479,930,412]` and floor `[-271,-1,-274,284,0,249]` |
| STANCE_SUPPORT | `[-274,-1,-274,299,0,249]` |

For comparison:

- Row 42 (all-yaw) is `[-712,0,-712,712,930,712]`.
- The pick's row 2 body is `[-445,0,-474,546,930,346]`, plus a pick box.

The claw box is wider than row 2 by 40 u on −X and 66 u on +Z. H's surveyed air, sized for the pick, will need
to cover that at activation.

## Proofs (`../claw-approach-v1/approach.json`)

The handoffs are the 45 fade simplices the rows use, ready → walk start and every walk interval → ready. They are
selected as the pick's `selected_handoffs` selects them, and checked with `prove_state_handoffs.separated_simplex`.

1. **Pending bearers: clear.** Every body triangle on every handoff simplex, with the root anywhere from 0 to
   4,096 u behind the station, misses both bearer prisms:
   - the L0 bearer at H, `[-192,0,-512,1856,128,-384]`;
   - the T0 bearer at the L0 contact, `[-256,0,-512,256,128,-384]`.

   These are `bearer_refusal`'s prisms. No triangle even shares a bounding box with either swept prism.
2. **Self-clearance: NOT clear.** 404 pairs are unresolved, all of them the right arm against the rest, in the
   READY fade from walk keys 28–37.
   - The sampled float gap falls to **0.009 u** (`fade-gaps.json`, from `../../measure_approach_gaps.py`).
   - That is the right paw grazing the right thigh as the late stride blends back to ready (`paws.png`).
   - Every other handoff is clear: ready → walk start, and the fades from walk keys 0–27 and 38–43.
   - The walk itself was already clear in step 1c. Only the fade's straight blend from the late stride to ready
     sweeps the paw through the thigh.

## Endpoints

| Endpoint | Content 6 travel | With row 42 | Proposed |
|---|---|---|---|
| 3, L0 contact | row 2 | the 712 u sweep contains the pending T0 bearer, which is 384 u ahead | narrow forward (yaw 0) |
| 0, H | row 2 | the sweep contains the pending L0 bearer, 384 u ahead (`[-192…1856]`) | narrow forward |
| 2, R, install row 0's retreat | row 6 | leaving H on row 42 turns at H, into the L0 bearer | narrow backward |
| 1 (M) and 13 (the T0 arrival) | rows 2 and 6 | not checked separately | narrow forward and backward, like for like |
| 4–12 | row 12 | row 42 is narrower than row 12 | row 42 |

## Images

- `overview.png`: ready key 8 at H and at the L0 contact, front and side, outlined with:
  - the narrow box (green);
  - row 42's box (red);
  - the bearer (brown).
- `motion.png`: side views of the approach.
  - The root 1,024, 512 and 0 u behind the station, every 6th walk key.
  - The fade from walk key 31 into ready.
- `paws.png`: the right paw against the right thigh in the fade from keys 30–33 at 5/8.

## Decision needed: the late-stride fade

1. **Recommended: gate the fade by walk phase.** The source clock starts the walk → ready fade only from walk
   intervals 0–27 or 38–43, which are all proved clear. Arriving in keys 28–37, the walk plays on to key 38
   first, which takes at most 10 key intervals, about 0.33 s. No geometry changes; the rule goes into the source
   program successor. The retreat uses the same gate when it arrives; its departure (ready → walk start) is clear.
2. **Author a fade path** that carries the right arm out during the late-stride fade, like step 1c's 13° swing.
   This is new motion, so it means re-proving and another review.
