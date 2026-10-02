# Independent review: batches 5–7, PC-04 and demolition D1–D4

Date: 2026-10-02. Review only; this change does not modify game code, tests, specifications or existing decision records.

## Reviewed revisions and method

The merged-master review is pinned to `d07dabb7629be8a7721b87fdd5b9532e3568a963`, fetched from `origin/master` before creating `codex/review-2026-10-02`. The first-parent baseline immediately before 2026-09-30 00:00 America/New_York is `0a2456b97c4ac5a0444d982b84a7cef6800325d6`. Both `git log --merges --since='2026-09-30 00:00:00 -0400' origin/master` and the first-parent history were inspected, including the nested lane merges.

**PR #215 was OPEN, not merged, when reviewed.** Batch 7 is reviewed separately at its exact head, `4eb8e3c04669cbfdcc14460502502a2ded6763f0`. References marked **B7** below are to that commit, not assertions about the contents of merged master. References marked **M** are to the master snapshot. Later changes are outside these snapshots.

The review traces decision-record intent through source, callers and tests. Severity describes behavior and impact, not style. Recorded demo exceptions and approved numerical proposals are distinguished from production settlement requirements; the demo's explicitly unsaved state is not reported as a newly introduced save defect. Headless evidence does not establish rendered performance on the qualification PC or a new visual sign-off at 1280×720.

## Findings: shared resources and progression

### R01 — high — Batch 7 creates the starting cloth twice

**Revision:** B7, the hall and infirmary integration in #215.

