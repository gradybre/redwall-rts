# STOCK-C4-LIFETIME-R01 — borrowed seed-expiry authority

Astra · 2026-09-19 · bounded shutdown ownership repair, active rules unchanged.

The isolated `stock_lifetime_probe.gd` demonstrates that Inventory and StockAge
retain each other after every external reference is dropped. Explicitly
unbinding the seed predicate releases both. This proves one ownership cycle,
not that all reported shutdown warnings have the same cause.

SettlementSystem owns its Inventory and StockAge instances. StockAge reads that
Inventory; Inventory borrows the seed-consumption predicate. Store the latter
as a WeakRef, rather than adding a second strong ownership edge. This is wiring,
not authoritative save state, and must remain outside canonical columns/digests.

`set_seed_expiry_authority(null)` retains its explicit unbind semantics. Binding
an object without the predicate, or rebinding in a transaction, retains the
existing refusal. `clear()` retains the binding exactly as before. A live bound
predicate is held strongly for the duration of a call, with the existing
reentrancy guard. `has_seed_expiry_authority()` reports whether a live predicate
is available.

A previously bound authority that has expired must **refuse consumption** with
existing `INVALID_SEED_EXPIRY_AUTHORITY`; it must not silently become the
never-bound/unbound case. Keep all other seed expiry, conversion, cleanup and
journal semantics unchanged. No new integer state, capacity or catalog ID.

Tests must prove the actual mutual retention disappears after external references
are dropped; live callbacks and reentrancy remain guarded; clear preserves a
live binding; explicit unbind is distinguishable from an expired binding; an
expired authority fails without changing inventory state. Full-suite and boot
leak counts are reported separately before and after; a reduction is not a claim
that all memory ownership or release qualification is finished.
