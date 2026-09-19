# Redwall resumption — current state and next work

2026-09-19 · Astra · Baseline `47a4da2642912afee4d5249424d31ab6c92f014a`.

Redwall has a substantial tested deterministic simulation foundation and a
responsive interface shell. It is **not yet a first playable settlement**.
The original checkout at `docs/executor-followup-rulings` is an older mixed
snapshot with 356 changed/untracked entries; it was preserved. The [file inventory](original_checkout_inventory.json) also checks materialized LFS assets against their pointer hashes: 248 apparent binary differences are the same integrated assets, not new art. Eleven local-only paths include historical/renumbered ADRs, archived Cycle3 review inputs, the preserved asset proposal, and the retired presentation pose scaffold. Work resumes in
`/Users/brendan/Developer/redwall-rts-loop-2026-09-19` from integrated master.

## Verified baseline

Godot 4.7.2: **4551 tests, 158103 assertions, zero test failures**. Fifteen
additional specification/queue/registry/movement checks passed. Test shutdown
reported 1882 leaked objects/33 retained resources in the suite process and
14 objects/3 resources in its boot process; these are unresolved findings, not
suppressed successful-shutdown claims. See [machine evidence](baseline.json)
and [raw evidence](../../validation/evidence/resumption-2026-09-19/).

An independent read-only probe loaded the actual main scene through normal
startup. It observed 12 residents, **0 buildings, 0 rooms, 0 furniture**, and
two different inventory instances. Displayed wood/berries/tools were
180000/40000/24000 milli-U; the simulation-owned inventory held zero of each.
The source confirms StockAge drives the latter. The first probe attempt used a
wrong accessor and was stopped; its log is retained. The corrected probe exited
successfully and is the evidence cited here.

The six implemented economic commands coexist with eighteen explicit unsupported
handlers. Standalone movement/navigation modules are present, but the running
settlement does not yet compose the travel→work→delivery loop. Building and
construction stores exist but their full jobs, commands and service integration
do not. Existing startup stock is real inventory data in a legacy owner, not a
properly built/stocked/accessible settlement.

The save effort has a strong registry and canonicalization foundation; the
[implementation matrix](../save_implementation_matrix.md) still identifies
missing section bodies, live adapters and the disk orchestrator. PR137 added
canonical inventory capture/restore primitives after that matrix's dated base;
it does not supply all six inventory-related owners or a full-world restore.

## Plans and reference material

GDD, UI, balance, architecture and setting amendments remain authoritative.
Settlement is the agreed release scope; battle and campaign layers are separate.
The [coverage matrix](../release_coverage_matrix.md) retains connected movement,
all construction methods, families/care, varied scenarios, food, community,
progression, persistence and final presentation/qualification.

The content library records its twelve available narratives, 7665 research
records and 1755 recipe/serving candidates; those records are not active game
catalog entries. Eulalia full text and the recorded Salamandastron source gap
remain unavailable. The approved world-finish concept was opened and reviewed
alongside retained UI evidence. DEC-039 already approves five relative height
anchors. Whole-body/gear/pose measurements and finished models remain distinct.
Only one imported mouse body is present in the integrated unit asset directory.

An untracked [creature-generation proposal](../creature_generation_batch.md) was
recovered unchanged from the original planning checkout. Its historical estimate
and model settings are proposals requiring fresh capability/pricing checks; they
are not a spending approval. No human art-approval record was edited.

## Decisions made and work remaining

[Cycle 4](../../rulings/2026-09-19_cycle04_resumption.md) answers the three current
advisories, resolves the UI visibility/input contradiction, and corrects the
attempt to reopen Q2-34/35. Seventeen explicit starter, planning, qualification and lifetime-repair task entries were added to the dispatch graph. The queue was reconciled with actually merged PRs
134/136/137/138 so finished lanes are not dispatched again. PR139's independent
review-packet refresh is preserved as an existing open PR.

