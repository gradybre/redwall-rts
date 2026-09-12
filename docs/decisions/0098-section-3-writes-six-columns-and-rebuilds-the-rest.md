# 0098 — Section 3 writes six columns, rebuilds the rest, and refuses to publish

Date: 2026-09-12 · Status: **Accepted**

[SAVE-LAYOUT-R01](../rulings/2026-09-12_clock_restore_and_layout_followup.md) fixes
section 3's block framing and column order, and
[SAVE-R09](../rulings/2026-09-11_save_codec_contract.md) fixes the container it sits
in. This record fixes the judgements that implementing
`godot/scripts/core/save_section_directory.gd` required, and names precisely what it
did **not** build. It does not claim task 09.2 complete, does not certify a
production save, and closes no 09.3 continuation gate.

**ADR number allocated from master's 0097 ceiling while four other agents were
allocating concurrently. Expect renumbering.**

## Decision

1. **Exactly six columns are written, and the category-2 members are rebuilt.**
   `_active`, `_generation`, `_retired`, `_persistent_id`, `_kind` and `_typed_row`,
   in SAVE-LAYOUT-R01's stated order, each at the full `DIRECTORY_CAPACITY` of
   352418. `_typed_owner_slot`, `_free_heap`, `_heap_index`, `_kind_base`,
   `_kind_free_count`, `_kind_live_count`, `_free_count` and `_live_count` are not
   written at all. The registry already classified them category 2; the
   implementation reason is sharper than "derived". `_pop_min()` returns the
   **window minimum**, so allocation order depends on the SET of free entries and
   never on the permutation the array happens to hold — which means a rebuilt
   ascending heap allocates identically, and also means the tail beyond
   `_free_count` is *stale garbage*. Two worlds identical in every observable way
   can hold different garbage there, so writing the heaps would give them different
   section bytes and different CRCs. That is a correctness defect, not waste.
   `test_the_free_set_alone_decides_the_next_allocation` pins the property the
   rebuild depends on against the live store.

2. **Persistence obligation and digest membership are separate axes, and for
   section 3 the two lists coincide — as a finding, not an assumption.**
   Decision 0063's axes are applied explicitly: ARCH-HASH-001 includes "all
   authoritative occupied/generation and typed fields in schema order" and excludes
   "derived spatial/active indexes". All six written columns are therefore hashed;
   every category-2 member is excluded from **both** saving and hashing. Section 3
   has no saved-but-not-hashed field of the kind `save_section_world_runtime.gd`
   carries in host debt and the six clock counters, and the module says so rather
   than leaving a reader to infer it.

3. **Retirement is cross-checked in both directions, per slot and per column.**
   The registry notes retirement "is also implied by `_generation[slot] >=
   2147483647`, so a loader can and should cross-check the two rather than trust
   either alone". Both halves are enforced: every retired slot must be inactive and
   hold exactly the spent generation, and the count of inactive slots holding the
   spent generation must equal the retirement count. Neither check subsumes the
   other — mutation testing proved it. Dropping the per-slot check survived the
   suite until a test was added for a *balanced swap*: slot A retired at generation
   10 while slot B holds the spent generation un-retired. The counts cancel; only
   the per-slot check sees it. A loader that trusted the count alone would hand A
   back to the allocator and never reuse B.

4. **Every four-byte field is read SIGNED.** GDScript ints are 64-bit, so
   `0x80000000` is a positive 2147483648 and `-2147483648` is the same four bytes
   read as int32. Generation lives at exactly that boundary: 2147483647 is the last
   value a slot spends before it retires. `save_codec.gd` carries signedness
   explicitly and never infers it from a width, so `00 00 00 80` decodes as
   -2147483648 and is **refused** as a negative generation rather than accepted as a
   plausible 2147483648 no i32 column could hold.

5. **The section is streamed, not materialised, because ARCH-SAVE-003 says large
   sections are.** At 6343616 bytes this is sixty thousand times section 10.
   `ChunkCursor` emits at most 65536 bytes per chunk, field-aligned so no chunk
   straddles two columns, driven by the caller. The cursor does **not** fold the CRC
   itself: `save_header.gd::crc32_update()` is already the incremental register API,
   and the caller has to fold the body SHA-256 over the same bytes anyway.
   `encode_record()` concatenates the same chunks for a caller that genuinely wants
   one buffer, and says so.

6. **Bulk packed-array conversion is used, and the byte-order assumption it
   introduces is turned into a refusal.** Writing 2114508 values through
   `save_codec.gd`'s per-value Writer would be a multi-second cold path;
   `PackedInt32Array.slice().to_byte_array()` and `PackedByteArray.to_int32_array()`
   are single C++ copies and encode/decode in under ten milliseconds each. Those
   conversions inherit the **host's** byte order rather than the codec's explicit
   little-endian, so `byte_order_refusal()` probes `save_header.gd`'s own
   `ENDIAN_SENTINEL` (0x01020304) on every encode and every decode. Every Godot
   target is little-endian; an assumption nobody checks is how a save silently
   transposes every generation on the machine where it is not.

7. **Free-slot unused values are proved by counting, not by a 352418-slot walk.**
   Every live slot is validated individually (`find(1, …)` jumps between them in
   C++), which proves no live slot holds an unused value. The whole-column counts of
   `persistent_id == 0`, `kind == -1` and `typed_row == -1` must then equal the
   inactive count, which forces those values onto exactly the inactive slots. The
   negative-generation bound is one C++ sort of a copy, reading only the minimum.
   Validation cost is O(live rows) plus a handful of whole-column C++ calls.

8. **No `apply()` is published, and no private column of another module is
   touched.** See the blockers below. `save_section_world_runtime.gd` hit the same
   wall against `sim_clock.gd`, refused to half-publish, and Astra then ruled the
   missing API into existence as RESTORE-R01's `restore_runtime()`. This module
   takes the same position rather than becoming the first in this repository to
   reach into another module's underscore-prefixed columns.

## Blockers this work did not close

**BLOCKER D1 — `entity_directory.gd` can neither be read nor written in bulk.** Its
public surface answers only for LIVE slots, so the generation of an inactive slot —
the one value the registry insists must survive verbatim — is unreachable. There is
no writer for any column, and no reachable variant of `_rebuild_free_heaps()` that
excludes live slots. `capture_columns_into()` is therefore the capture step and takes
the six columns from whoever can supply them; `capture_into(store, …)` **refuses
explicitly** and names the missing API. The directory owner needs:

```gdscript
func copy_columns_into(out_active: PackedByteArray, out_generation: PackedInt32Array,
	out_retired: PackedByteArray, out_persistent_id: PackedInt32Array,
	out_kind: PackedInt32Array, out_typed_row: PackedInt32Array) -> bool
