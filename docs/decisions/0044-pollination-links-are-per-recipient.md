# 0044 — A pollination slice belongs to one crop tile or one orchard block, not to a designation
Date: 2026-09-10 · Status: **Accepted** (Brendan adopted the READY_06 handoff) ·
Closes: the `HivePollinationLinks` half of **U6** · Source:
`docs/rulings/2026-09-09_ready06_open_item_answers.md` §3

## Decision

`godot/scripts/core/orchard_hive.gd` implements GDD §4.2's `OrchardPlot` and
`Hive` stores, §5.6's orchard and hive arithmetic, REQ-SET-079 through
REQ-SET-083, and the `HivePollinationLinks` table at the ruling's owner-major
index:

```text
recipient_index(FarmPlot typed row p)    = p            # 0..4095
recipient_index(OrchardPlot typed row o) = 4096 + o     # 4096..5119
link_row(recipient, k)                   = 6*recipient_index + k   # k = 0..5
```

Two I32 columns of **30720 references / 245760 bytes**, **+49152** over the
shipped 24576-row table. The owning budget is `docs/systems_architecture.md`
**ARCH-STATE-008**.

## What U6 actually was here, and was not

U6 was a **missing index formula, not missing capacity** — but in this table the
missing formula also meant missing rows. The shipped 24576 rows are exactly
`4096 farm recipients * 6`. They leave the 1024 `OrchardPlot` recipients with no
slice of their own, so any arithmetic that addressed an orchard by its typed row
aliased a farm plot: orchard row 0 wrote over farm row 0's six links. That is why
this closure costs bytes when decisions 0038–0041 mostly did not.

"Six pollination links max per field block" in GDD §4.2 does not say what a block
is. A player designation is 4–256 tiles and is explicitly "a UI/work
aggregation", so it has no fixed row count and cannot own a fixed slice. **A
recipient is therefore one FarmPlot tile or one OrchardPlot block**, which is
what the ruling states and what ARCH-STATE-008 now records.

## Six things settled here

1. **Health filters before the buffer, never after it.** The ruling names the
   error by name: caching the nearest six regardless of health silently drops a
   qualifying seventh hive. `_is_hive_eligible()` is applied inside the selection
   loop, and `test_six_unhealthy_neighbours_do_not_hide_a_qualifying_seventh_hive`
   is the mutation-tested guard on it.
2. **A stale, duplicated or no-longer-eligible slice REFUSES a read; it does not
   repair one.** The ruling says yield and UI reads never repair or mutate links,
   and it says refreshes are synchronous with the committed change. A silent
   downgrade would satisfy neither: it would let a world that skipped a refresh
   keep computing plausible yields forever. `POLLINATION_LINKS_STALE` is a
   refusal on its own channel, never an in-band number.
3. **Validation includes current eligibility, not just liveness.** A hive that
   fell below 5000 without a refresh leaves every reference live and unique, so
   liveness alone would keep paying 1150. Recomputation is the only way to
   discover the opposite direction (a newly eligible hive), and that direction
   can only lose yield, so it stays with the explicit refresh.
4. **`chill_days` is the current winter's count, reset on winter's first day.**
   §5.6 asks for "the previous winter" at an autumn harvest. Winter is the last
   season of the year and every harvest window is in autumn, so the count
   standing in autumn IS the previous winter's completed total. One §4.2 column
   answers the question; a second "previous winter" column would be an invented
   schema field.
5. **Hive strength is clamped to 0..10000.** §5.6 states the 8000 start, the 5000
   healthy line, the 0 abandonment floor and "x strength/10000", but no ceiling.
   Without one, "tended spring days ... restore 300" compounds and a hive
   produces more than the stated 2 U/day. 10000 is §5.6's own denominator and
   §4.1's integer scale — read, not chosen. **A loaded strength above 10000 is
   refused, not clamped**, so a corrupt save cannot enter as a plausible number.
