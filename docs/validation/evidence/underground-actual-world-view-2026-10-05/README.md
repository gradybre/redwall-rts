# 1175 — Actual World terrain presentation

Status: independently accepted by root as a bounded presentation component; not a playable-room or whole-demo acceptance. Base `b2527d79d413ad99a31459fba024103bb77bb372`, branch `codex/underground-world-view`. The only production addition is `godot/demo/burrow/modular_world_view.gd`; the live scene and test are owned additive witnesses. Existing canonical owners and shared demo controllers are unchanged.

## Exact API and caller lifetime

`configure(actual_world, full_world_ref, original_domain, actual_levels, surface_layer, slice_layer)` reads all 16,384 actual `WorldInit.terrain_into` rows once. Pass the **original retained Session._domain**, not a temporary `domain_copy()`: World, Directory, Levels and Domain are weak borrows. Exact concrete scripts, full World identity, original published seed, level revision/digest/columns, original Domain fields and identity transform are checked. `owner_refusal()` hides stale presentation; it grants no operation. `clear_view()` releases only this view's four mesh nodes and weak borrows; remount rebuilds from the new original World.

`set_floor(level_id, section_offset_u = 0)` uses the actual LevelCatalog, preserving the old selection on a refused floor. It reuses the same mesh. Root and XZ stay at identity; the slice child is translated to the exact integer floor / 1024. `bounds_into(out)` requires six caller integers and preserves them on refusal. The caller still owns camera/input/HUD, Session and synchronous reset.

## Geometry and interpretation

The real 128×128 terrain map spans X/Z [0,256] metres with exact 2m tile edges. Land is at 0.5m, water at 0m and integer datum is (0,512,0). Four source kinds remain visible; same-kind row runs share rectangular faces. Actual land/water edges alone produce 0–0.5m vertical banks. Clockwise winding, explicit normals, metre UVs and matching tangent handedness are tested on the decoded ArrayMesh. There are four MeshInstance3D nodes, four ArrayMeshes and no terrain physics/colliders, actors or new World.

The underground view hides the opaque surface. Its raw earth follows the actual Terrain natural-floor rule: the river ford has a -128u bed and therefore earth beneath it. Other protected wet columns receive a matte planning projection; it is not an invented water depth or empty room. All admitted underground planes are strictly below that bed and above Terrain.BOTTOM_U. Surface context outlines remain at their true source heights without writing depth; their render priority is below the planning marks. No Room/Space void is subtracted and no support, opening, route, excavation or payment is created.

The existing DEC-038 grounded ground shader, earth treatment and world palette are reused. Its old village path/clearing masks are disabled. Three existing 512² seeded noise textures supply the land treatment; no asset generation or paid service was used. The section material's presentation noise uses its section-local Y=0 while its actual child plane remains the exact catalog floor.

## Final evidence

- `candidate-5/`: official exact singleton shard, **10 tests / 51,358 assertions / zero failures**; strict/raw errors, warnings, expected/tolerated diagnostics and leaks all zero. Zero-warning analyzer on all three GDScript files. All 1,227 source/input pins unchanged; HEAD/project/registry/assets/import sidecars restored.
- `native-5/`: normal project main-scene boot (autoloads installed), real generated Host World and shipped LevelCatalog, actual **Metal / Forward+**, 25 assertions, zero failures, exactly four 1280×720 PNGs. All 1,227 before/after source/input pins equal; original project and HEAD restored. `image-sha256.json` pins every captured PNG. Native5 additionally closes the three material/overlay shader inputs before and after execution; all four PNG bytes equal the directly inspected Native4 images. The harness also verifies unchanged canonical identity/stock/jobs/residents/transforms, and three actual camera-to-cell round trips on the selected floor.
- `evidence-tests-4.log`: **13 Python tests** exercise census growth/lifetime refusals and native report/image negatives. `census-3.json` records the final source payload with tangents and ford-section counts.

Final native images: `surface-overview.png` shows Coast/River/Lake/Land in original coordinates; `surface-shore.png` shows the real river bank height; `section-overview.png` shows raw earth, the actual ford-bed crossing and above-floor context; `section-drawing.png` shows an **unconfirmed caller-owned** concave Kitchen drawing on the exact -4.5m plane. The drawing witness never calls RoomOrders or claims completed excavation. These captures assess this isolated component's visibility, not integrated HUD/input or whole-game art quality.

## Source-counted payload and build cost

The fixed numeric fields plus copied metadata are 300 bytes with the shipped level pack (348 bytes at its existing metadata capacity). Four weak references are separate. Each rectangle supplies 216 raw source bytes: four position/normal/tangent/UV vertices and six I32 indices. The actual map has 410 surface runs, 402 section runs, 465 banks and 1,445 line segments: **310,512 raw mesh-source bytes**, plus at most 100,440 bytes for one staging surface and the 16,384-byte terrain scratch. Top staging is dropped before section staging; each producer frame ends before the next surface stage.

