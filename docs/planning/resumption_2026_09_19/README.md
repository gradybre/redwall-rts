# Redwall resumption — current state and next work

2026-09-19 · Astra · Baseline `47a4da2642912afee4d5249424d31ab6c92f014a`.

Redwall has a substantial tested deterministic simulation foundation and a
responsive interface shell. It is **not yet a first playable settlement**.
The original checkout at `docs/executor-followup-rulings` is an older mixed
snapshot with 356 changed/untracked entries; it was preserved. The [file inventory](original_checkout_inventory.json) also checks materialized LFS assets against their pointer hashes: 248 apparent binary differences are the same integrated assets, not new art. Eleven local-only paths include historical/renumbered ADRs, archived Cycle3 review inputs, the preserved asset proposal, and the retired presentation pose scaffold. Work resumes in
`/Users/brendan/Developer/redwall-rts-loop-2026-09-19` from integrated master.

## Current verified position

PRs 140–158 are merged. The latest integrated candidate is `e898533`; its final CI passed **4808 tests / 189832 assertions / zero failures**. Capacity auditing, UI input gates, an inventory lifetime cycle, the progression interval helper, identity restore and clock/RNG restore have bounded accepted repairs. Full save/load and the first playable settlement remain incomplete. Exact pending-command restoration is integrated. Explicit encoding of economic sequence exhaustion is integrated; the full-file header checkpoint binding is integrated.

The family planning draft is integrated without runtime activation. A new runtime counterexample proves that planner dirty-list order/membership affects future job IDs despite identical previously declared fields; SAVE-J2-R01 implements the format/classification correction with explicit old-schema refusal, merged in PR148. The exact owner bulk adapter and section8 capture/apply merged in PR151; whole-world coordination remains open.

Section11 EventSchedule and exact StockAge declaration restoration are now merged (PR152/153). Exact Reservations row restoration and semantic index reconstruction merged in PR154. Its public-API overflow witness has an accepted checked-result repair contract (RES-TOTAL-R01v2 / ADR0164), merged in PR155. Exact Gear owner restoration and its adapter merged in PR156. Fishing/Forage claim-only owners and their single-block adapter merged in PR157. A subsequent public probe confirmed an older Fishing identity alias after cross-kind Directory slot reuse; FISH-ID-R01v2 / ADR0167 merged in PR158 with full stored Expedition identity and explicit old-schema refusal. The read-only claim checker merged in PR159 after exact-head CI4848tests/190647assertions/0failures; section4/file binding and activation remain separately blocked. Full section assembly, production claim-checker binding and world coordination remain open.

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

Local acceptance: **4652 tests / 180952 assertions / zero failures**, plus15 static checks; final focused268/33707/0. Tests cover both pending and drained exhaustion and actual next-submission refusal. [Evidence](../../validation/evidence/save-sequence-2026-09-19/) retains the caught owner-version mismatch and patch integration correction. Independent review found no blocking findings. PR145 merged at11526f7 after exact-head CI35471420193 passed4652/180955/0. The full-file header binding, remaining save owners/coordinator and first-playable settlement remain incomplete.


## Full-file checkpoint follow-through

SAVE-REPLAY-R01 version2 and decision0156 define the full-file checkpoint as a redundant copy of the next economic admission pair, including exhaustion, validated against section12 and section1 tick. The outer header advances to format2/264bytes; section body layouts stay unchanged. Independent contract review's five gaps were resolved before implementation. Local acceptance passed **4662 tests / 181239 assertions / zero failures**, focused159/11265/0, all15 static checks and editor import. Independent source review found no blocking findings; five advisories have recorded dispositions. PR146 merged at `7b3e83b0f448828a43e207eabf946f80ba8207b2` after CI35472659237 confirmed4662/181239/0 on head596f898. [Evidence](../../validation/evidence/replay-checkpoint-2026-09-19/) and the [source census](../../validation/evidence/replay-checkpoint-contract-2026-09-19/offset-census-disposition.md) record the exact scope. Full-file load coordination and the separately queued replay-stream contract remain unfinished.


## Family authoring progress

PC-04 now has an explicit [execution draft](../family_execution_package.md),
[bounded state proposal](../family_state_schema.md) and [lifecycle/command proposal](../family_lifecycle_contract.md). Two independent reviews checked numeric and policy
choices; the second confirmed the corrected care equilibrium and byte products.
Astra's latest repairs remain proposals pending confirmation and exact owner API/
transaction packets. The task remains in-flight; no child/elder runtime is enabled.
Evidence records reviewer findings, the source limits of old module comments, and
a deterministic arithmetic check. INIT-B's affinity20 pairs are no longer described
as already satisfying the friendship threshold40.


## Family numerical/schema closure and first implementation packet

Four independent planning reviews now confirm the family numerical tables,
care latches, bounded household/dependent payloads and the repaired illness
episode model. A separate untreated-chill bit prevents an unrelated post-treatment
injury from reviving a cured illness warning. SocialMood018 owns finalmood after
care/medical changes and shared pair-day contact; proposed phases remain inactive.

The pure fixed-stage rate helper is an implemented candidate under FAMILY-RULES-R01
(decision0158). Final-source tests:4675/181984/0 full and186/21561/0 focused, all15
specification gates and source review passed. Its two private18-value tables
occupy288 packed bytes. It is not yet wired into the running settlement: family
owner APIs, admission/lifecycle atomicity, relationship/injury consumers, named
scenarios and qualified stage profiles remain substantive work. PC04 stays
in-flight; these tests do not certify family gameplay.


