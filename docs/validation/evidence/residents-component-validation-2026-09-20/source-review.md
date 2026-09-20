# Independent source review — residents component validation (2026-09-20)

Scope: `godot/scripts/core/residents.gd`, `save_owner_residents.gd`, `test/test_save_owner_residents.gd`,
`tools/test_residents_metadata_preflights.py`, `run_mutants.py`, read against
RESIDENTS-S4-VALIDATE-R01 v1 and ADR 0178. Reading only; nothing was executed or applied here, and
no result below is a test outcome produced by this review.

## Confirmed by reading

- `columns_refusal` is static and argument-only: it constructs nothing, mutates nothing, and reads
  no catalog, Directory or Needs state. It is the shared prefix, then species-then-arrival per
  present row, exactly as contracted.
- `_restore_column_refusal` keeps `_catalog_error` first, calls the shared prefix, then the
  original live walk (species, compiled size, arrival, Directory) per row; the saved predicate is
  not called from it, so no later-row arrival can outrank an earlier-row size or Directory fault.
- The prefix preserves the published order and codes: shape before indexing, present/named then
  size/stage/role byte scans over all 512 physical rows, XP/level/reserved over all 6144, ascending
  reference and equipment shape, free-row rules, then the 256 present cap with 512 storage.
- Inactive rows retain full signed species (i32) and arrival (i64) history; nothing normalizes them.
- `set_arrival_tick` keeps `REFUSE_NOT_PRESENT` first, then the shared scalar rule, then the write;
  a refusal cannot reach a column. `REFUSE_INVALID_ARRIVAL_TICK` is distinct from the unchanged
  `COLUMN_ARRIVAL_TICK` spelling. The parent fixture correction to the real `RESIDENT_NOT_PRESENT`
  constant is right; no production namespace change is requested.
- The null guard sits in `_columns_are_capacity_sized`, which both `copy_columns_into` and
  `restore_columns` reach before any member access, so both refuse false/COLUMN_SHAPE without
  touching a Nil column. `skill_level_for_xp` is now a wrapper over the private static curve.
- Bridge gates are ordered null, owner!=12, forwarded `Schema.schema_refusal`, metadata plus source
  pins, forwarded `Section.owner_shape_refusal`, explicit assignment of all nineteen canonical
  accessors, then the exact raw column code wrapped with `Residents owner 12 `. Preloads are limited
  to Residents/Schema/Section/SaveHeader; there is no live owner, restore or copy call, and the
  projection assigns rather than duplicates, so the framed record is not mutated.
- Budget re-derived from the declarations: 2560 u8 + 22528 i32 + 24576 level + 4096 arrival +
  49152 XP = 102912; 102912 caller + 102912 transient defaults + 49152 sorted XP copy = 254976,
  below 6417408. This is allocation arithmetic only; no native, RSS or performance claim is made.
- Mutation sites enumerate to 47 assertion oracles plus the one null runtime-error oracle, and
  `run_mutants.py` asserts 52 results and 48 kills, per-run test count and absence of parse errors.

## Defects and blockers

1. Blocker (evidence, not code): the 48 required mutants and 27 metadata cases are pending. No
   acceptance may be recorded from this packet; the recorded 9/47336/0 focused log and the earlier
   null and priority probes are prior artifacts, not re-verified here.
2. Defect (harness): `run_mutants.py` invokes `res://test/residents_validation_focus.gd`, which is
   neither supplied in this packet nor written by the script, unlike the metadata harness which
   creates its own focus file. Confirm the runner exists and discovers exactly the one suite, or
   every run reports invalid execution instead of a kill.

## Optional notes (not blockers)

- Acceptance-domain coverage gaps: equipment `item 0 / durability 0` and a present-row CHILD stage
  are legal endpoints named by the contract but not exercised as accepted fixtures.
- The bridge pins the null handle through `Residents.EntityDirectory.NULL_SLOT`; a direct pin on the
  Directory constants would make that dependency explicit.
- Nineteen omission witnesses are acceptance-domain kills by design; any that refuse later for a
  different reason must be labelled honestly in the results file.
