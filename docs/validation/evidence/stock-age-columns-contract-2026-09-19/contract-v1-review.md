# Independent feasibility review of contract v1

SAVE-AGE-R01 · read-only review of `docs/planning/stock_age_columns_contract.md` · 2026-09-19

Scope: is the v1 contract buildable as written against `stock_age.gd`,
`save_section_inventories.gd` and `item_definitions.gd` as they stand. No tools were run,
no source was edited, and nothing below is a claim that anything was executed.

## What checks out

**Ordinal/type/group mapping.** Section 7 declares stock_age as ordinals 0 `_declared_count`
(u32, scalar), 1 `_last_hour_tick` (i64, scalar), 2 class (u8, primary), 3 heated (u8,
primary), 4 generation (i32, primary), 5 `_declared_slots` (i32, primary, count field 0).
Because u32 shares i64 storage, the storage groups are exactly u8×2, i32×2, i64×2, and both
i64 columns are length 1. The contract's total shape gate matches this exactly, and gating
before indexing is necessary: `owner_refusal` reaches `i64_column(1)[0]` and `u8_column(3)`
with no shape check of its own.

**Wire arithmetic.** Extent block 4 + six element counts 48 + u32 4 + i64 8 + 2×101376 u8 +
101376×4 i32 + 4N = 608320 + 4N. Wrapper 4 + 9 (`stock_age`) + 4 + 8 + 8 = 33. Empty block
608353; full (N=101376) 1013857. All three figures in the contract are correct.

**Per-object payload.** Owner columns 101376×2 + 405504×2 = 1013760 B. One `OwnerRecord`
1013760 + 16 = 1013776 B. Membership scratch 101376 B. Correct.

**Validator equivalence.** The proposed owner payload rules are value-for-value the existing
`_stock_age_refusal` rules: class 0..4, heated 0/1 on every row, declared rows generation > 0,
undeclared rows heated 0 and generation 0, prefix in range/unique/declared, every declared row
present once, count in 0..primary_count.

**Latch.** `_stock_age_refusal` admits any tick >= `NO_HOUR_RUN`, including 0. Keeping the
owner at the same domain preserves the set of admitted streams. A narrower hour-alignment gate
*would* change which restore values are admitted, so it is correctly excluded here and left to
the coordinator; this review makes no contrary claim.

**Tail compatibility.** `canonical_fill_of` and `set_stack_column` already canonicalise
ordinal 5's tail to `NULL_SLOT` (-1), so a decoded block satisfies the owner's "-1 unused
tail" invariant without conversion. This is the concrete evidence for that requirement.

**No codec/owner cycle.** `save_section_inventories.gd` preloads `stock_age.gd`;
`stock_age.gd` preloads no codec. A new adapter preloading both introduces no cycle.

## Holes, with bounded fixes

**H1 — the staging step cannot be built from the published API as described.**
`set_u8_column`/`set_i32_column`/`set_i64_column` all `duplicate()` their argument, so the
contract's "transferred into the private stage and published without another duplicate" is
false if the setters are used. Worse, `set_i32_column` *refuses* any ordinal whose count field
is not `NO_COUNT_FIELD`, so ordinal 5 cannot be set through it at all; ordinal 0 must go
through `set_scalar` (which range-checks u32) and ordinal 5 through `set_stack_column`.
Fix: choose one and state it. Either (a) use `set_scalar`, `set_u8_column`, `set_i32_column`
(ordinal 4 only) and `set_stack_column` (ordinal 5), and add the resulting four duplicate
buffers (+1013760 B) to the capture peak; or (b) assign through `storage_index_of` into the
typed column arrays directly, stating that this bypasses the setters' type/length guards and
is therefore legal only after the total shape gate has passed. Either way, every setter return
value must be checked and mapped to a refusal, not discarded.

**H2 — the capture-side staged `owner_refusal` gate is unreachable.** If the owner validator
and `_stock_age_refusal` are equivalent (they are, above), an owner-valid capture always
passes the staged check. The contract nonetheless requires a test for "block semantic failure"
preserving input and output. Fix: keep the gate as defence in depth, document it as an
equivalence assertion rather than a reachable path, move the positive semantic-failure test to
the **apply** direction (where a hostile `OwnerRecord` is constructible because its column
arrays are public members), and add a static table in the tests pairing each owner rule with
its codec counterpart so drift is caught if either side changes.

**H3 — capture clears the owner diagnostic even when the adapter refuses.** Owner capture
succeeds (clearing `_last_column_refusal`), then the staged codec check or a setter failure
refuses. The owner scalar then reads "clean" while the adapter returns a refusal. Fix: state
that the returned `SaveHeader.Refusal` is authoritative on both paths, that a post-owner
adapter refusal leaves the owner diagnostic cleared, and forbid tests from asserting the owner
scalar as the adapter's outcome. The apply-side rule ("a codec-stage rejection leaves the
older owner diagnostic alone") is sound because the owner API is not reached there.

