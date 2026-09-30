# 0207 — Swept bores, lantern light and the stoop
Date: 2026-09-30 · Status: Accepted

Phase P1 ("Bore look and traversal") of the approved underground revamp
([`docs/design/underground_revamp.md`](../design/underground_revamp.md) §3, §5, §6 and §8 P1; Brendan's
rulings in its §10). It builds on [0206](0206-the-underground-view-is-a-layer-cutaway.md) (P0's layer
cutaway, cap and prewarm) and keeps [0205](0205-the-playtest-fix-pass.md)'s walk pace. It answers two
playtest notes (`docs/playtests/2026-09-29-windows.md`): "Make us actually see and feel the tunnel" and
"Mouse slides along tunnel underground, doesn't move feet or crouch through them". Everything here is
presentation: nothing writes into the simulation, the tunnel network, router, chambers and jobs are
untouched (P2 and P3 rewrite them), and MOVE-G01–G05 stay open.

## Decision

### 1. Swept geometry, not voxels

Each tunnel's dug length is a hand-dug horseshoe tube swept along its centreline
(`demo/tunnel/bore_mesh.gd`, `bore_curve.gd`, `bore_view.gd`), replacing 0206's interim half-round
trough. The design's recommendation stands (its §6 cost table): a swept profile is cheap to build in
GDScript, controllable and clean to texture; marching cubes would take seconds a rebuild in GDScript and a
native toolchain for two platforms, and DEC-029 does not prescribe voxels.

- **The profile** is 16 points: a flat floor, walls bowing out to 1.1× the floor's half-width at the
  springline (0.45 of the crown up), and an elliptical arch to the crown. Its normals and triangles face
  **inward**, so with back faces culled the near wall and the roof cull themselves from above and the U
  view sees the floor and the far wall (design §5 "Walls").
- **Rings** stand every 0.25 m of route distance (4 a metre), upright at the floor's height, plus one at
  the dig face. Each ring is one of 8 pre-jittered copies of the profile (walls ±4 cm along their normal,
  the floor ±6 mm so feet still meet it), picked by a hash of the ring's index and slightly widened or
  narrowed (±3.5%): rough and irregular, never a clean tube, and the same ring always looks the same.
- **The centreline** is the route polyline with each corner rounded by a symmetric quadratic fillet
  (`bore_curve.gd`). Such a fillet is tightest at its middle, where its radius is r·cos(turn/2) for a
  tangent length r·tan(turn/2); r is set to `bend_radius` / cos(turn/2), where `bend_radius` is the
  bore's widest jittered half-width plus 5 cm (0.66 m standard, 1.23 m widened). So at the tightest point
  the inner wall still has room and does not fold. A test sweeps a right-angled L in both classes and
  finds no floor triangle turned over.
  - A fillet takes at most 45% of either leg. A corner too sharp for its short legs is rounded only as
    far as they allow, and can still fold (a 90° standard corner needs legs of 2.1 m, a 120° one 5.1 m).
- **One curve a tunnel.** `BoreCurveScript.of(network, slot)` is shared and rebuilt when the tunnel's
  generation, class or route changes. Everything underground stands on that one drawn centreline, so
  nothing stands in a wall at a corner:
  - the bore's rings;
  - its stones and roots;
  - the walkers and the digger (`resident_brain.gd stand_in_bore`), whose heading now turns smoothly
    round a corner;
  - the braces and lanterns.

  At a right-angled corner the drawn centre runs about 0.33 m (standard) or 0.62 m (widened) inside the
  polyline's corner. The route's rules are unchanged and are still checked on the polyline, as is the
  surface.
