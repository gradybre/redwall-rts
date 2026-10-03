# 1103 — Actual surface work anchor

Date: 2026-10-03

Status: scoped component implemented, independently reviewed and strict-tested;
full1101 stair frontier and playable composition remain open.

## Need and source of truth

The first physical cut needs a completed work position on existing natural
ground before any Room, Site or timber stair exists. Reusing a future Site or
Room publication callback for this would invent an owner and a free floor.
Create a World-owned level0 anchor from actual exterior air and retained dry
natural footing. This is observation of existing space, not excavation or
construction. No material, timber, Room, Site, worker reach or route is created.

Root owns underground_surface_anchor.gd and its tests. Geometry owns the narrow
underground_locations.gd World context and tests. Both use separate own codex
branches and explicit file leases. No other owner's edits may be reverted.

## Atomic companion contract

Locations adds a typed WorldScope, a once-bound actual scope, and
`begin_world_prepare(cold_token, space_token)`. The WorldScope checks
`exact_binding(locations, space, budget, world)`,
`prepared_refusal(space_token, cold_token)`, and callback-free
`is_publishing(space_token, cold_token)`. A generic caller bool, Room refresh,
or physical Site context cannot authorize this operation. The once-bound scope
is weakly retained and cannot be replaced, including after expiration. Binding
requires a configured actual World/owner, quiescent Budget and no preparation;
callers cannot swap a scope through the prepare API.

The concrete root provider pins actual World/Domain, Terrain, Space, source
owners, Locations, original Budget lease and exact integer envelope/footing.
It proves current natural exterior/support facts, source revisions and full
World identity; live resources/buildings and retained geometry/claims must not
overlap the proposed space or removed/reclaimed natural support. It stages
only World-owned level0 FLOOR_DATUM, exterior SUPPORTED_VOID and protected
retained-natural SUPPORT. Support must be outside every requested cut.

The context may add World/null-Room level0 records and refresh existing records
without changing payloads. It cannot remove or repurpose endpoints.

Locations checks exact root height and complete envelope/support coverage
against the sealed spatial candidate. It publishes only inside the concrete
provider's synchronous window, after the exact Owner publication token and
target revision, with original lease and final Inventory/Routes retention
guards still valid. The final callback-free actual scope and receipt checks
follow every observer. Any refusal before publication leaves live state
unchanged; neither a different transaction's equal revision nor a replaced
cold lease supplies authority.

Cold scratch is admitted before allocation. Fixed controls and new provider
state must fit the remaining shared binding reserve and join the source census;
no additional authoritative arena, receipt or physical history is introduced.
Published Region/Location state uses those owners' existing canonical storage.
A complete save/load composition remains UG16.

## First-cut witness and limits

The candidate front cube is datum-aligned Y[-512,512], with a root at Y512
on retained surface outside its footprint. The current top-face profile
suggests a root384u behind the near face and local X512/1280 in the two1m
columns. These are source-derived candidate contacts, not production permission;
the genuine worker/tool profile and complete motion still need qualification.

The current647u-long work stance cannot fit one512u tread at one height.
Installed fractional treads do not become workstations by assertion. The full
entry needs a physically executable cut/install sequence, assembly grouping,
paid dependencies, legal retreat and qualified high-wall work for the Kitchen
upper course. This anchor closes none of those obligations by itself.

## Implementation candidate on the owned surface branch

The concrete create API takes an integer root, complete exterior envelope,
complete natural footing and Location role. It copies caller data into fixed
scratch, proves real current Terrain and all retained geometry/claim exclusions,
and stages precisely the three World rows. Existing full Location payloads are
refreshed without repointing. A new Room, Site, timber part, recipe, worker/tool
permission or graph edge is never an effect of this operation.

The prepared natural-facts reader names the original Space revision, exact
sealed Space token and original actual Budget token. Ordinary final terrain
reads stay live-only. It reads current World/resources/Building leaves without
another source observation and adds no persistent state or packed allocation.
The root provider checks the exact three prepared rows, then repeats pure natural
and retained source/claim facts after the last external observer. The publication
window contains only the two prepared swaps and pure window/receipt checks.

Fixed logical storage is one Location record116, Region72, provider numeric
controls92 and returned result16=296 bytes before bounded helper frames.
A2048-byte reservation covers these controls within the existing binding
reserve; native overhead is still unqualified. Variable packed scratch remains
empty until configure admission. Locations cold peak plus2048 must fit the
original shared cold Budget before any anchor is created. There is no new
canonical field or live arena; saving requires the coordinator quiescent.

The corrected candidate passed126 strict tests/4420 assertions with no failures,
unexpected diagnostics or leaks, and a zero-warning analyzer over eight affected
files. Independent Geometry re-review accepted the corrected frozen source with
all four findings closed. Complete
first-entry, playable workflow and native memory acceptance remain open.

## Review correction boundaries

Independent review found one high atomicity issue and three medium issues. The
final World Location candidate is now checked by pure exact original-token,
sealed-mode, target-revision and complete payload/old-row guards before Space
publishes. A late abort or replacement cannot leave orphan natural-space rows.
Cleanup preserves independently replaced candidate tokens and cold leases.

Configure holds a poisoned reentry guard over every initial observer before any
public creation can touch unsized scratch. The provider retains the original
concrete Directory, Buildings, Construction, Inventory, Transforms, Residents,
Jobs, Work, Profiles, route binding and Profile collaborators. Prepared checks
compare those same instances even when there are no Resident source rows.
These extra references add native composition overhead, not saved authority.

One integer work counter covers the entire create, including every repeated
World scope callback needed to refresh prior endpoints. The source-count scan
is charged before it runs, followed by the complete source/claim, three Terrain
queries and retained-row scan. Final endpoint comparisons are also precharged.
Exhaustion refuses atomically; it is an operation budget, not a new gameplay
endpoint limit. Real low-budget and multiple-endpoint regressions verify this.

The World Locations prerequisite and its conservative full-claim refresh limit
are recorded in `docs/validation/evidence/underground-world-locations-2026-10-03`.
An underground endpoint covered by a Room reservation can refuse this bootstrap
path; no traversal exemption is silently borrowed.

