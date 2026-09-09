# 0031 — A deposit declares which occupant it may replace
Date: 2026-09-09 · Status: Accepted
Implements [0029](0029-deposits-are-sixteen-nodes.md); records the one judgement
call that ruling did not settle.

## The problem
§5.1 says "Ore footprints replace tree nodes". But **`resource_id`'s domain is
unstated** — a pre-existing recorded gap in `resource_nodes.gd` — so the store
cannot tell a tree row from any other row. It validates range only.

That leaves the instruction unimplementable as literally written.

## The decision
The caller **declares** which `resource_id` may be replaced. Any other occupant
refuses the whole deposit with `FOOTPRINT_OCCUPIED`.

The alternative was to read §5.1 as "replace whatever stands there", which would
let a deposit **silently delete a node §5.1 never authorised it to touch.** A
refusal is recoverable and visible; a silent deletion is neither. Where a
specification is ambiguous about destroying data, the reading that destroys less
is the safer default, and it can be relaxed later without having lost anything.

`regrow_days` is a parameter for the same reason rather than a compiled-in `0`:
§5.9 states no period for stone or iron, while §5.1's separate renewable bedrock
access shows an ore node *can* be renewable.

## Allocate-before-consume, and its visible cost
All sixteen directory rows are reserved **before** any replaced node is
destroyed, and every reservation rolls back on refusal. Any refusal leaves the
store byte-identical: no half-built deposit, and **no felled tree with nothing in
its place.**

This ordering has a real consequence, and it is pinned by test rather than
discovered later: on a nearly full store the sixteen rows must be free *before*
the replaced nodes hand theirs back, so **15 free rows refuse** with
`CAPACITY_RESOURCE_NODE` and spare the tree, where **16 free rows succeed**. A
destroy-first order could have squeezed in. That is the price of atomicity and it
is paid deliberately.

## A note on how the transcribed quantities are actually verified
The `_init` drift assert guards `75000*16 == 1200000` and `18750*16 == 300000`.
That assert is strong enough to kill a mutation of either quantity **on its own**
— which means it, not the tests, was doing the work, and the suite could have
been passing on the assert alone.

Paired mutations were therefore added that move a per-node quantity **and** its
total together, so the assert still passes: stone `75000/1200016` and iron
`18750/300016`. Both fail the suite. **The tests, not just the assert, pin the
transcribed values.**

This generalises: a mutation killed only by an assertion that aborts
construction proves the guard works, not that the behaviour is tested.

## Source
Task 03, implementing decision 0029, 2026-09-09. 1011 tests / 29100 assertions /
0 failures; 28 mutations, no survivors.
