# 1073 — Shared modular receipts and actual worker routing

Date: 2026-10-03 · Status: B2 receipts and B3 actual worker router implemented; production adapters remain open

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

## B3 accepted Job schema

Jobs' requester field is neither unique nor an immutable authorization to
advance a project. Add four packed I32 columns to `ModularProjects`, keyed by
the existing actual Job typed row: bound Job slot/generation and Construction
project slot/generation. Full references are retained; a typed row is never
mistaken for a Directory slot. Their fixed extent is Jobs.JOB_CAPACITY=8192,
for **131072 persistent bytes** and another **131072 per simultaneous cold
image**. These bindings cannot honestly be derived from all requester refs,
because only the actual owner's accepted primary and explicitly accepted party
Jobs are authorized.

Binding checks uniqueness on a cold finite scan, then productive lookup is
O(1). A primary Job may be solo or the real existing party coordinator.
Members hold zero independent remaining work and must qualify through their
actual coordinator; the current project's maximum of four builders remains
enforced. Every productive worker requires current generation, actual Job,
mandatory equipped tool, positive durability and current physical contact.
No per-worker objects or cold bill/Buildings result allocations are introduced
into the productive path. Pause/cancellation must inspect relevant members,
late requester Jobs and unfinished claims before a safe retirement.

B3 implements this router and Work adapter; B2 alone did not. UG16 must
validate these cross-owner references atomically in the versioned codec.
The router explicitly refuses legacy capture rather than dropping its bindings.
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


## B3 actual payment, worker and retirement implementation

`ModularProjects.new` borrows the actual Sites Funding arena and preflights
Construction and Work before either binds. Inventory, Reservations, catalog,
Jobs, Work, equipment and the live full World reference must belong to that
same composition. A later catalog/equipment rewiring is rechecked through
O(1) owner readers. Purpose owners are weak, bind once, and cannot be replaced
after expiry to reset physical history. There is no per-order owner object.

`open_order(owner, subject, operation)` reads the physical owner's already
prepared immutable quote. Callers do not supply prices, completed work or
adopted quantity. Actual Construction allocates the project and its exact
synchronous callback attaches that identity to the physical owner. A tip
handle remains in the tip purpose and actual World; it is never reinterpreted
as a Building, Room or excavation operation.

`bind_job` accepts one real solo Job or existing party coordinator. `bind_member`
accepts each actual zero-work member explicitly, retaining its full Job and
project reference in the same four columns. No fifth member can be accepted.
A worker may leave and a replacement occupy that still-owned member role
without losing the coordinator's single remaining-work counter. A stale,
detached or externally destroyed accepted Job refuses until its ownership
is resolved; it cannot be silently overwritten or promoted to a primary.

`bind_material_container` requires actual reachable contact.
`record_deliveries` derives every credit from actual modular-input claims
and the entire current bill. `start_work` prepares current contacts, verifies
actual worker/tool bindings and invokes real Funding consumption before
Construction or Jobs become productive. Positive outputs reserve finite
real capacity. Existing first-pile staging remains a World-owned surface
contact with the existing 400000 g policy; a deeper endpoint cannot alias a
surface tile. The actual spatial Inventory/Haul endpoint is a subsequent
integration. An ordinary unlimited container is not proof of such a pile.

Every productive tick uses real Work for capped labor, XP, integer carries
and equipped tool wear. Its successful owner gate retains an exact transient
Job bracket. Any subsequent tool, skill, carry or other Work refusal invokes
`discard_work_tick` for that Job. Zero accepted work also discards the physical
candidate. Only Work's synchronous post-commit callback can apply its real
Job-counter difference to Construction and publish PRODUCTIVE. Direct Work
calls, manually edited Job counters and direct publication attempts grant
no paid work. The router performs O(1) binding lookup and an at-most-four
member walk, with no Quote/Buildings reads or allocation of worker objects.
An unrelated ordinary Job keeps its existing Work behavior.

`set_paused` first holds actual Construction, then checks every relevant
accepted or late requester/member Job and actual Inventory/Work/Gear claim
before releasing claims and workers. Paid WIP and integer carry survive.
`resume_work` verifies real reassignment, matching remaining work and fresh
contacts without consuming a second bill. A safe refused pause may remain
held; this prevents an unsafe worker from continuing during reconciliation.

