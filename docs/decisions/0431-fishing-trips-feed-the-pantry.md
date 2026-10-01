# 0431 — Water part B: fishing trips feed the pantry through the real fishery
Date: 2026-10-01 · Status: Accepted

**Brendan, 2026-10-01: water part B is approved whole -- "everything in trimmed and everything in as originally
queued".** Built on `feat/demo-day-length` c228d90 (master with the ten-minute day, 0421; water part A, 0196/0231; the
review batches' arrival 0361, cards 0332, incidents 0331, map layers 0292, work board 0411, kitchen 0381, earth 0401,
weir 0301, sound 0351). Everything here is the demo's presentation layer; nothing the simulation owns. MOVE-G01–G05 stay
open.

Numbered 0431: the highest record on any branch or worktree was 0421, and this lane holds 0431–0439 (the weir lane
running beside it numbers above 0440). Its companions: **0432** the boat core, **0433** the pond's ice, **0434** the
drying rack and the mill, **0435** the real gear, **0436** the kitchen's fish stew.

## Decision

### 1. A trip is a real fishing cycle, opened at the water

A trip fishes through `demo/water/fishing_driver.gd`, which runs `scripts/core/fishing.gd` unforked: stocks, the daily
quota, closures, the restocking latch, the effort slots and the catch formula are the store's. The cycle is OPENED only
when the fisher stands at the water -- a bank, the ice's edge or the jetty -- after a recheck (`fishery.gd
entry_refusal`, decision 0231's bank recheck carried to every water): REQ-SET-044's effort slots
(`begin_cycle`), the gear's durability claimed by the cycle's Job (0435), and room held in a store for the expected
catch at the crew's FISH (decision 0222: a producer reserves first). It COMPLETES when §5.4's work is done
(`complete_cycle`: the store's catch, limited to the quota and the floor, debited from the stock; REQ-SET-045's wear
applied once; the slots released). Called off before then it is CANCELLED (`cancel_cycle`: the slots back, nothing
taken; the gear's claim released with no wear; the held room given back). A catch out of the water is always landed:
Cancel is refused then (0222).

### 2. Four methods in distinct roles -- the GDD's gear rows, not a yield ladder (review ECO-023)

| Method | §5.4 row | Where | Work | Role |
|---|---|---|---|---|
| Hand net | hand net | any bank: the run, the ford, the pond's west bank | 60 WU, one fisher | flexible: any of the water's fish, an hour |
| Trap | trap | any bank; dace, perch, carp only | 20 WU set, 6 h soak, 20 WU collect | little attendance: set and left, collected later |
| Boat | boat | the pond (fixed routes, 0432) | 120 party-WU, a crew of two, 2 effort slots | the big planned catch |
| Ice fishing | ice kit | the frozen pond, safe ice only (0433) | 90 WU, ice kit + tier-2 outfit | the winter fishery |

**There is no LINE**: §5.4 has no line row, and a line would be a gear the GDD does not have. The weir is a structure
with its own lane; it is not fished here. M1/M3 unlocks are not evaluated (the demo runs no milestones; the driver's
header says so already).

### 3. The species are the items; the whitelist holds

The catch lands as its species (`farm_catalog.gd` THE PANTRY'S OTHER GOODS): trout, dace and salmon from the stream (the
river habitat), perch, carp and whitefish from the pond (the lake) -- six pantry items, §5.7's fish row (1400 NP/U, not
raw-edible, 48 h). SET-AMEND-001's whitelist: the coast's herring, mackerel and mussel have no item here (no coast; mussel
coast-only), eel and pike are hazards and never food (REQ-SET-056), shrimp is no game fish, and there is no generic
"fish" item -- `fish` is only §5.7's recipe selector over the species (BAL-CAT-004).

The pantry keeps them beside the crops: `ITEM_COUNT` stays the sixteen crops (every crop-only table stops there);
`PANTRY_ITEM_COUNT` = 24 adds the six fish, dried fish and flour; `category_of` extends the §5.6 rows with `CAT_FISH`,
`CAT_DRIED_FISH` and `CAT_FLOUR`; `shelf_hours_of` reads each good's §5.7 shelf. The kitchen's reservations
(`ingredient_takes.gd`) and the raw-food rule read `category_of`, so a fish lot is never taken for a crop.

### 4. Who: the work board, and the FISH skill

Every fishery job is a work-board task (`work/fishery_work.gd`, decision 0411): `SOURCE_FISHERY` 7 (`SOURCE_WALK` moves
to 8, past every source), activities `ACT_FISH` (a trip's seat, a trap's collection) and `ACT_CRAFT` (the rack, the mill,
making and mending gear). No crew prefers them, so every crew takes them at priority 4 (LOW) until the player moves
them. A trip authorised with residents selected is given to them first (the Water panel's Authorise). One resident is
driven by a thin task (`fishery_task.gd`, as the kitchen's): the night, a meal call or an order takes it off cleanly
and the job goes back on the board -- a gear walk not begun starts again from the locker; a load in hand is SET DOWN
where it is, still in the books, for the next to fetch (REQ-SET-054: "retain cargo there"); out on the water or the ice
it is held (`water_hold`) and comes back first (MOVE-REQ-007).

FISH is §5.3's arithmetic (XP 10 a productive WU, residents.gd's level curve): seeded by trade (DEMO) -- the otter fisher
4, the otter boatwright 2, everyone else 0 -- and anyone learns by fishing (LORE-P12). A boat's HELM needs FISH >= 1; its
second seat may be a learner. Work runs on the calendar at §5.2's 80 milli-WU a tick × §5.3's `1000 + 50 × level`: a
hand-net cycle is a game hour, 25 s at 1x.

### 5. Arrival, carrying and the stores

Every walk goes to a FREE spot at its place (`fishery.gd _free_spot`: the place, else the nearest on rings round it clear
of anyone standing still -- an idler on the store's spot never blocks a delivery), and work and deliveries credit only an
arrived worker (decision 0361, rechecked every frame of work). A catch goes to the store holding its room
(`store_upto_into`); what does not fit is carried on to another store with room, or held until there is room (0222).

### 6. The player's view

- **The Water panel** (decision 0391's layout) gains three sections below Bridges -- so 0391's actions stay in view at
  1280x720: FISHING (the trip's site, method and fish, each stepped by a button; REQ-SET-055's figures before
  authorising -- stock and quota, closure dates, expected catch, gear condition, the numerical injury risk; Authorise
  trip; the trips out, one chosen for Cancel trip; the gear locker with each piece's wear; Make net / trap / ice kit and
  Mend gear), BOATS (each boat, its wear and crew; the jetty; the pond's ice) and DRYING RACK AND MILL.
- **Every new verb has its action card** from its order's own decision (decision 0332): `trip_refusal`, `cancel_trip`,
  `make_refusal`, `mend_refusal`, `dry_refusal`, `mill_refusal`.
- **The Pantry's Stocks** shows each fish species, dried fish and flour as the crops are shown (its rows follow the
  catalog).
- **Incidents** (decision 0331): an OVERDUE trip -- two game hours past its estimate -- is a WARNING,
  `water:overdue:<trip>`, Go to its crew; THIN ICE is 0433's.
- **Sound** (decision 0351, existing CC0 cues only, no new download): the fishery commits a `splash` where a net or trap
  goes in, a boat pushes off or a hole is cut, and the event map adds a wood knock (`step_wood`: oar on rowlock) every
  1.2 m a boat rows (`sound_taps.gd _poll_fishery`). Both cues already have their text match.

### 7. Every number chosen here (DEMO unless cited)

| Number | Value | Where |
|---|---|---|
| FISH seeds | otter fisher 4, otter boatwright 2, others 0 | `fishery_rules.gd FISH_SEED_*` |
| Helm | FISH >= 1 | `HELM_MIN_LEVEL` |
| Overdue | 2 game hours past the estimate (work + a game hour for walks; a trap's soak) | `OVERDUE_MARGIN_TICKS`, `estimate_ticks` |
| Retry | 3 s, at most 3 tries, then called off (the spoil crew's) | `RETRY_USEC`, `MAX_TRIES` |
| Jetty recheck | every 5 s while refused | `fishery.gd RECHECK_USEC` |
| Handling a load | 1 WU (the farm's, the kitchen's) | `HANDLE_MWU` |
| Arrival | 0.45 m (the bridge crew's) | `ARRIVE_M` |
| Places | the locker (20.2, 8.4) by the fisher shelter; the rack's, the mill's south door, the workbench's POI, snapped to standable ground for the widest resident | `fishery.gd` |
| Sound | an oar knock every 1.2 m rowed; at most 8 splashes between polls | `sound_taps.gd OAR_STROKE_U`, `SOUND_MAX` |

## Verification (2026-10-01)

- `./tools/run_tests.sh`: `ok: 7129 tests, 562715 assertions, 0 failures.` (7082 before this lane; `test_demo_fishery.gd`
  is new, `test_demo_kitchen.gd` and `test_demo_farm.gd` extended). Live harnesses: `demo_input_live` 182/0 at
  1280x720 and 190/0 at 1920x1080; `demo_layout_live` 143/0 and 211/0.
- Mutation testing: 67 mutants over the fishery, its rules, the locker, the ice, the fleet, the routes, the boat rescue,
  the driver, the catalog, the kitchen, the takes, the skills and the work adapter; 63 killed. The four survivors: the
  arrival guard (decision 0361; every planner walk in the rig ends at its goal), `expected <= 0` (no state the rig
  reaches gives a zero expected catch past the closure and quota refusals), the not-yet-lifted trap collection
  (equivalent: the collector is the trip's seat, so a call-off ends it anyway) and the stew's paired-input pre-check
  (defensive: `_cookable_slot` already found both).
- Cost, rendered at 1920x1080 with the whole village and two boats rowing: the fishery and boats p50 about 0.1 ms, p99
  about 0.15 ms a frame (`demo_fishery.gd last_usec`); the frame time's own spread on the shared machine was larger than
  that difference.
- An independent review's CRITICAL (a carrier with no store room re-planned every frame) and HIGHs (a boat rescue that
  gave up kept its victim reserved; a cured rack batch could be lost with every job row taken) were fixed, each with a
  test.

## Why

- **The real store, opened at the water.** A cycle opened when the trip is authorised would hold the habitat's effort
  slots and the gear while the crew walks round the village -- slots REQ-SET-050 says queue others, held by nobody
  fishing. Opened at the water, after a recheck, nothing is claimed that is not being used, and a storm or a closure
  that came up on the way stops the cycle before anything is taken.
- **Rejected: a generic catch, or a line.** Both would invent what the GDD and the pantry rules forbid.
- **Rejected: species locks for the boat.** LORE-P12; the boatwright and the otters start skilled, and anyone learns.

## Consequences

- Anything that adds food to the pantry respects reservations (0222) -- the catch does; anything that reads a pantry
  item's crop row must call `category_of` (a fish has none).
- A new job owner of the demo joins the board with a source id below `SOURCE_WALK`.
- The demo still has no FISHING RNG stream: no hazard roll, no injury, no rare-quality roll (fishing_driver.gd's named
  blockers); the injury risk is shown, never rolled.


## At the batch 5 integration (2026-10-01)

- **The pantry's ledger and O's record** (0451) cover all 24 pantry items.
- **The guide** (0481): the field guide describes the catch, gear, fishing, the rack and the mill from these tables.
  A catch shelved is not a "harvest" for the first-village guide.
- **The Routes layer and the rescue card** (0461) read boat legs and boat rescues (see 0432).

## Source

GDD §5.4 (the gear table, the catch, REQ-SET-043..056), §5.3, §5.7, §5.9; SET-AMEND-001 (the whitelist); decisions 0196,
0222, 0231, 0331, 0332, 0351, 0361, 0391, 0411; Brendan's approval of water part B (2026-10-01).
