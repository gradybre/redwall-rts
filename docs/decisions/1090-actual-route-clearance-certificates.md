# 1090 — Actual route clearance certificates and live local exclusions

Date: 2026-10-03

Status: engineering implementation in progress within the approved modular
underground plan; this record grants no new gameplay rule or completed route.

## Context

An actor moving between surface and underground contacts may straddle the
original ground height. The existing Terrain queries deliberately distinguish
original excavatable substrate, natural footing and open exterior. None alone
can validate this mixed interval: paid excavation belongs to the actual sparse
SpaceOwner, while current water, trees, foundations and surface buildings must
remain visible even when the geometry revision has not changed.

Repeatedly scanning every sparse source for an immutable World identity on
each resident movement query is also unnecessary. This is a bounded source
lookup cost repeated at the population cap, not useful physical validation.

## Implemented prerequisite

`Terrain.exclusions_refusal` reads at most 64 actual nearby tiles and reports
current water, resource, foundation and upper building exclusions across the
ground plane. It uses the same finite domain, full source references and
half-open integer extents as the existing queries. Air at or above water Y=0
does not overlap the wet column, but receives no support or traversal permission.
The method creates no void, paid cut, foundation, floor or route. Original
substrate, finished paid void and actual support still require their respective
owners' independent proofs.

Terrain retains one unsaved 8-byte geometry revision for the immutable World
source proof. Every query still checks actual owner bindings, published seed,
resource owner and full live World generation. The first read at another
spatial revision obtains the actual registered source revision and validates
the real source facts, then rechecks the revision and World lifetime before
caching. A failed or reentrant proof never pins a new revision. World source
facts contain only the immutable full identity/kind; normal geometry publication
and validated restore cannot forget or replace that bound source. This cache
does not extend to resources or Buildings, which are read from their actual
owners on every nearby query.

Terrain's existing 372 packed bytes plus 58 numeric control bytes therefore
become 372 plus 66, inside its unchanged 131072-byte reservation. No wire format,
authoritative column, source capacity or allowed diagnostic count changes.

## Route adapter contract

The typed WorldRoutes adapter consumes actual Profiles, Locations,
SpaceOwner, Terrain and the World with the actual Routes occupancy owner.
An authored floor datum is metadata, never proof of free air or support. Each
profile's full continuous swept body and load must fit completed supported
space, and its stance/support contacts must be covered by actual supporting
facts. Unfinished excavation and unrelated Room claims cannot admit passage.

Cold route compilation will retain profile eligibility bits per full edge
generation, exact geometry revision and content revision. Ground passages can
admit a mouse without falsely certifying a larger animal. Fixed connector
families still require their own authored motion, pace, support and contact
proofs; a generic ground speed or guessed staircase envelope cannot substitute.
Actual worker Job, tool, carried load, profile and current local occupancy are
checked at movement/contact use. This derived cache is neither a save owner nor
permission to silently change the World-pinned finite content.

For 1536 edges and 256 finite profiles, one certificate bank is 79872
bytes: 49152 profile-mask bytes, 6144 generation bytes and two 12288-byte revision
columns. Live plus staged banks reserve 159744 bytes within the existing 524288
binding/native-growth allowance. Fixed scratch and simultaneous cold lifetime
are counted below; these are logical admissions, not measured native memory.

A staged certificate bank remains private through all route publication checks.
It may replace the live bank only after the actual Routes owner successfully
publishes that exact non-reused operation token. A callback agreeing to publish
is insufficient: later endpoint, geometry or lease checks can still refuse.
An aborted candidate cannot supply eligibility to another candidate that reuses
the same numeric row. Full-generation paths are immutable; refreshing an edge
requalifies its content/geometry, while editing a path requires a new generation.

## Evidence and remaining work

Focused regression tests cover mixed-height boundaries, water/ford faces, live
resource lifecycle, unfinished unregistered Buildings, production source
capacity, full-generation retirement and source-read reentrancy. Independent
geometry review matched the final source/test hashes, traced validated restore
and the non-forgettable World source, and found no high or medium issue.