**H4 — membership scratch must be local.** If the byte membership array is an instance field
it becomes new owner scratch, which contradicts "no new persisted or derived owner arrays" and
breaks test 4's reflection comparison of *all* value fields with only `_last_column_refusal`
excluded. Fix: require a function-local allocation on both capture and restore, and say so in
the memory section (2×101376 B if both paths ever nest, which they do not).

**H5 — two external predicates are unverified.** `Inventory.is_transaction_poisoned()` and
`SimClock.is_load_barrier_held()` appear in no supplied source. `stock_age.gd` uses only
`is_transaction_open()`. Fix: confirm both exist and are pure before authoring. If
`is_transaction_poisoned()` is absent, busy is `is_transaction_open()` alone and the contract
must say so rather than assert a second query. If the barrier predicate lives on the world or
save orchestrator rather than the clock, accept that object and refuse
`SAVE_AGE_BARRIER_NOT_HELD` through a `has_method` gate; do not invent a predicate.

**H6 — `clock: SimClock = null` default contradicts the null-clock refusal.** The default can
only ever produce `SAVE_AGE_NULL_CLOCK`. Fix: drop the default, making the barrier holder a
required argument.

**H7 — duck-typed method-name collision with Inventory.** The owner adopts
`copy_canonical_columns_into` / `restore_canonical_columns` / `canonical_detail`, the exact
names `save_section_inventories.gd` probes with `has_method` in `capture_inventory_into` /
`apply_inventory`. A StockAge passed there clears the `has_method` gate and then hits a typed
parameter mismatch — a runtime error, not a refusal, which contradicts "refuse without runtime
errors". Fix: keep the names (Astra requires the Inventory-matching return type), declare the
owner parameters with the nested `CanonicalColumns` type, state that the new adapter is the
only production caller, and add a test asserting the inventory path is never invoked with a
StockAge store.

**H8 — memory accounting is still incomplete.** State phases explicitly and do not publish a
single peak or any RSS claim. Capture holds, simultaneously: live owner 1013760 + local
Columns 1013760 + staged OwnerRecord 1013776 + the target block's prior buffers 1013776 +
membership 101376, plus H1's optional +1013760 if the setters are used. Restore holds: live
owner's old buffers 1013760 + four fresh duplicates 1013760 + the caller's block 1013776
(borrowed, not copied) + membership 101376. The constructor's four allocated arrays may
briefly coexist with adopted ones. All figures are packed payload only, excluding object and
Array overhead.

**H9 — test 2's "next 2 lot IDs" is not restored by this adapter.** The adapter restores
declarations only; lot identity and Inventory free-stack order are not in scope and no
six-owner section capture exists. Fix: define "equivalently bound world" as an Inventory
rebuilt by replaying the same operations, restore only the StockAge block into it, then assert
the declared order [C, B], the resulting waste-expiry retirement order, and only then the
next-lot IDs that order produces. Keep the actual probe witness ([2,1], next slots [0,1] vs
sorted [1,0]); do not substitute an ascending fixture.

**H10 — the RECORD (corrupt-source) refusal needs an authorised construction route.** The
owner's own arrays are allocated once at `CONTAINER_CAPACITY` and never resized, so wrong
source extents are unreachable through the public API. The contract authorises reflection only
for *comparison*. Fix: explicitly authorise test-side reflective mutation to build the corrupt
source, keep the production ban, and state that RECORD is otherwise a defence-in-depth branch.

**H11 — Array-container aliasing on publication.** Assigning `out.u8_columns =
staged.u8_columns` rebinds the typed `Array` by reference; it is safe only because the stage is
dropped immediately. Fix: say this in one sentence, and require the stage be unreferenced after
publication so no later mutation can reach the caller's block. Previously handed-out packed
arrays are unaffected (copy-on-write), which is what makes "old output buffers remain previous
snapshots" true.

**H12 — no reentrancy statement.** Nothing prevents restore during `_sweep_declared_containers`
other than the fact that the sweep emits no signal or callback. Fix: record that as an explicit
assumption alongside the existing quiescence disclaimer, rather than leaving it implicit.

## Caller obligations that must stay stated

`bind_stores` before restore (rebinding a different Inventory clears declarations); barrier
acquisition/release, clock/world/catalog association, Inventory restore, publication and disk
rollback; and full clock/latch/fault consistency. This adapter certifies none of them.

## Verdict

Feasible. H1 and H5 must be resolved before authoring because they change the written API
surface; H2, H3, H9 and H10 change test obligations; the rest are wording and accounting
fixes. None requires touching the registry, owner schema 1, section schema 3, or the existing
`_last_refusal`.
