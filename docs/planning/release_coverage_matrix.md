# Settlement release coverage and ownership

2026-09-19 · Astra resumption v3 · Initial source baseline `47a4da2`; integrated repairs through `ccb3da6` (PR157).

This matrix accounts for the complete adopted settlement release. Status means
the observed layer, not requirement completion inferred from filenames or tests.
The primary GDD/UI/movement requirement allocation remains `requirements.csv`;
the rows below also preserve policy obligations outside that declaration list.

| Domain | Observed implementation | Remaining release deliverable | Owner / acceptance |
|---|---|---|---|
| Initialization and economy authority | Terrain, ecology and 12 residents/poses; separate EconomySystem and simulation inventories; zero starter buildings/rooms/furniture | One inventory, exact hall/interior/services/stocks/equipment, relationships, atomic valid-world publication and reseeding | INIT-0/A–F in resumption starter package; REQ-SET-009 and FP-01 |
| Time and commands | Fixed scheduler and six of 24 economic command kinds; speed queue separate | Remaining 18 commands, owned stores, pending/commit/refusal UI and duplicate/cancel recovery | Task04 + command-specific 06–08 packets; ARCH-CMD-003, no enabling a handler without its owner |
| Ground movement and work | Standalone spatial/navigation/movement stores; no composed production travel loop | Qualified starter profiles/contacts, one movement caller, reservation→travel→work→cargo→delivery and needs interruption | Task05/INIT MOVE-G and NEED-S; all FP-01–12, distinct from final G01–05 |
| Connected space | Adopted policy, hazard/economy values, tooling and profile register; production fit/cost inputs remain incomplete | Complete supported species/stage profiles, water/shore/dive, protected/unprotected climb/canopy, all three interoperable underground construction methods, rooms, support, safe cancellation/rescue | Task05/06, MOVE-G01–05; PC-02, finite geometry/peak memory, real-source measurements |
| Buildings, rooms and logistics | Packed stores and Construction lifecycle; no full live command/work/service integration | Placement, delivered-material jobs, build/upgrade, rooms/furniture, heat, equipment, hauling, evacuation, demolition/refunds and last-exit protection | Task06; REQ-SET-121–137, BUILD-C4-R01, actual goods/occupant blockers |
| Ecology and food | Resource, forage, fish, crop/weather stores and cadenced stages; missing movement/service consumers | All adopted fishing/forage/farming/orchard/hive, recipes/passive batches, storage aging and conservation, equipment wear/repair and renewable resource loops | Task03/07; no hunting activation; source recipes require explicit balanced runtime catalog |
| Need, health and care | Needs integrator, aggregate injury store; early care/health ordering debt | Real meal/water/rest services, heat and care at their proper stage, illness/injury/exposure, recovery/departure/death and grief | Task06/07/08; separate §17 care before lifecycle/progression once new inputs exist |
| Families and community | Adult cohort and life-stage identity; family numerical/schema planning has four independent reviews and an integrated unbound fixed-stage rate helper | PC-04 exact fixed-stage schemas/rates/schedules/care, warnings/rescue and non-graphic serious survival consequences; relationships and memories | Task08; no births/aging, adult fallback, child productive/hazardous work, or cap above256 |
| Admission and arrivals | Setting policy and amendment; candidate/arrival implementation absent | Atomic eligibility, exceptions, petition expiry, bed/population checks, legal arrival placement and deterministic naming | Task08 + PLAN-ARRIVAL-PLACEMENT; no reuse of initial-root formula for arrivals |
| Scenarios and content | Twelve-book reference library; one numeric refuge baseline | PC-03 finite named scenarios covering original/Abbey/novel-era settings and founding/restoration/established premises; authored cast/continuity, exact stocks/maps/objectives and saves | Task08, PC-03; missing Eulalia text/Salamandastron pages remain source limits, not invented prose |
| Feasts, chronicle and progression | Catalog/specification, event schedule infrastructure and reviewed winter interval helper | Finite authored events with trigger/repeat/effect/save rules, feasts, grief/remembrance, Charter and continuous winter interval, victory/continuation/collapse autosave protection | Task08/09; PC-06, ARCH-CONFLICT-004; no new supernatural power system |
| Persistence and replay | Section codecs including EventSchedule, exact StockAge, Reservations, Gear and Fishing/Forage claim owner restoration, plus canonical inventory, identity/clock/RNG and exact pending restore; terminal sequence and header binding integrated; planner dirty-state correction and exact owner/section8 adapter integrated | Remaining save prerequisites, owner bulk APIs, section bodies, provenance, complete owner capture/apply, stock-fault continuation, disk orchestrator, complete rollback/replay/save corruption recovery | Existing save matrix/queue, task09; `release_save_ready=false` until full generated world and continuation proof |
| Player interface | Authored responsive shell, roster/needs/alerts; UI-C4 visibility/input repair and headless positive-control routing probes accepted | actual selection/camera/input, all management screens, settings/keybinding persistence, onboarding/forecast and accessible keyboard/trackpad flow | Task04.5/10; all 103 registry elements assessed against real state, ART-UI-12 separate |
| Art and animation | Approved finish concept and five height anchors; one imported mouse body, procedural crowd/lookdev and UI art | Source-backed species/rig/gear/pose families, buildings/terrain/water/canopy/underground assets, LOD and material/animation/contact integration | Task10 + art gates; paid generation needs exact approved spend, no code-side art self-approval |
| Audio | Direction specified; no complete runtime audio delivery demonstrated | Contextual acoustic/orchestral music, ambience, effects, voices/singing where authored; volume controls and source/provenance | Task10; source reference is not an automatically licensed production audio file |
| Reliability and qualification | 4798-test integrated CI passes with static contract gates; inventory lifetime leak repaired, 553 objects/33 resources remain in suite shutdown | Investigate leaked objects/resources, profile actual integrated workloads, deterministic negative/race/recovery checks, accessibility/visual review and three-year survival runs | Task10 independent QA; Mac evidence distinct from minimum-spec hardware, Windows remains user-deferred |
| Packaging and release | GitHub PR/CI path operational; controller installed for controlled foreground use | Reproducible local Mac game package, manifest/runbook/save compatibility and release observation; configure any additional external distribution target before publication | Task10 release owner; no new public store upload, signing purchase or paid hosting inferred |

