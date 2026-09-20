# Independent review — SAVE-CLAIMS-R01 v2 claim columns

Date: 2026-09-19. Reviewer: independent, source-only, no tools, no execution.

**v2 acknowledged.** This review is against `docs/planning/resource_claim_columns_contract.md`
(SAVE-CLAIMS-R01 · version 2, including its "Independent review disposition" section) and
`docs/decisions/0166-restore-resource-claims-without-rebuilding-other-sections.md`. Accepted
scope is honoured: cross-section claim reconciliation is separately required before world
activation and is **not** demanded of this slice. Nothing below asserts that any test, static
check, editor import or CI run was performed; no CI evidence is invented.

Inputs reviewed: the two appended fragments in `godot/scripts/core/fishing.gd` and
`godot/scripts/core/forage.gd`, `godot/scripts/core/save_resource_claims_restore.gd`,
`godot/test/test_resource_claim_columns.gd`, `docs/persistence_state_registry.md`, and the
parent integration notes.

## Verdict

No release blocker found in the owner boundaries or the adapter. Ten actionable findings follow,
three of which (R1, R2, R3) are contract-compliance defects that should be fixed before this
slice is recorded as accepted; the remainder are coordinator hand-offs, evidence gaps or
optional test strengthening.

## Confirmed correct (source review)

- **Atomicity.** `restore_effort_claim_columns` (fishing) and `restore_forage_claim_columns`
  (forage) validate fully, then take 7/11 private `.duplicate()` locals, then publish arrays and
  the derived count with no fallible work remaining. `copy_*_into` publishes only after the
  count gate. A refusal writes nothing but the new diagnostic.
- **Explicit duplication.** Every one of the 7 and 11 arrays is duplicated on both capture and
  restore. This is stated as source-review evidence only; the disposition already records that a
  COW-sharing mutant may be behaviourally indistinguishable under public tests, and no such
  mutant kill is claimed here.
- **Gate order and first-gate-wins.** Both validators run: null/record shape → live shape →
  all active bytes across the whole table → ascending rows in wire order → (capture only)
  source count. Matches contract items 1–3 and 6.
- **Exact blanks.** Fishing `active 0 / both slots -1 / three generations 0 / slot_count 0` and
  Forage `active 0 / three slots and kind -1 / three generations 0 / three i64 zero` agree with
  `_clear_effort_claim_row` and `_clear_claim_row` respectively.
- **Namespace and domain gates.** Directory slots bounded `0..352417` via
  `EntityDirectory.DIRECTORY_CAPACITY - 1`; every generation `> 0`; Fishing `slot_count 1..6`
  derived by iteration over `EFFORT_SLOTS_BY_TYPE` with no allocation or sort; Forage kind
  `0..4`, remaining `1..MANUAL_QUOTA_MAX_MILLI`, created tick and persistent id `>= 0`. No
  clamping, masking or repair anywhere.
- **Preservation.** Neither fragment touches `_habitat_effort_used`, `_effort_total_scratch`,
  `_zone_quota_reserved_milli`, `_zone_harvested_today_milli`, `_math*`, `_pending_*`,
  `_owns_directory`, `_directory`, `_jobs`, `_zones`, or Forage's section 1 `_section_1_code` /
  `_section_1_detail`. Ordering keys are copied verbatim, including 0 and INT64_MAX.
- **Forbidden calls.** Neither fragment nor the adapter references `clear`,
  `restore_effort_claim`, `restore_claim`, `rebuild_effort_aggregates`,
  `validate_effort_aggregates`, `rebuild_reservation_aggregates`, `_refresh_claim_order_key`,
  `purge_stale_*`, `release_cancelled_*`, `release_claims_of_zone`, `reconcile_claims`,
  `run_midnight`, `collect_claim`, `release_claim`, or any hot mutator. No signal, callback or
  yield; no new binding, Directory, Inventory, Jobs or clock is constructed.
- **Adapter ordinals.** Every access uses a named ordinal constant resolved through
  `Codec.storage_index_of(owner, ordinal)`; no raw storage position is used in the adapter.
  Group counts (1/6/0 and 1/7/3) and every column length are checked before any codec access.
- **Adapter gate order.** capture: null store → total output shape → owner capture → private
  staged OwnerRecord → `Codec.owner_refusal` → publish three groups. apply: null block
  (BLOCK_SHAPE) → null store → null clock → held barrier → full shape → `Codec.owner_refusal` →
  borrow → owner restore. Barrier is queried only, never acquired or released.
