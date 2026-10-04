# ADR1143 — additive source-motion catalog

The component preserves all accepted1139/1142 source geometry in two bounded,
source-only banks. It never authorizes travel, support, a renderer or a gameplay
rate. No existing runtime consumer, Profiles, Levels, Budget or World file
changes. Root owns eventual shared admission and actual traversal integration.

Base: own branch `codex/underground-motion-catalog`, HEAD `4e0d2811` (merge of
accepted integration `fa017ba4`). The separate design is committed `54cf571c`;
Furnishing independently reproduced all26 design input pins and the complete
census without a high/medium finding. Runtime review is a distinct gate.

## Exact implementation

New `underground_motion_catalog.gd` keeps three field-major typed buffers per
bank:17,421 I32,67 I64 and640 B8 =70,860 bytes. They retain every semantic table:
5 programs,3 actor images,635 keys,630 intervals,1,029 complete body/tool boxes,
428 full-foot support rows,630 support references,66 original fixture-solid
rows, explicit source/coordinate/program identities and4 exact joins. There is
no per-actor row, retained JSON, full wire image or cross-artifact deduplication.
The actual caller must own one jointly admitted catalog; arbitrary extra
instances are not a valid composed World allocation.

`configure(actual_profiles, actual_levels, arena_bytes)` checks configured
Profile capacities, actual exact published Profile geometry/current cached
consumer closure, original Level image/domain and full live World identity.
The complete allocation is checked before either large motion bank is sized.
Original object/bank/revision/domain/digest/World generation/PID/typed-row facts
remain mandatory for every geometry read. Real Profile reload or World reuse
refuses. Source consumer closure is observed on cold configure/load; no hot
callback or source hashing is introduced. This version has no runtime consumer
that can interpret readable metadata as permission.

`load_file(path, expected_sha, 1)` accepts only the pinned exact source wire.
Decoding writes the inactive bank through a maximum4,096-byte stream window.
Each chunk is read/copied within its own helper returning only StringName;
every packed alias dies with that frame before another chunk is allocated.
The stream and column frames retain only fixed headers. This lifetime is
source-checked, not inferred from loop-local scope. The
fixed column counts and file size precede indexing. The same opened file feeds
the digest. A changed image with a newly supplied matching hash still refuses,
because that hash does not equal the published source identity. Any failure
leaves the published revision/bank untouched. A valid retry is possible before
success; source replacement after the first success is deliberately closed.

The current wire is `motion-catalog-v1/candidate-2/motion.ugmotion`,70,936 bytes,
SHA256 `495b22dacb303152651f8ca061a0017aa72a4031e281ac1df34dd9035bf695a0`.
The offline packer verifies ten exact input images/reports, complete table
shapes, source keys, stationary intervals,22 canonical fixture primitives under
all source transforms, source clip timing and all four root/heading/pose joins.
File reads are bounded before parsing and again at read. Its deterministic
output is byte-identical to that wire. No original proof or source artifact is
edited. Candidate1 is retained history; candidate2 additionally binds complete
handoff recipes in its legacy program digests.

## Read-into contract

All outputs are fixed caller-owned arrays, checked before any write. Source,
revision, range or shape refusal leaves the caller's full packet unchanged.
There is no returned alias to a retained array.

