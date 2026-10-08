# Tread fitting with a general paw working motion: review packet (ADR 1217 step 2d, DEC-058)

Brendan (2026-10-08): **"General digging motion, does not need to line up perfectly."**

The treads T1…T5 and the T6 sill are fitted from ADR 1209's tread station: 310 u behind T_{k−1}'s far edge, yaw 0,
facing down the stair. The paws need not make an exact, certified contact with the bearer, so step 2's contact
crossing and patch requirement is dropped for tread fitting. The work is accounted by the Job/Work model as usual.

## The motion (`../tread-fit-v1/`)

It is the approved paw handling seat and seating tap (step 2, candidate a's construction), unchanged in method and
re-posed at the tread station:

- the same corrected stand, posture recipe, arm solve, entry path, tap height law and exact-reverse recovery;
- adjusted where the proofs need it: lean, hip drop, paw spacing, the work point over the bearer, and the work
  height.

The work height is absolute (u above T_{k−1}'s deck). One program therefore serves T1…T5 and the sill, as one
program serves L0 and T0.

| | **b (recommended)** | c |
|---|---|---|
| Work height | **131 u** (lowest paw 1 u above a tread bearer's top) | 160 u (30 u above) |
| Paws | x = ±224, z = −300 (over the bearer's far half) | same |
| Lean, hip drop, head lift, palm rolls | 0°, 96 u, 60°, 90°/90° | same |
| Float arm-to-leg gap (worst sampled key) | 18.5 u | 34.4 u |
| Exact self-clearance candidate pairs (seat entry / tap work, left arm) | 96 / 414, all separated | 4 / 46 |

Against the approved L0/T0 recipe (lean 40°, drop 64 u, paws ±128 at z −448), the mole stands upright with a deeper
hip drop, spreads its paws wider and works over the bearer's far half. The far half is beyond its knees; step 2b
found that the paws meet the legs at the bearer's centre line.

## Proofs kept (all clear, no exception, both candidates, tread and sill)

- **World prisms with sole support** (`prove_paw_seat.world`, accepted, unchanged). Every triangle is checked
  against every solid on every rendered interval, with the accepted sole rule on T_{k−1}'s deck.
  - The solids are ADR 1209's tread fixture (support deck, bearer/post supersets, the deck behind (riser) and its
    supersets, the bearer) plus the trench side walls, at the deepest station's height (a superset).
  - **The bearer is hard for every triangle, paws included.** The paw skin is the whole bearer, so no paw enters
    its top.
  - Tap work: 384 pairs, all sole contacts. Seat entry: 462–468 pairs. Nothing is unresolved.
- **Self-clearance** (`prove_claw_pair.self_rows`): each arm against everything without that arm's weight (legs
  included), and arm against arm, on the entry and work of both programs. Recovery is the exact reverse of the
  entry.

**Dropped for tread fitting** (Brendan's ruling): the exact contact crossing and its patch on the bearer's top.

Search: `../tread-fit-probe-v1.json` has 96 recipes, 64 of them solvable with unchanged arm links. The exact trials:

- lean 15° at 131 u failed, on paw triangles crossing the bearer in entry intervals 18–20, and on the left arm
  against the body at the sill when the work height followed each bearer;
- b and c clear at a common absolute height.

## Images (painter renders, not native captures)

| | Tread (T1…T5, bearer top 128) | T6 sill (bearer top 64) |
|---|---|---|
| b, overview: tap key 16 (paws lowest), front, side and top | `candidate-b/tread/overview.png` | `candidate-b/sill/overview.png` |
| b, motion: handling entry 0/15/22/30, tap 0/8/16/24 | `candidate-b/tread/motion.png` | `candidate-b/sill/motion.png` |
| c, the same | `candidate-c/tread/…` | `candidate-c/sill/…` |

Feet are blue and paws brown. Green: decks and supports. Orange: the bearer.

## Checklist for Brendan

1. Does b read as the mole working the timber at the stair's edge (`candidate-b/tread/motion.png`)?
2. At the sill the paws work about 65 u above its lower bearer. Is that acceptable, or should the sill get its own,
   lower program (re-proved)?
3. b or c?

## Not done

No native capture, rows, content or Frontier rows have been made. The stair gaits still need their tool-free re-proof
(M7). Nothing is production-qualified.
