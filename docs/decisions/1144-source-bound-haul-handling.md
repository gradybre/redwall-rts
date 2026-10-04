# 1144 — Source-bound haul handling and distinct workpiece set-down
Date: 2026-10-04 · Status: Accepted direction; physical qualification pending

## Decision

Author an additive, source-hashed mole handling packet under
`godot/data/underground/mole-worker/haul-handling-v1/`. Reuse the supplied current
mesh and rig, the real carry animation and the existing wood presentation
geometry. Author actual no-tool HAUL loading, loaded CARRY, HAUL_OUTPUT unloading
and a separate BUILD set-down program. Existing consumers and published profiles
remain unchanged until the complete physical and allocation packet is reviewed.

The independently reviewed static source uses R−S=(0,0,576)u with two actual
hand/stock triangle witnesses and complete body/wood geometry. This is a measured
source contract, not a gameplay distance. Its nine source pins remain unchanged.
The additive `evidence/program-review-v1/` checkpoint extends that exact pose
through approach/lift/place/recovery with continuous source-only separation,
support and two-hand contact proofs. Native, gait, quantity and runtime gates
remain open.

The supported worker station R and Inventory storage anchor S are distinct.
Measure R−S and the actual hand/wood contact C−S from the authored geometry.
A storage Location's metadata point is not an instruction to touch the worker's
feet or to bend an animation around the synthetic zero-point fixture.

## Why

ADR1140 proves actual finite deliveries, per-payload work, repost and partial
unload through real owners, but its physical profiles are explicitly synthetic.
The existing accepted mole programs use the BASIC tool with empty cargo. Their
INSTALL adze contact is not a pickup, carry or set-down source. The original
`carry_heavy_object_walk` and ADR1067's inter-hand log are reusable inputs, not
complete source qualifications.

Separate source images avoid exceeding the current sixteen-clip presentation
limit or silently extending the accepted six-role driver. Source geometry,
runtime identities, source-derived contact and memory admission remain separate
proofs. Geometry's ADR1143 additive motion catalog is a separate owner; its stair
programs confer no hauling permission.

## Required source closure

Retain every body, clothing and cargo primitive, complete foot support, entry,
recovery, interruption/reversal and program join. No-tool HAUL meets a real wood
mesh at S from a separately supported station R. Loaded CARRY preserves the
actual quantity variant, including idle, full ground travel, turn and retreat.
HAUL_OUTPUT joins both empty and still-loaded outcomes; repost enters the loaded
hub without a second pickup. A partial unload cannot hide or delete its retained
payload. The BUILD set-down program is distinct from INSTALL and must match the
actual worker/tool state and the complete billed workpiece's source transform.

Only the exact current rig/mesh coefficients may be reused. No anatomy scaling,
mesh omission, caller success flag, inferred route, free support or new balance
constant is authorized. Existing 2,000 mWU loading and unloading per payload,
capacity-limited shipments, Catalog wood mass, wood-only assembly prices and
Work/CARRY formulas remain authoritative. Source timing does not create a second
economic work clock.

## Runtime seam proposed for later review

Keep the actual Inventory container's full STORAGE Location as S. Resolve a
separate already-live full worker Location R with the authored station offset,
exact World/Room/section/level and support. Route the actual worker to R. The
immutable service row pins its source image/program/profile/revision, cargo
variant and measured curved-mesh grip certificate. This is distinct from the
existing planar `CONTACT_PATCH` used by CUT/INSTALL; neither the storage anchor
nor a convenient planar box substitutes for the two actual hand contacts.
The final transfer leaf must recheck both
full Locations, the exact Inventory association, source digest, R/S/C transform,
current worker/PID/Job/cargo/claim, current tick and the original chosen
destination before committing. It must not add a per-Job goods or destination
ledger. This is a proposal, not a new runtime entry point in this increment.

