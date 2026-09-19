# Starter settlement — executable integration contract

Version 1 · 2026-09-19 · INIT-C4-R01 · Baseline `47a4da2`.

This package closes the immediate task-decomposition gap. Numeric source is GDD
§§5.1,5.9 plus adopted amendments; it does not narrow the full release to this
milestone. The existing first-playable checklist supplies FP-01–12.

## Observable result

New Settlement generates the authored estuary and opens paused at tick 0,
year 1/spring/day 1/06:00. The player sees a furnished, stocked refuge with twelve
residents. Inspecting a bed identifies its assigned resident; inspecting storage
shows real lots. Designating safe roots while paused shows a pending intent.
Resuming creates one job, sends an eligible resident to a legal contact, earns
work only there and delivers the actual output into reachable storage. Hunger
and rest interrupt work through real services and preserve the lawful work state.

## Exact startup inventory and ownership

The 12 adults are 6 mice, 2 moles, 2 otters, 2 squirrels. Global persistent IDs
1–12 are allocated first; Rowan is 1. Existing needs, health, skill XP, priority,
schedule and INIT-POSE-R01 values are retained. No injury or starting order.
Relationship pairs (1,2),(3,4),(5,6),(7,8),(9,10),(11,12) have affinity 20.

Create seven ACTIVE exterior buildings, rotation 0: hall at (58,59), 12×10;
stockpiles at (50,60),(50,65),(70,60),(70,65), each 4×4; well at (64,54), 2×2;
workbench shelter at (58,54), 3×3. Use the existing Building/Room/Furniture store
and shared directory. Clear the existing footprint/apron masks before resources.
Do not create duplicate stores or pretend cleared terrain is a building.

Hall interior origin is exterior origin+(1,1), extent 10×8. Its four rooms are
dormitory 40 tiles, kitchen 10, common room 25, pantry 5. Use the exact GDD ASCII
layout, including the x4/x5 partition, row-4 door and south exit at x5. Create
12 beds, 12 seat places, one two-cell kitchen bench, one two-cell hearth and
five shelves. Four row-7 shelves belong to the pantry (200000g total); the row-1
shelf belongs to the kitchen and cannot inflate pantry storage. Assign beds by
resident persistent ID ascending, then bed ID ascending. Every usable furnishing
has an adjacent walk contact connected to its room and exterior exit.

Initial quantities, **milli-U**:

| Item | Quantity | Item | Quantity |
|---|---:|---|---:|
| wood | 180000 | stone | 100000 |
| iron | 20000 | rope | 20000 |
| tool | 24000 total | cloth | 24000 |
| water | 60000 | grain | 80000 |
| roots | 80000 | berries | 40000 |
| nuts | 40000 | dried_fish | 60000 |
| ration | 60000 | seed_grain | 32000 |
| seed_roots | 32000 | seed_beans | 16000 |
| seed_cabbage | 16000 | seed_flax | 16000 |
| herb | 12000 | compost | 32000 |

PLAIN quality, age 0, STARTER provenance, zero reservations. The 24 tools are
12 equipped and 12 stored, durability 1000; equipped tools still have real
inventory/gear ownership. Tier-1 clothing is separately authored spawn equipment,
not a deduction of the 24 cloth. Starter construction is already completed and
does not charge these loose stocks again. Food-first then compiled item ID,
container ID ascending placement; use actual mass and filters. Four stockpiles
provide 1600000g. Refuse incompatible or overfull initialization atomically.
Do not overflow into unlimited buffers, discard leftovers or invent zero mass.

## Task packets and ready conditions

All packets require the current ruling, exact baseline SHA, source hashes and
requirement-to-test mapping. One integration owner writes SettlementSystem,
GameManager, shared catalogs/registry and memory ledger. Model policy is the loop
skill's Sonnet routine / Opus persistence and difficult-review split. Independent
test/reviewer sessions do not overlap author paths. Each attempt has a 15-minute
generation deadline, 3-minute no-progress deadline, at most two repair attempts;
test jobs use their measured expected duration and a separate 30-minute cap.
Unknown owners must be reconciled before dispatch. No attempt self-approves.

