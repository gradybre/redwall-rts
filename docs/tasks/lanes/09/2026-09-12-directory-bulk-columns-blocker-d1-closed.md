# Directory bulk columns — BLOCKER D1 closed — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


`entity_directory.gd` now publishes and accepts its six category-1 columns, so §3 can
capture a live world and apply a decoded one. See
[decision 0105](../decisions/0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md).

- `copy_columns_into()` is the only reader that answers for an INACTIVE slot, which is
  where the generations the registry requires verbatim live. It refuses a buffer that
  is not `DIRECTORY_CAPACITY` long and hands back snapshots, not aliases.
- `restore_columns()` installs the six and rebuilds `_typed_owner_slot`, `_free_heap`,
  `_heap_index`, `_kind_free_count`, `_kind_live_count`, `_free_count` and
  `_live_count`. Both free windows are filled **ascending**, live and retired slots
  excluded. The duplicate `(kind, typed_row)` check is the rebuild's own collision, not
  a separate pass.
- A refused restore leaves the directory byte-identical, asserted through a new
  `state_bytes()` image rather than by eye. The image emits each free window's live
  prefix **sorted**, because the permutation is not state — only the set is.
- Refusals are read through `last_column_refusal()`, a namespace separate from
  `create()`'s `last_refusal()`; every code is prefixed `COLUMN_`. The spellings are a
  proposal: ARCH-ID-004 publishes no registry for column operations.
- §3 gained `apply()`, and `capture_into()` no longer refuses.
  `test_capture_from_a_live_store_refuses_and_names_the_blocker` and
  `test_module_names_both_open_blockers` were the two tests pinning the blocked
  behaviour; both were rewritten to assert the new contract, each quoting its old
  assertion in the docstring.
- Round trip proved end to end: capture → encode → decode → apply → re-encode is byte
  identical, the reloaded store agrees with its record, and one fixed interleaved
  create/destroy script allocates the same slots and the same typed rows in both.
- Sixteen mutants killed, one per Godot invocation, both production files
  `shasum -a 256` byte-compared after each restore.

- [x] **BLOCKER D2 — CLOSED 2026-09-12** (decision 0115). §1 WORLD now carries the
      cursor and `restore_columns_and_cursor()` assigns it. The two tests that asserted
      the gap in the positive are retained and now assert the SPLIT: `restore_columns()`
      alone still leaves the cursor to §1, and the combined call makes the two worlds
      byte-identical including the cursor.
- [ ] **Registry rows owed, reported and not applied** (the file is another owner's):
      one category-3 member row for `_last_column_refusal` in
      `docs/persistence_state_registry.md`'s `entity_directory.gd` section, beside the
      existing `_last_refusal` row; and, if that registry is read as recording *how*
      each column is restored, a note on the free-heap row that the ascending refill is
      now `restore_columns()`'s as well as `_rebuild_free_heaps()`'s.
      `state_registry_coverage.py` passes without both, because it checks packed
      columns.
