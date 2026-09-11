# Direct-reference guide for 3D bodies, clothing, equipment and environments

Document `SET-ART-MODEL-001`, revision 1.0, 2026-09-06. Status: actionable reference and proposed modeling handoff. Brendan explicitly authorized using these screenshots as direct modeling references. No mesh, rig, texture, animation or engine feature was created in this review.

## Reference-use clarification — DEC-036

Use the supplied images directly, including as image-to-image/image-to-3D inputs
and for drawing/tracing/adaptation. Written descriptions supplement the image;
they are not the only permitted input. Preserve source IDs/regions and the separate
spending approval. Unknown attribution remains recorded, not a new use blocker.

## 1. The direction these images support

Use **expressive animal bodies, practical layered clothing and materially convincing woodland spaces**. Preserve the warm domestic illustrations as strongly as the military portraits. A keeper, cook or fisher must have as much visual specificity as a champion. IMG-03/04/18 supply ordinary life; IMG-12/26 supply mouse action; IMG-08/09/10 supply movement requirements; IMG-25 supplies comparative species silhouettes.

The folder contains multiple visual languages. IMG-01/06/08/14 use clean, detailed concept-character presentation; IMG-03/04 have soft domestic illustration; IMG-12/17/26 use dramatic narrative composition; IMG-25 is a line-art lineup. We should combine selected features through one authored model sheet. Do not average all faces, reproduce every accessory, or alternate entire rendering styles by faction.

| Priority | Keep from the reference | Resolve in the model |
|---|---|---|
| 1: species | Muzzle/beak, ear shape, body mass, paws/feet/wings, tail | Distinct three-dimensional silhouette in front, side and rear |
| 2: movement | Crouch, stride, reach, tail arc, body orientation | Working contact poses and equipment clearance |
| 3: occupation | Apron, tool, basket, quiver, standard, fishing gear | Modular equipment, hand use and stow position |
| 4: culture/person | Garment cut, cloth pattern, repaired materials, emblems | Scenario-specific clothing and original personal variants |
| 5: finish | Fur grouping, seams, metal wear, paint texture | Detail that survives the existing LOD and atlas contracts |

This priority is an authored production rule, not a measured percentage blend. It implements DEC-018/019's existing intent. Species anatomy must not encode morality. A rat worker can use the same practical wardrobe principles as a mouse worker.

## 2. Direct-reference assignments

All IMG IDs resolve through `screenshot_review.md` and `reference_manifest.json`. Body, costume and action references are deliberately assigned independently. An image used for a cape does not determine species or biography.

