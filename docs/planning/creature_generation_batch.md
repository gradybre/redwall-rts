# ART-CREATURES — proposed founding-species generation batch

2026-09-14 · Proposal for Brendan's approval, **not spending authorization**. No generation call, balance lookup, approval-ledger edit or asset acceptance was performed. This makes the scope priceable; it does not certify reference sheets or production assets as ready.

## Answers to the executor's three questions

1. **Four adult source models:** mouse keeper, mole worker, squirrel resident and otter resident, one body/clothing design each. They supply the12-person founding cohort (6/2/2/2); instances are not additional generation calls. Start with the mouse alone, then mole, then squirrel and otter after the existing pipeline/visual gates. Badger is a proportion-comparison participant, not part of this initial paid cohort batch. Children, elders, other species, extra outfits and unique individual portraits remain subsequent content work; this batch does not shrink their adopted release scope.
2. **Reference-guided image-to-3D.** Proposed model pin: `meshy-7`, standard, Ultra off; no mutable `latest`. This updates the older meshy-6 proposal for review. Verify that the executor's actual connector exposes the named model and parameters before presenting a callable approval request; an API capability is not proof of MCP support. If it does not, report the mismatch and price an explicit meshy-6 alternative rather than silently substituting.
3. **Generate2K PBR textures with each source model.** Evaluate convincing cloth/leather/fur-grouping/material separation early, alongside an untextured silhouette view. Generated UVs/materials are provisional: cleanup, retopology, rebaking and material authoring still happen locally. Repack runtime albedo/normal/ORM into the existing shared species-family2048² contract; do not presume the API emits the game's final packed ORM or a compliant atlas. All LODs share the approved family set. No hair-strand/shell-fur crowd rendering.

## Source models versus shipped LODs

Generate one detailed source per species. Build and verify the four runtime LODs in Blender from the same approved design, preserving silhouette, skinning, UV/material identity and animation. Do not buy a separately generated model at every LOD.

| Runtime tier | Existing triangle ceiling including equipment | Existing body vertex ceiling |
|---|---:|---:|
| L0 |12,000|—|
| L1 |3,500|2,400|
| L2 |1,200|800|
| L3 |350|250|

Thus four successful source models produce16 derived runtime mesh exports, not16 paid generations. The L0 body cannot consume12,000 triangles and then add unbudgeted tools. Detailed source geometry can exceed runtime limits; it is not ready to ship until retopology/LOD and deformation tests pass. Actual gameplay camera silhouette and action readability matter more than unseen surface detail.

The older untextured mouse test is not an accepted production body. Audit it against the mouse brief before spending: reuse is allowed if it meets the reference/anatomy/cleanup requirements, reducing the number of new calls. Do not declare it reusable merely because its filename says LOD0.

## Reference and generation settings

Use DEC-036 supplied-image permission and DEC-038's rounded, expressive, materially convincing RTS world direction. Combine IMG-25 anatomy outlines with the relevant species/body/clothing references in the model guide and the world-art brief. Do not apply the UI watercolor/contour/pigment lock to3D world materials. Keep the FOREST/JOURNAL UI distinction separate.

Prepare one coherent full-body design with a visible muzzle, paws and tail, separated limbs suitable for an A-pose, ordinary practical clothing, no held tools, scenery or baked text. Show front, side, actual authored rear and three-quarter for review. References inform that same creature; a collection of different mice is not a multiview set. Hidden surfaces are authored interpretations, not observed source facts. A spade and other detachable props are local Blender work and stay outside the paid creature body call.

Use multi-image-to-3D if the connector supports it and consistent views of that exact design exist; otherwise image-to-3D from the reviewed full-body view. Do not submit the entire labeled species lineup as one creature. Confirm the exact input filenames/hashes in the approval request; this proposal has not selected or certified those images.

