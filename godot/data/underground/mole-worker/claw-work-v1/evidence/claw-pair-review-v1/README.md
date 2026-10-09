# The two-paw claw stroke: human review packet (ADR 1217 step 1b, DEC-052)

This packet carries out Brendan's review of step 1:

- the cut stations move in to 1,430 u;
- **both paws scoop alternately**;
- the open paw is used for digging (the shape change from the haul paw is accepted).

It is for his review of the two-paw stroke.

## What changed from the one-paw stroke (step 1, candidate a)

Everything else is step 1's recipe: the open paw, tool-free stand key 8, hip drop with sole planting, lean, the
accepted fixed-length arm solve, and the 33-key rake loop from 80 u above the face to 60 u below it.

- **Both paws, half a cycle apart.** Each paw has its own claw tip, its most distal vertex: 2 on the right paw,
  14014 on the left. Each paw follows the loop at a mirrored lateral offset, the left 16 keys behind the right. One
  paw scoops while the other comes back over the top. The clip starts a quarter-turn into the loop, where both claws
  are 10 u above the face, one going down and one coming up. Each claw crosses the face downward exactly once per
  cycle: the right on edge 0→1, the left on edge 16→17.
- **Squared shoulders.** The supplied idle stands with its shoulder line turned 26° and tilted 3.5°: the left
  shoulder is back and up. The one-paw stroke never noticed this. With two paws the left arm could not reach the
  face (0 of 4 rolls solved). `squaring` measures the line on the stand and turns the upper body rigidly about
  Spine02 to square it, the same kind of turn as ADR 1144's lean.
- **Head lifted.** Leaning 70°, the forearms grazed the cheeks. This was unresolved in the exact self proof at
  head lift 0 and 30, and at paw offsets of ±128 and ±160. The head now turns up 60° about the neck joint, so the
  mole looks at the face. At ±192 and ±224 with the 60° lift every arm pair separates.
- **Lean and drop.** 70° and 96 u. These are the only lean and drop on the grid that kept everything except the
  paws above the face and the paws inside the cube (27 of 288 recipes, `../claw-pair-probe-v1.json`).
- **Anchor.** The claws enter the face at z = −544, 138 u inside the moved-in cube. Candidate a entered at −608
  with one paw.

## Candidates (`../claw-pair-v1/`)

| | Paws at x | Anchors (right / left) | Paw below face (x, y, z) | Proofs | Entry: stand contact released over |
|---|---|---|---|---|---|
| **pa** | ±224 | (224, 0, −544) / (−224, 0, −544), ±1 u patches | [−226, −61, −561] to [287, 0, −418] | **clear** | entry intervals 0–5 (346 pairs) |
| pb | ±192 | (192, 0, −544) / (−192, 0, −544) | [−194, −61, −561] to [255, 0, −417] | clear | entry intervals 0–6 (411 pairs) |

Both candidates share lean 70°, drop 96 u, claw tilt 60°, palm rolls 90° (right) and 90° (left), and head lift
60°. The station is at 1,430 u, so the cube's near face is at −406.

**What "clear" covers**, for the stroke and the entry (the recovery is the entry's exact reverse):

- **Contact.** Each claw crosses the face downward on exactly one rendered edge. Both patches lie on the cube's
  top face.
- **Below the face.** The clipped hull reaches only paw triangles (164 of them), and it stays inside the cube.
- **World.** For pa's stroke, 1,884 triangle–solid pairs: 384 sole contacts and 1,500 paw-in-cube pairs. The entry
  has 484 pairs, all of them soles. Nothing is unresolved.
- **Self-clearance** (step 1's rule, for each side):
  - right arm (1,000 triangles) against the 7,776 triangles with no right-arm weight;
  - left arm (1,056) against the 6,901 with no left-arm weight;
  - right arm against left arm.
  - All pairs separate. The seams excluded are 1,433 triangles on the right and 2,252 on the left.

**One finding needs your eye: the stand's left paw rests in its thigh.** The accepted tool-free stand (ADR 1199,
the published rows 30/31) holds the left paw slightly into the left thigh.

- Held still, ready key 8 leaves 9 left-paw × left-thigh triangle pairs unseparated, across 4 paw and 5 thigh
  triangles. The one-paw stroke never moved that arm, so this never showed.
- As the entry lifts the paw away, it slides out of the thigh over the first 6 of 30 entry intervals (pa) or 7 (pb):
  23 paw triangles against 36 or 46 thigh triangles.
- The prover reports these pairs apart, instead of failing. It requires them to form an unbroken run from the ready
  key, which means the paw is leaving and never returns. The stroke allows no such exception.
- Every other pair, including the rest of the left arm against the thigh, is proved.

## Recommendation: pa

It has the widest stance of the paws, the shortest release from the thigh, and the fewest arm–body near pairs
(14 against pb's 506 in the stroke).

## Images (`candidate-*/`)

| Image | What it shows |
|---|---|
| `overview.png` | The right paw's contact key, front, side and top. Orange: the cube (near face at 1,430 u). Green: the support earth. |
| `hands.png` | Both paws at the right paw's contact key (row 1) and the left paw's (row 2), ×1.3. |
| `motion.png` | Front (row 1) and side (row 2): entry 0 (ready), entry 30 = stroke 0, then stroke keys 8, 16, 24 and 31. |
| `compare.png` | **One paw against two.** Top row: step 1's candidate a, side and front, at its contact and deepest keys. Bottom row: this candidate at the right and left contacts. Same station and zoom. |

These are painter renders, not native captures. Both paws are tinted.

## Checklist for Brendan

1. **The two-paw scoop** (`motion.png`, `compare.png`). Does it read as a mole digging?
2. **The raised head.** It is up 60° so the snout clears the forearms. Is that acceptable, or should the head stay
   lower with the paws wider apart?
3. **The left paw leaving the thigh** in the first fifth of the entry. Accept it as the stand's own contact, or ask
   for a separate lift-off in the entry, which would be a new authored path.
4. **pa (±224) or pb (±192).**

## Not done, and why

- **Frontier successor.** It is not published in this run. Its station rows name the WORK profile, and its header
  links the profile wire's content revision and source digest. The claw rows exist only after this stroke is
  approved and the content successor is published. ADR 1217 records the order.
- **Waiting on approval:** native capture, the integer rows (yaw 0 plus quarter turns, with one CONTACT point and
  patch per paw or one combined patch, to be settled at row derivation), and the content successor.

## Reproduce

`invocation.json` lists the commands. `all-cast-v9.ugpal` was staged from the frozen `redwall-rts-codex-ug-space`
worktree, checked against its pinned digest `5b368eb3…`, and removed afterwards. `tests.log` holds two suites:

- `../../test_claw_pair.py`: 7 tests, including a byte-identical rebuild;
- step 1's `test_claw_stroke.py`: 10 tests, still passing.
