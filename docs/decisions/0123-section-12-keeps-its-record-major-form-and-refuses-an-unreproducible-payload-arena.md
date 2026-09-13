# 0123 — Section 12 keeps its record-major form, and refuses a payload arena no restore can reproduce
Date: 2026-09-12 · Status: Accepted

## Context

`godot/scripts/core/save_section_pending_commands.gd` is the ARCH-SAVE-002
section 12 PENDING_COMMANDS codec. Section 12 carries two owners' queues:
`commands.gd`'s economic edits and `scheduler_events.gd`'s speed/pause events.
Three questions had to be settled before a byte could be written, and two of
them are answered against the instruction this lane opened with.

## Decision 1 — §12 uses SAVE-LAYOUT-R01's record-major exception, not the generic owner wrapper

The lane brief specified `store_count:u32` followed by one standard owner block
per owner in ASCII key order, column-major. **That framing is the one
SAVE-LAYOUT-R01 explicitly exempts section 12 from**, in its "RNG and
fixed-format exceptions" section:

> Retain the existing explicit formats: section1's 44-byte provenance prefix;
> section2's u32-sized opaque JSON artifact; section11's i64 sequence allocator
> plus 32-byte records; **section12's schema2 prefix, 64-byte economic records,
> payload and record-major SCHQ0001 extension**; section13's 24-byte Chronicle
> records; section15's 32-byte digest. **Their record layouts override the
> packed-store default.**

REG-R01 repeats it: "Preserve the distinct existing forms of §10, §11, §12, §13
and §15 in SAVE-R09 / SAVE-LAYOUT-R01." `AGENTS.md`'s authority order puts
`docs/rulings/` above a working instruction, so the ruling wins and this record
exists so the divergence is not silent.

Four further facts point the same way and are why this is a reading rather than
a preference:

1. **The "already 2" schema version is physically the prefix's first u32.**
   REG-R01's baseline vector `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]` notes "§12 was
   already 2", and `scheduler_events.gd::SECTION_SCHEMA_VERSION_TWO` is written
   at offset 0 by `encode_section_prefix_into()`. The generic wrapper has no
   field to carry it.
2. **`scheduler_events.gd` already ships the arithmetic**, under the header
   comment "container version 2's section 12 arithmetic":
   `section_twelve_length()`, `section_twelve_refusal()` and
   `encode_section_prefix_into()`. A different framing would strand three
   tested, adopted functions.
3. **REG-R01's own §12 field ordinals reproduce the record field orders.**
   `commands` ordinals 4..18 are §8.1's 64-byte record fields in §8.1's order;
   `scheduler_events` ordinals 7..13 are the 32-byte record's. REG-R01 itself
   separates the two axes: "The artifact defines the logical field-record
   stream" — it is §15's walker order, not necessarily the wire order.
4. `docs/planning/ready07_scheduler_contract.md` states the byte map in full
   (`72 + 64*E + P + 32*S`) and `docs/persistence_state_registry.md` cites it by
   line number on the pending-command rows.

**Both owner keys still exist and still order ASCII-first.** `commands` supplies
the 24-byte prefix and the economic records; `scheduler_events` supplies the
trailing `SCHQ0001` extension, in that order and with no gap. The module exposes
`OWNER_KEY_COMMANDS`, `OWNER_KEY_SCHEDULER`, `FIELD_KEYS_COMMANDS` (20 ordinals)
and `FIELD_KEYS_SCHEDULER` (14 ordinals) so §15's canonical walker has the
declared ordinals without re-deriving them from GDScript declaration order.

**If a later ruling does move §12 onto the generic wrapper**, the section schema
version and the whole prefix change together; this is not a layout a reader may
quietly reinterpret.

## Decision 2 — the payload arena persists its live spans and zeroes everything else

Both queues are rings whose tail past `_count` positions from `_head` holds
whatever a drained record left. `save_section_directory.gd` already ruled the
general case for the allocator heaps: two worlds identical in every observable
way hold different garbage there, so writing it makes them produce different
bytes and different CRCs. Section 12 applies the same discipline:

* Rows are read only through `read_into(position, ...)`, which resolves each
  ring's `_head` and, for `commands.gd`, its `_order` permutation. Exactly `E`
  and `S` records are written, in queue order, and **no unused row is
  serialized**. Both `_head` values and `_order` are category 2 in
  `docs/persistence_state_registry.md`; the stored scheduler control head is the
  contract's canonical `0` and `restore_extension()` refuses anything else.
