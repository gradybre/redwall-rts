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

- [ ] **BLOCKER N1** — section 14 has no registered owner-block framing.
      SAVE-LAYOUT-R01 scopes the `owner_key / owner_schema_version /
      primary_count / payload_byte_length` wrapper to sections 3/4/5 and says
      6/7/8/9/14 still need registered owner schemas. No wrapper, owner_key
      spelling or schema version is invented here; adding one later increments
      the section version.
- [ ] **BLOCKER N2** — SAVE-R09-002's "a live resident cannot load an empty name"
      versus GDD REQ-SET-041's anonymous residents. Implemented as the `_named`
      consistency rule; needs the ruling author's confirmation.
- [ ] **BLOCKER N3** — `residents.gd::set_name()` enforces none of
      ARCH-SAVE-005's name rules, so a live store can hold a name this codec
      must refuse to write. `residents.gd` was read-only for this task.
- [ ] **BLOCKER N4** — section 14 must be applied after section 4, because
      `set_name()` rewrites `_named`. No load orchestrator exists to hold that
      order.
- [ ] Registry and architecture rows for the codec's transient `Record` column,
      and the §2.2 `name_key` I32-versus-`PackedStringArray` divergence, are
      reported to the integration owner; neither file was on this task's
      allowlist.

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

- [ ] **BLOCKER D2 — still open, and now more visible.** A world reloaded through
      `apply()` carries every slot, generation and retirement faithfully and still
      reissues persistent IDs from 1, because §1 WORLD has no `next_persistent_id`.
      `restore_columns()` deliberately does not write it; two tests assert the gap in
      the positive so it cannot be forgotten.
- [ ] **Registry rows owed, reported and not applied** (the file is another owner's):
      one category-3 member row for `_last_column_refusal` in
      `docs/persistence_state_registry.md`'s `entity_directory.gd` section, beside the
      existing `_last_refusal` row; and, if that registry is read as recording *how*
      each column is restored, a note on the free-heap row that the ascending refill is
      now `restore_columns()`'s as well as `_rebuild_free_heaps()`'s.
      `state_registry_coverage.py` passes without both, because it checks packed
      columns.
