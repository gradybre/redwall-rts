# Settlement asset dimensions, budgets and close-actor admission

2026-09-11 · ART-GAP-R01–05 · Astra authoring/engineering package.
New budgets and vertical envelopes below are explicit design decisions, not
measurements. Species-height candidates remain subject to decision 0002's
user-required proportion review. DEC-038 approved the visual look, not new meters.

## GAP-01/02 — Separate anatomical height, movement radius and animated bounds

The mouse anchor remains 1024 units = 1.0 m. Use integer units (1024/m) in
metadata, converting to float only for import/presentation. The legacy medium
1.49 m / large 2.55 m numbers are comparison candidates, not production ratios.
Crowd §5's radii 184/246/461/922 are horizontal battle locomotion/separation
inputs, not heights: dividing them by 184 cannot specify animal stature.
Do not normalize a species by multiplying mouse height by its radius ratio.

New explicit measurement convention for comparison sheets: neutral standing,
bare adult body; supporting soles on Y=0; height to the highest anatomical head/
ear point in its neutral pose. Exclude raised tail, equipment, headwear and
animation extremes. Record crown/eye/shoulder heights and separate full animated
AABB, carried/stowed equipment bounds and locomotion envelope. A squirrel's tail
must not shrink its torso when imported. Nonstanding species need their own
length/wingspan/contact conventions before production.

| Species | Comparison height units | Approximate meters | Status |
| --- | ---: | ---: | --- |
| mouse | 1024 | 1.000000 | Inherited 1.0 m anchor; measurement convention newly specified |
| mole | 922 | 0.900391 | Authored comparison candidate; not bulk-production approval |
| squirrel | 1024 | 1.000000 | Authored comparison candidate; not bulk-production approval |
| otter | 1526 | 1.490234 | Authored comparison candidate; not bulk-production approval |
| badger | 2611 | 2.549805 | Authored comparison candidate; not bulk-production approval |

The otter and badger entries retain the prior 1.49/2.55 m candidates to integer
precision; they do not elevate them into approved tier values. Mole/squirrel
candidates now make single comparison assets and rig/pose studies concrete.
Species anatomy and the approved courtyard look remain the visual guides.

Decision 0002 explicitly requires mouse/hare-or-otter/badger beside the SAME
door, table and workbench, standing/walking/carrying/crouching, close and at the
RTS camera, before bulk proportions are approved. Produce that review rather
than inventing user approval. Include mole and squirrel to resolve their new
candidates. Giant residents remain excluded. These candidate heights do NOT
set navigation clearance, service reach, step height or movement capability.

The current prep_unit.py scales the joined whole mesh AABB, including attachments.
It is insufficient to verify this anatomical convention. Executor must separate
the reference body or use validated landmark metadata for normalization, apply
the SAME transform to all attachments, and validate full animated bounds. Do not
run a squirrel through whole-tail-height scaling or silently modify existing
source assets. Keep axes −Z forward, +Y up, foot-origin and rig contracts.

Status: domain confusion resolved; comparison authoring unblocked. GAP-01/02
production proportion acceptance is OPEN pending the specified visual review.
It is not accurate to say this package alone frees every blocked creature.

## GAP-03 — Complete exterior vertical envelopes

These are NEW maximum visual heights above each building's placed ground datum,
covering shell, roof, fixed chimney and signs. They supplement, never resize,
the existing GDD 2 m footprint tiles. Rotation affects X/Z only. Local Y=0 is
the placed base. Terrain flattening/contact still follows placement rules.

| BuildingDefinition key | Max local Y, units | Meters |
| --- | ---: | ---: |
| apiary | 2048 | 2 |
| boathouse | 5120 | 5 |
| brewery | 5120 | 5 |
| cellar | 2048 | 2 |
| composter | 1280 | 1.25 |
| covered_store | 5120 | 5 |
| dirt_path | 64 | 0.0625 |
| dryer | 3072 | 3 |
| fence | 1536 | 1.5 |
| fisher_shelter | 3584 | 3.5 |
| forester_lodge | 4608 | 4.5 |
| gate | 3584 | 3.5 |
| hall | 7168 | 7 |
| infirmary | 5632 | 5.5 |
| kitchen | 5120 | 5 |
| lookout | 8192 | 8 |
| memorial_garden | 2048 | 2 |
| mill | 7168 | 7 |
| nursery | 3072 | 3 |
| open_stockpile | 2560 | 2.5 |
| paved_path | 128 | 0.125 |
| preserver | 5120 | 5 |
| quarry_shed | 4096 | 4 |
| residence | 6144 | 6 |
| saltpan | 512 | 0.5 |
| stone_wall | 2560 | 2.5 |
| weir | 1536 | 1.5 |
| well | 3072 | 3 |
| workbench | 3584 | 3.5 |
| workshop | 5120 | 5 |

