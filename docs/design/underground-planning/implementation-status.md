# Underground implementation status

## Current delivery status — 2026-10-05

The owned integration checkpoint is **`53541c91`**, queued for publication in
[draft PR #230](https://github.com/gradybre/redwall-rts/pull/230).
Players can open **Plan an underground room** from the demo Tunnels panel,
choose a room purpose and floor, and draw directly on the actual World's dirt.
The view retains its draft on close, restores the village camera, and preserves
modal input ownership and original World identity. It deliberately refuses
confirmation when completed access is missing, without spending resources.
**The first worker-built empty Kitchen is not complete.**

The [scene acceptance](../../validation/evidence/underground-planning-scene-2026-10-05/README.md)
passes **30 focused tests / 1,132 assertions / zero failures**, with zero
unexpected diagnostics or leaks and analyzer **0/6**. Its native Metal/Forward+
run passes **74 checks / zero failures**, with five inspected 1280×720 captures.
Independent review verified the corrected modal, keyboard-focus and actual
World-reset paths. The frozen8f checkpoint's clean-assets/cache/import,
**no-argument full suite**, all-file zero-warning analyzer and registry/memory
checks are running in an isolated frozen checkout. Their result is pending.

The latest8f remote run completed410 suites exactly once:11,282 tests /
1,082,433 assertions /3 failures, all in the stale exported-profile verifier.
Unexpected diagnostics and leaks remain zero; analyzer passes0/1264. The separate
contract job timed out before all checks ran. Reviewed corrections318a61d0 and
53541c91 preserve every check, give contracts sufficient time, and retain the
actual tenth published Script in the export verifier. The correction passes
12 focused tests/249 assertions/all-zero with analyzer0/1. A corrected remote run
is pending. This failed run remains recorded.

The [previously completed successful remote CI](../../validation/evidence/underground-short-step-itinerary-2026-10-05/ci-ca1edc3f/README.md)
was at `ca1edc3f`: all 14 jobs passed on attempt 2, with 406 files exactly once,
11,226 tests / 1,028,131 assertions / zero failures and zero unexpected
diagnostics/leaks. Its local suite had ten more assertions; exact parity is
not claimed. The local analyzer's raw editor errors were retained and led to
the reviewed preload and analyzer-lifetime fixes now integrated. That older CI
result does not certify the current source.

The queue still has **10 verified component lanes, 5 running and 9 queued**, with
all **107 requirements** mapped. These are dependency counts, not a percentage
of the finished player experience. The remaining major work is:

- Complete real timber handling, fastening, paid entrance construction, worker
  dispatch and the first empty Kitchen using actual settlement goods and workers.
- Finish room-specific furniture placement, both confirmation modes and services.
- Complete deeper access, the connector catalog and raised/sunken room sections.
- Finish live amendments, removal/backfill/replacement, relocation and renovation.
- Integrate deterministic save/resume, full visual/input acceptance and measured
  256-resident qualification.

Current parallel owners are developing the stationary timber source/contact
integration, its paid handling lifecycle, and original Session entry-owner composition. Actor image loading is reviewed at
`f14ba6b6`, awaiting the shared source-publication renewal before integration. The integration owner handles the
shared demo workflow, source publication and full checkpoints. Wood-only stairs
and the approved 30 ticks per tread / 45 ticks per half-turn remain unchanged.
Logical memory accounting is 99,999,806 bytes; measured native memory and target
hardware performance remain open. The durable [queue](../../tasks/underground-build-queue.json)
records ownership, exact evidence and blockers. No standalone module closes a
playable requirement.

## Earlier implementation checkpoints

The following retained snapshots describe their cited revisions. Statements
such as “current” or “running” below are historical; the delivery status above
and the queue are the current record.

[CI checkpoint6da6deb9](../../validation/evidence/underground-host-checkpoint-2026-10-04/ci-6da6deb9/README.md)
passed all14 jobs in14m44s:402 suite files exactly once across8 shards,
11156 tests/1026355 assertions/zero failures,272 expected/353 tolerated
diagnostics, zero unexpected diagnostics/leaks, and analyzer0/1243. The matching
[clean-import/no-argument full local run](../../validation/evidence/underground-host-checkpoint-2026-10-04/full-6da6deb9/README.md)
passed11,156 tests/1,026,365 assertions with identical402files, named test cases
and all diagnostic/leak totals; analyzer0/1243. Local assertions are10 higher
than CI, unattributed; strict all-counter equality is not claimed. The preceding
ebdd5daa full local and CI runs both failed nine stale support-clearance fixture
tests; those original failures are retained, and their independently reviewed
fixture correction is in6da6deb9. No diagnostic gate was weakened.

Current integration `9dad696d` adds the actual Room-owner constructor, atomic
frontier contacts, source-compatible mixed-profile itineraries and ground-only
pace content. Its reviewed worker publication keeps all v3 geometry and timing
unchanged while renewing three exact consumer hashes. The fresh native replay
passes 1,504 poses / 469,248 exact matrix scalar comparisons / 9,336 assertions;
it uses a synthetic physical provider and does not qualify a completed Room.

The ten focused integrated suites pass **169 tests / 18,457 assertions / zero
failures**, with every strict/raw diagnostic and leak counter zero and analyzer
**0/29**. Sources, HEAD, assets, project, registry and import sidecars are restored.
The old actual-composition refusal at8003bfe1 remains recorded. The exact9dad
clean-assets/cache/import/no-argument full suite and full analyzer are running
in the frozen own renewal checkout; the older6da results above do not certify
these newer sources.

CI at9dad completed with two stale frontier-test expectations after the source
renewal:11,207 tests/1,027,796 assertions/2 failures;0 unexpected diagnostics
or leaks,272 expected/353 tolerated. The analyzer passes0/1,250 and all other
seven shards/gates pass. The independently reviewed test-only correction
passes37 tests/1,149 assertions/all-zero and analyzer0/3. The failed run and
correction are both retained; a later green full checkpoint is still required.

The current joint memory adapter replays reviewed1161/1163/1165/1166 lifetimes,
checks51 current modules and pins all executable witnesses before replay.
Independent review caught a missing Movement callee pin; the fixed checker
passes all246 tests and rejects that exact new-allocation mutation. Logical
allocation remains99,999,806 bytes/headroom194; native measurement stays open.

Parallel work now composes the actual ground route owners and implements the
finite232u source programme on canonical runtime clocks. The latter's component
tests pass122/15,535/all-zero, while its actual ground-only reach check, complete
census, native replay and production publication remain in progress. Neither
source packets nor standalone modules close playable requirements.

The complete modular building workflow is still in development. The queue has
10 verified component lanes, 5 running lanes and 9 queued lanes, covering107
requirements. These counts are not a completion percentage: substantial demo
integration, persistence and qualification remain. The next playable checkpoint
is drawing on the dirt, confirming the plan, watching actual workers deliver
materials and excavate, and obtaining an empty Kitchen ready to furnish.

After that checkpoint, the remaining work includes the room-specific furniture
workflow; deeper levels and the full connection catalog; live amendments,
removal/backfill/replacement, relocation and renovation; composed save/resume;
and native1280×720 and256-resident acceptance. The wood-only stair decision is
unchanged. The first supported stair source sequence and its native witness are
reviewed, while actual paid route bindings and wider connector coverage
remain open. Ground walking profiles do not fit the first tread.

An earlier accepted full local checkpoint is
[`9ca21351`](evidence/modular-build/checkpoint-9ca21351/README.md):
10,941 tests / 1,016,692 assertions / 0 failures, zero unexpected diagnostics
and leaks, and zero analyzer warnings across 1,220 files. The clean import,
no-argument full suite, restoration and unchanged source checks passed in an
isolated own worktree while implementation continued independently.
[Remote CI at1eb7a64d](../../validation/evidence/underground-ci-1eb7a64d-2026-10-04/README.md)
passed all14 jobs in13m10s:391 files exactly once across8 shards,10,941 tests,
1,016,683 assertions and identical diagnostic/leak totals. These are different
commits; exact assertion equivalence is not claimed. The import warning found
locally at1eb7a64d and the failed child-marker correction are retained.

The newer [CI checkpoint a52ea73f](../../validation/evidence/underground-ci-a52ea73f-2026-10-04/README.md)
passed all 14 jobs in **13m49s**: 394 test files exactly once, **10,973 tests /
1,019,025 assertions / zero failures**, zero unexpected diagnostics/leaks, and
zero analyzer warnings across 1,225 files. It covers the Session, host equipment
and Clock increments, before the later ordinary Room publication work.

The subsequent CI at `f44efa7d` failed seven older entry-claim fixture assertions;
all other jobs passed and the aggregate correctly failed. The fixture injected
a non-flat batch beneath flat-room admission, which the new production guard
correctly refuses. The independently reviewed test correction at `fbc2281a`
uses actual entry admission, preserves all production guards and adds the
flat/non-flat bypass refusal. Its strict four-suite run passed83 tests/3,460
assertions, zero diagnostics/leaks and analyzer0/8.

The subsequent [b03fbc2b CI checkpoint](../../validation/evidence/underground-host-checkpoint-2026-10-04/ci-b03fbc2b/README.md)
passed all eight strict shards:396 files exactly once,11,000 tests/1,019,572
assertions, zero failures and zero unexpected diagnostics/leaks. Its overall
result is failed because the unchanged analyzer found12 warnings in six archived
rejected capture sources. Those exact historical bytes are now compressed as
data; active/v7 sources and all diagnostic gates remain unchanged. The full
local same-head no-argument suite passed11,000 tests/1,019,580 assertions with
the same272 expected/353 tolerated diagnostics and zero unexpected diagnostics
or leaks. The completed local analyzer reports the same12 historical-source
warnings; source and HEAD stayed unchanged and assets/project were restored.
The [retained full-run record](../../validation/evidence/underground-host-checkpoint-2026-10-04/full-b03fbc2b/README.md)
therefore records a failed complete checkpoint. Test and diagnostic
totals match CI; the local assertion total is8 higher and that difference remains
unattributed. The unchanged all-counter comparator correctly refuses equality.
The earlier green CI is not evidence for these later changes.

The concrete ordinary Room publication tail is accepted at `9a8e353f`, with
independent review `8dd07e6f`; broad tests passed 389 / 17,880 and the final
type-parity delta 69 / 2,568, with zero unexpected diagnostics/leaks and analyzer
0/11. Ordinary Room approach is now independently accepted and integrated at
`3726f088`, with review `5ad7644c`: exact completed access, full profile/source
identity and static final terrain checks precede admission. Seven integrated
suites passed134 tests/3,771 assertions with zero diagnostics/leaks. The source
census stays within existing limits and225 shared memory checks passed. This
component uses synthetic initial corridor/profile fixtures; actual source
composition and playable construction remain open.

The subsequent whole-project analyzer found one integration issue across1,231
files: EntryBindings repeated the identical WorldRoutes preload now inherited
from RoomBindings. An independently reviewed one-line deletion fixes it without
changing behavior or guards. Three affected suites passed101 tests/14,819
assertions with every diagnostic/leak count zero; affected analyzer0/3 and host
analyzer0/8 passed. The rejected whole scan and correction evidence are both
retained. The [complete remote gate at256c1908](../../validation/evidence/underground-host-checkpoint-2026-10-04/ci-256c1908/README.md)
then passed all14 jobs:397 files exactly once,11,027 tests/1,020,358 assertions,
zero failures or unexpected diagnostics/leaks, and analyzer0/1,231. Wall time
was16m24s. The independently reviewed timing-only refresh replaces the old
240-suite measurements with all397, estimating more even assignments; the next
run must measure that improvement. Test/gate behavior is unchanged.

The [next complete run at84acf740](../../validation/evidence/underground-host-checkpoint-2026-10-04/ci-84acf740/README.md)
passed all14 jobs in13m23s, meeting the15-minute target. The unchanged verifier
confirms398 suites exactly once,11,043 tests/1,021,242 assertions, zero failures,
zero unexpected diagnostics/leaks,272 expected and353 tolerated diagnostics;
the full analyzer reports0/1,232. The same-head clean no-argument local run now
passes11,043 tests/1,021,246 assertions, the identical272 expected/353 tolerated
diagnostics and zero unexpected diagnostics/leaks; analyzer0/1,232. Source/HEAD
stayed unchanged and project/assets were restored. The suite took30m09s locally.
All398 files, test counts and diagnostic totals match CI. Local assertions are4
higher and remain unattributed; the unchanged all-counter comparator correctly
refuses exact equality. The retained same-head comparison states that limit.

Ordinary phase refresh1153 is now integrated at386cd4aa after independent
review and one corrected initialization guard. Actual paid component fixtures
preserve the original Site/Project/Room identities and refresh all existing
endpoints/routes/opening-source pins through one existing context. Ordinary
painted Tunnel is distinguished from Entry by actual Placement ownership,
not Room purpose. Author tests passed173/17,943/all-zero with analyzer0/5;
the integrated phase/Location/Approach/host regression passed122/3,688/all-zero
with analyzer0/8. Source, registry, project and assets were restored. There is
no retained allocation increase. These fixtures do not close the concrete1152
provider, surface-entry bootstrap or playable construction requirements.

The previous full local checkpoint is
[`32db348a`](evidence/modular-build/checkpoint-32db348a/README.md):
10,895 tests /998,370 assertions /0 failures, zero unexpected diagnostics and
leaks, and zero analyzer warnings across1,210 scripts. The exact clean-assets,
cache removal, import and no-argument procedure passed with source and HEAD
unchanged and assets restored. All34 Specification commands passed too.
[Remote CI37208054867](../../validation/evidence/underground-ci-32db348a-2026-10-04/README.md)
passed all14 jobs in11 minutes34 seconds. All388 files ran exactly once across
8 shards;10,895 passed test cases and every diagnostic/leak total match the
same-head full run. Assertions differ by11; the unchanged all-counter verifier
refuses exact equality, and that difference remains explicitly unattributed.
The earlier rejected source-closure/stale-test runs remain recorded in the
queue and their evidence. No source guard or diagnostic allowance was weakened.

The next [remote CI checkpoint42bff090](../../validation/evidence/underground-ci-42bff090-2026-10-04/README.md)
passed all14 jobs in12 minutes57 seconds:389 files exactly once across8 shards,
10,910 tests /1,002,786 assertions /0 failures, zero unexpected diagnostics/leaks,
and analyzer0/1,213. No same-head local full run was made, so this is not an exact
local/CI equivalence claim.

UG24 extracts the actual demo composition work so it runs independently of the
remaining movement sources. Its reviewed confirmation adapter has35 focused
tests/480 assertions, strict/raw diagnostics/leaks0 and analyzer0/4. It preserves
actual purpose, floor and draft identity across callbacks and owner teardown.
The real Session foundation composer is independently reviewed and integrated,
and SettlementSystem now owns one actual Gear and HaulCarry pair without
duplicating bootstrap tools. The shared host regression passed313 tests/7,944
assertions with zero unexpected diagnostics/leaks and analyzer0/4. Actual scene
mounting and foundation reset/remount are now integrated at `3f898b35` after
independent review:287 tests/7,038 assertions, zero unexpected diagnostics/leaks,
analyzer0/8, and14 successful real-demo headless boot/restart checks. UI Create
reuses the existing World's staging banks. The two boots emitted44 recorded
missing-asset/audio warnings; this is lifecycle evidence, not visual acceptance.
Operational teardown, fixed-tick dispatch and successful Room entry/phase remain
open. Current parallel work composes ordinary paid phases, D11 suggested/editable
entrance selection in the real room editor, and the actual WALK-to-WORK source
transition. The complete published work pose fits the virgin face, but the
current walking/tool envelope reaches into its uncut wall; no positive paid
workflow may bypass that refusal. Geometry is implementing explicit source-clocked approach and backstep policies
from unchanged walk and ready keys. Its wood-handling proposal is
deferred behind this playable dependency. The shared spatial refresh is
integrated; actual wood-handling runtime integration remains separate.
The access UI is independently accepted and integrated at`dc6baa12` after
correcting a late view-teardown error and player-facing implementation text.
The selected affected suites pass60 tests/1,260 assertions with zero diagnostics
or leaks and analyzer0/6. Root independently checked all frozen source/result
pins, replayed eight Python guards and inspected the native1280×720 states.
Native3 has15 assertions, zero failures/diagnostics/leaks and analyzer0/1. Its
plain dirt and synthetic physical/profile fixture do not qualify installed game
content or the full HUD. The populated graph/maximum-paint candidate took69.176ms,
so the1.5ms UI target remains failed and maximum-source-population/0.25s overload
qualification stays open. The clean integrated four-suite check also passes60 tests/1,260 assertions,
all strict/raw diagnostics/leaks0 and analyzer0/6, with every original source,
project and asset state restored.
Geometry's next increment advances work-approach readiness on actual30Hz Routes
state; rendering only samples that state. Source-policy tagging preserves
ordinary route semantics and must pass headless/replay tests. The full actual
walk-in/work/recovery/back-out sequence remains the playable dependency.
Decision1155 is now released to the editor agent for independent implementation
of actual whole-World retirement and safe remount leaves; root retains Session
and host composition. This proceeds alongside movement and paid phases.
The added lane decomposes existing work and does not add or waive requirements.

Decision1140's actual Delivery component is integrated at`fa017ba4`, using
Decision1141's guarded Inventory/Reservations journal. The clean-import focused
integrated run passes124 tests/13,838 assertions, zero strict/raw diagnostics
and leaks, and zero analyzer warnings across6 files. Actual wood shipments fund
the first paid installation in its real-owner fixture. Production hauling
motion/contact sources remain open; that fixture's handling profiles are
explicitly synthetic. The reviewed accounting at`42bff090` includes the new
4,096-byte allowance: live plus reserve99,998,782, leaving1,218 bytes under the
unchanged100 MB ceiling. All193 adversarial memory checks pass; native memory
remains unqualified. See the
[integrated packet](../../validation/evidence/underground-delivery-memory-2026-10-04/README.md).

Decision1142's native stair witness is integrated at`fa7e556f` after independent
source, event and image review:3,795 poses/125,652 assertions/0 failures,12 joins
and93 PNGs at1280×720. This is an OpenGL witness on an unpaid test fixture;
paid traversal, Metal, gameplay timing, saves and whole-client qualification
remain open. The
[review](../../validation/evidence/underground-stair-native-review-2026-10-04/README.md)
retains those boundaries. Decision1143's source-only motion reader is independently accepted and integrated
at874e2f12. Its shared Profile/Level/Motion accounting stays232,436 inside the
unchanged262,144-byte reservation. The actual integrated focused run passed58
tests/14,678 assertions with zero strict/raw diagnostics/leaks and analyzer0/2.
Decision1144's static grip, lift/place and loaded gait source packets passed
independent review. The native sampled-input packet is integrated at `bea41615`:
7,068 samples/21,251 assertions/0 failures,16 Python tests, zero raw diagnostics
or leaks, and analyzer0/1. An independent reviewer reproduced the compiler,
full-vertex/contact verifier and census exactly. GPU/all-Q16 qualification,
runtime profile selection, distinct worker/service stations, real loaded
delivery, loaded turns and loaded stairs remain open.
Decision1145 and DEC-050 record Brendan's approved Natural initial stair pace:
30 fixed ticks per tread and45 per supported half-turn at1× for the first
unloaded adult mole with its existing pick. Source and paid-route qualification
still precede playback; this ruling does not adopt loaded or other-cast timing.
Decision1147's stateless source sampler is now integrated with29 focused
tests/15,761 assertions, zero diagnostics/leaks and analyzer0/2. The corrected
shared memory census passed225 tests and independent review, retaining the
unchanged global budget. Session adds its counted1,536-byte wrapper inside the
existing Profile/Level/Motion reserve; their joint total is233,972/262,144.

Decision1135's independently reviewed spatial component is integrated at
`84948b40`:404 selected tests /29,732 assertions /0 failures, zero unexpected
diagnostics/leaks and zero warnings across10 files. It preserves worker
occupancy, paid publication and refund safety. Decision1134’s paid workpiece component is now integrated at`b518ca1f`;
its final affected suite passed23 tests/1,522 assertions with zero strict/raw
diagnostics, leaks and analyzer warnings. Actual material hauling, the
composed playable lifecycle and the next full checkpoint remain open. Component evidence and
rejected attempts are retained in the
[workpiece spatial packet](../../validation/evidence/underground-workpiece-spatial-2026-10-04/README.md).

## Concurrent full-build continuation

Brendan subsequently authorized concurrent subagents and automatic release of
dependent work until all approved scope is built. The integration now continues
on `codex/underground-modular-integration`; see the
[build queue](../../tasks/underground-modular-build.md) for current
ownership, dependencies and evidence. The reviewed components now include
canonical footprints, direct dirt painting, fitted room surfaces, permanent
room purposes, furniture layouts, paid physical excavation, actual finite
terrain, sparse retained geometry, atomic room confirmation and native actor
presentation. D29 clarifies that the player paints the footprint on the dirt
in its actual selected level, never on a separate drawing canvas. The
[native 1280×720 component capture](evidence/modular-build/world/direct_dirt_room_plan_1280x720.png)
shows that interaction; ordinary village activation remains in progress.

The earlier full frozen source `a33ff093` passed **10,405 tests / 958,819
assertions / zero failures**, with zero unexpected diagnostics or leaks and
zero analyzer warnings across1,157 scripts. The
[checkpoint logs](evidence/modular-build/checkpoint-a33ff093/README.md)
record the exact clean-assets/cache/import and no-argument suite procedure;
source and HEAD stayed unchanged and the original assets state was restored:

```text
10405 test(s), 958819 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 1157 file(s)
```

This checkpoint includes actual natural surface anchors, World-owned Locations,
unique immutable billable connector assemblies, final actual-source/work-face
checks and the reconciled logical memory census. It does not create a paid
entrance or qualify an actual complete worker construction sequence.

[Remote run37152867094](https://github.com/gradybre/redwall-rts/actions/runs/37152867094)
passed all eight suite shards and four Godot gates but failed Specification
because a generated capacity report retained an old source hash and resize-line
number. The final aggregate correctly failed. The reviewed provenance-only
correction is integrated at`d20f4678`; all34 Specification workflow commands and
the additional9-case ledger regression passed at`e9d52293` in the
[corrected checkpoint](../../validation/evidence/underground-spec-e9d52293/README.md).
Neither local correction retroactively changes that remote result.

Subsequently integrated source-local mole motion proof`c62d6236` includes the
actual rendered loop boundary, forward/reverse transitions, real tool contact
and native sampling evidence. Exact WORK selection`e134818f` lets distinct
contact sources share the same worker/tool/BUILD key without silently taking
the first file row. Its25 tests/601 assertions, strict diagnostic/leak guards
and two-file analyzer passed. The ordinary ambiguous query refuses; committed
Routes consumers subsequently integrated at`10585921` preserve the exact
selected WORK profile and content revision. Neither component constitutes
production profile or first-entry qualification.

Independent review found and corrected a late Inventory callback after the
proposed final START guard. The accepted Funding/Reservations boundary at
`e40a55a3` runs the final check after actual Inventory staging and before commit,
and refuses reentrant claim metadata edits in that same transaction. Its148
tests/12,554 assertions passed with zero strict/raw diagnostics or leaks and
zero analyzer warnings across seven files. Two temporary identity controls
consume16 logical bytes in the existing binding reserve; the reviewed census
has44 passing Python tests. Actual paid connector installation remains open.

The subsequent [remote CI checkpoint at1f5b1e4d](../../validation/evidence/underground-ci-1f5b1e4d/README.md)
passed every gate:360 suite files exactly once across eight shards,10,387 tests,
958,137 assertions, zero failures,272 expected and353 tolerated diagnostics,
zero unexpected diagnostics/leaks, and zero analyzer warnings across1,156
scripts. The complete workflow took9 minutes26 seconds. This remote source was
not compared with a same-head full-run baseline. The later local combined
checkpoint at`a33ff093` passed the clean no-argument procedure above; the new
1107 entry-claim work remains outside that checkpoint.

The reviewed entry-claim component at`f914a55d` now maps overlapping,
varying-height entry prisms to unique physical cut keys without adding a second
excavation ledger. Independent review reproduced and corrected a repeated
Domain callback that could reserve the wrong map cell on both entry and flat
room paths. The final focused run passed119 tests/28,414 assertions, all strict
and raw unexpected diagnostics/leaks zero, and zero warnings across five files.
[Exact source, rejected reproducer and final logs](../../validation/evidence/underground-entry-claims-2026-10-03/README.md)
are retained. Future Corridor/Placement atomic confirmation and physical entry
construction remain open; this later component is outside the a33 full run.

The source-local upper-wall worker increment at`a33ff093` also passed independent
source and native visual review:537 poses/1,283 assertions, seven Python checks
and zero analyzer warnings. Its production qualification remains false. The
complete animation state transitions, idle/travel envelopes and actual support
must still be proved. The current downward stance cannot fit a512u tread, and
a landing cut must not remove the worker's only footing or retreat. The
construction and motion lanes are resolving that real first-entry sequence.

Brendan approved wood-only timber stair assemblies: 1 U of wood and 12 WU per
tread including bearer/joinery, 4 U and 32 WU per 2×2 m landing. The current
20-tread/six-landing candidate totals 44 U wood and 432 WU, with no rope.
[Decision1101](../../decisions/1101-first-paid-surface-entry.md) separates that
approved balance from the still-required paid excavation, structural geometry,
worker contact and route qualification.

The shell study proves boundary coverage and material scale, but its rounded
walls are visibly stepped. Organic silhouettes remain part of visual
qualification; a renderer-only change cannot cut through authoritative solid
corners or silently change usable room space. Front, side and rear native
inspection selected a firmer authored worker grip; its source-bound rebake
has passed native checks; physical contact/profile qualification remains in progress.

Active work derives unique physical cut claims, preserves existing circulation
during room confirmation, and resolves the actual first-entry/worker-contact
bootstrap. First entrance/connector construction and the first playable Kitchen
remain open.
Furniture/removal/renovation demo integration, composed save/resume, native
1280×720 end-to-end acceptance and256-resident qualification follow those gates.
These verified components do not complete D20 or make the full workflow
playable yet. The [draft implementation PR](https://github.com/gradybre/redwall-rts/pull/230)
and repository queue retain the remaining requirements. The evidence in the
following historical sections remains the prior PR229 baseline.

2026-10-02. Implementation authorized by Brendan's instruction to start
building this into the other work. Branch: `codex/underground-build-2026-10-02`.
Started at `origin/master` commit `223eb586`, including the merged hauling and
review fixes. Integrated `origin/master` at `82d60ba8` after PR #228 merged the
new route planner and kitchen-serving work. Only this Codex branch was rebased;
the other development checkout and its branches were not modified.

## First integration: review before ordering a room

The existing demo now has a real confirmation boundary:

1. Open Dig, choose Burrow home or Root cellar, and position the preview.
2. Click to hold its blueprint. Inspect the grid, outline, level, work estimate,
   spoil and proposed passage in the world and the right-hand review card.
3. Confirm / Enter revalidates and orders the existing excavation. Move /
   Backspace resumes positioning. Discard / Escape discards only the draft.
4. Existing workers excavate the accepted room; its existing fit-out becomes
   available after excavation. The blueprint adds no furniture orders.

Drafting leaves topology, materials and worker assignments untouched. A new
obstacle refuses confirmation. A changed automatic passage must be reviewed
again. If network capacity cannot accommodate the displayed passage, no room
is ordered in its place. A held room cannot silently change type or level.
The grid is clipped by the preview polygon and stays anchored at the demo's
existing positioning scale; it is not stretched with the mesh.

This is a foundation increment, **not completion of D20 or its first review
checkpoint**. Room painting, functional Kitchen/Bedroom rooms, material
installation and the new furnishing/removal lifecycle are not yet exposed.
The historical prototype's bracing, spoil, saving and service limitations
remain; this change does not qualify those owners as production-ready.

## Current-source refresh and implementation sequence

The earlier [review](../../reviews/2026-10-02-underground-building-review.md)
remains evidence against `d9941bd9`, not a claim about the new baseline.
The following dependencies were checked again at `223eb586`; the integration
at `82d60ba8` retains these owners and adds the route-performance changes:

| Current owner | Finding and next integration obligation |
| --- | --- |
| `demo/burrow/room_plan.gd`, `room_tool.gd` | Placement used an immediate click and a recomputed auto-passage. The confirmation increment addresses this; entrances are still template sockets. |
| `demo/burrow/underground_rooms.gd` | Shape, cells, fixture places and use are coupled to two templates. Introduce one canonical variable footprint consumed by placement, excavation, rendering, furnishing and route checks. A future paint-cell choice must not redefine ECON-001's physical cut lattice. |
| `demo/tunnel/underground_graph.gd` | Room work uses 24 template quanta; a segment timeline has 66 slots. Variable rooms need bounded storage and explicit capacity failures, not larger meshes over the same work ledger. |
| `demo/burrow/room_view.gd`, `room_mesh.gd` | Round/vault shells and staged growth are template-derived. Generate floor, wall, ceiling and openings from the same canonical boundary; verify concave shapes, stable material scale and no exposed undug floor. |
| `demo/burrow/room_fixtures.gd`, `fixture_crew.gd` | Post-dig placement correctly refuses an unfinished shell, but uses fixed places. Grid furnishing needs real equipment and access footprints, functional room eligibility and whole-room validity. |
| `demo/tunnel/tunnel_works.gd`, `tunnel_jobs.gd` | Existing demo work is not the adopted physical brace/cut/finish/backfill ledger. Integrate that ledger, delivered inputs, real spoil capacity, interruption and persistence before accepting the modular construction checkpoint. |
| `demo/tunnel/tunnel_control.gd`, movement amendment | Two demo levels and ramp/stair links exist. The full connector catalog and split-height sections need complete envelopes, protected landings and load/capability checks. Do not turn their existing demo dimensions into approved production constants. |

Continue in the already approved sequence: canonical footprint and matched
surfaces; shared passage/stair envelopes; paid excavation and finish stages;
typed empty Kitchen shell; safe project revision; then the Bedroom, furniture
modes, relocation, renovation and backfill/rebuild walkthrough. The numerical
and owner contracts must be recorded with each affected implementation. No
further approval of D01–D28 is being requested.

## Verification

The new adversarial tests cover draft purity, one-time submission, empty
completion, changed obstacles, changed auto-passages, type/level preservation,
connection-generation reuse, and allocation failure without a standalone
fallback. A discard/reposition check covers preview invalidation even when the
next pointer position is unchanged. The live harness uses real viewport clicks
and keys on the village at 1280×720.

The [held blueprint](evidence/room_blueprint_held_1280x720.png),
[accepted order](evidence/room_blueprint_confirmed_1280x720.png), and
[refused overlap](evidence/room_blueprint_refused_1280x720.png) are fresh runtime
captures on unstaged demo placeholders. See the [32 live checks](evidence/live-walkthrough.txt)
and [capture provenance](evidence/provenance.json). These show the confirmation
interaction, not final room art or completed modular construction.

The integrated complete no-argument suite passed **9,138 tests, 612,134
assertions, zero failures**, with **zero unexpected errors/warnings and zero
leaked objects/resources** (272 expected diagnostics; 353 tolerated notices).
The clean import and full run took 1,186.0 seconds locally. The integrated
analyzer reported **0 GDScript warnings in 1,028 files**.

See [full-run evidence](evidence/full-suite.txt), [analyzer output](evidence/gdscript-warnings.txt),
and the [14 passing CI checks](evidence/ci-checks.json) on runtime/test source
commit `92fcf82a`. Test and diagnostic totals match between the full local run
and CI; assertions differ by 11. [The comparison](evidence/validation-comparison.md)
records the platform-binding difference, the one unattributed assertion and
the exact match for the seven directly relevant suites. The work is in [draft PR #229](https://github.com/gradybre/redwall-rts/pull/229).

Historical screenshots in the initial review retain their original provenance
and are not new-build evidence.

## Checkpoint 2026-10-04: reviewed room-access CI complete

All 14 jobs at `d3e3dc7b` passed in **13m20s**. The unchanged independent verifier checked all 399 suite files exactly once: **11068 tests, 1022016 assertions, zero failures**; diagnostics **0 unexpected errors / 0 unexpected warnings, 272 expected, 353 tolerated; 0 leaked objects / 0 leaked resources**. Analyzer: **0 GDScript warning(s) in 0 of 1234 file(s)**. Evidence: `docs/validation/evidence/underground-host-checkpoint-2026-10-04/ci-d3e3dc7b/`.

The next paid ordinary-room candidate remains partial. Its next-source work readiness, actual approach/retreat and full paid positive are pending. Whole-room progression additionally requires scheduling each next reachable Site and publishing newly supported work access; one successful cube is insufficient. Operational World retirement is in concurrent development. No whole lane or requirement count is closed by this CI checkpoint.
