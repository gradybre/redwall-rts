# Tread installation tap, revision 2: human review packet (ADR 1209 step 4)

## Why this revision

Brendan reviewed revision 1 (`../tread-install-review-v1/`) on 2026-10-07 and chose **Revise**: the pick looked
awkward. The handle was too steep and crossed the body. He did not object to the lean, the station or the strike.

The measured cause is the v3 grip:
- the shaft stood 87° from horizontal;
- the hand sat 21 u **inboard** of the adze head, right in front of the chest.

Revision 1 needed that steep handle because of the solver. The accepted solver puts the elbow on its original
bend side, and this close to the feet that folds the forearm across the shaft.

## What changed (`../author_tread_install_v2.py`)

**Only the elbow.** For each key the solver considers the circle of elbow positions that keep both arm links their
exact length. It takes the one whose forearm, seen from the hand, points most nearly as in the accepted ready grip.

Everything else is reused from revision 1, line for line or by import:
- the tool orientation and placement lines;
- the limb-closing rotations;
- the planted legs;
- the station, 310 u behind the edge, and the workpiece;
- the fixture;
- the tap keys, the entry and the recovery;
- every proof.

The handle lean is held to the accepted range, 25–50°. Revision 1's backward torso pitch is still allowed, but it
is no longer needed: candidate b stands upright.

## Comparison at the contact key (`comparison.json`)

| | Torso | Handle lean, azimuth | Strike (x, z) | Shaft angle | Hand vs head (x) | Wrist turned from ready | Tool to body |
|---|---:|---|---|---:|---:|---:|---:|
| accepted v4 (L0 → T0) | 0° | 35°, 30° | 128, −448 | 65.7° | +70 outboard | 76.7° | 7.8 u |
| **v3** (revision 1, reviewed) | −25° | 60°, 30° | 128, −246 | **87.2°** | **−21 inboard** | 78.9° | 7.8 u |
| **a** | −15° | **35°**, 15° | 208, −300 | **65.7°** | +26 outboard | **0.7°** | 7.8 u |
| b | 0° | 40°, 15° | 208, −300 | 70.7° | +17 outboard | 4.2° | 7.8 u |
| c | −30° | 40°, 30° | 160, −270 | 70.7° | +53 outboard | 5.5° | 7.7 u |

How to read the columns:

- **Shaft angle** is the line from the adze end to the grip, measured above horizontal.
- **Hand vs head** is the grip's x minus the adze end's x. Positive means the hand is outboard of the head, so the
  shaft hangs down the mole's right side instead of across its front.
- **Wrist turned from ready** is the angle between the forearm's direction seen from the hand and the same direction
  in the ready pose.
- **Tool to body** is the float vertex gap to the non-grip body over every key.

## The candidates

All three pass every accepted proof, unchanged (`../tread-install-v2/candidate-*/proof.json`):

- the exact adze crossing patch lies on the bearer's top;
- the tool below the plane stays inside the bearer;
- continuous self-clearance holds over the work, entry and recovery clips;
- the world proof holds against all seven prisms, with full-foot support and sole contacts only.

Toes to bearer stay 13.7 u and heel band to riser 13.6 u. The images are `a7d83bc6b436…`, `7b197b9562bd…` and
`e1e36e0d1361…` (114,860 bytes each).

**Recommendation: a.** It holds the handle at the accepted motion's own angle (35° lean, 65.7° shaft) and keeps the
ready wrist almost exactly (0.7°). The shaft runs down the right side, and the torso leans back only 15°.

- If any backward lean reads wrong, take **b**, which stands upright at a 5° steeper shaft.
- **c** keeps the accepted 30° azimuth, but its head lies diagonally across the front, so it reads closer to v3.

## Images

These are orthographic painter renders, not proofs. Grip triangles are tinted. Green outlines are the support
deck and the deck behind; orange is the bearer.

- `candidate-a/overview.png`, `candidate-a/hands.png`, `candidate-a/motion.png`
- `candidate-b/…` and `candidate-c/…`, the same three images each
- v3, for comparison: `../tread-install-review-v1/candidate-v3/overview.png`

## What to judge

1. **The hold.** Does a's pick hang down the right side at a natural angle?
2. **The lean.** Is a's 15° backward lean fine, or is upright b better?
3. **The strike.** The adze end meets the bearer's top 10 u inside its front edge, toward the right end
   (x = 208 of ±256).
4. **The entry swing** (`motion.png`, side views of entry keys 0/10/20/30 and tap keys 0/16).

## Not addressed: one hand on the handle

The accepted pick source is held in the right hand only, as in v4. A two-hand hold would need a second grip and a
new grip exclusion in the self-clearance proof, which changes an accepted proof, so it is not attempted.

## Still open (unchanged from revision 1)

- the 141 u arrival step back from the descent's end;
- T6's sill bearer, whose plane is y = 64;
- the handling program, native capture, the integer rows, content 7 and the Frontier.

## Reproduce

`invocation.json` lists the commands. The gitignored demo assets were staged from the frozen
`redwall-rts-codex-ug-space` worktree, verified against their pins, and removed afterwards.

`../test_tread_install_v2.py` holds 7 tests: the swivel's link lengths and preference, an unreachable hand,
the domain, the stored proofs and pins, the image digests, the comparison, and the reconstruction. The
reconstruction test skips without the assets. `tests.log` holds both runs.
