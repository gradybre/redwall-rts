# 1085 — Actual underground World composition

Date: 2026-10-03 · Status: observation component independently reviewed and verified; productive qualification open

## Decision and ownership

Root takes the previously absent `underground_world_bindings.gd` and focused
test after geometry explicitly released them. Geometry retains SpaceOwner,
SpaceAuthority, Locations, CoreSources and Routes. Construction retains actual
RoomOrders and all paid accounting. The new provider composes those actual
owners; it cannot substitute synthetic yes/no permissions or flat tile Y.

The first implementation slice creates a read-only, bounded complete survey
for an exact query box from actual original terrain and retained sparse matter.
It never replaces already excavated or unfinished space with original dirt,
changes Room ownership, drops claims, or publishes preview geometry. The player
continues to paint on the dirt in the actual selected level (D29).

Terrain gains an explicitly natural-only survey, separate from its existing
full exclusion survey and fresh local checks. This is necessary before an
otherwise unrelated Building has a registered sparse source: the original
substrate still exists, while actual Building/resource exclusions are checked
by the real live owners before admission and productive work. A natural-only
survey never proves that resources, structures or actors are absent.

## Composition and exact boundaries

Copy the validated actual sparse snapshot, clip each retained region to the
query and retain its full source generation/revision and role. For each clipped
natural row, subtract the exact union of retained dry matter, finished void,
unfinished physical volumes, water and openable shell. Preserve all remaining
fragments; a bounding rectangle or corner sample is insufficient. Exact
retained floor metadata suppresses duplicate natural metadata. Planned Room
claims, furniture, supports and protected access remain visible blockers; a
claim is never evidence that soil has been excavated.

Every admitted operation clears output on refusal; a reentrant call refuses without touching the active caller’s output. Source and geometry revisions are checked at the
operation boundary. No survey itself grants support, paid void, a route,
material transfer, service or productive work. Static physical phase plans
still require the concrete actor/profile/contact/structure bindings that are
being developed concurrently. In particular, original dry soil does not prove
that a current footing survives inside retained excavated volume.

## Cold lifetime and allocation admission

Use the exact World-owned decision1072 Budget. Charge before constructing any
snapshot, fragments or caller output; keep the same lease until every retained
output/copy is consumed. A second arena with an equal numeric token is foreign.
This slice does not create another allocator or permanent geometry bank.

Initial technical limits are512 natural rows,8192 composed rows and4096
fragments per work list. They are explicit engineering refusal bounds, not room
size or level-count gameplay policy. Against the actual admitted SpaceOwner
limits R6144/O2048, the conservative simultaneous packed peak is:

| Retained data | Bytes |
|---|---:|
| Actual sparse snapshot48R+16O |327680|
| Natural observations48×512 |24576|
| Composed output48×8192+16O |425984|
| Two4096-fragment lists, sixI32 per fragment |196608|
| Bounded box/transient controls, including terrain survey controls |640|
| Total |**975488**|

The existing shared cold limit is1048960 bytes. Caller-owned RoomPlan copies,
companions and native/container growth are additional admitted coexistence,
not free space; the real coordinating operation must count them before acquiring
the lease. Permanent provider controls and native growth remain in the existing
binding reservation. These are logical source-derived figures, not measured RAM.

## Integration finding and closure gates

At the admitted R6144/O2048 pack, SpaceOwner's old validation precharge used
R×(O+1)+O=12591104 checks, above the unchanged1048576 operation ceiling even for
one region. Load precharge R+O²=4200448 has the same defect. Geometry owns a
bounded algorithm/accounting correction and real-capacity regressions. Do not
raise the ceiling or reduce the approved pack merely to hide the defect.

Before production activation, compose actual Routes/Profile selection, finite
current work contacts, source-bound supports, exact terrain protections,
spatial Inventory/landing reservations, RoomOrders and paid phase companions.
The typed base refusals remain effective until each concrete path is complete.
Save/hash, occupied interruption, actual demo interaction, native presentation
and256-resident timing remain independent closure gates.


## Source-scan correction during integration

The initial composition loop used `source_refusal` and `source_revision` once
per retained source. Each performed a source-capacity lookup, creating hidden
quadratic lookup work. The accepted SpaceOwner read-only
`snapshot_revision_refusal(expected_revision)` instead checks the unchanged
live geometry revision and revalidates all actual sources/claims in one finite
scan, without copying a second snapshot. Before the first snapshot, composition
charges3×(R+O)=24576 scan checks for the initial validation/copy and the final
validation. Exact clipping and fragment operations consume the remaining domain
allowance. Existing short-lived actual typed getter results are still native
cold-operation allocations; this change does not call that transitive path
allocation-free or claim a measured frame-time budget.


Independent review then found a second repeated lookup inside Terrain: reading
the World source revision per tile in both passes becomes O(tiles×sources) when
a valid save places World in a later source row. Terrain now pins that revision
once for both passes and checks it again at completion. Composition additionally
charges10O fixed World lookups and16 probes per queried terrain tile (both
passes) before its first snapshot. The finite map/query range bounds the count.
A real restore moves World to source row2047; a512-tile query asserts at most
ten World lookups. These are bounded logical probes, not instruction timings.

Review also found that an allocating source callback could release or replace
the original Budget token. Composition now rechecks that exact lease after the
sparse snapshot, after Terrain, and after final source validation, before output
publication. Six adversarial release/reacquire cases prove fail-closed cleanup
and no output-copy entry after early expiry. A new equally funded token is not
the original operation. The real caller still retains the successful output
lease until consumption; these checks do not transfer that responsibility.

Final focused iteration3: WorldBindings19 tests/373 assertions; Terrain17/340;
zero failures, strict/raw unexpected diagnostics and object/resource leaks;
zero expected/tolerated diagnostics. Analyzer0 warnings across4 changed files.
The first iteration stopped at the correctly enforced missing registry section
before any tests ran; its logs are retained. Iteration2 passed the earlier
source but predates the independent corrections. No component run is reported
as another full assembled suite or as productive excavation qualification.

Independent narrow re-review accepted all four iteration3 source pins, the two
MEDIUM corrections and their regressions with no remaining high/medium finding.
All34 current Specification contracts CI commands also passed; raw per-command
evidence is retained under the component evidence directory.
