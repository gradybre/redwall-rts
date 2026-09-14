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
  *§11's STORE landed 2026-09-12 (decision 0133):*
  `godot/scripts/core/event_schedule.gd` implements the EVENT_SCHEDULE owner
  `canonical_state_registry.json` had only forward-declared -- eight fields at
  REG-R01's ordinals, six packed columns at 64 rows (2048 B, already budgeted at
  `systems_architecture.md:417-418`), dense and sorted `(due_tick, sequence)`,
  SAVE-R09-005's allocator (initial 1, never reused, zero means EXHAUSTED) and a
  `restore_rows()` gate that validates order, uniqueness, sequence range and tick
  sign before writing a byte. Refusals leave the store byte-identical and the
  tail past `_count` is held zero. **Still open, and NOT closed by this:** §11 has
  no CODEC -- nothing encodes or decodes `next_sequence:i64` + N 32-byte records
  -- there is no producer and no consumer, and SAVE-R09-005's required
  kind/argument DOMAIN and event production/consumption rules are still unruled,
  so the columns are validated as int32 storage and carry no meaning. §13
  CHRONICLE and §15 STATE_DIGEST still have no owning module.
  **REGISTRY DEBT:** `docs/persistence_state_registry.md` owes this module a
  section and `state_registry_coverage.py` fails C1 until it is applied;
  `canonical_state_registry.json` owes the stale
  `REQUIRED_NOT_PRESENT_IN_SNAPSHOT` markers, a `source_contract` on the six row
  fields and `packed_source_field_count` 530 -> 536.
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

## §14 NAME_POOL landed — 2026-09-12

`godot/scripts/core/save_section_name_pool.gd` and
`godot/test/test_save_section_name_pool.gd` implement ARCH-SAVE-002 section 14,
the registry's single `residents.gd::_name_key` member. Reasoning and the four
named blockers are in
[decision 0099](../decisions/0099-the-first-variable-length-save-section-frames-its-own-row-count.md).

- [x] §14 NAME_POOL payload codec: `capture_into` / `encode_record` /
      `encode_store` / `decode_into` / `apply` / `canonical_bytes_of`, following
      `save_section_rng.gd`'s shape with a public `extent_refusal()`.
- [x] **The format's first variable-length framing**, which sections 3, 4, 5, 7,
      8 and 13 inherit: explicit `row_count:u32` checked against the compiled
      capacity, then 512 rows of `utf8_byte_count:u32 LE` + exactly that many
      UTF-8 bytes, no terminator, alignment or padding (SAVE-R09-002).
- [x] `decode_into()` takes the descriptor **length** as well as the offset and
      bounds every row against the section end, not the buffer end — the layout
      is gapless (SAVE-R09-004), so a buffer-bounded read would consume section
      15's bytes as a name. Exact consumption required; trailing bytes refuse.
- [x] SAVE-R09-002's pinned fixtures reproduced against this encoder: empty
      `00000000`, `Oak` = `030000004f616b`, `Móle` = `050000004dc3b36c65`, and
      `01000000c0` / `02000000c080` both refused as malformed UTF-8.
- [x] Name validation: 128 encoded bytes, 2–32 Unicode scalar values, and no
      Unicode category Cc character (U+0000–U+001F, U+007F–U+009F), each with its
      own refusal code. The 131072-byte arena limit enforced independently.
- [x] Empty is a present anonymous row, never an absent one (GDD REQ-SET-040–042).
      A nonempty name on an absent slot refuses; an empty one does not.
- [x] `apply()` is allocate-before-consume (decision 0059) with rollback, asserted
      against a store image built from `residents.gd`'s own public readers.
- [x] `canonical_bytes_of()` emits the 512 values **without** the row-count
      prefix, because SAVE-R09's canonical field record supplies `value_count`
      itself. Section 14 is category 1 **and** inside ARCH-HASH-001.

Still open, and not claimed by this work:

- [x] **BLOCKER N1 CLOSED** — NAME-R02 registers owner `residents`, owner schema
      1, primary_count 512, and section 14 now carries `store_count:u32`=1 plus
      SAVE-LAYOUT-R01's 33-byte wrapper ahead of the unchanged payload.
- [x] **BLOCKER N2 CLOSED** — NAME-R02 corrects SAVE-R09-002 and publishes the
      three-row table. A present anonymous row, INCLUDING a live resident, is
      flag 0 and the empty name. The earlier reading is confirmed, not guessed.
- [x] **BLOCKER N3 CLOSED** — `residents.gd::name_refusal()` is the one shared
      validator, reached by `set_name()`, `restore_name()`, automatic name
      assignment, capture and restore. The codec adds no rule and only maps codes.
- [x] **BLOCKER N4 CLOSED at the codec** — `occupancy_refusal()` validates all
      512 rows BEFORE `apply()`'s first write, and the writes go through
      `restore_name()`, which takes the incoming flag explicitly. A load
      orchestrator holding the §4-then-§14 order is still owed, separately.
- [ ] Registry and architecture rows for the codec's transient `Record` column,
      the new §14 framing arithmetic, and the §2.2 `name_key`
      I32-versus-`PackedStringArray` divergence, are reported to the integration
      owner; neither file was on this task's allowlist.

## NAME-R02 and the §14 owner wrapper — 2026-09-12