- **Array ownership.** Published group containers come only from the private staged
  `OwnerRecord`, which never escapes; no caller-visible group container is reused.
- **Arithmetic.** Packed bodies 512·25 = 12800 and 8192·53 = 434176; payloads 12860 and 434268;
  wrappers 31 and 30; blocks 12891 and 434298. Envelopes 3P owner, 5P adapter capture, 4P
  adapter apply are conservative and consistent with the constructor-plus-duplicate peaks;
  5P = 64000 and 2170880 are correct. These remain slice bounds, not process peak or RSS.

## Findings

### R1 — Medium, contract-compliance blocker for slice acceptance
`docs/persistence_state_registry.md`, section `### godot/scripts/core/fishing.gd`, row
**"Fishing scratch"**: `_effort_claim_count` is still listed among the category-3 members
("`_math`, `_math_b`, `_math_c`, `_effort_claim_count`, …"). The v2 disposition requires it to be
moved from scratch to **category 2**, mirroring Forage's `_claim_count`, which is correctly
retained at category 2 in the "Forage live counts" row. Fix: remove it from the scratch row and
give it a category-2 row (section 7), noting it is recomputed from `_effort_claim_active`.

### R2 — Medium, registry integrity
`docs/persistence_state_registry.md`: the two new **"Claim-column diagnostic"** rows (one after
the `fishing.gd` table, one after the `forage.gd` table) are each separated from their table by a
blank line. In Markdown that terminates the preceding table and starts a new one whose first row
becomes a header, so the row is no longer part of its store's table. This is both a rendering
defect and a parsing risk for `docs/validation/state_registry_coverage.py`, which the build runs.
Fix: attach each row directly to the last row of its store's table.

### R3 — Medium, stale legacy documentation (contract: record old paths as legacy-only)
The contract requires the old source-cache/rebuild comments to be recorded as legacy-only, with
no behaviour change. Four sites still read as the current load path:

- `godot/scripts/core/fishing.gd`, module header, claim-slice paragraph: "On load,
  `rebuild_effort_aggregates()` recomputes `effort_used` from the live claims…".
- `godot/scripts/core/fishing.gd`, `restore_effort_claim()` docstring: "The load half of
  ruling §5. A loader restores authoritative claim records and then calls
  `rebuild_effort_aggregates()`…".
- `godot/scripts/core/forage.gd`, module header GAPS: "R05-QUOTA-022's load path is implemented
  as `restore_claim()` plus `rebuild_reservation_aggregates()`" and the preceding
  "THERE IS NO SAVE MODULE IN THIS REPOSITORY".
- `godot/scripts/core/forage.gd`, `restore_claim()` docstring: "R05-QUOTA-022's load half."

These are the exact methods the new boundary forbids. A comment-only amendment naming them
legacy-only is sufficient; no code change is authorized or needed.

### R4 — High for world activation, out of scope for this slice (hand-off to SAVE-CLAIM-RECONCILIATION)
Concrete failure mode the reconciler must cover, recorded here as evidence rather than as a
defect in this slice. After a claim-only restore, §4 aggregates are untouched by design. If the
restored §7 claims are then released through ordinary public paths before reconciliation:
`fishing.gd::_release_effort_claim_row` does `_habitat_effort_used[slot] -= slot_count`, and
`forage.gd::_release_claim_row` does `_zone_quota_reserved_milli[slot] -= amount`. With
aggregates that no longer account for those claims, both can go **negative**, after which
`effort_slots_free_of` and `_available_quota_into` over-admit. The contract already assigns the
checked comparison against SAVED section 4 effort/quota columns to SAVE-CLAIM-RECONCILIATION;
this note supplies the specific arithmetic that must be proved impossible before resume. The
parent continuation test cannot exercise it, correctly, because it restores into the same world.

### R5 — Medium, static-check risk (test file only)
`godot/test/test_resource_claim_columns.gd` declares many untyped locals and dispatches through
`Variant`, e.g. `var _fish`/`var store: Variant` in `_reject`, `_seed`, `_restore`, `_capture`,
`_public_world` (`var fish_job = jobs.create_job(...)`, `var habitat = …`, `var basin = …`,
`var designation = …`, `var made: OpResult` absent), and `var column: Variant` in
`test_adapter_literal_mapping_recapture_and_independent_containers`. Every core module in this
repository is fully typed, and the first focus run already failed on a typing error in this file.
If `project.godot` promotes `untyped_declaration` or `unsafe_method_access` to errors, the
contract's "staticchecks" requirement fails on this file alone. Verify the configured warning
levels; if promoted, annotate the locals.

