# 1158 — Compose retirement through the actual settlement host

Date: 2026-10-04 · Status: independently accepted component; operational/UI integration remains open

ADR1155 supplies exact whole-World release leaves, but the current host drops
its unbound Session before clearing any settlement store. The host must retain
the original Session and authority tuple until its ordinary clear is complete,
then invoke the accepted owner-owned release tail. This component composes that
sequence for the actual mounted foundation; it does not construct operational
Room, phase, delivery or route providers.

## Original mount and lifetime

Session privately constructs one `Retirement.Owners` from its fifteen borrowed
host owners and existing foundation. Optional operational slots remain null.
There is no public adoption or registration setter. The host compares its
actual mounted Session, original World, Directory and all borrowed objects
before and after Session's cold observations. A matching foreign token or an
externally installed authority is not a mounted composition and refuses.

`prepare_world_reset(allow_prepared_world)` retains its public signature. First
prepare observes the original foundation, repeats the concrete mount check,
then calls Session's `prepare_retirement(host, allow_prepared_world)` to retain
one private Scope. Repeated prepare revalidates that original Scope; it does
not allocate another or run ordinary observations on a prepared retirement.

`reset` advances one host integer phase from prepared to clearing, uses the
existing complete `_clear_stores` order, checks the original mount again and
calls `release_retirement(host)`. The accepted kernel rechecks all emptied
owners before releasing the four once-bound links. Scope is dropped before
Session's Owners and foundation references, explicitly breaking the temporary
Session-to-Scope-to-Session cycle. No generation is rewound and no arena grows.

Host destruction also drops only the private Scope reference in PREDELETE,
so an abandoned continuation cannot retain Session through a strong cycle.
It does not release or rewrite any actual store authority.

The four host states are idle, preparing, prepared and clearing. Fixed/day
ticks, generation/cohort/colony admissions and ordinary project mutations
refuse while any reset phase is active. Session current reads and fresh owner
getters refuse while Scope is held. A recursive reset during clearing cannot
clear stores twice. `abandon_world_reset` delegates to `abandon_retirement` only
while the original complete World is still live and unchanged; once clearing
begins it refuses and leaves the host stopped. Existing UI/main failure paths
are audited read-only for the integration owner to add abandonment where needed.

The old `retire_foundation` remains an unbound-only API. It cannot discard a
pending Scope. Future root-owned operational constructors must populate the
private Owners packet from their own original receivers and update its exact
source checks; this change does not permit external packet registration.

## Ownership and storage

The furnishing lane owns only Session, SettlementSystem, their existing
Session/underground-host tests, this ADR and its evidence subtree. Root retains
UI/demo/main and shared registry/memory tooling. No other owner is modified.

The new source-counted storage is two Session references (one permanent Owners
and one temporary Scope) and one host integer reset phase. The permanent Owners
replaces the caller packet already charged in ADR1155; it is not a third copy.
The original Session1536 and additional retirement8192 reservations are retained
without increasing any ceiling. The census includes 111 joint reference slots and 84 numeric member bytes.
The additional retirement control calculation is 5,673/6,144 bytes; the
composed host/Session plus complete accepted static owner chain has at most
170 numeric/name bytes and 23 reference values, giving 1,162/2,048 helper
bytes including the existing 256-byte expression allowance. Implicit instance
receivers and reference-valued returns are included. Existing source-hash
observations and store-clear internals retain their original owner reservations;
their caller prefixes are included here. No source image is copied.

The 32-byte reference, three 256-byte control-object and 2,048-byte shared
native/symbol terms remain provisional. Original Session1,536 is charged once;
additional retirement8,192 keeps the proposed profile joint at 246,868/262,144
without enlarging a ceiling. These are source/reference bounds, not native
allocation measurements.

## Required evidence

Use real generated host population, starter buildings, actual source Content
and published catalog; do not replace source checks with fixture success.
Exercise prepare without clearing, repeated prepare, stopped ticks/admissions
and getters, original-live abandonment, late owner/source substitution, active
lease/transaction refusal, staged-World preservation, actual clear/release and
fresh remount with stale old handles. Weak references must demonstrate that
successful release and abandonment break the private Scope cycle. Preserve
all failed runs and exact executed sources. Strict diagnostics/leaks, changed
file zero-warning analysis, source census and independent review precede commit.

Mounted operational Room/Sites/Inventory authorities, demo boot/Create UI
cleanup, full integrated acceptance and measured native allocation remain
separate root-owned integration gates.

## Independent review and result

Root read the complete production/test delta, verified seven executable,
38 original output and 50 history pins, and independently reran 16 census
mutants. No runtime finding remained. Actual selected validation totals
250 tests / 8,529 assertions / zero failures; five preexisting expected
Settlement diagnostics are disclosed, with zero unexpected diagnostics or
leaks and analyzer 0/4. The correction to the Main-boot audit is prose only.
See `docs/validation/evidence/underground-host-retirement-2026-10-04/` for the
exact accepted review, restored inputs and original document locators.