`godot/scripts/core/residents.gd` and `godot/scripts/core/save_section_name_pool.gd`
implement NAME-R02 and the §14 wrapper paragraph of
[the save-registry answers](../rulings/2026-09-12_save_registry_answers.md).
Reasoning is in
[decision 0112](../decisions/0112-one-resident-owned-name-validator-and-the-section-14-owner-wrapper.md).

- [x] **One resident-owned validator.** `Residents.name_refusal()`: strict UTF-8,
      at most 128 bytes, 2–32 Unicode scalar values, and an explicit Cc predicate
      over U+0000–U+001F, U+007F and U+0080–U+009F. Empty stays legal. Nothing is
      normalized, truncated or replaced; a refusal writes neither column.
- [x] Scalars are counted as **scalars**. Pinned with `"A" + U+0301` ×17 — 34
      scalars, 51 UTF-8 bytes, 17 grapheme clusters — which a byte counter and a
      cluster counter both admit and only the scalar rule refuses.
- [x] `utf8_byte_length_of()` is arithmetic over the 0x7F/0x7FF/0xFFFF width
      boundaries, asserted equal to a real `to_utf8_buffer()` encode on six
      fixtures, so `residents.gd` need not preload the codec.
- [x] **§14 wrapper**: `store_count:u32`=1, `owner_key` `residents` (9 bytes),
      `owner_schema_version:u32`=1, `primary_count:u64`=512,
      `payload_byte_length:u64`, then the retained `row_count:u32`=512 and 512
      `utf8_u32` rows. Wrapper 33 bytes, framing 37; payload 2052..67588; section
      2089..**67625**. Both counts validated, and `payload_byte_length` checked
      against the descriptor's own framed length.
- [x] Section 14's schema version is **2**, published as `SCHEMA_VERSION` because
      `save_header.gd` carries the descriptor field opaquely.
- [x] The canonical record is unchanged: `(14, "residents", "_name_key", type 5,
      count 512, values)`. Measured on the real starter settlement — section 2101
      bytes, canonical 2060, delta exactly 41.
      `docs/planning/canonical_state_registry.json` already declares all of this;
      no change to that file is required.
- [x] **The ordering rule.** `occupancy_refusal()` runs over all 512 rows before
      `apply()` writes anything, and the writes use `restore_name()`, which never
      derives `_named` from emptiness. Both mismatch directions refuse; a refusal
      leaves the store byte-identical, asserted by image comparison (ADR 0059).
- [x] A retained dead row keeps its name and its flag; the fixture kills a real
      resident through `needs.apply_health_event(slot, -100)`.
- [x] Two tests that asserted the pre-NAME-R02 behaviour were rewritten, not
      deleted, and the change is recorded in decision 0112.

Reported, not done — outside this task's allowlist:

- [ ] `command_dispatch.gd::_alias_refusal()` is still a second copy of the name
      rules and misses C1 controls, which now surface as `RESULT_STORE_REFUSED`
      rather than `RESULT_ALIAS_CONTROL_CHARACTER`. No invalid name reaches a
      column either way; folding it into the shared validator belongs to that
      file's owner.
- [ ] §4 has no codec, so nothing restores `_named`. **No release-save
      completeness is claimed by this work.**

## 09.2 §3 ENTITY_DIRECTORY implementation — 2026-09-12

`godot/scripts/core/save_section_directory.gd` and
`godot/test/test_save_section_directory.gd` land section 3 under SAVE-LAYOUT-R01's
block framing. Reasoning and the two open blockers are in
[decision 0103](../decisions/0103-section-3-writes-six-columns-and-rebuilds-the-rest.md).

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
- [x] **BLOCKER D2 — CLOSED 2026-09-12** by decision 0115. `_next_persistent_id` is §1
      WORLD's own `entity_directory` block: schema 1, primary_count 1, payload 4 bytes
      `_next_persistent_id:u32 LE`, domain `1..2147483648` with 2147483648 the exhausted
      cursor. `entity_directory.next_persistent_id()` captures it and
      `restore_columns_and_cursor()` installs §3's columns and the cursor together, after
      checking the cursor strictly exceeds every positive stored id. `restore_columns()`
      still does not write it, so §3 does not duplicate a §1 value.
- [ ] **Registry row owed** — `docs/persistence_state_registry.md` needs one
      category-3 row for the new module. `state_registry_coverage.py` reports exactly
      one `C1` failure until it lands. The row was drafted, verified to turn the
      check green, then reverted because that file is outside this work's allowlist.
- [ ] SAVE-R09's canonical `field_key` registry is still unfrozen, so §3 emits
      canonical **values only**; the record prefix stays section 15's.

## Clock/queue load barrier — 2026-09-12

RESTORE-R01's "a GameManager-only check is insufficient while mutable raw access
exists" is now implemented inside the two objects `game_manager.clock()` and
`game_manager.scheduler_events()` hand out. See
[decision 0104](../decisions/0104-the-load-barrier-is-a-token-the-clock-holds.md).

- `SimClock.acquire_load_barrier()` returns a held token; the raised/lowered bit
  lives in that token, and the clock exposes no call that lowers it. A second
  concurrent grant refuses. `SchedulerEvents` reads the same barrier through its
  bound clock and owns no barrier state, so there is one barrier per world.