| Method | Output | Meaning |
|---|---|---|
| `identity_into(revision,out)` |20 I64 | Exact header, including absent geometry/renderer/consumer qualification |
| `digest_into(selector,revision,out)` |32 B8 | One of12 source/proof digests; zero is unbound, never a wildcard |
| `program_into(program,revision,out,longs)` |20 I32+7 I64 | Exact source/clip/equation/frame mapping and explicitly unbound future Profile/variant/rate |
| `source_into(source,revision,out,digest)` |4 I64+32 B8 | Original actor image SHA/revision/clip count, absent certificate/flags |
| `clip_metadata_into(program,revision,out)` |4 I32 | Absolute first frame, count, nonloop mode, authored source duration Q16 |
| `phase_into(program,revision,phase,out)` |9 I32 | Fixed-fixture XYZ, heading, source, clip, absolute frame pair and Q16 share |
| `join_into(ordinal,revision,out)` |4 I32 | From/to program, exact terminal/entry source keys |
| `interval_box_into(program,revision,interval,role,out)` |6 I32 | Complete body(0) or held-tool(1) interval box, root motion already included |
| `interval_support_count(...)` |integer | Exact full-foot obligations; negative is refusal |
| `interval_support_into(...,ordinal,out)` |8 I32 | Foot, canonical source solid, support plane, complete XZ enclosure, witness vertex |
| `primitive_into(program,revision,ordinal,out)` |6 I32 | One of22 exact canonical fixture solids |
| `primitive_mapping_into(program,revision,ordinal,out)` |6 I32 | Component, source solid, canonical ID, timber/natural kind, authored part, assembly |

Programs0/1 are ascent/descent;2/3/4 are approach/turn/retreat. Only the exact
nonlooping91/91/91/271/91-key images are admitted. Shares are0..65535; terminal
is `(last,last,0)`. Gait root uses signed local ceil before its certified fixed
quarter-turn. Handoff root stays in the fixed program frame while unwrapped
body heading uses the same phase and signed ceil. Stationary-root intervals
still advance the source pose. Complete interval boxes already include root;
a consumer must not translate by it again.

Header and descriptor field names are in the committed design `census.py` and
ADR1143. `activation_refusal()` always returns `MOTION_SOURCE_ONLY`. The three
rate fields, renderer/consumer qualification and backend remain zero; future
Profile/variant are-1. Source duration is preview/source metadata. Brendan has since approved ADR1145's
initial Natural timing:30 fixed ticks per tread and45 per supported half-turn at
1x for the initial unloaded adult mole with its existing pick. That separate
timing authority does not change this frozen source-only image or reader. A later actual traversal
must resolve live paid geometry, supports, endpoints/retreat, profile/gear,
source-phase state, renderer and accepted pace together.

## Complete simultaneous storage

`census.py` rejects unexpected members, bases, bank widths/counts, repeated
resize calls and constructor changes. It reproduces `census.json`:

- two motion banks141,720;
- retained owner numeric/packed controls250;
- shared numeric constant payload432, conservatively charged per owner;
- maximum own declared numeric chain144; small simultaneous payloads136 and
  expression/result allowance128 give1,090 inside the4,096 logical/helper
  reservation;
- decode4,096 and caller176 are separate; no full-file or `to_byte_array` copy;
- native/reference/Variant/array/interpreter reservation32,768 remains
  provisional and unmeasured. The inventory of handles/temporary owners is
  explicit in the census. It is not an allocator result.

Actual configured Profiles18/194/1 cost47,288, including their existing32KiB
control reservation. Their cold source/hash helpers use that reservation once.
Levels remain2,292. The complete formula is:

`47288+2292+141720+4096+176+4096+32768 =232436 <=262144`.

The unchanged global Profile maxima256/3072/64 would instead compose to444,284
and refuse. Current smaller loaded content in oversized configured banks cannot
hide their capacity. There is no increase to the global100MB gate or the
PROFILE_BYTES reservation. Single-world admission integration and native
measurement remain open. Test-only actual ActorContent readers have a separate
presentation reservation, are loaded sequentially, and are never retained by
Motion or counted as free motion storage.

## Verification and retained failures

Candidate4 ran through clean import and the ordinary strict singleton shard
runner with a temporary isolated `Redwall-ug-motion-catalog` user directory and
port6315. Every source/project/registry/assets restoration check passed.

| Strict suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| MotionCatalog |15|13,671|0|
| Profiles |25|601|0|
| Levels |10|179|0|
| Published mole Profiles |8|227|0|
| Total |58|14,678|0|

