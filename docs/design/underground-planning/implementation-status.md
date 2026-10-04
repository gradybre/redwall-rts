# Underground implementation status

## Current delivery status — 2026-10-04

The complete modular building workflow is still in development. The queue has
10 verified component lanes, 4 running lanes and 9 queued lanes, covering107
requirements. These counts are not a completion percentage: substantial demo
integration, persistence and qualification remain. The next playable checkpoint
is drawing on the dirt, confirming the plan, watching actual workers deliver
materials and excavate, and obtaining an empty Kitchen ready to furnish.

After that checkpoint, the remaining work includes the room-specific furniture
workflow; deeper levels and the full connection catalog; live amendments,
removal/backfill/replacement, relocation and renovation; composed save/resume;
and native1280×720 and256-resident acceptance. The wood-only stair decision is
unchanged. A complete stair motion and safe return route still need source
qualification; ground walking profiles do not fit the first tread.

The latest accepted full local checkpoint is
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

Decision1141's guarded hauling component is integrated at`ee63d7b9` after
independent review and replay. Its final16 tests/603 assertions pass with zero
strict/raw diagnostics and leaks; the combined hauling/support focused analyzer
reports zero warnings across5 files. The separate3,072-byte logical reservation
brings the current source-counted pack to99,994,686 bytes, leaving5,314 bytes
below the unchanged100 MB ceiling. Runtime memory is unqualified, and the
Delivery contribution and stair programs are not silently included. Actual
Delivery lifecycle integration and complete stair motion/native evidence remain
in progress.

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
