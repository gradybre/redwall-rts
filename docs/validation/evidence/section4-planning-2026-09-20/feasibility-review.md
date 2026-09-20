# Section 4 codec feasibility review — 2026-09-20

Read-only. Sources: `astra-feasibility-questions.md`, `fixed-column-census.json`
(base `e8985336`, registry 6), `representative-owner-sources.md`, SAVE-LAYOUT-R01 /
RESTORE-R01, REG-R01 / PROV-R01 / NAME-R02, decision 0122, `save_codec.gd`,
`save_section_directory.gd`. No file was edited, nothing was executed, and no
test, measurement or save-parity result is claimed.

## 0. Census arithmetic independently reproduced

Block wrapper is `24 + len(owner_key)` (4 key length + key + 4 schema + 8
primary_count + 8 payload length) plus `8` per field for `element_count:u64`.

* buildings: 29 fields, key 9 bytes -> `24+9+29*8 = 265`; `3,298,304+265 =
  3,298,569` = census `ordinary_block_bytes`. The rule holds for all 18.
* Sum of the 18 `ordinary_block_bytes` = `12,947,449`; `+4` for `store_count:u32`
  = **12,947,453** = census `ordinary_section_bytes`. Confirmed.
* Field count: 29+16+15+20+22+20+11+38+16+20+25+4+19+10+6+9+9+9 = **298**.
* Census owner order is already ASCII (`farming` < `field_policy` < `fishing` <
  `forage`; `residents` < `resource_nodes`), matching SAVE-LAYOUT-R01.

## 1. Mapping, conflicts, child extents and exact bounds

### 1.1 Remaining source/authority conflicts

1. **`SECTION_1_PRIMARY_COUNT` is not section 4's.** `buildings.gd:1756` and
   `forage.gd:3001` both declare `SECTION_1_PRIMARY_COUNT = TILE_COUNT` (16384)
   for their section 1 tile-map blocks. The proposed section 4 primaries are
   1024 and 128. One owner key legitimately carries different primary counts in
   different sections (REG-R01's section 1 / section 3 `entity_directory`
   precedent), but section 4 must not reuse these constants or their names.
2. **`fishing.gd:264` `CANONICAL_OWNER_SCHEMA_VERSION = 2` is section 7's**
   ("the section 7 `fishing` owner schema"). The census gives fishing section 4
   `owner_schema_version: 1`. A codec that read the module constant would emit 2.
3. **buildings carries no owning-directory reference in section 4.** Its 29
   census fields exclude `_b_ref_slot/_b_ref_generation`, `_r_ref_*`, `_f_ref_*`
   and every chain link, while residents (ordinals 11-12) and jobs (16-17) do
   include theirs. `residents.restore_columns()` and `jobs.restore_columns()`
   use that pair as *the* validator; a buildings section 4 block has no
   equivalent and cannot self-validate against the directory.
4. **Two declared derived caches are in the census.** `fishing._habitat_effort_used`
   (ordinal 12) has `rebuild_effort_aggregates()` / `validate_effort_aggregates()`;
   `forage._zone_quota_reserved_milli` (ordinal 12) is documented "a DERIVED
   CACHE, maintained atomically and rebuilt from active claims". Persisting them
   creates a second authority for a value section 7 already rebuilds.
5. **Reserved-allocation columns are in the census.** jobs `_agent_path_id`,
   `_agent_path_cursor`, `_agent_lease_expiry`, `_agent_blocked_tick`,
   `_agent_manual_until` are "Reserved allocation only" (GAPS), and
   `needs._departure_days` is "Reserved and explicitly zero". jobs already has
   `REFUSE_COLUMN_RESERVED_NONZERO`; the other owners have no such gate.
6. **jobs' section 4/5 split is already frozen in source.** `jobs.gd:2396`
   `SECTION4_COLUMN_COUNT = 38` and `:2435` `SECTION5_COLUMN_COUNT = 4`
   (`_coordinator_slot`, `_coordinator_generation`, `_member_head`,
   `_member_next`). The census's 38 jobs fields match and exclude all four.
   This is the precedent shape; buildings' chains have no such declaration.
7. **residents 19 / needs 20 agree with source.** `residents.gd:1761`
   `COLUMN_COUNT = 19`, `needs.gd:1714` `COLUMN_COUNT = 20`, both schema 2 in
   the census, matching REG-R01's "resident2". No conflict.
8. **`descriptor row_count` for a multi-owner section is unresolved.** Decision
   0122 recorded this open for section 7's six owners and published no
   `descriptor_row_count()`. Section 4 has the same gap across 18 owners; the
   sum of 18 unrelated capacities is a number with no meaning.

### 1.2 Child extents: reuse the section 7 form, exact cost +112 bytes

