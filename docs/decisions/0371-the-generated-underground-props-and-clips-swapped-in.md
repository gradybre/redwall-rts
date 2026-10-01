# 0371 — The generated underground props and clips swapped in, their defects fixed
Date: 2026-10-01 · Status: Accepted

Phase P7, the last, of the approved underground revamp ([`docs/design/underground_revamp.md`](../design/underground_revamp.md)
§7, §8 P7). It swaps in the seven props and nineteen clips bought under decision
[0204](0204-the-underground-pass-clips-and-props.md) and fixes the defects 0204 recorded, and it closes review F16 ("the
surface tunnel entrance reads as a dark strip over intact ground") and F17 ("underground walking relies on a deformed
normal walk"). **No Meshy credits were spent**: every fix is Blender (headless) or code. Everything here is presentation;
nothing writes into the simulation, and MOVE-G01–G05 stay open.

## Decision

### 1. The fixes are derived files, made from the library high-polys

`tools/make_demo_derived_props.py` (Blender half `tools/demo_derived_blender.py`) makes five fixed props from the
library's high-polys, which it only reads, into the demo's gitignored `godot/demo/assets/props/`, with provenance the way
the weir's structure was derived (decision 0301): a `.made.json` per key (the job, stamped with both Blender scripts'
SHA-256, and the source's SHA-256) and a manifest row (source, SHA-256, the edits, each part's path, bound and
triangles). It uses `demo_props_blender.py`'s own decimation and bake, so a fixed prop looks like its siblings, and it
refuses a key over the furniture ceiling (GAP-04: 2,000 triangles, 1,024 px), its parts together. `stage_demo_assets.py`
runs it with the props; without Blender the rows are left out and each piece draws its stand-in.

| Key | Defect (0204) | Fix |
|---|---|---|
| `burrow_door_open` | One solid piece; cannot open | Split by region: the round **leaf** (a disc of 0.448 units round its measured middle (0.016, -0.19)) from the **frame**; the leaf's back face brought forward 0.14 so it is a door's thickness, its edge closed by a rim band. 559 + 1,340 triangles. |
| `tunnel_arch_open` | A solid dark slab fills the doorway, front and back | The slab's two sheets dropped (faces darker than 0.08 inside the doorway's box: 4,571 faces). 1,899 triangles. |
| `hanging_stores_strung` | Faceted lumps at 1,150 | Made at the furniture budget and split into its **bar** (with the brackets, hooks and ropes) and **five strings**, so a cellar's strings can show one by one. 520 + 5 × 232–272. |
| `hand_lantern_lit` | Frame warped, candle mangled at 1,150 | Made at the furniture budget (1,900): the frame straight, the candle whole. Its pale horn panes and candle are moved to a second material, `glow` (80 faces), which the demo lights from within. |
| `large_bed` | The large bed (0211) was the bed stretched | The bed's high-poly lengthened 1.31 units by cutting at its middle and filling the gap with a copy of the middle slab: the quilt repeats, the head- and footboards are untouched. Widened by a plain scale in the demo (a lengthwise cut showed as a seam the quilt's length). |

The seven plain L0s are registered too (`make_demo_props.py UNDERGROUND_PROPS`, in the families 0204 gave them), so the
manifest carries all of them. **The root bin is used plain**: it is modelled full of roots, and two tries to separate
them (the roots as a part; the roots cut out) both shattered its slats at the budget. It shows full whatever the cellar
holds; the cellar's fill shows on its other slots.

**Parts** (`demo/props/demo_props.gd`): a row with `parts` is staged only when every part's file is; each part is drawn by
the whole model's scale and recentring (`base_fit`), so placing every part with one transform puts the model back
together, and `drawn_bound` is the whole's. `fitted(key, part)` bakes that fit into one mesh for the kits.

### 2. The mouth: an open cutting, the ground cut away, the arch at the portal (F16)

