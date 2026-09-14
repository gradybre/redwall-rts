# REGISTRY-CAPACITY-AUDIT — source-proved numeric capacity sidecar — 2026-09-14

Task: 09_persistence_replay_reliability.md
Date: 2026-09-14
Base: `388f4f4b97e30adab355ebfd21b31cb7ac91e8d7` (merge of PR122)
Contract: [REG-C3-R01](../../../rulings/2026-09-14_cycle03_save_counts_and_capacities.md#declared-capacity-as-prose)
Decision: [0147](../../../decisions/0147-capacity-prose-is-audited-against-gdscript-not-converted.md)

## What landed

- [x] `tools/audit_registry_capacities.py` — parses each `shape.declared_capacity`
      against the closed grammar `` `expr` (= | <=) <digits> ``, binds the field to the
      single `resize(...)` that sizes its column in `godot/scripts/core/<module>.gd`,
      resolves that expression with a restricted integer evaluator (decimal literals,
      module constants, `Alias.CONST` through explicit `preload`, `*` products; depth 16;
      int64 guard on every intermediate; **no `eval`**), classifies the source as equality
      or upper bound, then compares relation and value with the prose.
- [x] `docs/planning/registry_capacity_audit.json` — 519 rows keyed by
      `(section_id, owner_key, ordinal, field_key)`, each with the prose, the parsed
      expression, the relation, the source file, the resize line, the full substitution
      chain, the proof kind and the status. Plus the 80 non-capacity canonical records so
      the two lists partition all 599, and a `unproved_or_contradicted` block.
- [x] `tools/test_registry_capacity_audit.py` — 134 checks, negative first.

## Sidecar only — nothing active was touched

`git status` shows three new files and **zero modified tracked files**.
`docs/planning/canonical_state_registry.json`, `docs/persistence_state_registry.md`,
`docs/validation/validate_save_registry_handoff.py` and every `godot/scripts/core/*.gd`
are byte-unchanged; a test asserts the registry's digest is identical before and after a
tool run. The sidecar carries `"kind": "read_only_sidecar"` and `"adopted": false`, and
does not re-assert the registry's `source_registry_sha256`, choose a registry version, or
add numeric metadata to the registry.

## Census — agrees with Astra Cycle 3, no parser tuning

| Count | This audit | Astra Cycle 3 |
|---|---:|---:|
| prose records | **519** | 519 |
| equality (`=`) | **473** | 473 |
| upper bound (`<=`) | **46** | 46 |
| other canonical shapes | **80** | 80 |
| distinct expressions | 56 | 56 |
| canonical records / packed source fields / owners | 599 / 553 / 52 | 599 / 553 / 52 |

The 8 `hash: false` fields are counted and excluded; none carries a
`declared_capacity` and none entered the audit. Astra's numbers are embedded as a
*comparison*, printed beside the observed counts, with any difference emitted as an
explicit `DISAGREEMENT` line — they are snapshot counts, not pins.

## Proof outcome

**517 proved = 471 equality + 46 upper bound. 0 contradictions. 2 unproved.**

The 46 bounds are exactly the four clamped stores the ruling names — gear
`_row_capacity <= 16384` (12), inventory `_c_capacity <= 101376` (12), inventory
`_l_capacity <= 16384` (14), reservations `_row_capacity <= 32768` (8) — each proved as a
`clampi(arg, 1, MAX)` maximum, never as an element count.

The 2 unproved rows are `(5, orchard_hive, 0, _link_hive_slot)` and
`(5, orchard_hive, 1, _link_hive_generation)`. Resolution halts at
`orchard_hive.gd:316 const RECIPIENT_CAPACITY = FARM_RECIPIENT_CAPACITY + ORCHARD_CAPACITY`
because REG-C3-R01 allowlists "products and qualified constants" and `+` is not on that
list. Deliberate refusal, not a parser gap.

## Remaining contract — open blocker

**May the resolver's allowlist include `+` for nested constant definitions?** Two rows,
and only those two, depend on it. Not decided here, because the allowlist is the ruling's.
Separately still open and untouched by this lane: adoption of any numeric capacity into
the registry, wire extent/count validation per field, and the SAVE-R09-003 rules-identity
question if the registry ever becomes a production manifest input.

## Checks actually run in this worktree

- `godot --headless --path godot --editor --quit` — exit 0, run first in the fresh worktree.
- `./tools/run_tests.sh` — `ok: 4355 tests, 155623 assertions, 0 failures.`
- `python3 tools/test_registry_capacity_audit.py` — `test_registry_capacity_audit: PASS -- 134 check(s), 0 failure(s)`
- `python3 tools/audit_registry_capacities.py` twice — sidecar sha256 identical both times; `--check` passes.
- `python3 docs/validation/validate_save_registry_handoff.py --source-root .` — PASS
  (54 modules / 352 rows / 681 packed columns; 553 persisted packed fields; 52 owners, 599 canonical records).
- `python3 tools/generate_canonical_state_table.py --check` — PASS.
- 12 mutants, one per invocation, `shasum -a 256` byte-compare after each restore. All 12 killed.
