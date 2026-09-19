# Redwall resumption — current state and next work

2026-09-19 · Astra · Baseline `47a4da2642912afee4d5249424d31ab6c92f014a`.

Redwall has a substantial tested deterministic simulation foundation and a
responsive interface shell. It is **not yet a first playable settlement**.
The original checkout at `docs/executor-followup-rulings` is an older mixed
snapshot with 356 changed/untracked entries; it was preserved. The [file inventory](original_checkout_inventory.json) also checks materialized LFS assets against their pointer hashes: 248 apparent binary differences are the same integrated assets, not new art. Eleven local-only paths include historical/renumbered ADRs, archived Cycle3 review inputs, the preserved asset proposal, and the retired presentation pose scaffold. Work resumes in
`/Users/brendan/Developer/redwall-rts-loop-2026-09-19` from integrated master.

## Current verified position

PRs 140–144 are merged. The latest integrated candidate is `24fe7d6`; its final CI passed **4643 tests / 180723 assertions / zero failures**. Capacity auditing, UI input gates, an inventory lifetime cycle, the progression interval helper, identity restore and clock/RNG restore have bounded accepted repairs. Full save/load and the first playable settlement remain incomplete. Exact pending-command restoration is integrated. Explicit encoding of economic sequence exhaustion is the active next task; full-file replay checkpoint binding remains a separate contract gate.

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

Full Q2 physical/cost profiles, PC-03 finite scenarios and PC-04 family rules
still need complete authored execution packets. PC-06 now has an exact interval
contract and reviewed timing helper; its producers, saved owner and live bindings
remain to be implemented.
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

Progression follow-through [PR141](https://github.com/gradybre/redwall-rts/pull/141) merged at `960d9c438beb01b84d652dd10395f9584628fa9b` after both GitHub checks passed on head `8c6bfda`. Its bounded helper task is reconciled as done; full PC-06 remains open.

## Identity restore follow-through

The new stateless save adapter joins section 3's six identity columns and section 1's saved allocator cursor through the existing atomic owner API. It requires the supplied clock's load barrier. Nine tests prove deleted/all-deleted IDs remain spent, exhaustion persists, and refusals preserve state. Local acceptance: **4599 tests / 159572 assertions / zero failures**, all 15 static checks passed; independent Opus review found no blocker. [Evidence](../../validation/evidence/save-identity-2026-09-19/) retains the initial registry-format failure and passing retry. Full disk/world restore remains incomplete.

Identity restore [PR #142](https://github.com/gradybre/redwall-rts/pull/142) merged at `77d03dcdd29889259150c351ceb040209e3dff74` after both CI checks passed on head `8ab03f9`. SAVE-D2 is done for its bounded scope; the full-world save task remains blocked on its other prerequisites.

## Clock and RNG restore follow-through

SAVE-W1-R02 joins decoded WorldRuntime and section10 RNG state under GameManager's load barrier. It validates both before writes, installs RNG first and the clock last, and checks each recovery write on failure. A prior seed change is valid; unseeded incoming release records refuse. No world is published and no barrier is released here.

The initial complete local run passed **4623 tests / 163075 assertions / zero failures**. After strengthening the fixtures and adding three failure/guard tests, the exact final focused suite passed **27 tests / 3999 assertions / zero failures** through the same supervisor. All 15 static checks and editor import passed. Independent Opus review found no blocker; [evidence and precise scope](../../validation/evidence/save-world-2026-09-19/) distinguish the full run from the later focused run. Full settlement save/load, initialization, movement/work integration, family/scenario authoring and release qualification remain unfinished.

Clock/RNG restore [PR #143](https://github.com/gradybre/redwall-rts/pull/143) merged at `897d3e3624a0618c00e08a8e26e3bbce8f02069c`. Final GitHub CI on head `28d9722` passed **4626 tests / 163571 assertions / zero failures**, plus specification checks (run35467235353). Its bounded queue task is reconciled as done.

## Exact pending-command restoration

SAVE-P2-R02 preserves every command record, payload offset and allocation highwater, including permuted allocation order, partial-drain holes and dead tails. Ordinary queue changes respect the actual clock barrier; the two-owner adapter installs commands first and checks restoration of the prior allocator if the scheduler refuses. Failed recovery reports explicit uncertainty and retains the barrier.

Local acceptance: **4643 tests / 180723 assertions / zero failures**,15 static checks; the focused suite118/27176/0 and independent review found no blocker. [Evidence](../../validation/evidence/save-pending-2026-09-19/) retains intermediate failures and the bounded worker recovery history. [PR #144](https://github.com/gradybre/redwall-rts/pull/144) merged at `24fe7d6d6749d3d92bfa0da20b299a0c6cd4685f`; final CI run35469937964 passed **4643/180723/0** on head `388ec82`. Schema2 is unchanged; [SAVE-SEQ-R01](../../rulings/2026-09-19_economic_sequence_format.md) specifies the separate future format extension for terminal economic sequence allocation. Full-world save/loading and first-playable acceptance remain incomplete.


## Economic sequence format follow-through

SAVE-SEQ-R01 v2 advances section12 to schema3 with a28-byte prefix, preserving the runtime allocator's exhausted state after its last ordinary value is issued. The commands canonical owner advances to2 and declaration version to4; its high scalar is u64 while field counts and packed allocations stay unchanged. Old section schemas refuse explicitly.

Local acceptance: **4652 tests / 180952 assertions / zero failures**, plus15 static checks; focused268/33704/0. Tests cover both pending and drained exhaustion and actual next-submission refusal. [Evidence](../../validation/evidence/save-sequence-2026-09-19/) retains the caught owner-version mismatch and patch integration correction. Independent review and CI are pending. The full-file header binding, remaining save owners/coordinator and first-playable settlement remain incomplete.
