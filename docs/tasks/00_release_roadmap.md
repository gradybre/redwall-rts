# Settlement release roadmap

2026-09-09 · **Planning allocation, not implementation or acceptance evidence.**
Read [package handoff](../planning/README.md) first. This roadmap extends tasks
01–03 and preserves the full confirmed first-release settlement scope. It is a
sequence of dependency-owned increments, not ten equally sized releases.

## Starting evidence and sequencing

At repository HEAD `4fb57b1`, [STATUS](../STATUS.md) reports task 01 complete,
task 02's checklist complete with integration gaps, and task 03 at 6/10 increments;
1224 tests / 35844 assertions / zero failures is the executor's reported snapshot,
not a result rerun by this planning work. File mentions and isolated controls do
not establish system completion. Re-read current status before dispatch.

ARCH-MIG-006 remains the migration owner. Recover missing initialization,
commands, gear/container foundation and player projections through task 04;
continue task 03 in parallel under explicit file ownership. Task 05 supplies
actual access/travel. Task 06 completes rooms/construction before task 07 relies
on those services. Task numbers identify ownership, not a prohibition on pulling
an independently specified prerequisite forward. Pulling work forward never
creates two stores or grants credit to an unimplemented consumer.

| Task | Deliverable | Dependencies and boundary |
|---|---|---|
| 03 | Ecology/crops/weather integration and READY_06 follow-through | Existing executor owns completion; stores are not yet a running economy |
| [04](04_world_commands.md) | World initialization, ordered intent, pending previews, inspectable application | Command contract now; initializer waits on real starter services/spatial identity |
| [05](05_movement_first_playable.md) | Shared movement architecture and first observable gather/work/deliver loop, then connected domains | Reviewed slices may proceed; full G01 precedes full G02 binding/closure; ground checkpoint is intermediate |
| [06](06_buildings_rooms_logistics.md) | Build, inhabit, heat, furnish, equip and supply connected spaces | 04 commands; 05 access; starter subset pulled into 04 |
| [07](07_food_production_survival.md) | Integrated food production, consumption, sustainable seasonal economy | 03 ecology; 05 movement; 06 services; family coefficients require task-08 contract |
| [08](08_community_scenarios_progression.md) | Community/care/dependents, admission, story, all scenario families, progression | Begin scenario/family authoring now; integrate after services and food |
| [09](09_persistence_replay_reliability.md) | Transactional persistence, complete replay and failure recovery | Schema work begins with 04; final parity needs all authoritative state |
| [04.5](04_5_ui_visual_refinement.md) | First-playable UI refinement:42 requirements, visual targets, native evidence | Component work follows04.4; visual quality grows now while independent gameplay continues |
| [10](10_presentation_qualification.md) | Complete art/audio/UI and whole-release qualification | Presentation grows with every task; final gate requires 03–09 and all expanded contracts |

Immediate order: finish task 03's current increment without changing its branch;
parallel plan-parser work closes 04.1 and movement geometry/interface questions;
implement 04.2 and UI shell; publish 04.3 only with legal stores; run 04.4; progress
05's first-playable checkpoint; complete connected domains and dependent systems.
The checkpoint can precede production save completion, but final-only subset
hashes cannot be reported as full determinism or save parity.

## Full-scope safeguards and supporting contract owners

[requirements.csv](../planning/requirements.csv) assigns declaration-level
GDD/UI/movement requirements to an integration owner. It starts NOT_ASSESSED.
It is not a checklist of implemented features. Lower-level ARCH/BAL requirements
are read with their owning sections and tracked in each task's acceptance evidence.
The following policy obligations exceed the current numerical GDD and must not
be lost merely because they have no REQ-SET row yet.

