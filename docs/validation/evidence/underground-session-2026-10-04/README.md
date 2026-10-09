# UG24 / ADR1146 — actual Session foundation

This packet owns only the new Session, its new test/UIDs, and this evidence
directory. Root owns ADR1146, SettlementSystem, the demo adapter, lifetime/reset
APIs and the shared memory/registry records. The starting checkout is
`205ec79ed07d6ce5ee4a169ab46b5162e5c9ffc5`, fast-forwarded from freshly fetched
`origin/master` (`82d60ba86dcecf6e7c6184eeaf77a389e8b2b5c2`).

## Fixed implementation contract

Session borrows the actual World/full World identity, Buildings, Construction,
Inventory, Items, Residents, Jobs, Work, Reservations, Transforms, Gear,
HaulCarry, GroundPiles and already loaded ActorContent. It derives the actual
Directory from that World and checks every collaborator, including exact
`Work.gear`, before allocating foundation banks. Missing Gear/Carry/Content is
a refusal; Session supplies no alternate stores or source catalog.

Its private foundation is one shared Budget, an actual unconfigured Routes
identity receiver, CoreSources using that permanent receiver, one Space owner,
Terrain using its actual published World, the immutable initial Levels pack,
and the actual current mole Profile catalog. Domain values come from Terrain's
existing constants and Budget's configured capacities. Profiles uses the
published 18-profile / 194-box / one-source configuration. All eight actual
consumer Scripts must match the current publication. Historical source geometry
cannot reopen a changed production consumer.

Initialization is synchronous and poisoned by reentry. Private candidates are
not exposed while preparing. All observations precede a final direct check of
the original full World/PID/seed and actual collaborator tuple. Refusal releases
only private candidates and allows retry; success is source-once. Session
never binds Buildings/Construction/Inventory authorities during this step.
Neither an empty graph nor the presence of source geometry grants movement,
paid entry, a contact, a renderer certificate or a stair permission.

Session keeps strong references to the borrowed owner tuple and its foundations
for the SettlementSystem lifetime. Getters return existing objects, never
another bank. `current_refusal()` is a cold validation boundary. Reset checking
does not clear data: any active lease/preparation, configured graph, retained
space or one-way authority (including an expired WeakRef) refuses. The host
must supply an explicit coordinated reset/replacement API before this lifetime
can be shortened. Multiple private Sessions over the same unbound stores are
the host's composition responsibility; this component creates no global owner
registry.

## Approved reservation and limits

Root approved a **1,536-byte Session slice within existing PROFILE_BYTES**:
1,024 bytes for its fixed wrapper/control/reference/native allowance and 512
for its own numeric helper frames. No new global reserve, Profile bank,
Motion bank, actor image or per-entity column is introduced. The actual
Profile/Level foundations retain their existing charges (47,288 and 2,292
bytes); the accepted Motion joint peak 232,436 plus Session is **233,972 /
262,144 bytes**. Independent Profile/Motion maxima remain non-composable.

The Routes constructor's existing fixed packets use its existing topology
allowance; no graph/actor bank is configured. Space, Terrain, CoreSources and
Budget each use their existing single-owner reservation. Domain's temporary
descriptor and the Levels/Profile loader frames belong to those existing
foundation bounds and occur sequentially. ActorContent is an already loaded
borrowed host input charged to presentation, not a second Session allocation.
Final source census and negative mutation checks must verify these claims.
Native allocation and whole-game performance remain unmeasured.

## Candidate-4 validation and source freeze

The exact candidate passes **77 tests / 1,768 assertions / 0 failures**:
Session 14/211, current published mole catalog 8/227, actual Terrain 28/1042,
and actual starter-colony generation 27/288. Every strict/raw unexpected error,
warning, expected/tolerated diagnostic and leak count is zero. The clean import
raw guard passed and the analyzer reports **0 warnings in 2 files**.
`candidate-4/invocation.json` records the exact commands, original source pins,
isolated `Redwall-ug-session` user directory, port6317 and successful restoration
of project/diagnostic registry/assets. Only the new module needs a temporary
test registry section; that classification is not a shared ledger update.

