# 0137 — Construction's columns were implemented state that was never declared
Date: 2026-09-14 · Status: Accepted

## Decision

`docs/planning/canonical_state_registry.json` now declares construction.gd's **seventeen**
category-1 packed columns: sixteen project columns as `(section_id 4, owner_key
"construction", owner_schema_version 1)` and the delivered-material ledger as
`(section_id 5, owner_key "construction", owner_schema_version 1)`. All seventeen are
`hash: true` and carry the new `source_contracts` key **C172**.

Three pins move with them, and each is a snapshot rather than a constant of the format:

| Pin | Was | Is | Why |
|---|---:|---:|---|
| `record_count` | 582 | 599 | Seventeen NEW `hash: true` declarations, so seventeen new records |
| `packed_source_field_count` | 536 | 553 | Seventeen packed columns gained a `source_contract` |
| `CANONICAL_OWNER_COUNT` | 50 | 52 | Two new `(section, owner)` blocks |

`CANONICAL_FIELD_COUNT` moves 590 → 607 as a consequence of the first.

Section 4's field order is `_present` first — ARCH-SAVE-002's occupied bitset rule — then
construction.gd's own declaration order for the other fifteen. `_present` is declared at
construction.gd:334, *after* `_material_container_slot` at 324, so this is a deliberate
hoist, not transcription. It is the same hoist `(4, "needs")` and `(4, "buildings")` already
carry.

`tools/generate_canonical_state_table.py` is added: it compiles the marker-delimited table at
the bottom of `godot/scripts/core/canonical_state_hash.gd` out of that JSON, and `--check`
refuses on drift without writing.

## Why

**REG-R01 forbids exactly this omission.** Its growth paragraph permits registering an
unimplemented store late, then closes the door: "This is an adopted development compatibility
policy, **not permission to omit implemented state**." Construction was implemented, was
classified category 1 in `docs/persistence_state_registry.md`, and had no declaration at all.
`validate_save_registry_handoff.py::validate_source()` had been failing on it, naming all
seventeen. Astra's cycle-1 audit records it as the one unrecorded schema omission the audit
found, "a concrete unrecorded schema omission ... that must be repaired, not accepted as an
exclusion."

**`record_count` moves here and did not move for section 11, and the difference is the point.**
Decision 0133 landed `event_schedule.gd` and moved `packed_source_field_count` 530 → 536 while
leaving `record_count` at 582, because SAVE-R09-005 had already *declared* those eight fields;
the module's arrival only gave them a source. Construction's seventeen were never declared, so
they are new records and `record_count` must move. REG-R01 says the same thing from the other
side: do not "fabricate zero-valued progression/community/hazard stores merely to hold
record_count constant" — the count follows the declaration, never the reverse. Both pins now
carry that reasoning in a comment beside the number, in the validator and in the test.

**One contract key, computed.** `C172` was derived as `max(int(k[1:]) for k in
source_contracts) + 1` from the file itself. A previous lane proposed C168 from a document
while C168–C170 were already taken; reading a number out of prose is how that happens. One key
covers both blocks, which `C022` already does across eight blocks, and which matches the
recent one-key-per-arriving-store pattern of C168 (needs), C169 (work) and C170 (injury).

**The bill tables stay out.** `_build_key`, `_build_milli`, `_build_count`, `_upgrade_*` and
`_furniture_*` are category 2 immutable catalog recompiled from `gameplay_balance.md` §4.1–4.3
on construction. Declaring them would create a second source of truth for numbers the catalog
already owns.

**A compiled table nobody can regenerate is a table that drifts.** `canonical_state_hash.gd`'s
header has named `tools/generate_canonical_state_table.py` since decision 0127, but the script
did not exist, so 590 entries were hand-maintained. Proof that the new script is faithful
rather than merely plausible: run against the **pre-change** registry it reproduced the
checked-in table byte for byte except for one number — the header comment said "530 persisted
packed fields" when the registry had said 536 since decision 0133. A hand-maintained generated
table had already drifted from its own source.

## What this does NOT do

* **No section or owner version moves.** The two new blocks are additions at
  `owner_schema_version 1`; no existing owner's field set changed, so nothing is "affected" in
  REG-R01's sense. `section_schema_versions` is untouched, matching
  `cycle_01_world_schema.json`'s "other owner and section versions: unchanged by this scoped
  delta". When a section 4 or 5 **body** exists, its owner re-audits that with the rules
  identity; there is no codec today to pin either number.
* **R-WORLD-S1-001 is untouched.** `resource_nodes`' three deposit members are still declared,
  `resource_nodes.owner_schema_version` is still 1 and `section_schema_versions[0]` is still 2.
  That ruling activates atomically with SAVE-S1-OWNERS' implementation and is not this lane's.
  Its arithmetic note is now satisfiable: 599 and 553 are the integrated totals its "-3 only"
  figures of 579 and 533 were explicitly forbidden to be pinned as.
* **No adapter.** `production_walker()` still refuses with `CANONICAL_NO_ADAPTER`; the list it
  refuses with is now 52 owners rather than 50. Declaring state is not producing it.
* **`source_module_sha256` is left alone.** It is a 197472b snapshot: nine of its 47 entries
  already disagree with the working tree and seven core modules including `construction` are
  absent from it. Half-refreshing it would make a stale inventory look current.

## Consequences

`validate_save_registry_handoff.py --source-root .` passes for the first time since the
construction store landed. `godot/test/test_canonical_state_hash.gd` gains two tests that pin
the section-4 key order and type codes, and the section-5 arena, **independently of the JSON**:
the pre-existing tests only prove the compiled table and the registry agree, which a consistent
edit to both satisfies. Mutation G5 demonstrated that gap — reordering the JSON into
construction.gd's declaration order and regenerating the table left the Python validator and
every pre-existing Godot test green, and only the new test failed.

`validate_save_registry_handoff.py` is still **not run by CI** (`.github/workflows/tests.yml`
runs `state_registry_coverage.py` but not this one), and `generate_canonical_state_table.py
--check` is not run either. Both are outside this lane's file ownership.

## Sources

- [REG-R01](../rulings/2026-09-12_save_registry_answers.md) — registry growth and block ownership
- [`docs/planning/astra_cycles/cycle_01.md`](../planning/astra_cycles/cycle_01.md) and
  [`cycle_01_world_schema.json`](../planning/astra_cycles/cycle_01_world_schema.json)
- [decision 0127](0127-the-canonical-field-walker-refuses-what-it-cannot-hash.md) — why the table is compiled
- [decision 0133](0133-section-eleven-gets-the-store-the-registry-already-declared.md) — the contrasting pin
- [decision 0131](0131-the-construction-store-owns-the-project-lifecycle-not-a-second-building-store.md) — the store being declared
- [`docs/persistence_state_registry.md`](../persistence_state_registry.md) — the category-1 classification
