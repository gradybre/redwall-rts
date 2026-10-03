# Underground implementation status

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

The latest full frozen source `3e891a41` passed **10,227 tests / 953,231
assertions / zero failures**, with zero unexpected diagnostics or leaks and
zero analyzer warnings across 1,140 scripts. The
[checkpoint logs](evidence/modular-build/checkpoint-3e891a41/README.md)
record the exact clean-assets/cache/import and no-argument suite procedure:

```text
10227 test(s), 953231 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

This includes full-size painted-room admission, packed footprint validation,
actual World structural phase observations and compact native actor content.
It also includes unique cut mapping, endpoint preservation, the static profile-edge
query and reviewed mole grip. Subsequent profile-path search and atomic
Room/Sites reservation retain separate focused evidence.

The subsequent pushed head `2f29ffd1` passed all remote CI gates in9minutes37seconds.
The strict aggregate verified355 suite files executed exactly once across8 shards:
10,249 tests,953,898 assertions,0 failures,0 unexpected errors/warnings and0
object/resource leaks; the analyzer reported0 warnings in1,141 scripts.
[Remote evidence](../../validation/evidence/underground-ci-2f29ffd1/README.md)
retains the exact merge/head identities and diagnostic totals. This later CI
run has no same-head local single-run comparison artifact and does not replace
the separately pinned local full checkpoint above.

The next integrated source increment adds final actual-source attestation and
solid work-face checks. The latter passed 58 tests / 2,124 assertions with zero
failures, unexpected diagnostics, leaks or analyzer warnings in its seven files;
[focused evidence](../../validation/evidence/underground-work-face-2026-10-03/README.md)
records the independent review and exact scope. Source and lease changes during
validation now refuse before a geometry image can be allocated or accepted.
These commits are newer than the remote CI checkpoint above.

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