| Asset family / application | Primary source | Supporting sources | Preserve directly | Deliberate adaptation / missing view |
|---|---|---|---|---|
| Mouse base body | IMG-12 mouse; IMG-25 mouse | IMG-26 upper; IMG-02 scout | Round ears, forward muzzle, broad small paws, short readable torso, clear tail attachment | Neutral standing body and rear view are new drawings; use 1.0 m mouse anchor |
| Rowan / keeper clothing | IMG-03/04 working garments | IMG-05 provisions; IMG-12 cloth construction | Apron/belt/tool relationships, usable pockets, sleeves clearing hands | Original keeper outfit; no copied champion identity, sword or unconfirmed biography |
| Mole worker | IMG-08 body/tool | IMG-25 mole; IMG-03 cooks | Rounded compact mass, projecting nose, broad digging hands, heavy tool silhouette | Ungloved hand structure and rear anatomy need drawings; elaborate lantern rig is optional |
| Squirrel | IMG-09 pose/body | IMG-07 costume; IMG-25 squirrel; IMG-04 ladder | Pelvis-rooted plume tail, ear tufts where selected, crouch/reach, short flexible outfit | Tail volume must work in crawl/turn/climb; no permanent tartan or northern ancestry |
| Otter | IMG-18 body | IMG-20 archer; IMG-17 community; IMG-19 hero | Long torso, pale throat, compact ears, broad muzzle, thick tapering tail | Back/underside and stroke drawings required; no automatic armor compatibility |
| Hare | IMG-01 standing; IMG-27 motion | IMG-22 hooded alternative; IMG-25 hare | Long ears, long hind limbs, broad feet, narrow upright trunk | One common body beneath three garment styles; formal officer coat is a variant |
| Badger | IMG-25 body | IMG-02/28 protective group; IMG-27 face/armor | Broad shoulders, distinctive facial stripes, substantial paws, weight-bearing stance | Group perspective does not supply a height ratio; full neutral side/rear required |
| Rat | IMG-13 head/clothing | IMG-14 load pose; IMG-25 rat | Long muzzle, ears, tail, torso under practical cloth | Hooked tail accessory is excluded from default body; no permanent sinister expression |
| Shrew / vole / hedgehog | IMG-25 labeled silhouettes | IMG-03/04/11 where species is clear | Distinct muzzle/ear/quill/body combinations | Small illustrations are inadequate for detailed production heads and paws; author explicit sheets |
| Stoat / ferret / weasel / marten / fox | IMG-25 labeled lineup | IMG-15 marten face; IMG-16 equipment | Family-specific proportions and facial markings, not identical recolors | Avoid assigning unnamed IMG-16 fighter a species; exact size/rig compatibility unresolved |
| Toad | IMG-06 | IMG-25 text classification only | Broad head, raised eyes, squat body, splayed feet and layered gear | Swimming stroke, hands and back need explicit anatomy; no species-wide villain traits |
| Birds | IMG-02/28 kestrel; IMG-24 owl | IMG-12 bird group | Beak/face disk where appropriate, wing feather masses, talons, folded-wing silhouette | Separate bird rig and per-species scale; no humanoid arm substitution or default flight |
| Fish / aquatic encounter body | IMG-10 pike | IMG-18/20 fish props | Fish body taper, fins, gill/head masses, lateral movement silhouette | Food prop, ecological stock and simulated character are three distinct representations |
| Kitchens / shared rooms | IMG-03/04 | IMG-05/18 | Practical hearth, cookware, baskets, stored produce, occupied furniture | Fit the actual hall layout and resident clearance; do not infer new rooms from a vignette |
| Water access / vessels | IMG-17/23 | IMG-13/20 | Lashings, timber, boarding edges, wet surfaces, handholds | No measured plans supplied; boat physics and mobile interiors remain separate |

## 3. How to build from a screenshot

1. Open the original PNG at native resolution. Locate its IMG record and region window. Read the extraction note as well as the art.
2. Select a body reference, one costume reference and one relevant action reference from §2. Record their IDs and accepted features before building.
3. Draw a neutral front, side and rear construction sheet. Keep source-observed features and newly authored hidden geometry visibly labeled. A mirrored painted three-quarter view is not a true rear view.
4. Block the whole body with simple volumes. Include muzzle, ears, tail and feet before clothing. Use the inherited mouse anchor; leave other species dimensions as explicit authored candidates until a common lineup resolves them.
5. Check silhouette in neutral, walk, carry and the relevant traversal pose. Do this with an untextured body so a painted fur patch cannot hide incorrect anatomy.
6. Fit clothing around the body. Establish ear holes, tail openings, sleeve ends, skirt splits, fasteners and pack straps. Every carried tool must have a hand pose or a stowed location.
7. Review the source beside the blockout and record each intentional change: shorter cape for climbing, folded lantern for tunnels, simplified medals for distant viewing, or original rear seams. Do not mark source divergence as accidental faithfulness.
8. Finish topology, rig and materials under the existing asset contract. Recheck the same poses with the complete equipment set; a valid naked body is insufficient.
9. Produce standard turnaround and gameplay-distance renders and a machine-readable build report. The report contains measured statistics and generated hashes from the actual asset, never invented sample values.
10. Keep narrative art and slide text out of runtime texture atlases. Model the referenced subject; do not use a screenshot rectangle as the unit's texture or put carousel arrows on a prop.

No external generation service or paid asset call is required for the reference review. The existing Meshy-credit rule applies if later production uses that service.

## 4. Shape and material decisions