Evidence is retained under
`docs/validation/evidence/underground-route-clearance-2026-10-03/iteration-1/`.
The exact assets-absent clean editor import precedes strict singleton CI
selections: Terrain 23 tests / 966 assertions and WorldBindings 34 / 766,
57 tests / 1732 assertions total, zero failures. Both strict and raw diagnostic
footers report zero unexpected errors, warnings and leaked objects/resources;
expected and tolerated counts are zero. Analyzer: zero GDScript warnings across
both changed files. Final hashes are unchanged and own-worktree assets restored.
This is focused evidence, separate from the full frozen fc4fac4f checkpoint.
The implemented ground-only adapter is documented below. Continuous fixed
connector proof, ordinary demo activation, save composition and the256-resident
performance gate remain open.

## Actual ground adapter increment

`underground_world_routes.gd` supplies the concrete Routes binding. It verifies
the exact World, Directory, Residents, Transforms, CoreSources, SpaceOwner,
Locations, Profiles, Levels, Movement, ConnectorCatalog, Terrain and shared
Budget. Matching numeric references in a different owner graph do not bind it.
Only ground family-1/variant0 is currently admitted; fixed connector families
explicitly refuse until their separately paid installed geometry and complete
motion/contact proof exist. Catalog rows alone never install stairs.

Compilation holds one actual traversal snapshot, with only typed reservation
markers omitted by the physical owner. Every whole body/load and turn/recovery
swept AABB must be covered by the exact union of completed void and actual
support intersected with explicit authored stance. Every stance independently
requires real support. Six disjoint slab subtraction preserves interior holes,
adjacent half-open faces and negative authored residuals without sampling or
rounding them away. It has fixed fragment and work limits; exhaustion refuses.

Completed void does not make physical supporting material intangible. Every
body/recovery intersection with SUPPORT or DRY_SOLID must independently fit
actual support intersected with the authored stance. Review found that skipping
SUPPORT while subtracting void first could otherwise permit a structural beam
through the middle of a path. The regression reproduces this for both body and
the wider recovery envelope, with independently valid actual endpoints. The
corrected rule preserves legitimate below-floor contact and blocks both beams.

Exact geometry, content, catalog and full edge generations qualify every bit.
A catalog reload invalidates all retained masks until each live edge is
requalified. Whole batch source checks bracket cheap prepared observations.
All fallible checks precede publication, and only the exact successful actual
Routes publication receipt promotes the private mask bank. Exact successful
Space/Locations companion receipts are required for future-geometry composition;
equal revision counters after abort/reuse are insufficient.

At use, actual profile identity, equipment/load, actor pose and occupancy remain
required. Fresh bounded Terrain exclusion reads see water, resources and upper
buildings even when the sparse revision does not change. A local reentry guard
protects the reusable body/contact scratch across these callbacks. Hot motion
does not allocate another whole-world snapshot or reconstruct the cold proof.

The two79872-byte certificate banks plus4096 fixed/control bytes reserve163840
inside the existing524288 binding/native-growth allowance. Together with
ConnectorCatalog190448 this uses354288 before the other declared providers.
The cold packet is377856: Snapshot327680, two flat fragment banks49152 and1024
controls. With the original Authority snapshot425984 and two1013-entry72-byte
plans145872, known simultaneous logical payload949712 fits1048960. It cannot
coexist with the975488-byte terrain compositor. These admissions do not assert
native memory or runtime performance qualification.

The actual ground fixture moves a real resident one metre using actual
Movement pace through the concrete provider. Its body certificates and explicit
surface void/support are labelled test data; it is neither paid demo digging nor
a production-qualified character pack. Tests cover interior holes, unfinished
volume, physical beams, negative contact, finite work/fragment limits, all256
profile bits, catalog changes, geometry invalidation, live resources, exact lease
loss/reacquisition, failed final endpoint publication and callback reentry.
Evidence and initial failures are retained under
`docs/validation/evidence/underground-world-routes-2026-10-03/` and the earlier
numbered iteration directories. Final exact-companion regression, after the support correction:22 tests,1397
assertions,0 failures; strict and independent raw-log unexpected diagnostics
and object/resource leaks are all0; analyzer0 warnings across2 files. The
recorded source hashes remained unchanged and original assets were restored.

Independent review by ug_furnishing accepted the final source/test hashes after
the structural-support regression and correction. It also identified bounded
Terrain range-array allocation as a low-priority cleanup before256-resident
qualification; this increment does not claim that performance gate passed.

The exact successful Space/Locations receipts are now integrated. A concrete
provider regression accepts its exact published Space candidate and refuses an
aborted candidate followed by another publication at the same numeric revision.
No provider source changed after the accepted structural-support correction.
This is not the future installed-connector or paid-Sites/Locations coordinator.
