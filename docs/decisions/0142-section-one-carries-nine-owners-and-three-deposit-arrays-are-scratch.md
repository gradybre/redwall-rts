# 0142 — Section 1 carries nine owners, and three deposit arrays are scratch
Date: 2026-09-14 · Status: Accepted

## Decision

[R-WORLD-S1-001](../rulings/2026-09-14_world_section_owner_encoders.md) is
activated in one coordinated change. Section 1 WORLD now encodes, decodes,
validates and restores **all nine** registered owners at the ruled offsets, and
the three `resource_nodes` members `_deposit_tiles`, `_deposit_ref_slot` and
`_deposit_ref_generation` are reclassified from category-1 persisted state to
**category-3 operation scratch**. They contribute no save payload, no count
prefix, no null normalization and no canonical field record.

Five things move together, because a tree where the registry says "scratch" and
the encoder still writes it is a broken tree:

1. **`docs/persistence_state_registry.md`** reclassifies the row to category 3
   with no save section, which is what `state_registry_coverage.py` enforces.
2. **`docs/planning/canonical_state_registry.json`** drops the three field
   declarations, takes `(1, resource_nodes)` to `owner_schema_version` **2** and
   `section_schema_versions[0]` to **3**, and changes the rules identity:
   `registry_id` becomes `RWL-CANONICAL-REGISTRY-2026-09-14-2` and
   `registry_version` becomes **2**. `source_contracts` key **C007** is deleted,
   because no remaining declaration cites it.
3. **`tools/generate_canonical_state_table.py`** regenerates
   `canonical_state_hash.gd`'s compiled table from that JSON. The 604 declared
   fields, 596 records and the new `DECLARATION_ID`/`DECLARATION_VERSION` are
   generated, never hand-edited, and `--check` is the CI gate.
4. **`godot/scripts/core/save_section_01.gd`** is the new and only producer of a
   section 1. `save_section_world_runtime.gd` keeps the two fixed-format payloads
   it has always owned and its two-block composer is renamed
   `encode_development_section()`; `encode_section()` now REFUSES by name.
5. **The seven owner modules** gain `copy_section_1_columns_into()`,
   `section_1_local_refusal()`, `section_1_cross_check_refusal()` and
   `restore_section_1_columns()`, so every domain rule is enforced by the store
   that owns it rather than by a second copy inside the codec.

Both registry count pins move DOWNWARD and both carry their reason in the
source: `record_count` **599 → 596** and `packed_source_field_count`
**553 → 550**. Three declarations leave the canonical registry, so three
`hash: true` records leave the first; the same three leave
`persistence_state_registry.md`'s category-1 set, so three persisted packed
columns leave the second. They are snapshot pins that REG-R01 requires to track
the declarations, not constants of the format.

## Why

### Why the deposit arrays are not state

`resource_nodes.gd` declares them under a `# --- scratch` heading and uses them
as the working set of ONE placement. `_refuse_deposit()` writes the sixteen
footprint tiles BEFORE it validates the resource id, the capacity or the
occupancy; `_reserve_deposit_rows()` parks sixteen temporary directory
references in them; and a partial reservation failure hands those rows back
WITHOUT clearing the arrays. A freshly allocated arena additionally holds
default zeros, which name tile 0 and slot 0 rather than "absent", and a later
node destruction leaves a stale reference behind.

The persistence prose described them instead as committed world-generation
output. That reading is contradicted by the lifecycle: persisting them would
have put scratch left behind by a FAILED operation into both the save and the
canonical state hash, and a strict live-reference check on load could then have
rejected a legitimate later world. The committed deposit is not lost by this —
each placed node is an ordinary `ResourceNode` row with its own `_tile` and its
own `_resource_slot` inverse entry, and both remain category 1.

Two alternatives were rejected. Inventing a deposit ledger would have added
gameplay state this lane does not own. Writing three null-filled arrays would
have spent 216 bytes and three canonical records on values with no meaning.

### Why the version and identity change with the implementation

SAVE-R09-001 requires the owning version to move when a field's persistence
changes. Removing three fields changes `resource_nodes`' payload from 65760 to
65544 bytes, so `(section_id=1, owner_key=resource_nodes)` takes schema 2 and
the section takes 3. Older bytes are NOT reinterpreted under the new versions:
`decode_section()` refuses any section that is not exactly 3752768 bytes and
refuses `resource_nodes` at schema 1 by name. No migration is implemented, and
an incompatible development save is refused rather than guessed at.

The scope is narrow on purpose. It is `(1, resource_nodes)` that moves, not
every block `resource_nodes.gd` owns: its section-4 `COMPONENT_COLUMNS` block is
untouched at version 1.

### Why the decoder reads at compiled absolute offsets

This repository has been bitten three times by a check that derived its
expectation from the thing it was checking — §7's `_read_block()` recomputed a
payload length from decoded extents, and §9's ordinal swap survived because
encode and decode swapped together. `save_section_01.gd` therefore takes every
block offset, payload offset, field count offset and field value offset from a
compiled table, and COMPARES each declared extent in the file against it rather
than using it to advance a cursor. `test_save_section_01.gd` reads the wire with
`PackedByteArray.decode_*` at literal offsets transcribed from the ruling, so
neither side can move without the other noticing. The swapped-owner case is
tested with `forage` and `weather` specifically because both keys are the same
length, so a swap leaves every length in the file self-consistent.

### Why payloads are assembled natively, with an endianness gate

A 3.75 MB section written through `SaveCodec.Writer`'s per-value path is roughly
a million GDScript calls. Payloads are instead assembled with
`Packed*Array.to_byte_array()` and `PackedByteArray.append_array()`, which are
native. That conversion is a raw memory copy, so it is little-endian only
because the host is. `little_endian_refusal()` proves that before any of it is
trusted and refuses otherwise, rather than assuming the platform and producing a
plausible file no other build could read.

## Consequences

- Section 1 is **3752768 bytes**, its descriptor `row_count` is **344067** — the
  checked sum of the nine block primary counts — and section 2 begins at
  **3753984**. First body offset 1216 was never blocked by the missing encoders;
  what they blocked was every length after it.
- Section 1 declares **44 stored fields** and emits **36 canonical field
  records**, down from 47 and 39.
- **No release-save completeness is claimed.** `world_runtime` still cannot be
  published (BLOCKER W1: `sim_clock.gd` has no side-effect-free writer), the D2
  cursor is still installed with section 3, the 44-byte provenance prefix still
  has no value producer (SAVE-R09-003), and thirteen sections remain unwritten.
- **`farming._tile_orchard_row` remains an open source-maintenance gate.** The
  field is allocated, initialized to -1, read and persisted, but no writer in
  `farming.gd` populates it. R-WORLD-S1-001 §6 requires the intended live-orchard
  inverse maintenance to be established before anyone claims the reverse orchard
  check passes, so `section_1_cross_check_refusal()` deliberately does not assert
  one: rubber-stamping an all-null column or reconstructing over a contradictory
  one are both forbidden. The field stays registered; removing it is not the fix.
- The ARCH-MEM-009 ledger does **not** move. `save_section_01.State` is 3.75 MB
  of bounded cold-path codec scratch that exists only between a capture and an
  apply, which `systems_architecture.md` already excludes from the resident
  budget for every other `save_section_*` Record.