At the finite checkerboard capacity there are 16,384 runs per plane, 32,512 banks, at most 65,536 context segments and **15,673,344 raw mesh-source bytes**. The largest single staging payload is 7,022,592 bytes. An explicitly illustrative old+new generation, staging and one equal-size upload payload totals 45,408,256 bytes (actual-map equivalent 838,288). Three RGBA8 512² full mip payloads total 4,194,300 bytes; two CPU/GPU generations would be 16,777,200 bytes. These are payload calculations, **not measured native allocation bounds or a global memory admission**. Actual ArrayMesh compression/upload copies, renderer deferred destruction, possible extra generation overlap, noise workers/seamless skirt/normal conversion, native headers/RIDs/arrays/materials/shader cache and helper frames remain unmeasured. The census mutation suite is a bounded producer regression check, not an arbitrary-allocation proof. No authoritative arena or shared ceiling changes.

Final native mount returned in **73,962µs**; focused headless real mount 72,537µs and the synthetic full checkerboard build 178,909µs. These are single local cold calls on this Mac, not p95/p99, target-hardware, steady UI, whole client or 60FPS qualification. Texture worker completion, shader compilation and presentation occur outside the mount timer. There is no mesh construction during ordinary frames or floor switching.

## Retained development history

- `candidate-1`: an initial UV assertion compared tiny decoded normal components to exact zero; one assertion failed. Production face axes were correct, and the test now uses the exact known cardinal axis before comparing UVs.
- `candidate-2`: strict tests passed but the analyzer refused a mixed material-subclass ternary; explicit typed Material selection corrected it.
- `candidate-3` and `native-2`: passing pre-ford/pre-tangent component evidence, superseded by the final packet. `analyzer-native-2.*` records the corrected normal-main-scene harness.
- `candidate-4` and `native-3`: passing actual ford-bed correction, superseded by explicit tangent attributes. Its LAND/RIVER checkerboard print reported the capacity constant; final candidate uses LAND/COAST and asserts both planes reach that count.
- `native-4`: exact final GDScript/tangent capture; Native5 reruns the same source with the three shader inputs added to the wrapper closure. All four images are byte-identical. `census-2.json` and `evidence-tests-3.log` retain that prior witness.
- `native-1`: rejected early SceneTree startup before autoloads; own stalled child was terminated, failure and restoration retained. Native2–4 use a normal main scene.
- `census-rejected-1/` and `evidence-tests-1.log`: first census parser accidentally collected nested function locals; corrected parser/baseline-first tests are retained separately. `census-pre-ford/`, `census-pre-tangent/`, `census-1.json` and `evidence-tests-2.log` remain historical.
- Every executed GDScript/wrapper snapshot is retained as nonexecuting `.txt`. `historical-source-locators.json` resolves changed producer hashes explicitly. `untracked-generated-sidecars-removed.json` records only new untracked import sidecars removed from this own worktree after the final native run.

`room-mode-review-1/` and `room-mode-review-2/` hold the separate read-only review requested by root: two initial MEDIUM findings and their exact corrected source acceptance. That review did not alter root's files or run another engine.

## Reproduction

Run from this worktree/repository root with installed Godot 4.7.2 and Python3. Choose new absent output paths (the tools refuse reuse or symlinks). Do not overlap another operation that changes this worktree's project or sources.

```sh
python3 docs/validation/evidence/underground-actual-world-view-2026-10-05/reproduce.py --out /tmp/ug1175-strict-new --port 6443
python3 docs/validation/evidence/underground-actual-world-view-2026-10-05/run_native.py --out /tmp/ug1175-native-new
python3 -B docs/validation/evidence/underground-actual-world-view-2026-10-05/test_evidence.py
python3 -B docs/validation/evidence/underground-actual-world-view-2026-10-05/census.py --native docs/validation/evidence/underground-actual-world-view-2026-10-05/native-5/report.json --out /tmp/ug1175-census-new.json
```

The strict wrapper cleans/imports the real project, chooses the official singleton shard from the current suite inventory, and restores its exact project/registry/assets/sidecars. The native wrapper sets a unique user directory and temporary normal main scene, checks the actual backend, exact assertion/image census, raw diagnostics, source closure and restoration. It never mutates canonical simulation modules. Full no-argument suite, actual integrated demo UI, physical room access, paid phases, actor/source playback and whole-process/native memory remain separate gates.

## Independent acceptance

Root independently accepted the exact eleven executable/UID/source pins in `source-review-1/source-sha256.json`, reviewed actual ford-bed selection, finite meshes, normals/UV/tangent handedness and directly inspected all four Native5 PNGs. No outstanding high/medium finding remains. The acceptance establishes original coordinates and a readable unconfirmed planning plane only; it does not accept final whole-game art, integrated input/room gameplay or native memory. The source/executed evidence is unchanged. The two reviewed pre-acceptance documentation bytes are preserved under `review-acceptance/` with explicit locators; original review manifests stay immutable.