0207 drew the mouth as a procedural gateway over a dark strip laid on the turf, and rejected cutting the ground in its
shader (a discard on the whole ground, every frame). This cuts the ground's **geometry**, and only when a hole changes
(`demo/world/ground_cut.gd`): every ground triangle overlapping a hole is dropped from the ground's index array, and what
of those triangles lies outside every hole is drawn again as a **collar** — each triangle minus each convex hole,
decomposed by the hole's edges into convex pieces (so none has a hole), fanned on the triangle's own plane in the
ground's own material, which reads world x, z, so the collar is the same grass. Kept ground plus collar is exactly the
ground less the holes (tested). Triangles are found through a 4 m bucket grid built when the ground is given (at the world's build: reading the
58k-triangle ground takes tens of ms, so not on the frame a mouth first opens); a mesh someone else replaces (the water's
carving) is read again as uncut. A hole cuts only the triangles its bound touches, so a distant hole's edge lines split
nothing, and a clip line through a corner emits no zero-area piece.

`demo/tunnel/tunnel_mouth.gd` builds the **cutting**: its floor is the ramp's floor (`ramp_depth_m`, the floor the brain
stands residents on), between hand-dug earth walls (bulging ±3.5 cm, the earth's tone varying ±12% repeatably) up to the
ground, CUT_MARGIN_M (5 cm) beyond the bore's floor, its middle worn paler, low banks along its tops. It runs to the
**portal** (where the bore's crown goes under the turf: 2.94 m for the standard bore), opening over its last 0.75 m into
a **forecourt** as wide as the arch's piers. There the staged **arch** stands facing up the ramp, scaled so its doorway is
the cutting's width and **sunk so its doorway's top is the bore's crown at the portal** — the ground — so the doorway
frames the bore exactly and only the lintel and its earth stand over the turf. The library wall lantern hangs on the
lintel's face (its front measured off the mesh: the piers flare further forward at their feet), a small glow in its
cage. Beyond the portal the bore goes on 1.5 m as a dark throat. While the entrance shaft is dug the cutting opens in
eighths, ending at its earth face. A burrow home's door ramp is a cutting down to its door; a cellar's hatch covers its
ramp, so it has none.

A resident walking a cutting is drawn on the surface layer too (`demo_actor.gd` IN A CUTTING;
`tunnel_mouth.gd in_open_cutting`), so the surface view sees it go down and under the arch instead of vanishing at the
mouth. Nobody is sent to **stand** over a cutting or its forecourt, through to the arch's back (`cast_space.gd on_mouth`), and
no spoil heap is laid on one or its banks (`tunnel_heaps.gd`): both ask `tunnel_mouth.gd cutting_gap`, the distance to the
cutting's rectangle and its forecourt's, the forecourt as wide as the mouths draw it (`cast_space.gd set_props`: the
staged arch's piers). Walks may still cross one, as they cross a hole's rim (planning round every mouth costs five times
a plan, cast_space.gd). `cutting_run_m` takes each bore's portal from a per-class cache (`portal_of`): it runs every
frame for every resident on a ramp, and `Rules.portal_m` is a 30-step bisection (10.7 µs a call).

**Rejected**: the arch at the top of the ramp, on the turf (its doorway is 1.68 m tall at the bore's width, so it would
stand 2.3 m over the ground for a 1 m bore, a different height from the bore it fronts); a stencil-masked ground (Forward+
depth prepass ordering not established, and not testable headless); a finer ground grid over the village (the water's
mesh, shared).

### 3. The burrow door swings

`room_view.gd` stands the staged door at the foot of the home's cutting, on its level's floor, facing out, its leaf
hung from a hinge at its left edge (seen from the cutting; the iron straps' end). `burrow/door_swing.gd` swings it open
(1.45 rad, inward, away from the cutting, in 0.45 s of demo time) while a resident **below** stands within 1.6 m of the
door, and shut once nobody is; paused, it holds. The stand-in door swings the same.

### 4. The crouch walk (F17)

`demo_actor.gd` plays the staged crouch walk (Meshy 524 `Cautious_Crouch_Walk_Forward`) **in place of the walk** where
the bore makes the resident stoop (`stoop_target_m` ≥ 5 cm): mice, squirrels, otters, the beaver and the badger; a mole,
upright in every bore, walks. A carrier keeps its carry walk. The clip's rate is the walk's ground speed — walk speed
times the brain's clip speed over its `gait_rate()` (the walk's stride_rate) — over the **speed the crouch's planted feet
move at**, the grounding step's own measure (decision 0202), which `stage_demo_assets.py crouch_row` stages, measured off the clip as staged (re-pinned, below). It is not always
the root motion's: the mouse keeper's feet move at 0.742 m/s (0.760 before the re-pin) while its hips travelled 0.878
(the clip slid 6.7 cm when played at the root's). The procedural stoop (0207) adds only what the crouch's own lowered head (`head_drop_m`, the
median Head height under the walk's) leaves to clear, and still leans into ramps. The brain is unchanged: the actor chooses
the clip (`choose_clip`, `crouch_rate`).

**The mouse keeper's slide.** 0204's grounding left two of its contacts unpinned as "support" (8.8 cm). Pinning the
grounded clip again with the support tolerance at 2 cm pins both (`stage_demo_assets.py REPIN`); the staged copy is the
pinned one and the cast row says so (`repinned`). The library's grounded clip is untouched.

### 5. The dig swings once per strike

Meshy 128 `Heavy_Hammer_Swing` ends turned 68–81°, so it is never looped (`LOOP_NONE`). `demo/cast/strike_clock.gd`: a
digger owes one swing as it reaches the face and one more for every quantum cut (`cut_count`); once the time between cuts
is known, a swing starts so its blow — `impact_s` into the clip, staged by `dig_row` as the moment the hands come lowest
after their highest, 1.73 of 1.87 s — lands as the next cut falls, the face's clods bursting with it. Between swings the
digger stands at least 0.35 s, blended back out of the swing over 0.4 s, so the turn eases out. A dig quicker than a swing
gets its swings back to back, never more than one a cut. A cut count that goes **down** is a new face (at 4x a digger
can finish one face and begin the next inside a frame, with no step off the face to reset on), owed its first swing. The mole digger and the badger quarryman have the clip (the mole
mason is not in the cast); others dig as before.

### 6. The rest of the swap

- **The hand lantern** (`warren_kit.gd`): the lit library lantern, 0.3 m with its handle, set down at the face as P5's.
- **The basket**: the library basket, 0.38 m to its handle's top, the spoil heaped at its rim.
- **The fit-out** (`fixture_kit.gd`): the hanging stores hung by their wall brackets from the room's ring beam
  (`fixture_view.gd hang_back_m`: back along the place's facing to the beam's inner face; their top at the beam), a
  cellar's five strings showing one by one; the library root bin (no slot), rag rug (a mesh, over the decal) and chimney
  pot (its smoke from its drawn top); the large bed.
- **The stairs** (`stair_view.gd`): each step a packed-earth block under a timber tread board whose nosing overhangs a
  timber riser, in a procedural grain texture (planks, wavy grain, dark seams), the grain across the stair. Procedural:
  the library's timber props are baked atlases, not tileable wood.
- **What the kits derive from a staged model** (the lit lantern, the sized and the loaded basket, the arch's lintel
  depth) is kept on the props table (`demo_props.gd derived`/`keep`), not in a script static: a restart builds a new
  table, and the old one's meshes go with it.
- **The prewarm**: every new mesh and material registers (`fixture_kit.gd register`, `warren_kit.gd register`), and the
  ground prewarm samples the cutting, the arch and its lantern, the glow and the door's parts.

## Measured

On the Apple M5 Pro (Metal, 1920×1080), the P6 probe's scene (the playtest tunnel, a home and a cellar, the stairs and the
level-2 home, all fitted), shader and pipeline caches moved aside for the cold runs. **Before** is 6b6e2ca (feat/live-demo
plus P6) in a detached worktree with the same staged assets; **after** is this branch. The machine carried other agents'
test runs (load 6–7) throughout.

| | Before | After |
|---|---:|---:|
| First cold U toggle, worst frame (compiles: surface/draw/specialisation) | 8.6 ms (0/0/+6) | 9.1 ms (0/0/+6) |
| 20 U toggles, worst frame (5 runs each; stall banners, compiles) | 10.2, 15.7, 10.2 ms (3 runs) | 15.8, 16.4, 11.8, 10.2, 10.3 ms; 0 banners, 0 compiles |
| 20 toggles, median of the per-toggle worsts | 9.4 ms | 9.4–9.7 ms |
| Surface at 17 m: objects / primitives / draws; median frame | 89 / 1,128,683 / 75; 9.0 ms | 90 / 1,134,157 / 73; 9.2 ms |
| A mouth at 8 m: objects / primitives / draws | 33 / 929,196 / 28 | 37 / 935,365 / 30 |
| U view level 1: objects / primitives / draws; median frame | 103 / 43,632 / 45; 8.33 ms | 70 / 46,791 / 47; 8.34 ms |
| U view level 2: objects / primitives / draws | 57 / 27,394 / 30 | 45 / 28,510 / 34 |

The occasional 15–16 ms toggle appears in both trees under the machine's load (before's second run has two); the cold
toggle stays under the 50 ms limit. Frame time holds P1's budgets: the U view at the 120 Hz floor, the surface +0.2 ms.
CPU a frame (1,000 calls): the overlay's refresh with its ground cut 71 µs (70.9 before: the cut does nothing unless a
hole changed), the door swings 0.8 µs, every resident's clip choice 4.8 µs. After the review's fixes, both trees run
back to back while another agent's windowed probe shared the GPU: surface median 17.0 ms after, 16.9 before; U level 1
8.6 / 8.6 ms; 20 toggles worst 25.5 and 26.7 after, 25.8 before; 0 banners, 0 compiles in each. Same counts as above
(the surface 87 / 1,133,399 / 70 after the ground cut's slivers went). Parity, measured under load; the quiet numbers
above stand.

**Foot drift** (P6's foot probe, fixed 60 fps; a contact's drift is the furthest a planted foot strays from where it
landed):

| | Before (walk + stoop): worst / mean cm | After (crouch): worst / mean cm |
|---|---|---|
| Mouse keeper, level bore | 2.14 / 1.6 | 2.9 / 1.0 (6.5 / 2.5 before the feet-speed rate and the re-pin) |
| Mouse keeper, ramp / stairs | 2.2 / 1.6; 2.1 / 1.3 | 3.5 / 1.1; 2.9 / 0.7 |
| Squirrel gatherer, level bore / ramp / stairs | 1.2 / 0.4; 1.5 / 0.7; 0.7 / 0.5 | 1.8 / 0.6; 3.9 / 0.8; 1.9 / 0.6 |
| Mole digger (walks, unchanged) | 1.05 / 0.7 | 1.05 / 0.7 |

After the review's fixes (the crouch measured off the re-pinned clip). The crouch drifts a centimetre or so more than the
pinned walk at worst; its stance is shorter and lower.

**Strikes**: over 20 s at a face, 3 swings for 3 cuts, the cuts 3.14 s apart; the blow lands within two frames of its cut
(tested). **Sleep**: the mattress seating holds with the clips staged: the badger's lowest point -0.767 + 0.033 on the
large bed's -0.80 mattress, the mouse keeper's -0.737 + 0.063.

Frames in `scratchpad/revamp_p7_check/` (`before/` and `after/`, `look/`, `bed/`, `crouch/`; `crouch_sheet.png`,
`pair_surface.png`, `pair_door_dig.png`).

## Tested

`./tools/run_tests.sh`: `ok: 6602 tests, 555786 assertions, 0 failures.`, the same with the staged manifest moved aside (no staged assets). `godot/test/test_demo_p7_assets.gd` is new (34 tests, without staged assets: a
"staged" prop is a tiny scene saved under `user://`): prop registration and parts, the shared fit and `fitted`, the lit
lantern and the basket, the hanging stores' parts, hang and beam, the root bin, rug, chimney and large bed, the door's
swing and its hinge in a dug home, the cutting's floor, throat, face and forecourt, the ground cut's conservation (a hole
across triangles and one inside one), the arch's sink and the cutting's holes, the open cutting and who stands over it,
the surface layer in a cutting, the stairs' nosing and riser, the clip choice and crouch rate, a mouse crouching and a
mole not, the strike clock (one a cut, the blow on the cut, rest, pause, reset) and the prewarm's coverage. Two existing
tests changed: a resident below now stands past its ramp's cutting (test_demo_tunnel.gd), the prop count is 60
(tools/test_make_demo_props.py). `tools/test_make_demo_derived_props.py` is new (48 checks); `test_make_demo_props.py` 72
checks (the crouch and dig measures, synthetic clips); the grounding tool's tests unchanged and passing. The live harness
passes at 1280×720 (116 checks) and 1920×1080 (121).

**Mutation-tested** (one mutant at a time against the P7, tunnel and cast suites, the file's hash checked after each):
the first set of 108 mutants of the new GDScript killed 75. Of the 33 survivors, 26 got tests that kill them (the second
and third runs: 26/26), four marked code that did nothing and was removed (an underground guard the caller already
made, a check the hole's emptiness already made, a stand-off constant, and the collar's winding flip: a clipped piece
keeps its triangle's winding), and three are equivalent (a sliver filter whose slivers are harmless, a guard against an
engine error, an axis only ever zero in the templates): **101 of 108 killed, none surviving that is not equivalent**.
The review's fixes got 17 more (all killed once their tests were in: 11, then 6/6). The Python tools: 18 mutants, 18
killed.

## Review

An independent `code-reviewer` read the whole diff and probed it in its own clones. It found two CRITICAL and four HIGH
issues, all fixed here:

- **CRITICAL** — the snapshot it was given had `tunnel_mouth.gd`'s two return lines swapped mid-edit (it did not compile);
  the committed file compiles, and the whole suite runs it.
- **CRITICAL** — the lit lantern, the sized and loaded basket and the lintel depth were cached in script statics keyed by
  the props table's meshes, so every restart leaked them (~400 KB). They are kept on the props table now (§6), tested.
- **HIGH** — standers and heaps were kept off the cutting's width only, not its wider forecourt, and heaps only to the
  portal on a home's door ramp: both use `cutting_gap` now (§2), tested.
- **HIGH** — the strike clock never re-armed when a new face began inside one frame: a count going down is a new face
  now (§5), tested.
- **HIGH** — `Rules.portal_m` (a bisection) ran every frame for every ramp walker: cached per bore class (§2).
- **HIGH** — five mutation survivors (the ground cut disconnected, a moved hole, the strike's debt, the crouch rate's
  walk-speed term, the stand-in hinge) had no killing test; they have (above).

Of its MEDIUM findings: the ground is read at the world's build (§2); the door swing gathers the residents below once a
step (doors × residents below, none on the surface); the crouch speed is measured off the re-pinned clip (0.742 m/s, was
0.760, restaged); the clip emits no duplicate corner and a hole leaves triangles off its bound alone. The cutting cache's
growth is left open (below). Of the LOW: the dead winding flip is removed, the collar follows a new ground, a door staged
without its leaf falls back to the stand-in, the hinge test uses one frame, the Blender job has a 900 s timeout and
always removes its job file, `dig_row` reads its clip once.

## Open

- Walks still cross an open cutting on the surface (only standing is kept off it).
- The root bin shows full whatever the cellar holds (above).
- The crouch's planted feet drift 2–3.9 cm at worst, a centimetre or so more than the pinned walk.
- A door opens for a resident below within reach on any level (a level-2 resident under a level-1 home opens it).
- The crouch has no hysteresis at its 5 cm stoop threshold (a bore whose stoop hovers there could flicker the clip).
- `tunnel_mouth.gd` keeps its built cuttings in a static cache keyed by bore, length (mm), end and forecourt: bounded by
  the ramps a session digs times eight opening steps, never freed.
- Within a triangle two holes both touch, one hole's edge lines can still split the other's collar pieces (a T-junction,
  no gap: the kept ground is unchanged and area is conserved).
- The mouth's cutting walls are vertex-coloured earth, not the U view's triplanar earth shader; the home's old earth
  face still stands over its door frame.
- The badger did not get a large bed in the P6 scene's night (the allocation found none for it there); the bed frames are
  from P5's scene, where it does.
- The mole mason has the dig clip but is not in the demo's cast.

## Source

Decision 0204 and the asset library README's "Underground revamp pass"; the design's §7 and §8 P7; decisions 0207, 0210,
0211, 0212 and 0301; review F16 and F17 (`redwall-review/REVIEW.md`). The probes and logs in `scratchpad/revamp_p7_agent/`.
