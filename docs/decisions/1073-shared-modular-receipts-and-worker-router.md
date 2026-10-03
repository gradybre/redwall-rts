# 1073 — Shared modular receipts and actual worker routing

Date: 2026-10-03 · Status: B2 receipt implementation; router schema approved

## Decision

Continue decision 1069's separate Construction purpose domains for actual
spatial furnishings and World-qualified spoil-tip operations. Reuse the
existing `ExcavationInventory` Funding instance, rather than allocating
another project/receipt arena. Its name records its origin; Inventory owns
loose goods and Funding owns every consumed input until output or refund
settles. No module may interpret a tip operation as an excavation operation.

The Sites `funding_owner` reader returns that exact instance only for the
actual Construction, Inventory, Reservations, Items, Jobs and Work composition.
Late catalog/equipment/claim-store rewiring refuses. The reader grants no
geometry, work-contact or source-stock permission. Those remain duties of
the bound physical purpose owner.

## Implemented B2 receipt transaction

Funding reads the full project-specific bill, including all three Kitchen
bench inputs, from Construction's actual typed owner. Every claimed item,
quantity, full-generation lot and absolute expiry must match. Excavation
claims retain purpose 3; modular claims use purpose 4. Extra or foreign
claims cannot be consumed as spare inputs. Consumption and finite output
reservation remain one actual Inventory/Reservation transaction.

Refunds retain original item, quality, provenance, recipe and captured age
metadata, with integer carry per item. A blocked destination retains every
receipt and reservation; historical loss is booked only after the entire
refund commits. Material-free cancellation needs no destination. Completed
outputs use registered item metadata and checked per-lot mass arithmetic,
release only the current project's reserved mass and publish all output lots
atomically. First-pile promotion uses the existing journaled Inventory API.
A failed promotion or second-output allocation rolls back Inventory and
retains paid WIP for retry; neither retries nor duplicate calls mint goods.

The historical loss column now has three explicit item domains: EXCAVATION,
SPATIAL_FURNITURE and SPOIL_TIP. It contains 768 I64 entries instead of 256,
adding **4096 persistent logical bytes**, and another 4096 for each real
simultaneous copy. This is authoritative history, including after Construction
retirement. It cannot be reconstructed from the remaining live projects.
Funding adds one reusable 112-byte packed Quote scratch record, plus its
four named keys, scalar/reference controls and native container overhead.
The original Funding project/receipt capacities and single arena stay intact.

The measured top-level Funding packed live-plus-scratch formula is now
`2334720 + 88 * receipt_capacity` bytes. At the existing 512-receipt fixture,
that is 2379776 bytes. This reflection-based measurement excludes nested
Quote scratch, which is counted separately above. It is allocation evidence,
not a claim that independent engineering maxima fit the composed world budget.

Sites' support-conservation reader counts only excavation WIP and losses.
Its whole-world earth reader counts the shared loose/WIP/loss stores once,
plus actual tip embedded stock through the typed router. An expired modular
binding explicitly refuses; it cannot silently become assumed zero stock.
The purpose-qualified WIP reader scans the finite project arena on cold
validation paths only, never on a productive tick.

## Typed preparation and publication contract

The base contract grants no permission. Its `is_bound_owner`, `is_publishing`
and `owner_binding_refusal` queries default to refusal; the actual router must
prove exact object and World identity. `item_definitions_owner` exposes the
actual shared catalog, not merely matching item IDs in a different world.

Construction accounting actions and physical preparation actions are
separate domains. Physical ADMIT=0, CANCEL=1, COMMIT=2 and PRODUCTIVE=3 retain
their existing tip-store numbering. START=4 means fresh worker/material/output
contact preparation before input consumption; it changes no tip ledger and
does not share the numeric meaning of Construction's BEGIN_WORK action.
Retained zero-work operations still require full repayment and a fresh COMMIT
check, even though no further productive tick is needed.

Only a successful actual Inventory transaction may open the exact synchronous
physical completion/cancellation publication window. All fallible geometry,
source-lock, service and topology candidate preparation must precede that
commit. Physical publication itself must be non-failing. Funding must finish
its bill/refund reads before actual Furniture installation changes source
facts or tip closure retires a subject. No deferred callback, direct call or
previous window may authorize that publication.

## Approved next router schema

Jobs' requester field is neither unique nor an immutable authorization to
advance a project. Add four packed I32 columns to `ModularProjects`, keyed by
the existing actual Job typed row: bound Job slot/generation and Construction
project slot/generation. Full references are retained; a typed row is never
mistaken for a Directory slot. Their fixed extent is Jobs.JOB_CAPACITY=8192,
for **131072 persistent bytes** and another **131072 per simultaneous cold
image**. These bindings cannot honestly be derived from all requester refs,
because only the actual owner's accepted primary Job is authorized.

Binding checks uniqueness on a cold finite scan, then productive lookup is
O(1). A primary Job may be solo or the real existing party coordinator.
Members hold zero independent remaining work and must qualify through their
actual coordinator; the current project's maximum of four builders remains
enforced. Every productive worker requires current generation, actual Job,
mandatory equipped tool, positive durability and current physical contact.
No per-worker objects or cold bill/Buildings result allocations are introduced
into the productive path. Pause/cancellation must inspect relevant members,
late requester Jobs and unfinished claims before a safe retirement.

The router and Work adapter are the next increment and are **not implemented
by B2**. UG16 must validate these cross-owner references atomically in the
versioned codec, and legacy capture must explicitly refuse retained bindings.
Root's decision 1072 owns the complete simultaneous memory/canonical ledger.
These bounds are engineering allocation ceilings, never room or level policy.

## Scope and verification

The B2 tests use actual Construction, Inventory, Reservations and the single
Funding arena with explicitly synthetic typed physical permission. They do
not activate live tip stock, real worker dispatch or furnishing installation.
The actual room coordinator and staged pending-to-installed geometry/service
bridge remain subsequent integrations. In-world room painting, paid cubic
cut history and permanent room purpose are unchanged.

The final five strict focused suites passed **128 tests / 27099 assertions /
0 failures**. Every suite reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The seven-file analyzer reports `0 GDScript warning(s) in 0 of 7 file(s)`.
Independent source review accepted the frozen seven-file checkpoint, with
no unresolved finding. Raw evidence, source hashes and the setup/correction
record live under
`docs/validation/evidence/underground-ug07-shared-funding-2026-10-03/`.
The clean import preceded the focused runs; it had no diagnostic lines.
No full-suite, hardware performance, production geometry or composed
save/load qualification is inferred from these tests.