The 14 Session cases use actual `SettlementSystem.create_generated_settlement`,
the tracked ActorContent image, current v2 profile artifact and actual
Gear/Carry bindings. They exercise full stock/identity/pose preservation,
missing/foreign owner and content refusal, actual cached Script drift,
observing Gear reentry, actual Carry and Work rewiring, World seed/generation
replacement, a real Profiles revision2 load, original cold/Space tokens,
expired authority retention, the strong source/World lifetime and a successful
Space receipt that must not be silently reset. There is no fixture Catalog or
certificate override.

`census.py` derives **27 retained numeric bytes and 24 strong references/aliases**
from the actual new source, no packed columns, and a **48-byte own maximum
numeric/StringName call chain** inside the 512 helper slice. The separate
maximum own borrowed-reference call chain is 28 values (`configure` and
`_borrow`); these are not additional retained owners. The 997 bytes left inside
the 1024 fixed slice are explicitly provisional reference/Variant/native
header allowance, not a measurement or a claim that a reference is free.
Foundation callees retain their existing own logical/native allowances; the
Session's caller frames coexist and are charged here, once. Seventeen Python
tests reject extra/inherited/untyped/widened state, another bank or source image,
duplicate construction, a second retained Domain, independent maximum Profile
configuration, authority mutation and changed underlying arena formulas.
`census.json` pins all unchanged foundation source files and records
**233,972 / 262,144** joint logical reservation including accepted Motion.

Rejected evidence remains intact. `candidate-1` used a nonexistent Buildings
`state_bytes` test helper, causing five aborted cases; the corrected fixture
hashes every actual packed/numeric Buildings property. `candidate-2` passed the
original 12 cases/188 assertions. `candidate-3` retained a test-only parse error
from treating the actual void Space publication as a return value; candidate-4
instead checks its original successful receipt. Neither failed run is runtime
acceptance. `historical-source-locators.json` retains both exact executed
GDScript source images for each of candidates1–3; every reconstructed historical
image was required to match its original invocation's SHA256 before retention.

`source-sha256.json` is the final source/test/UID/census/harness freeze. This is a
foundation correctness packet. Root independently reviewed the frozen candidate-4
source and replayed all 17 census tests, reporting no blocking correctness issue
within this foundation-only boundary. Root will reconcile the historical
accepted Motion total against the actual shared Motion/Profile/Level source
accounting before integrated acceptance. Native
memory, whole-game latency, UI/RoomOrders composition, renderer attachment,
paid construction and traversal activation remain outside this component.

## Final API and strong-reference lifetime

`configure(world, full_world, buildings, construction, inventory, items,
residents, jobs, work, reservations, transforms, gear, carry, piles,
actual_content) -> StringName` uses the concrete types in the new source.
The full World reference, PID and published seed are captured once. Source
failure releases only private candidates and borrows; an accepted instance
cannot be configured again.

`current_refusal() -> StringName` is a cold exact source/owner check. The seven
typed getters `space_owner`, `source_owner`, `terrain_owner`, `level_catalog`,
`profile_catalog`, `route_owner`, and `cold_budget` perform that check and return
the existing object or null. They are not per-tick APIs or operational permits.
The exposed actual Routes receiver remains unconfigured, and source geometry
does not create support, endpoint, graph, paid contact or animation permission.

The 15 strong borrowed references are World, derived Directory, Buildings,
Construction, Inventory, Items, Residents, Jobs, Work, Reservations, Transforms,
Gear, Carry, Piles and Content. The eight foundation references are Budget,
Routes, CoreSources, Space, Terrain, Levels, Profiles and an alias to Space's
Domain. The final reference aliases the originally published Profile bank.
There are no per-entity wrappers. Neither the host Node nor this Session is
retained by one of those foundations; the actual lifetime regression verifies
there is no composer cycle after the last strong Session reference is dropped.

`reset_refusal() -> StringName` is read-only. A held cold lease, prepared Space,
configured graph, used/new Space receipt or any one-way authority binding
refuses. Root must call the lifecycle preflight before any destructive host
clear. Once actual authorities are attached, their existing APIs retain even
expired weak pointers; a full reset therefore needs root's explicit coordinated
owner replacement/reset contract. Session does not clear those pointers or
pretend that foundation quiescence alone implements the host reset.