6. **Missing winter feed consumes nothing.** §5.6 gives the 0.5 U/day
   consumption and the 500-strength penalty but not what a partial stock does. A
   day's feed is taken only in whole; otherwise the day is unfed, the penalty
   applies, and the partial stock is left where REQ-SET-083's deficit reader can
   still describe what is owed.

## Dependencies refused rather than invented around

- **There is no Building store.** `Hive.building` is an `EntityRef` to one, and
  the lookup rule needs that building's committed, rotated footprint. The bounds
  are **validated parameters** of `create_hive()` and `set_hive_footprint()`, in
  the manner `farming.gd` takes `pollination_factor` and `fishing.gd` takes
  `base_catch_milli`. The reference is checked for liveness and kind and is never
  dereferenced. No Building store was created and no footprint was fabricated.
- **Vertical and underground pollinator access is undefined.** The ruling says so
  explicitly. Every coordinate here is a horizontal exterior-grid tile;
  **non-surface recipients need an explicit ecology-access rule before
  activation** and none is guessed.
- **`TileHistory.orchard_row` is not written.** It is `farming.gd`'s column, and
  the cross-store join is ARCH-SYS-006's (increment 10). The orchard store keeps
  the inverse (`origin_x`, `origin_z`) and publishes `block_bounds_of()` so the
  join can check farm-tile occupancy. **The consequence is stated, not hidden:
  this store refuses an orchard overlapping another ORCHARD and cannot see a
  FarmPlot at all.**
- **No reverse hive-to-recipient index.** The ruling excludes one from this
  budget. A committed hive change sweeps the live orchard rows here; farm
  recipients are refreshed by the owning join through
  `refresh_farm_links(farm_row, tile_x, tile_z)`, because a FarmPlot's tile
  belongs to `farming.gd`.
- **Farm-side owner reuse is a caller obligation.** The ruling requires the owner
  lifecycle to clear its slice including on typed-slot reuse. The orchard
  lifecycle does that here; `clear_farm_links()` must be called by whatever
  destroys or recreates a FarmPlot. The alternative — an owner-generation guard
  column per recipient, 5120 x 2 int32 = 40960 bytes — is **not** budgeted by the
  ruling, so it is named here instead of allocated.
- **R06-JOB-006's 20-WU hive-service job is not built.** This increment supplies
  the store that producer needs; `job_planner.gd` is not called and no job state
  is written. `HIVE_SERVICE_WORK_MILLI_WU`, `CARE_WORK_MILLI_WU`,
  `NURSERY_WORK_MILLI_WU` and `HIVE_RECOLONIZE_WORK_MILLI_WU` are §5.6's numbers,
  exposed for it.
- **Cross-process save is blocked.** `link_state_bytes()` /
  `restore_links_from_state()` round trip in process and
  `revalidate_orchard_links_after_load()` implements the ruling's
  validate-or-recompute rule, but no header, chunk layout or version field is
  specified for any store, so reading an image written by another process is
  deferred exactly as in `gear.gd` (decision 0038).

## Ledger

The table moves from 24576 rows / 196608 bytes to **30720 / 245760**, a
**+49152** delta, and 120 bytes of six-candidate scratch are counted separately
(distance I64[6] 48, persistent ID I32[6] 24, hive slot/generation two I32[6]
48). Dependent figures in `systems_architecture.md`:

| Figure | Before | After |
|---|---:|---:|
| Auxiliary payload (§3) | 16663388 | 16712540 |
| Planned allocated payload | 59321038 | 59370190 |
| One live world plus reserve | 67709646 | 67758798 |
| Headroom below decimal 100 MB | 32290354 | 32241202 |
| Additional candidate mutable state | 53105454 | 53154606 |
| Transactional peak plus reserve | 120815100 | 120913404 |
| Transactional headroom | -20815100 | -20913404 |

All five stated identities hold on the new figures: `live = payload + reserve`;
`headroom = 100000000 − live`; `candidate = payload − 6215584` (the 3670016
navigation map, 2097152 catalog arenas, 262144 I/O, 131072 UI snapshots and
55200 timing samples); `peak = live + candidate`; `t-headroom = 100000000 − peak`.