Every strict/raw unexpected/expected/tolerated diagnostic and leak count was0.
The analyzer reported0 warnings in the2 changed GDScript files. All630 intervals
retain complete body/tool/full-foot records. Every interval's first, near-first,
middle and last fractional phase matches the actual ActorContent source frame
pair/share; all terminals and four joins match. Tests cover actual World reuse,
real Profile revision advance, another valid Level image, actual cached consumer
text drift/refusal/retry, no output alias, source-once refusal, malformed finite
wire, forged caller digest and configured-capacity refusal before allocation.
The synthetic busy-control probe is labeled; it grants no geometry permission.

`packer-tests-3.log`:11 Python tests pass, including deterministic exact output,
complete source counts/joins, stationary/heading/primitive mutations and bounded
ordinary input/fresh output handling. `unchanged-consumers.json` pins all eight
production consumer files plus the additional Level/Budget sources (10 unique
files), byte-equal to the accepted base.

Retained rejected attempts: check-only2 exposed invalid packed constant
initializers; candidate1/2 stopped at diagnostic registry coverage before any
engine suite; a runner source edit briefly introduced an invalid Unicode byte
literal and was corrected before candidate3; candidate3 passed10/5522 runtime
assertions but the analyzer rejected a test local shadowing `RefCounted.reference`.
The earlier Python failure was an unresolved macOS temporary-root alias in the
test fixture, corrected to resolve the test root. No diagnostic threshold was
relaxed. The root-owned shared registry is unchanged; the harness's exact
metadata append is diagnostic only, including accepted1140 pending ledger rows.

## Independent review and corrected decoder lifetime

Furnishing reviewed the exact eight candidate4 source/UID/tool pins, independently
ran all11 packer tests, rebuilt the70,936-byte wire and manifest byte-identically,
reproduced the original census and checked all10 unchanged-consumer/base pins.
It found one MEDIUM blocker: Godot retains the old loop-local PackedByteArray
while evaluating the next read. Two4,096-byte payloads could coexist, so the
initial232,436 admission understated loading by4,096. Candidate4 remains valid
functional evidence but is rejected as a loading-lifetime qualification.

The exact eight rejected sources and old census are in `source-review-1/`.
The reviewer's engine proof is pinned to Godot
`ed1daf0bf001b61586d9930840f2f1394092c079`: GDScript initializer/loop cleanup and
packed-return temporary lifetime require an explicit call-frame boundary.
The correction uses `_decode_payload` returning only StringName; no packed
return or retained alias can cross back into the loop. The complete decoder
numeric chain is104 bytes, below the unchanged144-byte maximum. All retained
bank/control sizes, the4,096 decode reservation and232,436 joint total remain
unchanged.

`test_evidence.py` passes7 focused Python tests: the new frame boundary is
accepted, the exact rejected source is refused, and loop payloads, escaped
aliases, copied buffers and a larger window refuse. The LOW harness finding is
also closed: exit-zero raw import errors/warnings/parse aborts and both singular
and plural leak forms are rejected. Candidate4's actual raw import was already
clean; its log is a positive test input.

Corrected `candidate-5/` reran the affected Motion suite:15 tests /13,671
assertions /0 failures, all strict/raw unexpected/expected/tolerated diagnostics
and leaks0, clean-import raw guard0, analyzer0/2. Source, project, registry and
assets restoration are all true. The other three candidate4 suites and unchanged
packer/native evidence were not redundantly rerun. The nine current executable
pins (including the new evidence test) were independently accepted by Furnishing.
It rechecked9/9 pins before/after, reran all7 new evidence tests and reproduced
the corrected census byte-identically, with no remaining high/medium finding.
The original eleven packer tests and exact wire/manifest replay stand. The
reviewer's retained packet is
`../underground-motion-independent-review-2026-10-04/`; no duplicate engine run
or foreign worktree edit was performed during that review. The exact received
scope and pins are recorded in `independent-review.json`.

These component checks do not qualify native RAM, movement, timing,
presentation or the complete game.