`complete_order` finishes fallible source/contact/output and worker-release
preflights, commits the real Funding outputs, releases actual workers, then
opens the exact physical COMMIT callback. `cancel_order` freezes accounting
and either releases unstarted claims in place or refunds actual WIP. A blocked
refund retains project/receipts and source claims for retry. Physical CANCEL
publishes only after settlement. Cancellation may have safely released workers
or some unstarted claims before a later refusal; this is explicit resumable
state, not a claim of byte-atomic cancellation across all owners.

Completion/cancellation destroys accepted member Jobs before the primary and
then retires Construction. No post-publication bill read occurs: actual
Furniture installation or tip closure may intentionally invalidate the former
subject facts. Retained zero-work operations still repay the full bill and
then complete through fresh COMMIT without a fabricated productive tick.
Legacy surface Construction and ordinary Work contracts are unchanged.

## B3 simultaneous allocations and persistence obligations

The four I32 Job columns total 131072 persistent live bytes. Each actual
simultaneous cold image adds another 131072; `_delivery_totals` adds 32 bytes
of packed cold scratch. There is no extra project receipt arena. Router
initialization refusal leaves its columns empty. The existing source coverage
gate proves the exact fixed Job capacity and four-line delivery capacity.

Construction, Funding and Router each own one reusable Quote: **three times
112 = 336 packed scratch bytes** in the assembled implementation. Per Quote,
eight integer facts add 64 logical bytes and its full subject reference adds
8, for **72 numeric control bytes**. Its four StringName keys, Array/object
headers, packed-array handles, references and other native overhead are
separate and consume the composition's explicit native/control reservation.
These are component scratch objects, never one Quote per project or worker.

Router itself adds 49 numeric control bytes: derived World ref 8, crew count
8, busy flag 1, mutation project/action 16 and publication project/action 16.
Its two reusable IntResults add 18 numeric bytes (one bool plus one I64 each),
plus their String/native overhead. Its exact owner references, weak purpose
and admission bindings, refusal StringName and strong callback-only owner
reference are wiring/native controls, not persisted or canonicalized pointers.
Work adds two transient full Job brackets (16 bytes) plus a weak router target.
The callback owner is assigned only during publication; this avoids allocating
a WeakRef on every productive tick.

Relative to the already counted B2 arena/Quote, B3 therefore adds 131072 live
plus 131072 cold-image bytes, 32 delivery scratch, 112 Quote packed scratch,
72 Quote numeric controls, 67 Router numeric controls and 16 Work bracket
bytes: **262443 logical bytes**, before explicit native/declaration overhead.
Root's joint decision 1072 must count the complete simultaneous lifetimes;
independent maxima are not production admission. No target-hardware runtime
or memory-budget pass is claimed here.

UG16 must capture and validate all four binding columns with actual Job,
Construction, party, receipt and physical-owner identities, rebind exact
live owners, and clear transient windows on load. An old codec must not
silently omit retained bindings or reinterpret new purposes. This increment
supplies local state images/refusals, not the composed release codec.

## B3 verification scope

The Router tests use actual Construction, Inventory, Reservations, Items,
Jobs, Work, Residents, Gear, Buildings and the one actual Sites Funding arena.
Only physical contact/geometry and purpose source publication permission are
explicitly synthetic. The tests include actual paid Kitchen-bench installation,
which invalidates the pending quote before safe retirement, real party limits
and replacement, byte-identical refusal comparisons, expired/foreign wiring,
late requesters, stale generations, orphan equipment, blocked refund retry,
retained zero work/full repayment, post-gate abort and zero accepted work.
They do not claim actual tip stock, production room dispatch, measured worker
clearance or the staged pending-to-installed geometry/service bridge. Those
remain the responsibilities of their concrete adapters.

Initial B3 validation caught an incorrect fixture reader name and a child
fixture left in a nonproductive Job state. Both tests were corrected; the
second now explicitly attempts productive child work. The unchanged strict
runner caught both failures. Final frozen-source test/analyzer evidence is
recorded with the source checkpoint under the B3 evidence directory.


The final unchanged B3 candidate passed a fresh asset-free cache/import, then
**293 tests / 48339 assertions / 0 failures** across eight strict singleton
suites. Every suite reports zero unexpected errors/warnings, zero expected or
tolerated diagnostics, zero raw unexpected errors/warnings and zero leaked
objects/resources. The five-file analyzer reports `0 GDScript warning(s) in
0 of 5 file(s)`. Independent review accepted all five matching frozen source
hashes with no unresolved finding in this scope. Exact logs and source pins:
`docs/validation/evidence/underground-ug07-shared-router-2026-10-03/`.