Shared enclosed surface-building authoring values: 3072 units (3 m) minimum clear
internal height; ordinary common-access door opening 1536 wide × 3072 high.
These are NEW model-brief dimensions, not proof that every future body/gear
profile passes the opening. Header/roof rise fits within the table's envelope.
The numeric doorway brief is usable for the scale comparison; the movement
profile must independently qualify actual clearances. Tables/work surfaces in
that comparison use 640-unit top height as an explicit candidate, not a universal
work-contact policy for every species. Adjustable/role-specific furnishings
remain possible under later approved sheets.

Open stockpile height is the maximum filled visual stack, not an opaque empty
8×8×2.5 m cube. Paths are shallow surfaces. Cellar's value is its aboveground
entrance; underground depth, floors and excavated volume remain MOVE-G01/G02
work. Weir's above-base envelope does not determine water depth or submerged
geometry. No belowground geometry is authorized by assigning a positive height.

Each delivered asset MUST declare measured local min/max bounds, structural
camera-obstacle proxy pieces and pivots. The table bounds the asset; the actual
proxy describes the current structure. Static roof/wall proxies must enclose
their opaque surfaces, retain real openings, and rotate with the building.
Do not treat an entire footprint as solid where no geometry exists, use mesh
height=0 as a fallback, or derive camera obstacles from resident navigation radii.
Stage-specific blueprint/unfinished/complete visuals expose corresponding proxy
geometry. Hidden cutaway parts follow the selected view's camera-occlusion policy,
without changing authoritative room occupancy or access.

The existing 0.5 m camera sphere sweep remains view-only. It reads these verified
proxies plus actual terrain; it does not decide navigation or simulation collision.
Validate actual eaves, ridges, doorway approaches, rotation, inside/outside views
and slope placement in engine. A maximum-Y table unblocks building briefs; it
does not certify a mesh or complete the camera sweep implementation.

## GAP-04 — Non-creature production ceilings

NEW per-asset ceilings, counted after triangulation and including attached
decorative mesh parts assigned to that asset. Near/mid/far are static geometry
tiers, not creature animation L0–L3. Separately instanced furniture/props are
charged separately once; they cannot disappear from the whole-scene accounting.

| Asset family | Near triangles | Mid | Far | Max surfaces | Max individual texture edge |
| --- | ---: | ---: | ---: | ---: | ---: |
| Building assembly | 32000 | 10000 | 2500 | 16 | 2048 |
| Furniture instance | 2000 | 700 | 180 | 2 | 1024 |
| Tool / resource / small prop | 1200 | 400 | 100 | 1 | 1024 |
| Tree / large vegetation | 6000 | 2000 | 500 | 2 | 2048 |
| Ground cover cluster | 600 | 180 | 40 | 1 | 1024 |

NEW static-asset admission policy: initially near at projected maximum AABB
extent ≥180 render-target pixels, mid at ≥48, far below. Reuse the creature
algorithm with10% hysteresis and0.20s residence: far→mid at52.8px, mid→far
below43.2px; mid→near at198px, near→mid below162px. These static thresholds and
their application to buildings/props are new, not inherited crowd requirements. Large structures
may naturally remain near at normal zoom. Do not force all instances to near
because the asset has a near mesh. Exact vertex/material/draw cost still needs
measurement. No new terrain tessellation algorithm is prescribed by this table;
terrain remains independently measured in the full scene.

Buildings use at most4 distinct shared materials. To preserve the required
independent roof/wall/cap parts, the assembly allows at most16 draw surfaces at
near/mid and4 at far; the table reports the largest of those caps. Material count
is not draw-surface count: repeated material slots on different parts still cost
draw surfaces. Include visible cut caps/opening geometry within both triangle
and surface limits. A far representation must still honor selected cutaway
visibility (roof/upper/lower-cap grouping); do not fuse it into an unhideable shell.
This explicitly reconciles multipart cutaways with rendering budgets.

A small asset may use a tile within a shared 2048 atlas rather than its own
1024 texture. Shared atlas edge≤2048. Authoring source can be larger; imported
runtime textures obey these ceilings. Use shared timber/stone/cloth/metal
materials and per-instance variation; no material or full texture set per
resident, plank or bed. Normal/ORM are linear data, albedo follows its import
color-space convention. Alpha-cutout foliage must be measured for overdraw;
no blended strand-fur/leaf-card escalation to hide weak silhouettes.

