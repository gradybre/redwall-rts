# Task 09 — Persistence, replay and recovery

2026-09-09 · PLANNED milestone card; schema ownership begins at task 04.
Owners: REQ-SET-158–162, architecture §8 ARCH-SAVE/ARCH-CMD/ARCH-MEM-006,
ARCH-SYS-022, crowd determinism contracts, MOVE-REQ-016, MOVE-TEST-06 and task-09
CSV requirements. Read actual IDs/sections for exact field, version and refusal
rules; this card does not replace the binary schema.

## Dependencies and work

- [x] 09.1 Maintain a future-affecting-state registry as every store arrives:
  columns/widths, null/unused representation, allocator generations/retirement,
  child indexes, RNG, pending commands/scheduler events, clocks/leases/claims,
  route/cache/search state, cargo/WIP, memories, scenarios and family state.
  Fix pending scheduler serialization with 04.1; expanded movement version and
  migration/rejection matrix with MOVE-G02. Do not silently repurpose v1 bytes.
  *Done 2026-09-11 (decision 0062):* `docs/persistence_state_registry.md` covers
  all 36 modules under `godot/scripts/core/` -- 275 rows over 541 declared packed
  columns -- and `docs/validation/state_registry_coverage.py`, run by
  `tools/run_tests.sh`, fails the build when a store lands without a row or a
  width/count stops matching the GDScript. **Still open inside 09.1:** three
  UNRESOLVED rows (the command result ledger's eight columns, and
  `inventory._c_reachable`); pending scheduler serialization remains unwired
  pending 04.1's caller, which is 09.2's `SCHQ0001` writer; and the expanded
  movement version plus migration/rejection matrix stays with MOVE-G02, so the
  reserved zero columns are recorded do-not-repurpose rather than versioned.
- [ ] 09.2 Implement canonical little-endian sections and complete validation,
  hashes, bounded reads and overflow checks. Preserve rule/catalog/map/lookup/
  engine identity. Reject incompatible v1 hunting state under SET-AMEND-001;
  expanded schemas need an explicit version policy before writing release saves.
  *Partly done 2026-09-11 (decision 0065):* the version-independent layer is in.
  `godot/scripts/core/save_codec.gd` implements ARCH-SAVE-001's little-endian
  integers, two's-complement reinterpretation, strict length-prefixed UTF-8, and
  bounded reads that refuse a truncated buffer or a hostile length prefix before
  allocating. `godot/scripts/core/save_header.gd` implements ARCH-SAVE-002's
  256-byte header, its 64-byte descriptors, CRC-32/ISO-HDLC, the offset-224 body
  digest and ARCH-SAVE-004's structural section-table validation; the offset-72
  catalog hash is `catalog_ids.gd`'s digest, not a second one. **Still open:** no
  section BODY is written or parsed, so the per-store codec registry the READY_07
  addendum authorises is not built; the per-section `schema_version` is carried
  and deliberately not validated, because that is the blocked policy; the rules,
  map, lookup and engine hashes at offsets 40/104/136/168 have no producer in
  this repository (decision 0034); and §11 EVENT_SCHEDULE, §13 CHRONICLE and §15
  STATE_DIGEST still have no owning module. `SCHQ0001` remains unwired.
  *Two sections added 2026-09-11 (decision 0081):*
  `godot/scripts/core/save_section_rng.gd` writes §10 RNG as a fixed 108-byte
  payload -- nine i32 stored xorshift32 states at offset 0, nine i64 draw counts
  at offset 36 -- validating the zero state xorshift32 forbids, negative draw
  counts and SET-AMEND-001 §3's HUNTING tombstone, and applying all nine streams
  or none. `godot/scripts/core/save_section_world_runtime.gd` writes §1 WORLD's
  leading 80-byte WorldRuntime block and realises the READY_07 G3 split: all
  thirteen fields are saved, and only the five ARCH-HASH-001 ones enter the
  canonical contribution, so host debt and the six clock counters are CRC- and
  SHA-protected without joining the state digest. **Still open inside 09.2:**
  thirteen sections remain unwritten, `SCHQ0001` is still unwired, and §1 is
  composed from per-owner blocks whose order and contiguity nothing settles.
  **BLOCKER W1:** `sim_clock.gd` has no writer for the completed tick, the debt
  or the six counters, and `set_pause(PLAYER, true)` discards sub-tick debt, so
  the WorldRuntime block can be captured and verified but NOT published. It needs
  a side-effect-free `restore_runtime(...)` from that module's owner.
