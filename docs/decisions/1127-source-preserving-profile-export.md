# 1127 — Export source-bound underground profile prerequisites
Date: 2026-10-04 · Status: Independently reviewed; staged packaging prerequisite verified

> **Superseded in part by [1841](1841-the-demo-pack-carries-every-underground-binary-by-an-export-plugin.md)
> (2026-10-09):** the preset's include_filter no longer names the profile and actor paths. The editor plugin
> `godot/addons/demo_pack_files` packs every underground binary the runtime reads, from
> `godot/data/underground/runtime_files.gd`. Script export mode 0 and the cached-source check are unchanged.

## Decision

Use Godot script export mode 0 for the Windows demo preset and include the exact
immutable mole profile and actor binary paths. Extend the existing pack verifier with a
mandatory byte-count/hash and actually cached Script-source check before the
demo boots. Keep every existing asset, scene, clock, stall/resume, build-info and
playtest-log check. This is a packaging prerequisite, not underground activation.

## Why

The independent root probe at
`docs/validation/evidence/profile-export-probe-2026-10-04/` measured that mode 2
keeps the actual cached Script identity but strips `get_source_code()` to zero
characters. The existing include filter also omits `.ugprof`. The source-bound
loader must refuse both cases. Mode 0 plus explicit inclusion preserved the
actual source and raw file under the editor pack and real macOS debug/release
templates, with zero diagnostics. Those small probes establish capability, not
validation of the complete demo pack or Windows template execution.

## Implementation and validation scope

The exclusive source slice is `tools/demo_build/windows_export_preset.cfg`,
`tools/godot/verify_demo_pack.gd`, and the related preset-contract checks in
`tools/test_build_demo_windows.py`. The additive `godot/test/test_demo_profile_pack.gd` exercises the verifier's
bounded static profile check, including an actually cached Script whose source
is stripped or changed, and restores that object after each test. The accepted
immutable publication compiler/loader remains unchanged.

The verifier uses the same concrete, already cached eight Script resources as
the runtime gate and the generated immutable wire hash. It must reject missing,
truncated, changed or oversized binary input and unavailable/changed source.
This check does not publish a World, infer support, create a Job, pay materials,
select a work contact, or bypass actual renderer attachment. Source retention
and native allocator/startup effects require explicit measurement; the existing
simulation ledger is not a whole-client measurement.

The full staged-demo build must still export and boot its actual pack through
the unchanged build pipeline. Raw import/export/verification logs, exact input
hashes before/after execution, source availability, artifact byte counts and
reported memory are retained. A failed existing gate remains a failed build.
No `--allow-unstaged` or skipped verification is evidence of a passing demo.

The exact existing 648,760-byte actor image is included from
`data/underground/mole-worker/evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor`;
its digest must equal `Pins.ACTOR_SHA`. The profile image is exactly 7,268 bytes
and must equal `Pins.WIRE_SHA`. Each is hashed from one bounded open stream in
16KiB blocks. Native WorldBasis attachment and actual component activation
remain separate obligations. No source relocation, broad binary glob or new
success flag is introduced.

## Independent component review

Root independently accepted the four exact `focused-v2` source pins on
2026-10-04: preset `6007721a…`, verifier `8e8c5931…`, Python export tests
`9654e722…`, and Godot test `d2172e66…`. The review found no high or medium
source issue in bounded binary hashing, cached Script identity/source checks,
or preservation of the existing demo checks. The selected CI suite reports
5 tests / 21 assertions / 0 failures, both strict and raw diagnostic/leak
footers zero; the analyzer reports zero warnings in two files. Existing
Python export tests report 80 checks / 0 failures. This acceptance remains
conditional on the separately recorded complete staged export/boot result.

## Complete staged-package result

`full-pack-v1` completed the unchanged normal builder on an isolated APFS clone
of the existing asset library. It staged 141 world assets, nine cast entries and
56 sound files, with no skipped/refused input. The existing art UI script issued
one Pillow deprecation warning, retained in the raw staging log. No paid
generation or shared-library write was used.

After a cache-deleted clean import, the default Windows debug export and editor
pack boot completed successfully. The actual packed checker read the exact
7,268-byte profile and 648,760-byte actor streams, verified all eight actual
cached consumer sources (420,955 characters), and then passed every existing
demo check. The manifest, compressed textures/raw images, beaver tail binding,
clock, deliberate stall/resume and playtest log were present. It observed 49
ticks after resume. ANSI-normalized raw import/export/verification scans contain
zero engine error, warning or leak lines. Executed sources, original local
export preset and isolated user-data override were unchanged or restored.
Original source-capture assets were restored after retaining the complete
staging and generated packages under ignored `build/` output.

The actual editor pack boot used Metal 4.0 / Forward Plus. Its pre-demo static
memory observation was 319,253,443 bytes; this is one whole-client snapshot,
neither an allocation peak nor the simulation's 100 MB ledger. Windows native
execution and a full release demo export were not run. Root's separate small
debug/release template probe establishes source-retention capability only.
The profile report preserves `world_activation_qualified=false`, and the
underground actor still refuses this unqualified Forward Plus backend. Pack
presence/source retention does not grant renderer, terrain, Work or paid-timber
permission.

## Source

Root's isolated Godot 4.7.2 capability probe and 1123's immutable catalog/source
contract; the user-authorized complete underground implementation. No gameplay,
material-price, pace, grip, room or traversal policy changes.

## Final independent evidence acceptance

On2026-10-04 root independently rehashed all5 source and42 original output
pins, read the actual build, verification, raw diagnostic and restoration
records, and accepted this complete staged packaging result. The original
reviewed documentation/manifests are retained in review-full-pack-v1 before
this acceptance annotation. Exact executable source hashes remain unchanged.
The renderer, World, Windows-native and whole-client limits above remain open.