The [starter contract](starter_settlement.md) gives the exact startup census,
lots, equipment, room layout, ownership, transaction and first-playable tests.
Its [API ownership map](starter_binding_manifest.json) records the current public interfaces and missing bindings. Its first runtime task is one inventory authority; it must not seed a second 24 tools
when equipping the existing cohort. Catalog mass arithmetic gives 179200g pantry
stock and 1500000g stored materials/equipment after 12 tools are equipped, within
the authored 200000g/1600000g aggregate capacities. This is capacity arithmetic,
not proof of room ownership, contact access or correct per-container placement.

Full Q2 physical/cost profiles, PC-03 finite scenarios, PC-04 family rules and
PC-06 progression interval still need complete authored execution packets.
Their omission remains explicit; the review and starter package do not pretend
to close all planning or to finish development.

## Execution boundary

Existing authorization covers ordinary development, independent review, PRs,
passing CI and merges. New expenses and human art acceptance remain separate.
The Claude Redwall session's latest completed message was waiting for this
Cycle 4 handoff. A new competing source executor was not started in its dirty
checkout. Claude work here uses the verified subscription-backed, no-tools
transport with bounded prompts/output, recorded process/session identity and
parent-reviewed file application. One model worker at a time reserves room for
the other existing sessions.

The installed loop controller's doctor reports `productionReady=false` and
`toolWorkersEnabled=false`. No unattended product service or schedule is active.
Native computer inspection was blocked because the Mac is locked; the unlock
request remains pending. Headless checks and repository work can continue.
No background-completion, native-playtest, Windows or minimum-hardware
qualification claim is made.


## First repair cycle

Capacity proof now allows the approved bounded addition grammar and refuses the
nested-resize/augmented-assignment counterexamples found by independent review.
The sidecar proves 470 equalities and 46 bounds; its 190 checks pass. The digest
name is corrected with sidecar schema 2, without an active save-schema change.

UI selection and workspace gates now track visible controls, including the
workspace search control, and context changes refresh keyboard wiring. Back
closes idempotently; a name editor without selected context refuses before
opening. The general visible-control/gate invariant covers the four specified
compositions. The old test's alleged outside point was inside the workspace;
its replacement asserts both the geometry and the open-world behavior.

The command-positive engine probe passes six cases: its instrumented world
handler adds one command through the real bridge/queue for open-world clicks,
and adds none for covered panels or Back. This is real headless event routing,
not a production world-router implementation, native pointer test or art review.

Inventory now borrows StockAge's seed predicate weakly. Releasing the two owners
reclaims both; an expired borrowed authority refuses consumption instead of
silently becoming unbound. The isolated boot/lifetime probe no longer prints
shutdown leak warnings. The full suite retains other leaks; those remain open.

The independent review and its bounded follow-up, raw intermediate failures,
accepted test results and worker recovery history are retained in the evidence
folder. No intermediate failure log is presented as a passing result.

Final local repair acceptance: **4574 tests,159269 assertions,0 failures**,15static checks passed,190capacity checks passed. Suite shutdown remains553objects/33resources (down from1882/33); the autoload boot process now exits without the old14object/3resource warnings. These are bounded repair results, not first-playable or release acceptance.

Repair PR [#140](https://github.com/gradybre/redwall-rts/pull/140) merged at `5ea810e15150bec509aa5d9eca5faa15bb441a87` after both GitHub checks passed on head `49901b7`. Its four queue entries are now reconciled as done for their bounded scope. The subsequent [progression contract](../progression_execution_package.md) has completed independent contract review and a bounded stateless timing helper; full progression and release remain incomplete.

## Progression follow-through

PROGRESS-C4-R01 resolves the Charter interval as54000complete ticks with both
endpoints observed. The stateless helper refuses gaps/corrupt tuples and checks
the exact winter-day12 midnight. Sixteen new tests bring the full suite to
**4590tests/159439assertions/0failures**; independent review found no blocking
regression. Evidence is in [the progression record](../../validation/evidence/progression-2026-09-19/).
The producer facts, saved owner, grants, UI and full progression are not wired.

The starter/queue follow-through also makes ARCH-MEM-006's disk rollback a real
dependency of prior-valid-world replacement. Save orchestration cannot dispatch
ahead of its concrete section/owner prerequisites. None of these planning
corrections creates a rollback mechanism or finishes the starter settlement.