**Evidence:** [godot/demo/hall/hall_projects.gd:38](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/hall/hall_projects.gd#L38) initializes its own `cloth_milli` to 24000; [godot/demo/infirmary/care_state.gd:65](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/infirmary/care_state.gd#L65) independently initializes another 24000. [godot/demo/hall/hall_rules.gd:30](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/hall/hall_rules.gd#L30) explicitly assumes that nothing else keeps cloth. Both features are constructed in [godot/demo/demo_village.gd:447](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/demo_village.gd#L447) and `:461`. Hall construction debits its private balance at `hall_projects.gd:363–365`; infirmary construction debits the care shelf at [godot/demo/infirmary/infirmary_project.gd:111](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/infirmary/infirmary_project.gd#L111).

**Reproduction and impact:** Open a village: the two consumers together own 48 U. Build the infirmary (12 U) and upgrade the hall (8 U): 28 U remains available between the two books, instead of 4 U from one opening stock. This hides the treatment-versus-construction trade-off. Decisions 0622/0623 and 0771 each refer to the GDD §5.1 opening **24 U**, and each locally approved allocation is understandable; their combination does not authorize a second opening stock. Decision 0902 reconciles care and infirmary reservations but misses the hall's copy.

**Suggested fix:** Put cloth in one shared village-owned store. Have hall building, infirmary building and treatment reserve and debit that owner. If separate shelves are desired, partition the one opening quantity explicitly. Add an integration conservation test covering both buildings, a treatment, cancellation and loads in transit; the separate lane tests cannot detect two individually conserving copies.

### R02 — medium — The opening-stock deduction loses provenance after cellar storage changes consumption order

**Revision:** B7, the full-larder goal plus cellar hauling in #215.

**Evidence:** [godot/demo/farm/opening_pantry.gd:36](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/farm/opening_pantry.gd#L36) assumes opening lots are consumed first, subtracting **all** withdrawals and spoilage of the item from the initial quantity at `:43`. However, [godot/demo/kitchen/ingredient_takes.gd:161](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/kitchen/ingredient_takes.gd#L161) chooses by forecast expiry; [godot/demo/farm/farm_pantry.gd:553](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/farm/farm_pantry.gd#L553) makes that expiry depend on each lot's storage rate. [godot/demo/goals/village_goals.gd:173](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/goals/village_goals.gd#L173) uses the resulting deduction for the village's own food-days.

**Reproduction and impact:** Move the opening carrots into a cool cellar (350‰), then receive younger carrots into the covered store (1000‰) while the cellar is full. The younger lot can expire first and be cooked or spoil first. Either event incorrectly reduces `left_milli` for the untouched opening lot. Repeated new harvests can reduce the inferred opening balance to zero while opening carrots still exist. The goal then credits starter supplies as food the village produced, contrary to the approved full-larder ruling in 0902. This is an interaction introduced by combining legitimate expiry-first selection with storage transfers, not a reason to change that selection rule.

**Suggested fix:** Track opening provenance on actual lot quantities, preserving it through splitting, transfers, merging, consumption and spoilage. Test an older opening lot in a cellar against a younger harvested lot in a warm store, for both consumption and spoilage. `test_demo_opening_pantry.gd:66` currently tests the aggregate-ledger assumption without reversing expiry order.

## Findings: care and winter

### R03 — medium — Infirmary patients inherit the remote hall's temperature

**Revision:** B7, winter and the standalone infirmary in #215.

**Evidence:** [godot/demo/infirmary/care_tasks.gd:99](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/infirmary/care_tasks.gd#L99) sets `brain.indoors` when the patient enters the infirmary. [godot/demo/winter/demo_winter.gd:463](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/winter/demo_winter.gd#L463) treats **every** indoors resident as `FuelScript.HALL`, then uses that source's heat and temperature at `:472`. [godot/demo/winter/hearth_fuel.gd:44](https://github.com/gradybre/redwall-rts/blob/4eb8e3c04669cbfdcc14460502502a2ded6763f0/godot/demo/winter/hearth_fuel.gd#L44) has only burrow-home sources plus the hall.

**Reproduction and impact:** Admit a Chilled patient to an infirmary placed away from the hall. With the hall burning, the patient clears exposure using hall warmth; bank the hall's hearth and the patient's thermal state changes despite remaining in the infirmary. No infirmary fuel is counted. The indoors flag was sufficient when the hall was the only hidden interior, but decision 0623 adds a different building. This also makes winter demand and care feedback disagree about where the patient is.

**Suggested fix:** Resolve a resident's actual interior/heat source instead of mapping a boolean to the hall. Bind the infirmary to its own adopted heating rule, or state and obtain a specific demo simplification if that rule is intentionally deferred. Add an integrated test with a patient in the infirmary and another resident in the hall while the hall hearth is toggled. The winter tests exercise hall interiors and a composed health work factor, but do not exercise an infirmary interior's heat source.

## Findings: resident identity and committed events

### R04 — medium — PC-04 can transfer family state to a different resident when a typed row is reused

**Revision:** M, PC-04 in #209. Reproduced with Godot 4.7.2 using an isolated minimal project importing the reviewed scripts; no repository game files were changed.

**Evidence:** [godot/scripts/core/households.gd:341](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/scripts/core/households.gd#L341) stores only a directory generation against the resident's typed row; `:355–357` and `:386` compare only that generation. Save-column validation has the same incomplete identity at `:1205`. [godot/scripts/core/entity_directory.gd:205](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/scripts/core/entity_directory.gd#L205) allocates directory slots and typed rows independently; generations belong to directory slots at `:223–235`. Two different directory slots can therefore have the same generation and reuse the same resident row.

**Reproduction:** Bind resident `(0,1)` at typed row 0, join a household and disable willingness. Despawn without unbinding, which is the recovery case decision 0521 explicitly supports. Allocate a resource node into the freed directory slot, then spawn another resident. The replacement uses resident typed row 0 but a different directory slot, `(2,1)`. The old binding is incorrectly considered live:

```text
old_ref=(0, 1) old_typed_row=0 household=0
intervening_resource_ref=(0, 2) new_ref=(2, 1) new_typed_row=0
new_resident_is_bound=true inherited_household=0 inherited_willing=false
bind_fresh=false refusal=HOUSEHOLD_RESIDENT_ALREADY_BOUND
release_stale=false refusal=HOUSEHOLD_BINDING_NOT_STALE
capture=true
image_refusal=HOUSEHOLD_COLUMN_MEMBER
unhoused_child old=(0, 1) filler=(0, 2) fresh=(1, 1) row=0 inherited_care=6000 image_refusal=''
```

The final line is a second case: an unhoused child's care decays from its initial 6500 to 6000 before reuse. The new child inherits 6000 and the captured image **passes** `columns_refusal()`. With household membership, the stale member reference instead makes the captured image invalid.

**Why it matters:** Household, care, willingness and fairness state can cross identity boundaries. Fresh binding and stale-row recovery both refuse to repair the affected row. This breaks the full `(slot, generation)` identity contract and the no-inheritance guarantee in `docs/planning/family_state_schema.md:44–82`. Severity is medium because family/child production integration remains inactive; this is still a reproducible failure in the store's adopted recovery and persistence contract.

**Suggested fix:** Retain and validate the complete bound directory reference in every reader, mutation, recovery path and column validator. Correct the generation-only schema and memory ledger along with the implementation. Extend [godot/test/test_households.gd:920](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/test/test_households.gd#L920): its immediate respawn reuses the same directory slot and advances the generation, masking this case. Interpose another entity kind and test both membership and unhoused care/save validation. Nearby Buildings and Construction retain the full reference; stores indexed by actual directory slot do not share this typed-row alias.

### R05 — medium — Feast and resident memories finalize while diners still hold unresolved bowls

**Revision:** M, with the trigger still present in B7. Batch 7's feast buff adds another consumer of the premature result.

**Evidence:** [godot/demo/regatta/regatta.gd:525](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/demo/regatta/regatta.gd#L525) tallies at 19:00. Lines `:850–856` snapshot already-consumed hotpot portions and clear the occasion; `:863–865` finish permanently. However, [godot/demo/kitchen/kitchen.gd:1371](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/demo/kitchen/kitchen.gd#L1371) intentionally preserves held portions after closing, and consumption is committed only by `_eat_portion()` at `:1294–1300`.

[godot/demo/people/people_taps.gd:383](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/demo/people/people_taps.gd#L383) also processes each meal once at closing. Its cooked-for-everyone deed at `:391–392`/`:416–418` uses the kitchen's provisional served tally (`kitchen.gd:1395`); shared-supper contact at `people_taps.gd:401–405` sees only those who have already eaten.

**Reproduction and impact:** A diner served at 18:59 can finish after 19:00. The feast chronicle and shared-feast affinity omit that resident, and the resident-memory pass misses the shared supper. In B7 the final menu/buff calculation can also miss the late committed meal. Conversely, when the last outstanding bowl is returned after 19:00, `kitchen.gd:838–846` corrects the kitchen's tally, but the permanent “Cooked supper … for everyone” deed has already been awarded and is never retracted. Decisions 0381, 0438 and 0491 require consumption/committed deeds; decision 0781 already recognizes the need to defer meal goals until these portions resolve.

**Suggested fix:** Publish one finalized-meal event after all holders for that meal finish or cancel, retaining the committed diner set for feast and memory consumers. Add two boundary tests: a last bowl eaten after closing, and a last bowl returned after closing. Regatta tests pre-populate eaten meals or use on-time meals; the people tests at `test_demo_people.gd:825–897` exercise settled/static tallies. Neither tests the unresolved-holder boundary.

## Findings: validation and scale

### R06 — medium — The scale subprocess can leak an arbitrary number of resources while the outer suite reports zero leaks

**Revision:** M and unchanged in B7.

**Evidence:** [godot/test/test_scale_stress.gd:24](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/test/test_scale_stress.gd#L24) matches any resource count with `\\d+`. The captured subprocess output is consumed at `:218–229`, and `:235` requires only **at most one matching line**, not zero leaked resources. The line is not forwarded to the outer diagnostic supervisor.

**Why it matters:** A single `ERROR: 1 resources still in use at exit ...` and a single `ERROR: 1000 resources still in use at exit ...` are equally acceptable to this test. The outer zero-leak summary cannot see either. The exception was explicitly documented in 0561, so this is not an undisclosed rule invention; it is an open regression-detection gap, particularly relevant after #210's teardown fix and B7's 0922 ownership changes.

**Suggested fix:** Remove the broad tolerance once the teardown fix is verified in this subprocess. If a residual exception remains, record and check its exact object/resource identity and bounded count, and surface it in the aggregate evidence. Add a fault-injection case that introduces one extra retained resource and must fail. Preserve the existing zero-unexpected and zero-leak gates in `tools/run_tests.sh`; changing the runner cannot repair a diagnostic a nested harness swallows.

**Qualification:** This review does **not** claim ordinary Restart still leaks on master. `demo_actor.gd:264–268` calls `brain.drop_jobs()` during destruction, and `resident_brain.gd:1160–1165` breaks the older kitchen/job cycle; `test_demo_lifetimes.gd:76–94` covers that mitigation. The broad scale-test exception is the confirmed finding.

### R07 — high — The route budget cannot bound one expensive plan, and the demo still lacks the 256-resident presentation path

**Revision:** M, carried into B7. This is a previously documented, still-open scale hazard, not a new benchmark or an undisclosed regression.

**Evidence:** [godot/demo/cast/route_desk.gd:70](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/demo/cast/route_desk.gd#L70) always admits one plan into an empty frame window. [godot/demo/cast/cast_nav.gd:308](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/demo/cast/cast_nav.gd#L308) executes the search synchronously. Standing residents add dynamic ring nodes at `:548–571`; expansion links dynamic nodes at `:650–682`, while standing collision checks scan the standing set at `:292–298`. The frame budget is checked between plans and cannot yield inside a long plan. [godot/demo/cast/demo_cast.gd:152](https://github.com/gradybre/redwall-rts/blob/d07dabb7629be8a7721b87fdd5b9532e3568a963/godot/demo/cast/demo_cast.gd#L152) additionally creates one full actor per stress resident, without the adopted 24-skeletal-actor/crowd split.

**Why it matters:** The committed [scale report](../performance/2026-10-01-scale-test.md) already measured route means growing from 2.0 ms at nine residents to 44.8 ms at 50, with visible route waits and clock stalls. Its loaded-Mac, headless 256-resident run reports frame p95 values of 463 ms at breakfast and 656 ms at supper. Those numbers are **not** qualification-machine release measurements: contention at 256 was 2.46, and headless processing does not measure rendering. Nevertheless, a budget that explicitly permits one unbounded search cannot guarantee responsive controls. Adding the B7 systems and a nine-resident soak does not establish 256-resident readiness.

**Suggested fix:** Bound or incrementally schedule search work inside a plan, restrict obstacle-neighbor work spatially, and use the adopted crowd presentation above the skeletal actor cap. After integration, repeat 9/25/50/100/256 tests with contention recorded, then run the release qualification profile. Include synchronized meal, dusk, group-order and winter/care activity; a short invariant smoke at 25 residents is not that performance gate. Retain the report's separate capacity limits (seats, beds, POIs and the 62-resident deed mask) as explicit follow-ups rather than treating successful spawning as functional 256-resident support.

## Coverage and intent checks

The first-parent merges in the requested date range are #179, #199 and #201–#214. #215 is the separately reviewed open PR. The nested lane decisions were used to distinguish adopted behavior, proposals and disclosed deferrals.

| Cohort | Intent and paths examined | Result / limits |
|---|---|---|
| #179 asset-pipeline skill | Skill diff and decision 0188 provenance; species authority, measured import axes, paid-generation approval and provisional asset status | No new actionable defect. No assets generated or paid requests made. |
| #199, #201–#203, batches 1–4 | Decisions 0196, 0205–0212, 0222–0261, 0292–0301, 0331–0332, 0351–0361, 0371–0411; focused checks of arrivals, orders, audio/input ownership, meal conservation and work resumption | The old HOLD-as-arrival concern is addressed by the later work-board changes. R05 concerns actual committed meal consumers, not that earlier issue. This is focused source review, not a claim to exhaustively exercise every historical path. |
| #204–#205 | 0421 day-length change and 0511 loose ends; tick-derived calendar/needs context | No confirmed additional finding. |
| #207 batch 5 | 0431–0436, 0441–0442, 0451, 0461, 0471, 0481, 0491–0493; water/fishing including delivery/cancellation, planner/routes, session/guide, people, keybindings and external-review approval log | R05's resident-memory consumer. No additional confirmed ownership defect. |
| #212 batch 6 | 0437–0439, 0561–0562, 0581, 0591, 0781 and integration 0901; ferry/regatta, scale, playtest evidence, map layers, notices and goals | R05's feast consumer and R06–R07. Ferry route refusal and boat ownership were traced. The scale report's limits are retained, not restated as a successful 256-resident qualification. |
| #209 PC-04 | Decision 0521; households, child hunger wiring, reuse/recovery, column restoration and family schema | R04, including live store-level reproduction and accepted-invalid-state case. |
| #206/#208/#211/#214 demolition D1–D4 | 0531–0534; anchor transaction journals/restore, pile BFS and quantity rollback, starter structure ownership/capacity, containment, shared inventory, admission reservations and cancellation/stranded release | No additional confirmed defect. D5–D9 and the construction/admission persistence closure are explicitly incomplete in the lane records. They are not silently declared save-ready by this review. |
| #210 hygiene, #213 art lock | 0501, runner diagnostics/raw-log gate, lifetime mitigation, analyzer and visual authorization diff | R06 identifies a nested test exception outside the runner's view. Ordinary Restart is not reported as newly broken. |
| #215 batch 7, OPEN | 0541, 0551, 0571, 0601–0603, 0611–0612, 0621–0623, 0631, 0681–0682, 0711, 0771, 0791, 0801, 0881–0886, 0902, 0911–0912, 0921–0923 and 0931; day/night, seasonal trees, winter fuel, dishes, cellars, infirmary, chronicle, foraging/feast, standing orders, Great Hall, multi-select, camera, crop plans, opening stocks, soak and pause card | R01–R03 and the continuing R05–R07 interactions. Approved demo numbers and defaults are not treated as unmarked rule inventions. The deferred hall tier-2 fuel factor, herb-patch consolidation, building-panel work and production save integration remain disclosed scope limits. |

For determinism and save review, the core store contracts were checked against full EntityRef identity, integer quantities, slot reuse, rollback and column validation; R04 is the confirmed failure. Demo display-time floats, unsaved presentation state and explicitly approved demo numerical rules are not automatically production-state violations. No unsupported new gameplay rule is prescribed by the fixes above.

For 1280×720, source/layout paths and existing live-test coverage were inspected across notices, goals, roster/multi-select, map layers, camera and the B7 pause/card integration. The lane's recorded small-window overlap fixes were considered. **No fresh rendered 1280×720 session was performed for this review**, so it does not grant a visual sign-off or assert a screenshot-based layout defect. A composed small-window pass with maximum notices, a party selection, winter/care feedback and a building card remains useful acceptance work.

## Independent runtime evidence

The clean master baseline was executed in the separate `codex/ci-shard` worktree at the same `d07dabb7` game/test revision, before changing the test wrapper. There were no staged `godot/demo/assets` in that worktree. Its generated `godot/.godot` directory was removed, followed by:

```sh
godot --headless --path godot --editor --quit
./tools/run_tests.sh
```

A temporary, untracked `godot/override.cfg` assigned a unique user-data directory to avoid touching Claude's running sessions. The test corpus was unchanged: 240 directly discovered suite files. The actual summary was:

```text
7974 test(s), 577345 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 268 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
ok: 7974 tests, 577345 assertions, 0 failures.
```

The import took 4.122 seconds and the full suite 783.548 seconds on this local machine. These are actual local observations, not an estimate of hosted CI time or rendered frame performance. Exact CI-sharding equivalence evidence belongs to the companion CI PR under `docs/validation/evidence/ci-shard-2026-10-02/`.

The isolated PC-04 probe independently reproduced R04. R01–R03 and R05 are source-traced counterexamples with the missing integration tests specified above; this review did not run a second full suite on the unmerged B7 head. R06 is a direct inspection of the nested diagnostic filter. R07 uses explicitly attributed existing measurements, not a new benchmark. A passing master suite therefore does not close these findings.