- **Chunks.** A tunnel is up to five meshes of 64 bands (16 m) on the fixed ring lattice. As the face
  advances only the chunk it is in is swept again (and, once, the one it left, to drop its face wall);
  a change of state (bore class, a widening's step, a flood, a fall, a new tunnel in the slot) sweeps them
  all. A 32 m bore -- 129 rings, 2,064 vertices -- is swept, sampled and committed in about **0.2 ms**
  headless (the test's budget is 2 ms). The per-frame per-tunnel P0 trough is gone.
- **Per vertex:** UV is the profile coordinate (for the packed floor and its worn path), COLOR the ring's
  state (R flooded, G rubble; B and A spare for P5's hazards), UV2.x the game day the ring was dug.

### 2. The bore dimensions (demo values)

| | floor | widest | crown | where |
|---|---|---|---|---|
| Standard bore | 1.0 m | 1.1 m | 1.0 m | design §3 "Geometry" |
| Widened bore | 2.0 m | 2.2 m | 1.1 m | the design's 2 × 3 quanta is **paid**; drawn, the crown is held to 1.1 m |

- The widened bore's paid height (three quanta) is kept for time and spoil. It cannot be **drawn**: level
  1's floor is 1.25 m down, and a 3 m bore would break the surface. Its crown is drawn at the level's
  section plane, 1.1 m over the floor, so otters, the beaver and the badger stoop hard in it (Brendan's
  brief: widened bores are P3/P4 scope). `tunnel_rules.gd` names both crowns (`BORE_CROWNS_U`).
- **The section plane** (`demo_layers.gd CAP_Y_M`) moves from 0206's −0.75 m (half a bore up) to
  **−0.15 m**, the design's level-1 crown height: the widened crown, 0.1 m over the standard one.

### 3. The cap cuts the bores as a section

P0's cap discarded a fragment where its view ray met a dug **floor** point, which showed only the floor.
Walls up to the crown need more, as 0206 noted:

- The void mask becomes an RGBA distance field (`underground_cap.gd`): **G** is each pixel's distance from
  the nearest bore disc over that disc's floor half-width (out to 1.5 of it), **B** that disc's floor rise
  over the level's floor (a ramp's is higher), **A** its crown; **R** stays P0's rooms. Every dug step is
  stamped as it is dug (~41 µs a disc; a mask upload measured 0.05 ms median, 0.18 ms max).
- The cap shader walks each fragment's view ray down from the cap to the floor, 10 points, and asks at
  each whether the point is inside a bore's horseshoe at that height over that point's own floor (the
  same shape function as the mesh). If any is, the ray enters the bore: the cap is cut away and the
  far wall or floor is seen through it. A ray that only grazes a bore draws a dark cut band. Picking,
  the strata and the marks are still read at the floor point (0206 §2).
- A ramp is stamped all the way to its mouth; where it rises through the section plane it is simply cut.

### 4. The underground's earth

One world-space earth, `underground_earth.gdshaderinc`, shared by the cap and the bores (the design's
"one triplanar earth shader"), so a wall and the cut it meets are the same soil: the ground map's colour
(loam, rust clay, pale sand, grey rock, wet ground, exactly where they slow or weaken a dig) through a
soft warp, banded by height (a darker humus under the turf, a clay seam lower down), with a grain. The
cap reads it at the floor point (its strata at the floor's height, as P0 showed them); the bores'
material (`bore_earth.gdshader`) at each fragment, triplanar-grained, with:

- the floor packed hard and paler down its worn middle;
- stones bedded in the walls (a cellular noise) and root streaks under trees (the cap's root marks);
- **the drying hook**: a ring dug on game day `d` is dark and glossy and pales to dry earth over one game
  day (`now_days`, the demo calendar's day, written when it moves 0.001 of a day). P5's construction
  theatre builds on it;
- flooded rings a wet blue-grey, rubble dark;
- a 0.04 emission floor, so an unlit bore reads as dark earth, never black (design §5);
- **the cutaway**: nothing above the section plane is drawn.

**Procedural, not CC0 textures.** Free Poly Haven sets would need the Blender bridge, a new import rule
for loose textures (`tools/demo_texture_imports.py` reads roles from GLB materials only) and a
placeholder path for CI, which has no staged assets. Noise textures cost nothing, work unstaged and
match the cap. Revisit if the look asks for it.

**Stones and roots that stand proud** (`bore_dressing.gd`): per tunnel one MultiMesh of a lumpy stone
(3.5–9 cm, bedded 40% into the wall, ~0.22 a wall a step) and one of a tapering root with a rootlet,
out of the upper walls within a mature tree's root reach (the reach the cap's root tangles use), likelier
near the trunk. Only steps deep enough that the highest root stays 5 cm under the section plane are
dressed (`dressed_at`), so nothing stands through the cut on a ramp. The dice are a hash of the tunnel's generation and the step, so a rebuild re-rolls the
same stones.

### 5. The lights budget

- Lanterns are **real `OmniLight3D`s** (`tunnel_lanterns.gd`): shadowless, range 3.5 m, on the underground
  layer and lighting only it, **at most 32**, made once at boot and **pooled**. Every lit tunnel's lanterns
  are light spots. The pool gives its lights to the 32 spots nearest the U view's focus (where the
  camera's forward ray meets the level's floor). It reassigns them only when the spots change or the
  focus moves 1.5 m, choosing into a fixed row, so it allocates nothing.
- **Flicker**: each light's energy wavers ±8% (two slow waves at its own phase) on the demo clock's
  time, so a paused game holds it; it runs only while the U view is on.
- Lanterns now hang evenly over the stretch **under the ground** (between the two ramps' portals), one
  for each started 4 m as before; the one per-tunnel light 0196 hung at a tunnel's middle is gone.
- The glow in each lantern has emission ×3, so it blooms in the U view's environment.
- **Braces use the cutaway shader** (`cutaway.gdshader`, its albedo map and tint copied from the prop's
  material): a frame is fitted inside the horseshoe's arch (floor-wide, 0.72 of the crown tall) and cut
  away at a fixed height, 0.62 m over the level's floor, under its cap beam -- the beam over a walker's
  head is not drawn (design §5). On a ramp's deep end, where the floor is higher, less of a post shows.
  Frames stand only where the bore is wholly under the ground. The cutaway copies the prop's albedo map,
  tint and roughness only; the staged brace's normal and roughness maps are not drawn.

### 6. The stoop rules

`tunnel_rules.gd stoop_drop_u`: a walker in a bore lowers its head to `STOOP_CLEAR_U` (0.1 m) under the
bore's drawn crown, by at most `STOOP_MAX_PERMILLE` (35%) of its height.

| resident | height | standard bore (crown 1.0 m) | widened (crown 1.1 m) |
|---|---|---|---|
| mole | 0.90 m | 0 (upright) | 0 |
| mouse | 1.00 m | 0.10 m | 0 |
| squirrel | 1.15 m | 0.25 m | 0.15 m |
| beaver | 1.40 m | 0.49 m (35%, capped) | 0.40 m |
| otter | 1.49 m | 0.52 m (35%, capped) | 0.49 m |
| badger | 2.55 m | 0.89 m (35%, capped) | 0.89 m (capped) |

`demo/cast/stoop_modifier.gd`, a `SkeletonModifier3D` first on each rigged resident's skeleton (after
the clip, before the tail's spring):

- the **hips** come down 30% of the drop (at most 7% of the height), and each **leg is re-solved** --
  thigh and shin by the law of cosines in the plane of its own knee, the foot turned back to the clip's
  turn -- so a stoop never moves a planted foot (0202's pins hold; tested to a millimetre on a rig built
  in code);
- the **spine** bends forward over the rest, 45/35/20% of one angle at Spine02, Spine01 and Spine, the
  angle read off a table of head drop per bend built from the rig's rest pose; the **neck** takes half of
  it back so the gaze stays ahead;
- eased in and out over 0.3 s of demo time (design §6). With no stoop and no lean the modifier is
  switched off, so a resident on the surface costs nothing. Its per-pose scratch is sized once, so a pose
  allocates nothing.
- Global poses are composed from the bones' own poses up the chain: a skeleton's cached global poses are
  not refreshed outside its own update, which the headless tests never reach.

It is the base; P7 swaps in the generated `Cautious_Crouch_Walk_Forward` clips and keeps this as the
fallback. A placeholder (CI) has no rig and no stoop.

### 7. Ramps at 1:2.5, walked along their slope

- **The profile** (`tunnel_rules.gd ramp_depth_m`): down `BORE_FLOOR_DEPTH_U` (1.25 m) at no steeper than
  `RAMP_GRADE_RISE:RAMP_GRADE_RUN` = 2:5, its ends eased by parabolic fillets of `RAMP_FILLET_U` (0.875 m)
  so the grade never jumps under a walker: `RAMP_RUN_U` = 4 m a ramp (0196's was 1.25 m over 1.5 m,
  ~40°). `ramp_grade_ok` pins the constants; a test samples the whole ramp and finds 0.4000 at the
  steepest.
- **The refusal** (`REFUSE_RAMP_TOO_STEEP`): a route under 8 m would need its ramps steeper, and is
  refused -- "too short for its ramps: going 1.25 m down and back up at no steeper than 1:2.5 takes 8 m".
  The planner asks it last (`tunnel_plan.gd route_reason`), so a route under water says that first. The
  panel's length readout floors any length under 8 m, so a refused 7.96 m never reads "8.0 m".
  `validate_route` and `MIN_LENGTH_U` are unchanged.
- **Walking it** (`resident_brain.gd`): in a bore the flat step is walk speed times the slope's cosine,
  so the pace **along the slope** is the walk's and the clip, at `stride_rate()` (0205's 1.4× walk
  pace), keeps the feet on it; the body **pitches with the full slope** (`pitch`), which is what puts
  planted feet on it; and the spine takes half of that back, so the body leans into a ramp by half its
  slope (design §6's "the body pitches with half the slope").

### 8. The mouths

A mouth on the surface (`tunnel_mouth.gd`) is a procedural **fieldstone-and-timber gateway** over the
top of its ramp -- two jambs of five rough stones each, 1.2 m apart, a timber lintel at 1.3 m (a squirrel
walks under it) -- and the ramp's **cutting**: a dark strip down the ramp to where the bore goes under
(`portal_m`, 2.94 m for the standard bore, on the first or last leg) between low earthen banks. While the
entrance shaft is dug the cutting grows and the gateway waits for it. The generated `tunnel_arch` prop
(0204) has a solid slab in its doorway; P7 fixes and swaps it in. Rejected: cutting a hole in the ground
shader and drawing the ramp through it (a discard on the whole ground, and a second copy of every ramp on
the surface layer), and drawing the cutting over the ground without a depth test (it would draw over
residents at the mouth).

### 9. The underground environment

`tunnel_view.gd`: the U view sets its own `Environment` on the camera (`Camera3D.environment`) and the
surface view sets none, so the `WorldEnvironment` -- sky, sun-lit ambient, the weather's haze -- is the
surface's alone and nothing below bleeds up. It has a dark earth background, a low cool-brown ambient
(0.55), SSAO in the bores' corners, glow (threshold 1.0, soft light) so the lantern glows bloom, and a
faint warm depth haze; the underground's directional fill (0206) drops to 0.5. A switch is now two writes
(mask and environment), still no material. The boot prewarm draws its frames in the U view's
environment.

### 10. Built at dig time, registered for the prewarm

The bores, stones, roots, braces (with their cutaway) and the lantern lights are built when dug, braced
or lit, never on a toggle. `underground_prewarm.gd add_multimesh` takes an override now (the braces'),
and everything new registers when it is built: a bore sample in the builds' vertex format with its
material, the stone and the root instanced, the brace with its cutaway. The mouths are built at boot and
drawn on the surface layer.

## Why

The playtest's two notes. With P0 the U view showed a lit trough seen from above: no walls, and a walker
sliding down a 40° ramp upright at its flat pace. The swept horseshoe cut by a section plane shows the
bore as a tunnel -- walls rising to the cut, the far wall visible, stones and roots in the soil, warm
lantern pools on dark earth -- and residents who fit it by stooping, their feet planted on the ramps.

## Consequences

**Measured** on an Apple M5 Pro Mac (Metal, 1920×1080), each run with the shader and pipeline caches
moved aside. The scene is the same for both: a braced, lit 11 m tunnel beside the farm beds
((−6.2, 17.5) → (−6.2, 12) → (−4, 7)), a burrow home and a root cellar off it. "Before" is P0 (494ba1c)
in a detached worktree with the same assets; "after" is this decision's code. The probe and its logs are
in `scratchpad/revamp_p1_agent/p1probe.gd`; frames in `scratchpad/revamp_p1_check/before` and `after`.

| | Before (P0) | After (P1) |
|---|---|---|
| First U toggle from a cold boot, worst frame | 11.6 ms | **11.4 ms** |
| Pipeline compiles on the first toggle (surface / draw / specialization) | 0 / 0 / +3 | 0 / 0 / +7 |
| 20 toggles: worst frame, stall banner, clock pauses, compiles | 10.0 ms, 0, 0, 0 | 9.9 ms, 0, 0, 0 |
| U view: objects / primitives / draw calls / shadow draws | 25 / 28,266 / 18 / 0 | 26 / 29,540 / 19 / 0 |
| U view with three residents walking the bore | 24 / 58,047 / 21 | 25 / 59,321 / 22 |
| Frame time, U view (median; Metal holds 120 Hz with vsync off) | 8.36 ms | 8.33 ms |
| Frame time at 2× 3D supersampling (4× the pixels): U view / surface | 8.22 / 20.1 ms | 8.24 / 19.9 ms |
| Click error at floor level | < 0.001 m | < 0.001 m |

- **GPU.** Metal reports no GPU timestamps here, so it is compared by frame time and draw counts: one
  more draw call, 4% more primitives, and the U view still at the 120 Hz floor with four times the pixels
  (where the surface takes 20 ms). Inside the +1.5 ms budget. The specializations are background
  compiles (0205); no frame on the first toggle is over 11.4 ms.
- **CPU per frame** (the probe's micro-benchmarks): the stoop 22 µs a resident below (only while it is
  below), the lanterns' focus and flicker 5 µs, the earth's day 0.4 µs -- 0.03 ms with one resident
  below, 0.18 ms with all eight. Under the 0.2 ms budget. Digging adds a chunk sweep (≤ 0.1 ms) and a
  stamp and upload per 0.25 m.
- **Foot drift on the ramps** (`scratchpad/revamp_p1_agent/footprobe.gd`, headless at a fixed 60 fps, the
  rigged mouse keeper, squirrel gatherer and mole digger walking down the entrance ramp and up the exit
  ramp of the same tunnel). As in 0202's audit: the contact point is the lowest skinned vertex whose
  strongest bone is that side's Foot or ToeBase; a foot is planted while it moves at under half the
  walker's speed for at least 3 samples; drift is the furthest it strays from where it landed.

  | | planted share: ramp / level | contacts on ramps | drift per contact on ramps, mean (worst) | same foot on the level, worst |
  |---|---|---|---|---|
  | mouse, before | 0.02–0.20 / 0.82–0.84 | 2 | 0.9 cm (1.1) | 2.0 cm |
  | mouse, after | **0.81–0.82** / 0.83–0.84 | 41 | 0.5–1.6 cm (2.35) | 2.14 cm |
  | squirrel, before | 0.12–0.26 / 0.63–0.64 | 4 | 1.1 cm (1.5) | 1.2 cm |
  | squirrel, after | **0.62–0.63** / 0.62–0.64 | 56 | 0.3–0.8 cm (**1.59**) | 1.16 cm |
  | mole, before | 0.31–0.38 / 0.65 | 12 | 0.9 cm (1.3) | 1.05 cm |
  | mole, after | **0.65** / 0.64–0.65 | 61 | 0.7 cm (**1.24**) | 1.05 cm |

  Before, on the 1:1.2 ramp with an upright body at its flat pace, the feet almost never plant: they move
  with the body at 0.8× its speed, down through the slope -- the playtest's "slides". After, they plant as
  on the level, and a contact drifts 0.3–1.6 cm on average. The squirrel's and the mole's worst are under
  2 cm; the mouse keeper's right foot's worst is 2.17 cm down and 2.35 cm up the ramp against 2.14 cm on
  level ground -- the clip's own (0202 pinned at 2 cm), with at most 0.2 cm from the ramp's eased ends.
- The stoop, side on, is in `scratchpad/revamp_p1_check/stoop_sheet.png` (each creature upright and
  stooped on the same walk frame, with the crown and the 0.9 m clearance drawn): the mole unchanged, the
  mouse's head just under the clearance, the squirrel bent further, the otter hardest.
- **Correction to 0206's record.** 0206's probe meant to dig a 12.6 m tunnel from (−6.6, 19); that entrance
  is refused ("inside a building or obstacle"), so it dug the 5.6 m fallback from (−6.6, 12). 0206's
  numbers are for that scene. Both runs here dig the same 11 m tunnel.
- At engine shutdown only, some windowed runs print Godot's "BUG, indexing did not unpair geometries from
  light" a few times (P0 at 494ba1c did not). The cause is not established; the likely one is the
  shutdown order of the pooled lights and the geometry they lit. No run printed it during play.
- **Review.** An independent review of the first draft found one CRITICAL and four HIGH issues, all
  fixed:
  - the stoop allocated scratch every frame;
  - the fillet folded the inner floor and wall at right-angled corners (its tightest radius is
    r·cos(turn/2), not r);
  - the dressing followed a different centreline from the bore;
  - walkers, braces and lanterns stayed on the polyline, so at corners they stood in the drawn wall;
  - the lean was untested.

  Its MEDIUM items fixed:
  - the lantern pool allocated when choosing lights;
  - roots stood through the section plane on a ramp's first dressed step;
  - the widened crown was written twice;
  - the grain texture was generated twice.

  Its LOW items fixed: the face wall's UV order, a ring cap per build, the day-recording slack, the U
  view's focus plane, a pitch while digging and the knee's fallback axis. The brace cutaway still drops
  the prop's normal and roughness maps (noted in §5).
- **Mutation-tested**: every mutant of the new logic, one at a time, each file restored and hash-checked
  (`scratchpad/revamp_p1_agent/mutate.py`); 87 mutants, all killed. Three guards that no mutant
  could fail were redundant, and they were deleted rather than kept.

**Open:**
- The widened bore is drawn with a 1.1 m crown, so the badger, stooped as far as it goes, still stands
  through the section plane. P3/P4 own taller bores (a deeper level, or rooms).
- A corner too sharp for its legs is rounded only as far as the legs allow (45% of each), and its inner wall
  can still fold (see §1). While a widening is under way the standard bore's curve is kept, so the widened
  stretch can fold at a sharp corner until the tunnel's class changes. P2's curve rules own bend radii.
- The mouths' gateway is procedural; the surface shows no ramp cut into the ground (a strip over it).
  P7 swaps the `tunnel_arch` prop in.
- Rooms are still P0's slabs, lit now by the U view's environment. P3.
- The drying runs off the dig day; P5's face mesh, clods and seep visuals build on the hook.
- The crouch-walk clips (0204) are P7's; the procedural stoop leans a squirrel forward ~45° on a walk, more
  than a crouching gait would.

**For P2:**
- Bore meshes are built by `bore_view.gd build(slot, dug_m, widen_m)` over a route polyline; its ring
  lattice, chunks and `state_key` are per slot. Re-key them per segment. `BoreCurveScript.of(network,
  slot)` is the one drawn centreline everything underground stands on; give each segment one. The
  design's Catmull-Rom centreline can replace the fillets, and it must keep a radius of at least
  `bend_radius`.
- The cap's void field takes `stamp_disc(centre, half_width, cut, rise_m, crown_m)`; junction hubs can be
  stamped as discs of their own radius.
- `tunnel_rules.floor_y_m` / `floor_grade` / `portal_m` assume a ramp at each end of a slot; segments
  that are not mouths need a flat floor, and ramps become their own segment kind.
- The brain's slope pace (`slope_share`) and `pitch` read the tunnel it is in; keep them per leg.
- `tunnel_lanterns.gd set_spots(slot, ...)` is keyed by slot; key it by segment.

## Source

- The design and its §10 rulings; the playtest record; decisions 0196, 0202, 0204, 0205, 0206.
- The probes and logs in `scratchpad/revamp_p1_agent/` and the frames in `scratchpad/revamp_p1_check/`.
