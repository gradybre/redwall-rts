# 1082 — Source-bound finite underground terrain

Date: 2026-10-03 · Status: accepted terrain component; integrated runtime qualification open

## Decision

The room preview is painted directly on the selected-level dirt (D29). Its
placement checks and the workers' checks must use the same real world. Add
`underground_terrain.gd`, bound to the actual `WorldInit`, its actual
`ResourceNodes`, actual `CoreSources`/`SpaceOwner`, Buildings, loaded item
catalog and shared decision1072 Budget. Matching reference numbers in another
owner are insufficient. This module neither allocates a Room nor changes paid
excavation, inventory, support, routes or construction state.

Decision1058 explicitly assigns finite extents and support/contact authoring to
engineering. The following is new finite estuary content, not a claim that GDD
surface tiles already specified underground geology or that the previous demo's
level count is adopted:

- The economic datum is `(0,512,0)`, the actual `WorldInit` LAND height. The
  surveyed X/Z rectangle is the existing 256m by256m estuary. Base matter is
  authored down to datum minus32m; exterior survey stops at datum plus16m.
  Queries outside this finite pack or its bound SpaceOwner domain refuse. This
  sets neither main-floor spacing nor a number of player levels.
- LAND has dry solid below512u and exterior free space above it. The natural
  ford has its actual floor at−128u, dry substrate below and the actual shallow
  water interval from−128u to0u. Other water tiles carry an excavation exclusion
  down to the pack bottom. That conservative protected column is not a measured
  swimming/diving depth or a new traversal permission.
- Natural floor datum metadata does not grant support, a route or paid void.
  Natural-ground support can be queried over an exact dry footing. Do not stamp
  protected SUPPORT across the whole map: RoomSpace treats SUPPORT as an
  obstruction, which would make the first entrance impossible. WorldBindings
  retains protected footing only where a real contact or structure requires it,
  outside the requested cut and with the correct lifetime.
- Actual resource nodes are resolved through the loaded item catalog's wood,
  stone and iron keys. Authored protection uses each actual2m tile: live trees
  have1m roots and8m upper extent; renewable exhausted stumps retain roots and
  a0.25m upper extent. Stone/iron deposits protect4m below and1m above the land
  datum while stock remains. An exhausted nonrenewable node contributes no
  resource obstacle. These are conservative excavation/contact exclusions, not
  mesh bounds, ore yield or resource-generation rules.
- Every actual Building reserves an explicit foundation depth keyed by its
  real catalog entry and rotated footprint. Paths use64/128u, lightly founded
  open sites512u, ordinary structures1024u, the standalone cellar4096u and
  well8192u. These authored protected foundations are not free excavations.
  Aboveground body shape without a qualified structural source remains a
  protected site up to the existing maximum-Y brief, not an invented opaque
  model or usable interior. Open stockpiles and paths receive no opaque upper
  cube; actual goods and storage contacts remain Inventory/Locations truth.
  Enclosed-building contacts must approach from outside or use their separately
  qualified structure source. No source geometry is inferred from a maximum
  visual height. Blueprint/unfinished foundations are also protected.

## Publication and freshness

`survey_into` clips exact half-open integer boxes to the requested bounds. It
uses a bounded count pass before output allocation and requires a token from
the exact configured shared Budget covering its caller-owned output. Any
refusal clears the output, so a prior successful survey cannot be mistaken for
current truth. The caller retains that lease while consuming the output.

Natural/resource rows carry the actual bound World reference and nonzero
SpaceOwner source revision. Building rows require the actual registered
Building source and current revision; absence refuses rather than guessing1.
Source facts, terrain kind, full resource references/quantity/regrowth and
Building identity are re-read. Resource overlays are live derived observations,
not permanent immutable World matter. Allocation-free local queries check a
bounded footprint at productive contact time; they never replace paid-space,
profile, occupancy, Inventory or connectivity validation.

WorldBindings owns composition: introduce previously unknown base matter only
after exact subtraction of retained paid/unfinished geometry. Never refill a
paid room with base soil, replace a room's owner, or use original dry substrate
as proof that a footing still exists after excavation. Refresh live resource
and building exclusions at cold admission and immediately before productive
work. A terrain query alone grants no action.

## Ownership and accounting

Root owns the new module/test and narrow allocation-free WorldInit/ResourceNodes
readers. UG07 owns the separately reviewed Buildings identity reader; UG21 owns
WorldBindings, sparse publication, Locations and Routes. Other checkouts and
Claude's master are untouched. The full integration checkpoint e267eaec ran while this branch developed
independently; its legacy save-test mismatch and focused correction are recorded
in decision1084. It did not qualify this later terrain implementation.

No dense depth/tile store or persistent simulation field is added. The eight packed columns total372 bytes: three six-I32 domain/query boxes
(72), two30-I32 catalog arrays(240), three resource IDs(12), four Building facts
(16), and four-I64 resource facts(32). Four scalar integers, two full refs, one
boolean and the reused IntResult add58 logical numeric bytes. These430 bytes
fit inside decision1072's existing131072-byte terrain reservation. Fixed content
Dictionary/native handles and initialization copy peaks still require measured
qualification; no claim of430 bytes of actual RAM is made. Survey output costs48 bytes per row plus bounded
transient controls and is charged to the existing shared cold arena before
allocation. Native overhead remains subject to final measured qualification.
The actual World/save must pin this content revision; base terrain is derived
from WorldInit plus that content, not serialized as a second voxel world.

## Focused validation and remaining qualification

The corrected focused run used assets-aside cleanup, deleted this checkout's
`.godot`, a clean `godot --headless --path godot --editor --quit` import, and
strict singleton selections through the unchanged runner gates. Each emitted
both exact zero diagnostics and raw-log leak footers:

```text
15 test(s), 302 assertion(s), 0 failure(s)
122 test(s), 18192 assertion(s), 0 failure(s)
39 test(s), 637 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

The suites cover Terrain, existing WorldInit and existing ResourceNodes. Terrain
exercises the real generated estuary and ford; exact dry/water clipping;
finite/negative bounds; wrong actual owners; resource exhaustion, regrowth,
retirement and stale generations; rotated unfinished Buildings; open stockpiles;
source revision changes; output/lease refusal; and preserved paid space. These
are component tests, not proof of complete construction or 256-resident timing.

The first attempt retained four failures caused by test fixtures passing an
invalid planted day0 to the existing ResourceNodes API, which requires day1 or
later. All five fixture creation calls now use day1; production code did not
change. Rejected and corrected raw logs are retained in
`docs/validation/evidence/underground-terrain-2026-10-03/`. The first run stopped
before the strict raw-log footer because its assertions failed. A mistaken
Python unittest module invocation is also retained; the documented standalone
entry points then passed190 capacity-audit checks and13 joint-budget tests.

Source-derived capacity and budget artifacts retain the existing reservations:
4,962,389 new mutable/reserved bytes and99,955,154 total logical bytes including
the prior reserve, with44,846 headroom. These figures are allocation admission,
not a native memory measurement. Independent construction-agent source review matched all four final source
pins, reviewed the full module, both narrow readers and all15 tests, and found
no high/medium correctness issue. The whole hot path still reads the actual
SpaceOwner source; allocation-free leaf readers alone are no performance proof.
The full integrated run and playable-room, movement, save and native performance
gates remain open.