- [ ] 09.3 Implement transactional disk-backed rollback load, validated inactive
  checkpoint, autosave rotation and interrupted-I/O recovery. Recompute expanded
  peak memory; the baseline single-floor ledger is insufficient. No second full
  mutable world beyond the budget or partially visible decoded world.
  *Partly done 2026-09-12 (decision 0092):* RESTORE-R01's LOAD integration is
  wired in `godot/scripts/systems/game_manager.gd`. `begin_load()` raises the
  shared guard, checked before host advance (`_process` and the direct
  `advance_host_time()` entry point) and before scheduler pumping
  (`_drain_boundary()`); every operational control refuses under it with
  `LOAD_IN_PROGRESS` and mutates neither clock nor queue.
  `restore_clock_runtime()` is the one production call site of
  `sim_clock.gd::restore_runtime()` and reaches it through no setter, event or
  tick. `publish_restored_world()` sets `_started` and derives PLAYING/PAUSED
  from the RESTORED mask, so a load from BOOT needs no `start_game()`;
  `end_load()` and `rollback_load()` both reset the monotonic host origin, so
  load time owes no debt. Rollback reinstalls a pre-load checkpoint of the
  clock's ten scalars through the SAME API and restores the previous
  `_started`/`_state`. **Still open, and neither inferred nor stubbed:** the
  shared guard does not reach the raw objects handed out by `clock()` and
  `scheduler_events()` — that needs an edit inside `scripts/core/sim_clock.gd`
  and `scripts/core/scheduler_events.gd`, which belong to the clock owner; and
  the rollback checkpoint is **in memory only**, because no §1 WORLD section
  writer exists in the main tree to back it with disk. Autosave rotation,
  interrupted-I/O recovery and the expanded memory recomputation are untouched.
- [ ] 09.4 Implement replay sequence and every-300-tick checkpoints plus an
  every-tick verification mode. Canonical future state must include navigation
  admission/readiness, frozen traversals, queue ages, pending edits and interval
  progression, not merely needs and XP. Chronicle streams retain all history.
- [ ] 09.5 Integrate save/load UI, paused pending previews, errors, migration
  refusal, critical-pause restoration, collapse protection and startup recovery.
- [ ] 09.6 Preserve GDD §8's future-boundary contracts (REQ-SET-176–180): shared
  identity/item schemas, atomic transfer manifests, exactly-once cancellation
  and returning persistent identity into valid free slots with carried state.
  Test through the declared boundary API; keep execution UI hidden while no
  future consumer exists. This supplies settlement compatibility, not a battle
  or campaign implementation.

Save coder owns codec/checkpoint/replay files; each system owner supplies its
state schema and independent continuation fixtures; integration lead alone edits
shared registry/stage/header/version; UI owner implements dialogs. PC-01/02/04/06
unresolved layouts block associated parity claims, not independent codecs.

## Acceptance and evidence

Use a continuous run and saves at meaningful boundaries: paused command queue,
midnight, leased goods, batch work/passive completion, active climb/dive, waiting
crossing, partial path search, occupied topology edit, death, petition expiry and
Charter evaluation. Save at tick 3000 and compare **every tick 3001–18000** where
that fixture applies; include shorter edge fixtures and longer scenario runs.
Compare independent processes, same commands at 1/2/4 speeds and view changes;
first divergence reports exact fields and revisions. Test corrupt/truncated/
wrong-hash/oversized/unsupported files and simulated write/read/rollback failures.
A failed load keeps the prior valid world or an explicit unrecoverable LOAD pause
with recoverable files; no partial playable world.

Check all free generations, restored lowest-free allocation, history, item/XP/
clock remainders and fully referenced route arenas. Preserve raw commands,
source/content/export hashes and scope exclusions. Final-only subset FNV matches
and an isolated reference codec are not production save parity.

