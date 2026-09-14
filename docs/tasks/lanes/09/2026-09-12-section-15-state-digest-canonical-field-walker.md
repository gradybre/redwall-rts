# §15 STATE_DIGEST canonical field walker — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


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
