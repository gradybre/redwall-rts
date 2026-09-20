# ResourceNodes owner 13 — independent feasibility review (read-only)

2026-09-20. No accepted contract, no implementation, no reviewer dispatch. Nothing was run.

## Re-derived geometry

Compiled section 4 owner index 13 is `resource_nodes`, schema version **1** — distinct from the
separate section 1 `resource_nodes` block at version 2, which owns only `_resource_slot`.
Primary rows 4096, field begin ordinal 255, field count 10, child extents 0.
Fields in ordinal order: `_present` u8, `_resource_id` i32, `_quantity_milli` i64,
`_capacity_milli` i64, `_regrow_days` i32, `_planted_day` i32, `_exhausted` u8, `_tile` i32,
`_ref_slot` i32, `_ref_generation` i32 — every column 4096 long.
Values `2*4096 + 6*4096*4 + 2*4096*8 = 8192 + 98304 + 65536 = 172032`.
Payload `4 + 0 + 10*8 + 172032 = 172116`. Block `24 + 14 + 172116 = 172154`, offset 9550427.
All six figures match the compiled tables; a ten-typed-argument static bridge is feasible with
zero extra scratch and no framing change.

## Producer image the gates must accept

`clear()` zeroes all values except tile/ref_slot -1 and ref_generation 0. `create_at_tile()` and
deposit publication write a full present row: nonnegative storable id, strictly positive i64
capacity, quantity = capacity, nonnegative regrow_days, planted_day 1..INT32_MAX, exhausted 0,
tile 0..16383, live Directory ref. Harvest subtracts a positive amount not exceeding quantity;
reaching 0 sets exhausted 1 and re-dates planted_day. Regrow restores quantity = capacity and
clears exhausted, leaving planted_day. Destroy clears present/quantity/exhausted/tile/refs but
**retains** id, capacity, regrow_days and planted_day, so an all-zero inactive image must not be
required. Candidate pure gates: shape first; boolean present/exhausted; nonnegative id,
regrow_days, planted_day, capacity, quantity on all 4096 physical rows; quantity <= capacity;
present rows capacity > 0, planted_day >= 1, exhausted exactly when quantity is 0, tile
0..16383, ref slot 0..352417 with generation > 0; inactive rows quantity 0, exhausted 0, tile -1,
ref (-1,0) with numeric history preserved.

Capacity is full positive i64 including INT64_MAX; no float conversion. `planted_day +
regrow_days` overflowing int32 is an already-reachable valid producer state answered by an
explicit runtime refusal — not malformed data. Do not clamp, normalize or require the sum to fit.
No absent-row tightening should be invented without source or authority support.

## Bounds and what cannot be reused

The ref column indexes the **global** EntityDirectory (capacity 352418), not the typed 4096 row
bound; both must appear, with neither substituted for the other. Tile bound is the 128x128 grid.

## Cross-check split

`section_1_cross_check_refusal()` reads the live store and directory and writes
`_section_1_detail`, so a pure saved-column bridge cannot call it and must not be made to.
Proposed: this bridge stays scalar-only; a separately authorized same-file follow-up owns the
inverse/Directory relation in both directions against saved state. Tile uniqueness and ref
uniqueness follow from that relation, not from scalar domains; local duplicate policy and any
scratch budget stay undecided pending authority. Existing section 1 APIs remain unchanged.

## Resource identity

Settled: `resource_id` is the compiled `ItemDefinition` ID of the extracted output — wood, stone,
iron — per the GDD ruling 2026-09-11 and ADR 0052, resolved by `resource_catalog_binding.gd`.
The legacy `resource_nodes.gd` header and old test comments calling the domain unstated are
stale lower-authority text and should be corrected in the eventual authorized slice. Recommended
exact split: a pure scalar-domain predicate accepting any nonnegative storable id (matching the
generic public create API), plus a **separate** saved catalog-membership check verified in the
same file. Generic creation acceptance is not valid published content, and no live catalog is
constructed and no owner projection allocated.

## Evidence and blockers

Public readers refuse absent scalar reads, so retained inactive history cannot be observed
through them. Propose source-owned fixtures plus public create/harvest/regrow/destroy/read and
section 1 behaviour as the history evidence; do not add a private getter for tests.

Blockers: no accepted contract or reviewer authority; the inverse/Directory relation and
duplicate policy are unresolved; catalog-membership scope is undecided. Open domain questions:
whether absent-row numeric relationships tighten, and whether inactive tile/ref sentinels are
mandatory or merely produced. No claim of full save validity follows from this review.
