# 0203 — The beaver joins the pipeline, and every creature can swim
Date: 2026-09-29 · Status: Accepted

Builds on [0202](0202-planted-feet-are-pinned-where-they-land.md), and is stacked on it. DEC-041
(`docs/setting_decisions.md`) put the beaver on the release roster, at a proposed 1434 u.

## Decision

### A. The beaver bridgewright

1. **Species tables.** The beaver is the sixth row of `SPECIES_KEY`, `SPECIES_HEIGHT_U` (1434) and
   `SPECIES_HEIGHT_MM` (1400) in `godot/assets/lookdev/lookdev_dimensions.gd`, and of
   `docs/planning/asset_dimensions_and_budgets.{md,json}`.
   - It is appended **last**, so the five DEC-039 rows keep their indices.
   - Its status is `PROPOSED_FOR_REVIEW_DEC_041`, not `APPROVED`. A test pins that.
   - **No landmark row was invented.** `proportion_comparison.gd` places only the species that have
     landmark permilles, which are read off authorized references. None has been read for a beaver, so the
     comparison scene stays at five. `species_count()` there now counts the landmark rows.
2. **`repair_meshy_rig.py` refuses an unknown species** by name, before anything is written. It used to
   crash with a bare `KeyError: 'beaver'` part-way through the library (0202's *Not done here*).
3. **The beaver's tail is chained**, with a new `"section": "flat"`. See *The tail* below.
4. **The chain was run on a staging copy** (APFS clone) of the whole creature library, then the new and
   changed outputs were copied back. No other creature's output changed (see *Evidence*).

### B. Water clips

5. **`tools/author_water_clips.py` authors the swims.** Meshy's action catalogue cannot be listed without
   spending, so these are authored, not generated. Every rigged creature gets:
   - `anim_swim`;
   - `anim_tread_water`;
   - for the two otters, `anim_dive`.

   Each clip is keys on a copy of the raw `rigged.glb`, in `<key>/authored/`. Meshy's mesh, skin,
   material and 0.01 Armature survive byte for byte, and only the animation is new. So the chain treats
   them exactly as it treats a Meshy clip. `repair_meshy_rig.py` repairs `authored/anim_*.glb` with
   Meshy's clips, and refuses a name that is both.
6. **The waterline is y = 0.** A water clip is authored against the water surface, not the ground. The
   game places a swimmer's root at the surface.
   - A **surface** clip (swim, tread-water) holds the `neck` joint at a share of the creature's height, with
     a small bob. The Head stays above the surface, the Hips below it.
   - A **submerged** clip (dive) holds `Spine01` at −0.42 of the height. The whole body stays under the
     surface.
7. **`ground_meshy_clips.py` gains `WATER_CLIPS`**, each with its medium. A water clip has no ground,
   so it is never lifted, seated, pinned or untwisted. It is checked against the waterline instead, and
   refused if it breaks its rule. Its travel, if any, is taken out as a carry walk's is (0195). Its stamp
   records the medium.
8. **The bake gives a water clip no ground, and pulls its tail back, not down.**
   - The spring's floor is 100 m down on every key. Its `ground_ok` is `null`: there is no ground to judge,
     which is neither a pass nor a failure. A dive's tail must stay under the surface (`water_ok`).
   - In water the spring's pull points **back** along the creature, at the asset's own strength, as the
     water streaming past a swimmer carries its tail (`tail_rig.gd`'s `set_water`).
     - Pulled down, as on land, the first bake hung the otters' tails straight under them, like keels, in
       every swim and dive.
     - With no pull, the tail followed the pitched hips, which point it back and 45° **up**. It stood
       0.1–0.4 m out of the water, and the otter boatwright's dive failed `water_ok`: its tail broke the
       surface, +0.126 m.

## The tail

**Measured, left on the Hips as Meshy bound it.** The paddle is 28 cm wide and 6–12 cm thick (mesh
units), and lies on the ground behind the feet. Meshy bound all of it to the Hips, none to a thigh. Riding
the Hips, its lowest point against the feet's, over every key of each clip:

| clip | lowest | highest |
|---|---:|---:|
| collect_object | −42.7 cm | −3.1 cm |
| chair_sit_idle | −35.6 cm | −16.8 cm |
| carry_heavy_object_walk | −14.7 cm | +2.7 cm |
| idle | −14.5 cm | −9.8 cm |
| carry_water_bucket_walk | −5.9 cm | **+61.5 cm** |

It sinks into the ground in 8 of 10 clips and flies up in the bucket walk. "No chain by design", as for
the moles and badgers, is right only for a tail that cannot be seen apart from the body. This one can, so
it is chained. A real paddle is stiff, so its spring is twice the otter's stiffness (8.0), drag 0.9, and
half the otter's gravity (1.0).

**The segmentation.** The chain starts at y 0.30, below the trouser seat, where the tail is clear of the
legs. Above that point the tail stays on the Hips, as the mouse's does above its hem. `"refit": false`:
on a paddle, the refit's second pass zigzags across the breadth (a 1.09 m polyline for a 0.47 m tail).
1114 vertices; 0.555 m drawn.

**Two things the chain tools assumed that the beaver breaks:**

- **A bind scale of 1.** The repair rescales the beaver ×1.1879 by its joints, not its vertices. The
  radii and clearances were measured in mesh units, and so came out 16% small. They are now in drawn
  metres: the rig's bind scale times the mesh measure. The scale is snapped to exactly 1 within 1e-6, so
  the six tails chained before are measured exactly as before. Their manifest rows are unchanged.
- **A round tail.** A round tail's clearance is its radius, whichever way it points. Measured that way,
  a paddle's clearance is its half-**width** (about 16 cm drawn against a 3–5 cm half-thickness), and the
  ground constraint would hold it a hand's breadth off the ground it lies on. So `"section": "flat"`
  measures a segment's thickness, not its width: its distance from the axis with the creature's
  left-right offset left out. (A first version measured only the depth below the axis at bind; that
  missed the thickness of the chain's steep upper segments once they swung level.)

**The first flat bake failed the ground check in 9 of 10 clips**, by up to 5.5 cm at idle. The joints
were exactly at their clearance, and the paddle's **edge** was in the ground. The spring had rolled it
32–56° about its own length, where the hips roll at most 9.5°. Godot's spring turns each bone the
shortest way onto its new direction, and down a curved chain those turns add up to a roll. On a round
tail it cannot be seen.

**`godot/scripts/presentation/tail_flat_roll.gd`** therefore runs after the spring and the ground
constraint, on a chain whose `tail_00` extras say `section: flat` (`rig_meshy_tail.py` writes it).

- It turns each tail bone about its own length, so its breadth is as level as a bone pointing that way
  allows.
- Each bone keeps the world direction the spring and constraint gave it, so no joint moves.
- Levelling it to the hips' roll instead still dug an edge 1.45 cm into the ground in the bucket walk.
  A paddle lying on the ground is level, so level it is.

`tail_rig.gd` adds it, and the bake runs it. The skeletal pool and the crowd therefore get the same
tail. Round tails get no such modifier and are unchanged.

## Why authored swims, and why like this

- **Not Meshy.** Its catalogue cannot be listed without spending, and Brendan ruled out paid generation.
- **Not a Blender round-trip.** Re-exporting through Blender re-encodes textures and resamples every
  channel; decision 0190 edits the glTF directly for that reason. The clips are written the same way.
- **As data, in character axes.** Each clip is a function of phase. It poses joints by a rotation in the
  rest pose's own axes: +X the creature's left, +Y up, +Z front. That rotation is applied in the parent's
  posed frame, as `B_p^T R B_p L0`, so the identity is the rest pose exactly. The same numbers pose every
  creature at its own bone lengths, mirrored left and right.

  The styles:

  | style | who | what it does |
  |---|---|---|
  | paddle | mice, squirrels, moles | Forepaws circle under the chin in turn; the hind legs kick |
  | paddle, heavier | badgers | The same, at 1.3 s with 15% larger strokes |
  | hindkick | beaver | Forepaws tucked to the chest, the webbed hind feet driving |
  | undulate | otters | Near level, a wave from chest to feet, the hind legs kicking together |
  | tread | everyone | Upright, arms sculling at the surface, legs cycling |
  | dive | otters | Level and streamlined, forepaws back, a wave through the body |

  Blender (headless) was used to **look** at them, not to author them.
- **In place, and no speed.** Every clip holds the hips over their rest x and z. The period is recorded on
  the Hips (`water.period_s`). A swimming speed is movement's to decide (MOVE-G01), and none is invented
  here.

## Consequences

- **A new clip that swims must be added to `WATER_CLIPS`**, or grounding will stand it on the ground. The
  skill's §6 says so, with a new-species checklist.
- **A new species** needs, in order:
  - a species-table row;
  - a measured tail decision;
  - a `SPECIES_CLIPS` row;
  - the chain;
  - a manifest diff showing that nothing else changed.
- **The game** must place a swimmer's root at the water surface. While the creature swims, it must call
  `TailRig.set_water(true, back)`, with `back` its world back direction, and set the live tail's floor to
  the bed or far below it.
- **The beaver's height is still a proposal.** A later change is a free re-scale: re-run the chain.

## Evidence

- **The chain ran author → repair → tail → ground → bake** on an APFS clone of the whole creature library.
  It ran twice, independently, with byte-identical results except for the clips changed between the two
  runs. The new files were then copied into `assets/library/creature/`: 147 new, and 36 later overwritten
  (the otters' swim and dive after their feet were pointed back; every water clip's bake after the tail's
  pull). Every file in all five manifests matches the library by SHA-256.
- **No other creature's output changed.** Against this branch's base, every existing manifest row is
  byte-identical:

  | manifest | rows before | rows after | changed | added |
  |---|---:|---:|---:|---:|
  | `repaired.json` | 110 | 145 | 0 | 35 |
  | `tailed.json` | 66 | 93 | 0 | 27 |
  | `grounded.json` | 100 | 134 | 0 | 34 |
  | `baked.json` | 60 | 86 | 0 | 26 |

  `authored.json` is new: 24 clips. The bake's verdicts are 0202's, plus the beaver's and the water clips':
  - 0 tails below the ground;
  - the one flick, otter fisher `collect_object` at 124.4°, which is pre-existing;
  - the run exits 1 for that flick, as it did before.
- **The beaver, from the files:**
  - Repaired height 1.1789 → **1.4004 m**, ×1.1879. The target is 1434/1024 = 1.40039 m.
  - The idle swung 81.3° and is untwisted.
  - Gaits: walk `gait.speed_m_s` 0.9919, run 3.1403.
  - 11 contacts pinned across 6 clips; worst planted slide 9.8 → 3.5 cm. The 3.5 cm is collect_object's two
    kneeling contacts, left and reported `"support"`, as the other creatures' kneels are.
  - Tail bake over all 10 land clips:
    - the tail no lower than 3.8 mm below the ground, feet and base;
    - the constraint within 0.02 mm;
    - largest one-frame step 41.8°, largest seam 8.3°.
- **Godot 4.7.2**, importing the library files in a throwaway project (viewer `verify_water.gd`):
  - Rest height, skinned here from Godot's pose: **beaver 1.4003 m**, feet at 0.0000; otter 1.4897, badger
    2.5464, mouse 0.9999.
  - Idle → walk → idle at 60 Hz, 0.3 s blends:
    - beaver: idle heading 0.00°, idle feet slide 0.6 mm, blends turning 3.2° and 6.7°;
    - otter fisher, the same measure: 0.00°, 0.5 mm, 4.1° and 7.0°. The turns are the walk's own stride.
  - All 24 water clips on all 11 rigged creatures, every frame at 60 Hz:
    - bone-length drift 0.00000 m;
    - each surface clip's neck within 5 cm of the waterline (a treading badger's 8 cm) and the hips below it;
    - the dives' highest point −0.126 m (boatwright) and −0.360 m (fisher).
- **Contact sheets**, rendered windowed in Godot (`shots_water.gd`), looked at:
  - `contact_sheets/beaver_lineup.png` shows the beaver's crown on the 1.40 m rule, between the mouse and
    the otter, with the paddle lying on the ground.
  - `contact_sheets/water_{otter_fisher,mouse_keeper,badger_quarryman,beaver_bridgewright}.png`: at four
    phases of each clip, the heads are clear of the waterline and the bodies under it; the otter's dive is
    wholly submerged, with the tail trailing.
  - They were also used to fix two defects. The otters' feet hung like keels, and are now pointed back
    (toe point 85° and 88°). Their tails hung straight down under the spring's land gravity, and are now
    pulled back.
- **Tool self-tests** (`python3 -B`):

  | tool | checks before | checks after |
  |---|---:|---:|
  | repair | 44 | 60 |
  | tail | 46 | 68 |
  | ground | 197 | 222 |
  | bake | 49 | 69 |
  | authoring (new) | — | 34 |

  All pass. The Godot suite (`tools/run_tests.sh`) passes: 5149 tests, 0 failures.
- **Mutants: 55 of 55 Python and 11 of 11 GDScript killed.** Each ran on a fresh copy of `tools/`, or
  in place with the file restored. Three survived the first round, and each got the test it lacked:
  - the chain's radii and clearances not converted to drawn metres inside `rig_creature`;
  - the flat section not passed to the clearance measure;
  - the anchor's share not multiplied by the creature's height, which a 1.0 m fixture cannot see.

## Not done here

- **The beaver is not in the gameplay species catalog** (`catalog_ids.json`, the residents' 16
  species) or the GDD's species references. DEC-041 lists those as follow-ups. They change catalog ids
  and save identities, and are not asset-pipeline work.
- **No beaver emblem.** ART-LOCK-001 delivered four medallions; like the badger, the beaver has none.
- **No buoyancy or flow model.** In water the tail is pulled straight back at the land gravity's
  strength, whether the creature swims or treads water. The spring's stiffness and drag are the land ones.
- **The swims are authored by eye**, from rendered sheets, not from reference footage. They read as
  swimming at game distance, but they are a first pass for Brendan to judge.
- **The live demo still plays the old files** (0202's note stands).