| Element | Required treatment for this reference direction | Failure example |
|---|---|---|
| Eyes | Readable lids and directed gaze within a recognizable animal face | Oversized identical glossy eyes pasted onto every species |
| Muzzle | Actual projecting volume and appropriate nose/mouth placement | Flat human face hidden by an animal nose decal |
| Ears | Thickness, root placement, inner plane and garment clearance | Thin single-sided planes penetrating a cap |
| Hands | Enough anatomy for the selected grip; model digits explicitly in the sheet | Painted claws without a gripping palm or invented finger count from an occluded glove |
| Hind feet | Contact surface and stride appropriate to the selected species sheet | Identical booted human feet on hare, mole and otter |
| Tail | Pelvis-rooted continuous volume with owned animation bounds | Tail glued to backpack or clipped through every chair |
| Fur / quills | Large sculpted silhouette groups plus atlas detail | Thousands of individual hair shells on crowd residents |
| Cloth | Broad fold structure following support, fastening and movement | Detailed wrinkles that ignore elbow, hip or tail movement |
| Leather / timber / metal | Distinct broad material response and wear at use points | Uniform glossy brown over fur, leather and wood |
| Patterns | Broad checks, hems and markings selected for camera readability | Fine tartan or woven patterns dominating distant silhouettes |
| Symbols | Known scenario affiliation or explicitly original symbol | Automatically placing the sword, crown or Abbey emblem on every resident |
| Water effects | Scene lighting, ripples and wetness state separated from base material | Permanent green underwater tint on the ordinary otter body |

Reference-driven palette roles: woodland greens and warm undyed cloth for practical dress; brown leather/wood as supporting masses; limited gold/blue/red/purple for selected roles and regions; warm occupied interiors with cooler exterior weather variants. No sampled RGB palette is claimed. Exact material values belong to a later look-development asset sheet, not to an unsupported numerical average of the slides.

## 5. Traversal changes the model specification

| Action family | Required pose/contact study | Equipment consequence | Environment counterpart |
|---|---|---|---|
| Dig | Standing/kneeling work, two-handed pick, palm/claw work, spoil transfer | Distinct tool grips; backpack/light must clear ceiling | Working face, standing space, spoil destination, completed tunnel |
| Tunnel travel | Stand, crouch/crawl, corner, turn, climb out | Fold/stow tall tools and light arm; preserve tail clearance | Explicit section width/height and portal lip |
| Surface swim | Entry, horizontal propulsion, tread/hold, turn, bank exit | Arm stroke and tail envelope; permitted carried kit visible | Water surface, bank grip, landing space |
| Dive | Submerge, submerged propulsion, ascend and surface | No default bow use; held cargo changes profile | Water-column route and reachable air endpoint |
| Climb trunk/ladder | Reach, pull, hind-paw placement, rest, reverse | Hands available; weapon/basket stowed or carried by an explicit method | Trunk/rung contacts and stable start/end landings |
| Canopy travel | Crouch/walk along branch, turn, junction, descend | Tail balance and quiver/cape clearance | Connected traversable branches, load/clearance tags |
| Water/branch work | Stable working pose and tool use | Cannot simultaneously use both hands for incompatible support and work | Specific work socket with safe return route |

The contact set can be sparse and authored. Crowds do not require one live full-body IK solver per creature. The authored pose must still look physically connected to its surface. Camera distance may simplify fingers, but must never replace swimming with walking or put a tunnel traveler on top of the roof.

A carrying-profile change is mechanically relevant when it changes route eligibility; visual folding must follow a committed equipment state. An artist cannot shrink a lantern only on screen while collision still assumes the tall version, or enlarge a load without a valid carrying profile. The traversal review specifies the proposed interface.

## 6. Existing Godot/Blender constraints inherited unchanged

Source: `docs/crowd_rendering_architecture.md` §2.7, §3 and §9; settlement-specific actor cap comes from `docs/game_gdd.md` §7. These are specifications, not measured success for these new assets.

| Field | Inherited requirement |
|---|---|
| Authoring units | Blender metric, unit scale 1; prototype mouse 1.0 m |
| Coordinates | Blender +Z up/+Y forward; Godot +Y up/−Z forward; convert `(x,y,z)` to `(x,z,−y)` exactly once |
| Root origin | Ground contact center between feet, or ground-projected body center for non-bipeds |
| Transforms | Applied rotation/scale; no negative determinant, animated scale/shear or runtime nonuniform root scaling |
| Ordinary rig | At most 64 exported bones including sockets; immutable rig manifest controls hierarchy, order and bind data |
| L0/L1/L2/L3 geometry | 12,000 / 3,500 / 1,200 / 350 triangles **including equipment**; existing large/giant exception requires its own metadata/qualification |
| L0 surfaces | At most 3; body remains one surface; gear surfaces separately budgeted |
| Atlas | Initially one 2048² albedo, normal and ORM atlas per species family; lower LODs share it |
| Fur | Sculpted silhouette with albedo/normal detail; no crowd shell fur/hair strands |
| Root motion | In-place clips; simulation owns authoritative travel |
| Clip baseline | 16 clips, 609 frames at 30 Hz for the initial biped library; traversal extensions are absent and must version the catalog |
| Small-scale review | Front, side, rear and three-quarter at 180, 70, 24 and 8 rendered pixels |
| Readability | Species clear at 70 px; sword/spear/bow distinguishable at 24 px when weapon length is at least 6 px |
| Close deformation | Existing bake limits: body 2 mm/equipment tip 5 mm at baked frames; specified interpolated-frame tolerances also apply |
| Actor pools | Settlement close skeletal pool at most 24; battle's separate pool is not a settlement allowance |

