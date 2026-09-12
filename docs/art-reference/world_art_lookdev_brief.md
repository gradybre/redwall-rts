# World-art look-development brief

Document `SET-ART-LOOKDEV-001`, revision 1.1, 2026-09-11.
Status: **preparation only — no asset is authored, generated or paid for by this document.**

> **Revision 1.1 — the 2026-09-11 ruling is bound into this brief.**
> [The asset/save/movement ruling](../rulings/2026-09-11_asset_save_movement_blockers.md) and
> [asset dimensions and budgets](../planning/asset_dimensions_and_budgets.md) (ART-GAP-R01–05)
> supply the numbers revision 1.0 refused to invent. **Six of the nine blocked entries now
> have authoring answers. Three creature entries — A2 mole, A3 squirrel, A4 otter — have
> concrete comparison briefs and still need proportion approval. They are not
> production-ready, and neither are the other six in the sense of qualification: an
> authoring contract is not exported evidence or a measured frame time.**
>
> The numbers are bound for the engine in
> [`godot/assets/lookdev/lookdev_dimensions.gd`](../../godot/assets/lookdev/lookdev_dimensions.gd),
> the GAP-06 hierarchy check in
> [`asset_import_validator.gd`](../../godot/assets/lookdev/asset_import_validator.gd), and the
> review scene decision 0002 requires in
> [`proportion_comparison.gd`](../../godot/assets/lookdev/proportion_comparison.gd) with its
> captures under `godot/assets/lookdev/captures/`. Recorded as
> [decision 0082](../decisions/0082-lookdev-dimensions-are-bound-and-the-comparison-scene-is-built.md).
> **Every creature height below remains a comparison candidate until Brendan approves the
> comparison scene. Bulk creature generation does not start before that.**

This is the brief that [the consolidated handoff](claude_visual_handoff.md) §6 asks for:
"a concrete look-development brief using the approved image plus named original
references: representative residents, a dwelling/workspace, ground/vegetation and
practical props. Define the actual production/validation steps and any dependency
gaps before generating families."

## 0. What this document is and is not

| It is | It is not |
|---|---|
| A per-asset specification for four families, with sources, inventions, geometry and review views named separately | An asset, a mesh, a render, a texture or a rig |
| A production and validation order that follows [crowd §9.2](../crowd_rendering_architecture.md) | Authorization to spend credits. §9 is a **proposal** for Brendan |
| An honest register of what must be settled before each family can start | A place where a missing dimension gets an invented value |

Four families, **18 asset entries**: 5 residents (including the paired hand tool
required by the bake validation), 3 dwelling/workspace, 4 ground/vegetation,
6 practical props.

Revision 1.0's introduction said "six of the eighteen are blocked" while its own §8 and §10
marked **nine**: A2, A3, A4, B1, B2, B3, C3, D3 and D5. The ruling names that discrepancy
explicitly; nine is the number, and the introductory six was wrong. As of revision 1.1:

| | Entries | Position after the ruling |
|---|---|---|
| Authoring-ready | A1, A5, B1, B2, B3, C1, C2, C3, C4, D1, D2, D3, D4, D5, D6 | Every dimension, budget, cutaway, material and naming contract these need now exists |
| Comparison brief only | A2 mole, A3 squirrel, A4 otter | Exact candidate heights and a measurement convention exist; **bulk-production proportion approval is open** and decision 0002's review has not happened |

**Authoring-ready is not production-qualified.** Exported meshes, rendered evidence, the
camera obstacle sweep, GPU measurement and the Windows minimum-hardware pass all remain
open, and GAP-10 is untouched by this ruling.

### What DEC-038 approved, and what it did not

Brendan viewed [the mouse keeper / mole worker courtyard](visuals/grounded_expressive_rts_example_v1.png)
and answered **"Yes - this is what I'm looking for"**
([`docs/setting_decisions.md`](../setting_decisions.md) DEC-038).

That image is a **generated 2D concept**. Restating the limits recorded in its own
[provenance manifest](visuals/grounded_expressive_rts_example_v1.json) and in DEC-038,
because they govern every use of it below. It is **not**:

- a production mesh, or evidence that any mesh exists;
- a Godot render or any engine screenshot;
- a calibrated camera test — its right panel is stated in
  [the prompt](visuals/grounded_expressive_rts_example_v1.prompt.txt) as "about 50 degrees
  down", which happens to sit near the shipped 48° initial pitch, but the prompt is a
  request to an image generator, not a measurement;
- a species-size specification — "Exact relative species size ... remain production
  authoring details";
- approval of incidental generated content. The chicken is not fauna. The cottage
  proportions are not a building spec.

Its close view governs character and material intent; its elevated view governs RTS
scene composition. Fine fur and texture noise in the close view **exceed** the intended
runtime simplification and are explicitly listed as a limit in the manifest.

### The world treatment and the UI treatment are different

[ART-LOCK-001](../design/ui_refinement/asset_generation_lock.md) fixes twelve
illustration pigments (I01–I12), permanent ink contours and a fixed light angle.
Its own scope line says the lock "governs UI illustrations". Per
[visual alignment](visual_direction_alignment.md), those pigments, contours,
light angle, 24 px silhouettes and medallion framing **do not become global
world-rendering rules**. Nothing in this brief samples, references or reuses them.
The world follows the approved dimensional example; the two must feel coherent, not
identical. No watercolor shader, no black outline pass, no fixed upper-left sun,
no twelve-colour index on a 3D model.

## 1. Reference inputs actually opened for this brief

Provenance is recorded as found. Creator, presentation URL and illustration edition
are **unknown** for all `ImageReference/` files and remain unknown — they are not
asserted to be Brendan's copyright, and they are not asserted to be CC-licensed.
Direct use is authorized by project decision **DEC-036**, which is an internal
project authorization, not a licence determination.

