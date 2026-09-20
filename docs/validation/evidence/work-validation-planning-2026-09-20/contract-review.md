# Work owner16 contract review — WORK-S4-VALIDATE-R01 draft1

2026-09-20. Independent final review before author intake. Not an acceptance: one blocker and
three clarifications must be resolved first. Everything else below re-derives clean.

## Blocker

**B1 — the pinned owner version is wrong.** The contract and `metadata-fault-plan.md` both state
owner16 `work` version1. The compiled schema declares `OWNER_VERSIONS[16] = 2`. A bridge pinning
version1 refuses every valid frame at gate4, and the planned "Version16 to2" fault becomes a
no-op that proves nothing. Pin 2, and make that fault 1 or 3. No other value moves.

## Clarifications

- **C1 — u8 accessor.** Field8 `_tool_broken` is u8. The only existing bridge
  (`save_owner_world_init.gd`) uses `i32_column`/`i64_column` only. Confirm `Section.FramedOwner`
  publishes a u8 accessor and that `owner_shape_refusal` validates the u8 bucket. If not, that is
  a Section change and sits outside the author's two-file scope.
- **C2 — memory-shape mutant kill path.** "Ignore memory extent" is killable only by calling the
  static predicate directly with a wrong-length memory column; through the bridge, gate5 refuses
  first. Name that direct static witness explicitly, or the 21st mutant survives.
- **C3 — unverifiable source pins.** `RESIDENT_CAPACITY512`, `SKILL_COUNT12`,
  `JobsScript.JOB_CAPACITY8192` and `InventoryScript.LOT_CAPACITY16384` could not be re-derived
  here: needs.gd, residents.gd, jobs.gd and inventory.gd are not in this packet. They stay on the
  independent source-capacity audit, not on this review.

## Re-derived and confirmed

- Nine fields, canonical order, 8 i32 then 1 u8, keys and counts matching schema indices 280..288;
  `_xp_remainder` 6144, every other column 512. Field begin280/count9 agree.
- Value bytes 9728*4 + 512 = 39424; payload 4 + 72 + 39424 = 39500; block 24 + 4 + 39500 = 39528;
  12892567 + 39528 = 12932095, the declared owner17 offset.
- Domains match the writers: potential 0..999, XP 0..999, reserved index3 exactly0 at every
  `resident*12+3`, wear 0..9999, broken 0..1, lot slot 0..16383, job slot 0..8191, generations >0,
  exact (-1,0) null, paired null/bound, unbound implies broken0. Memory is any signed int32 at any
  physical row, with no value gate. Typed-store handles, not Directory handles — correct.
- Retained carries, stale current-job bindings and retained broken bindings are legal history; no
  local uniqueness scan. Full-world Work/Gear/Jobs/Inventory/resident coherence stays deferred and
  is stated as such. No live projection, constructor, scratch column or repair path is proposed.
- Diagnostic `state_bytes()` is potential, memory, XP; the probe's offsets 2048 and 4096 confirm
  it. Remapping to canonical XP-before-memory for fixtures only, leaving the diagnostic alone, is
  correct and must stay labelled equality-test data.
- Mutant census: 8 zero accessors (memory excluded) + 9 value clauses + memory extent + 3 order
  reversals = 21. The memory-zero substitution is genuinely equivalent while every int32 is legal;
  excluding it and source-reviewing the mapping instead is right, and no fabricated memory value
  restriction appears anywhere. No source assertion is described as an executable kill.
- Metadata faults: the fauna transfer moves 1536 value bytes + 8 count = 1544; Work's first nine
  descriptors are unchanged with the extra descriptor last, so a bypassed count guard cannot fall
  into a per-field refusal; 298 descriptors and the section total hold. Primary 513/383 preserves
  896. Child 10->16 gives begins 11..16 = 4, offsets 11..16 -8, payload 10 -8 / 16 +8, offset17
  unchanged. Type i32->i64 is +2048 and extent 512->513 is +4, both added to payload/block16,
  offset17 and both section totals. 18 cases at 9 assertions is 162.
- Constant chains are feasible: Work already exposes `GearScript`, `InventoryScript`, `JobsScript`,
  `EntityDirectory`, `NULL_SLOT` and the four numerators as consts, and the world_init bridge sets
  the precedent for reading a chained constant without construction.
- Preload closure is 22 nodes and contains only the pre-existing IntMath and SaveCodec self-loops;
  `save_owner_work.gd` is a new unreferenced root, so no new bridge cycle. Engine import still owed.
- Probe: 217 assertions, 0 failures, with 40 accepted / 800 / 40 / 40 from factor510 arithmetic.
  Its 28 leaked objects and 5 resources at shutdown are recorded; this is not a clean teardown and
  no performance or lifecycle claim follows from it.