| Policy / contract | Required release coverage and owner | Closure required |
|---|---|---|
| DEC-001/002/003/008/023/025/028 | 08 authors original-community, Abbey and novel/era setting families; new-refuge, restoration and established premises; 04 initializes; 10 selects/displays | Finite named scenario roster and valid combinations, role, era/cast, objectives, opening, maps, exact initial states, protected/variable outcomes. Not every Cartesian pairing is mandated; one refuge is insufficient |
| DEC-010/029/031/035; MOVE-REQ-001–020 | 05 spatial/access contract; 06 all three interoperable underground methods, inhabited earth-built rooms and varied homes | G01–05 closure; persistent finished tunnels, multilevel editing, swimming/diving, supported canopy routes, no X/Z shortcuts |
| DEC-015/032/033 | 08 fixed life stages and dependents; 07 needs/food; 05 rescue/access; 06 homes | Family amendment: packed schemas, capacity within 256 living/512 slots, needs/care/exposure, warnings/rescue and non-graphic survival loss; no invented adult coefficients, births or aging |
| DEC-005/006; SET-AMEND-001 | 08 scenario admission/individual exception; 07 diet and active recipe catalog | Exact refuge petition/expiry/atomicity, retired hunting/reserved holes retained, plant/fish/seafood and nut roast; research food never auto-activated |
| DEC-007/011/012/016/017/022/023 | 08 meaningful feasts, grief/remembrance, names, light dialect, warm humor, notices/chronicle/story surfaces, civic Charter | Finite authored events and memory effects with trigger/state/save contracts; no new arbitrary mood buffs or forced endings |
| DEC-009/030 | 08 rare, significant, uncertain wonder | Event state can be deterministic without declaring supernatural truth; no new powers or belief meter implied |
| DEC-000/018/019/021/024/034 | 10 recognizable anatomy, grounded storybook materials, contextual sound; source review in 05–08 | Direct image inputs and species/contact sheets, era-qualified source records, assets and audio budgets; whole available 12-book corpus with six-book emphasis retained |
| DEC-013; DEC-004/014/020/026/027 open portions | 08 scenario/story lead | Preserve varied antagonist motives without importing battle/campaign mechanics; resolve named scenario/content boundaries where a scene depends on them; no torture mechanics or authored child-cruelty actions |
| ARCH-CMD/CLOCK/SAVE; U2/U3 | 04 with 09 review | Scheduler event ordering, persistence/version, recovery debt; see task 04.1 |
| ARCH-JOB/INV and BAL-WORK-001 | 03/05/06/07 | One job producer per intent, atomic claims, exact whole-product work factor and XP; darkness/workshop missing ownership resolved before production use |
| ARCH-MEM/ID; MOVE-G02 | 05 with 06/09/10 | Full expanded capacity/allocator/rollback/renderer ledger; old single-floor totals are baseline-only |
| ARCH-CONFLICT-004 / REQ-SET-155 | 08 with 09 | M4 maintained winter interval versus point sampling; approved trigger and budgeted saved interval state before claiming Charter victory |
| ARCH-PERF; ADR 0016/0024 | Integration lead, independent reviewer; 10 final | Current integrated release measurements with workload/hash/build manifests; Mac M5 Pro is not the qualification floor |

## Cross-task contract queue

These are **deliverables to resolve**, not tacitly adopted numerical choices:

1. **PC-01 command/scheduler closure (04/09):** queue ordering, widths/capacities,
   paused persistence, duplicate/refusal semantics, U3 reconciliation.
2. **PC-02 connected-space closure (05/06/09/10):** use
   [movement contracts](../planning/movement_contracts.md), with per-gate evidence.
3. **PC-03 scenario catalog (08/04):** name the finite scenario roster, document
   coverage across setting/premise families, source/era limits and all numeric
   initializer/objective differences. Each candidate remains inactive until its
   owning GDD/balance/UI/catalog definitions are reviewed and versioned.
4. **PC-04 family/care amendment (08/07/05):** fixed stages, dependent schedules,
   capacities, service demands, needs and hazard/care formulas, rescue and
   notification thresholds. Preserve child vulnerability and ban hazardous child
   work; do not implement birth/aging or silently reuse adult rates.
5. **PC-05 service/work context (06/05/07):** Building/Room/gear and real light,
   weather/workshop factors, installed boat ownership and interaction points.
   Reconcile READY_06 proposals with adoption state before using their values.
6. **PC-06 progression interval (08/09):** settle ARCH-CONFLICT-004 and fixtures
   before the winter completion test is approved.

Each closure records decision status separately from implementation and evidence:
PROPOSED → ADOPTED (by owning authority) → IMPLEMENTED → VERIFIED. An accepted
policy may have an unresolved engineering contract. A implemented proposal does
not become adopted through test success. Keep prior ADR evidence and supersede
stale lower-priority guidance explicitly, including any unadopted R06 ruling.

## Parallel execution and evidence discipline

Use the repository's six-agent flow: plan-parser → game-coder → test-runner →
user-qa → code-reviewer → git-manager. Parser/UX/reviewer use the configured
Sonnet tier, narrow repeatable tests/git Haiku, coder inherits the session's
capable implementation model and has Bash. Escalate failed reasoning-heavy test
triage to coder/reviewer; never substitute a cheap model's assertion for logs.
Codex-native execution uses available equivalent reasoning/coding tiers rather
than pretending Claude's model aliases execute here. Assign exact files before
spawning, use compact requirement extracts and query individual library records.

The integration lead is the sole writer to common runtime composition, registry,
memory ledger and shared task status during a parallel batch. Independent QA
writes test/evidence files, reviewer returns findings; coders apply corrections.
Git manager checks branch/status and stages only assigned work after review under
current user authorization. Do not merge unrelated PR #2 or disturb executor work.

For every increment retain: base revision, requirements, new/proposed versus
inherited constants, exact commands, engine/export identity, fixture inputs,
assertion summary, actual failures, deterministic state scope, screenshots for
UI claims, allocation/memory changes and next owner. Update the existing test
migration ledger. Begin save schema and performance capture with each new store;
never defer discovering omitted state until task 09 or overload until task 10.

First playable acceptance is [here](../planning/first_playable_acceptance.md).
Final release additionally needs all adopted scenario/family/movement content,
full UI/accessibility, production save/replay, survival/progression and actual
performance evidence. Windows testing remains deferred by Brendan; the available
64-GB/RTX-5090 PC and Mac results do not qualify the specified minimum hardware.