- Barred while held, each changing nothing at all: `set_speed`, `set_pause`,
  `advance`, `acknowledge_without_catchup`, `apply_overload`,
  `apply_overload_target`, `note_overload_step`, every `submit_*`,
  `admit_stamped_into`, `pump_into`/`pump`, `clear`, `rebind_clock`,
  `begin_host_frame` and `advance_frame`.
- Passing through, because the barrier is raised *for* them: `restore_runtime`,
  `restore_extension`, `restore_sequence`.
- The barrier is never a pause bit, is never serialized, and lowering it never
  clears a saved `LOAD` hold.

**Still open, and not claimed here.** `game_manager.gd` does not yet acquire or
release this token, so the running game raises only its own `_loading` flag and
the raw-access hole remains open in production until that file's owner adds the
three lines decision 0104 §"What is still owed" names. 09.3 acceptance remains
open on its own terms: this is one named half of RESTORE-R01, and the
disk-backed checkpoint, file rotation and I/O fault injection belong to another
owner. No save parity, full-colony, movement-gate or Windows evidence is implied.

## Directory bulk columns — BLOCKER D1 closed — 2026-09-12

`entity_directory.gd` now publishes and accepts its six category-1 columns, so §3 can
capture a live world and apply a decoded one. See
[decision 0105](../decisions/0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md).

- `copy_columns_into()` is the only reader that answers for an INACTIVE slot, which is
  where the generations the registry requires verbatim live. It refuses a buffer that
  is not `DIRECTORY_CAPACITY` long and hands back snapshots, not aliases.
- `restore_columns()` installs the six and rebuilds `_typed_owner_slot`, `_free_heap`,
  `_heap_index`, `_kind_free_count`, `_kind_live_count`, `_free_count` and
  `_live_count`. Both free windows are filled **ascending**, live and retired slots
  excluded. The duplicate `(kind, typed_row)` check is the rebuild's own collision, not
  a separate pass.
- A refused restore leaves the directory byte-identical, asserted through a new
  `state_bytes()` image rather than by eye. The image emits each free window's live
  prefix **sorted**, because the permutation is not state — only the set is.
- Refusals are read through `last_column_refusal()`, a namespace separate from
  `create()`'s `last_refusal()`; every code is prefixed `COLUMN_`. The spellings are a
  proposal: ARCH-ID-004 publishes no registry for column operations.
- §3 gained `apply()`, and `capture_into()` no longer refuses.
  `test_capture_from_a_live_store_refuses_and_names_the_blocker` and
  `test_module_names_both_open_blockers` were the two tests pinning the blocked
  behaviour; both were rewritten to assert the new contract, each quoting its old
  assertion in the docstring.
- Round trip proved end to end: capture → encode → decode → apply → re-encode is byte
  identical, the reloaded store agrees with its record, and one fixed interleaved
  create/destroy script allocates the same slots and the same typed rows in both.
- Sixteen mutants killed, one per Godot invocation, both production files
  `shasum -a 256` byte-compared after each restore.

- [x] **BLOCKER D2 — CLOSED 2026-09-12** (decision 0115). §1 WORLD now carries the
      cursor and `restore_columns_and_cursor()` assigns it. The two tests that asserted
      the gap in the positive are retained and now assert the SPLIT: `restore_columns()`
      alone still leaves the cursor to §1, and the combined call makes the two worlds
      byte-identical including the cursor.
