# 1081 — Paid underground furniture and one room authority

Date: 2026-10-03 · Status: Accepted bounded paid-Furniture increment; Room admission follows

## Decision

One actual `UndergroundRoomOrders` owns Buildings' weak spatial-authority
binding for room lifecycle and furnishing. `UndergroundFurnitureWork` owns
the separate spatial-furniture purpose in the actual shared modular router.
Neither adds a receipt arena, Construction table, geometry store, price or
per-piece object. Full actual Room/Furniture generations and the protected
catalog remain authoritative; a Kitchen cannot become a Bedroom by clearing
its contents.

The first increment installs or cancels an already registered actual pending
Furniture identity. Admission requires its completed Room shell, compatible
permanent purpose, exact sparse-space source, full placement and access proof.
Missing physical/profile/service bindings refuse. The base typed binding has
no successful geometry fallback and is not activated by the demo.

## Paid publication

The owner copies the existing Construction furniture bill and BUILD work into
the router's reusable Quote. The single existing Funding arena consumes actual
claimed lots. Actual Jobs, Work and Gear supply labor, skills and tool wear.
START and every productive contribution require the real current contact
binding; a caller supplies neither a price nor accepted work.

Completion prepares the sparse owner's narrowly attested pending-to-installed
source transition and all companion contact/service changes before Inventory
commits. During the exact router COMMIT call stack, Buildings publishes the
installed flag and presence count, the sparse owner publishes the sealed
future source, then the companion owner publishes its prepared result. There
is no fallible reconstruction after payment and no post-install bill read.
Installation presence alone never proves a valid or usable Room service.

Cancellation removes only that full Furniture identity's geometry from a
sealed candidate. Actual refunds settle first. The candidate publishes while
the source identity is still live, then Buildings retires the pending item.
The Room footprint, neighboring furniture, protected routes and other project
claims remain owned. A blocked refund retains WIP and candidate-independent
live geometry for retry. Router cancellation may already have safely frozen
work or released workers/claims; it is not an all-owner rollback operation.

## Allocation boundary and remaining work

No authoritative columns are added. The two components retain only weak
composition links and reusable transient operation controls. Numeric
component controls are 59 bytes for RoomOrders and 33 for FurnitureWork,
including one existing-shape IntResult per component. No additional Quote is
allocated. Cold cancellation's own packed packets have a conservative
`8R + 72` byte bound: two int32 handle entries for at most the actual `R`
region rows, six-int32 retained survey bounds, and old/new six-int32 Region
boxes during assignment. The domain-copy temporary boxes precede the handle
population and fit that conservative bound. The sparse owner's existing live
and staged banks are counted separately, not duplicated in this component.
The cold Region packet also carries 48 logical numeric bytes, the locally
retained SpaceOwner result 16, and the earlier temporary immutable Domain 68;
these packet lifetimes are not all simultaneous. Existing imported helper
frames and Variant/reference/native headers remain within the explicitly
admitted bindings/control reservation, with measured runtime qualification
still open. None of these cold packets is an entity component or save image.
An explicit typed `begin_cold` acquires the shared actual World budget before
the first sparse-bank, domain or handle copy for COMMIT/CANCEL. A one-byte
`_cold_held` records successful admission independently of the spatial token.
The exact lease remains with the typed binding and releases only after
companion scratch and this operation's sparse candidate have been published
or discarded. A denied/nested lease makes no spatial copy; a later busy
geometry owner keeps its own token while this attempt releases only its own
lease. START/PRODUCTIVE allocate no cold bank and never acquire a cold lease.
This ordering corrects the independent review's pre-allocation budget finding.
Variant, reference and engine-native overhead is separately qualified, never
called zero runtime memory. These bindings and in-flight permits are rebuilt,
not serialized pointers. UG16 still owns composed save/load and source checks.

Atomic new Room/Furniture batch admission is a separate following increment.
The current Directory has no candidate full-identity/transaction primitive;
create-then-delete would advance generation/PID and violate RoomLayout's
unchanged-on-refusal contract. This increment does not simulate such rollback,
use fake identities, replace the sole Buildings authority, or claim Room
confirmation and the full underground workflow complete. Actual shell,
profile, hauling/contact, service and UI composition remain the assigned
dependent work. Tests distinguish synthetic physical qualification from the
actual accounting, identity, geometry and installation owners they exercise.

## Source

Approved D08/D09/D10/D12/D18/D19, the adopted GDD catalog and fixed work rules,
1069 actual identities, 1073 shared paid router, 1079 physical Inventory output,
and 1064's sealed actual sparse-space source transition. No gameplay rule or
production geometry constant is introduced here.

## Verified bounded increment

Independent source review accepted the exact four source/test hashes after
the pre-allocation cold-budget fix. The final own-worktree CI-style clean
import had zero error/warning lines. Five unchanged strict singleton shards
passed **94 tests / 7530 assertions / 0 failures**: paid Furniture 15/4628,
Room authority 6/229, actual sparse-space owner 39/570, shared modular router
19/1816, and spatial Buildings 15/287. Every runner reports:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The actual editor analyzer on the four changed files reports
`0 GDScript warning(s) in 0 of 4 file(s)`. Registry source coverage passes
111 modules / 532 rows / 925 packed columns. Reviewed source hashes remained
unchanged through final checks. The initial missing result-constructor
arguments were rejected by the strict parser/analyzer and corrected; those
rejections remain in the evidence, and no diagnostic allowance changed.

The tests compose actual Directory/Buildings, Construction/Router/Funding,
Inventory/Reservations, Jobs/Work/Gear and sparse SpaceOwner publication.
They cover completed-work versus installed presence, purpose mismatch,
unfinished-shell admission, cancellation/refund capacity/retry, preserved
neighboring geometry, full-generation identity, expired/replaced wiring,
direct callback denial, pause/resume and post-gate zero/refused actual work.
Instrumented real sparse-owner entry points prove cold denial precedes
copying, every acquired synthetic test lease releases, and another geometry
transaction retains its own token. Initial room/item placement, physical
profile/contact qualification, whole-room services and the shared budget
provider are explicitly synthetic fixtures. Real composition, initial atomic
Room/Furniture batch admission, save/load and target-hardware performance
remain the assigned dependent work; this is not a full-suite or complete
underground gameplay claim.

[Full logs, exact commands and reviewed hashes](../validation/evidence/underground-paid-furniture-2026-10-03/README.md)
are retained in the repository.