Repeated screenshot equipment does not create extra budget. Banners, quivers, packs, poles, tails and wings must be included in animated bounds. The currently inherited 609-frame palette does not have room for new clips merely because their names can be mapped to `walk`.

For `B` bones and `F_add` newly stored frames, the existing three-RGBA16F-texel palette representation adds `24 * B * F_add` bytes of raw texels per compatible library before padding. **Illustrative arithmetic only:** 64 bones × 120 new frames × 24 bytes = 184,320 bytes. These 120 frames are not an adopted traversal library. Actual frame counts, format, padding and library sharing must come from the authored assets and revised manifest.

Do not enlarge all rig families for hypothetical features. First expose the required body contacts and sockets, then author the smallest compatible skeleton that passes the movement tests. Similar silhouettes do not establish identical binds or animation compatibility.

## 7. Completed reference manifest example

This is an authoring record, not a generated asset or an ECS component. The record deliberately states the missing geometry instead of fabricating a mesh hash.

```json
{
  "schema_version": 1,
  "brief_id": "ART-BRIEF-MOLE-WORKER-01",
  "status": "REFERENCE_READY_NO_MODEL_BUILT",
  "body_refs": ["IMG-08", "IMG-25"],
  "costume_refs": ["IMG-08", "IMG-03"],
  "pose_refs": ["IMG-08"],
  "accepted_features": [
    "compact rounded torso",
    "projecting nose",
    "broad digging hands",
    "separate pick and lantern equipment"
  ],
  "authored_adaptations": [
    "draw ungloved hands before building the glove",
    "supply neutral rear and side construction drawings",
    "provide a folded or removed tall lantern configuration for low clearance",
    "keep elaborate goggles and armor optional rather than species anatomy"
  ],
  "traversal_review_refs": ["TRV-T01", "TRV-T02", "TRV-T03"],
  "mechanical_owner": "docs/systems_architecture.md",
  "asset_contract": "docs/crowd_rendering_architecture.md#9-blender--blender-mcp-asset-rules",
  "generated_asset": null,
  "generated_hash": null
}
```

Validation: IMG IDs must resolve; accepted features must be visible in a named region; adaptations must not masquerade as observed anatomy; `generated_asset` and `generated_hash` remain null until an actual file exists. The output manifest records `source_repo_path` so a Windows agent can locate sources without depending on Brendan's Mac absolute paths.

## 8. Production order and acceptance checklist

1. Create one consistent mouse construction sheet from IMG-12/25/26, plus an original keeper garment study from IMG-03/04. Resolve species/body readability before defining named characters.
2. Produce the existing mouse-and-sword baseline under the established rendering validation plan. Keep the keeper equipment as a separate original variant, with no biography changes.
3. Prepare mole, otter and squirrel **reference sheets and pose studies** in parallel with the mouse work, covering the movement families in §5. These are preproduction drawings, not a claim that full crowd bakes are qualified.
4. Respect the existing Windows P3/P4 gate before extending qualified crowd asset production to further species. The 64 GB / RTX 5090 machine is not currently available; do not infer its performance or replace the existing qualification floor.
5. Record source IDs, hidden-view decisions, per-LOD measured triangles/surfaces, bones, texture dimensions and pose bounds for every built asset.
6. Verify tails, ears, capes and tools clear the authored tunnel, bank and branch fixtures. Recheck at the actual presentation tiers and while paused.
7. Compare neutral daylight, warm interior and wet exterior views using the same body materials. Species and equipment remain identifiable in each.
8. Reject source mismatches that were not recorded as intentional adaptations. Keep a side-by-side review image in the future asset report, pointing back to the original source PNG.

Remaining work is concrete: no turnarounds, meshes, rigs, textures, clips, contact fixtures or renders were produced in this task. This document tells the model-building agent which original images and features to use; it does not report those production steps as completed.