Source tables, decoded image, compiler scratch, render mesh and replacement
lifetimes need a complete census before admission. ADR1140's unused allowance is
not permission to allocate them. Share or replace source images only after joint
review with ADR1143 and the existing Profiles/presentation reservations; do not
charge PROFILE_BYTES twice or enlarge the decimal 100 MB limit.

## Provenance and boundaries

The author opened DEC-038's grounded expressive example and supplied IMG-08 and
IMG-25. They guide the existing mole's compact mass and readable working motion;
their troop counts and relative pixels are not measurements or game rules. The
already approved mesh remains unchanged. All generation is local deterministic
authoring of existing supplied inputs; no paid generation was requested.

Only this ADR, the new `haul-handling-v1/` subtree and dedicated evidence are
owned here. Furnishing's stair handoffs, Geometry's motion catalog, accepted
profile consumers, Delivery/Work/Planner/Inventory and the shared registry remain
outside this increment. Production hauling/handling activation and the complete
blueprint-to-empty-Kitchen milestone remain open until their actual composition
passes.

## Source

Root's explicit 1144 additive source lease; ADR1140 and ADR1134; accepted
`review-install-source-v1`, `review-install-program-v1` and
`review-install-program-native-v1` evidence; final `install-source-v4` and
`install-program-compile-v3` inputs; ADR1067; DEC-036/037/038/039 and
SET-MOVE-001. Exact input hashes and all authored/rejected candidates are retained
in the new subtree rather than replacing earlier evidence.

## Reviewed source checkpoints

Root independently accepted the static checkpoint after reading the complete
source and contact packet, inspecting three views, verifying nine input and
twenty-two output hashes, and replaying all fourteen tests. It then accepted the
four-phase checkpoint after reading the four new source files, verifying all
twenty-four input and thirty-five output pins, inspecting the lifted poses and
replaying thirteen tests in 53.877 seconds with zero failures. Root retained the
independent evidence under `docs/validation/evidence/underground-haul-static-review-2026-10-04/`
and `docs/validation/evidence/underground-haul-program-review-2026-10-04/` on the
integration branch. Both verdicts are source-only; none of the open activation
gates above is waived.

## Exact-one-unit loaded source checkpoint

The next variant represents exactly 1,000 quantity-milli of the actual wood
mesh, using the Catalog's existing 5,000 g/unit mass. Repeated actual one-unit
deliveries can meet whole-unit timber bills; this does not change general
Inventory quantities or erase a partial remainder. Future runtime admission
must prove the admitted and carried quantity is exactly 1,000 at every boundary.
The existing 2,000 mWU load and unload amounts are unchanged. No hauling speed
is adopted by source animation timing.

Five additive source tools author and prove hold, entry, loaded gait and reverse
entry using the complete current meshes. They retain all 197 original supplied
gait keys, adding measured sole-transfer keys where the original candidate lost
continuous support. The four resulting clips contain 351 stored palettes and
347 rendered intervals, including the actual loop wrap. Exact rational
Bernstein sign proofs preserve both real curved hand contacts; full non-grip
triangles, stock overhang, floor and continuous sole witnesses remain required.
The rejected original support intervals are retained and still refuse.

Geometry's independent review read the five files, verified 32 input and 40
output hashes, and replayed all 15 initial tests. It found one loader capacity
defect: a small compressed NPZ allocated oversized arrays before rejecting the
key count. The corrected loader bounds the immutable disk image, ZIP directory,
member names, both NPY headers, exact float32/C-order shapes and payload sizes
before array decoding, with explicitly bounded decompression reads. Eight new
loader tests and the complete 23-case suite pass against unchanged geometry.
The old compressed-allocation witness and failed regression run remain in
`haul-handling-v1/evidence/loaded-gait-loader-review-v2/`. Independent correction
review accepted the exact source pins and re-ran the eight loader tests; its
evidence is `docs/validation/evidence/underground-loaded-gait-review-2026-10-04/`
on Geometry's branch.