| Packet | Exact deliverable | Dependencies / exclusive ownership |
|---|---|---|
| INIT-0 inventory authority | Make EconomySystem a projection of the settlement-owned inventory. Bind after its construction; reset and new-world generation must reseed the same store once and rebind projections without retaining old-world lots. StockAge, construction, gear, UI and saves must read that identical instance. Preserve failed-generation state, no double seeding or transient second production allocation | First integration packet after INIT-A maps its affected owners; own `systems/economy_system.gd`, `systems/settlement_system.gd`, `scripts/main.gd`, `systems/ui_manager.gd`, `ui/ui_world_session.gd`, integration tests and memory/registry corrections. Coordinate exact paths with INIT-E and save owners |
| INIT-A ownership map | Enumerate current public Building/Room/Furniture, inventory/gear and directory APIs; map every startup field to its one owner, prove mass/filter capacity and persistence classification; enumerate missing interfaces without writing parallel stores | Planning: new `starter_binding_manifest.json`; read existing stores/catalogs. Required before runtime startup edits; [observed API map](starter_binding_manifest.json) records current methods and blockers |
| INIT-B relationships | Budgeted packed relationship state and exact six startup pairs, canonical ID order, stale-generation rejection, clear/reset and serialization classification | PC-04 compatibility decision before allocating a new permanent layout; own `core/relationships.gd`, its tests and reserved registry change |
| INIT-C structures | A prepared starter-building plan using seven building instances, four rooms, exact furnishings and all contacts; validate room/door/furniture reachability against spatial owner | INIT-A and compatible spatial contracts; own new `core/starter_structures.gd` plus tests. Existing-store edits explicitly added to this packet before dispatch |
| INIT-D goods | Deterministic legal container placement and gear bindings; prove every milli-U, gram, equip instance and durability value; no duplication | INIT-A/C, real room/container identities; own new `core/starter_goods.gd` and tests. Reserve any necessary inventory edits against SAVE-COLUMNS-INVENTORY |
| INIT-E transaction | Preflight catalog, all allocations and geometry; build all prepared state; preserve prior-valid-world failure behavior; publish once. Cohort first, one persistent-ID sequence, one reset; authoritative poses unchanged | INIT-B/C/D; integration owner only: SettlementSystem, GameManager, initializer, relevant integration tests. No second complete in-memory world unless peak-memory contract allows it |
| INIT-F inspection | Show hall, room, bed assignment, pantry/stockpile stocks and equipped tools from real published state. Hook New Settlement, pause and error recovery to transaction; no synthetic counters | INIT-E and UI-C4 input repair; own presentation/scene and UI files by named subpacket. Structural representations labelled separately from production art |
| MOVE-G ground loop | Bind the one spatial/transform/navigation/movement pipeline, source/output/cargo reservations and legal services; implement RESERVED→TRAVEL→WORK→delivery and cancellation/replan boundaries | Qualified starter ground profiles/contacts, INIT-E; split planner, movement, productive completion and integration writers before dispatch. No fake fit or ground-only release claim |
| NEED-S service loop | Real eat/drink/rest service intent and transfers, reachable bed use, interruption and return; separate care/heat phase ordering before adding new producers | INIT-E/MOVE-G; read owning need/food/work contracts; one needs owner. No floor-sleep stand-in credited as bed service |
| FP-Q checkpoint | Tick-indexed player fixture and negative matrix FP-01–12; real runtime captures, exact conservation accounting, speed invariance and first-divergence record | INIT-F/MOVE-G/NEED-S; independent QA; one heavy job |

These are bounded ownership packets, not claims that their unresolved upstream
interfaces already exist. INIT-A must publish concrete API recipes before INIT-C
or D dispatch; PC-04 compatibility remains a real prerequisite for INIT-B.

## Required failures and evidence

Preflight failures: unknown/retired catalog entry, incompatible variant, overfull
container, insufficient entity/lot/gear/room capacity, illegal contact, overlapping
furniture, unreachable only exit, duplicate identity, missing scenario profile.
Each leaves the previous valid world and save intact, with the failed assertion
visible in New Settlement. No infinite seed retry; maximum 16 as inherited.

After success: regenerate same seed/catalog/scenario twice and compare all
authoritative fields; restart after a world with claims; verify zero stale claim
or relationship/bed refs. Assert resident IDs 1–12 and unique subsequent IDs.
Assert seven buildings, four hall rooms and the furniture census, and exact
inventory/equipment totals. Do not merely change existing tests from zero to
nonzero; prove identities, locations, capacities and no missing instances.

For actual play, use seed 20260905 and the safe roots fixture required by FP-01–12.
Derive yield, quota, WU, XP, cargo and delivery expectations from current catalogs
and measured route, not hardcoded completion ticks chosen after seeing output.
Test contested source/destination, full storage, cancellation at each phase,
destroyed/reused targets, topology changes, needs interruption, pause and equal
ticks at 1×/2×/4×. Ordinary visual/input actions do not alter authority or RNG.

Evidence records candidate SHA plus dirty diff digest, engine/catalog/scenario
identity, actual commands and exit codes, assertion summaries, every participating
state field, screenshots and outstanding failures. Missing UI interaction capture
does not become a headless pass. Until all section owners and disk orchestrator
exist, repeatability is checkpoint-local, never full save/replay qualification.

## End-to-end release remains larger

The first playable unlocks product evaluation, not release completion. Tasks
06–10 retain: all building/room/logistics operations; full seasonal food chains;
fixed life stages, care, admission, relationships, feasts and progression;
original-community/Abbey/novel-era scenarios and all three premise families;
connected underground/water/canopy behavior; all fifteen persistence sections,
transactional disk restore, replay and failure recovery; finished reference-backed
art/animation/audio, accessible controls, UI settings and release packaging.

PC-03 named scenarios and PC-04 family coefficients are still real authoring
gaps. They need finite versioned data, source-qualified casts, exact initial
conditions and testable survival/care rules. This document does not claim to have
authored those by listing them. The task-08 release card must be expanded before
those consumers start; no single-refuge or adults-only final-release substitution.
