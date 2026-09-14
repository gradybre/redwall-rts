# §14 NAME_POOL landed — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


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