NEW aggregate non-creature allocations: ≤128 MiB loaded non-creature meshes
across all LODs, ≤256 MiB loaded non-creature material textures INCLUDING mips
and all loaded variants. These separate environment sub-budgets are charged
ALONGSIDE the existing creature/crowd allocations within the2.5GiB total ceiling.
Charge shared resources once, copies/staging separately where resident. For
conservative planning, one 2048² albedo+normal+ORM set at RGBA8 with a complete mip
chain consumes just under 64 MiB; four such sets exhaust the texture allowance.
Compression can lower measured allocation but is not assumed as free headroom.
Larger atlases/extra unique sets require an explicit budget revision and evidence.

These are sub-budgets INSIDE the existing 2.5 GiB total loaded graphics ceiling
and 4 GiB process target, not additions to those ceilings and not simulation
memory. The 100 MB simulation requirement remains separate. Existing creature
geometry/rig/atlas and crowd allocations remain unchanged. Report rendered
triangles, surfaces, shadow-pass multiplication and alpha overdraw in the actual
256-resident scene; per-asset compliance is not a frame-time pass. Mac evidence
does not establish qualification on the specified minimum Windows GPU.

### Crop, terrain and repeated-pile accounting (C1/C3/D3)

NEW crop-module ceilings per 2 m tile: near256 / mid96 / far16 triangles,
one material surface, shared crop/state texture set (max2048 atlas). At all
4096 tiles, worst all-near geometry is1048576 triangles; all-mid393216; all-far65536.
These are counts, not measured GPU times. Bind EMPTY/SOWN/GROWING/RIPE/WITHERED
and the five crops to real state; neighboring geometry may batch but cannot
remove tile/state identity. Reduce density/LOD when needed; never exceed the
ceiling by instancing a full plant budget once per stalk.

Terrain C1: shared LOAM/CLAY/SAND albedo/normal/ORM textures, source period4m at
1024 pixels (256 texels/m), repeatable world-space phase from world origin;
blend masks follow actual terrain data and do not imply fertility changes.
A flat 2 m tile needs two triangles; a16×16 exterior-tile chunk initially has
512 surface triangles. Shore-height transition geometry must be counted separately
and checked against the actual generator. No tessellation/displacement changes
collision or navigation. General structure tiling target128 texels/m, furniture/
props256 texels/m; ±25% within a family unless a documented focal detail uses a
separate budgeted region. These are authoring targets, not display-pixel promises.

D3 needs a correction BEFORE modeling: an 8×8m open-stockpile building with its
400000g main container is not sixteen independent400000g ground piles. The N/E/S/W
spill rule belongs to ground-pile placement, not automatic per-tile stockpile
capacity expansion. Bind visuals to each actual container, with no invented lots.
Per-container pile assembly ceiling1200/400/100 triangles, one material; if an
8×8m container uses sixteen decorative submodules, their SUM stays within that
ceiling. Empty=empty; nonempty fill variants at occupied mass≤1/3,≤2/3,>2/3 of
actual capacity. Quality/age/reservation do not duplicate visible quantity.
Use stable dominant item-category styling; exact quantities remain in the UI.

### Adjacent art gaps exposed by the same brief: GAP-06/07/08/09

These are explicit authoring decisions so independent assets do not remain blocked
behind a filename or an undefined material model:

- GAP-06: managed building parts are separately addressable `roof`, four
  `wall_<n/e/s/w>_upper` sections above the inherited1m cut, corresponding lower
  wall sections, interior floor, and opening/cap geometry. Closed roof/upper walls
  and selected cutaway variants share the same base transform and actual bounds.
  Render caps at the cut to avoid hollow wall shells. Use the UI's existing fade,
  visibility and collision/navigation rules. Multi-part buildings bypass the
  destructive join step in prep_unit.py: provide a hierarchy-preserving import
  validator. Creature-normalization scripts are not universal asset processors.
- GAP-07: explicitly adopt opaque trunks and alpha-scissor foliage for settlement
  art, with at most two overlapping leaf-card layers along the principal48°
  gameplay view in the single-tree fixture. Check35°/65° and the100-tree grove
  for real overlap/overdraw; two layers per tree is not a scene-wide guarantee.
  No full alpha-blended foliage fallback. Share geometry/material batches.
