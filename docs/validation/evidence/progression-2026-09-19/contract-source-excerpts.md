## docs/game_gdd.md:778-817
Full source SHA256: 4af401786cea23dfb7ba114871b75070bdbbe270077841380ebc1337e9f262eb

### 5.11 Immigration, milestones, victory, saves, and performance

Immigration events occur every third midnight from day 4. Candidate count=`min(8,2+floor(reputation/2000)+orchard_feast_bonus)`, reputation 0–10000. Candidates arrive only after player acceptance; capacity is limited by spare valid beds and the 256 resident cap. Default automatic acceptance is off. Acceptance predicts resulting food demand and rejects if ready food-days<4 after acceptance; an explicit event-specific override permits it. Candidate species use the scenario AdmissionProfile under SET-AMEND-001 §5. The refuge normal pool is mouse,mole,otter,squirrel,shrew,hedgehog,hare,badger in that order. At event day D=4+3*e, ordinary slot i uses pool[(world_seed mod N+e+i) mod N]. A declared exception replaces slot C-1 and requires explicit acceptance; it is never auto-admitted. The refuge has the authored rat petition at absolute day 10. Pending rows expire next midnight; acceptance/refusal clears the row atomically. The global 16-species catalog remains available to other validated profiles; giant residents are not candidates. New residents arrive with health 100, needs 6500, tier 1 clothing, one basic tool, skill XP 5000 in two seeded active skills and 0 otherwise; reserved skill index 3 remains zero. Immigration adds no food or currency.

Reputation is recomputed daily: `clamp(floor(mean_mood/2)+min(3000,100*completed_feasts)+1000*charter_awarded−500*deaths_last_12_days,0,10000)`. Empty population mean is 0. Acceptance cannot hide current deaths by resetting history.

**R-BUILD-DOM-001 mask binding:** bit m in World.milestone_mask and
Progress.unlocked_mask records actual award of Milestone m. Active new worlds
start with M0=0 and both masks=1; unknown/unbound progression is unavailable.
Progress.milestone is the highest earned ordinal for display, not an unlock
threshold. A definition requires its exact earned bit; do not infer earlier
awards from a higher ordinal. Awards/rewards commit once when their own conditions
pass, with eligible awards evaluated in ascending ID order. Masks agree and
reserve bits above 4 as zero; see [domain ruling](rulings/2026-09-11_building_room_domains.md).

| Milestone | Condition | Unlock/reward |
|---|---|---|
| M0 Refuge |Start |All basic survival buildings, farming, nets, safe foraging, drying, composting |
| M1 Settled Hearth |Day≥4 AND at least 12 residents AND prepared 200 portions cumulatively |Mill, workshop, cellar, preserver, saltpan, infirmary, lookout, traps; bean_hotpot, nut_loaf, tier 2 outfits; Hearth feast |
| M2 Abundance |Population≥48 AND survive first winter AND master 3 recipes |Weirs, apiary, brewery, stone walls, paved paths; pie, roast, tart, feast_fish, rations, mead, iron_tool |
| M3 Deep Roots |Population≥80 AND year≥2 AND food-days≥8 |Boats, boathouse, nursery, orchards;2 apple+2 pear saplings once; fruit recipes; Orchard feast |
| M4 Hearth Charter |Year≥3; population≥120;8 named specialists with skill≥8 across≥6 skills;10 mastered recipes;12 completed feasts; mean mood≥6500; ready food≥18 winter-demand days; fuel≥18 winter days; all residents warm-bedded; zero starvation/exposure deaths in current winter; conditions maintained last 3 winter days |Victory presentation, Charter monument cosmetic, continue settlement |

Feast success count, recipe mastery, and unlocks are monotonic; population/stock/mood conditions are current values. M4 can be earned at winter day 12 only, after evaluating that midnight's needs/deaths. There is no time-limit loss; year 10 is still eligible. An all-resident death/departure ends the settlement after the final lifecycle commit, offering load or new settlement. Warden death alone does not end play; player can appoint another adult, with no stat change.

