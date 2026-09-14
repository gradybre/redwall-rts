# 09.2 §3 ENTITY_DIRECTORY implementation — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


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