- [ ] **Registry rows owed, reported and not applied** (the file is another owner's):
      one category-3 member row for `_last_column_refusal` in
      `docs/persistence_state_registry.md`'s `entity_directory.gd` section, beside the
      existing `_last_refusal` row; and, if that registry is read as recording *how*
      each column is restored, a note on the free-heap row that the ascending refill is
      now `restore_columns()`'s as well as `_rebuild_free_heaps()`'s.
      `state_registry_coverage.py` passes without both, because it checks packed
      columns.


## D2 allocator, §1 composition and two standing barriers — 2026-09-12

Decision [0115](../decisions/0115-the-persistent-id-cursor-is-section-ones-and-both-barriers-are-wired.md).
Lane files: `godot/scripts/core/save_section_world_runtime.gd`,
`godot/scripts/core/entity_directory.gd`, `godot/scripts/systems/game_manager.gd`,
`godot/scripts/systems/settlement_system.gd` and their four focused suites.
**This closes no 09.2 or 09.3 acceptance**: it is neither a release-save digest, a load
orchestrator, a §15 verification nor cross-store ordering, all of which remain the
integration lead's.

Landed:

- §1 composes as SAVE-R09-003's 44-byte map-provenance prefix, `store_count:u32`, then
  SAVE-LAYOUT-R01 wrappers in ASCII owner-key order tiling the remainder. The two owned
  blocks are `entity_directory` (44 bytes: 4 + 16 key + 4 + 8 + 8 + 4 payload) and
  `world_runtime` (117 bytes: 4 + 13 key + 4 + 8 + 8 + 80 payload); 44 + 4 + 44 + 117 =
  **209 bytes**, pinned as a hex vector rather than round-tripped against its own encoder.
- `world_runtime` keeps schema 1, primary_count 1 and its exact 80-byte payload and
  offsets, its three reserved bytes zero, and no directory state.
- The exhausted cursor is pinned as the bytes `00000080`, with both the 64-bit
  (`2147483648`) and int32 (`-2147483648`) readings asserted and asserted to differ.
- `game_manager.begin_load()` takes `sim_clock.acquire_load_barrier()` and refuses the
  whole call if the grant refuses; `end_load()` and `rollback_load()` release it;
  an unrecoverable rollback leaves it held. `GameManager._loading` stays.
- `settlement_system._compose_stock_layer()` binds `stock_age` as the lot store's
  seed-expiry authority. `TICK_STAGE_COUNT` is unchanged at 8.
- The saved debt domain is corrected to `0..INT64_MAX` per RESTORE-R01.
- Ten mutants killed, one per Godot invocation, all four production files
  `shasum -a 256` byte-compared against pristine copies after each restore.

Still open, named rather than papered over:

- [ ] **BLOCKER W2 — seven of §1's nine registered owners have no encoder anywhere.**
      `buildings, farming, forage, resource_nodes, spatial_world, weather, world_init`.
      `encode_section()` emits `store_count = 2` and `SectionRecord.missing_owner_keys()`
      reports the gap; `decode_section()` already measures a foreign registered block's
      extent so those owners can decode their own payloads without this module guessing
      a schema. A release §1 requires all nine.
- [ ] **§1's 44-byte prefix fields are carried but produced by nobody.**
      `scenario_version`, `map_generator_schema` and `authored_map_digest` are bounded and
      round-tripped here; `world_init.gd` supplies none of them and no default is
      manufactured.
- [ ] **Registry/ledger rows owed in files outside this lane's allowlist** (reported, not
      applied). `state_registry_coverage.py` passes without them because it checks packed
      columns in `godot/scripts/core` only, and no new packed column was added:
      1. `docs/persistence_state_registry.md:214` — the persistent-id allocator row should
         gain the §1 block framing: owner key `entity_directory`, `owner_schema_version:u32`
         = 1, `primary_count:u64` = 1, `payload_byte_length:u64` = 4, payload
         `_next_persistent_id:u32 LE`, domain `1..2147483648`; block width 4 + 16 + 4 + 8 +
         8 + 4 = **44 bytes**.
      2. `docs/persistence_state_registry.md:586` — the §1 WorldRuntime codec row should
         record that the module now also composes the whole section: 44-byte prefix +
         `store_count:u32` + ASCII-ordered blocks, `store_count` bounded by REG-R01's nine
         §1 owners, and the two owned blocks at 44 and 117 bytes for a 209-byte
         two-block development section. Its `DEBT_MAX` is now `INT64_MAX`.
      3. `docs/systems_architecture.md:405` (cited by registry row 214) — `WorldRuntime.
         next_persistent_id` should be restated as a SEPARATE `entity_directory` owner
         block in §1, not a field of the WorldRuntime payload.

## 2026-09-12 — §8 JOB_INDEXES codec (save/registry lane)

`godot/scripts/core/save_section_job_indexes.gd` and
`godot/test/test_save_section_job_indexes.gd` are new; see
[decision 0120](../decisions/0120-section-8-freezes-its-payload-and-refuses-to-invent-a-primary-count.md).
Nothing outside those two files, this subsection and that record was touched.

- [x] **§8's wire body is frozen for the 29 declared fields.** SAVE-LAYOUT-R01's
      owner wrapper (`store_count:u32`=1, `owner_key`="job_planner",
      `owner_schema_version:u32`=1, `primary_count:u64`, `payload_byte_length:u64`)
      followed by 29 × (`element_count:u64` + column values), column-major, in the
      registry artifact's declared ordinal order. 39 + 232 + 362880 = **363151 bytes**;
      canonical hash contribution **362880 bytes**, which excludes the wrapper and the
      29 element counts.
- [x] **Each of the five child extents is validated from the owning schema**, not from
      whichever column is encoded first: 8192 service rows (ordinals 0–10), 4096 cycle
      rows (11–12), 128 zone rows (13–15), 640 demand rows (16–20), 1024 hive rows
      (21–28). Deriving either the encoded or the decoded `element_count` from ordinal
      0's extent kills 8 and 7 tests respectively.
- [x] **Validate then commit.** A full-length section carrying an invalid value leaves
      the caller's Record byte-identical, asserted by comparing all 29 columns. The
      extent gate catches truncation long before anything is read, so the
      commit-then-validate mutant is exercised with a full-length invalid section.