The fixed-stage helper and family planning repairs merged in [PR149](https://github.com/gradybre/redwall-rts/pull/149) at `ab457e8380e8026d1b8768331d33a8119a8f0a86`. CI run35475979469 passed both checks on exact head `be314d1e0b0ca474984729794cac6ea87c44d460`; bounded helper queue entry is done. Whole family integration remains open. The next inventory-owner contract is under independent review; it does not yet alter the two-store boot.


## Inventory count primitive

INIT-COUNT-R01v2 / decision0159 supplies one callback-free cold whole-stock scan,
with checked live/loose/equipped/unreserved-loose totals and atomic output. Eleven
new tests include real Gear equip/unequip and aliased caller outputs. Final local
suite4686/183384/0, focused232/3515/0,15static checks and independent review pass.
[Evidence](../../validation/evidence/inventory-counts-2026-09-19/) retains the
contract corrections and actual array-alias probe. Merged in [PR150](https://github.com/gradybre/redwall-rts/pull/150) at `d495b9cbb7603096a31822d8c2b9078b5020076d`; CI35477230365 repeated4686/183384/0 on exact head `efc80939c29697a66ca35b5bc8f4ca7f9ca54793`. This primitive does not bind
the UI or fix the two inventories; ready NP and composition remain work.


## Exact planner capture and restore

SAVE-J2-R02v2 / decision0160 is in implementation after independent contract review. Shared schema extraction retains the35fields and exact schema2 wire hashes. Expanded focused tests256/3369/0 cover actual farm/forage/hive owners, stale jobs, dirty-order continuation, malformed outputs, buffer independence, all21diagnostic resets and derived counters. Independent source review findings resolved; final focused260/3625/0, full4703/184136/0,15static gates and import pass, with3targeted mutations killed. Merged in [PR151](https://github.com/gradybre/redwall-rts/pull/151) at `e2ce392b16ec6e224cacc65805fb4f519b8f341e`; CI35478704594 passed on exact head04791eb6ad7c99648a90289fbf21dbff42d9a23b with4703/184136/0. This closes only the planner boundary; whole-world saving remains open.


## Event schedule byte adapter

SAVE-S11-R01v2 / decision0161 candidate supplies the missing section11codec over the existing64-row owner. It preserves exact sequence allocation and due order, including exhausted or empty schedules, and requires the supplied clock barrier for apply. Independent source review found no defect; final focused43/538/0, full local4713/184355/0 before2review-requested test-only additions,15static gates and import pass. Merged in [PR152](https://github.com/gradybre/redwall-rts/pull/152) at `f4368a31ee9b496240502c7e3eaaf72d80c816fe`; CI35479087613 passed4715/184365/0 on exact head0c1e19664e3daf059b84b93983ca475f2c1ecf50. Real event domains/producers/consumers and full-world saving remain open.


## Read-only resource claim reconciliation

PR159 merged at `f0d91ba0b34323ea6b8f4b1d41836c40c15a7847` after CI35488733439 passed **4848tests/190647assertions/0failures**. The checker preserves stale historical ownership and refuses inconsistent live provenance, ecology and totals without repairing saved state. Independent review resolved and five meaningful mutants killed. [Evidence](../../validation/evidence/claim-reconciliation-checker-2026-09-19/) separates pure checker acceptance from absent production file/world binding. Twenty bounded PRs140–159 are merged; this is not first-playable settlement acceptance. Section4 streaming/owner contracts are the next active lane.

### Section4 streaming candidate,2026-09-20

Accepted SAVE-S4-STREAM-R01v2 / ADR0169 is implemented and locally verified:4869tests/202461assertions/0failures, focused21/11814/0,58generator checks,17static gates and10meaningful mutants. Both independent source reviews have no blocker. Exact-head CI/merge is next. Immutable schema adds10536 logical bytes to the ledger; actual native memory remains unqualified. [Evidence](../../validation/evidence/component-columns-stream-2026-09-20/) and [acceptance prerequisites](../component_columns_acceptance.md) distinguish structural framing from still-absent whole-section semantic/owner installation.

PR160 is merged after exact-head CI35491728462 passed4869/202461/0. Twenty-one bounded PRs140–160 have merged. Active work is the Needs offline validation boundary, with a reproduced health0/ACTIVE restore causing stale living_count; its corrective contract is being reviewed before implementation.

2026-09-20 follow-on: owner9 Needs primitive accepted locally under NEEDS-S4-VALIDATE-R01v2/ADR0170,4884/208744/0 with unchanged553/33shutdown diagnostics. Explicit20field bridge shares pure owner predicate; corrective present-row health/death gate refuses before restore.28actual mutants killed,19metadata engine cases,17static gates/import and two source reviews pass. Exact-head CI pending. All18semantic parent remains incomplete; NEEDS-STATUS-PRECEDENCE and NEEDS-DEPARTURE-DOMAIN are explicit prerequisites. Evidence: docs/validation/evidence/needs-component-validation-2026-09-20/.

2026-09-20: PR161 merged1369fce5fee64d7c292453f5d4fe8c6123328251 after CI35493467909 /4884tests /208744assertions /0.22loop PRs140–161 merged. Next: PRIORITIES-S4-VALIDATE-R01v1 /ADR0171 owner11 primitive; author active, no production intake yet. Two independent planning reviews accepted four-packed-argument API without owner construction, shared free-row predicate and distinct flags. Original checkout remains untouched.

2026-09-20 follow-on: Priorities owner11 primitive accepted locally under PRIORITIES-S4-VALIDATE-R01v1/ADR0171:4895/216053/0, focused33/7585/0,16mutants killed,18metadata cases,17static gates/import and two source reviews. Parent removed rangeArray allocation; final evidence rerun. CI pending. No bulkapply or fullsection4 acceptance. Schedule owner14 source-domain research is separate ongoing work.
