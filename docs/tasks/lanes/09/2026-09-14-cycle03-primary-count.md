# SAVE-C3-R01 primary counts bound — 2026-09-14

Task: 09_persistence_replay_reliability.md
Date: 2026-09-14

`godot/scripts/core/save_section_job_indexes.gd`,
`godot/test/test_save_section_job_indexes.gd` and
`godot/test/test_save_section_navigation.gd`, under
[SAVE-C3-R01](../../../rulings/2026-09-14_cycle03_save_counts_and_capacities.md).
Reasoning in
[decision 0146](../../../decisions/0146-section-8-binds-8192-and-section-9-pins-what-a-primary-count-means.md).

- [x] **§8 `primary_count` = 8192**, bound as `PRIMARY_COUNT := SERVICE_ROWS` —
      the designated pending-service row table, written as the planner's constant
      and not as the literal, so the designation follows the table. BLOCKER J1
      closed.
- [x] **Writer and decoder validate against the compiled constant.**
      `encode_section(record, out)` and `decode_section_into(bytes, offset, out)`
      lost their count parameters; there were no production call sites.
      `primary_count_refusal()` accepts 8192 alone and refuses 7, 4096, 5248 and
      14080 by name, each with the reading that produces it. All four are
      positive and u64-representable, so the old `> 0` gate passed every one.
- [x] **`descriptor_row_count()` = 8192, argument-free**, matching §9's shape.
      One block, so SAVE-LAYOUT-R01's checked sum has one term.
- [x] **`SAVE_JOB_PRIMARY_COUNT_UNRULED` retired.**
      `production_write_refusal()` kept and rewritten onto **BLOCKER J2 alone**
      (`SAVE_JOB_STORE_NO_COLUMN_API`), per the ruling's "keep production refusal
      until J2 is actually implemented and tested".
- [x] **Wrapper bytes pinned as one literal hex vector at literal offsets**
      (23, 31, 39): `01000000 0b000000 6a6f625f706c616e6e6572 01000000
      0020000000000000 688a050000000000`. A second, separate test checks the
      module's own `OFFSET_*` constants against those literals, so neither the
      vector nor the arithmetic can move alone.
- [x] **A forged header is refused and writes nothing.** 7 / 4096 / 5248 / 14080
      / 0 are injected straight into the wire at byte 23 — the encoder no longer
      offers a way to produce one — and each full-length section is refused with
      `SAVE_JOB_PRIMARY_COUNT`, leaving the caller's Record byte-identical.
- [x] Capture → encode → decode → re-encode is byte-identical, unchanged.
- [x] **§9 keeps 512 / 8192 and descriptor 8192; zero §9 production bytes
      change.** `save_section_navigation.gd` is byte-untouched. The suite gains
      the descriptor assertion the ruling records as missing, the two wrapper
      words read at absolute offsets 20 and 18558, and the statement that the
      descriptor is **not** the 8704 sum, not 512 and not the 256 route
      descriptors. Existing 511 / 256 corruption cases were left alone.
- [x] Section and owner schema versions unchanged throughout: §8 section 1 /
      owner 1; §9 section 2 / movement 1 / navigation 2. §8 payload 363112,
      section 363151, 29 fields, all extents unchanged.

## Not done, and not implied

- **BLOCKER J2 is open.** `job_planner.gd` publishes no
  `copy_job_index_columns_into()` / `restore_job_index_columns()` pair, so §8 has
  no capture or restore adapter and `capture_into()` / `apply()` still refuse.
  §9's BLOCKER N1 is likewise untouched.
- **No release-save completeness follows.** This lane bound two counts.
  `release_save_ready` stays false and section 15 is unaffected.
- `docs/planning/canonical_state_registry.json` still carries no `primary_count`
  key for `job_planner`. That artifact is REG-C3-R01's sidecar work and another
  lane's file; it was not touched here. The compiled constant is the source until
  that lands.
- `docs/persistence_state_registry.md` was not edited; this change adds no
  authoritative column and alters no ledger row size.

## Evidence

- `./tools/run_tests.sh` → `ok: 4362 tests, 155729 assertions, 0 failures.`
- `merge_gate.py`, `ready07_arithmetic.py`, `decision_numbers.py` and
  `state_registry_coverage.py` all PASS.
- Mutation table in decision 0146's lane report: the primary count changed to the
  14080 sum, to 5248, to 512, to 4096 and to the retired 7 fixture; the
  descriptor count changed; and the decoder's header-versus-constant comparison
  removed. Every mutant was killed.