### R6 — Medium, evidence gap (goldens)
`test_six_complete_literal_owner_wire_goldens` obtains its bytes by capturing through the
implementation and then re-building the wrapper framing inside the test
(`writer.write_utf8_u32(...)`, `write_u32`, `write_u64`, then a per-column `u64` prefix and
`Codec.column_slice`). The pinned lengths (12891 / 434298) are an independent arithmetic check
and are correct. The pinned digests, however, are produced by the code under test plus a
test-local reimplementation of framing, so the test cannot by itself demonstrate the
contract's "independent byte generator plus pinned digests and lengths". The independent
generator and its recorded outputs are not present in this packet. Fix: check the generator and
its emitted digests into the evidence directory and cite them from the test, and keep the test
title from implying an integrated disk writer — the hand-built framing is a probe, not the
shipped section encoder.

### R7 — Low, verification item (GDScript)
Both new inner classes resolve outer-class constants from `_init()`:
`fishing.gd::EffortClaimColumns` uses `FISHING_EFFORT_CLAIM_CAPACITY` and
`CLAIM_COLUMN_BLANK_*`; `forage.gd::ForageClaimColumns` uses `FORAGE_CLAIM_CAPACITY` and
`CLAIM_COLUMN_BLANK_*`. No pre-existing inner class in either file (`OpResult`,
`EffortClaimTally`, `ForageClaimTally`) does this. Outer-constant lookup from an inner class is
expected to resolve in GDScript 4, and the blanks resolve transitively through the preloaded
`EntityDirectory` constants, so this is flagged as the one new parser-resolution surface to
confirm in the editor import, not as an asserted defect.

### R8 — Low, optional test strengthening
Gaps that add distinct evidence but are not required to be mutants:
- An **active** Forage row with `claim_created_tick == 0` is never exercised; `_seed` only
  populates rows 2 and `rows-1`, and only `claim_persistent_id[2]` is driven to 0. The
  contract asks for distinct created-tick/PID values including 0 and MAX across restore.
- A codec-admitted Forage `remaining_milli == 0` is exercised at the owner boundary
  (`test_payload_domains_…`) but not through `apply_forage`; only `1180001` and fishing `7`
  are forwarded through the adapter in
  `test_adapter_forwards_codec_and_stronger_owner_refusals_atomically`.
- Test titles do not retain the loader-reconciliation limit the contract asks for; for example
  `test_public_claims_continue_identically_after_exact_slice_restore` reads as a world-level
  claim. A "claims only, not a reconciled world" qualifier in the title would prevent that.

### R9 — Low, verification item (not a source defect)
The four required mutants (drop Forage ordering-key publication, rewrite Fishing habitat effort,
skip Forage amount bound, skip Fishing amount bound) are not evidenced in this packet, and no
result is inferred here. The source supports all four being killable: ordering keys are published
only by `restore_forage_claim_columns`, `_habitat_effort_used` is untouched and snapshotted by
`test_other_section_aggregates_…`, and both amount bounds are single, uniquely coded gates.

### R10 — Low, test fragility
`test_adapter_forwards_codec_and_stronger_owner_refusals_atomically` and
`test_adapter_literal_mapping_recapture_and_independent_containers` index storage positions
directly (`block.i32_columns[5]`, `block.i64_columns[0]`, and `index-1` / `index-8`
arithmetic). That bakes in an assumption that storage position equals wire ordinal within each
group. The adapter itself is correct because it always routes through
`Codec.storage_index_of`; the tests would silently mis-target if the codec's storage order ever
diverged from ordinal order, and they cannot distinguish a correct adapter from one that
happened to use identity indices. Prefer `Codec.storage_index_of` in the tests too.

## Scope statement

This review covers structural admission only. It does not attest row/Directory/Job association,
reference liveness, habitat or zone presence, per-habitat effort capacity, checked aggregate
totals against saved section 4 columns, or Forage order-key provenance — all of which remain
SAVE-CLAIM-RECONCILIATION's obligation and gate world activation under ADR0166. A pair of claim
blocks is not a completed section 7, and nothing here claims otherwise.