**A pre-existing defect in ARCH-MEM-009's trail was found and corrected while
doing this.** The running-total column jumped 291332 bytes at the GearInstance
step against a stated +212996 delta — a 78336-byte gap — because two steps that
the totals already counted were missing from the table: `TileHistory.family_streak`
(+65536, READY_06 §7, recorded at §2.2's TileHistory row and in §3's auxiliary
sum) and `FishingEffortClaim` (+12800, decision 0037, recorded in §2.3's
fixed-registry note). Both rows are restored, in that order, immediately before
the gear step, and every row of the trail now follows from the one above it. No
total changed as a result; only the trail's ability to be checked did. The stale
"32660018-byte headroom" sentence in §3.1 was corrected to the current figure at
the same time.

**A second pre-existing discrepancy is reported here and deliberately NOT
changed.** §2.3's ledger rows sum to 59807822, while "Planned allocated payload"
states 59370190 — 437632 less. The gap is exactly §2.3's `Fixed registry
payload` row (24952146) minus §2.2's own stated fixed-field sum (24514514), and
437632 = 131072 (the claim-ordering cache, "declared separately per
R05-QUOTA-024") + 306304 (decisions 0026/0030) + 256 (decision 0027). So the two
sections count three items differently and the metrics table follows §2.2. That
predates this change, is unaffected by it, and belongs to the decisions that
introduced those three items — this record names it rather than moving someone
else's number.

## Verification

`./tools/run_tests.sh`: **1600 tests, 40141 assertions, 0 failures** (baseline
before this work: 1522 tests / 39387 assertions / 0 failures). 78 new tests.
Every acceptance item in ruling §3 is a named test in
`godot/test/test_orchard_hive.gd`.

**55 mutants, one per `godot` invocation**, each with a 600-second per-run
timeout, each restored from a pristine copy and `sha256`-compared afterwards; the
production file is byte-identical to the pre-mutation copy. The mutated lines
include the recipient-index formula, the six-entry stride, the 12 m squared bound
and its inclusivity, the 5000 health threshold, the persistent-ID tiebreak
(including keying it on the directory slot instead) and both halves of the
null-fill.

**Three mutants initially survived and each produced a new test rather than an
equivalence claim**: shifting the orchard block centre by one tile on x or on z
(the link tests all sat well inside the 12 m range, so the shift was invisible —
`test_the_block_centre_is_the_distance_origin_at_the_range_boundary` now places
hives exactly 12288 units from the block centre on each axis), and making either
disjunction of the block-overlap rectangle test strict (only two of its four
adjacency directions were exercised — `test_a_block_that_only_touches_another_is_allowed`
now plants a legal neighbour on all four sides). All three are killed after the
additions.

**Four mutants were killed only by an `_init` drift assert and were re-run
paired**, with the guarding assert removed in the same invocation, to prove a
value test catches them on its own: `LINKS_PER_RECIPIENT` 6→5 (9 failing tests),
the squared range +1 and the range units −1 (the boundary test, after it was
given the two constants to assert directly — the units constant previously had no
consumer but the assert), and the footprint-centre formula losing its half-tile
term (5 failing tests).

## Consequences

- Increment 8 of `docs/tasks/03_ecology_crops_weather.md` is closed; increments 9
  and 10 can join this store to weather, jobs and inventory.
- `farming.gd`'s `pollination_factor` parameter now has a source:
  `farm_pollination_factor_into(farm_row, crop_id, out)`. `farming.gd` is
  unchanged by this work and is not called from the new module.
- U6 still stands for MoodMemory, ManualTask, `Feast.attendees` and
  `Feast.reserved_lots`.
- GDD §4.2's "six pollination links max per field block" wording is left as
  written; the recipient interpretation is recorded in ARCH-STATE-008, which is
  where the ruling permits it to live. Amending the GDD text itself is a
  documentation task this decision does not take unilaterally.
