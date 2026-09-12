# 0102 — Inventory enforces the seed guard, and the expiry declares its own cleanup

Date: 2026-09-12 · Status: **Accepted**

[STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md) splits one rule
across two modules: `stock_age.gd` owns the PREDICATE and `inventory.gd` "owns
enforcement for quantity admission". Decision
[0093](0093-expired-seed-converts-to-compost-by-floored-nominal-mass.md) landed
the predicate and named the other half as an open handoff — *"**Nothing calls
it.** No seed consumer in this repository is guarded today."* This record closes
that handoff and fixes the judgements enforcement required.

## Decision

1. **The guard delegates and never duplicates.** `inventory.gd` knows an item's
   mass and category. It does not know what a seed is, what a shelf hour is, or
   how the two compare, and it does not learn: every guarded path calls
   `StockAge.refuses_seed_consumption(lot_ref)` through a bound authority. There
   is exactly one copy of that comparison in the repository, so the two cannot
   disagree. No packed column, no per-lot flag and no shelf-life constant was
   added here — see *Consequences*.
2. **Seven call sites, not one.** A new reservation (`reserve_lot`), an
   unreserved withdrawal (`sink_lot_quantity`), the commit of an existing claim
   (`consume_reserved`), a transfer, a whole-lot move, a split and the in-place
   `transform_lot_item` each ask separately. `_seed_consumption_refusal()` is the
   single place the authority is called, but the decision to ask lives in each
   path's precondition check, because a guard threaded through one shared choke
   point would have been proved by one test and left six paths unproven.
   `test_inventory.gd` carries one refusal test per path and the mutation log
   below kills one path at a time.
3. **Revalidation at commit is structural, not remembered.** No verdict is cached
   anywhere. Every guarded call re-asks against the age persisted in
   `_l_age_milli_hours` at that instant, so a claim taken while a seed was fresh
   carries no permission into the work commit — there is no code path on which an
   earlier "yes" can be replayed, because there is nowhere to store one.
   `test_every_admission_asks_the_authority_again` counts the questions rather
   than trusting the claim.
4. **Fail-closed is passed through unsoftened.** An authority that cannot
   evaluate a lot — unbound store, unloaded catalog, invalid ref — answers true,
   and this store treats that as the refusal it is. It does not second-guess it
   and it never converts "cannot tell" into an admission. The test binds a REAL
   unbound `stock_age.gd` and asserts every path refuses.
5. **Release and cancellation are never guarded.** `release_reservation()` and
   `release_all_reservations()` reduce a claim; the ruling keeps them permitted so
   a job holding expired seed can always let go of it.
6. **The declared expiry is told from consumption by a single-use CLEANUP
   DECLARATION.** This is the judgement the ruling forced and did not make. See
   below.
7. **A refusal leaves every collaborating store byte identical** (decision 0059).
   Every guard is asked before anything is costed — before the first
   `_journal_lot()`, before the first `_math` value exists — and the tests assert
   it with `state_bytes()` rather than by inspecting two fields. A mutant that
   incremented an unjournaled ledger cell while refusing was killed by seven
   tests at once.

## Why the cleanup declaration is what it is

STOCK-SEED-R01 requires both of these at once:

> every seed-consuming eligibility path ... MUST reject a seed lot whose existing
> age has reached its catalog shelf threshold

> Release/cancellation and declared expiry transform/sink operations remain
> permitted, so the guard cannot prevent its own cleanup

Cleanup and consumption reach this store through the **same two methods**.
`stock_age.gd`'s zero-yield retirement calls `sink_lot_quantity()` — the very call
`economy_system.gd` uses to take a helping off a lot — and its conversion calls
`transform_lot_item()`, which is what a workshop turning seed into something else
would call. Guarding those two without an exemption would have broken the expiry
stage's own cleanup; exempting them would have left the ruling's two loudest
paths open.

`stock_age.gd` is another owner's file and is byte-untouched, so the exemption had
to be recognisable from what that module **already does**. Every declared-expiry
sequence there is: `begin()`, `release_all_reservations(lot)`, then one
sink-or-transform of that same lot, then `commit()`. That release is the ruling's
own invalidation step, so it is what declares the lot:

- **Single use.** `_enter()` takes the pending declaration and clears it in one
  step, so it licenses exactly the operation that follows and nothing further.
- **Named.** The declaration carries a lot ref and is compared including the
  generation, so declaring lot A licenses nothing for lot B.
- **Atomic.** It is recorded before `_leave()`, so a release that owned its own
  implicit transaction has that close discard it. Only a release inside an
  explicit transaction can license the step after it, which is decision 0059's
  atomicity requirement made structural rather than requested.
