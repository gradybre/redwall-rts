# 0150 — Resume from integrated master and build the starter colony

Date: 2026-09-19 · Status: Accepted for planning and bounded repairs

## Decision

Continue Brendan's end-to-end settlement development from integrated `47a4da2`
in an isolated worktree. Preserve the older dirty checkout. Apply
[Cycle 4 rulings](../rulings/2026-09-19_cycle04_resumption.md), prioritize a single
inventory authority and the actual starter colony, and retain complete release
scope in [the coverage matrix](../planning/release_coverage_matrix.md).

## Why

The existing executor was waiting for Astra's Cycle 4 handoff. Its latest request
reopens two movement policies already answered by Cycle 3 and overstates the
remaining height-approval dependency. More seriously, the current runtime still
seeds an EconomySystem inventory separate from the empty simulation inventory
driven by StockAge. Green tests and serializable stores do not close that gap.

## Consequences

REG-C4-R01 authorizes bounded addition in source-capacity proofs; BUILD-C4-R01
defines completed-upgrade demolition basis; ECON-C4-R01 assigns physical phase
ownership; UI-C4-R01 aligns contextual visibility and real input rectangles.
No art approval file is edited, no expense is authorized, and no full movement,
save, first-playable or release gate is claimed. Native interactive review still
requires access to the unlocked Mac. Controlled foreground Claude transport is
not an installed unattended product controller.

## Source

Brendan's 2026-09-19 request; AGENTS authority order; ADR0129; current GDD and
amendments; Cycle4 request; source and local baseline evidence under
`docs/validation/evidence/resumption-2026-09-19/`.

## Verified repair follow-through

The independent review exposed two pre-existing capacity-proof holes, both now
covered by synthetic refusals: nested/direct resize variants and augmented
runtime assignments. The read-only sidecar uses schema 2 and correctly names its
canonical-JSON digest; the active registry/save schema remains unchanged.

A real engine probe falsified the old claim that panel clicks already leaked
into the world: Godot consumed them, but the hit table said WORLD. UI-C4 repairs
that disagreement and updates keyboard wiring with context changes. The stronger
probe uses an explicitly instrumented world handler that submits through the
real UiCommandBridge/Settlement command queue; it is not a claim that the missing
production world input router is complete.

The isolated Inventory/StockAge lifetime experiment reproduced a reference
cycle. [STOCK-C4-LIFETIME-R01](../rulings/2026-09-19_stock_authority_lifetime.md)
sets the borrowed predicate edge to WeakRef. Explicit unbind and a released
previous binding remain distinct: the latter refuses consumption. This removes
one demonstrated cycle; the full-suite residual leak count remains separate.