- [x] **26 mutants run, one per Godot invocation**, production file `shasum -a 256`
      byte-compared against a pristine copy after each restore. 25 killed; one
      (`extent_refusal`'s redundant `bytes.size() < SECTION_BYTES` clause) is an
      equivalent mutant, and disabling the gate outright kills one test. One real
      coverage hole was found and closed this way: the u8 branch of the free-row
      hygiene check had no test until `_requires_water` and `_gate_reason` residue
      cases were added.

- [ ] **BLOCKER J1 — §8's `primary_count` value is unruled and is not invented here.**
      `job_planner` owns three independent owner capacities (4096 plots, 128
      designations, 1024 hives) plus two derived child tables, and REG-R01's artifact
      declares no `primary_count` for it. `encode_section()` takes the count as a
      required argument, `decode_section_into()` takes the value it must match, and
      `production_write_refusal()` refuses `SAVE_JOB_PRIMARY_COUNT_UNRULED` so no
      section 8 block reaches a real save file until a ruling supplies the number.
      Only those eight bytes wait; the other 363143 are frozen.
- [ ] **BLOCKER J2 — `job_planner.gd` publishes no bulk column API**, so there is no
      live-store round trip yet. Its public readers are gated (a FREE row and a
      non-daily operation both refuse, a Job answers only while PENDING, the sowing
      readers address only an owner's SOW row), so a capture built on them would have
      to synthesise values it cannot read. `capture_into()` and `apply()` refuse
      `SAVE_JOB_STORE_NO_COLUMN_API` and name the validating, transactional
      `copy_job_index_columns_into()` / `restore_job_index_columns()` pair the planner
      owner must publish — the same resolution decision 0105 gave §3 and RESTORE-R01
      gave the clock. The exact signature is that owner's to choose.
- [ ] **Registry rows owed, reported and not applied** (the files are other owners'):
      `docs/persistence_state_registry.md` needs a
      `### \`godot/scripts/core/save_section_job_indexes.gd\`` section with one
      category-3 codec row and one category-3 scratch row (`Record` is 362880 bytes of
      bounded codec scratch on ARCH-SAVE-003's cold path, holding no module-level
      `var` and adding no authoritative column), and `docs/systems_architecture.md`'s
      ledger needs the same classification. Until that section exists
      **`state_registry_coverage.py` fails its C1 check** for the new module; every
      other listed validator passes.

## §9 NAVIGATION landed — 2026-09-12

`godot/scripts/core/save_section_navigation.gd` and
`godot/test/test_save_section_navigation.gd`, under REG-R01 and SAVE-LAYOUT-R01.
Reasoning in
[decision 0121](../decisions/0121-section-9-navigation-persists-used-prefixes-and-declares-its-own-primary-count.md).

- [x] Two owner blocks behind `store_count:u32 = 2`, in ASCII key order `movement`
      (schema 1, primary 512) then `navigation` (schema 2, primary 8192), each with the
      standard wrapper, tiling the section with no gaps. Column-major bytes; field order
      is the declared ordinal from `canonical_state_registry.json`, which differs from
      GDScript declaration order in **both** blocks.
- [x] `_heap` and `_arena` persist their **used prefixes**; the tails are zeroed at
      capture, absent from the wire and refused in a Record. `_stamp`, `_g`, `_parent`,
      `_heap_position` and `_state` are written at the registry's declared full capacity;
      sparsifying them is a later schema version's change and is flagged as needing a
      ruling, not taken here.
- [x] Owner schema version 2 doubles as PATH-R02's route-semantics gate, compared against
      `navigation.gd::route_semantics_version()` and run through
      `refuse_route_semantics()`. `_r_start_cell` must equal `_r_exact_start`, and
      `PHASE_SEARCHING_LOCAL` is refused outright.
- [x] Queue progress validated as state: the free list and the pending queue each thread
      exactly their own rows with no cycle, and the queue must be in `_enqueue()`'s
      service order. Descriptor refcounts are rebuilt from the READY requests that hold
      them; every in-use route window must lie inside the arena used prefix and not
      overlap another.
- [x] Real byte vectors: an empty navigator is 5180042 bytes, the ceiling is 10422922,
      and `4 + 32 + 18504 + 34 + 5161468 + 4*(heap_size + arena_used)` is pinned by both
      the framing hex vector and the section arithmetic test. Capture → encode → decode →
      re-encode is byte-identical, including from a live serviced navigator holding a
      READY request, a quota-interrupted search and a queued request at once.
- [x] Ten mutants killed, one per Godot invocation, the production file `shasum -a 256`
      byte-compared against a pristine copy after each restore.

- [ ] **BLOCKER N1 — neither owner publishes bulk columns.** `navigation.gd` and
      `movement.gd` have no `copy_columns_into()` / `restore_columns()` pair, so §9 has no
      `capture_into(store)` and no `apply(record, store)` — the same wall §3 hit as its
      BLOCKER D1 before decision 0105. The exact signatures needed are in the module
      header. `agrees_with_navigation()` cross-checks a Record against a live navigator as
      far as the public readers allow, which is every published scalar, every descriptor's
      generation/variant/refcount and every request phase.
- [ ] **Registry row owed, reported and not applied** (the file is another owner's): a
      `### godot/scripts/core/save_section_navigation.gd` section in
      `docs/persistence_state_registry.md` with one **category 3** row citing no save
      section. `state_registry_coverage.py` reports exactly one C1 failure until it lands.
      `Record` (10422324 bytes), `Derived` (10240 bytes) and the transient `GroupBuffers`
      are bounded codec scratch, not authoritative columns, so nothing is owed in
      `docs/systems_architecture.md`.
- [ ] **`navigation`'s primary count is this owner's declaration**, not a published one:
      `PATH_REQUEST_CAPACITY` = 8192, with every child extent validated separately. A
      ruling naming a different value changes one constant and the schema version.
- [ ] §9 persisting closes no MOVE gate and certifies no release save. PATH-R02's
      readiness-latency work is untouched.

## §15 STATE_DIGEST canonical field walker — 2026-09-12

`godot/scripts/core/canonical_state_hash.gd` implements SAVE-R09's RWL-STATE-1 stream
against REG-R01's ordered declaration. See
[decision 0127](../decisions/0127-the-canonical-field-walker-refuses-what-it-cannot-hash.md).

- [x] Record grammar: `section_id:u32, owner_key:string, field_key:string, type:u8,
      value_count:u64, values`, with strings as u32 little-endian **UTF-8 byte** length.
      Prefix is the 11 ASCII bytes `RWL-STATE-1`, four 32-byte identities, the engine
      identity line, `completed_tick:i64` and `record_count:u32`.
- [x] Order is section 1–14, then ASCII `owner_key` byte order, then the declared field
      ordinal — never alphabetical by field key. `Declaration.validate()` checks the order
      it is given; nothing in the module sorts.
- [x] §15 never includes itself: an owner declaring section 15 refuses with
      `CANONICAL_SELF_INCLUSION`. The header's body SHA-256 over `[256, EOF)` stays
      `save_header.gd`'s and is a different digest.
- [x] The declaration is a **generated** constant table compiled from
      `docs/planning/canonical_state_registry.json` (50 owners, 590 declared fields, 582
      canonical records). Two tests re-read that JSON and compare every owner and every
      field, so the table cannot drift and stay green.
- [x] Bounded streaming: one 65536-byte `Emitter` window folded into `HashingContext`; the
      stream is never materialised. Capture is opt-in, capped, and refuses rather than
      truncating.
- [x] Pinned fixture: a three-owner, seven-field, six-record declaration whose 426-byte
      stream and SHA-256 `7711d6b5dcd94db94f82bb4d61fb976506ffb57aec60eb62d94d4051aad61da0`
      are asserted from constants computed independently in Python.
- [x] Ten mutants killed, one per Godot invocation, each restored and `shasum -a 256`
      byte-compared: alphabetical field order, case-folded owner order, reversed owner walk,
      section 15 accepted, missing adapter unnoticed, character-count string prefix,
      values not emitted, exclusions ignored, and two generated-table drifts.

- [ ] **BLOCKER — no owner adapter exists.** `Walker.digest_into()` on the production
      declaration refuses with `CANONICAL_NO_ADAPTER` and `missing_adapter_owners()` lists
      **all 50** declared owners. No real digest can be produced until each store owner
      implements `canonical_field_values()`. `DigestResult.covers_release_state` stays
      false and `release_save_ready` stays false.
- [ ] **BLOCKER — non-scalar extents are unenforceable from the registry.** 501 of the 590
      declared fields carry `shape.declared_capacity` as prose rather than an integer, so
      the walker can check only the 54 fields with an integer `shape.count`. Either each
      adapter owns that check or the registry publishes resolved integer capacities. No
      capacity constant was invented.
- [ ] **Registry section owed, reported and not applied** (the file is another owner's):
      `docs/persistence_state_registry.md` needs one category-3 section for
      `canonical_state_hash.gd`. `state_registry_coverage.py` FAILS on this branch without
      it (`FAIL C1 canonical_state_hash.gd has no registry section`), and so does
      `validate_save_registry_handoff.py --source-root .`. The exact row, with its byte
      arithmetic, is in the lane's handoff report; both validators pass with it applied.
- [ ] **Generator owed** at `tools/generate_canonical_state_table.py`, outside this lane's
      allowlist. The table was produced by it; only the JSON-equivalence tests are committed.
## 2026-09-12 — §4 component-store bulk columns: `needs`, `residents`, `jobs`

[Decision 0132](../decisions/0132-three-component-stores-publish-their-columns-and-rebuild-the-rest.md)
extends decision 0105's directory API to the three largest §4 COMPONENT_COLUMNS owners.
Each publishes `copy_columns_into(out: Columns)`, `restore_columns(columns: Columns)`,
`last_column_refusal()` and `state_bytes()`, plus its declared ordinal tables. The buffers
travel in a per-store `Columns` inner class because the directory's six columns become
twenty, nineteen and forty-two here.

- [x] `needs.gd` — 20 §4 columns. `_present_count` / `_living_count` recomputed; the
      256-living cap is checked against the recomputed number before any write.
- [x] `residents.gd` — 19 §4 columns. `_live_slots` rebuilt ascending; each present row's
      self-reference must resolve through §3 to its own typed row. `_name_key` stays
      §14's: `restore_columns()` installs `_named` and empties every name, and
      `unresolved_name_row_count()` counts the rows §14 still owes.
- [x] `jobs.gd` — 38 §4 columns plus the 4 §5 CHILD_ARENAS chain columns in one
      transaction. `_job_persistent_id`, `_agent_persistent_id`, `_live_slots`,
      `_bucket_begin`, `_live_count`, `_agent_count` and `_deepest_continuation_bucket`
      are all rebuilt; the worker binding is checked in both directions and every member
      chain is walked under a `JOB_CAPACITY` step cap.
- [x] Restore ORDER is enforced, not assumed: §3 before `residents.gd`; §3 and
      `residents.gd` before `jobs.gd`.
- [x] A refused restore leaves each store byte-identical, asserted by `state_bytes()`
      comparison in every refusal test.

**What is now unblocked.** A codec holding these three stores can capture every
category-1 column including free rows, and install a validated set back. That is the
whole of what this adds.

**What is still open, and it is not small.**

- [ ] There is **no §4 COMPONENT_COLUMNS codec and no §5 CHILD_ARENAS codec** in this
      repository. These are the store halves only; nothing yet turns them into section
      bytes. **No release-save completeness is claimed.**
- [ ] The other §4 owners still publish no bulk column API: `inventory.gd`, `gear.gd`,
      `buildings.gd`, `farming.gd`, `fishing.gd`, `forage.gd`, `orchard_hive.gd`,
      `injury.gd`, `priorities.gd`, `schedule.gd`, `reservations.gd`, `work.gd`.
      Decision 0132's shape is available to copy.
- [ ] **BLOCKER J2 is untouched.** It names `job_planner.gd`, a different module from
      `jobs.gd`; §8's own capture and apply still refuse `SAVE_JOB_STORE_NO_COLUMN_API`.
- [ ] Registry rows owed and not applied (files outside that work's allowlist): one
      category-3 `_last_column_refusal` member row per store in
      `docs/persistence_state_registry.md`. **No ledger byte is owed** — no new packed
      column was added, and a refusal-code `StringName` is a scalar that is not
      persisted and is excluded from `state_bytes()`.
## 09.3 — section 7 INVENTORIES_AND_LEASE_INDEXES — 2026-09-12

Decision [0122](../decisions/0122-section-7-frames-six-owners-and-declares-its-extents.md).
New files: `godot/scripts/core/save_section_inventories.gd` and
`godot/test/test_save_section_inventories.gd`. No existing file was edited.

- [x] **Six owner blocks in REG-R01's ASCII order, tiling the section with no gaps.**
      `store_count:u32 = 6`, then `fishing`, `forage`, `gear`, `inventory`,
      `reservations`, `stock_age`, each with SAVE-LAYOUT-R01's wrapper. `inventory`
      is owner schema 2; the other five are 1. Column-major. Field order is the
      declared REG-R01 **ordinal**, which for `inventory` interleaves container and
      lot columns and is not GDScript declaration order. Blocks out of ASCII order
      are refused, not sorted.
- [x] **Extents declared, never inferred.** Each payload opens with
      `child_extent_count:u32` and its child extents. `inventory` declares
      `primary_count = _c_capacity` and one child extent `_l_capacity`; the other
      five declare zero. Each column's own `element_count:u64` must equal whichever
      declared extent its shape names. Every count is bounded against the owning
      module's compiled maximum **before** an `OwnerRecord` is allocated.
- [x] **Free stacks: prefix in order, tail never written.** `_c_free`, `_l_free`
      and `stock_age._declared_slots` persist exactly their count fields' worth of
      entries in order; the stale tail is rebuilt as canonical `NULL_SLOT`. Counts
      are validated against occupancy and retirement: every slot is live, on the
      stack, or retired at `MAX_INT32`.
- [x] **`_l_provenance` refused outside 0..5 (decision 0113), never clamped**, on
      every row rather than only on live ones.
- [x] **No generation invented for `gear` or `reservations`.** Both declared field
      lists are pinned by test at twelve and eight keys, and both tables are written
      at full row extent so a load cannot compact them.
- [x] **ARCH-SAVE-003 chunking implemented.** The empty section at the compiled
      maxima is 10437959 bytes, larger than section 3's 6343616, so `ChunkCursor`
      streams it field-aligned at no more than 65536 bytes per chunk. The stream
      reproduces `encode_record()` byte for byte.
- [x] **Real byte vector**, empty world at the compiled maxima: `store_count` 4,
      `fishing` 12891, `forage` 434298, `gear` 688256, `inventory` 7481637,
      `reservations` 1212520, `stock_age` 608353, section **10437959**.
- [x] **Round trip byte-identical**, including a store whose free stack is
      partially consumed and whose live prefix is a non-descending permutation.
- [x] **Seventeen mutation runs**, one mutant per Godot invocation, the production
      file `shasum -a 256` byte-compared against a pristine copy after each restore.
      Fifteen died. Both survivors were real defects and were fixed: a declared
      `payload_byte_length` that was compared against a figure recomputed from the
      same read, and one unreachable comparison in the declared-list validator.
- [x] Full suite: `3833 test(s), 133967 assertion(s), 0 failure(s)`.

- [ ] **BLOCKER I1 — no section-7 owner publishes its columns.** There is no
      `capture_into(store)` and no `apply(record, store)`, because none of
      `inventory.gd`, `gear.gd`, `reservations.gd`, `stock_age.gd`, `forage.gd` or
      `fishing.gd` has the `copy_columns_into()` / `restore_columns()` pair decision
      0105 added to `entity_directory.gd`. Six files this lane does not own.
- [ ] **Registry row owed and not applied** (`docs/persistence_state_registry.md`
      is another owner's file). `state_registry_coverage.py` C1 fails without a
      section for `save_section_inventories.gd`. The module holds no module-level
      `var`, so the row is category 3, the same shape as
      `save_section_directory.gd`'s. Exact text reported with this work.
- [ ] **`gear` and `reservations` sub-capacities are unregistered.** Both hold a
      `_job_capacity` and a `_lot_capacity` that are constructor arguments, and
      REG-R01 declares neither as a field. This module bounds those references by
      the compiled maxima; a restore into a store built with smaller sub-capacities
      cannot be validated from the wire. Needs a REG-R01 amendment or an
      orchestrator rule.
- [ ] **The 64-byte descriptor's `row_count` for a six-owner section is
      unresolved.** No document settles it, so no `descriptor_row_count()` is
      published rather than a summed number with no meaning.
- [ ] **`inventory.gd` does not blank a retired row**, unlike the other four row
      owners, so two observably identical inventories can differ in a retired row's
      bytes. Not refused here; recorded for section 15's canonical digest.
## 2026-09-12 — §12 PENDING_COMMANDS codec (`save_section_pending_commands.gd`)

- [x] **Section 12 implemented in SAVE-LAYOUT-R01's record-major form**, which that
      ruling names in its fixed-format exception list beside §10: a 24-byte schema-2
      prefix, E 64-byte economic records in canonical command order, P arena bytes,
      then the record-major `SCHQ0001` extension. Section length is
      `scheduler_events.gd::section_twelve_length()`'s `72 + 64*E + P + 32*S`, never a
      second formula. §12 stays at schema 2 (REG-R01: "§12 was already 2") and the
      nested `SCHQ0001` at schema 1. **This diverges from the lane instruction, which
      asked for the generic `store_count` + owner-wrapper + column-major framing;
      [decision 0123](../decisions/0123-section-12-keeps-its-record-major-form-and-refuses-an-unreproducible-payload-arena.md)
      records why the ruling won and what would have to change if it is overruled.**
- [x] Both registered owners are present and ASCII-ordered: `commands` supplies the
      prefix and the economic records, `scheduler_events` the trailing extension, with
      no gap between them. REG-R01's declared field ordinals are published as
      `FIELD_KEYS_COMMANDS` (20) and `FIELD_KEYS_SCHEDULER` (14) for §15's walker, and
      the suite asserts the record columns follow ordinals 4..18 and 7..13 — **never
      GDScript declaration order**.
- [x] **Ring garbage is not persisted.** Rows are read only through
      `read_into(position, ...)`, so a wrapped `_head` and `commands.gd`'s `_order`
      permutation are resolved for the codec; no unused row is serialized; the stored
      scheduler control head is the canonical 0; and `_ring_tail_refusal()` refuses a
      Record whose columns carry a drained row past the live window. Wrapped-head round
      trips are exercised for BOTH rings (4100 and 260 cycles).
- [x] **The payload arena keeps its used prefix P and zeroes every byte no pending
      command owns**, including holes between spans, per ARCH-SAVE-002's "encode zero
      for unused payload" as quoted on the registry's own arena row.
- [x] Restore goes through the owners' published APIs only:
      `scheduler_events.gd::restore_extension()` over bytes rebuilt by the same private
      writer `encode_record()` uses, then `commands.gd::restore_sequence()` and one
      `admit_stamped_into()` per record. Both pass through the load barrier, which a
      test asserts by installing under a held `acquire_load_barrier()` grant.
- [x] Allocate before consume: every refusal path leaves BOTH collaborating stores
      byte-identical, asserted by re-encoding them and comparing bytes. Every
      full-length-but-invalid case is exercised with a full-length section, so
      commit-then-validate cannot hide behind a truncation test.
- [x] The int32/int64 sign trap is exercised, not assumed: 0x7fffffff before
      0x80000000 in both sequence spaces, the u32 allocators bounded at 4294967295, and
      a byte-swapped pair that reads in order only under a signed comparison refused.
- [x] Calendar boundary fixtures use the offset calendar, never `tick % 18000 == 0`:
      saved at 13499 with an edit due at first midnight 13500, and at 17999 with an
      edit due at 18000.
- [x] Eleven mutants killed, one per Godot invocation, the production file
      `shasum -a 256` byte-compared after each restore. Two survived first and the
      tests were strengthened until they died.
      Suite: `3847 test(s), 142779 assertion(s), 0 failure(s)`.

- [ ] **BLOCKER P1 — framing contradiction, reported not resolved.** SAVE-LAYOUT-R01
      exempts §12 from the generic packed-store wrapper; the lane instruction asked for
      that wrapper. The ruling was followed. An integration lead should confirm or
      overrule; if overruled, the section schema version and the whole prefix change
      together.
- [ ] **BLOCKER P2 — `commands.gd` publishes no arena-base restore.** A save whose
      first pending payload span does not start at offset 0 (only reachable through a
      replay stream with mixed future ticks leaving a partial drain) is refused with
      `SAVE_PC_ARENA_NOT_REBUILDABLE` at capture and at apply, rather than written into
      a file that cannot be loaded. Closing it needs an arena-base restore on
      `commands.gd`, which is another owner's file.
- [ ] **Registry rows owed, reported and not applied** (both files are other owners'):
      one category-3 `save_section_pending_commands.gd` section in
      `docs/persistence_state_registry.md`, and the matching codec-scratch line in
      `docs/systems_architecture.md`. `state_registry_coverage.py` reports exactly one
      C1 failure until the first lands; the exact row text is in the lane report.
- [ ] **No release-save completeness is claimed.** §12 is one section; the header, the
      section directory, the canonical digest and every other section's producer remain
      unfinished, and `release_save_ready` stays false.