Proposed parameters: `ai_model=meshy-7`, `ultra_mode=false`, `should_texture=true`, `texture_resolution=2k`, `enable_pbr=true`, `should_remesh=false`, `image_enhancement=false`, `pose_mode=a-pose`, outputGLB. No paid remesh/rig/animation/retexture. Request unprocessed source geometry and do budgeted topology/rigging/LODs locally. Do not supply a target-polycount promise when the selected endpoint does not apply it with remeshing disabled. Normalize to the actual approved DEC-039 units in Blender; do not use AI-estimated real-animal scale. Verify axes per artifact instead of applying an old importer workaround blindly.

## Itemized cost proposal

| Item | Endpoint / pinned model | Credits each | Calls | Credits |
|---|---|---:|---:|---:|
| Mouse keeper source with2K PBR |Image or multi-image-to-3D / meshy-7, Ultra off|30|1|30|
| Mole worker source with2K PBR |Same|30|1|30|
| Squirrel resident source with2K PBR |Same|30|1|30|
| Otter resident source with2K PBR |Same|30|1|30|
| One optional replacement attempt, for one failed species only |Same|30|1|30|
| **Four-species planned spend** ||||**120**|
| **Ceiling with one replacement** ||||**150**|

**First decision-sized tranche:30 credits for the mouse only.** Complete its anatomy/material/rig/LOD/bake and gameplay-camera review before committing to the remaining species. The original mouse-first then mole validation sequence remains; this full-batch estimate is not an instruction to run four parallel generation calls. The reserve is a single additional call, not30 per species, and is not automatically consumed.

Published API pricing checked2026-09-14: Meshy7 standard image and multi-image generation with normal-resolution textures is30 credits; mesh-only20; Ultra adds5;8K textured generation35 before Ultra. These are API prices, not web-app plan entitlements or a verified account balance. [Meshy API pricing](https://docs.meshy.ai/en/api/pricing). This proposal chooses2K and excludes Ultra/8K. Four models at30 give120; one30-credit replacement gives150. Dollars depend on the actual API-credit purchase/account and are not inferred here.

Generating meshes without textures would cost80 credits for four candidates. Texturing later is a separate paid or local-authoring step; mesh-only is not an80-credit quote for four finished textured characters. The proposed combined30-credit route lets us inspect the intended material treatment on the first candidate without representing generated textures as final assets.

Explicit exclusions: separate paid LODs, text-to-3D, paid2D reference generation, paid remesh, retexture, automatic rigging/animation, Blender generation bridges, tools/props and extra body/outfit variants. Any requested addition needs a separately priced line. Local cleanup/authoring has no Meshy credit charge but still requires development effort. If paid generation is declined, the existing local modeling route remains available.

## Existing context that should not be re-asked

The [world-art brief](../art-reference/world_art_lookdev_brief.md) §3 already names the four founding species and LOD/atlas contracts, and §9 already contains an older two-species paid proposal. Its historical100-credit ceiling combines two cheap probes, two textured production calls and one replacement; it is not the price of this four-species batch.

[DEC-039](../setting_decisions.md#dec-039--approved-creature-proportions-for-all-five-species) already records five height approvals. Some later paragraphs in the old brief still say those heights await approval: use DEC-039 for height, while keeping remaining anatomy, bake, facing and user visual acceptance separate. Do not infer that all ART-PROPORTION checks or the pending approval ledger are cleared. Windows validation remains deferred by Brendan; no substitute Mac performance claim is made.

The executor can record120 base/150 ceiling/30 first tranche in this proposal or a request sidecar. The approval ledger's null value must not be treated as an unanswerable species/LOD question, and filling in an estimate never means approved. Preserve the ledger's human-controlled policy.

## Claude's next action

Read this proposal, the existing A1 mouse brief and paid-asset process. Inspect available references and the existing test mouse, name the exact source images, check the real tool's parameters and current balance without generation, then return the mouse-only30-credit approval request. Stop before the paid call. After approval, execute only its stated scope and record prompt/model/input hashes/taskID/credits/source files; all subsequent quality gates remain real checks.

Official capability references: [image-to-3D](https://docs.meshy.ai/en/api/image-to-3d), [multi-image-to-3D](https://docs.meshy.ai/en/api/multi-image-to-3d), [retexture](https://docs.meshy.ai/en/api/retexture). Connector availability and exact request inputs remain to be verified by the executor.