* **The economic payload arena is the count-then-prefix case the ruling names.**
  `P` (the used prefix length) is preserved, because ready07 requires it —
  consumed space "still affects admission". Bytes *inside* that prefix that no
  pending command's span covers are a drained command's leftovers, and they
  differ between two observationally identical worlds. ARCH-SAVE-002's rule,
  quoted on the registry's own arena row, settles it: **"encode zero for unused
  payload."** The live spans are verbatim; every other arena byte is zero, and
  `_payload_refusal()` refuses a Record that is not in that form — including a
  *hole between* two spans, not only a trailing region.

## Decision 3 — an arena base no public API can reproduce is REFUSED, at capture as well as at load

`commands.gd::_allocate_payload()` is a bump cursor that resets only while the
queue is empty, so restoring through `admit_stamped_into()` always lays the
pending payloads out contiguously from offset 0 in canonical order. A world
whose first pending span does not start at 0 — reachable only when a partial
drain left the queue non-empty, which `submit_into()`'s uniform
`completed_tick+1` stamping cannot produce and only a replay stream with mixed
future ticks can — has **no public restore path at all**.

`arena_rebuild_refusal()` therefore refuses such a Record with
`SAVE_PC_ARENA_NOT_REBUILDABLE`, naming the missing API, **at capture as well as
at apply**: writing a save that cannot be loaded is worse than refusing to write
one. This is an explicit refusal, never a sentinel and never a silent
normalisation. Closing it needs `commands.gd` to publish an arena-base restore;
that file belongs to another owner. Recorded as **BLOCKER P2** in the module
header.

## Decision 4 — restore goes through the owners' published APIs, under their own validators

`apply()` never touches an owner's columns. It rebuilds the `SCHQ0001` bytes
from the Record with the same private writer `encode_record()` uses and hands
them to `scheduler_events.gd::restore_extension()`, then calls
`commands.gd::restore_sequence()` and one `admit_stamped_into()` per record in
canonical order. Both restore paths deliberately pass *through* the load
barrier: restore is not a command (RESTORE-R01), exactly as
`save_section_world_runtime.gd` relies on `sim_clock.gd::restore_runtime()`.

Everything is validated before the first mutation (decision 0059): this module's
rules, the arena rebuild gate, both stores empty,
`scheduler_events.gd::extension_refusal()` over the rebuilt subsection, and
`commands.gd::envelope_refusal()` plus the completed-tick floor over every
incoming record. A refusal leaves both collaborating stores byte-identical, and
the suite asserts that by re-encoding them and comparing bytes.

**Ordering obligation on the load orchestrator, stated in the module header:**
§1 WORLD's clock and §3 ENTITY_DIRECTORY must be restored *before* §12.
`admit_stamped_into()` refuses a tick at or before `completed_tick()` and
validates every target `EntityRef` against the live directory;
`restore_extension()` compares every pending boundary against the saved
completed tick. Restoring §12 first would refuse a perfectly good save.

## Evidence

Pinned byte vectors, both asserted in `godot/test/test_save_section_pending_commands.gd`:

* empty section, 72 bytes —
  `0200000000000000000000003000000000000000000000005343485130303031`
  `010000002000000000000000000000000100000000000000ffffffffffffffff`
  `0000000000000000`
* one `DESIGNATE_ZONE` command with a five-byte payload plus one speed-2
  scheduler event, 173 bytes = `72 + 64*1 + 5 + 32*1` —
  `0200000001000000050000005000000001000000000000000100000000000000`
  `00000000000000000000000008000000ffffffff000000000000000000000000`
  `0500000000000000000000000500000000000000000000000102030405534348`
  `5130303031010000004000000000000000010000000200000000000000ffffff`
  `ffffffffff000000000000000000000000000000000100000000000000000000`
  `00000000000200000000000000`

Suite: `3847 test(s), 142779 assertion(s), 0 failure(s)`. Eleven mutations were
applied one per Godot invocation, each restored and `shasum -a 256`
byte-compared; **all eleven died**, including ring garbage past the live window,
a stored ring head that is not the canonical 0, admission in reverse queue
order, a u32 allocator bound read as i32, a prefix sequence half read signed,
the two owner blocks out of order, commit-then-validate in `decode_into()`, an
unchecked `payload_byte_length`, accepted arena garbage and a disabled arena
rebuild gate. Two mutations (`M10`, `M11`) survived their first run and the
tests were strengthened until they died — both survivals were real test gaps,
not harness noise.

**No release-save completeness is claimed.** Section 12 is one section; the
header, the section directory, the canonical digest and every other section's
producer remain other owners' work, and `release_save_ready` stays false.

## Owed registry rows

`docs/persistence_state_registry.md` and `docs/systems_architecture.md` are not
this lane's files. `docs/validation/state_registry_coverage.py` reports exactly
one C1 failure until the registry section lands; the exact row text is in the
lane report.
