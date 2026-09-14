# SAVE-REGISTRY-RECONCILE — construction's seventeen columns — 2026-09-14

Task: 09_persistence_replay_reliability.md
Date: 2026-09-14

Astra cycle 1 step 2. `validate_save_registry_handoff.py --source-root .` was failing with
`packed registry drift: added={17 construction fields}, missing=set()`. See
[decision 0137](../../../decisions/0137-construction-columns-were-implemented-state-that-was-never-declared.md).

- [x] All seventeen category-1 `construction.gd` columns registered under REG-R01, derived
      from the GDScript declarations and `docs/persistence_state_registry.md`, not guessed:
      sixteen project columns as `(4, "construction", v1)` and `_delivered_milli` as
      `(5, "construction", v1)`. Types read from the packed declaration — `u8` for `_present`,
      `_paused`, `_work_begun`; `i64` for `_remaining_mwu` and `_delivered_milli`; `i32` for
      the other twelve. Capacities quote the module's own constants,
      `CONSTRUCTION_CAPACITY` = 82944 and `DELIVERED_CELLS` = 331776.
- [x] Ordinals: `_present` at 0 per ARCH-SAVE-002's occupied-bitset-first rule, then
      construction.gd's declaration order. `_present` is declared at line 334, after
      `_material_container_slot` at 324, so this is the same deliberate hoist `(4, "needs")`
      and `(4, "buildings")` carry — not transcription.
- [x] New `source_contracts` key **C172**, COMPUTED as `max(int(k[1:])) + 1` from the file.
      C168–C171 were already taken; a previous lane proposed C168 by reading a document.
- [x] `record_count` 582 → 599 — these are seventeen NEW `hash: true` declarations, unlike
      section 11's eight, which were declared before their module existed and moved only the
      packed count. `packed_source_field_count` 536 → 553. Both pins carry the reason beside
      the number in `validate_save_registry_handoff.py` and in `test_canonical_state_hash.gd`.
- [x] `tools/generate_canonical_state_table.py` added and the compiled table regenerated:
      52 owners, 607 declared fields. Faithfulness proof: run against the PRE-change registry
      it reproduced the checked-in table byte for byte except the header comment's stale "530
      persisted packed fields", which had read 536 since decision 0133.
- [x] Two new tests pin the construction declarations independently of the JSON. The
      pre-existing tests only prove the table and the registry agree; mutant G5 showed a
      consistent edit to both is invisible to them.
- [x] `docs/persistence_state_registry.md`: §15 walker resident-byte arithmetic recomputed
      (9937 fixed + 8987 key text = 18924, from 9650 + 8734 = 18384), and the construction
      occupancy row now records the ordinal-0 hoist so a codec does not walk GDScript order.

## Verification

```
python3 docs/validation/validate_save_registry_handoff.py --source-root .
  PASS 31 independent name, cursor, UTF-8 framing and name-section-bound fixtures
  state_registry_coverage: PASS -- 54 modules, 352 rows, 681 packed columns checked
  PASS source membership/types: 553 persisted packed fields
  PASS registry structure: 52 owners, 599 canonical records
python3 docs/validation/state_registry_coverage.py  PASS -- 54 modules, 352 rows, 681 columns
python3 docs/validation/ready07_arithmetic.py       {"status": "PASS", ...}
python3 docs/validation/decision_numbers.py         PASS -- 130 records, 0 problem(s)
python3 docs/validation/merge_gate.py               PASS -- ledger only, 0 problem(s)
python3 tools/lane_notes.py --check                 PASS -- 39 lane record(s), 0 problem(s)
./tools/run_tests.sh   ok: 4338 tests, 152837 assertions, 0 failures.
```

Mutation testing, one mutation per invocation, every file restored and `shasum -a 256`
byte-compared afterwards. 12 mutants, 12 killed.

| # | Mutation | Killed by |
|---|---|---|
| G1 | compiled table: `"_work_begun"` → `"_work_begon"` | 2 Godot failures |
| G2 | registry JSON: construction `_remaining_mwu` i64 → i32, table untouched | 1 Godot failure |
| G3 | compiled `CANONICAL_RECORD_COUNT` 599 → 582 | 2 Godot failures |
| G4 | compiled `OWNER_FIELD_COUNTS` construction 16 → 15 | 6 Godot failures |
| G5 | JSON reordered into GDScript declaration order **and table regenerated** | 1 Godot failure — the new test only |
| P1 | JSON: `_phase` ordinal 15 → 14 | validator, exit 1 |
| P2 | JSON: `source_contract` removed from `_work_begun` | validator drift, exit 1 |
| P3 | JSON: `packed_source_field_count` 553 → 536 | validator, exit 1 |
| P4 | JSON: `record_count` 599 → 582 | validator, exit 1 |
| P5 | validator's own 553 pin → 536 | validator, exit 1 |
| PG1 | generator counts all fields instead of `hash: true` | `--check` DRIFT, exit 1 |
| PG2 | generator wrap width 100 → 96 | `--check` DRIFT, exit 1 |

**G5 is why two tests were added rather than none.** The Python validator PASSED and every
pre-existing Godot test PASSED against a canonical order that walks `construction.gd`'s
declaration order instead of ARCH-SAVE-002's. That is a digest that is stable, plausible and
wrong, and nothing in the repository saw it.

## Not claimed by this lane

- **No adapter.** `production_walker()` still refuses `CANONICAL_NO_ADAPTER`, now naming 52
  owners instead of 50. Declaring state is not producing it.
- **No section 4 or 5 codec body, and no section/owner version movement.** The new blocks are
  additions at version 1. When a body exists its owner re-audits section versions with the
  rules identity.
- **R-WORLD-S1-001 untouched**, as instructed: `resource_nodes`' three deposit members remain
  declared, its `owner_schema_version` is 1 and `section_schema_versions[0]` is 2. Its "-3
  only" figures of 579/533 were explicitly forbidden as final pins; the integrated totals are
  599/553.
- **`source_module_sha256` deliberately left stale.** Nine of 47 entries already disagree with
  the tree and seven core modules including `construction` are absent. A half-refresh would
  make a snapshot look current.
- **CI gap, outside this lane's ownership.** `.github/workflows/tests.yml` runs
  `state_registry_coverage.py` but NOT `validate_save_registry_handoff.py`, which is the check
  that catches this class of defect, nor `generate_canonical_state_table.py --check`.
