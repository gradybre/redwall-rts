# 2026-09-12 — §4 component-store bulk columns: `needs`, `residents`, `jobs`

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


[Decision 0132](../decisions/0132-three-component-stores-publish-their-columns-and-rebuild-the-rest.md)
extends decision 0105's directory API to the three largest §4 COMPONENT_COLUMNS owners.
Each publishes `copy_columns_into(out: Columns)`, `restore_columns(columns: Columns)`,
`last_column_refusal()` and `state_bytes()`, plus its declared ordinal tables. The buffers
travel in a per-store `Columns` inner class because the directory's six columns become
twenty, nineteen and forty-two here.

- [x] `needs.gd` — 20 §4 columns. `_present_count` / `_living_count` recomputed; the
      256-living cap is checked against the recomputed number before any write.
- [x] `residents.gd` — 19 §4 columns. `_live_slots` rebuilt ascending; each present row's
      self-reference must resolve through §3 to its own typed row. `_name_key` stays
      §14's: `restore_columns()` installs `_named` and empties every name, and
      `unresolved_name_row_count()` counts the rows §14 still owes.
- [x] `jobs.gd` — 38 §4 columns plus the 4 §5 CHILD_ARENAS chain columns in one
      transaction. `_job_persistent_id`, `_agent_persistent_id`, `_live_slots`,
      `_bucket_begin`, `_live_count`, `_agent_count` and `_deepest_continuation_bucket`
      are all rebuilt; the worker binding is checked in both directions and every member
      chain is walked under a `JOB_CAPACITY` step cap.
- [x] Restore ORDER is enforced, not assumed: §3 before `residents.gd`; §3 and
      `residents.gd` before `jobs.gd`.
- [x] A refused restore leaves each store byte-identical, asserted by `state_bytes()`
      comparison in every refusal test.

**What is now unblocked.** A codec holding these three stores can capture every
category-1 column including free rows, and install a validated set back. That is the
whole of what this adds.

**What is still open, and it is not small.**

- [ ] There is **no §4 COMPONENT_COLUMNS codec and no §5 CHILD_ARENAS codec** in this
      repository. These are the store halves only; nothing yet turns them into section
      bytes. **No release-save completeness is claimed.**
- [ ] The other §4 owners still publish no bulk column API: `inventory.gd`, `gear.gd`,
      `buildings.gd`, `farming.gd`, `fishing.gd`, `forage.gd`, `orchard_hive.gd`,
      `injury.gd`, `priorities.gd`, `schedule.gd`, `reservations.gd`, `work.gd`.
      Decision 0132's shape is available to copy.
- [ ] **BLOCKER J2 is untouched.** It names `job_planner.gd`, a different module from
      `jobs.gd`; §8's own capture and apply still refuse `SAVE_JOB_STORE_NO_COLUMN_API`.
- [ ] Registry rows owed and not applied (files outside that work's allowlist): one
      category-3 `_last_column_refusal` member row per store in
      `docs/persistence_state_registry.md`. **No ledger byte is owed** — no new packed
      column was added, and a refusal-code `StringName` is a scalar that is not
      persisted and is excluded from `state_bytes()`.
