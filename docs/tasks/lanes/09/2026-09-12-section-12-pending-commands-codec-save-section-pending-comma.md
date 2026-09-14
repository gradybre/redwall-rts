# 2026-09-12 — §12 PENDING_COMMANDS codec (`save_section_pending_commands.gd`)

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


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
