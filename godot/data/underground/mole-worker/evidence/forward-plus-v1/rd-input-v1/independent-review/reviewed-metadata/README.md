# Exact Metal mesh-input census — pending independent review

ADR1138. This packet captures actual RenderingDevice input storage for the accepted firm-grip mole and pick on the unchanged Godot4.7.2 official macOS Metal/Forward+ renderer. **It grants zero profile, deformation, GPU-arithmetic or World permission.** It neither edits the Actor/Profile consumers nor refreshes a published profile certificate.

The final `native-v6` uses the actual original imported assets and unchanged grip helper. The unchanged ActorContent loader matches both primary meshes to the accepted648,760-byte14-clip image, SHA `adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9`. That binds the original body/clothing and held-pick position/influence transcript; independent audit also matches every primary triangle to topology `da623e5c7c3c5a6aff5c466b143425422f3aa2253497527c84f713738f997b42`. No matching filename, synthetic mesh or copied qualification flag substitutes for these checks.

## Actual result

| Source | Vertices | Base triangles | Additional LOD triangles | Native CPU position reference |
| --- | ---: | ---: | --- | --- |
| Firm-grip body/clothing |17,172|10,209|none|present, all exact source bits compared|
| Original pick |1,176|1,150|572 /286 /198|present, exact compressed decode checked|
| Original pick shadow mesh |575|1,150|572 /286 /198|absent in this pinned engine branch|

All3 surfaces/18,923 vertices,37,527 base indices and6 complete LOD streams are retained. The input wire is1,789,659 bytes, SHA `6cae5de988d7dbe55035d692592cfb050ba7dcbc80680512bd794f937704741d`. Main fingerprints remain `29f8d3218fddfaa6f2369c1c1c7dfd9b0a429b3df5cbefa38c6bf6ab9364fe14` and `c4029dd3ea3266e6fac9f9d5734c37925d7300020d494ca0f83529567a9a9b3a`. The auxiliary raw transcript is separately `41bc598d52d67f9eb975e7c8a67bc2ed6252430cf5302755daa961b683030985` and is **not** a match to the primary palette mesh certificate.

The body has4 integer UNORM weight lanes per vertex:68,688 total,57,796 positive and10,892 zero. Every ID, including zero-weight lanes, stays within the actual24-bind palette. Positive used IDs are0–21. Weight sums range65532–65535; the audit preserves these sums and exact word/65535 fractions rather than normalizing them. The maximum difference from the native decoded float32 reference is exactly10921/366498283520. The pick's three exact rational source-to-CPU compressed-coordinate residuals are retained in `audit.json`; these are not a Metal shader error bound.

`RenderingServer.mesh_get_surface` calls the actual RD buffer readback in the pinned engine. The capture retains all vertex/normal/tangent, attribute, skin and base/LOD index bytes, offsets/strides/counts, exact binary32 AABB words and exact binary32 LOD thresholds. JSON decimal numbers are readable diagnostics: the auditor requires them to round back to the normative binary words. Primary position, bone, weight and index references are independently checked; other shading attributes are retained/hashed and length-checked, not numerically qualified.

## Compressed shadow distinction

The actual575-vertex shadow format is34896613377: compressed positions with no normals. In the pinned `rendering_server.cpp` `_get_array_from_surface`, the compressed/no-normal branch computes its local positions, then `continue` skips `ret[ARRAY_VERTEX] = arr_3d`. The actual native API consequently returns no vertex array. The diagnostic refusal records this directly; the capture does not manufacture a native reference or modify the engine.

The separate `UGAUX001` transcript includes mesh/surface AABBs, full format/counts, all four raw buffers and all LOD thresholds/index streams. The offline reader derives exact rational compressed positions from the actual integer words and AABB, but leaves `native_position_reference=false` and CPU residual `null`. Its triangle indices are still compared with the actual native index reference. A future enclosure must explicitly include these auxiliary inputs and Metal conversion semantics; neither the main mesh fingerprint nor similar bounds excuses them. The primary `UGMESH01` binding and CPU references remain unchanged.

## Validation and source closure

`check-v7` ran the official exact singleton shard after moving own assets outside Godot, deleting only the own import cache and completing a clean editor import:9 tests/54 assertions/0 failures, strict and raw unexpected errors/warnings/leaks all0; analyzer0 warnings/2 files. No full no-argument suite is claimed. Its exact executed check wrapper is retained as `check-v7/run_checks.py.txt`. The current wrapper adds only pre-resolution dangling-output refusal, covered by its focused Python regression; it does not alter the already executed Godot commands.

