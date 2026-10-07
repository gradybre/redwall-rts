# Paw handling and paw seating of the L0/T0 bearers: human review packet (ADR 1217 step 2, DEC-052)

No tool: both paws do what the pick-holding handling row 29 and the adze tap of INSTALL row 16 did.

## The two motions (`../paw-seat-v1/candidate-a/`)

Both start from the approved corrected stand (step 1c) and step 1b's approved posture recipe: hip drop with sole
planting, squared shoulders, lean and head lift. Both use the accepted fixed-length arm solve.

| Motion | Replaces | What the paws do |
|---|---|---|
| **Handling (`seat_*`)** | row 29 (left palm on the bearer, right hand holding the pick) | Both paws come to rest on the delivered bearer's top. Each paw's lowest point sits 1/512 u above it, the accepted seat's own gap. Two identical keys, as the accepted seat has. |
| **Seating (`tap_*`)** | row 16 (adze tap) | Both paws press the bearer's top together. The accepted tap's height law is unchanged: 80 u above the top down to 2 u below it, smoothstep over 17 keys, mirrored to 33. |

**Contacts.** The right paw works at row 16's own contact point (128, 128, −448) and the left at its mirror
(−128, 128, −448). Both points lie on both bearers' common section (station-local z ∈ [−512, −384]), so one
program serves L0 (from H) and T0 (from station 3).

**Contact vertex.** For each paw it is the paw's lowest vertex in its work frame (vertex 4 right, 13886 left). Only
vertices weighted entirely to the hand bone qualify. The seat then raises each paw until its lowest skinned point
over the bearer sits on the top.

**Entry**, 31 keys from ready:

1. The body settles into the work posture with the arms carried as they hang.
2. The arms reach. Each contact point follows the accepted handling entry's path: up to 128 u above its work point
   over 30/46 of the reach, then straight down. It moves forward first and sideways and up later, so the paw leaves
   the body's side before it turns in.
3. The elbows turn outward as the arms reach. Without this, the left elbow swung back into the hip.

The recovery is the exact reverse.

**Recipe:** lean 40°, hip drop 64 u, head lift 60°, both palms rolled 90° (palms facing each other, claws forward
and down).

## Proofs (`../paw-seat-v1/candidate-a/proof.json`, all clear, no exception)

They cover both programs and both installations, using the accepted install fixtures unchanged (L0 from H;
T0 from station 3, standing on L0):

- **World prisms.** Every triangle is checked against every solid on every interval, with the accepted sole rule.
  On the bearer:
  - non-paw triangles separate from the whole prism;
  - paw triangles separate from the prism lowered to y ≤ 125, one integer unit below the tap's deepest key. A paw
    may rest on the bearer and press into its top by no more than the accepted tap's own 2 u.
  - The tap work has 442 pairs: 384 soles and 58 paw-on-bearer contacts. The seat entry has about 470 pairs.
    Nothing is unresolved.
- **Seating contact.** Each paw's contact vertex crosses the top once, downward, on edge 14→15. The anchors are
  exactly (±128, 128, −448), with ±1 u patches on both bearers' tops.
- **Self-clearance.** Each arm is checked against everything without that arm's weight, and the two arms against
  each other:
  - the work keys have no candidate pairs;
  - the entries have up to 464 candidate pairs, all separated;
  - shoulder seams are excluded (1,433 right, 2,252 left).

**Search** (`../paw-seat-probe-v1.json`):

- The grid has 480 recipes, of which 270 solve with unchanged arm links and pass the float check.
- Five of the float-clear recipes went through the exact proofs. Candidate a is the only one that clears every proof:
  - the other four failed on the left arm in the entry or on ground contact;
  - roll 0 (palms flat down) put the two paws into each other;
  - other rolls sank a paw past the 2 u allowance.

## Images (`candidate-a/`)

| Image | What it shows |
|---|---|
| `overview.png` | The tap's deepest key (paws pressing) from the front, the side and the top. Orange is the T0 bearer; green is the L0 deck and supports. |
| `hands.png` | Both paws on the bearer at ×1.3, at the handling seat (row 1) and the tap's deepest key (row 2). |
| `motion.png` | Side views: handling entry keys 0, 15, 22 and 30 (= the seat), then tap keys 0, 8, 16 and 24. |

These are painter renders, not native captures.

## Checklist for Brendan

1. **The paws read as seating timber** (`motion.png`, `overview.png`). With palms rolled 90° the paws stand on
   their claws, palms facing each other. Palms flat down did not clear.
2. **The two motions.** Handling places both paws on the bearer; seating presses twice per cycle. Is a separate
   handling step still wanted, or should one paw motion carry both?
3. **The entry:** settle first, then reach.

## Next, after approval

1. Native capture.
2. Claw rows and the Frontier successor at 1,430 u.
3. The content successor, carrying the corrected stand and walk.
4. The runtime switch.

The tread seating below T0 (Brendan, 2026-10-07) reuses this motion per tread, with ADR 1209's station 310 u
behind each tread's far edge and the T6 sill at y = 64. It will be proved on the tread fixtures after this review.

## Reproduce

`invocation.json` lists the commands. Inputs were staged from the frozen `redwall-rts-codex-ug-space` worktree:
`all-cast-v9.ugpal` (`5b368eb3…`), `mole-grip-v3.ugpal` and `world-yaw-v1.ugyaw`. They were hash-checked and
removed afterwards.

`tests.log` holds four suites:

- `../../test_paw_seat.py`: 6 tests, including a byte-identical rebuild;
- step 1's `test_claw_stroke.py`;
- step 1b's `test_claw_pair.py`;
- step 1c's `test_stand_walk_v2.py`.

## Brendan's review (2026-10-07): **approved**

Candidate a is approved. Handling and seating stay two separate motions.