| Input | Region opened | What was taken |
|---|---|---|
| `docs/art-reference/visuals/grounded_expressive_rts_example_v1.png` (DEC-038) | both panels, full | Character/material intent; RTS composition intent; value grouping |
| IMG-25 `Screenshot 2026-09-06 at 2.26.38 PM.png` ([review](screenshot_review.md#img-25)) | `IMG-25/woodland_lineup`, pixels `[413,247,1304,565)` of 1366×1026; `IMG-25/count_labels` `[19,205,403,849)` | Comparative mouse / mole / squirrel / otter silhouettes; ear, muzzle, tail and shoulder contrasts. **Labels read, categories not adopted as heights** |
| IMG-08 `Screenshot 2026-09-06 at 2.21.25 PM.png` ([review](screenshot_review.md#img-08)) | `IMG-08/mole_body` `[12,415,744,1066)`; `IMG-08/pick` `[544,399,754,1060)` | Mole compact mass, projecting snout, broad clawed digging hands, two-handed tool grip and weight |
| IMG-04 `Screenshot 2026-09-06 at 2.19.57 PM.png` ([review](screenshot_review.md#img-04)) | `IMG-04/hearth_household` `[693,534,1383,997)`; `IMG-04/kitchen_group` `[55,570,659,995)`; `IMG-04/ladder_pair` `[1167,118,1364,759)` | Working aprons, caps, sleeves, mixing bowls, low worktables, inhabited warmth; squirrel on a ladder |
| IMG-12 `Screenshot 2026-09-06 at 2.23.01 PM.png` ([review](screenshot_review.md#img-12)) | `IMG-12/mouse_guardian` `[1019,383,1432,956)` | Mouse round ears with a visible inner plane, projecting muzzle, pale muzzle/brow markings, green outer garment over a belt |
| IMG-07 `Screenshot 2026-09-06 at 2.20.59 PM.png` ([review](screenshot_review.md#img-07)) | `IMG-07/squirrel_group` `[775,4,1408,976)` | Squirrel plume tail volume and root, ear tufts, cheek fur masses, short sleeved working shirt |
| IMG-18 `Screenshot 2026-09-06 at 2.24.31 PM.png` ([review](screenshot_review.md#img-18)) | `IMG-18/otter_body` `[771,157,1284,932)` | Full standing otter: long torso, pale throat and chest, small rounded ears, broad muzzle, thick tapering tail, broad hind feet with separated toes, plain belt and trousers |
| IMG-03 `Screenshot 2026-09-06 at 2.19.34 PM.png` ([review](screenshot_review.md#img-03)) | `IMG-03/kitchen_group` `[35,614,646,1047)` | Communal cooking props: cauldron, ladle, bowls, stored produce |
| IMG-17 `Screenshot 2026-09-06 at 2.24.20 PM.png` ([review](screenshot_review.md#img-17)) | `IMG-17/raft_group` `[661,309,1390,947)` | Lashed timber, rope construction and wet-surface treatment |

Region rectangles are copied from [`reference_manifest.json`](reference_manifest.json)
(`bounds_pixels_half_open`, top-left origin, half-open). The manifest defines them as
"authored selection guides, not segmentation or anatomical measurements."

### Library records consulted

Retrieved individually with `query_library.py`, not by loading the library:

| Record | Fact used (NARRATOR evidence) |
|---|---|
| `redwall::RW-OBJECT-food-vessels-and-wrappers` | Acorn cups, tankards, canteens, bowls, earthenware jugs, mugs, rush baskets, dock-leaf wraps, cloths, wooden ladle |
| `redwall::RW-OBJECT-wicker-repair-baskets` | Grain baskets reused for material delivery and haul work |
| `triss::TRI_object_strawberry_trug` | Harvest basket connects orchard picking to kitchen work |
| `outcast::OUT_object_farm_tool_set` | Spades, hoes, rakes and trowels share a forge with arms |
| `martin_warrior::MW_PLACE_noonvale` | Thatched cottages, gardens/orchards, stream, peaceful community |
| `taggerung::TAG_place_nimbalo_s_family_farm` | Cultivated flatland beside a thatched single-window cottage with a hearth |
| `taggerung::TAG_ecology_woodland_seasonal_texture` | Dogrose, vetchling, red clover, orchards and garden rows make inhabited woodland rather than empty wilderness |
| `outcast::OUT_ecology_autumn_orchard` | Russet apples, golden pears, dew berries, browning elm, low-bough harvest |

These are source atmosphere and material culture. They carry `NOT_RUNTIME_ACTIVE`
and grant no catalog entry, recipe or quantity.

### RTS comparison applied

One transferable principle per [visual alignment](visual_direction_alignment.md)'s
research table, applied rather than name-dropped: **validate at the game camera
before accepting the beauty render**. The only primary-source camera lesson recorded
in the repository is the Age of Empires IV team describing the balance between
battlefield overview and selection readability when adding zoom options
([update 17718](https://www.ageofempires.com/news/age-of-empires-iv-update-17718/),
consulted 2026-09-11). Every acceptance view in §3–§6 is therefore anchored to the
real camera contract in §2.2, not to a close-up. The broader world-art comparison
against Company of Heroes, Northgard and Total War is **proposed research, not
completed work**, and is not treated here as a finding.

## 2. Shared production contract

### 2.1 Geometry, axes and naming — inherited, not restated loosely

All from [crowd §9.1](../crowd_rendering_architecture.md) and
[the asset-pipeline skill](../../.claude/skills/asset-pipeline/SKILL.md). These are
project conventions that **deliberately differ** from the usual Godot/glTF defaults.

| Field | Required value | Source |
|---|---|---|
| Blender units | Metric, unit scale 1.0, 1 unit = 1 m | crowd §9.1 |
| Simulation convention | Godot **+Y up, −Z forward, +X right** | crowd §9.1 |
| Authoring convention | Blender **+Z up, +Y forward, +X right** | crowd §9.1 |
| Axis conversion | `(x_g, y_g, z_g) = (x_b, z_b, −y_b)`, applied **exactly once** | crowd §9.1 |
| Meshy import correction | Meshy writes GLB **Z-up**, violating glTF's Y-up mandate; Blender then applies its standard Y-up→Z-up rotation anyway, so the model arrives **on its back**. The +90° X correction in `prep_unit.py` is not optional and affects every Meshy model | skill, "Gotchas" |
| Origin / pivot | Ground-contact centre **between the feet**; ground-projected body centre for non-bipeds | crowd §9.1 |
| `origin_at: "bottom"` | **Silently ignored** by the API unless `auto_size: true` is also set. Fix the pivot in Blender; never rely on the parameter | skill, "Gotchas" |
| Transforms | Applied rotation/scale, scale exactly `(1,1,1)`, no negative determinant | crowd §9.1 |
| Topology | **Triangulated before bake**; UV seams and hard normals finalised | crowd §9.1 |
| Prototype mouse height | **1.0 m gameplay scale — "fantasy relative scale, not biological meters"** | crowd §9.1 |
| Rig | ≤64 bones **including sockets**; `socket_main`, `socket_off`, `socket_head` count against the budget | crowd §9.1, §9.2 step 2 |
| Naming (creatures) | `species_mouse_body_a_lod1`, `rig_mouse_v1`, `clip_attack_a`, `socket_main` | crowd §9.1 |
| Naming (buildings, props, vegetation) | `building_<BuildingDefinition_key>_<variant>_lod<n>`, `furniture_<FurnitureDefinition_key>_<variant>_lod<n>`, `prop_<semantic_key>_<variant>_lod<n>`, `flora_<semantic_key>_<state>_lod<n>`, `crop_<CropDefinition_key>_<state>_lod<n>`, `terrain_<soil_key>_<variant>`. ASCII; `n` = 0/1/2 static tiers; variants begin a, b, c | GAP-08, ruling ART-GAP-R04 |
| Naming: what a name may NOT do | An art semantic key is **not** a new gameplay catalog entry, and a live catalog key is **never** renamed to suit a filename. Manifests declare any real catalog binding separately | GAP-08 |

**Facing cannot be automated.** glTF conventionally treats +Z as model front; this
project uses −Z forward. Apply the conversion once, validate against a "face north"
fixture, and use `use_model_front=false` on presentation roots so `look_at()` does not
add a second 180°. A model that is upright, correctly scaled and **facing backwards
passes every automated check** in `prep_unit.py`. Every asset below therefore carries
a **human facing check** in its acceptance views. Flag it for a human eye; do not sign
it off from a script exit code.

`prep_unit.py` verifies exactly three things — target height, `min_z == 0`, and
`dims.z >= dims.y` — and it **joins all imported objects into one mesh**. It does not
triangulate, does not check facing, does not check determinant, does not preserve
material slots and does not preserve a multi-part hierarchy. Anything that must stay
in separately addressable parts (§4's roof and walls) cannot be normalised by it
unmodified. Recorded here because the skill's one-command step reads as if it is
sufficient for every asset; it is sufficient for a single-object creature.

GAP-06 settles the consequence: **multi-part buildings bypass the join step**, and the
hierarchy-preserving import validator it asks for is
[`godot/assets/lookdev/asset_import_validator.gd`](../../godot/assets/lookdev/asset_import_validator.gd).
It refuses a managed building that arrives as one joined mesh — naming the tool that did
it — requires GAP-06's ten addressable parts, checks each wall part against the inherited
1 m cut line, and checks measured bounds against GAP-03's envelope and GAP-04's ceilings.
It reports and never repairs. **Creature-normalisation scripts are not universal asset
processors**, and nothing in this brief runs a building through one.

It also carries a **named blocker rather than an invention**: GAP-06 requires "opening/cap
geometry" as an addressable part but does not name it, so the validator accepts extra parts
and records each as a note. Close the cap-naming contract before a reviewer reads those
notes as approval.

### 2.2 The camera, and what it means for every acceptance render

Fully specified in [`docs/ui_ux_controls.md` §6](../ui_ux_controls.md):

| Field | Value |
|---|---|
| Projection | Perspective, vertical FOV **55°**, `KEEP_HEIGHT` |
| Initial orbit | Yaw 45°, pitch **48°** below horizon, distance **40 m**, target central hall |
| Zoom | Orbit distance **8–120 m** |
| Pitch | **35–65°**, 1°/step |
| Ground following | Camera origin ≥ terrain height + 1.5 m |

Applying the crowd document's own LOD formula, `pixels ≈ h·H / (2·z·tan(f/2))`, at
1920×1080 (`H = 1080`, `f = 55°`, `tan 27.5° = 0.520567`) gives `pixels ≈ 1037.3·h/z`.
For a **1.0 m** resident across the legal zoom range:

| Orbit distance | Projected pixels | Crowd LOD tier |
|---|---:|---|
| 8 m (closest legal zoom) | **≈ 130 px** | L1 (70–180) |
| 40 m (default) | **≈ 26 px** | L2 (24–70) |
| 120 m (furthest legal zoom) | **≈ 8.6 px** | L3 (8–24) |

**A 1.0 m resident never reaches the crowd document's L0 threshold of ≥180 px anywhere in
the legal settlement camera range.** Crossing 180 px at the 8 m minimum would require an
animated bounding-sphere extent of ≥ 1.39 m — roughly 39% beyond standing height,
which a tail-and-pose envelope might reach and a neutral standing body will not.
This is a calculation from two sourced contracts, not a measurement, and it produced
GAP-05. It also fixes the acceptance render set: **8 m / 40 m / 120 m at 1920×1080**,
which is where Brendan will actually see these assets, in addition to the crowd
document's abstract 180/70/24/8 px sheet.

**GAP-05 is now settled by a settlement-specific override.** The settlement L0 admission
threshold is **nominal 64 render-target pixels** with pool cap **24**, retaining the
existing creature L0 geometry and rig ceiling. Battle is untouched at 180 px and cap 48.
The exact contract, bound in `lookdev_dimensions.gd` as integer tenths of a pixel so it
cannot drift by rounding:

| Field | Settlement | Battle |
|---|---:|---:|
| Initial admission | ≥ 64.0 px | ≥ 180 px |
| Promote at | ≥ 70.4 px | — |
| Demote below | 57.6 px | — |
| Residence before a transition | 0.20 s | 0.20 s |
| Pool cap | 24 | 48 |

Admission uses the **actual projected animated AABB maximum extent** — not UI logical
pixels, not monitor pixels, not a standing-height estimate. Ties rank by projected extent
descending, then camera-space depth ascending, then persistent ID ascending. Near-plane
crossing may request the highest representation immediately but **never bypasses the cap**.
Eligible overflow uses L1; non-eligible residents use the ordinary L1/L2/L3 thresholds.
Selection and naming grant nothing: **focusing one resident does not force a tiny character
into L0.** Transition all attachments atomically, return actors to the pool on loss of
eligibility, and reconstruct the current presentation pose without touching simulation.

The consequence for the ~26 px default orbit is **not** a bug: a settlement pool with zero
skeletal actors at the shipped 40 m default is correct. The 8–120 m range already supports
close inspection, so nothing moves the camera, changes model scale or lowers the threshold
to default-zoom size to manufacture an admission. Authoring an L0 at the 12,000-triangle
ceiling is therefore worth doing, because the 8 m end of the legal range reaches it.

**This closes the admission definition. It does not close performance or exported-rig
acceptance**, and no runtime implementation of it is claimed by this document.

### 2.3 What has actually been built so far

`godot/assets/units/species_mouse_body_a_lod0.glb` exists: **8,307 triangles, no skin,
no animation, no material, no texture image** (inspected directly). `assets/source/`
holds the raw `test_mouse_warrior.glb` it came from — a 5-credit Meshy test committed
in `a54041f` to prove the pipeline end to end. It validates the **axis, scale and pivot**
path only. Nothing in the repository has validated the rig, the clip bake, the palette,
the LOD chain or a texture atlas. Do not describe the crowd bake as proven.

Added in revision 1.1: `godot/assets/lookdev/proportion_comparison.tscn` and its six
captures under `godot/assets/lookdev/captures/`. Those are **hand-authored blockout volumes
built by a committed script**, not exported assets, not generated art and not approved
anatomy. They exist so the review in §2.4 can happen.

### 2.4 Species heights, the measurement convention, and the review that gates them

ART-GAP-R01/R02 supply anatomical-height **comparison candidates**. The ruling states in
terms that these are "not bulk-production approval".

| Species | Candidate, units (1/1024 m) | Integer millimetres (derived) | Status |
|---|---:|---:|---|
| mouse | 1024 | 1000 | Inherited crowd §9.1 anchor; measurement convention newly specified. **Still a comparison input** — what is judged is the relation between all five |
| mole | 922 | 900 | **Comparison candidate — not bulk-production approval** |
| squirrel | 1024 | 1000 | **Comparison candidate — not bulk-production approval** |
| otter | 1526 | 1490 | **Comparison candidate — not bulk-production approval.** Retains the prior 1.49 m candidate at integer precision; that is not an elevation into an approved tier |
| badger | 2611 | 2550 | **Comparison candidate — not bulk-production approval.** Same, for the prior 2.55 m |

Heights are authored in **integer millimetres**; float is import and presentation only. The
authoritative unit remains 1/1024 m, and the millimetre column is derived by half-up
rounding. Where they disagree the unit column wins — see §8's GAP-03 note for the one
building row where they do.

**The measurement convention** (new, and the reason a squirrel's tail cannot shrink its
torso): neutral standing, bare adult body, supporting soles on Y = 0, height to the highest
anatomical head or ear point in the neutral pose. **Exclude** raised tail, equipment,
headwear and animation extremes. Record crown, eye and shoulder heights, and record
separately the full animated AABB, the carried and stowed equipment bounds, and the
locomotion envelope. Non-standing species need their own length, wingspan and contact
conventions before production; none is written here.

`prep_unit.py` scales the **joined whole-mesh AABB including attachments** and is therefore
insufficient to verify this convention. Separate the reference body or use validated
landmark metadata, apply the same transform to every attachment, and validate the full
animated bounds. Do not run a squirrel through whole-tail-height scaling, and do not
silently modify an existing source asset. Axes stay −Z forward, +Y up, foot-origin.

**These candidate heights set no navigation clearance, service reach, step height or
movement capability.** MOVE-G01 owns those independently.

#### The prescribed comparison scene — built, and awaiting Brendan's eye

Decision 0002 requires mouse / hare-or-otter / badger beside the **same** door, table and
workbench, standing, walking, carrying and crouching, close and at the RTS camera, before
bulk proportions are approved. Mole and squirrel are included because the ruling gives them
new candidates. Giant residents remain excluded.

That scene now exists as `godot/assets/lookdev/proportion_comparison.tscn`, rebuildable with:

```bash
# scene + manifest only; works headless
godot --headless --path godot --script assets/lookdev/build_proportion_comparison.gd
# the review captures as well; needs a real rendering device
godot --path godot --script assets/lookdev/build_proportion_comparison.gd
```

Layout: five bays, one species each, reading mouse → badger left to right in the front
elevation. Each bay repeats a **dimensionally identical** prop set, because "the same door"
on a comparison sheet means the same dimensions beside every subject, not one shared
instance the far species cannot reach. Four stations, one per pose:

| Station | Pose | Prop, authored from the ruling |
|---|---|---|
| doorway | standing | 1536 × 3072 u opening (1500 × 3000 mm exactly) in a 3584 u panel |
| open ground | walking | none — stride and silhouette only |
| work surface | carrying | 2000 × 800 mm top at the 640 u (625 mm) candidate |
| table | crouching | 2000 × 2000 mm seat place, top at the same 640 u candidate |

A full-size `workbench` building at its 6 m footprint and 3584 u envelope stands behind the
sheet, and a 500 mm-banded scale rule stands beside it, so the elevation is read off rather
than believed. Captures: **8 m / 40 m / 120 m at pitch 48°**, plus pitch 35° close at the
work surface, pitch 65° at 40 m, and a 3200 × 800 orthographic front elevation. All at the
sourced camera contract — 55° vertical FOV, the legal 8–120 m orbit.

Yaw is captured at both **45°** (the shipped initial orbit) and **225°**. Residents face −Z,
so the shipped yaw shows their backs; orbit yaw is unrestricted, so 225° is an equally legal
camera and is where a face is visible. The pair doubles as the facing check, which §2.1 says
no script can make.

#### What the captures already show, before anyone rules on them

Three observations that follow from the ruling's own numbers and need no landmark
assumption. They are offered as **questions for the review**, not as findings:

1. **The 640 u work surface does not serve all five species.** 625 mm is 62.5% of a mouse's
   standing height and **24.5% of a badger's**. In the pitch-35° work-contact capture the
   surface reads as chest height for a mouse and roughly knee height for a badger. The
   ruling already anticipates this — 640 u is "an explicit candidate, not a universal
   work-contact policy for every species", and "adjustable or role-specific furnishings
   remain possible under later approved sheets". The comparison makes the size of the
   problem visible rather than arguable.
2. **The badger has 450 mm of headroom in a 3072 u doorway.** 2550 mm under a 3000 mm
   opening. That passes as a model brief. It is **not** a clearance qualification: the
   movement profile must qualify the real opening against a real animated body with gear,
   and this brief makes no claim about it.
3. **Mouse and squirrel share a candidate height**, so nothing in this sheet distinguishes
   them by stature. Their whole difference is tail, ear tufts and cheek mass — which is
   precisely what a blockout cannot judge, and what A3's construction sheet must.

One further note, kept honest. IMG-25's lineup ranks mole slightly below mouse and squirrel
at or above it, which is **directionally consistent** with 922 / 1024 / 1024. Its otter and
badger read taller relative to the mouse than the candidates imply. That observation is
**not** offered as a measurement: the lineup carries horizontal guide rules across the whole
frame, the figures are line art with no orthographic depth, and
[screenshot_review IMG-25](screenshot_review.md#img-25) says plainly "do not measure pixels
here and call the result canonical metres". It is recorded because the review should look at
the otter and badger relations with that discrepancy in mind.

**What this scene can and cannot settle.** It answers the **stature** half of decision 0002:
whether 922 reads right beside 1024, whether 2611 sits correctly under a 3072 u opening,
whether a 640 u surface serves a mole and a badger equally. It does **not** answer the
**anatomy** half — its bodies are boxes. That needs the per-species construction sheets in
§3's steps 1.1–1.2, which are separate deliverables. Approving the scene approves the
proportions, not the modelling.

## 3. Family A — representative residents (5 entries)

The roster is not a choice. [`docs/game_gdd.md`](../game_gdd.md) §5.1 fixes the starting
colony: **12 adults — 6 mice, 2 moles, 2 otters, 2 squirrels**, ID 1 named Warden Rowan.
Those four species are the representative residents, and they are the same four the UI
medallion set uses. Species IDs are compiled: `mouse=7, mole=6, otter=8, squirrel=12`
in `godot/data/catalog_ids.json`.

Shared geometry for A1–A4 (sourced, [crowd §2.7](../crowd_rendering_architecture.md)):

| Tier | Triangle ceiling **including gear** | Body vertices | Animation |
|---|---:|---:|---|
| L0 | 12,000 (≤3 surfaces; body is one surface) | — | Conventional skeleton ≤64 bones, 60 Hz |
| L1 | 3,500 | ≤2,400 | 4-influence bone texture, 30 Hz baked |
| L2 | 1,200 | ≤800 | 2-influence, 15 Hz |
| L3 | 350 | ≤250 | 1-influence, 10 Hz |

Atlas: one 2048² albedo + normal + ORM **per species family**; lower LODs share it
(crowd §9.1). Fur is a **sculpted silhouette plus albedo/normal detail** — no shell
fur, no hair strands, ever, in the crowd path. This is the single largest translation
step away from the approved image, whose close-view fur is explicitly listed in its
own manifest as exceeding the intended runtime simplification.

---

### A1 — mouse keeper (Rowan archetype) · `species_mouse_body_a`

**Source features.**

- IMG-12 `mouse_guardian` `[1019,383,1432,956)`: round ears with a visible inner
  plane and thickness at the root, forward-projecting muzzle, pale muzzle and brow
  markings against warm chestnut, a green outer garment gathered over a belt.
- IMG-25 `woodland_lineup` `[413,247,1304,565)`, cell labelled "Mouse": upright trunk
  shorter than the hare's, slender tail rooted at the pelvis, small broad paws.
  Used for **comparison only** — it is line art with no orthographic depth.
- IMG-04 `hearth_household` `[693,534,1383,997)` and `kitchen_group` `[55,570,659,995)`:
  the oatmeal apron over a coloured working dress, sleeves that clear the hands, cap.
- Approved image, left panel: the material relationship — matte linen with broad folds,
  a leather belt worn at its edges, restrained moss green against a cooler backdrop.
- `redwall::RW-OBJECT-food-vessels-and-wrappers` for what a keeper plausibly carries.

**Authored completion — invention, stated as invention.**

- **The entire rear and the whole neutral standing pose are invented.** Every reference
  above is a painted three-quarter or a line profile. A mirrored three-quarter is not a
  rear view.
- Ear inner-surface geometry, tail cross-section and taper, hind-paw contact surface,
  and the palm/digit structure required for a tool grip are invented.
- Apron tie, seam and fastener placement, tail opening in the skirt, pocket depth:
  invented. IMG-04's figures are soft illustration with no visible construction.
- The keeper is an **original character**. IMG-12's figure carries a sword, buckler
  and cloak; none of that transfers. No Abbey emblem, no champion identity, no
  biography beyond "Warden Rowan, experienced mouse keeper" (DEC-003).

**Geometry constraints.**

- Height **1.00 m — SOURCED**, crowd §9.1. The only sourced height in the project.
  Fantasy relative scale; do not substitute a biologically plausible mouse.
- LOD ceilings as the table above. Sockets `socket_main`, `socket_off`, `socket_head`
  defined in the bone map and counted against the 64-bone budget.
- Z-up→Y-up correction applied once; pivot between the feet; transforms applied;
  scale `(1,1,1)`; triangulated before bake; **−Z forward**, human-verified.
- Naming `species_mouse_body_a_lod0..3`, `rig_mouse_v1`.

**Acceptance views.**

1. Untextured blockout turnaround — front, side, **true rear**, three-quarter — before
   any clothing is fitted. A painted fur patch must not be able to hide wrong anatomy.
2. Crowd sheet: front/side/rear/¾ rendered at **180, 70, 24 and 8 px**. Species clear
   at 70 px; no body/gear detachment at 180 px; no missing shadow limbs (crowd §9.2.9).
3. **Game-camera set at 1920×1080, pitch 48°, yaw 45°: orbit 8 m, 40 m and 120 m.**
   At 40 m — where the game actually opens — the keeper must still read as a mouse and
   as a keeper. This is the view that decides acceptance, not the turnaround.
4. Lighting triple per bible §14.7's required review: neutral daylight, warm interior,
   winter/low light, same body materials.
5. **Facing fixture**: the "face north" test, by eye. Automated checks cannot see this.
6. Beside the approved image's left panel at matched framing, for material intent only.

---

### A2 — mole worker · `species_mole_body_a`

**Source features.**

- IMG-08 `mole_body` `[12,415,744,1066)`: compact rounded torso with mass carried low,
  tapering fleshy snout, very small eyes, **broad clawed digging hands** with heavy
  pale claws, forward-set shoulders.
- IMG-08 `pick` `[544,399,754,1060)`: how a heavy hafted tool sits in that hand.
- IMG-25 lineup, cell labelled "Mole": barely-visible ears, short limbs, the silhouette
  contrast against the mouse two cells away.
- Approved image, left panel: the ochre/umber waistcoat over a plain undershirt, muted
  trousers, a paw resting on a spade — the correct level of restraint.

**Authored completion — invention.**

- **The goggles, the armoured shoulder rig, the backpack and the articulated lantern
  arm in IMG-08 are excluded.** They are that presentation's concept equipment, not
  mole anatomy, and the approved image's prompt explicitly rejects "armor/goggles/
  industrial lantern rig". Excluding them is a decision, recorded here, not an oversight.
- IMG-08's hands are **gloved**. The ungloved hand, digit count, palm pad and claw root
  must be drawn from scratch before any glove or mitt is modelled.
- Rear anatomy, neck/shoulder junction under the waistcoat, and the tail (short, barely
  present in the references) are invented.
- Waistcoat buttons, belt pouch and their seams are invented.

**Geometry constraints.**

- Height **922 u = 900 mm — COMPARISON CANDIDATE, NOT PRODUCTION APPROVAL** (ART-GAP-R01,
  §2.4). Revision 1.0 carried a derived 1.00 m from IMG-25's "Small" category, which
  [screenshot_review IMG-25](screenshot_review.md#img-25) rejects as a height source —
  those bands are "squad model counts, not colony populations, hitboxes or height
  multipliers". The ruling replaces that derivation with an authored candidate: **the mole
  is shorter than the mouse, not equal to it.** Author to 922 u, labelled a candidate, and
  accept that the §2.4 review may still move it.
- Digging hands are wider than the mouse's; check them against the L2/L3 ceilings early,
  because claws are where triangles disappear first and where silhouette lives.
- All shared constraints as A1. Naming `species_mole_body_a_lod0..3`, `rig_mole_v1`.
- **A shared rig with the mouse is not assumed.** Crowd §9.2 step 10: sharing requires
  equal skeleton hierarchy, bone order, bind-space transforms and clip metadata, and
  "similar-looking species are not proof of compatibility". The mole's proportions
  differ enough that this must be tested, not asserted.

**Acceptance views.** As A1, plus:

7. Mole and mouse **side by side at 40 m**. The two must be distinguishable by
   silhouette alone at ~26 px. This is the specific test DEC-038 names: "Preserve the
   contrast between the mouse and mole; do not round every species into one plush body type."
8. Working contact pose with the A5 spade, checked for hand/haft penetration.

---

### A3 — squirrel · `species_squirrel_body_a`

**Source features.**

- IMG-07 `squirrel_group` `[775,4,1408,976)`: plume tail volume and its **pelvis root**,
  ear tufts, heavy cheek fur masses, short sleeved working shirt over a waistcoat.
- IMG-25 lineup, cell labelled "Squirrel": upright trunk, tail arc relative to body.
- IMG-04 `ladder_pair` `[1167,118,1364,759)`: a squirrel on a ladder — reach, grip and
  hind-paw placement in an everyday, non-combat context.

**Authored completion — invention.**

- The tail is the problem. References show it as a painted mass from one angle. Its
  **cross-section, root attachment volume, and animated bounds** are invented, and
  crowd §9.2 step 8 requires those bounds to include it — "banners, quivers, packs,
  poles, tails and wings must be included in animated bounds".
- IMG-07's figures are Border Squirrel mercenaries with tartan, bonnets and blades.
  **None of that transfers.** Per [the model guide](model_reference_guide.md) §2:
  "no permanent tartan or northern ancestry". The settlement squirrel is a resident.
- Rear view, ungloved paw structure and the hind-paw contact surface are invented.

**Geometry constraints.**

- Height **1024 u = 1000 mm — COMPARISON CANDIDATE, NOT PRODUCTION APPROVAL**
  (ART-GAP-R01, §2.4). The squirrel's candidate equals the mouse anchor, so **height is not
  what distinguishes it**: tail, ear tufts and cheek mass carry the whole silhouette
  difference. The measurement convention excludes the raised tail from height, which is the
  specific clause written for this species.
- The tail must not consume the LOD budget. At L3's 350 triangles including gear, the
  tail and the body compete directly; decide the split at blockout, not at simplification.
- All shared constraints as A1. `species_squirrel_body_a_lod0..3`, `rig_squirrel_v1`.

**Acceptance views.** As A1, plus:

9. Tail silhouette at 24 px in neutral, walk and carry poses — three renders, not one.
10. Animated AABB render with the tail at maximum extent, confirming it is inside the
    bounds actually exported (crowd §9.2 step 8: build bounds from **all** deformed
    vertices, plus 0.05 m offline padding).

---

### A4 — otter · `species_otter_body_a` — **comparison candidate supplied; proportion approval still open**

**Source features.**

- IMG-18 `otter_body` `[771,157,1284,932)`: the single best full standing otter in the
  folder — long torso, pale throat and chest against darker dorsal fur, small rounded
  ears set low, broad muzzle with a heavy nose pad, **thick tail tapering from a wide
  root**, broad hind feet with visible separated toes, plain belt and trousers.
- IMG-17 `raft_group` `[661,309,1390,947)`: practical river-work clothing and wet
  surface treatment.
- IMG-25 lineup, cell labelled "Otter": shoulder and torso mass relative to the mouse.

**Authored completion — invention.**

- Back, underside and the swimming stroke are invented; IMG-18 is a single front view.
- Webbing geometry between the toes is invented — it is implied, not drawn.
- Wet-versus-dry material state is a **presentation state to author**, not a second
  body. Per [the model guide](model_reference_guide.md) §4: no permanent green
  underwater tint on the ordinary otter body.
- IMG-18's strings of fish are a prop, not costume.

**Geometry constraints.**

- Height **1526 u = 1490 mm — COMPARISON CANDIDATE, NOT PRODUCTION APPROVAL**
  (ART-GAP-R02, §2.4). This retains revision 1.0's unconfirmed 1.49 m figure at integer
  precision. **It is not an elevation of that figure into an approved tier**, and the
  ruling says so.
- The contradiction revision 1.0 found is **resolved by separating the domains, not by
  picking a winner**. [Crowd §5](../crowd_rendering_architecture.md)'s small/medium/large/
  giant radii of **184/246/461/922 units** are horizontal battle locomotion and separation
  inputs. They are **not heights**, dividing them by 184 cannot specify animal stature, and
  **no species may be normalised by multiplying mouse height by its radius ratio**. The
  asset-pipeline skill's 1 : 1.49 : 2.55 and the radii's 1 : 1.337 : 2.505 were never two
  answers to one question.
- Reference sheets, blockout drawings and the §2.4 comparison bay are unblocked and done.
  **Bulk otter production still waits on the proportion approval**, because a re-export
  after a late ruling is the expensive path the skill warns about.

**Acceptance views.** As A1 once the proportions are approved, plus the otter-beside-mouse
relation already captured in §2.4's comparison sheet, and a wet/dry material pair under the
same light.

---

### A5 — the paired hand tool for bake validation · iron spade

Crowd §9.2 step 1: *"Produce the mouse body and one sword first. Do not generate all 20
species before validating the bake."* The settlement has **no sword**. Its gear items are
`tool`, `net`, `trap`, `ice_kit`, `candle`, `outfit_tier2` (`godot/data/catalog_ids.json`).
The rule is about validating one body plus one socketed attachment before scaling out;
the attachment here is the generic `tool`, rendered as the wooden-hafted iron spade the
approved image shows in the mole's paw. **Substituting the object does not relax the
order, and this substitution is recorded rather than assumed.**

**Source features.** Approved image, left panel: wooden haft with a visible grain
direction, a forged iron blade with a subdued cool highlight and a slightly worn edge.
IMG-08 `pick` for haft-in-hand scale and grip spacing.
`outcast::OUT_object_farm_tool_set` — "spades, hoes, rakes and trowels share forge with arms".

**Authored completion.** Ferrule/socket join between blade and haft, blade thickness
and rear face, and the stow orientation on the belt are all invented. A carried tool
must have a hand pose **or** a stowed location (model guide §3); both are authored here.

**Geometry constraints.**

- Length proportioned to the 1.00 m mouse, not to a human spade. Held two-handed by the
  mole, one-handed at rest.
- Counts **inside** the resident LOD ceiling — crowd §2.7's limits are "including gear".
  Proposed ≤600 triangles at L0 falling to ≤40 at L3 so the body keeps its headroom.
  *This split remains PROPOSED and is not ratified; the 12,000/3,500/1,200/350 totals are
  sourced from crowd §2.7. GAP-04's non-creature families do not apply to a tool carried in
  a socket, because crowd §2.7's creature limits are already "including gear".*
- Binds to `socket_main`. Tool tip deformation tolerance is **5 mm** at baked frames and
  **20 mm** at L1 half-frames (crowd §9.2 step 7) — twice the body tolerance and the
  thing most likely to fail first.

**Acceptance views.**

1. Tool alone, turnaround, with the haft grain direction visible.
2. In `socket_main` on the mole at 180/70/24 px. Crowd §9.2 step 9 requires a tool to be
   distinguishable at 24 px when its length is ≥6 px — check whether a spade at 1 m
   scale even reaches 6 px at 40 m before accepting the silhouette.
3. Deformation comparison: crowd-deformed tip vs conventional reference at every baked
   frame of the carry and work clips. **≤5 mm.**

## 4. Family B — dwelling / workspace (3 entries)

Footprints are **2 m tiles** ([GDD §5.9](../game_gdd.md)). A "6×6" building is therefore
12 m × 12 m. The approved image's cottage is a generated concept and its proportions are
not a spec — model to the catalog footprint, not to the picture.

### B1 — workbench shelter · footprint 3×3 tiles = **6 m × 6 m**

Catalog row, [GDD §5.9](../game_gdd.md): wood 12, stone 4, 180 WU, Crafter 2,
2 craft slots, unlocked at Start. It is one of the structures the starting settlement
already contains — placed at exterior tile (58,54), rotation 0. It has **no managed
interior**, so no cutaway is required.

**Source features.** Approved image, left panel: the timber post-and-lintel frame, the
supported shingle roof plane, split wood stacked against the wall, the solid low
worktable. Approved image, right panel: how that structure reads from above at RTS pitch.
IMG-04 `kitchen_group` for what a working surface is actually covered in.
`taggerung::TAG_place_nimbalo_s_family_farm` — thatched, single-window, hearth, working
flatland beside it.

**Authored completion.** Post footing detail, rafter count and joinery, roof pitch,
shingle-versus-thatch choice, and the entire underside of the roof are invented.
Which of the Abbey / Holt / Fortress visual kits this shelter belongs to is an authored
choice — [GDD §5.1](../game_gdd.md) says the three kits have identical costs and
capacities, so the kit is presentation, and a kit variant set is three models, not one.

**Geometry constraints.**

- Footprint exactly 6 m × 6 m; it must occupy 3×3 tiles with no overhang into the
  neighbouring tile, because REQ-SET-122 validates placement on in-bounds non-overlapping
  tiles with slope ≤8° and height spread ≤0.5 m.
- **Maximum local Y: 3584 u = 3500 mm** (GAP-03), above the placed ground datum, covering
  shell, roof, fixed chimney and signs. Local Y = 0 is the placed base; rotation affects
  X/Z only. Shared enclosed-building values also apply: **3072 u minimum clear internal
  height** and a **1536 × 3072 u** common-access door opening, with the header fitting
  inside the envelope. Those are model-brief dimensions and **not proof that any body or
  gear profile passes the opening** — the movement profile qualifies real clearances.
  The camera's obstacle sweep (`ui_ux_controls.md` §6 — 0.5 m sphere, orbit shortened to
  hit distance − 0.5 m) is view-only: it reads verified proxies and terrain, and decides
  no navigation or simulation collision.
- Ground plane at **y = 0.5 m**: [GDD §5.1](../game_gdd.md) fixes navigable land at
  `y=512` units and water surface at `y=0`, and states "water-bank interpolation affects
  visuals only". The shipping estuary preset is essentially flat.
- Triangulated, transforms applied, −Z forward, pivot at the **footprint centre on the
  ground plane** (the crowd "feet" rule generalises to ground-projected body centre for
  non-bipeds).
- **Building assembly ceilings (GAP-04, ratified): 32,000 / 10,000 / 2,500 triangles at
  near / mid / far, at most 4 distinct shared materials, at most 16 draw surfaces at near
  and mid and 4 at far, texture edge ≤ 2048.** Counted after triangulation, including
  attached decorative mesh parts. Separately instanced furniture and props are charged
  separately once and cannot vanish from whole-scene accounting. Near/mid/far are static
  geometry tiers, not creature animation L0–L3.
- Every delivered asset must declare **measured** local min/max bounds, its structural
  camera-obstacle proxy pieces and its pivots. The table bounds the asset; the proxy
  describes the structure. Static roof and wall proxies enclose their opaque surfaces,
  retain real openings and rotate with the building. Do not treat a whole footprint as
  solid where no geometry exists, do not fall back to mesh height 0, and do not derive
  camera obstacles from resident navigation radii.
- Blueprint, unfinished and complete stages expose their corresponding proxy geometry.
- **Cannot be normalised by `prep_unit.py` as written** if it keeps separate roof/frame
  objects, because the script joins everything into one mesh. Run
  `asset_import_validator.gd` instead (§2.1).

**Acceptance views.**

1. Exterior turnaround at 45° increments, untextured then textured.
2. **Game camera at 8 m, 40 m, 120 m, pitch 48° and pitch 65°** — the extreme pitch is
   where a roof plane stops reading and a building becomes a grey lozenge.
3. Placed on its real tile footprint with the tile grid visible, proving 3×3 exactly.
4. With a mouse resident standing at the work slot, at 40 m. A 1.0 m resident against a
   6 m building is the scale relationship that will look wrong first.
5. Daylight / warm interior spill / winter, per bible §14.7's required review conditions.
6. Facing check by eye — the door must face the way the placement code thinks it does.

### B2 — kitchen · footprint 6×6 tiles = **12 m × 12 m**

Catalog row, [GDD §5.9](../game_gdd.md): wood 30, stone 20, iron 2, 600 WU, Cook 2,
**"Black box; 2 cooking slots"**, unlocked at Start. Black box means no modelled managed
interior — exterior shell plus an entrance only. This is the closest catalog match to the
approved image's "timber-and-fieldstone kitchen/workshop with an open door".

**Source features.** Approved image: fieldstone coursing with matte irregular mass,
heavy timber lintel over the door, warm interior glow visible through the opening,
hanging cookware silhouetted against it, herbs drying at the jamb, a wall lantern.
IMG-03 `kitchen_group` and IMG-04 `hearth_household` for what the glow is coming from.
`martin_warrior::MW_PLACE_noonvale` for the thatched-cottage register.

**Authored completion.** Stone coursing pattern, quoin treatment, chimney (the approved
image shows one on the right panel; nothing in the catalog says a kitchen has a chimney),
door swing, and the shallow interior volume visible through the doorway are all invented.
The warm glow is a **light and a shallow false interior**, not a room — the catalog says
black box, and modelling a real interior would imply room mechanics the building does
not have.

**Geometry constraints.** As B1, at 12 m × 12 m. **Maximum local Y 5120 u = 5000 mm**
(GAP-03), and the same building-assembly ceilings as B1 (GAP-04): 32,000 / 10,000 / 2,500
triangles, 4 materials, 16/16/4 draw surfaces, 2048 texture edge.
The lit doorway must not read as an enterable room; residents do not path inside a
black box.

**Acceptance views.** As B1, plus a night/dusk render proving the doorway glow reads
without a bloom haze (the approved image's own prompt rules out bloom haze and a warm
colour cast), and a render confirming no resident-sized opening implies access.

### B3 — residence · footprint 10×8 tiles = **20 m × 16 m** — **cutaway ownership now specified**

Catalog row, [GDD §5.9](../game_gdd.md): wood 60, stone 24, cloth 8, 1200 WU,
**managed interior 8×6, 12-bed layout capacity**, furniture bought separately.

Revision 1.0 blocked this entry because the interior was a *behaviour* with no *geometry
ownership*. [`ui_ux_controls.md` §6](../ui_ux_controls.md) specified the runtime behaviour
precisely — roof AUTO / HIDE_SELECTED / SHOW_ALL, **"walls on the camera-facing side of a
selected interior hide down to 1 m height"**, 120 ms alpha-dither fade, collision unchanged
— and nothing stated who owned the split.

**GAP-06 now states it.** A managed building ships these separately addressable parts:

| Part | Extent |
|---|---|
| `roof` | whole roof |
| `wall_n_upper`, `wall_e_upper`, `wall_s_upper`, `wall_w_upper` | above the inherited 1 m (1024 u) cut |
| `wall_n_lower`, `wall_e_lower`, `wall_s_lower`, `wall_w_lower` | below that cut |
| `floor` | interior floor |
| opening and cap geometry | **the part naming for these is NOT settled — see §2.1's named blocker** |

Closed roof and upper-wall variants and their selected cutaway variants share the **same
base transform and the same actual bounds**. Render caps at the cut, so a hidden upper wall
does not reveal a hollow shell. Use the UI's existing fade, visibility and collision or
navigation rules; a cutaway changes none of them, and it changes no authoritative room
occupancy or access either. A far representation must **still honour cutaway visibility**
grouping — do not fuse far into an unhideable shell. Include visible cut caps and opening
geometry inside both the triangle and the surface limits.

**Geometry constraints.** **Maximum local Y 6144 u = 6000 mm** (GAP-03), building-assembly
ceilings as B1 (GAP-04). The multi-part hierarchy **bypasses `prep_unit.py`'s join** and is
checked by `asset_import_validator.gd`.

Reference sheets, floor-plan studies against the sourced 10×8 starter interior layout
in [GDD §5.9](../game_gdd.md) and material studies proceed as before.
[Bible §14.5](../setting_bible.md)'s Blender handoff row still stands for the parts this
contract does not cover: **earth-cover and entrance ownership, and validation of selected
exterior/interior views against the final construction contract, remain open**, and no
engine evidence for any of this exists yet.

## 5. Family C — ground and vegetation (4 entries)

### C1 — ground material set · LOAM / CLAY / SAND

**Sourced, not invented**: `Soil` is a three-value enum `LOAM=0, CLAY=1, SAND=2`
(`godot/data/catalog_ids.json`), and [GDD §5.1](../game_gdd.md) places them:
"Land soil is LOAM for x=40..74, z=40..88, SAND within 4 tiles of coast or x>=112,
CLAY otherwise." Plus two path buildings at 1×1 tile each: **dirt path** (no materials,
2 WU, +10% ground speed) and **paved path** (stone 1, 6 WU, +20%, replaces dirt).

**Source features.** Approved image ground plane: earthen path with a few worn flat
stones set into it, localized wear along the walked line rather than uniform dirt,
grass and weeds surviving at the edges. Bible §14.7: "Wear appears at contact, water
paths, grips, thresholds, hinges and repairs" and "Maintained homes can look cared for;
age is not represented by uniform dirt everywhere."

**Authored completion.** Every texel. No reference supplies a tiling ground texture.
Texel density, tile period, blend-mask authoring, whether soil type is a material swap
or a vertex blend, and whether paths are decals, mesh strips or a terrain layer — all
invented, and the last of those is an engineering decision this brief does not own.

**Geometry constraints.**

- Flat. Navigable land is `y=512` units (0.5 m) across the preset; water surface `y=0`;
  the ford at `y=−128`. Visual relief is presentation only and must not change the
  slope ≤8° / height spread ≤0.5 m placement result (REQ-SET-122).
- Tile period must be a whole divisor of the 2 m gameplay tile so that a soil boundary
  lands on a tile edge; soil is a per-tile quantity.
- **Ratified (GAP-04 C1):** shared LOAM / CLAY / SAND albedo, normal and ORM textures,
  source period **4 m at 1024 pixels = 256 texels/m**, with a repeatable world-space phase
  from the world origin. Blend masks follow actual terrain data and **imply no fertility
  change**. A flat 2 m tile is two triangles; a 16×16 exterior-tile chunk starts at **512
  surface triangles**. Shore-height transition geometry is counted **separately** and
  checked against the actual generator. No tessellation or displacement changes collision
  or navigation, and **no new terrain tessellation algorithm is prescribed** — terrain is
  measured independently in the full scene.
- Texel density targets: **structures 128 texels/m, furniture and props 256 texels/m**,
  ±25% within a family unless a documented focal detail uses a separately budgeted region.
  These are authoring targets, not display-pixel promises.

**Acceptance views.**

1. A 16×16-tile (32 m) patch of each soil at **40 m and 120 m**, checking for visible
   tiling repeat. Repeat is invisible at 8 m and obvious at 120 m; test the far view.
2. A LOAM↔SAND and LOAM↔CLAY boundary at 40 m, on a tile edge.
3. Dirt path and paved path crossing all three soils, at 8 m and 40 m, showing the wear
   concentrated on the walked line.
4. The same patch under daylight / warm evening / winter.
5. Beside the approved image's ground at matched value — not matched hue.

### C2 — woodland tree life-cycle set · mature / stump / sapling

**Sourced states.** [GDD §5.9](../game_gdd.md): a mature node yields 12 wood U;
"Trees regrow after 48 days when their stumps remain and no building occupies the tile";
planting a cleared forestry tile costs compost 0.25 U and 4 WU and also matures in 48
days. REQ-SET-138: felling "shall debit its wood once and leave a **dated stump** for
permitted regrowth". Tree centres occupy every second x and every second z in the forest
masks, with a guaranteed 100-tree grove at x=40..49, z=54..63 ([GDD §5.1](../game_gdd.md)).

So the set is **three meshes minimum**: mature, stump, sapling. It is not a decorative tree.

**Source features.** Approved image: canopy read as broad grouped masses with light
passing through the edges, opaque trunk, no leaf noise. `outcast::OUT_ecology_autumn_orchard`
— russet apples, golden pears, browning elm, low-bough harvest. IMG-09's canopy region
for branch-contact plausibility (canopy traversal is adopted scope, though not modelled here).

**Authored completion.** Species of tree, bark, branch structure, seasonal leaf states
and the stump's cut face are all invented; no supplied reference contains a usable tree.
Whether a "dated stump" shows its age visually is an invention this brief proposes and
does not assume.

**Geometry constraints.**

- **Ratified (GAP-07):** opaque trunks and alpha-scissor foliage are **explicitly adopted
  for settlement art**, with at most two overlapping leaf-card layers along the principal
  **48°** gameplay view in the single-tree fixture. Check **35° and 65°** and the 100-tree
  grove for real overlap and overdraw: **two layers per tree is not a scene-wide
  guarantee.** No full alpha-blended foliage fallback, and no blended strand-fur or
  leaf-card escalation to hide a weak silhouette. Share geometry and material batches.
  Alpha-cutout foliage must be **measured** for overdraw.
- One tree per **2 m tile**, centres on every second tile. Canopy overhang across a tile
  boundary is a visual choice that must not imply the neighbouring tile is occupied.
- **Tree / large vegetation ceilings (GAP-04, ratified): 6,000 / 2,000 / 500 triangles at
  near / mid / far, at most 2 draw surfaces, texture edge ≤ 2048.** A stump and a sapling
  are the same family and are charged against the same ceiling; the revision 1.0 proposals
  of 1,800 / 600 / 200, stump 120 and sapling 200 all sit comfortably inside it and remain
  authoring intentions rather than limits.
- Static admission, initially: **near at projected maximum AABB extent ≥ 180 render px,
  mid at ≥ 48, far below**, with 10% hysteresis and 0.20 s residence — far→mid at 52.8 px,
  mid→far below 43.2 px, mid→near at 198 px, near→mid below 162 px. **Do not force every
  instance to near because the asset has a near mesh.**
- The guaranteed grove is 100 trees in a 10×10-tile block, and it stays the first place a
  settlement draw-call count must be **measured**. The per-asset ceilings above are not a
  frame-time pass.

**Acceptance views.**

1. Single mature tree: 8 m, 40 m, 120 m.
2. **The guaranteed grove — 100 trees at x=40..49, z=54..63 — rendered at 40 m and
   120 m.** One tree looks fine; a hundred is where the leaf layers and the repeat fail.
3. Felled sequence on one tile: mature → stump → sapling → mature, four stills at 40 m,
   confirming each state is distinguishable at ~26 px.
4. Canopy against sky and against ground, checking alpha-scissor edges do not sparkle.
5. Daylight / evening / winter, with the winter state being a distinct leaf state and
   not a colour filter.

### C3 — crop plot state set · 5 states × 5 crops

**Sourced.** `CropState` is `EMPTY=0, SOWN=1, GROWING=2, RIPE=3, WITHERED=4`
([GDD §4.3](../game_gdd.md), and identically in `catalog_ids.json`).
`CropDefinition` is `beans, cabbage, flax, grain, roots` (five). Fields use **2 m × 2 m
tiles**; designation is 4–256 tiles ([GDD §5.6](../game_gdd.md)). A plot records its own
growth and soil. WITHERED is reached 5 days after ripe if unharvested.

That is **25 tile appearances**, plus the fallow/compost surface treatment. The player
must be able to read "this field is ripe" and "this field withered" from the default 40 m
camera without opening a panel — otherwise the farming loop is invisible.

**Source features.** `taggerung::TAG_ecology_woodland_seasonal_texture` — "orchards and
garden rows create inhabited woodland rather than empty wilderness". Approved image,
right panel: cultivated rows inside a low fence, legible as rows from above. IMG-04's
produce for ripe-state colour.

**Authored completion.** Every plant. Grain, roots, beans, cabbage and flax growth
silhouettes are invented; no supplied reference shows a growing crop. Row spacing within
the 2 m tile, whether SOWN shows bare tilled soil or visible seed drills, and what
WITHERED looks like that is not simply "brown" are all invented.

**Geometry constraints.**

- One tile-sized module per (crop, state); it must tile edge-to-edge with its neighbours
  without a visible seam, because fields are painted connected areas up to 256 tiles.
- **Instanced, not one node per tile.** 4096 active farm tiles are permitted
  ([GDD §4.2 FarmPlot](../game_gdd.md)); a per-tile `Node3D` would be an architecture
  violation.
- **Ratified (GAP-04 C3): per 2 m crop tile, near 256 / mid 96 / far 16 triangles, one
  material surface, a shared crop and state texture set at a 2048 atlas maximum.** At all
  4096 permitted farm tiles the worst case is **1,048,576 triangles all-near, 393,216
  all-mid, 65,536 all-far.** Those are counts, not measured GPU times, and GPU
  qualification is open.
- Bind EMPTY / SOWN / GROWING / RIPE / WITHERED and the five crops to **real state**.
  Neighbouring geometry may batch but must not remove tile or state identity. Reduce
  density or LOD when needed; **never exceed the ceiling by instancing a full plant budget
  once per stalk.**
- EMPTY and WITHERED must be distinguishable from each other and from plain LOAM.

**Acceptance views.**

1. A 4×4-tile plot of each crop, in all five states, at **40 m** — twenty-five renders,
   and this is the point of the exercise.
2. The same at 120 m: at 120 m a 2 m tile is ~17 px, so state readability at max zoom
   should be judged and, if it fails, fixed with value grouping rather than by adding
   geometry (bible §14.7's stated priority order).
3. A 16-tile field with a ripe/withered boundary, proving the difference is visible.
4. Seam test: a 4×4 plot with every tile a different state, checking module edges.
5. Seasonal light triple.

### C4 — understory dressing set · fern clump, grass tuft, herb/wildflower patch

**Source features.** Approved image: "purposeful clusters of fern", grass surviving at
path edges, a planted border rather than scattered filler.
`taggerung::TAG_ecology_woodland_seasonal_texture` — dogrose, vetchling, red clover.

**Authored completion.** All plant geometry. Placement density and scatter rule.

**Geometry constraints.**

- **Decorative only.** Bible §14.7: "Decoration does not masquerade as harvestable stock,
  obscure commands or imply unsupported traversal." Forage stock lives in ecology basins
  with quotas ([GDD §5.1](../game_gdd.md)); a wildflower patch that looks harvestable and
  is not is a UI lie. If a dressing plant resembles a forage item, change the plant.
- Must not occlude a resident at 40 m. A 1.0 m resident is ~26 px there; a 0.4 m fern is
  ~10 px and can hide a third of them.
- `MultiMeshInstance3D` scatter, never individual nodes.
- **Ground cover cluster ceilings (GAP-04, ratified): 600 / 180 / 40 triangles at near /
  mid / far, one draw surface, texture edge ≤ 1024.** Revision 1.0's fern 150, grass 24 and
  herb 90 sit inside that and remain authoring intentions.

**Acceptance views.**

1. Scatter field at 8 m, 40 m, 120 m.
2. **A resident walking through dense dressing at 40 m** — the occlusion test.
3. Dressing beside a real forage basin edge, confirming they are not confusable.
4. Seasonal triple; winter must not be the summer mesh tinted grey.

## 6. Family D — practical props (6 entries)

The mole's spade is **A5**, not repeated here.

### D1 — wicker carry basket

**Source.** Approved image, left panel: the mouse's small wicker basket with roots and
leafy tops, weave visible as a grouped pattern rather than per-strand.
`triss::TRI_object_strawberry_trug` — a harvest basket connects orchard picking to
kitchen work. `redwall::RW-OBJECT-wicker-repair-baskets` — grain baskets reused for
haul work. `redwall::RW-OBJECT-food-vessels-and-wrappers` — rush baskets among the vessels.

**Authored completion.** Weave geometry (it will be a normal map, not modelled strands),
handle join, interior floor, and the empty-versus-full state. The contents are separate:
a basket of roots is `roots`, a basket of berries is `berries`, and these are catalog
items with real quantities — the mesh must not imply a quantity.

**Geometry constraints.** Scaled to a 1.0 m resident's forearm, carried at `socket_main`
or `socket_off`. **Carried props count inside the resident's LOD ceiling**, which is the
binding limit here; when the basket appears as a static scene prop instead it is charged
against GAP-04's **tool / resource / small prop** family: 1,200 / 400 / 100 triangles at
near / mid / far, one draw surface, texture edge ≤ 1024. Triangulated, −Z forward.

**Acceptance views.** Turnaround; in-hand at 8/40/120 m; empty and full; at 24 px to
confirm the basket silhouette survives; carried in the walk clip without arm penetration.

### D2 — split-log wood stack

**Source.** Approved image: split logs stacked against the wall with visible end-grain
starbursts, an irregular but stable stack. IMG-08's rough timber for bark treatment.

**Binding.** `wood` is `ItemDefinition` 59 at **5000 g/U** ([GDD §5.7](../game_gdd.md)).
This is the stored-wood visual. **Note the identity collision with UI**: ART-LOCK-001
specifies wood as "a three-log stack" and fuel as "flame and embers", and requires them
to be distinguishable. That constraint belongs to the 2D icon family; the 3D stack is
free of it, but the two should not read as unrelated objects.

**Authored completion.** Log count per unit, stacking pattern, how the stack grows and
shrinks with stored quantity, and the split faces.

**Geometry constraints.** Occupies part of a 2 m tile. **Small-prop ceilings (GAP-04):
1,200 / 400 / 100 triangles, one draw surface, texture edge ≤ 1024**, or a tile inside a
shared 2048 atlas rather than its own texture. If it represents a changing quantity it uses
the same fill vocabulary as D3 — empty, then ≤ 1/3, ≤ 2/3, > 2/3 of the **actual** container
capacity — rather than an invented number of levels.

**Acceptance views.** Turnaround; three fill levels at 40 m; against the B1 shelter wall
as in the approved image; at 120 m to confirm it does not vanish into the wall value.

### D3 — open-stockpile container fill · **revision 1.0's reading of this entry was wrong**

**Sourced and mechanically bound.** Open stockpile is 4×4 tiles = **8 m × 8 m**, wood 4,
60 WU, **400000 g open storage** ([GDD §5.9](../game_gdd.md)). The starting settlement
has four of them, at (50,60), (50,65), (70,60), (70,65).

> **Correction required before modelling (ruling ART-GAP-R04, D3).** An 8 × 8 m open
> stockpile with its 400000 g main container **is not sixteen independent 400000 g ground
> piles.** Revision 1.0 read §5.9's "Ground piles hold at most 400000 g each and create
> adjacent passable tiles in N,E,S,W breadth-first order when a pile is full" as a property
> of the stockpile building. It is not. That sentence belongs to **ground-pile placement** —
> the temporary visible piles REQ-SET-110 allows when storage capacity is insufficient — and
> it is **not automatic per-tile stockpile capacity expansion**. Modelling sixteen spilling
> per-tile piles inside one building would have shown the player a storage capacity that
> does not exist.
>
> **Bind visuals to each actual container. Invent no lots.**

**Source features.** Approved image, right panel: barrels, sacks and stacked goods
arranged as a worked yard rather than a heap. IMG-05 `barrel` and `wagon` regions for
container forms.

**Authored completion.** Pile shape per item category, the sack/crate/barrel vocabulary,
and the fill-level stages. `ItemCategory` has eleven values (`FEAST, GEAR, LIQUID,
MATERIAL, PREPARED, PRESERVED, RAW_FISH, RAW_FOOD, SAPLING, SEED, WASTE`); how many
distinct pile looks that needs is an authored decision, not a given. Use **stable dominant
item-category styling**; exact quantities stay in the UI, and the mesh never states one.

**Geometry constraints (GAP-04 D3, ratified).**

- **Per-container pile assembly ceiling: 1,200 / 400 / 100 triangles at near / mid / far,
  one material.** If an 8 × 8 m container is dressed with sixteen decorative submodules,
  **their SUM stays inside that ceiling** — a container is one container.
- Fill variants: **empty = empty**, then non-empty variants at occupied mass **≤ 1/3,
  ≤ 2/3 and > 2/3 of the container's ACTUAL capacity**. Four visual states, bound to the
  real container, not to a tile count.
- **Quality, age and reservation do not duplicate visible quantity.** A reserved or aging
  stack is not a fuller stack.
- Ground piles — the separate, temporary REQ-SET-110 objects — keep the N,E,S,W spill
  behaviour and must not block the walk tiles that rule creates. They are their own visual,
  charged against the small-prop family, and are not this entry.

**Acceptance views.** One container at all four fill states; a full 4×4 stockpile at 40 m;
a **ground pile** spill case — one full pile plus its N neighbour starting — at 40 m, framed
so it is visibly a different object from the stockpile building; at 120 m to confirm a full
container is distinguishable from an empty one at max zoom.

### D4 — seat / table place

**Sourced with an explicit visual requirement.** Furniture row, [GDD §5.9](../game_gdd.md):
1×1 tile, wood 1, 10 WU, "1 diner; **group table visuals merge**". The starter hall
contains **twelve** seat places, laid out in the 10×8 interior as `TTTT` runs.

"Group table visuals merge" is a spec line that directly binds art: adjacent seat places
must combine into a continuous table rather than showing twelve separate stools.

**Source features.** IMG-04 `hearth_household` and IMG-03 `kitchen_group`: long communal
boards, bench seating, handmade construction with stable feet. Approved image: the solid
worktable, timber grain following the piece, wear at the edge where hands rest.

**Authored completion.** The merge rule itself — corner pieces, end caps, how a run of
four differs from a run of two, and whether a bench or individual stools. All invented;
the GDD says merge, not how.

**Geometry constraints.** 1×1 tile = 2 m × 2 m per diner. Modular so runs merge without
a seam. **Furniture-instance ceilings (GAP-04): 2,000 / 700 / 180 triangles at near / mid /
far, at most 2 draw surfaces, texture edge ≤ 1024** — charged **per instance**, so a run of
four costs four instances and cannot disappear from whole-scene accounting. Must leave the
adjacent walk tile clear — GDD §5.9: "every seat has an adjacent walk tile above or below".
A table top is a work surface: the §2.4 comparison uses **640 u = 625 mm** as an explicit
candidate top height, **not** a universal work-contact policy for every species.

**Acceptance views.** A single place; a run of four; the starter hall's exact `TTTT`
arrangement at 40 m with the roof hidden; the merge seam at 8 m; with four residents
seated, confirming a 1.0 m resident fits the seat.

### D5 — hearth

**Sourced.** Furniture row, [GDD §5.9](../game_gdd.md): **2×1 tiles = 4 m × 2 m**,
stone 6, 60 WU, "Heat up to 120 interior tiles". Heat is a connected service — "a fueled
hearth supplies every valid room connected by open boundaries or interior doors within
that building". Kitchen rooms require ≥1 hearth. The starter hall has exactly one.

**Source features.** Approved image: the warm fire visible through the kitchen doorway,
iron cookware hung above, stone mass with a matte irregular surface, no bloom haze.
IMG-04 `hearth_household`; `taggerung::TAG_place_nimbalo_s_family_farm` (cottage hearth).

**Authored completion.** Stone construction pattern, lintel, whether a chimney or a smoke
hood, the fire itself as a VFX element, and the **unlit state**. The unlit state matters:
the audio direction in bible §15 states "unlit hearths do not sound like fires"; the same
discipline applies to the visual — an unfueled hearth must not glow.

**Geometry constraints.** 4 m × 2 m, occupying two tiles. **Furniture-instance ceilings
(GAP-04): 2,000 / 700 / 180 triangles, at most 2 draw surfaces, texture edge ≤ 1024.**
Lit/unlit must be a material and light state on one mesh, not two meshes. Interior fixture,
so it is seen through the B3 cutaway — and **B3's cutaway ownership now has an authoring
contract (GAP-06)**, so the hearth can be reviewed in situ as soon as a residence with the
named parts exists. **Contact and runtime validation remain open**; an authoring contract is
not a rendered interior.

**Acceptance views.** Turnaround; lit and unlit at 8 m and 40 m; through a doorway at
40 m as the approved image frames it; with the fire VFX off, confirming the mesh reads
as a hearth without the fire doing the work.

### D6 — wall lantern (candle fixture)

**Source features.** Approved image, left panel: a simple iron-framed glazed lantern on a
wall bracket beside the door — plain, domestic, small. Its restraint is the point.

**Binding, stated honestly.** `candle` is a real `ItemDefinition` (id 4 in `godot/data/catalog_ids.json`), listed
among the portable gear masses at 125 g in [GDD §5.7](../game_gdd.md). A **fixed wall lantern is not in the building or furniture catalog.**
There is therefore no placement, cost, work, capacity or light rule for it, and this prop
is **`DECORATIVE_ONLY`** per bible §14.4's `mechanical_binding` field. It must not imply a
light level, a safety radius, a fuel cost or a night-work bonus, because none exist.
`redwall::RW-OBJECT-lanterns-and-hourglass` supplies the source register.

**Authored completion.** Frame, glazing, bracket, mounting height and the flame. All
invented. IMG-08's articulated lantern rig is **explicitly excluded** — it is concept
mining equipment, and the approved image's prompt rejects an "industrial lantern rig".

**Geometry constraints.** Scaled to a 1.0 m resident's reach. **Small-prop ceilings
(GAP-04): 1,200 / 400 / 100 triangles, one draw surface, texture edge ≤ 1024.** Mounted on
a B1/B2 wall; its pivot is the bracket root, not the ground, which is the one place in this
brief where the feet-at-origin rule does not apply — record that deviation in the asset
manifest rather than letting `prep_unit.py`'s `min_z == 0` check silently force it to the
floor.

**Acceptance views.** Turnaround; mounted on B2 at 8 m and 40 m; lit at dusk without
bloom; at 24 px, where it should read as a small warm point and nothing more.

## 7. Production and validation sequence

[Crowd §9.2](../crowd_rendering_architecture.md) fixes the order and it is not
negotiable: **one body and one attachment first, validate the bake, then the next
species. Do not batch.** The sequence below obeys that and adds the non-creature
families, which §9.2 does not cover.

### Phase 0 — settle before touching a tool

**Done for the non-creature families.** GAP-03, GAP-04 and GAP-06 through GAP-09 now carry
authoring contracts, and §2.4 binds the species candidates and the measurement convention.

**Not done for the creatures.** The one remaining Phase 0 item is the §2.4 comparison
review itself: Brendan looks at the captures and rules on the five proportions. That review
costs nothing and prevents exactly the re-export the asset-pipeline skill warns about:
*"Settle the remaining tiers by eye with two side by side before bulk generation; re-running
every asset later is the expensive alternative."* **No bulk creature work starts before it.**

### Phase 0b — the material authoring baseline (GAP-09, ratified)

Standard **metallic/roughness PBR** is the material authoring baseline, opaque except for
declared foliage and cutaway effects. A shared **ORM** texture stores occlusion in R,
roughness in G, metallic in B. Normal and ORM are **linear data**; albedo follows its import
colour-space convention. Non-metal cloth, wood, stone and fur are metallic 0; clean exposed
metal regions are 1; grime and rust stay non-metal.

| Material | Starting roughness |
|---|---:|
| linen | 0.9 |
| dry timber | 0.8 |
| stone | 0.85 |
| leather | 0.65 |
| forged iron | 0.5 |

These are **look-development starting values, not physical measurements**, and authored
spatial variation remains allowed provided it matches the approved look. The crowd
deformation shader samples the same PBR inputs: **no replacement toon or fur lighting
pipeline is implicitly approved**, and renderer, anti-aliasing and GI defaults are not
altered to flatter a beauty render. Background:
[Godot material documentation](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html),
consulted 2026-09-11 — which supports the material options, not this project's budgets.

A small asset may take a tile in a shared 2048 atlas instead of its own 1024 texture; a
shared atlas edge is ≤ 2048. Authoring sources may be larger, but **imported runtime
textures obey these ceilings**. Use shared timber, stone, cloth and metal materials with
per-instance variation: **no material or full texture set per resident, plank or bed.**

Aggregate environment allocations: **≤ 128 MiB of loaded non-creature meshes across all
LODs, ≤ 256 MiB of loaded non-creature material textures including mips and every loaded
variant.** These are **sub-budgets inside** the existing 2.5 GiB loaded-graphics ceiling and
4 GiB process target, charged alongside the unchanged creature and crowd allocations — not
additions to them, and not simulation memory. The 100 MB simulation requirement is separate.
Charge a shared resource once, and copies or staging separately where resident. For
planning: one 2048² albedo + normal + ORM set at RGBA8 with a complete mip chain is just
under 64 MiB, so **four such sets exhaust the texture allowance**. Compression may lower
measured allocation but is **not assumed as free headroom**. Larger atlases or extra unique
sets need an explicit budget revision with evidence.

### Phase 1 — the validation pair (A1 + A5)

| Step | What | Check before proceeding |
|---|---|---|
| 1.1 | Author the mouse construction sheet: front, side, **true rear**, ¾, from IMG-12 + IMG-25 + IMG-04, with source-observed and invented features **separately labelled** | Every invented surface is marked as invented |
| 1.2 | Blockout the body in simple volumes — muzzle, ears, tail, feet **before** clothing | Silhouette readable untextured at 70 px |
| 1.3 | Fit the keeper garment; establish ear holes, tail opening, sleeve ends, skirt split | Clothing does not hide species, tool hand or action pose |
| 1.4 | Model A5 spade; define the hand pose **and** the stow location | Both exist; neither is "figure it out later" |
| 1.5 | Apply transforms, finalise topology (triangulate), UV, hard normals | Scale `(1,1,1)`, no negative determinant, triangulated |
| 1.6 | Rig ≤64 bones; define `socket_main/off/head` in the bone map | Socket bones counted against the 64 |
| 1.7 | Author the 16 clips to crowd §3's exact sample counts and impact positions; bake at 30 Hz; strip control bones; in-place, root planar displacement and yaw removed | 609 frames; no clip silently reusing idle |
| 1.8 | Export L0 GLB; generate L1/L2/L3 to 3,500/1,200/350; **normals and tangents after simplification, before palette/VAT validation** | Order not reversed |
| 1.9 | Evaluate the imported rig in Godot model space, or apply the same explicit conversion matrix to Blender vertices **and** bone matrices | Never bake one coordinate system and import the other |
| 1.10 | Generate the skin-matrix palette; store palette dimensions, frame table, bind hash, bone-map hash, vertex counts in a manifest | Hashes computed from real artifacts, **never sample text** |
| 1.11 | **The bake gate**: for every clip at every baked frame, compare crowd-deformed vertices with the conventional reference — **≤2 mm body, ≤5 mm equipment tip**. At half-frames vs interpolated source: **≤10 mm body, ≤20 mm weapon tip at L1** | Fail → resample that clip at 60 Hz or change palette representation and update frame metadata. Do not proceed on a failed bake |
| 1.12 | Build animation AABBs from all deformed mesh and gear vertices; add 0.05 m offline padding | Tail and tool inside the bounds |
| 1.13 | Render the 180/70/24/8 px sheet **and** the 8/40/120 m game-camera set | Species clear at 70 px; tool distinguishable at 24 px if ≥6 px long |
| 1.14 | **Human facing check** against a "face north" fixture | −Z forward, by eye. No script can do this |
| 1.15 | Brendan reviews A1 at 40 m | His verdict, recorded separately from any test result |

**Nothing else is generated until 1.11 and 1.15 both pass.**

### Phase 2 — second species (A2 mole)

Repeat 1.1–1.15 for the mole. Additionally test rig sharing explicitly: crowd §9.2 step 10
requires equal skeleton hierarchy, bone order, bind-space transforms and clip metadata
before a rig is reused, and states that similar-looking species are not proof. If the
mole needs its own rig, that is a finding, not a failure.
Gate: **mole and mouse distinguishable by silhouette at 40 m.**

### Phase 3 — A3 squirrel; A4 otter once the §2.4 proportions are approved

Squirrel repeats the sequence, with the tail-bounds check at 1.12 as the likely failure
point. The otter's reference sheets, blockout drawings and comparison bay are done; its
**bulk production waits on the §2.4 review**, not on a missing number.

### Phase 4 — ground and vegetation (C1, C2, C4)

Runs in parallel with Phase 2–3 because it shares no rig or bake dependency. Order:
C1 ground first (everything else is judged against it), then C2 trees, then C4 dressing.
Validate the **100-tree guaranteed grove** at 40 m and 120 m before authoring a second
tree species. Checks at each step: tile period divides 2 m; no visible repeat at 120 m;
flat at y = 0.5 m; instanced not per-node; decorative plants not confusable with forage.

### Phase 5 — dwelling and workspace (B1, then B2, then B3)

GAP-03 is closed, so this phase is unblocked. B1 first: it is the smallest, has no interior, and already
exists in the starting settlement. Checks: 3×3 tiles exactly; placement passes
REQ-SET-122 with slope ≤8° and height spread ≤0.5 m; the camera obstacle sweep at 8 m
does not shove the orbit; a 1.0 m resident at the work slot looks right at 40 m.
Then B2, then B3 — whose cutaway ownership GAP-06 now specifies, and whose ten named parts
must survive import through `asset_import_validator.gd` rather than `prep_unit.py`.

### Phase 6 — props (D1–D6) and C3 crop states

Props follow the buildings they sit against, so they can be judged in context.
C3's 25 tile appearances are last because they are the largest authoring volume and the
most sensitive to the C1 ground treatment they sit on.

### Phase 7 — the integrated look-development scene

[Visual alignment](visual_direction_alignment.md) names this as the next deliverable:
"a small reference-backed look-development scene: representative residents, a
dwelling/workspace, woodland ground/vegetation, tools/items and the UI together."
Compose it from accepted assets only, at the **real camera** — 40 m default, plus 8 m
and 120 m — under daylight, warm interior and winter, per bible §14.7's three required
review conditions. **Mark any synthetic or placeholder element distinctly.** If real
residents are not yet renderable, say so; do not stage a fake populated colony.

### What is checked at every step, regardless

- Scale `(1,1,1)`, transforms applied, no negative determinant.
- Triangulated before bake.
- Pivot at ground contact (documented exception: D6).
- Axis conversion applied **exactly once**.
- **Facing verified by a human.**
- Provenance written in the same commit as the asset: source image IDs and regions,
  prompt, model, seed where available, credit cost, date and the licence position —
  per [the paid-asset process](../design/paid_asset_process.md) step 4. An asset whose
  provenance is not in the repository is not finished.
- Measured statistics only. Per-LOD triangles, surfaces, bones, texture dimensions and
  pose bounds come from the actual file. **Never an invented sample value.**

## 8. Dependency gaps

Each entry names where it was searched, not merely that it is missing.

**Revision 1.1 status at a glance.** The search records below are kept as written, because
they are the evidence that the gap was real. What follows each is the ruling's answer.

| Gap | Status after the 2026-09-11 ruling |
|---|---|
| GAP-01 | Candidates supplied and a measurement convention specified. **Bulk-production proportion approval OPEN** |
| GAP-02 | Domain confusion resolved — radii are not heights. Candidate supplied. **Proportion approval OPEN** |
| GAP-03 | All 30 exterior maximum-Y envelopes supplied, with proxy and cutaway export rules. **Engine validation open** |
| GAP-04 | Geometry, surface and texture ceilings for every non-creature family, plus whole-scene sub-budgets. **Hardware measurement open** |
| GAP-05 | Settlement L0 admission fully specified. **Runtime implementation and performance open** |
| GAP-06 | Cutaway part hierarchy specified; import validator delivered. **Cap/opening part naming still unnamed** |
| GAP-07 | Settlement foliage rule explicitly adopted, not merely borrowed. **Overdraw measurement open** |
| GAP-08 | Naming convention ratified across all six non-creature kinds |
| GAP-09 | Metallic/roughness PBR baseline and starting values adopted |
| GAP-10 | **Untouched. Windows / minimum-hardware qualification remains unavailable** |

### GAP-01 — Only the mouse's height is sourced · blocks A2, A3 as confirmed values

[Crowd §9.1](../crowd_rendering_architecture.md) states the prototype mouse at
**1.0 m gameplay scale, "fantasy relative scale, not biological meters"**. That is the
only species height in the repository. The asset-pipeline skill assigns mole and squirrel
to the Small tier via IMG-25's category labels, but
[screenshot_review IMG-25](screenshot_review.md#img-25) states those bands are
"squad model counts, not colony populations, hitboxes or height multipliers" and warns
"Do not measure pixels here and call the result canonical meters". DEC-019's own
`remaining_questions` field lists "Exact relative species sizes" as unresolved, and
DEC-038 repeats that the approved image is not a species-size specification.

**Searched:** `game_gdd.md`, `gameplay_balance.md`, `ui_ux_controls.md`,
`crowd_rendering_architecture.md`, `setting_bible.md` §14.1, `systems_architecture.md`,
the asset-pipeline skill, and a grep of the whole `docs/` tree for height, tier and metre
terms. **Only the mouse is stated.**

**To settle:** Brendan rules on whether mole and squirrel share 1.00 m. The cheapest path
is the skill's own advice — two blockouts side by side at 40 m, judged by eye, before
bulk work.

> **Resolved for authoring, revision 1.1.** ART-GAP-R01 supplies mole **922 u** and
> squirrel **1024 u** as comparison candidates, keeps the mouse anchor at 1024 u, and adds
> the measurement convention in §2.4. **Bulk-production proportion acceptance is still
> OPEN**: the §2.4 comparison scene is built and captured, and Brendan has not yet ruled on
> it. It is not accurate to say this ruling alone frees every blocked creature entry.

### GAP-02 — The Medium tier height is unconfirmed and contradicted · blocks A4

The skill's table gives Medium **1.49 m** and marks it "**derived, unconfirmed**", adding
"Only Small is sourced... ratios chosen for readability, confirmed by nothing."
Independently, [crowd §5](../crowd_rendering_architecture.md) gives small/medium/large/
giant collision radii of **184/246/461/922** units, ratios **1 : 1.337 : 2.505 : 5.011**,
against the skill's implied **1 : 1.49 : 2.55**. The two disagree, neither is labelled a
height ratio, and the radius numbers come from the battle document's ground movement
section. **Large 2.55 m is equally unconfirmed; Giant is undefined outright.**

Two of the twelve starting residents are otters ([GDD §5.1](../game_gdd.md)), so this is
not a deferred species — it blocks a sixth of the starting colony.

**Searched:** as GAP-01, plus a grep for the radius-class numbers and for every
occurrence of "Medium"/"Large"/"Giant" in `docs/`.

**To settle:** Brendan rules the otter's height. Either adopt the radius ratio 1.337
(→ 1.34 m), adopt 1.49, or set a number by eye. **Do not pick one silently.**

> **Resolved for authoring, revision 1.1.** ART-GAP-R02 settles the question by separating
> the domains rather than choosing between the two ratio sets: **battle horizontal radii are
> not height ratios**, and no species is normalised by multiplying mouse height by a radius
> ratio. Otter **1526 u** and badger **2611 u** retain the prior comparison scale at integer
> precision and are explicitly **not** elevated into approved tier values. **Proportion
> approval is OPEN**, as for GAP-01.

### GAP-03 — No building height exists · blocks B1, B2 from production; gates B3

[GDD §5.9](../game_gdd.md) specifies `footprint_x/z` and `room_tiles` for every building
and **no Y dimension anywhere**. The nearest thing to a vertical number is
[`ui_ux_controls.md` §6](../ui_ux_controls.md) — "walls on the camera-facing side of a
selected interior hide down to **1 m** height" — which constrains a cut line, not a
building.

Height is not purely aesthetic: the camera's obstacle sweep (ui §6) shortens the orbit
against geometry, so building height changes camera behaviour.

**Searched:** `game_gdd.md` §5.9 and §5.1 in full, `gameplay_balance.md`,
`ui_ux_controls.md`, `systems_architecture.md`, `setting_bible.md` §14, and a grep of
`docs/` for wall height, eave, storey, ceiling height and clearance.

**To settle:** a height convention per building, or a stated rule such as "wall plate at
N × mouse height". Look-development studies may proceed with a **labelled candidate**;
production models may not.

> **Resolved for authoring, revision 1.1.** ART-GAP-R03 supplies a maximum local Y for
> **all 30** BuildingDefinition keys, bound in `lookdev_dimensions.gd` and checked against
> the live catalog by `test_lookdev_dimensions.gd`, so a building added without an envelope
> fails the suite. They supplement and never resize the GDD's 2 m footprint tiles.
>
> Three things these envelopes explicitly do **not** do. They do not set **underground depth**
> — the cellar's 2048 u is its aboveground entrance, and excavated volume stays MOVE-G01/G02
> work. They do not describe **submerged geometry** — the weir's above-base envelope decides
> no water depth. And assigning a positive height authorizes **no belowground geometry at
> all**. Open stockpile's 2560 u is the maximum **filled visual stack**, not an opaque empty
> 8 × 8 × 2.5 m cube; paths are shallow surfaces.
>
> **One arithmetic note that contradicts the millimetre authoring column.** `dirt_path` at
> **64 u is 62.5 mm** and cannot be expressed as an integer millimetre. The 1/1024 m column
> stays authoritative and the millimetre column records 63 as a derived, rounded value.
> `test_dirt_path_is_the_only_envelope_millimetres_cannot_express` asserts that by name, so
> nobody later "fixes" 63 into the authority.

### GAP-04 — No geometry or texture budget exists for anything that is not a creature · affects B, C and D entirely

[Crowd §2.7](../crowd_rendering_architecture.md) gives 12,000/3,500/1,200/350 for
**creature LODs including gear**, and crowd §9.1 gives one 2048² atlas set **per species
family**. Nothing covers buildings, props, terrain, foliage or crops — no triangle
ceiling, no texel density, no draw-call budget, no material count. `systems_architecture.md`
contains no geometry budget at all (grep for triangle, polycount, MultiMesh and foliage
returns nothing). GDD §5.11's budgets are frame time, simulation CPU and memory, not geometry.

In revision 1.0 every non-creature triangle figure in §4–§6 was marked **PROPOSED — NOT
RATIFIED** for exactly this reason. The C3 case was the sharp one: 4096 permitted farm
tiles × 300 triangles is 1.2 M triangles from crops alone. Revision 1.1 replaced those
proposals with the ratified ceilings; C3's ratified near tier of 256 triangles per tile
gives 1,048,576 at all 4096 tiles, so the sharp case did not get less sharp — it got a
number and an explicit instruction to reduce density or LOD rather than exceed it.

**To settle:** an engineering budget pass producing per-category ceilings, derived from
the qualification floor (GTX 1660 Super 6 GB at 1920×1080) rather than by analogy. That
is measured work, not an art decision — bible REQ-LORE-020 is explicit that an art-style
decision is not authorization to change a technical contract.

> **Resolved for authoring, revision 1.1.** ART-GAP-R04 supplies per-family ceilings
> (§4–§6 above), the static near/mid/far admission policy with its hysteresis, crop and
> terrain accounting, the per-container pile budget, and the aggregate 128 MiB mesh /
> 256 MiB texture environment sub-budgets in Phase 0b.
>
> **These are explicit design decisions, not measurements**, and the gap this section
> identified is only half closed. Report **rendered** triangles, draw surfaces, shadow-pass
> multiplication and alpha overdraw in the actual 256-resident scene: **per-asset compliance
> is not a frame-time pass.** Mac evidence establishes nothing on the specified minimum
> Windows GPU, which is GAP-10 and is untouched.

### GAP-05 — L0 is unreachable at the settlement camera, and the 24-actor pool has no admission rule

Crowd §2.7 admits L0 at "**≥180 px and admitted to skeletal pool**".
[GDD §5.11](../game_gdd.md) says "256 residents use at most **24** conventional close-up
skeletal actors" — but does not say what admits them. Applying the crowd document's own
formula to the sourced camera contract (§2.2 above), a 1.0 m resident spans ≈130 px at
the closest legal zoom of 8 m and never reaches 180 px anywhere in the legal range.
Under the screen-space rule alone, **the L0 12,000-triangle tier would never be selected
in the settlement**, and the 24-actor pool would be populated by some other rule that is
not written down.

**Searched:** every occurrence of "180 px" in `docs/` (three hits, all in the crowd
document), plus GDD §5.11, `systems_architecture.md` and `ui_ux_controls.md` §6.

**Consequence for this brief:** authoring an L0 at the 12,000 ceiling may be authoring a
tier the settlement never displays. It is still authored — a portrait, a cinematic or a
future camera change would need it — but the cost is recorded here rather than discovered
later. **To settle:** state the settlement's L0 admission rule, or state that the
settlement's close-actor pool uses L1 geometry.

> **Resolved, revision 1.1.** ART-GAP-R05 overrides crowd §2.7 for the settlement only:
> **nominal 64 render px, pool cap 24**, retaining the existing creature L0 geometry and rig
> ceiling. The full contract, with hysteresis, tie-break, overflow and pause behaviour, is
> in §2.2. Battle is unchanged at 180 px and cap 48.
>
> The 12,000-triangle L0 is therefore reachable: it is selected near the 8 m end of the
> legal orbit, and **correctly selected for nobody at the 40 m default**, where the
> analytical estimate is about 26 px. A pool holding zero skeletal actors at default zoom is
> the contract working. **This closes the admission definition, not performance and not
> exported-rig acceptance**, and verification still requires real captures at real render
> resolution including Retina scaling.

### GAP-06 — Cutaway geometry ownership is unspecified · blocks B3

[`ui_ux_controls.md` §6](../ui_ux_controls.md) specifies the cutaway *behaviour*
completely — roof AUTO / HIDE_SELECTED / SHOW_ALL, camera-facing walls hidden **down to
1 m**, 120 ms alpha-dither fade, collision and navigation unchanged. It does not specify
the *geometry* that makes this possible: submesh split, per-side wall grouping, where the
1 m cut is authored, or what the wall looks like at the cut.
[Bible §14.5](../setting_bible.md) lists this as outstanding under its Blender handoff
row: "Separate earth-cover, entrance, room and cutaway ownership; validate selected
exterior/interior views against the final construction contract."

Compounding it, `prep_unit.py` **joins all objects into one mesh**, so the current
normalisation tool would destroy the split even if it were specified.

**To settle:** a geometry-ownership spec for managed interiors, and either a `--no-join`
path in `prep_unit.py` or an explicit statement that multi-part assets bypass it.

> **Resolved for authoring, revision 1.1.** GAP-06 supplies the part hierarchy (B3's table
> above), states that **multi-part buildings bypass `prep_unit.py`'s join step**, and asks
> for a hierarchy-preserving import validator — delivered as
> [`asset_import_validator.gd`](../../godot/assets/lookdev/asset_import_validator.gd).
> Creature-normalisation scripts are not universal asset processors.
>
> **One piece is still unnamed and is deliberately not invented here.** GAP-06 requires
> "opening/cap geometry" as an addressable part but gives it no name, and GAP-08's part
> clause says only that parts use the hierarchy names above. The validator therefore
> requires the ten named parts, **accepts** further parts and records each as a note.
> Someone must name the cap and opening parts before those notes can mean anything.

### GAP-07 — Settlement vegetation has no rendering rule of its own

The only foliage rule in the repository is in
[crowd §2](../crowd_rendering_architecture.md): "Foliage uses opaque trunks and
alpha-scissor leaves, at most two overlapping leaf layers along the principal tactical
view **in the fixture**" — stated for the battle-layer test fixture, alongside battle VFX
ceilings and corpse limits. Adopting it for the settlement is defensible and is what §5's
C2 entry does, but it is an **adoption, not a citation**.

**Searched:** `game_gdd.md`, `systems_architecture.md`, `ui_ux_controls.md`,
`gameplay_balance.md` and a grep of `docs/` for grass, foliage, shrub, fern and
vegetation. The only hit outside the crowd document is a passing mention of reading
counters over foliage in `ui_ux_controls.md` §2.

> **Resolved, revision 1.1.** GAP-07 **explicitly adopts** opaque trunks and alpha-scissor
> foliage for settlement art, so C2's rule is now a citation rather than an adoption by
> analogy. At most two overlapping leaf-card layers along the principal **48°** gameplay
> view **in the single-tree fixture** — and that is a fixture limit, not a scene-wide
> guarantee. Check 35° and 65° and the 100-tree grove for real overlap and overdraw. No full
> alpha-blended fallback; share geometry and material batches.

### GAP-08 — No naming convention for non-creature assets

Crowd §9.1 gives `species_mouse_body_a_lod1`, `rig_mouse_v1`, `clip_attack_a`,
`socket_main`. There is no equivalent for buildings, furniture, props, vegetation or
terrain materials. The skill's directory layout (`godot/assets/units/`,
`godot/assets/buildings/`) implies structure but names no file convention.

Revision 1.0 deliberately **did not invent one** and offered a pattern as a proposal.

> **Resolved, revision 1.1.** GAP-08 ratifies almost exactly that proposal; §2.1 carries the
> six patterns. `n` is 0/1/2 for the static near/mid/far tiers, variants begin a, b, c, and
> names are ASCII. **An art semantic key is not a new gameplay catalog entry**, manifests
> declare any real catalog binding separately, and **a live catalog key is never renamed to
> accommodate a filename.** `asset_import_validator.gd` checks names against the live
> catalog, so renaming a `BuildingDefinition` key without renaming its assets fails the
> suite. Asset filenames in this brief are now committed names.

### GAP-09 — No world shader or material model is decided

DEC-037's own text states it "does not settle a new renderer, world shader, species-size
ratio or asset budget", and [visual alignment](visual_direction_alignment.md) repeats that
UI illustration parameters do not govern 3D world rendering. Whether the approved look is
reached with standard PBR, a stylised lighting model, or a custom fur-silhouette shading
term is open. That decision changes what the textures in every family above have to contain.

**Consequence:** the material studies in §3–§6 are authored against *observable material
behaviour* (matte linen, worn leather edges, subdued iron highlights, matte stone mass),
not against shader parameters.

> **Resolved for authoring, revision 1.1.** GAP-09 adopts standard metallic/roughness PBR
> with a shared ORM packing and five starting roughness values; the contract is in
> Phase 0b, and the values are bound as integer permille in `lookdev_dimensions.gd` so the
> table cannot drift by rounding. They are **look-development starting values, not physical
> measurements.** The crowd deformation shader samples the same PBR inputs, so **no
> replacement toon or fur lighting pipeline is implicitly approved**, and renderer, AA and
> GI defaults are not altered to flatter a render.
>
> Revision 1.0's claim that "no roughness or metallic values appear anywhere in this brief"
> was true of revision 1.0 and is no longer true; the values live in Phase 0b.

### GAP-10 — Windows / minimum-hardware qualification is unavailable

[The model guide](model_reference_guide.md) §8 and the crowd document both gate further
species on a Windows P3/P4 pass, and record that the qualification machine is not
currently available. Nothing in this brief can be signed off as performance-qualified.
Treat every budget above as an acceptance target, never as a measurement.

## 9. Paid-generation proposal — **NOT APPROVED, NOT CALLED**

Following [the paid-asset process](../design/paid_asset_process.md). **No tool that
spends credits has been called, and none will be from this brief.** The process is
explicit that a subagent can never call one, because subagents run unattended and cannot
obtain consent. This document was produced unattended. The decision is Brendan's.

### Step 1 — tool fit

| Family | 2D or 3D? | Geometric or illustrative? | Reference already on disk? | Conclusion |
|---|---|---|---|---|
| A residents | 3D | Illustrative/organic | Yes — IMG-08/12/18/25/07 + approved image | **Meshy image-to-3D is a candidate**, conditioned on supplied references under DEC-036 |
| A5 tool | 3D | Geometric | Yes | **Blender by hand.** A spade is a handful of primitives; generation adds cost and cleanup |
| B buildings | 3D | Geometric, footprint-exact | Approved image + IMG-04/12 | **Blender by hand.** Generation cannot hit an exact 3×3-tile footprint or a separable roof submesh |
| C1 ground | 2D textures | Tiling, seam-exact | No | **Authored.** Generation cannot produce a seamless tile at an exact period |
| C2/C4 flora | 3D | Organic | No | Blender by hand or a free library; generation is a weak fit for alpha-card foliage |
| C3 crops | 3D | Modular, tile-exact | No | **Blender by hand** — modularity is the whole requirement |
| D props | 3D | Mostly geometric | Approved image + IMG-03/04/05 | **Blender by hand**, except possibly D1's woven basket |

**Explicitly not needed, and therefore not paid for:** Meshy text-to-3D (references
exist, so image-to-3D dominates); Meshy retexture, remesh, rig and animate (the project
rig contract is ≤64 bones with a fixed manifest and 16 named clips at exact sample counts
— a generic auto-rig cannot satisfy it); Meshy 8K textures (the atlas contract is 2048²);
`meshy_creative_lab`; all Blender MCP generation bridges (Hyper3D / Hunyuan3D); all 2D
image generation. Blender's own modelling and its free PolyHaven / Poly.pizza / Sketchfab
fetches cost nothing.

### Step 2 — specifications that must be extracted first

These raise output quality more than budget does. Revision 1.0 listed four as open;
**revision 1.1 can now supply all four**:

| Parameter | Value available as of revision 1.1 |
|---|---|
| Target height (GAP-01/02) | The §2.4 candidates — **but they are candidates, and generating to an unapproved height is exactly the re-export this brief exists to avoid** |
| `target_polycount` (GAP-04) | Creature L0 12,000 including gear; the non-creature families in §4–§6 |
| Naming (GAP-08) | §2.1's six ratified patterns |
| Material model (GAP-09) | Phase 0b's metallic/roughness baseline |

**The blocking condition has therefore moved, not disappeared.** It is no longer "the
generator would invent these numbers"; it is "**the proportions have not been approved**",
which is §2.4's review and Brendan's alone. The reference derivation boundary is settled:
DEC-036 authorizes direct use of supplied material, so no further permission question exists.

### Step 3 — the itemised request, for Brendan's decision

Costs are the published rates in the asset-pipeline skill and the Meshy tool table.
**Unit prices should be re-verified against the live tool before any approval**, per §7
of the handoff — the earlier nano-banana-pro proposal is explicitly not approved and
pricing may have moved.

| # | Item | Tool / model | Unit | Qty | Line |
|---|---|---|---:|---:|---:|
| 1 | Mouse keeper base mesh, silhouette probe | `meshy_image_to_3d`, meshy-5, mesh only | 5 | 1 | 5 |
| 2 | Mole worker base mesh, silhouette probe | `meshy_image_to_3d`, meshy-5, mesh only | 5 | 1 | 5 |
| | **Floor — decides the pipeline question and nothing else** | | | | **10** |
| 3 | Mouse keeper production mesh + texture | `meshy_image_to_3d`, meshy-6, + texture | 30 | 1 | 30 |
| 4 | Mole worker production mesh + texture | `meshy_image_to_3d`, meshy-6, + texture | 30 | 1 | 30 |
| | **Production pair subtotal** | | | | **60** |
| 5 | Iteration reserve (one re-roll of either) | meshy-6, + texture | 30 | 1 | 30 |
| | **Ceiling** | | | | **100** |

**What each tier buys.** The 10-credit floor answers one question: does image-to-3D from
a supplied reference produce a base mesh worth retopologising, or is hand modelling
faster? That is a real question — the existing 8,307-triangle test mesh came out
untextured, unrigged and as a single unnamed `output_unwrapped` object.
The 60-credit tier produces the Phase 1 and Phase 2 pair as production inputs.
The 100-credit ceiling adds one re-roll.

**Items 3–5 are contingent on the §2.4 proportion review passing**, because the
normalisation height is a generation-time parameter and not a post-hoc fix. `target_polycount`
is no longer a blocker; the approved height is.

**Nothing in revision 1.1 was generated or paid for.** The §2.4 comparison scene is
hand-authored blockout geometry built by a committed script, which is why it could be
produced unattended at all. If a reviewer decides the comparison needs generated art rather
than blockouts — a judgement this document cannot make for him — the itemised request above
is the one to approve, and it must be approved by Brendan in session.

**If declined:** nothing stops. Every asset in this brief is reachable by hand modelling
in Blender; the consequence is schedule, not capability. What stays OPEN is the specific
question of whether Meshy image-to-3D is useful for this project's organic assets — it
remains unanswered rather than answered negatively.

### Steps 4–5

Provenance lands in the same commit as any asset, in the owning manifest, with prompt,
model, seed where available, credit cost, date and licence position. Generated art is
**source material**, not a shipped asset: retopologised, re-UV'd, re-textured, exported
at the real contract. And having paid for a mesh does not make it good — the visual
verdict is Brendan's, recorded separately from any test result, and a miss keeps the
check OPEN.

## 10. Status summary — revision 1.1

| Family | Entries | Authoring-ready | Comparison brief only |
|---|---:|---|---|
| A — residents | 5 | A1 mouse, A5 tool | **A2 mole, A3 squirrel, A4 otter** — candidates and a measurement convention exist; proportion approval does not |
| B — dwelling/workspace | 3 | B1, B2 (GAP-03 envelopes, GAP-04 ceilings), B3 (GAP-06 cutaway hierarchy) | none |
| C — ground/vegetation | 4 | C1, C2, C3, C4 | none |
| D — props | 6 | D1, D2, D3, D4, D5, D6 | none |

**Fifteen of eighteen are authoring-ready. Three are not.** Six of the nine entries
revision 1.0 blocked now have authoring answers; the three creature entries have concrete
comparison briefs and still need proportion approval. **Do not call all nine
production-ready** — the ruling says so in terms, and "authoring-ready" is a statement about
contracts, not about exported meshes or measured frames.

### What still gates work, in the order it bites

1. **The §2.4 proportion review.** Brendan looks at
   `godot/assets/lookdev/captures/` and rules on the five candidate heights. Until then no
   bulk creature generation starts, and A2/A3/A4 stay where they are.
2. **Facing, by eye.** No script can see it. Every creature acceptance set carries the
   check, and §2.4's yaw 45°/225° pair is the first instance of it.
3. **GAP-06's unnamed cap and opening parts.** Named as a blocker rather than invented.
4. **GAP-10 — Windows / minimum-hardware qualification.** Untouched by the ruling. Every
   budget here is an acceptance target, never a measurement, and Mac evidence establishes
   nothing about the specified minimum GPU.
5. **Engine evidence generally.** Exported meshes, the camera obstacle sweep, rendered
   triangle and overdraw counts in the real 256-resident scene, and the L0 admission
   implementation are all outstanding. **A specification decision is not completed runtime
   work**, and nothing in revision 1.1 claims otherwise.

Recorded as [decision 0079](../decisions/0079-world-art-lookdev-blocks-families-rather-than-inventing-dimensions.md)
for revision 1.0, and
[decision 0082](../decisions/0082-lookdev-dimensions-are-bound-and-the-comparison-scene-is-built.md)
for revision 1.1.