`final-python` records16 auditor tests plus8 wrapper tests, all passing. The adversarial cases cover exact weights, all4/8 lanes, topology/identity, complete shadow and LOD census, byte/metadata budgets, truncation/trailing data, nonfinite values, actual binary metadata, raw-only shadow versus native-reference relabelling, drift, backend and output preservation. The same final auditor was also run through its CLI on the complete native image: its report is byte-identical to `native-v6/audit.json`.

The native witness records8 actual source assertions, empty failures, exact Metal/Forward+/macOS/official engine identity and zero raw import/native error, warning or leak lines. All1,545 restored-import/current executable/source pins agree before and after native execution and were rechecked afterward. The original raw asset library is read only; the wrapper maps only the exact old library prefix into the already verified own clone, retaining identical expected hashes. Original imported scenes are restored only into the own cache from their exact accepted archive. The unique `user://` directory, project bytes, override removal and full source restoration are recorded in `invocation.json`. This work uses no paid service.

The capture loads the source program for mesh identity; it does not replay its poses or read deformed GPU vertices. Palette execution, model/root arithmetic, Metal UNORM behavior, optimized shader expression error, auxiliary/LOD enclosure, native animation/visual quality and actual World support/contact remain separate obligations. Material uniforms, UV interpretation and the complete draw pipeline are not certified by retained vertex buffers. The previous OpenGL certificates are unchanged.

## Bounds and memory

At most2 primary meshes plus1 explicit shadow mesh per primary,8 surfaces per mesh,32,768 total vertices per mesh,196,608 base/LOD indices per surface,8 LOD streams,4/8 influence lanes and64 binds are admitted. Recursive shadows, blends, custom/dynamic/2D or unknown layouts refuse. Main asset counts are additionally fixed by the immutable Content image. Auxiliary decoding never substitutes the primary loader's narrower index/vertex heuristic.

Capture and audit stream one surface at a time. Native raw/reference/decoded numeric coexistence is capped at16MiB per surface and total emitted numeric data64MiB; metadata is separately bounded to16KiB per record and total reader overhead262,144 bytes. The independent reader rejects lengths before buffer allocation. Actual numeric bytes are1,786,498 and maximum simultaneous native surface numeric payload3,191,166. Small hashes, metadata, native controls, immutable source loading and borrowed meshes/materials are separate, not hidden inside this payload count. The actual process reported memory before171,925,007, after194,315,198 and prior peak329,765,637 bytes. That peak is non-isolated and is not a whole-client or100MB simulation-memory qualification. No production reserve or flag changes.

## Retained refusals

* The first wrapper preflight refused old external library names; the exact prior wrapper is retained. The correction permits only the known original-library prefix mapped to unchanged bytes in the own clone.
* `native-v2` retained the complete body, then refused the real pick shadow rather than omitting it.
* `native-v3`/`native-v4` retained both primary parts and actual pick LODs, then refused the absent auxiliary fingerprint. The initial generic fingerprint diagnosis was insufficient; it was not evidence of valid shadow decoding.
* `native-v5-diagnostic` identifies the actual null vertex reference and matching raw/native format/counts. The real shadow has3,450 indices for575 vertices, exactly6 per vertex; the separate high-valence test is an adversarial fixture, not the cause of this actual refusal.
* `check-v1` retains the original analyzer-path failure; `check-v6` retains two unexpected empty-HashingContext update diagnostics despite passing assertions. Empty buffers now hash their explicit zero length and skip the engine's forbidden empty update. Both iterations remain rejected.

Exact executed owned bytes resolve through `historical-source-locators.json`:37 recorded source references,0 missing, with the old reports/specifications unchanged. Archived `.gd` bytes are non-executable `.gd.txt`. Positive partial results are never reported as a complete capture. Earlier passing focused checks remain scoped to their own source pins.

## Reproduction

From this checkout, with the existing pinned raw/import assets, use the actual bundled interpreter and fresh output names:

```sh
ug_python=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
ug_input=godot/data/underground/mole-worker/evidence/forward-plus-v1/rd-input-v1
"$ug_python" tools/test_audit_underground_metal_inputs.py
"$ug_python" "$ug_input/test_capture_inputs.py"
"$ug_python" "$ug_input/run_checks.py" "$ug_input/reproduce-checks"
"$ug_python" "$ug_input/capture_inputs.py" "$ug_input/reproduce-native"
```

The capture wrapper already runs the independent full audit. `final-python/audit-command.json` retains its standalone equivalent; use a fresh output filename. Missing/drifted inputs, wrong backend or existing output refuse. `source-sha256.json` pins7 executable files and2 UIDs; output/history/inherited manifests retain final evidence, all earlier refusals and exact source dependencies. Independent review is pending.
