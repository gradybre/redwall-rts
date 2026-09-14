# D2 allocator, §1 composition and two standing barriers — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


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