Completion establishes persistence/replay for all implemented authoritative
systems in the covered scenarios. Qualification still needs complete 03–08
scope and actual task-10 hardware/renderer/accessibility evidence. Windows
cross-platform execution remains deferred, explicitly unverified.

## 09.2 contract handoff — 2026-09-11

Read [SAVE-R09-001–005](../rulings/2026-09-11_save_codec_contract.md) before codec
work. It resolves the five requested storage decisions; task09.2 is still open.
Implement the version vector, u32 UTF-8 strings, canonical identity artifacts,
map provenance binding, gapless sections and assigned11/13/15 payloads. Update
registry/memory as owners land; missing event/Chronicle content and expanded
MOVE-G02 schemas still block their complete release saves. Follow the ruling's
independent corruption and continuation evidence; do not label empty fixtures
complete systems. STATE-COHORT-R01 excludes `_cohort_slots` rollback scratch.
The earlier09.1 note about three unresolved rows is historical: decision0063
resolved result/reachability classification; scheduler writer wiring remains work.

## Astra follow-up — 2026-09-12

RESTORE-R01 atomic clock restoration and SAVE-LAYOUT-R01 explicit column-major framing precede end-to-end09.3 acceptance. Independent file/checkpoint work may continue.
Read [the current executor handoff](../rulings/2026-09-12_executor_followup.md) before dispatch.

## 09.2 §3 ENTITY_DIRECTORY implementation — 2026-09-12

`godot/scripts/core/save_section_directory.gd` and
`godot/test/test_save_section_directory.gd` land section 3 under SAVE-LAYOUT-R01's
block framing. Reasoning and the two open blockers are in
[decision 0098](../decisions/0098-section-3-writes-six-columns-and-rebuilds-the-rest.md).

- [x] §3 block framing: `store_count:u32`=1, `owner_key` "entity_directory",
      `owner_schema_version:u32`=1, `primary_count:u64`=352418,
      `payload_byte_length:u64`=6343572. Section is a fixed 6343616 bytes;
      descriptor `row_count` is the capacity, never the living-resident count.
- [x] Column-major payload in the ruled order `_active:u8`, `_generation:i32`,
      `_retired:u8`, `_persistent_id:i32`, `_kind:i32`, `_typed_row:i32`, each at
      full capacity, each preceded by its own `element_count:u64`.
- [x] Category-2 members written nowhere and rebuilt instead: `_typed_owner_slot`
      and the counters by `rebuild_into()`, the two min-heaps by the directory's own
      ascending refill. Only their live prefix is meaningful.
- [x] ARCH-SAVE-003 streaming: `ChunkCursor` emits at most 65536 bytes per chunk,
      field-aligned; CRC is folded by the caller through `crc32_update()`.
- [x] Validate-then-commit decode, proved against a full-length-but-invalid section,
      not only against truncation.
- [x] Canonical unused values preserved: free `_kind` and `_typed_row` stay `-1`,
      never normalised to 0; never-used generation stays 0.
- [x] Eleven mutants killed, one per Godot invocation, production file byte-compared
      by `shasum -a 256` after each restore.
- [ ] **BLOCKER D1** — `entity_directory.gd` needs `copy_columns_into()` /
      `restore_columns()`. Until then §3 cannot capture a live directory (free-slot
      generations are unreadable) and has no `apply()`. `capture_into()` refuses
      explicitly and names the API.
- [ ] **BLOCKER D2** — `_next_persistent_id` is registered to §1 WORLD and no owner
      writes it. A reloaded world reissues persistent IDs and fails ARCH-SAVE-004's
      unique-id validation. §3 must not write it; that would duplicate one
      future-affecting value across two sections.
- [ ] **Registry row owed** — `docs/persistence_state_registry.md` needs one
      category-3 row for the new module. `state_registry_coverage.py` reports exactly
      one `C1` failure until it lands. The row was drafted, verified to turn the
      check green, then reverted because that file is outside this work's allowlist.
- [ ] SAVE-R09's canonical `field_key` registry is still unfrozen, so §3 emits
      canonical **values only**; the record prefix stays section 15's.
