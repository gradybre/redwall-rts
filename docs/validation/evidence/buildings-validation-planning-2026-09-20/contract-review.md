# Buildings contract review — BUILDINGS-S4-VALIDATE-R01 v1

Independent read-only review of the candidate contract, 2026-09-20. No source was
written, nothing was executed, no contract is accepted here. All arithmetic below was
re-derived by hand from the pinned source snapshot and the frozen planning artifacts.

## Verdict

Adopt after the four must-fix items below. The shape arithmetic, the default-versus-
retired union and the case plan are internally consistent and writer-grounded; the
defects found are wording and witness gaps, not structural faults.

## Arithmetic re-derived

Four u8 fields (1024 + 16384 + 81920 + 16384) = 115712 bytes. Twenty-five i32 fields =
9x1024 + 8x16384 + 8x81920 = 795648 elements = 3182592 bytes. Values 3298304, matching
the snapshot. Payload = 3298304 + 29x8 counts + 4 child header + 2x8 extents = 3298556.
Block = 4 + 9 key bytes + 4 + 8 + 8 + payload = 3298589. Offset 4 is correct: only the
u32 store count precedes owner 0. Primary 1024 is the building group alone and must
never be reused as a room or furniture bound; the 16384 room extent coincides with the
section-1 tile count only by accident of ROOM_CAPACITY. Memory: 3298304 + 2x327680 +
3x65536 = 4150272, within the existing 6417408 allowance; 2x3298304 = 6596608 exceeds it
by exactly 179200. Every figure in the contract checks out.

## Case counts audited

frozen-witnesses.json: I counted 170 cases individually — 7 accepts, 8 flag faults, a
30-entry tier-2 type sweep, 12 hall rotation/edge cases, 8 edge-furniture cases, 10
priority cases, and the remaining value/free/state rows. shape 89 = 2 + 29x3. Sampled
field/row witnesses 87 = 29x3. Mutation units 29+4+11+11+10+5+3+1+1 = 75. Metadata 69
cases including exactly 10 schema fault/bypass pairs, 621 = 69x9 assertions. All
reconcile with the contract's claims.

## Geometry witnesses spot-checked

hall (type 12, 12x10): origin 15220 gives x=116, z=118, an exact fit; 15221 and 15348
overflow x and z respectively. At rotation 1 the extents swap to 10x12 and 14966 gives
x=118, z=116, again an exact fit. hearth (type 2, 2x1) at tile 127 overflows in x and
fits at rotation 1. dirt_path (type 6, 1x1) fits at 16383. Rotation parity, exchange of
X/Z on odd rotations, and bounds-before-lookup are all correct as specified.

## Union discriminants

tier==0, r_building_slot==-1 and f_room_slot==-1 occur only in the clear image: every
publish path writes MIN_TIER or a live parent reference, and accepts_tier rejects
anything below MIN_TIER. The never-used branch therefore cannot swallow retired history.
remove_room clears offset/count/mask/valid but keeps type/temperature/occupants;
remove_furniture keeps type/parent/origin/rotation/condition and can only run with a null
user; demolish_building keeps everything except presence and self identity. The
contract's FREE/STATE split matches each of those writers exactly. Refusing to derive
r_valid, refusing to reconstruct the mask, and treating parent and user references as
structural only are all correct for a section-4-local predicate: the self-identity,
chain, arena and tile-map columns are simply absent from these 29 fields.

## Must fix

1. The building STATE tier sentence is ambiguous. "require tier1 or tier2 only for
   typeIDs 5/12/23/29" can be read as permitting tier 1 only for those four types, which
   would refuse accept-building (type 12, tier 1 — and every other ordinary building) and
   contradicts the tier2-type-N sweep. Rewrite as: tier must be 1; tier 2 is permitted
   only when type_id is in {5,12,23,29}.
2. The two detail prefixes disagree by one space: column refusals are wrapped with
   `Buildings owner 0 ` while metadata uses `Buildings owner0 metadata:`. Pin one exact
   literal for each and assert both, or a test will happily pass on the wrong form.
3. Add one accept witness: an inactive building row with tier 1 and a nonnull
   construction reference. demolish_building demonstrably leaves a stale construction
   reference on a retired row, and the contract explicitly declines any construction-
   versus-state implication, but no current case pins that acceptance — so a mutant that
   adds "retired implies construction NULL" survives the frozen set.
4. The allocation gate must fail closed. Require the adapter test to refuse, not pass,
   when OS.get_static_memory_peak_usage is unavailable or when the ballast step does not
   raise current usage above the prior peak. Otherwise a missing API reads as an
   increment of 0, which is below the 1048576 threshold and silently green.

## Should fix

- In the Room clause, state explicitly that a retired row with a retained nonnull parent
  keeps type/temperature/occupants and is accepted only with valid==0; the current text
  implies it but the FREE ordering is easy to misimplement.
- The 6596608 figure compares two full images against a ceiling whose transient terms
  were derived for Construction. Label it as a ceiling test, not a Buildings-specific
  measured peak.
- The flag scan order (b_present, r_present, f_present, r_valid) should be stated as fixed
  and independent of u8 ordinals, so later-flag-before-building-enum cannot be satisfied
  by accident by an ordinal-ordered implementation.

## Correctly declined

No furniture user_slots policy: the public probe (1 test, 16 assertions) shows the current
setter accepts a resident on decoration and interior_partition, so refusing such rows
would reject a representable save. No cross-file liveness, footprint overlap, mask
equality, arena coverage or tile-map reciprocity. No inference of room validity from
furniture, heat or access. No second owner image and no codec coupling inside Columns.
The synthetic 3724-versus-3302692 result is treated as a discriminating method, not as
adapter evidence, and the original Image class-name parse failure is preserved alongside
the corrected run. Nothing in this plan qualifies process RSS, the 100MB world budget, or
any timing claim; the actual adapter, a real benchmark, and BUILDINGS-SAVED-BINDINGS
(Directory self IDs, section 5 chains and arena, section 1 tile maps, mask equality,
construction and user links, loaded tick, common provenance) all remain required.