- **Never partial.** The sink exemption additionally requires the quantity to be
  the row's ENTIRE remaining quantity with no claim standing. A sink that leaves
  quantity behind is a consumer taking a helping, whoever asked for it, and is
  refused even under a declaration.

What this buys: a consumer can only reach the exemption by first cancelling every
claim on the lot and then destroying all of it in the same transaction — which is
the permitted "release/cancellation" and "declared expiry sink" combination, and
hands the consumer nothing. What it costs is an implicit coupling between two
calls, which is why five of the mutants below exist to pin it.

## Which generation namespace this touches

There are four in the repository — directory, inventory container, inventory lot,
navigation route descriptor — and this change touches **one**: the INVENTORY LOT
generation (`_l_generation`). The cleanup declaration holds a lot ref and
`_is_declared_cleanup()` compares `(slot, generation)` in that namespace. It is
never compared against a container ref: the same slot number in `_c_generation` is
an unrelated value, and a declaration that matched on slot alone would let a
container's generation license a disposal. `refuses_seed_consumption()` on the
other side is likewise a lot ref, validated by `is_lot_valid()`.

## What this did NOT implement

- **Nothing binds the authority in production yet.** With no authority bound,
  nothing is refused — this store cannot identify a seed by itself, so an unbound
  guard has no lots to refuse rather than every lot, and refusing every lot would
  stop the settlement dead. `set_seed_expiry_authority()` /
  `has_seed_expiry_authority()` are the wiring, and the one call that turns
  enforcement on belongs to whoever constructs both collaborators — ARCH-SYS-001 /
  `settlement_system.gd`, which is another owner's file:
  `inventory.set_seed_expiry_authority(stock_age)` after the two are built.
  Until that line exists, the guard is enforced in the tests and nowhere else.
  **This is a named handoff, not a solved problem.**
- **The blocking critical pause and exactly-once retry are still not here**, as
  decision 0093 left them. The ruling's "The eligibility guard prevents use even
  before that pause barrier is applied" is now true; the barrier is not.
- **Equipping is not guarded.** `detach_lot_to_equipment()` /
  `attach_equipped_lot()` are not consumption, and `gear.gd` admits only the five
  instance-required items, none of which is a seed.
- **Merging is not guarded and cannot launder age.** `_check_merge()` refuses
  `AGE_MISMATCH` unless both rows round to the same whole hour, and `_apply_merge()`
  adopts the OLDER row's age, so folding an expired seed into a fresh one cannot
  produce a usable lot.

## Consequences

- **No packed column was added or changed.** The verdict is derived from
  `_l_age_milli_hours`, which already exists, plus the item definition; the ruling
  says as much ("requires no new per-lot flag or remainder store").
  `docs/systems_architecture.md` §2.2/§2.3 and `docs/persistence_state_registry.md`
  therefore gain no row, and `state_registry_coverage.py` passes unchanged. The
  three new fields — `_seed_expiry_authority`, `_tx_cleanup_lot`,
  `_op_cleanup_lot` — are a wiring reference and two transaction scratch refs:
  not journaled, absent from `state_bytes()`, and nothing a save carries.
- **A new refusal code, `SEED_PAST_SHELF_LIFE`**, and
  `INVALID_SEED_EXPIRY_AUTHORITY` for an object that cannot answer the predicate
  it would be bound for. Both are explicit refusals; neither is a sentinel.
- **One cross-object call per guarded admission.** It is `Object.call()` by
  StringName, the same duck-typed shape the equipment authority already uses,
  because `stock_age.gd` preloads `inventory.gd` and the dependency cannot be
  circular. `_attesting` is raised across it, so an authority that re-entered with
  a mutator is refused `ATTESTATION_REENTRY`, and it is asked before anything is
  costed so no `_math` or `_plan` value is live across it. Admissions are
  per-job, not per-resident-per-tick; this is not on the crowd path.
- `_move_lot_checked()` was split, extracting `_check_move()`, to keep the 30-line
  rule after the guard landed. No behaviour changed with it.

## Source

- [STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md) — the
  eligibility-path list, "Revalidate at commit", the permitted-cleanup sentence
  and the Inventory/StockAge ownership split.
- Decision [0093](0093-expired-seed-converts-to-compost-by-floored-nominal-mass.md)
  (the predicate, and the handoff this closes), decision
  [0085](0085-stock-aging-runs-hourly-and-declares-its-store.md), decision
  [0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) (allocate before consume; byte-identical
  refusal), decision [0061](0061-an-equipped-lot-is-a-null-container-lot-a-store-can-prove.md).
- GDD §4.2 (lots, reservations, all-or-nothing) and §5.8 (aging and expiry).