| ID | EARS requirement |
|---|---|
| REQ-SET-151 | When an immigration event occurs, the system shall create a reviewable candidate list and show housing, food, and labor consequences before acceptance. |
| REQ-SET-152 | If accepting candidates exceeds living capacity or valid spare beds, then the system shall cap the selection and explain the limit; the population cap cannot be overridden. |
| REQ-SET-153 | When an accepted resident arrives, the system shall allocate a new persistent ID and valid bed and initialize the declared skills, needs, and equipment. |
| REQ-SET-154 | When a milestone's complete conditions are met, the system shall unlock its catalog entries once and record the triggering tick. |
| REQ-SET-155 | When M4 completes, the system shall award the Hearth Charter, pause for the completion screen, and allow continuation of the same save. |
| REQ-SET-156 | If living resident count reaches 0, then the system shall pause on settlement collapse and offer load save or return to menu without overwriting the previous autosave. |
| REQ-SET-157 | When Warden Rowan or a later Warden dies/leaves, the system shall allow appointment of any living resident and preserve the settlement. |
| REQ-SET-158 | The system shall support manual saves, five rotating daily autosaves, a separate prewinter save, and a separate pre-major-demolition quicksave. |
| REQ-SET-159 | When saving, the system shall serialize authoritative state, RNG streams, inventories/reservations, relationship edges, event schedule, job progress, unlocks, and pending commands at a tick boundary. |
| REQ-SET-160 | When loading, the system shall validate ruleset/map/catalog versions and rebuild navigation/render state before resuming, preserving simulation hashes after the next tick. |
| REQ-SET-161 | If a save is incompatible or corrupted, then the system shall retain the file, report the reason, and offer other saves without attempting a partial world load. |
| REQ-SET-162 | The system shall store per resident data in packed columns, batch job/path queries, and keep per-frame UI updates independent from hourly/day-level simulation. |
| REQ-SET-163 | While 256 residents are active at 1× or 4×, the system shall satisfy the qualification budgets below on the Windows reference floor before claiming support for that configuration. |


## docs/systems_architecture.md:594-625
Full source SHA256: d830fd15bd31620f18d7696812db6aab68f2db940f86c383ef837dc777b94215

