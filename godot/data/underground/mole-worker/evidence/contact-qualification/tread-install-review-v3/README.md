# Tread installation tap, revision 3: human review packet (ADR 1209 step 4)

## Why this revision

Brendan reviewed revision 2 on 2026-10-07 and chose **Revise**: the grip looked strange. The hand's orientation on
the shaft read wrong. It should wrap the handle from the side with the thumb toward the head, not hold the end from
above.

## What the grip can and cannot change

**The paw-to-pick fit is fixed by the pick source.** Every revision, the accepted fitting motion (v4) and the ready
carry use the same rigid fit, with no regrip. That fit holds the handle by its end: the grip pivot is 0.68 of the
handle's 0.95 half-length from the head. The shaft enters the paw's palm (the tinted triangles).

That end grip itself cannot move in this packet:
- sliding the paw along the shaft (choking up) would be a regrip, and Brendan did not ask for one;
- a different fit would mean a new pick source.

**Two things decide how the fist reads, and revision 3 sets both.**

1. **The wrist.** This is where the forearm enters the paw. Revision 2 aimed the forearm as in the *ready carry*,
   where the pick is held up and forward, so with the head lowered the forearm came down onto the paw from above.
   Revision 3 aims the elbow at **the accepted v4's own contact wrist**: the forearm direction seen from the hand at
   v4's contact key, read from the pinned v4 image. It also uses v4's own handle lean and azimuth (35°, 30°).
2. **The roll.** The pick and the paw turn together about the handle's own axis, through the adze contact point. The
   adze end stays on its strike point and the paw turns around the shaft. Candidates e and f roll 30° and 45° so the
   paw comes onto the shaft more from its side.

Everything else is reused unchanged from revisions 1 and 2:
- the station, 310 u behind the edge;
- the bearer and the fixture;
- the swivel elbow circle;
- the tap keys, the entry and the recovery;
- every accepted proof.

**Finding.** With roll 0 (candidate d), the paw, wrist and pick at contact match v4 within 2.8°. The from-the-end
grip that remains is the accepted motion's own; `grip-comparison.png` shows v4 at the same zoom.

## The candidates (`../tread-install-v3/`, all clear every proof)

Every candidate is upright (torso 0°) with a 35° lean and 30° azimuth.

| | Strike (x, z) | Roll | Shaft angle | Hand vs head | Wrist vs v4 at contact | Tool to body |
|---|---|---:|---:|---:|---:|---:|
| accepted v4 (L0 → T0) | 128, −448 | 0° | 65.7° | +70 | 0° (itself) | 7.8 u |
| rev2 a (reviewed) | 208, −300 | — | 65.7° | +26 | ~76° (it kept the ready wrist) | 7.8 u |
| **d** | 160, −270 | **0°** | **65.7°** | **+70** | **2.8°** | 7.7 u |
| e | 160, −246 | −30° | 61.0° | +173 | 3.1° | 7.8 u |
| f | 160, −246 | −45° | 54.7° | +224 | 2.6° | 7.8 u |

How to read the columns:

- **Shaft angle** is above horizontal.
- **Hand vs head** is the grip's x minus the adze end's x; positive means the hand is outboard.
- **Wrist vs v4** is the forearm direction seen from the hand, compared with v4's contact key. It is measured at
  the contact key; over the whole tap it peaks at 25°, 17° and 11° for d, e and f.
- The values come from `comparison.json` and the candidates' `pose_solver_diagnostics`.

The images are `f164bdb01996…`, `7a10e15c35d8…` and `8664bbd88bb2…`. Each candidate also holds 13.7 u to the
bearer and 13.6 u to the riser.

**Recommendation: d.** It is the accepted fitting motion's own grip, wrist and handle angle, moved to the tread
station. If the paw should come onto the shaft more from the side, **e** rolls it 30° with the wrist still v4's.
**f** rolls further, but its shaft drops to 55°.

## Images

**Grip close-ups** (new; zoomed ×1.4 on the paw; front, right side with the paw toward the camera, top):
- `grip-comparison.png`: the ready carry, accepted v4, rev2 a, and d, e and f at the contact key, all at one zoom.
- `candidate-d/grip.png`, `candidate-e/grip.png`, `candidate-f/grip.png`: v4 above each candidate.

**Whole pose**, as before: `candidate-*/overview.png`, `hands.png` (the adze, the feet and the riser) and
`motion.png`.

Digests are in `grips.json` and each `review.json`. These are painter renders, not proofs.

## What to judge

1. **The paw.** In `grip-comparison.png`, does d read like v4 (which was accepted), and is that acceptable here?
2. **The roll.** Do e or f wrap the shaft more naturally from the side?
3. **The whole pose.** The `overview.png` for the chosen candidate.

## If the end grip itself must change

Holding the shaft further down, with the thumb wrapped, needs a regrip, either a choke-up or a new pick fit. That
is new source authoring with its own grip proof, as wood's and stone's grips had. Brendan did not ask for it.

## Still open

- the arrival step back from the descent's end;
- T6's sill plane (y = 64);
- the handling program, native capture, the integer rows, content 7 and the Frontier.

## Reproduce

`invocation.json` lists the commands. The demo assets were staged from the frozen `redwall-rts-codex-ug-space`
worktree, verified against their pins, and removed afterwards.

`../test_tread_install_v3.py` holds 7 tests: roll identity and axis, the roll domain, the stored proofs and pins,
the image digests, d matching v4, and the reconstruction. The reconstruction test skips without the assets.
`tests.log` holds both runs.

## Verdict (2026-10-07)

Brendan chose **re-fit the pick grip**. The paw should wrap the shaft lower down, fingers and thumb around it,
instead of the handle's end butting into the palm. This needs a new pick fit, authored as a successor; see ADR 1209.