func restore_columns(active: PackedByteArray, generation: PackedInt32Array,
	retired: PackedByteArray, persistent_id: PackedInt32Array,
	kind: PackedInt32Array, typed_row: PackedInt32Array) -> bool
```

`restore_columns()` must, after assigning the six, rebuild `_typed_owner_slot`, both
heaps and all five counters from them, excluding live slots from `_free_heap` and
filling every window **ascending** — ascending fill is what makes the rebuild
canonical, because it is what makes the next `create()` return the lowest free slot.

**BLOCKER D2 — `_next_persistent_id` is registered to §1 WORLD and nobody writes
it.** It is future-affecting and not derivable, because `destroy()` zeroes
`_persistent_id`, so "max live id + 1" is wrong the moment anything has died. The
registry assigns it to §1 as `WorldRuntime.next_persistent_id`, but
`save_section_world_runtime.gd`'s 80-byte block does not carry it and
`entity_directory.gd` exposes no reader for it. Until both owners act, a reloaded
world restarts persistent IDs at 1 and breaks ARCH-SAVE-004's unique-persistent-id
validation. Section 3 must not fix this by writing the scalar itself; that would put
one future-affecting value in two sections.

**Open, not invented.** `owner_key` is `"entity_directory"`, read off
SAVE-LAYOUT-R01's own phrase "exactly one entity_directory block"; no document
publishes a formal section-3 owner-key registry. `owner_schema_version` is 1, from
"Adopt the above as the initial section3/4/5/10 schema1 framing"; the 64-byte
descriptor's `schema_version` is a different number and is still carried opaquely by
`save_header.gd`. SAVE-R09's canonical `field_key` strings are **not** emitted: the
ruling requires the save owner to freeze the ordered canonical registry with each
store owner before a production digest, and that registry does not exist, so
`ColumnCursor` emits canonical **values only** and leaves the
`section_id/owner_key/field_key/type/value_count` prefix to section 15.

## Consequences

- `docs/persistence_state_registry.md` owes one category-3 codec row for the new
  module; `state_registry_coverage.py` fails with exactly one `C1` message until it
  lands. The exact row was drafted and verified to turn that check green, then
  reverted because the registry is outside this work's file allowlist.
- `Record` (6343524 bytes) and `Derived` (1409816 bytes) are **bounded codec
  scratch** on ARCH-SAVE-003's cold path, not new authoritative columns and not a
  second world. Neither exists between a save and a load. The streaming path holds
  at most 65536 bytes at a time.
- Section 3 cannot round-trip a live world until D1 is closed, and a round-tripped
  world will reissue persistent IDs until D2 is closed. Both are named in the module
  header and asserted by a test, so neither can be quietly forgotten.