- GAP-08: ASCII names `building_<BuildingDefinition_key>_<variant>_lod<n>`,
  `furniture_<FurnitureDefinition_key>_<variant>_lod<n>`,
  `prop_<semantic_key>_<variant>_lod<n>`, `flora_<semantic_key>_<state>_lod<n>`,
  `crop_<CropDefinition_key>_<state>_lod<n>`, `terrain_<soil_key>_<variant>`.
  n=0/1/2 for these static near/mid/far tiers. Art semantic keys are not new
  gameplay catalog entries; manifests declare any real catalog binding separately.
  Parts use the hierarchy names above. Variants begin a,b,c; never rename live
  catalog keys to accommodate an asset filename.
- GAP-09: standard metallic/roughness PBR is the material authoring baseline,
  using opaque materials except declared foliage/cutaway effects. Shared ORM
  stores occlusion R, roughness G, metallic B. Nonmetal cloth/wood/stone/fur have
  metallic0; clean exposed metal regions1, grime/rust remain nonmetal. Starting
  roughness targets: linen0.9, dry timber0.8, stone0.85, leather0.65, forged iron0.5;
  authored spatial variation remains allowed and must match the approved look.
  These are look-development starting values, not physical measurements. The
  crowd deformation shader samples the same PBR inputs; no replacement toon/fur
  lighting pipeline is implicitly approved. Do not alter renderer/AA/GI defaults
  merely to make a beauty render. API background: [Godot material documentation](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html),
  consulted2026-09-11. This source supports the material options, not our budgets.

### Executor's nine blocked entries

| Entry | Ruling outcome |
| --- | --- |
| A2 mole / A3 squirrel / A4 otter | Exact comparison candidates provided; bulk-production proportion approval still open |
| B1 workbench / B2 kitchen | Footprints inherited, vertical envelope and static-asset ceilings now defined |
| B3 residence | Height/budgets plus separable cutaway ownership now defined; engine evidence still required |
| C3 crops | Tile/state geometry and full4096-tile arithmetic now explicit; GPU qualification open |
| D3 stockpile | Per-container visual budget and capacity distinction explicit |
| D5 interior prop | Residence cutaway dependency now has an authoring contract; contact/runtime validation remains |

## GAP-05 — Explicit settlement skeletal admission

NEW settlement-specific override to crowd §2.7: nominal L0 admission threshold
is **64 render-target pixels**, pool cap **24**, retaining the existing creature
L0 geometry/rig ceiling. This applies to the settlement scene only; the battle
threshold remains 180 and its cap remains 48. The cap is not a target occupancy.

Use the actual projected animated AABB maximum extent, not UI logical pixels,
monitor pixels or a standing-height estimate. Initially admit if extent≥64;
thereafter promote at ≥70.4 and demote below57.6, with 0.20 s residence. Near-plane
crossing may immediately request the highest representation but never bypasses
the 24-actor cap. Rank eligible visible residents by projected extent descending,
camera-space depth ascending, persistent ID ascending. No selection or name
bypass: focusing someone alone does not force a tiny character into L0.

Admitted residents use the pooled skeletal representation. Eligible overflow uses
L1, as in the inherited overflow contract. Noneligible residents use ordinary
L1/L2/L3 pixel thresholds. Transition all attachments atomically; return actors
to the pool on loss of eligibility and reconstruct current presentation pose
without touching simulation. Pause freezes animation evaluation as before.

The user's ~26px default-zoom example is correctly below admission; a pool with
zero skeletal actors can be correct there. A diameter1m sphere at depth40m and
1080px/FOV55 gives about25.93px, at depth8m about129.67px. These are analytical
sphere estimates only; a tilted biped's projected AABB differs. The existing
8–120m camera range can therefore support close inspection without automatically
moving the camera, changing scale or lowering the threshold to default-zoom size.

Verify threshold/hysteresis boundaries, 24/25 candidates, stable ties, pool reuse,
near-plane overflow, pose/equipment continuity, pause and unchanged authoritative
hashes at equal ticks. Record actual normal/max-zoom captures at real render
resolution, including Retina scaling. This closes the admission definition, not
performance or exported-rig acceptance.

## Next execution and honest closure

First bind these model-brief metadata and asset ceilings, prepare the single
proportion comparison, and implement camera proxies/skeletal admission against
existing runtime interfaces. No paid generation or bulk creature proportion
approval is implied. Preserve the approved grounded visual style and supplied
reference permission. The executor brief is now [docs/art-reference/world_art_lookdev_brief.md](../art-reference/world_art_lookdev_brief.md) (SET-ART-LOOKDEV-001); its originating temporary worktree has been removed. Its explicit blocked rows total nine: A2/A3/A4, B1/B2/B3, C3, D3/D5, despite its introductory claim of six. Use the entry mapping above; distinguish authoring readiness from production qualification.