## Dispatch policy

The queue has been reconciled with merged PRs 134/136/137/138 and 140–157. A ready label
left behind after merge is not permission to repeat a finished lane. PR139 owns
only the review-packet refresh. Preserve the old dirty source checkout and its
untracked planning records; transfer only reviewed differences with known bases.

INIT-A source ownership mapping and the bounded UI repair are accepted. Prioritize
remaining live adapters, section bodies and the other save prerequisites that gate atomic starter
replacement, while authoring the remaining gameplay packages. Before writing new gameplay, expand each row to
task packets with exact interfaces, rules, failure behavior and tests; the broad
table does not make absent numerical contracts ready. PC-03/04/06 and complete
Q2 authoring remain active Astra planning work. PLAN-RELEASE-COVERAGE is not fully
accepted merely because this index exists: its runtime queue expansion and
bounded downstream packets must be reconciled and validated first.

Each release claim must name a candidate, requirement coverage, exact commands,
observed results, relevant captures and an independent reviewer. Test counts and
memory-ledger arithmetic alone do not prove a playable colony, physical fit,
full save parity, visual finish or measured performance.

## Added dispatch entries

The 2026-09-19 queue now names INIT-A/0/B/C/D/E/F separately. INIT-A is a
reviewed-source API map, while runtime INIT entries remain behind an unanswered
Astra contract gate; the graph cannot release them merely from this document.
The remaining finite packages have explicit planning owners:

| Package | Queue task |
|---|---|
| Scenario roster and initial conditions | PLAN-PC03-SCENARIOS |
| Fixed stages, households and care | PLAN-PC04-FAMILIES |
| Winter interval and progression | PLAN-PC06-PROGRESSION |
| Commands, jobs, material movement and services | PLAN-LIVE-CONSTRUCTION |
| Seasonal production and need services | PLAN-LIVE-FOOD |
| Event producers, consumers and community | PLAN-COMMUNITY-EVENTS |
| UI, species/audio assets and Mac packaging | PLAN-PRESENTATION-RELEASE |
| Retained object/resource diagnosis | QA-SHUTDOWN-LEAKS |
| Integrated release acceptance | PLAN-INTEGRATED-QUALIFICATION |

Each planning package must add precise implementation task ownership and its
actual numerical/interface contract before releasing a writer. Existing
PLAN-ARRIVAL-PLACEMENT and PLAN-RELIEF-SEEDS remain separate obligations.
This graph expansion closes the missing-owner index, not the underlying
PC-03/04/06 authoring or any runtime release gate.