This is a source-only acceptance. Raw palette arithmetic for these clips is
422,604 bytes, or 716,380 including the prior four-phase source, before mesh,
headers, decode, replacement and presentation lifetimes. It is not runtime
admission into the 100 MB gate. Native error/replay, finite World support and
root advancement, loaded turns, empty-ground joins, BUILD set-down, immutable
runtime contact/quantity publication and joint source memory remain open. The
entire subtree is offline importer-ignored; future runtime images must be staged
explicitly outside it.

## Isolated native replay increment

Replay only the eight accepted source clips in a separate ignored native
project. A new offline compiler may encode them with the existing finite Content
wire; it must first verify the accepted source and output hashes, preserve all
595 stored palettes and both complete meshes, and report the full presentation
reservation separately from runtime admission. The existing Actor, Content,
WorldBasis and grip derivative are staged byte-for-byte with their dependency
closure. No production driver or profile is replaced.

The native witness reads actual RenderingServer skeleton matrices and actual
mesh-instance World transforms at every source key and quarter interval,
including the true loop wrap. Nonzero integer roots and cardinal/noncardinal
headings test that the World root is applied once. The verifier independently
checks the source clock, complete vertex positions, both authored hand contacts
and exact joins. A sampled native witness is identified as sampled; continuous
source proofs do not silently become complete GPU or native interval proofs.
Full source/native differences and any unclosed error envelope are retained.

The new project uses its own user directory and importer cache. The original
body is imported with the pinned source settings and the actual wood factory is
fingerprinted before Actor configuration. Native replay timing creates no HAUL
rate, inventory movement, support, profile flag or economic work credit. Finite
World traversal, loaded turns, BUILD set-down, empty-ground joins and runtime
source/capacity admission remain separate gates.

The first native binding correctly refused the primitive stock transcript:
Content requires an ArrayMesh, while the accepted CylinderMesh source records
surface format zero. Native v4 retains the complete wrapped ArrayMesh capture.
All 522 binary32 vertex triples and 2,304 indices match the accepted stock;
only format metadata and the reported AABB depth differ. The latter changes
from 0.0990000069141388 to 0.0989999994635582 metres. The new offline compiler
therefore pins both original geometry and measured wrapper transcript, checks
complete equality before encoding, and retains Content's exact native mesh
fingerprint requirement. No primitive, source pose or physical envelope changes.

The final native-v7 packet is independently accepted for this sampled-input
scope. It captures 7,068 actual native rows with 21,251 assertions and no
failures or unexpected diagnostics/leaks. The independent reviewer passed all
sixteen tests, rebuilt the five compiler outputs byte-identically, reproduced
the complete native-input verifier and census, verified six executable, 83
input and 39 output hashes, and added four successful corrupted-input refusal
probes. Review evidence is committed as
`d16d751d8661ef61c3493225be6e15e792c7a0f0` under
`docs/validation/evidence/underground-room-publication-2026-10-04/native-haul-review-v1/`.
The frozen candidate README and output manifest remain unchanged; its separate
acceptance note records the later verdict. Every runtime/source/contact,
finite-world, loaded-turn, BUILD set-down, timing and memory limitation above
remains open.

## Historical source archives and the whole-project analyzer

Integration CI run `37223870212` at `b03fbc2b` correctly failed the unchanged
zero-warning gate: six historical rejected native capture snapshots (v1–v6)
still contained twelve intentional integer-division warnings. The accepted v7
capture and current executable already contained their reviewed annotations.
The offline importer exclusion does not exclude `.gd` files from the analyzer.

Retain those six historical sources as lossless `.gd.gz` data beside their
original manifests. Do not edit their contents to make an old rejected result
look clean. `haul-handling-v1/evidence/historical-source-archives.json` records
both compressed and original hashes, byte counts and original paths. The
original `source-sha256.json` files remain decoded-byte provenance. No active
source, accepted output, replay reader, analyzer option or diagnostic allowance
changes. Extraction and verification are documented in the evidence directory;
the failed CI log remains in the host checkpoint evidence.
