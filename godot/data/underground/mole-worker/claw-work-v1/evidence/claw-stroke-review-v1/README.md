# The first claw stroke: human review packet (ADR 1217 step 1, DEC-052)

This packet is for **Brendan's review of the first claw dig stroke**, and for **one choice only he can make: where
the cut stations stand.** No tool: the right paw's claws dig.

## What the stroke is

One program serves BRACE, CUT and FINISH on a cube's top face, as the pick's downward program did (ADR 1188). It is
authored for the Frontier's first episode: cube 0, worked from station 4 (yaw 49152, today's profile 25), in the
yaw-0 source frame.

- **Body: the open paw** (the original cast mesh `a938d479…`, claws spread), no held part.
- **Ready:** the accepted tool-free stand key 8 (ADR 1199), the hub of rows 30/31.
- **Posture:** ADR 1144's hip drop and sole planting, and its rigid forward lean.
- **Arm:** the accepted fixed-length arm solve with its forearm closing, aimed at the claw tip. The tip is
  vertex 2, the paw's most distal vertex along the claws.
- **Stroke:** a 33-key loop. The claws come from 80 u above the face (the fitting tap's raise), go down through
  the face at the anchor, rake back to 60 u deep (the pick stroke's own depth) and come up behind the anchor.
- **Entry:** 31 keys from ready; the arm is solved on every key. **Recovery** is the exact reverse.

## The finding: from today's stations the claws cannot dig the cube

Today's cut stations stand 1,536 u out, 512 u behind the cube's near face (ADR 1188). The open paw reaches the face
only about 70–100 u inside the cube. Its own length then puts the back of the paw under the face **behind** the
near edge, in retained earth that is not part of the paid cube.

- **Candidate p** (station 1,536) is the best of the bounded search at that station. The exact below-face hull of
  its paw reaches z = −486, which is **26 u past the near face** (−512). The world proof refuses.
- **The search** (`../claw-stroke-probe-v1.json`): 3,672 recipes on a grid of lateral offset, anchor, rake, lean,
  hip drop, claw tilt, palm roll and station. 892 solve with unchanged arm links. Of the 94 that solve at station
  1,536, **none** keeps the paw inside the cube. 137 do at the moved-in station.
- **The pick could do it** because its head reached 673 u ahead of the root on a long handle.

## Options for Brendan

1. **Recommended: move the six cut stations in by 106 u, to 1,430 u.** 106 is not a choice: it is the most the
   tool-free stance allows. Rows 30/31 have a 406 u stance half-width, and ADR 1188 keeps the whole all-yaw foot
   certificate off the future pocket: 512 − 406 = 106. The cube then starts 406 u ahead, and candidates a, b and c
   clear every proof.
   - **Cost:** a Frontier successor (stations 4–9, their endpoints and perimeter paths), re-proved through
     WorldRoutes and Locations.
   - **Lost:** ADR 1188's 106 u margin. The foot certificate then touches the pocket's edge.
   - **Unchanged:** the cuts, the bills and the work amounts.
2. **Keep 1,536 and scratch only the surface.** A float sweep finds that the paw stays inside only if the claws go
   about 12–24 u deep instead of 60 u. The 24 u case clears the edge by only about 2 u. That would be a new depth
   constant for Brendan to set, and it reads as scraping rather than digging. **Not recommended.**
3. **Something else.** For example, dig the first cube from inside a starter hole, or with both paws. Each needs
   new design; nothing published supports it.

## Candidates (`../claw-stroke-v1/`)

All four share the posture recipe's shape. **a is p moved in**: every clip byte is identical, so the pair isolates
the reach.

| | Station | Lateral x | Anchor z | Rake | Lean | Drop | Tilt | Paw below face (x, y, z) | Proofs |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| **p** | 1,536 | 128 | −608 | 32 | 60° | 96 | 60° | [61, −61, −620] to [191, 0, **−486**] | **refused**: the paw leaves the cube |
| **a** | 1,430 | 128 | −608 | 32 | 60° | 96 | 60° | [61, −61, −620] to [191, 0, −486] | **clear** |
| b | 1,430 | 128 | −576 | 64 | 60° | 64 | 60° | [61, −61, −586] to [191, 0, −429] | clear |
| c | 1,430 | 160 | −608 | 64 | 60° | 96 | 75° | [93, −61, −611] to [235, 0, −422] | clear |

How to read the table:

- Coordinates are station-local in u, yaw 0, with forward along −z. The cube's near face is at −512 for p and
  −406 for a, b and c.
- The palm roll is 90° for all four: palm toward the body's midline. No recipe with the palm outward (270°, the
  classic mole stroke) or away from the body (180°) cleared.
- **Contact:** the claw tip crosses the face exactly at the anchor on rendered edge 8→9, with a ±1 u patch (for
  example `[127, 0, −609]` to `[129, 0, −607]` for a). The anchor is 202 u inside the moved-in cube for a and c, and
  170 u for b.
- **World** (a): 1,146 triangle–solid pairs. 384 are sole contacts on the support earth, 762 are paw triangles in
  the target cube, and no other pair is unresolved. The entry has 484 sole pairs and nothing below the face.
- **Self-clearance:** 1,000 right-arm triangles against 7,776 body triangles. The entry has 68 candidate pairs, all
  separated. The stroke has none: the arm is clear of the body by at least 31 u (float). 1,433 shoulder-seam
  triangles with mixed weights are excluded and counted.
- **Pick comparison:** row 13's stroke reached 24–166 u into the cube from 1,536. Claw a reaches 80–214 u into the
  cube from 1,430, at the same 60 u depth.

**Recommendation: option 1, with candidate a.** It is the deepest strike, has the simplest rake, and is the exact
pose that fails at the old station.

## Images (`candidate-*/`)

| Image | What it shows |
|---|---|
| `overview.png` | The contact key (stroke key 9) from the front, the side and the top. Orange is the target cube, green the support earth. |
| `hands.png` | The paw at the contact key and at the deepest key (16), ×1.3 on the anchor. In p's side view at key 16, the back claws cross the cube's near-face line. |
| `motion.png` | Side views of entry keys 0, 15 and 30, then stroke keys 4, 8, 12, 16, 24 and 9. |

The right paw is tinted. These are painter renders, not native captures. Digests are in each `review.json`.

## Checklist for Brendan

1. **Stations:** option 1 (move in to 1,430), 2 (surface scratch at 1,536) or 3?
2. **The stroke:** does a (or b, c) read as a mole digging with its claws? Look at `motion.png` and `hands.png`.
3. **One paw or two:** the right paw digs and the left hangs. Is a two-paw stroke wanted?
4. **The paw:** the open paw here, and the closed paw on the haul rows (30–41). Is the change at the switch
   acceptable, or should travel move to an open-paw stand and walk too (ADR 1217, M6)?

## Not done, and why

These wait on the answers above:

- native capture;
- integer rows (the yaw-0 row and its three quarter turns);
- the content successor;
- the Frontier successor (if option 1).

## Reproduce

`invocation.json` lists the commands. `all-cast-v9.ugpal` was staged from the frozen `redwall-rts-codex-ug-space`
worktree into `godot/demo/assets/underground-matrices/` and checked by its pinned digest (`5b368eb3…`). It was
removed afterwards. `tests.log` holds `../../test_claw_stroke.py`: 10 tests, including a byte-identical rebuild of
every clip.
