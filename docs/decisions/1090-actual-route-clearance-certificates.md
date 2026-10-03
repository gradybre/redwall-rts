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

## Route adapter contract being implemented

The next typed WorldRoutes adapter will consume actual Profiles, Locations,
SpaceOwner, Terrain and WorldBindings with the actual Routes occupancy owner.
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

For 1536 edges and 256 finite profiles, one planned certificate bank is 79872
bytes: 49152 profile-mask bytes, 6144 generation bytes and two 12288-byte revision
columns. Live plus staged banks reserve 159744 bytes within the existing 524288
binding/native-growth allowance. Fixed scratch and simultaneous cold lifetime
must be counted before code admission; this figure is not measured native memory.

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
Route certificates, continuous connector proof, ordinary demo activation, save
composition and the 256-resident performance gate remain open.
