# Static stone grip: human review packet (ADR 1206)

This packet is for **Brendan's grip review**. Wood had the same checkpoint, `static-contact-review-v1`. Nothing
after the static grip has been authored yet: no lift, place, gait, joins, rows or runtime use. Those wait for
this review.

## What is gripped

- **Stone.** The captured procedural lump (`../stone-source-v1`, 70 vertices / 108 triangles) at the adopted
  0.150 m/unit. It has the 0.8 vertical squash and no rotation (`../stone-scale-v2/fine.json`; 0.151 already
  meets the body). That is about 0.33 × 0.26 × 0.31 m. It rests 1/512 u above the floor with its centre on S.
- **Body.** Every one of the current mole's 10,209 body and clothing triangles is kept.
- **Pose.** Wood's pose recipe is reused unchanged:
  - the carry hub, a 95° torso lean and a 96 u hip squat;
  - fixed-length arm solves;
  - planted soles.
- **Grip.** Each hand keeps its wood-grip orientation and is moved inward along X onto the lump's sides
  (`author_stone_grip.py`).

## The series

All five candidates pass the exact static rules in `static-contact.json`:

- every solid triangle separates from the stone, and no solid vertex is inside it;
- each hand has an exact hand-edge/stone-triangle witness;
- both soles and the stone have exact floor contacts, and nothing is below the floor.

| Candidate | R−S (u) | Raise, in L/R (u) | Deepest grip penetration L/R | Wrist/forearm gap L/R | Nearest other body (head) |
|---|---|---|---|---|---|
| **v1** | 576 | 128, 200/200 | 7.7 / 7.0 | 16.6 / 39.5 | **1.7** |
| v2 | 576 | 112, 208/200 | 3.9 / 8.7 | 9.2 / 51.3 | 1.7 |
| v3 | 576 | 128, 216/200 | 20.7 / 7.0 | 20.2 / 39.5 | 1.7 |
| **v4** | 640 | 128, 200/200 | 7.7 / 7.0 | 5.1 / 47.7 | **63.3** |
| v5 | 640 | 128, 192/200 | 1.0 / 7.0 | 3.7 / 47.7 | 63.3 |

How to read the table:

- All gaps and penetrations are float radial diagnostics in u (1 u = 1/1024 m), from `review.json`.
- Search ranking is in `../stone-grip-probe-v1/`. Stage 1 has 180 recipes and stage 2 has 360.
- Shallower inward shifts give no contact; deeper ones bury the fingers.

## Images (wood's review views: front, side, top; hands zoomed ×1.3)

- `candidate-v1/overview.png`, `candidate-v1/hands.png`
- `candidate-v4/overview.png`, `candidate-v4/hands.png`

Grip (distal palm) triangles are tinted orange. These are orthographic painter renders, not clearance proofs.

## What to judge

1. **Both hands seated on the lump.**
   - The palms close on the lump's flanks at about mid-height. The fingers run forward along the sides.
   - Exact witnesses: left at about (−154, 112, −538) u and right at about (122, 172, −545) u, for v1.
   - Is this a believable two-hand grip?
2. **Wrist clearance.**
   - The wrists and forearms stay outside the stone: at least 16.6 u for v1 and 5.1 u for v4 (left wrist).
3. **Torso and head clear of the stone.**
   - v1 keeps wood's station, R−S = 576. It reuses the existing haul stands beside M and R, so the
     protected work area needs no change. But the snout is only 1.7 mm from the stone.
   - v4 moves the stone 64 u farther out (R−S = 640). The head is then 63 mm clear, but stone hauls would need
     their own stands.
   - **Recommendation: v1**, because it shares the certified stands. Switch to v4 if the snout gap reads wrong
     or the lift later fails.
4. **Both soles planted.**
   - Exact sole gaps are about 0.0020 u (left vertex 16125, right vertex 3622).
   - The stone rests on vertex 51, about 0.0020 u above the floor.

## Reproduce

`invocation.json` lists every command and SHA-256 pin. `tests.log` holds both test runs:
`test_stone_grip.py`, 8 tests (rebuilds, exact proofs, and the counterexamples: short hands, buried hands, a
lifted stone, an unplanted pose); and `test_stone_source.py`.

## Verdict

Brendan approved **candidate v1** on 2026-10-06; see `review-acceptance.md`. That note also records the
star-shaped containment successor proof.
