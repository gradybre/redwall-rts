# Native haul coefficient replay — source-only candidate

The native replay uses the actual Godot 4.7.2 Metal/Forward+ backend, unchanged
Content/Actor/WorldBasis code, the exact approved body/grip derivative and the
complete original wood geometry. It changes no existing runtime consumer,
driver, profile, simulation owner, project configuration or memory registry.
Independent review is pending.

## Result and limits

- Eight accepted clips, 595 stored palettes, 587 rendered intervals. The carry
  loop's final interval closes to its first key; its unused stored terminal key
  is not substituted for that wrap.
- 7,068 native samples across three nonzero World-root/heading cases; 21,251
  native assertions, zero failures and raw diagnostics/leaks. Clean isolated
  import; analyzer zero warnings in the one new GDScript file.
- Complete 17,172 body and 522 stock vertices reconstructed per sample, retaining
  all 10,209 body and 768 stock triangles. Zero native coefficient mismatches.
- 11,256 exact rational hand/stock triangle witnesses from captured native
  coefficients; nine exact joins and three exact reversal pairs in each view.
- Maximum source-to-native-input vertex difference: body 0.000287307u; wood
  0.000995328u. Minimum height above the descriptive root plane: 0.00136567u.
- Sixteen executable tests pass, including changed complete stock geometry,
  malformed capture size, true loop wrap, wrong selected clip, duplicated World
  root, altered body palette, one departed hand, displaced stock and changed hub.

Native matrices are actual RenderingServer skeleton values plus actual
MeshInstance World transforms. A deliberately unrelated nonzero parent tests
root application exactly once. The verifier uses independent source sampling
and scalar World equations. It does not read Actor scratch as its expected
answer. Every sampled hand witness uses exact rational reconstructed geometry;
full vertex error measurements use binary64 reconstruction.

This is sampled native **input** evidence. It does not establish GPU shader
roundoff or every unsampled Q16 coefficient, finite World support/traversal,
loaded turns, empty-ground joins, generic partial parcels, BUILD set-down,
runtime station/contact publication, gameplay timing or playable acceptance.
No synthetic profile flags are needed or emitted by this native project.

## Complete primitive representation

The original source transcript came from a native CylinderMesh, whose format is
zero. Content accepts ArrayMesh only. The first exact bindings therefore refused
correctly. Native v4 captures the complete ArrayMesh wrapper: all 522 binary32
vertex triples and 2,304 indices match the accepted source. Only format metadata
and the reported AABB depth differ. The wrapper transcript digest is
`a392927be5738063a4d4f98f9289c439cab83b2e47d9946f8d10d39a87c51d7c`;
its mesh fingerprint is
`cb0bf551f5439b0bea4609952c0ba43ff16d8c1bc5641743e1081e2412919cc5`.
The compiler checks full equality before encoding the new representation. No
Content fingerprint guard, physical triangle or accepted pose was changed.

## Reproduce

Use the NumPy-equipped Python at
`/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`.
From the worktree root, run the commands retained verbatim in `invocation.json`
and `validation-invocation.json`, changing the output to a new directory.
`run_native_program.py` executes compiler, clean isolated import, analyzer on
port 6364 and real native replay. Then run `verify_native_program.py` and
`test_native_program.py` with that capture. The compiler verifies the accepted
source and output manifests before encoding. All outputs are create-only.

The runner stages the exact 79-script transitive native dependency closure and
the original body/import settings in a temporary project beneath the ignored
offline subtree. It removes only that own temporary project after the run.
Its custom user directory is `Redwall-ug-haul-native-1144`. The main project,
importer cache, foreign worktrees and foreign processes are untouched. Source
closure and asset hashes, original commands, timings and restoration results
are retained. `final-source-sha256.json` pins the six new executable inputs.

## Memory scope

`census.py` derives the counts from the actual wire and current compiler/loader
declarations. The palette is 716,380 bytes; tables 696; the existing loader's
declared offline peak is 7,210,260 bytes, plus its separately loaded 544,768-byte
WorldBasis. This includes the existing mesh-array/control allowance, not a new
gameplay reservation. Mesh resources/textures, renderer allocations and Python
verification objects remain outside this declaration. The global simulation
state delta is zero and runtime admission remains false. Joint source image
replacement/loading still needs review; spare Delivery bytes do not admit it.

## Earlier attempts retained

- v1: wrong manifest-relative path in the new offline compiler, fixed before
  native loading. The failed log and executable snapshot remain.
- v2/v3: correct mesh-binding refusal exposed primitive/wrapper metadata.
- v4: retained full wrapper capture; binding still refused before representation
  was explicitly pinned. The measured complete geometry is unchanged.
- v5: first complete native/verification pass. Its exact executed verifier and
  source snapshots are retained; no unqualified runtime result is inferred.
- v6: two analyzer warnings in screenshot midpoint integer division. Replaced
  with the equivalent explicit half-duration bit shift; no source pose changed.
- v7: current clean source-frozen native, analyzer, verifier and test candidate.
