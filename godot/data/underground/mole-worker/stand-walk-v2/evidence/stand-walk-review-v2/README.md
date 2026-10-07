# Corrected tool-free stand and walk: human review packet (ADR 1217, successor to ADR 1199)

Brendan approved the two-paw dig pa, and chose to **fix the paw-in-thigh at the source, for digging and for
everything else**. This packet is for his review of the corrected stand and walk, the clips behind rows 30/31 and
their haul joins.

## What was wrong (measured)

Step 1b's exact per-arm interval separation checks each arm against every triangle with no weight on that arm. On
the published clips (ADR 1199) it found:

| Clip | Left paw vs left thigh | Right paw vs right thigh and shin |
|---|---|---|
| stand (121 intervals) | unseparated on 75 | 41 (open paw) / 21 (closed paw) |
| walk (44 intervals) | 3 | clear |

The supplied idle rests both paws into the thighs. The haul joins start from that stand's ready key, so they
inherit it.

## The correction (`../stand-walk-v2/`)

- **One constant outward swing per upper arm.** Bone 13 or 17 turns about its own joint, around the body's forward
  axis, by the same angle on every key. The forearm, the hand and every other bone keep their supplied local
  transforms, so the idle and walk motion, rhythm and loop closure are the supplied ones. Grounding is unchanged.
- **Angles found by search, not chosen.** A bisection over whole degrees found the smallest angle at which every
  pair separates on the stand and the walk. The check runs on both bodies: the closed paw drawn by the haul rows and
  the open paw used for digging.
  - **Left 11°:** 10° still leaves 2 unseparated pairs.
  - **Right 13°:** 12° still leaves 10 pairs, on the open paw, whose spread claws reach the shin.
  - The full trail is in `candidate.json`.
- **Joins re-authored by their accepted recipe.** The wood and stone joins are rebuilt from the corrected ready key
  into each haul program's unchanged first key. "Leave" is the exact reverse.

## Proofs (`../stand-walk-v2/proof.json`, all clear)

- **Floor and one-foot support** (`prove_empty_walk.support_proof`, unchanged) pass for the stand and walk on both
  bodies and for all four joins. No vertex goes below the floor.
- **Paws out of the body:** each arm against everything with no weight on that arm, with **no exception**, on
  every rendered interval. Every pair separates in the stand and walk (both bodies) and in the four joins (the closed
  paw, which the haul sources draw).
- **Stock separation:** the wood joins pass `prove_empty_walk.join_proof` and the stone joins pass
  `prove_stone_joins.prove`.
- **The approved dig pa from the corrected ready key:** re-authored and proved with the stand-contact release
  switched off.
  - It clears: both contacts at ±224, −544 and paw-only below the face, inside the cube.
  - The entry's left arm now separates with no exception (250 candidate pairs, 0 released).
  - Step 1b's `released_stand_contact` is no longer needed.

**One consequence for the rows.** The all-yaw STAND/WALK body sweep these clips would publish grows from 651 to
712 u, because the paws hang wider. That is still inside the pick-era ground row 12 (738). The floor and stance
boxes are unchanged (402 / 406). This lands only when the content successor carries it; rows 30/31 and the v8/v9
images are untouched until then.

## Images (this folder)

| Image | What it shows |
|---|---|
| `paws.png` | Close-ups (×0.9), front and side, of each paw at its thigh. Shown at ready key 8 and at the stand key where that paw comes closest to its thigh (left: 38, right: 75). Each pair of rows is published above corrected. Paws are tinted, thighs darker. |
| `walk.png` | The walk cycle every 6th key. Rows: front published, front corrected, side published, side corrected. |
| `overview.png` | The whole mole at ready key 8: published and corrected, front and side. |

These are painter renders on the closed paw (rows 30/31's body), not native captures. Digests are in
`review.json`.

## Checklist for Brendan

1. **Do the arms read naturally** at 11° and 13° further out (`overview.png`, `walk.png`)? Or should the swing be
   larger or equal on both sides?
2. **Paws clear of the thighs** in `paws.png`.

## After approval (ADR 1217's order)

1. Paw handling and seating of the L0/T0 bearers.
2. Native capture: the corrected stand, walk and joins, and pa.
3. The claw rows, and the Frontier successor at 1,430 u.
4. The content successor: claw source plus corrected stand and walk, rows 30/31 successors.
5. The runtime switch.

## Reproduce

`invocation.json` lists the commands. Inputs staged from the frozen `redwall-rts-codex-ug-space` worktree:

| File | Digest prefix |
|---|---|
| `all-cast-v9.ugpal` | `5b368eb3…` |
| `mole-grip-v3.ugpal` | `08de5453…` |
| `world-yaw-v1.ugyaw` | `de8c3b04…` |

Each was hash-checked by the tools and removed afterwards. `tests.log` holds `../../test_stand_walk_v2.py`:
5 tests, including a byte-identical rebuild.
