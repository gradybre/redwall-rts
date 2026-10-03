# Imported runtime profile evidence

This is the staged-runtime follow-up to decision 1067. It measures the existing
demo's imported body, remapped clip paths, final Skeleton3D modifier poses and
fitted carried geometry. **Every output is sampled evidence, not a qualified
movement profile.** No clearance, gameplay permission, cost or connector size
is inferred from it.

The immutable library in the main checkout is read-only. Generated models,
texture imports and Godot's cache are confined to the isolated space worktree's
ignored `godot/demo/assets` and `godot/.godot`. Existing staging tools are used
unchanged. Blender is local; no paid generation occurs.

The harness evaluates imported Skin binds and all four/eight vertex influences
at the actual `skeleton_updated` callback. It does not measure a rest-pose AABB.
It resolves every animation track against the body, retains actual bone names,
checks final skin matrices against the rendering server, and records
deformation. The signal precedes the renderer's palette upload: final matrices
are retained at the signal and compared in the following deferred callback,
before another animation step. Comparing the palette inside the signal would
compare different updates and produce a false mismatch.

Unsupported blend shapes, missing binds, invalid weights and nonfinite geometry
refuse. Held objects use the existing actor, farm and tunnel helpers with the
actual staged prop meshes. ArrayMesh and PrimitiveMesh are handled separately;
the demo's carried log is a CylinderMesh. Each body/attachment set is bounded to
200,000 vertices, each mesh to 32 surfaces, and each request to 16 attachment
variants. The bounds are measured independently for each held object, not as
an invented simultaneous cargo load.

The input contains exact hashes for the immutable library files, actual staged
GLBs, `.import` settings, generated scene bytes that ResourceLoader consumes,
staging implementations, the capture tool and its transitive literal script
load/autoload dependencies. It includes every clip loaded by the actor, not
only the selected state. Source hashes are checked again after the batch.
Missing clips remain explicit source gaps; neither another creature nor
another life stage supplies a substitute permission.

Required follow-up before production qualification remains continuous and
numerical residual proof, transient transitions and recovery, exact resident
life stage, real gear/cargo generations and quantity, accepted profile revision,
and actual root/support/contact/state-cost bindings. The scheduled half-turn
and demo ramp/stoop are presentation probes, not an authored traversal contract.
The source demo faces +Z; an authoritative −Z movement binding remains explicit.

The source clip is explicitly restarted at time zero after the 90-tick modifier
warm-up. Each case retains the observed AnimationPlayer timeline and expected
sample/palette counts. Both non-looping hammer clips cover all 58 requested
poses from zero to their 1.8666666746-second endpoint and show nonzero changes
from the first bone pose. This fixes a rejected intermediate batch that warmed
past the entire hammer clip. The restart transient remains unqualified.

The captured candidate's strict native batch reported:

```text
capture input: 47 cases; 522 exact source pins; 3 explicit clip gaps; no production permission
capture verified: 47 cases; 3736 sampled poses; 107040 exact observed native matrix checks; 0 unexpected diagnostics/leaks; 0 qualified
```

It covers the five actual mouse, mole, squirrel, otter and badger body imports;
their 22 available idle/walk/crouch/carry/hammer clips; and explicit plain,
standard-bore, ramp-pitch and half-turn probe scenarios where requested. Ten
carry cases each measure the actual log plus eleven crop props separately; two
hammer cases measure the staged pick. Mouse, squirrel and otter hammer clips
are absent and remain the three recorded clip gaps. Existing live tails are
observed for mouse, squirrel and otter; mole and badger retain their actual
`TAIL_NO_CHAIN` refusal. No life-stage or gear/cargo eligibility is inferred.

Godot 4.7.2 ran the native OpenGL Compatibility renderer on Apple M5 Pro. The
final adversarial test log reports `Ran 30 tests` / `OK`; the analyzer reports
`0 GDScript warning(s) in 0 of 1 file(s)`. Exact commands, raw outputs and hashes
are recorded in `verification.json` and `source-evidence.json`.

Reproduce from the isolated repository root:

```sh
python3 tools/stage_demo_assets.py --library /Users/brendan/Developer/redwall-rts/assets/library --out "$PWD/godot/demo/assets" --only cast
python3 tools/make_demo_props.py --library /Users/brendan/Developer/redwall-rts/assets/library --out "$PWD/godot/demo/assets" --only mole_pick item_radish item_turnip item_carrot item_beetroot item_onion item_leek item_lettuce item_celery item_peas item_barley item_oats
godot --headless --path godot --editor --quit
python3 tools/test_underground_profile_capture.py
python3 docs/design/underground-planning/evidence/modular-build/profiles/runtime/reproduce.py --run --out-dir /tmp/redwall-underground-capture-fresh
```

The native invocation recorded in `verification.json` uses `--path godot`,
`--rendering-method gl_compatibility`, `--audio-driver Dummy` and the actual
capture script and input paths. It deliberately does **not** use `--headless`:
the dummy rendering server cannot verify an uploaded skin palette. A bare
headless diagnostic run may still produce sampled geometry, but the strict
native evidence verifier refuses a missing palette. Use a fresh `--out-dir` for another batch. The entire output bundle (input,
report, native log and verification) is checked before any write; each is
create-only. Refusals cannot truncate a source, manifest or existing report,
including through a symlink or hard link.

These are asset-capture invocations, not the strict headless test-suite procedure.
The unrelated full suite is owned by the parent integration lane. The analyzer
is run on the outside-project tool text through its supported separate
`--project . --editor-project godot` roots and port 6149, leaving the source and
project paths untouched.

`reproduce.py --run` rejects any engine SCRIPT ERROR, ERROR, WARNING or leak
line, any missing case or attachment, changed identity, invalid bounds,
unverified native palette, incorrect sample/palette count, incomplete clip
timeline, stationary hammer pose, or claimed continuous residual. Exit 0 alone is
insufficient. The rejected intermediate CylinderMesh API run is preserved under
`historical-cylinder-refusal/`; its missing attachments and script errors are
not passing evidence. The subsequently rejected warm-up batch and its former
verification are preserved under `historical-warmup-refusal/`; zero diagnostics
did not prove that its non-looping motion was recorded. Final raw logs, exact
pins, case observations and strict verification live alongside this document. The separate
`connector-verification/` directory and `connectors-native.png` belong to the
reviewed synthetic connector rendering increment in decision 1070.

Godot's [MeshInstance3D skin-baking implementation](https://github.com/godotengine/godot/blob/4.7-stable/scene/3d/mesh_instance_3d.cpp)
provides the weighted matrix-sum reference; the installed engine's returned
skin palette is checked separately. Exact agreement with that API palette is an
observed matrix check. It is **not** proof of continuous motion between samples
or a bound on GPU arithmetic, shader deformation, spring transients, traversal,
turning with actual loads, or collision/contact semantics.