```

**ARCH-TICK-002.** Define a tick interval as `(k-1,k]`; read interval climate and resident activity from the committed tick `k-1`. Accrue continuous needs/work/age for that interval once. At an hourly/midnight crossing apply accumulated boundary effects before starting the next interval. Initial calendar offset is 4500 ticks; first midnight is 13500, then every 18000 ticks. Hour boundaries satisfy `(k+4500) mod 750=0`. Midnight satisfies `(k+4500) mod 18000=0`. Never perform a second age pass just because the same tick is both hourly and daily. `[GDD §5.1 REQ-SET-006–007; NEW interval convention]`

**ARCH-TICK-003.** Daily ordering is stock aging → ecology → crops/weather → immigration/departures → progression. At midnight, aging uses the season in the elapsed interval; ecology uses the new calendar day's season; crop hourly growth uses the elapsed hour's climate, followed by new-day weather/moisture/service reset. Prepare deaths/departures as intents, but commit them before progression so current living population and cause-of-death counters are correct. All systems below operate once in their assigned phase. `[GDD §5.1 REQ-SET-007, §5.10–5.11; NEW crossing convention]`

| ID / system | Reads | Writes | Frequency and dependency | Provenance |
|---|---|---|---|---|
| ARCH-SYS-001 TransformSnapshot | Transform current | Transform previous | Every tick; first | [crowd §6.2] |
| ARCH-SYS-002 CommandCommit | Ordered command queue, catalogs, directory, current stocks | Orders, policies, reservations, lifecycle intents | Every tick; after snapshot, before selectors | [GDD §5.1 REQ-SET-005] |
| ARCH-SYS-003 IntervalIntegrator | Needs, activities, weather, lots, rooms, work context | NeedRemainders, IntegrationRemainders, age/work accrual | Every tick; prior interval state | [GDD §5.2, §5.8] |
| ARCH-SYS-004 StockAge | Accrued lot age, storage factors | InventoryLot, spoilage intents, invalid leases | Hour crossing and expiry crossing; midnight first | [GDD §5.8 REQ-SET-107–108] |
| ARCH-SYS-005 Ecology | Basins, fish/forage/tree state (fauna reserved empty), climate | Stock growth, quotas, migration, resource regrowth, ecology events. **NOT `FishStock.closed`** | Midnight after StockAge | [GDD §5.4–5.6, §5.9–5.10; [ruling 2026-09-11 §4.1](rulings/2026-09-11_ready07_open_item_answers.md)] Fish stock and quota recovery use the **new day's** season and closed stocks still recover, but this stage writes no closure bit under any condition — in particular it may not copy yesterday's event state forward as today's closure. ARCH-SYS-006 sets it one call later |
| ARCH-SYS-006 CropWeather | FarmPlot, OrchardPlot, Hive, previous climate, event schedule, **Weather absolute-season identity**, **FishStock presence/species** | Crop progress/health/ripe state, moisture, weather forecast, service counters, **`Weather.scheduled_absolute_season`/`forecast_absolute_season`**, **`FishStock.closed` (the summer-blight event bit)** | Hourly crop integration; midnight after Ecology | [GDD §5.6, §5.10; [ruling 2026-09-11 §4.1](rulings/2026-09-11_ready07_open_item_answers.md), decision 0055] **This system is the ONLY writer of `FishStock.closed`.** At each midnight, after settling the completed day's crop/orchard effects and refreshing the new day's weather exactly once, it sets every present mussel stock's event bit to `new_season == SUMMER && active_new_day_event == BLIGHT` and to false otherwise — including autumn blight and the day after expiry — before any later job planning. §5.4's calendar spawning closures remain a SEPARATE derived predicate, `harvest_closed = calendar_closed \|\| event_closed`; no other subsystem may reuse the event bit for another cause, and a future additional cause would need a typed reason mask that is deliberately not added now. Season identity, the WEATHER stream and both catalogs are preflighted before the boundary may partially advance |
| ARCH-SYS-007 ImmigrationDeparture | Needs/mood histories, reputation, candidates, policy, bed/stock availability | Review candidates, acceptance/departure intents | Daily; candidate event every third midnight from day 4; after CropWeather | [GDD §5.11] |
| ARCH-SYS-008 NeedIntent | Committed/accrued needs, safe rooms, food | Personal feeding/sleep/rescue intent | Every tick; emergencies preempt immediately | [GDD §5.2] |
| ARCH-SYS-009 JobPlanner | Orders, thresholds, recipe inputs, field/care/build service needs | Job rows, reservation plans, output commitments | On dirty service conditions; idle selectors every 30 ticks staggered by ID | [GDD §5.3, §5.7–5.9] |
| ARCH-SYS-010 JobSelector | Indexed jobs, priorities, schedule, skill, tools, paths | JobAgent, reservation transactions, scan cursors | At most 32 candidates/eligible resident/pass; exact GDD rank | [GDD §5.3] |
| ARCH-SYS-011 Navigation | Baked masks, map revision, request queue | Heap/search state, route caches, JobAgent path status | Every tick; total 2048 expansions | [GDD §5.11] |
| ARCH-SYS-012 Movement | Tick-start transforms, paths, clearance, speed caps | Transform current, motion remainders, occupancy scratch | Every tick; after Navigation | [GDD §5.11; crowd §5.3] |
| ARCH-SYS-013 ProductiveWork | Assigned job, F, tool, delivered inputs | Remaining work, XP accrual, wear remainder, completion intents | Every tick; after Movement | [GDD §5.3, §5.9] |
| ARCH-SYS-014 BatchCompletion | BatchState, frozen input/quality snapshot, passive_until | Finished lots, station release, mastery/portion increments | Every tick at exact deadline; stable job order | [GDD §5.7 REQ-SET-091–098] |
| ARCH-SYS-015 LogisticsCommit | Completion/transfer plans, containers, leases | Inventory quantities/owners, reservations, ground piles | Every tick; atomic operation order | [GDD §5.8] |
| ARCH-SYS-016 RoomHeat | Layout dirty tiles, hearth fuel, occupants | Room validity/temp, warm-bed index, fuel debit | Layout change; heat integration each tick; convergence hourly | [GDD §5.9] |
| ARCH-SYS-017 CareHealth | Hunger/exposure/injury accrual, care work | Health, injury, incapacity/death intents | Every tick; before lifecycle and progression | [GDD §5.2, §5.10] |
| ARCH-SYS-018 SocialMood | Needs, paired activity, memories, relationships | Affinity, mood memories, daily conflict result, naming triggers | Needs-derived mood each dirty tick; hourly/contact triggers and 18:00 conflict | [GDD §5.2–5.3] |
| ARCH-SYS-019 Lifecycle | Create/destroy/arrival/departure/death intents | Directory, typed occupancy, child release, chronicle | End of every tick; before progress | [GDD §4.1, §5.11; crowd §6.2] |
| ARCH-SYS-020 Progression | Final alive state, completed recipes/feasts, inventory, winter history | Progress, milestone_mask, unlock gifts, victory pause intent | On changed predicates; daily streak after lifecycle | [GDD §5.11] |
| ARCH-SYS-021 ForecastNotice | Dirty totals, current obligations, active conditions | Cached food/fuel/potential summaries, Notice/NoticeCondition | Hourly and committed stock/policy change; no frame scan | [GDD §5.8 REQ-SET-119; UI §7] |
| ARCH-SYS-022 CheckpointHash | All authoritative state and queues | Canonical digest, save stream, replay diagnostic | Committed boundary only | [GDD §5.11; crowd §6.4] |
| ARCH-SYS-023 PresentationExtract | Completed immutable snapshot, dirty pages | Render buffers, UI snapshots only | Render cadence; never writes simulation | [GDD REQ-SET-162; UI §3; crowd §6.3] |



## docs/validation_resolution.md:94-109
Full source SHA256: 62d3022be254644af7ee16c4dfca7e1ee6661c1f609d5152a01ff337064e737b

## 5. M4 temporal ambiguity: exact proposed amendment

The existing drafts interpreted the source as checks at the starts of winter days 10,11,12. Three point samples do not prove continuous maintenance between those samples. The GDD both says “conditions maintained last 3 winter days” and permits award at midnight starting winter day 12. Its timing words need one explicit interpretation; changing a threshold is unnecessary.

**RES-M4-PROPOSAL-001.** Proposed wording, not an applied GDD edit: “At the midnight beginning winter day 12, after needs, deaths and lifecycle commit, award M4 only if every current predicate holds and has held at every completed tick throughout the preceding 54000 ticks. These are winter days 9,10,11. A false predicate resets the maintained interval immediately.” `[NEW proposed interpretation; 54000 DERIVED from GDD 3 × 18000]`

| Boundary in year 3 | Absolute day | Completed tick |
|---|---|---|
| Start winter day 9 | 141 | 2515500 |
| Start winter day 10 | 142 | 2533500 |
| Start winter day 11 | 143 | 2551500 |
| Start winter day 12 / existing award instant | 144 | 2569500 |
| End winter day 12 | 145 | 2587500 |

The amendment would preserve the source's award instant and all numeric thresholds. Implementation would need saved `m4_true_since_tick:i64` and a sentinel for false, plus corresponding memory/schema revision, or an equivalent explicitly budgeted interval-validity representation. It must test a predicate failure between midnights and reset across save/load. No array field is silently added to the current memory ledger by this proposal. Until the wording is adopted in a versioned source revision, M4 outcome certification remains withheld; the existing point-sample interpretation is not evidence of continuous maintenance.



## docs/setting_decisions.md:359-403
Full source SHA256: 528740861ad3ae6ba4f6db964668cef07c4d170c10e471bebec35dd2a7f08abc

| interpretation | Preserve uncertainty about the supernatural origin of rare meaningful guidance; characters may interpret it differently |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]` |
| operative_rule | Present experiences and attributed beliefs without omniscient confirmation or debunking. Do not introduce a hidden authorial true/false verdict, an objective miracle label or a proven supernatural modifier |
| affected_lore | `[LORE-U06, LORE-U13, LORE-C12]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; future event/codex/chronicle content |
| mechanical_change | No new powers or belief stats. Event occurrence can be deterministic and saved while its fictional cause remains uncertain; event outcomes must still be precisely specified |
| remaining_questions | Exact events and character viewpoints; mixed story delivery now confirmed under DEC-022; canonical portrayals require source/era review |
| revisit_trigger | `NONE` |
| supersedes | `[DEC-030/open supernatural certainty]` |

### DEC-032 — Adopted dependent-resident family model

Brendan initially requested advice, then answered “That works for me” to the recommendation. The model is now `USER_CONFIRMED`; adoption establishes design and release scope, not missing implementation math.

| Field | Value |
|---|---|
| status | `USER_CONFIRMED` |
| answered_on | 2026-09-06 |
| user_wording | “That works for me” |
| interpretation | Adopts the immediately preceding dependent-resident recommendation, including shared care, active elders, family starts/immigration, population accounting and fixed first-release life stages |
| scope | `[WORLD, RELEASE_1, FUTURE, PRESENTATION]`; births and aging are separate later specification work |
| operative_rule | Implement children as dependents with real needs and play/learning routines; adults share care; elders retain individual roles; all simulated people count within existing caps |
| affected_lore | `[LORE-U11, LORE-U14, LORE-C11]` |
| affected_docs | `[docs/setting_bible.md, docs/setting_decisions.md, CLAUDE.md]`; required GDD, UI, balance, architecture, save, initialization and asset revisions |
| mechanical_change | Required dependent-resident extension. Preserve existing numeric rules as the baseline until an exact family amendment supplies changed schemas, quantities, schedules and validation; adult-only coverage does not satisfy the adopted final scope |
| remaining_questions | `[DEC-014, DEC-027]`; family/mourning customs and wider portrayal limits; child vulnerability is confirmed under DEC-033 and exact family engineering remains required |
| revisit_trigger | Revisit birth/aging scope when planning the later lifecycle feature, before its implementation; no date or recurring reminder is set |
| supersedes | `[DEC-032/revision-0.7 proposed family model]` |
| provenance_boundary | The previous agent recommendation is adopted within its described scope; no new hunger multiplier, care workload or child danger rule was supplied by the user |


| Area | Adopted direction | Reason / boundary |
|---|---|---|
| Children | Real dependent residents with food, bed, warmth, health, social and care needs; visible play, learning and shared meals | Their presence affects decisions and makes care visible; avoid decorative children whose needs never count |
| Adult caregivers | Named household/care relationships, with care shared among available adults and a community fallback | Avoid assigning all care to one gender, assuming kinship from surname, or making a single guardian's loss delete a child's support network |
| Child activities | No ordinary productive labor assignments, hazardous expeditions or excavation jobs; play/learning use a separate routine policy | Children do not become cheap replacement workers; a visible helping animation must not secretly create inventory or production XP |
| Elders | Full residents with individual skills and chosen roles, including optional storytelling, teaching and care | Age alone does not imply helplessness or a universal productivity penalty |
| Initial release population | Authored households in scenario starts and family-aware immigration; life stage remains fixed for the scenario | Makes visible family life possible without requiring childbirth, aging or generational turnover to be complete |
| Later lifecycle work | Births, aging, adulthood transitions and death by age require a separate explicit decision and complete rules | Fixed first-release life stages are now adopted; later lifecycle implementation requires a separate scope decision and complete rules |
| Population accounting | All simulated people, including children and elders, count toward the existing 256 living cap and 512 resident slots | No free secondary population; household admission must account for all members before acceptance |
| Safety and loss | DEC-033 now confirms illness, injury and possible death from survival hazards, with clear warnings, rescue opportunities and non-graphic presentation | Exact hazard/needs/care values remain required; no hazardous work assignment or combat system is added |
| ECS representation | Extend shared resident data with tightly budgeted life-stage, household and care references; retain the crowd rendering path | Do not build a separate Node hierarchy or unbounded object graph for each family |

The adopted release model has fixed life stages: play/learning do not imply a promised adulthood transition during the initial scenario. That tradeoff must be visible in the scenario description. New hunger multipliers, care work, schedules, household capacities, elder modifiers and relationship bonuses are deliberately not fabricated as inherited values.



## docs/setting_rules_amendment.md:1-35
Full source SHA256: ede2b0508f8428b7216c3b831d5ea54d1db3a868d903224b192d56b61cf1db10

# Settlement Rules Amendment — Community Admission and Food

| Field | Value |
|---|---|
| Document | SET-AMEND-001, revision 1.0, 2026-09-05 |
| Authorization | Brendan: “Adopt both”; DEC-005 and DEC-006 |
| Ruleset | `settlement_rules_v2` |
| Owners updated with this amendment | GDD revision 1.1, UI revision 1.1, balance and architecture documents |
| Scope | Approved admission and dietary rules; current refuge initialization plus contracts for other scenario authors |
| Evidence status | Exact authored specification and reference validation; not a completed settlement runtime or full-release scenario package |

## 1. Authority and provenance

The approved policies are settlement-specific populations with authored individual exceptions, and plant staples plus explicitly nonsapient fish/seafood instead of mammal/bird hunting. This document supplies the mechanical reconciliation. `[USER]` means that policy; `[NEW]` means an implementation/content choice authored here; `[INHERITED]` means an unchanged prior GDD value; `[DERIVED]` means arithmetic from identified values.

The exact refuge roster order, exception date/text, replacement recipe inputs and retirement strategy are `[NEW]`, not quotations from the user or Redwall canon. They are operative implementation choices under the adopted policies and can be revised explicitly as the interview develops. Do not attribute the rat traveler to the novels or invent a canonical biography.

For these two policies this amendment resolves the superseded rules. The GDD and derived catalogs are edited to agree; this is not an invitation to keep implementing the old tables. Other scenario maps, casts, founding histories and completion conditions remain separate required first-release work under DEC-028.

## 2. Food and material boundary

| ID | EARS requirement |
|---|---|
| REQ-ADM-001 | The catalog compiler shall reject a food-source creature classified as sapient, a resident species also registered as food stock, and any mammal or bird harvest source. |
| REQ-ADM-002 | When a food job reserves an aquatic stock, the system shall require membership in the exact edible aquatic whitelist and shall preserve the existing stock, quota, closure and hazard rules. |
| REQ-ADM-003 | If a command, scenario, recipe, lot, job or building references a retired key from Section 3, then the validator shall reject it before world mutation rather than substitute an item or spawn free resources. |

The edible aquatic whitelist is exactly `[carp, dace, herring, mackerel, mussel, perch, salmon, trout, whitefish]`, all `sapient=false` in the food-stock catalog `[INHERITED keys; NEW explicit whitelist authority]`. The `fish` recipe selector resolves only these keys. Pike/eel hazards are non-harvestable encounters; they produce no edible lot. Future sapient aquatic characters may not reuse an edible species key with a contradictory classification.

No livestock, milk or egg production is introduced. Cloth remains produced from flax, rope from flax, outfits from cloth, and tools from wood/stone/iron under existing recipes. Hide currently has producers but no active material recipe consumer; remove it rather than inventing a leather replacement chain. Wax remains available for current candles; waxed-cloth equipment is a future authored recipe, not a hidden change to outfit inputs.

## 3. Exact retirement and replacement map

| Domain | Retired keys | Replacement / disposition |
|---|---|---|
