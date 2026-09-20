# Independent source review — NEEDS-S4-VALIDATE-R01 v2

Date: 2026-09-20. Reviewer role: independent source/security/correctness review, not implementation.
Inputs: `godot/scripts/core/needs.gd`, `godot/scripts/core/save_owner_needs.gd`, the frozen
`save_component_columns_schema.gd` / `save_section_component_columns.gd` / `save_header.gd`,
the parent suites `test_save_owner_needs.gd` and `test_needs_columns.gd`, and
`tools/test_needs_metadata_preflights.py`. Contract, DEC-0170, the Astra disposition and the
author-intake note were read first. I ran nothing; no run, timing, mutation or full-suite claim
is made here, and the focus log is treated as parent-supplied evidence, not as my own.

## Verdict

**No blocker.** The implementation matches the accepted contract on every point I could check
statically. The three highest findings are coverage gaps, not defects.

## Findings, ranked

**S1 — medium. The exact gate-4 detail prefix has no in-engine assertion.**
`save_owner_needs.gd:METADATA_DETAIL_PREFIX` is the literal `"Needs owner9 metadata:"`, restored
by the parent after the author widened it. Nothing in `test_save_owner_needs.gd` reads the
prefix; the only check is `tools/test_needs_metadata_preflights.py`, whose `suite()` asserts
`refusal.detail.begins_with("Needs owner9 metadata:")`. That harness is a disposable-clone tool,
not part of the Godot suite, and no run evidence exists yet. Consequence: the precise fault the
author already committed once — altering the quoted prefix — reintroduces silently under the
Godot suites alone, and gate 4 stops being distinguishable from gate 3 as the contract requires,
since both carry `SAVE_COMPONENT_METADATA`. Bounded fix (parent-owned, one test): assert
`Bridge.framed_refusal(frame).detail.begins_with(Bridge.METADATA_DETAIL_PREFIX)` plus
`Bridge.METADATA_DETAIL_PREFIX == "Needs owner9 metadata:"` in one reachable gate-4 case.

**S2 — medium. Three of gate 4's four owner-identity branches have no mutant witness.**
`_metadata_refusal()` guards (a) `owner_key`/`owner_version`, (b) `primary_count`/
`child_extent_count`, (c) the five field counts, then delegates per-field parity. The Python
harness's `publication_fault()` only perturbs `Needs.COLUMN_KEYS` / `COLUMN_TYPE_CODES` /
`COLUMN_EXTENTS`, which reaches (c) and the parity loop; its schema fault mutates `OWNER_OFFSETS`,
which fails `Schema.schema_refusal()` at gate 3 and never reaches gate 4 at all. Branches (a) and
(b) are therefore unexercised, so `OWNER_VERSION = 2`, `OWNER_PRIMARY_COUNT = 512` and
`OWNER_CHILD_EXTENT_COUNT = 0` are asserted by nothing. Consequence: a schema regeneration that
renumbered owner 9's version or primaries would be accepted by the bridge's own gate and only
caught, if at all, downstream. Bounded fix: extend the harness's fault table with
`OWNER_VERSIONS`, `OWNER_PRIMARY_COUNTS` and `OWNER_CHILD_COUNTS` edits at owner 9's row.

**S3 — low/medium. Gate-3 forwarding is harness-only and unproven in-engine.**
The contract requires the schema detail be forwarded *unchanged*. `framed_refusal()` returns the
`Schema.schema_refusal()` object by reference, which is correct, but the only witness is the
harness case `schema-gate-before-owner-parity`. The Godot suite never constructs a failing
schema. This is acceptable — the compiled tables cannot be perturbed from inside a test — but it
should be recorded as harness-dependent rather than covered.

**S4 — low. Redundant field-count constant, safely fails closed.**
`OWNER_FIELD_COUNT = 20` duplicates `Needs.COLUMN_COUNT`. If Needs gained a column, gate 4
refuses with `SAVE_COMPONENT_METADATA` rather than misprojecting, so the duplication is a
fail-closed guard, not a hazard. Noted so a later reader does not "simplify" it away; the
`FIELD_*` ordinals and `_project_*` would then silently cover only the first twenty fields.

**S5 — low, style. Repeated schema walk per call.**
`Schema.schema_refusal()` re-walks 18 owners and 298 fields, and `storage_index()` is O(n²) in an
owner's field count, on every `framed_refusal()`. Offline and bounded; the contract forbids
optimization in this slice. Record only.

**S6 — low, style. Refusal-path string formatting.**
`_metadata_refusal()` calls `Schema.owner_key(9)` and `owner_version(9)` twice each when building
a refusal detail. Refusal-path only, no per-row object, inside the stated wrapper overhead.

