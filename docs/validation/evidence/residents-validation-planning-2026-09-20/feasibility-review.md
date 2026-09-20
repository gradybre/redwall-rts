# Residents owner 12 — independent feasibility review

2026-09-20. Read-only. Everything below is read from the supplied sources; nothing was built, probed
or executed, so no statement here is observed behaviour. This is a feasibility opinion, not a
contract and not dispatch authority.

## Recommended shape

A pure static local predicate plus a framed bridge is feasible, and the `Columns` inner class
should carry it. ADR 0132 §2 already rejected positional parameters for this owner — nineteen
argument lists are not reviewable — so `static func columns_refusal(columns: Columns) -> StringName`
is the right signature, mirroring the Needs owner-9 pattern rather than inventing a second one.
The bridge (`save_owner_needs.gd` shape: null record, owner index, `Schema.schema_refusal`,
owner-local metadata parity with a distinguishing detail prefix, `Section.owner_shape_refusal`,
explicit nineteen-field projection, owner predicate) can instantiate `Columns` alone. It must not
construct `Residents`, which compiles the species and rig catalogs and builds Directory and Needs
collaborators.

The split that makes this work is by dependency, not by convenience. Shape, byte domains, skill
XP/level/reserved-index, reference well-formedness, the free-row rule and the present-count bound
are argument-only and extract cleanly. The catalog-error gate, the per-row species-range and
size-class cross-check, and the self-reference Directory resolution are not: the first two read the
instance's compiled `_species_size`, the third reads a live directory. Keep those in the live
restore path, in their current position and order. The saved-side checks should be limited to
species id in 0..15 and arrival tick >= 0, with no catalog size lookup and no Directory resolution;
saved catalog, Directory, Needs, name and equipment agreement stay explicitly outstanding.

## Hazards

Gate order is load-bearing and currently begins with the catalog-error check before shape.
Extracting a pure predicate that starts at shape silently changes which code a doubly-bad image
reports. Either preserve the legacy order by leaving the catalog gate ahead of the shared predicate
in the live path, or record the reordering as a deliberate decision — do not let it happen as a
side effect.

`copy_columns_into` and `restore_columns` reach `_columns_are_capacity_sized(out)` and index the
record without a null test; a null argument appears to be a script error rather than a refusal. A
shared null guard inside the sized predicate, returning the existing `COLUMN_SHAPE` code, is the
bounded fix and matches what Needs did.

`set_arrival_tick` accepts any signed int64 while restore refuses arrival < 0 on present rows. A
negative tick can be written publicly and then rejected on restore. An atomic refusal in the setter
with a new `OpResult` code is the clean repair, but it must not erase retained inactive histories
that already carry such values; the inactive-row rule does not bound arrival today.

The generic reference setters accept any non-negative int32 slot with positive generation, which is
wider than any saved Directory or container identity. Do not tighten them from arena capacities
alone. `present.count(1) <= 256` and the directory's active-resident cap coexist with dead-but-
present rows and end-of-tick release; this reads as a terminology mismatch, not a proven cap bug,
and declaring one needs lifecycle authority. Storage stays 512, so every physical row matters.

The transient-defaults allocation in `Columns._init()` — 102912 bytes of values, replaced field by
field — is acceptable if charged explicitly, as the Needs contract charged its 135168. Do not call
it zero-allocation. The existing sorted-copy helper pattern can replace the pure XP count scan, but
the 49152-byte int64 copy must be budgeted rather than assumed free.

## Missing decisions

Whether `skill_level_for_xp` becomes static outright, breaking or restyling callers, or stays an
instance method delegating to a new static helper. Whether the legacy catalog-first refusal order
is preserved or deliberately changed. Whether the negative-arrival repair lands in this slice and
under which code. Whether inactive rows gain any arrival or species bound at all. Who owns the cap
and lifecycle reconciliation.
