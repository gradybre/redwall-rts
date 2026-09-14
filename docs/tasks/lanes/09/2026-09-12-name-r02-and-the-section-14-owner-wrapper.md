# NAME-R02 and the §14 owner wrapper — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


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