## Verified clean

- **Total order.** `needs.gd:columns_refusal()` runs shape → byte domain → value domain →
  free row → death equivalence → recomputed living cap, exactly the contract's six steps.
  `test_living_cap_and_first_refusal_across_distinct_rows` walks that ladder backwards across
  distinct rows, which is the masking case the disposition insisted on.
- **Purity and call graph.** All ten helpers (`_columns_are_capacity_sized`,
  `_column_byte_domain_refusal`, `_byte_column_below`, `_column_value_domain_refusal`,
  `_int32_column_within`, `_int64_column_within`, `_column_free_row_refusal`,
  `_free_row_is_clear`, `_living_row_count`, `_column_health_status_refusal`) are `static` and
  argument-only; they read only their arguments, script constants and `IntMath.INT32_MAX` /
  `INT64_MAX`. No store member, diagnostic, clock, signal, callback or filesystem access appears
  on the predicate path. `_install_columns` and `_rebuild_counters` stay instance methods, and
  `_rebuild_counters` still calls the shared `_living_row_count`, so cap and counter cannot drift.
  The bridge constructs no live Needs: `Needs.Columns.new()` is the inner image class only.
- **Null/shape totality.** The null guard lives in `_columns_are_capacity_sized`, so both
  `restore_columns(null)` and `copy_columns_into(null)` refuse with `COLUMN_SHAPE` before any
  indexed read. `test_null_inputs_are_total_and_refused_owner_is_unchanged` pins all three paths
  plus `SAVE_COMPONENT_SHAPE` for a null record.
- **All twenty explicit assignments.** `_project_values` writes ordinals 0–8 and `_project_bytes`
  writes 9–19; the `FIELD_*` constants match `Needs.COLUMN_KEYS` and the schema's owner-9 field
  keys ordinal for ordinal. I traced each of the twenty omission mutants against the fixtures:
  every one changes the returned code, including the contract's awkward case — the status witness
  keeps `health[0] = 100`, so omitting the status assignment yields `COLUMN_HEALTH_STATUS`
  instead of the asserted `COLUMN_ENUM_BYTE`. Omitting `present` gives `COLUMN_FREE_ROW`,
  omitting `health` gives `COLUMN_HEALTH_STATUS`, omitting `clothing_tier` gives success. None
  collides with its expected code.
- **Memory.** Projection is assignment, never `duplicate()`; `_install_columns` is unreachable
  from the bridge; only `_int32_column_within` / `_int64_column_within` duplicate, and their
  copies are function-local so no i32 and i64 copy coexist across a returning call. The
  57344-byte image plus the transient default buffers plus the largest sort copy
  (`need_remainder`, 2560×8 = 20480) is 135168, matching the contract. I re-derived 57344 from the
  declared extents. This remains allocation arithmetic, not RSS.
- **Preserved input and target.** `_parity()` asserts `Columns.equals()` before/after on the
  static path, per-field packed equality on the framed path, and `state_bytes()` equality on a
  refused live restore.
- **Compatibility of the new rule.** Every live producer keeps `(health == 0) == (status ==
  DEAD)` for present rows: `_write_spawn_row` writes 100/ACTIVE; `_integrate_health` and
  `_apply_health_event_checked` are each followed by `_refresh_status`; the input setters change
  no health; `despawn`/`clear` clear presence. So a `copy_columns_into` → `restore_columns` round
  trip of any reachable live state is still accepted, and the existing `test_needs_columns.gd`
  fixtures (including the slot-6 death and the 256-living boundary) remain valid.
- **Departure comments.** All three sites — header GAPS block, `_departure_days` declaration and
  `departure_days_of()` — now distinguish the absent normal producer from the admitted
  0..INT32_MAX saved counter. No departure mechanics or LEAVING/TRANSFERRED reinterpretation
  appears anywhere.
- **Tick path.** I looked for a reachable state where a live tick could publish a present row
  violating the new equivalence and found none. Per the contract, no repair task is opened.

## Not reopened

Gameplay semantics, total nonfatal status precedence (`NEEDS-STATUS-PRECEDENCE`), departure
production (`NEEDS-DEPARTURE-DOMAIN`), tick optimization and range-scan optimization are out of
scope and untouched. This review certifies the bounded owner-9 primitive only: it is not a
full-save validator, and a positive bridge result still certifies nothing about common-file
origin, Directory/resident agreement, Injury agreement or cross-owner saved consistency.
Mutation and full-suite evidence are still outstanding.
