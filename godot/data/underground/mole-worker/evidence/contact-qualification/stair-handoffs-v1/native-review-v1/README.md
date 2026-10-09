# 1142 native supported stair handoff witness

Status: frozen for independent review. The six offline source/proof files were
accepted independently and committed as `414ecec7`; this additive packet changes
none of them, their existing manifests, or the eight captured runtime consumers.
Its diff base is that commit on `codex/underground-stair-handoff`.

## Result and exact scope

`native-v5` passes 3,795 emitted poses, 91,080 actual native skeleton-matrix
checks, 7,590 actual body/tool instance-transform checks, 125,652 assertions,
12 complete joins and 93 saved PNGs. The independent Python oracle reconstructs
every emitted root, heading, source-frame pair and complete 301-F32 sample hash.
Every interval endpoint and midpoint is present, including stationary-root
phases. The four joins are repeated in side, opposite and RTS views. All 22
complete positive fixture prisms are present: fourteen timber parts and eight
natural bearing boxes.

The final source tests pass 15 cases. The changed GDScript analyzer reports zero
warnings in one file. Its 19 functions have at most 23 nonblank lines each.
Import and native logs contain no unexpected diagnostics or leaks. The 835
pre-import inputs and 911 native inputs match their own before/after snapshots;
the subsequent test/analyzer run also leaves all 911 unchanged. HEAD and project
source remain fixed. Each run creates and removes only its own output-specific
user-directory override; the final analyzer uses its own separate user directory.

This is an OpenGL `gl_compatibility` presentation witness over an unpaid source
fixture. It does not drive Routes, Work, Placement or a paid World. The complete
episode returns to the same fixed root with heading 32768, not the initial
heading zero. No instant heading reset or closed return route is asserted.
Continuous source collision/support proofs remain the separate accepted offline
packet; sampled render readback is not a substitute for them. Default Metal,
native continuous arithmetic, actual paid support identities, authoritative
phase playback, adopted pace, save/lifecycle integration and whole-client memory
or performance remain unqualified. The 60 Hz capture command and half-interval
sampling never supply a gameplay rate.

## Native equation and source lifetime

The unchanged actual Actor, Content loader, original/derived mole mesh, original
materials, held pick and finite OpenGL WorldBasis are used. Each of the three
source images is loaded sequentially; the prior Actor and Content are released
before another is decoded. One immutable mesh/material set and one WorldBasis
are shared. Full body/clothing and held-tool geometry remain visible.

The old gait's signed local root ceil precedes its fixed quarter-turn. New
handoff roots already inhabit the fixed program frame. Moving heading rotates
palette geometry and grounding, never the root a second time. Native skeleton
and actual MeshInstance transforms are checked against separately assembled
scalar values, with F32 byte comparison. Complete local palette, root and
heading match at every join, including image replacement. Terminal sampling is
last-row/last-row/share-zero.

The source-program presentation ceiling remains the offline proposal of
7,039,052 bytes, with a separate 544,768-byte WorldBasis reservation. The native
log records non-isolated process observations (159,461,498 bytes before initial
content load, 160,008,978 after, prior/high-water 257,065,986). Those include
unrelated loaded resources and diagnostic machinery and do not establish an
isolated peak. This harness additionally retains event dictionaries, joins,
image metadata, fixture meshes and oracle buffers solely for diagnostics; none
is admitted as a simulation owner or charged silently against joint headroom.
The 101,368-byte handoff table proposal and separate prior gait table proposal
remain unadopted.

## Retained refusals and redraw correction

* `native-preflight-v1` refused the obsolete high-wall execution bake with
  `HIGH_WALL_PREIMPORT_SOURCE` before launching Godot.
* `native-v1` completed pose/matrix checks but wrote zero images because JSON
  screenshot numbers were not converted to the integer selection type. Its
  outer complete-image guard correctly refused the result.
* `native-v2` saved the first PNG, then stalled. The exact owned native PID
  32273 was sampled and terminated with SIGTERM. Exit -15, source equality and
  override removal are preserved. No other process was signaled.
* `native-v3` retained the unsuccessful extra process-frame wait. Its bounded
  engine-iteration watchdog ended before a report, so the outer guard refused.
* `native-v4` added diagnostic boundaries and isolated the stall to awaiting
  the second automatic `frame_post_draw` signal. The watchdog/refusal remains.
* `native-v5` explicitly calls main-thread
  `RenderingServer.force_draw(true, 0.0)` for each selected pose before reading
  and saving the viewport image. This supplies rendering only, not source phase
  or gameplay time. The complete capture then passes. Godot documents this
  explicit redraw operation and its main-thread requirement in
  [RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-force-draw).

The observed missing automatic draw signal does not establish an operating
system occlusion cause or an engine defect. No original rejected source or log
was rewritten. Executed source snapshots have non-executable `.txt` suffixes;
`historical-executable-locators.json` resolves only the exact changed historical
source hashes to those copies. It is an evidence locator, not a runtime bypass.

## Current execution closure

`native-runtime-v1` changes exactly eleven existing GDScript rows in the old
hash-bound high-wall bake: Actor, Buildings, Construction, EntityDirectory,
ExcavationContract, Inventory, ModularProjectContract, Reservations,
ResourceNodes, Transforms and WorldInit. Every old/new hash and the original
manifest identity are explicit. The wrapper reconstructs that precise delta,
requires all current bytes, and retains every other raw asset/import/source
row. This changes current native execution closure only. It neither rebakes a
palette nor renews a physical profile, source producer or current integration
publication. Both exact runtime metadata files are hard-pinned by the wrapper;
the old execution bake continues to fail its original strict preflight.

`source-sha256.json` contains the three new executables. `output-sha256.json`
pins the current run, focused checks, runtime mapping, design note, UID and
compact image census. `history-sha256.json` pins every retained rejected run
and preflight file. `inherited-sha256.json` records the exact 911-input native
closure, including all unchanged offline proof inputs and eight consumers.
The four original offline review manifests are also checked at every invocation.
Of those 911 inputs, 75 original raw-library files are outside this worktree and
are represented by their original absolute paths. They are read and hashed only;
all native import/cache restoration writes are confined to the owned worktree.
Their before/after bytes also match. A different machine must supply the exact
recorded inputs or refuse; no portable path substitution is implied here.

## Reproduce at the frozen checkout

The actual staged original assets, the hash-bound imported-scene archive and
ignored WorldBasis file must be present. Missing or changed inputs refuse.
Use the bundled NumPy interpreter, not an assumed system Python:

```sh
P=godot/data/underground/mole-worker/evidence/contact-qualification
PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
"$PY" -B "$P/stair-handoffs-v1/test_native_handoffs.py"
"$PY" -B "$P/stair-handoffs-v1/run_native_handoffs.py" "$P/stair-handoffs-v1/native-next"
```

The output must not exist, including a dangling symlink. Exact commands, engine
arguments and raw logs are retained in `native-v5`. The wrapper refuses drift,
partial poses, absent joins/images, unexpected diagnostics, wrong backend and
any production flag. It validates every saved PNG's SHA-256. Saved evidence can
also be checked without an engine run by importing the existing wrapper,
calling `validate_report(report, spec)` and comparing each named image against
the report's hash; `native-check-v1/saved-replay.json` records that replay.

Representative actual witnesses: `native-v5/side-turn-316.png`,
`opposite-turn-466.png`, `side-descent-120.png` and `rts-ascent-120.png`.
The whole fixture is visible in the RTS views; closer views may naturally crop
or occlude parts. These isolated source views are not a gameplay HUD, full
multilevel camera, final timber art or whole-game aesthetic acceptance.