REG-R01 requires explicitly validated child extents and forbids inferring an
extent from a column. Declaring `child_extent_count:u32` for **every** owner,
including zero, is the correct reading: it makes "this owner has no second
table" an emitted fact rather than an absence, and it keeps the reader's per-block
loop uniform. Cost:

* `18 * 4 = 72` bytes of `child_extent_count`.
* `5 * 8 = 40` bytes of declared extents.
* Total **+112**; section becomes **12,947,565** bytes.

Affected blocks: buildings `3,298,569 -> 3,298,589` (+4+16); field_policy
`44,484 -> 44,496`; jobs `685,900 -> 685,912`; orchard_hive `102,636 -> 102,648`
(each +4+8); the other 14 owners +4 each (+56).

Exact child counts and resulting bounds, each checked against its compiled
constant before allocation (decision 0122's `child_extent_maximum_of()` shape):

| owner | children | primary | child extents | source |
|---|---:|---:|---|---|
| buildings | 2 | 1024 | 16384, 81920 | buildings.gd:93-95 |
| field_policy | 1 | 128 | 4096 | field_policy.gd:242,246 |
| jobs | 1 | 8192 | 512 | jobs.gd:280,282 |
| orchard_hive | 1 | 1024 | 1024 | orchard_hive.gd:211,213 |
| other 14 | 0 | table capacity | — | census `capacity_source` |

orchard_hive declares its extent **despite equality**: `ORCHARD_CAPACITY` and
`HIVE_CAPACITY` are two independent literals, so a future divergence would
otherwise silently alias two tables onto one count.

Fishing and forage are correctly **not** child extents: `FISH_STOCK_CAPACITY =
FISH_HABITAT_CAPACITY * SPECIES_PER_HABITAT` (fishing.gd:255) and
`FORAGE_PATCH_CAPACITY = HARVEST_ZONE_CAPACITY * PATCHES_PER_ZONE`
(forage.gd:265) are derived products, not independent capacities.

Seven fixed-stride relations must be validated as `element_count == extent *
compiled_stride`, never read from the wire: fishing 3 (96), forage 5 (640),
field_policy `_rotation_ids` 3 (384), needs 5 (2560), residents 12 (6144),
priorities 12 (6144), schedule 24 (12288), work 12 (6144).

### 1.3 Declaration refinement vs schema bump

Registry 6 gives section 4 version **2**, which REG-R01 attributes to the
LifeStage semantic change, not to any framing choice. **No section 4 bytes have
ever been emitted** (no production codec exists). A framing addition to a never-
emitted section is a declaration refinement, so freezing child-extent framing
inside schema 2 is defensible and no bump is justified by these 112 bytes alone.
This is a ruling call, not an implementer's: see R2 below.

## 2. Streaming: reusable helpers, bounded interfaces, and the three peaks

### 2.1 What already exists and can be reused unchanged

* `save_codec.gd`: `Writer` / `Reader`, `read_u8/u32/i32/u64/i64_into`,
  `write_*`, `read_bytes_into`, `read_utf8_u32_into`, `zero_padding_refusal`,
  `u32_bits_to_int32`, `Scalar` / `Text`, sticky reader failure, and
  allocate-before-consume in `read_bytes_into` (count validated before
  `out.resize()`). Explicit signedness on every 4- and 8-byte read is what makes
  the `00 00 00 80` generation trap a refusal.
* `save_section_directory.gd`: `Chunk`, `ColumnCursor`, `ChunkCursor`,
  `EncodeResult`, `CHUNK_BYTES = 65536`, `byte_order_refusal()`,
  `field_count_offset()` / `field_value_offset()`, `extent_refusal()`,
  `section_length_refusal()`, `canonical_type_of()`.
* `save_header.gd`: incremental `crc32_update()`, `Refusal`, `ENDIAN_SENTINEL`.

Gaps: `ChunkCursor` is single-owner and hard-codes one framing block. Decision
0122 records that a multi-owner variant was implemented for section 7's six
owners; that file was not supplied here, so this review does not assume its
shape beyond what 0122 states.

### 2.2 Proposed bounded interfaces

* `OwnerCursor(record, owner)` — field-aligned runs of one owner's declared
  field list; no chunk straddles two columns.
* `SectionCursor(record)` — `store_count` chunk, then 18 `OwnerCursor`s in ASCII
  order. `emitted_bytes()` must equal the computed section length **exactly** at
  drain; that equality is the EOF proof, and it is what section 3 already does.
* `owner_extent_refusal(bytes, offset)` and `section_extent_refusal(...)` —
  bound-before-allocate, callable by a coordinator before any staging exists.
* `decode_owner_into(bytes, offset, owner, out)` — per-owner decode, so a caller
  need never stage 18 owners at once.

`decode_into(bytes, ...)` taking the whole buffer does **not** multiply it:
`SaveCodec.Reader` stores the `PackedByteArray` and only ever moves `_cursor`;
GDScript packed arrays are copy-on-write and the reader never mutates. The real
transient is `save_section_directory._read_columns()`'s per-field
`bytes.slice()` plus `to_int32_array()`. Largest single section 4 field is
construction `_remaining_mwu` at **663,552** bytes, so that transient peaks at
about **1,327,104** bytes — bounded, and independent of the 12.9 MB total.

### 2.3 Staging peaks against the 78.393899 M live+reserve

| strategy | staged bytes | share |
|---|---:|---:|
| whole-section Record (all 298 columns) | 12,944,480 | 16.51% |
| per-owner Record (worst: construction) | 4,893,696 | 6.24% |
| per-field staging (worst: `_remaining_mwu`) | 663,552 | 0.85% |

`encode_record()` concatenation adds a second full copy and must be reserved for
fixtures. A disk path drives `SectionCursor` and never calls it.

### 2.4 Three distinct claims, kept separate

1. **Byte framing validity** — counts, key, schema, primary_count, child
   extents, per-field `element_count`, exact block consumption, exact section
   EOF, little-endian probe. Testable **today for all 18** with no live store.
2. **Semantic validity** — per-owner domains, occupancy, free-row blanks,
   cross-column invariants. Testable today **only for jobs, residents, needs**.
3. **Save-ready proof** — capture from and apply to a live store, plus canonical
   digest membership. Needs the 15 missing owner APIs and a section 15 ruling.

No interface below should be described as save-ready until (3) holds.

## 3. Normalization: concrete lifecycle facts, and what gates exist

Blanket zeroing and a guessed `-1` are both wrong, each disproved by source:

1. **`field_policy.destroy_policy()` (field_policy.gd:724-743) deliberately
   does not reset `_cycle_ordinal`**: "`_cycle_ordinal` stays where it is and is
   never reset, so every stamp written under this policy fails the ordinal check
   for whatever policy occupies the row next." Zeroing it on load would make
   every stale plot enrolment valid again. It also leaves `_rotation_ids`,
   `_auto_rotation`, `_seed_reserve`, `_withdrawn`, `_completed_cycles`,
   `_cancelled_cycles`, `_close_reason` and the whole plot ledger untouched.
2. **Non-zero declared blanks exist.** `field_policy.clear()` fills
   `_seed_reserve` with `1` (`DEFAULT_SEED_RESERVE = true`); `needs.clear()`
   fills `_status` with `STATUS_DEAD = 5` and `_free_row_is_clear()` requires
   it; `jobs._clear_job_row()` writes `URGENCY_ORDINARY = 3`.
3. **Mixed `-1` and `0` within one owner.** `field_policy` blanks
   `_rotation_ids` to `NO_CROP` and `_plot_field_slot` to `NO_FIELD = -1` but
   `_rotation_cursor`/`_cycle_state`/`_close_reason` to 0. forage blanks
   `_patch_item_id` and `_claim_patch_kind` to `-1` but `_zone_type` to 0 and
   `_zone_quota_mode` to `QUOTA_MODE_AUTOMATIC = 0`. buildings blanks
   `_b_origin_tile`, `_b_interior_id`, `_b_construction_slot` to `-1` and
   `_b_type_id`, `_b_tier`, `_b_state` to 0.
4. **Fishing: `destroy` and `clear` disagree.** `destroy_habitat()`
   (fishing.gd:1050-1072) clears present, both ref pairs, zone pair,
   `_habitat_capacity_milli` and `_habitat_intensive`, but leaves
   `_habitat_type`, `_habitat_effort_slots`, `_habitat_pollution`,
   `_habitat_danger`, `_habitat_protected_fraction` and `_habitat_effort_used`
   at the last tenant's values — while `_clear_habitat_columns()` zeroes all of
   them. Two observably identical worlds can therefore differ in bytes. This is
   exactly decision 0122's inventory retired-row finding, in a second store.
5. **orchard_hive is the opposite case.** `destroy_hive()` blanks every hive
   column (`SPECIES_NONE`/`NO_ROW`/`NULL_SLOT`/0), so hive rows *do* reach a
   canonical blank. Treatment is inconsistent across owners, not across a rule.
6. **residents mixes stage and equipment blanks.** `_size_class = SIZE_SMALL`,
   `_life_stage = LIFE_STAGE_ADULT`, `_role = ROLE_RESIDENT` are 0, but
   `_equip_tool_item_id = NO_TOOL_ITEM = -1` and both ref pairs are
   `(NULL_SLOT, NULL_GENERATION)`.

Conclusion: every unused value is **declared per column by its owner**, exactly
as SAVE-LAYOUT-R01 requires ("Use zero only where the owner declares zero").
No blanket rule is defensible, and no domain rule can be frozen from the
registry list alone.

### 3.1 Public gates available today

* **jobs.gd** — `copy_columns_into()`, `restore_columns()`,
  `SECTION4_COLUMN_KEYS/TYPE_CODES/EXTENTS` (38), `SECTION5_*` (4),
  `last_column_refusal()`, `_free_job_row_is_clear()`,
  `_free_agent_row_is_clear()`, `validate_job_definition()`.
* **residents.gd** — `copy_columns_into()`, `restore_columns()`,
  `COLUMN_KEYS/TYPE_CODES/EXTENTS` (19), `restore_name()`,
  `name_occupancy_refusal()`, `last_column_refusal()`.
* **needs.gd** — `copy_columns_into()`, `restore_columns()`,
  `COLUMN_KEYS/TYPE_CODES/EXTENTS` (20), `_free_row_is_clear()`.
* Adjacent but **not** section 4: buildings/forage
  `copy_section_1_columns_into()` / `restore_section_1_columns()` /
  `section_1_local_refusal()`; fishing/forage claim-column copy/restore and
  `validate_effort_aggregates()` (section 7); orchard_hive
  `restore_orchard_state()` / `restore_hive_state()` / `restore_links_from_state()`
  (per-row, not column-level); fishing `restore_effort_claim()` and forage
  `restore_claim()` (both marked legacy-only).

### 3.2 Source still needed — 15 owners, of which 10 unseen

No section 4 column API: **buildings, construction, farming, field_policy,
fishing, forage, injury, movement, orchard_hive, priorities, resource_nodes,
schedule, transforms, work, world_init** (15 of 18).

Not supplied at all in this packet: **construction.gd, farming.gd, injury.gd,
movement.gd, priorities.gd, resource_nodes.gd, schedule.gd, transforms.gd,
work.gd, world_init.gd** (10 files, 124 of the 298 fields). For the five
multi-table owners that *were* supplied, the `clear`/`destroy`/allocate sections
are present but no column capture/restore exists to review.

## 4. Recommended bounded order

* **S4-A (envelope subtask, explicit).** Framing constants, ASCII owner order,
  child-extent declaration, layout arithmetic, `OwnerCursor`/`SectionCursor`,
  per-owner and whole-section extent refusals, decode-with-exact-EOF, and
  framing-level tests including pinned bytes and a byte-order probe. Zero owner
  semantics. Completable now. **SAVE-S4-CODEC remains incomplete after this.**
* **S4-B.** Wire jobs, residents and needs end to end through their existing
  `copy_columns_into` / `restore_columns`, proving the owner-record contract
  against real APIs before 15 more are written to it.
* **S4-C.** Add the missing column APIs in the jobs/residents/needs shape,
  least-coupled first: transforms, world_init, movement, priorities, schedule,
  work, injury, resource_nodes, farming, construction; then the five
  multi-table owners: buildings, field_policy, fishing, forage, orchard_hive.
* **S4-D.** Per-owner semantic validators and explicit free-row blank
  enumerations, one per owner, mirroring `_free_job_row_is_clear()`.
* **S4-E.** Capture/apply round trips against live stores. Only here does claim
  (3) become available. File binding, coordinator, rollback and canonical digest
  stay **out of scope** — that is the full-coordinator scope creep to avoid.

## 5. Items requiring a versioned Astra ruling

* **R1.** Section 4 owner-key registry; per-owner `primary_count`; which table
  is primary for buildings, field_policy, jobs, orchard_hive; whether
  orchard_hive declares an extent given equality (this review recommends yes).
* **R2.** Does child-extent framing enter schema **2** (recommended — no bytes
  shipped) or force **3**?
* **R3.** Buildings' own directory ref pairs and intrusive chains: section 4,
  section 5, or unassigned — and why residents/jobs carry theirs in section 4.
* **R4.** Canonical unused values per owner, and whether fishing's
  destroy-vs-clear residue divergence is refused, normalized, or accepted with
  the question deferred to section 15 (decision 0122's inventory precedent).
* **R5.** `descriptor row_count` for a multi-owner section (18 owners here; left
  open for section 7's six).
* **R6.** Are `fishing._habitat_effort_used` and
  `forage._zone_quota_reserved_milli` persisted or rebuilt? Both are declared
  derived caches with existing rebuild/validate helpers.
* **R7.** Reserved-zero enforcement for jobs' five reserved agent columns and
  `needs._departure_days`, and the compatibility path when those features land.

This review makes no claim that any interface above was built, run or tested.
