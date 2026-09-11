# READY_07 — planner alignment and executor handoff

2026-09-11 · Repository inspected at `16e1efc` on `master` (implementation parent
`6cac394`). Incoming [executor brief](2026-09-11_ready07_executor_brief.md).
This is a source/code review and engineering recommendation, not a runtime test
report. The brief's **1999 tests / 56972 assertions / zero failures** is reported
by the executor; it was not rerun here. `docs/STATUS.md` retains substantial older
text and cannot be used as the current implementation inventory without checking
code and ADRs 0042–0049.

## How to use these answers

Read AGENTS' authority order. **Existing contract** below means the cited owning
specification already provides the answer. **Engineering recommendation** means
new implementation detail supplied for adoption into the owning specification/
ADR; it is not a previously approved gameplay value. **Open design gate** remains
open. Implementation, adoption and verified acceptance are different states.
No whole movement gate is closed by this handoff. No depth, species capability,
hazard damage, excavation price or family coefficient is silently approved.

The dependency correction is important: movement blocks travel, but all five
movement gates cannot be prerequisites to starting movement implementation.
G04 needs assets and G05 needs running code. ADR0020 and task05.1a already permit
independent work and a reviewed ground/shared-interface slice. Likewise, missing
Building/Furniture modules do not erase the existing inventory-container store.

| Item | Alignment | Immediate owner/action |
|---|---|---|
| 1 | Full connected movement is open; “task 05 cannot start” is too broad | Parser/architecture lead prepares the bounded ground contract below; navigation coder can implement reference kernels/fixtures now |
| 2 | Bind resource outputs to compiled ItemDefinition keys; there are 17 bindings across five request fields | Game coder adds checked request construction and tests; no hardcoded numeric catalog IDs |
| 3 | Separate scheduler events, with a complete proposed envelope/order/save contract | Adopt [scheduler proposal](../planning/ready07_scheduler_contract.md) in 04.1 before coding |
| 4 | SYS-006 owns weather-derived mussel closure; make time identity explicit | Ecology integration lead applies §4 after schema adoption |
| 5 | Mechanical row sum is the correct current planning basis | Applied in this review under ADR0050; do not add the correction again; see §5 |
| 6 | Assign implementation lead and independent performance reviewer now | Measure current integration; fix health phase ownership before RoomHeat/care integration |
| 7 | Geometry and containers already have owners; bootstrap integration is missing | Pull starter stores/catalogs forward, correct stale “nowhere specified” claims, fix single-directory publication order |

## 1. Movement — begin the right work without claiming a closed gate

### 1.1 Correct interpretation of the wall

Use [ADR0020](../decisions/0020-movement-gates-close-in-dependency-order.md),
[task05.1a/05.1b](../tasks/05_movement_first_playable.md) and
[movement contracts](../planning/movement_contracts.md). Full G01 precedes full
G02 binding/closure; G03 develops alongside G02, G04 follows scale/clearance, and
G05 closes with actual evidence. “0 of 20 MOVE-REQ acceptance rows satisfied”
does not mean no engineering or code may start.

**Start immediately:** exact integer Transform storage using the existing eight
I32 fields, generation-safe references, ground-map/static-legality construction,
reference search, path-storage exhaustion tests, queued-path versus unreachable
states, UI camera/selection/pending feedback, and future-domain interface tests.
Production connected topology, diving and canopy profiles still require their
own completed contracts. A synthetic graph test may use declared synthetic values;
it must not publish those values in active gameplay catalogs.

### 1.2 Executable baseline slice and remaining entry criteria

Keep the existing ARCH-PATH-001–005 contract for the authored surface fixture:
256 m square; 512×512 half-metre navigation cells; stable neighbor order; 10/14
costs and corner blocking; 2048 finalized expansions/tick shared by all searches;
256 cache descriptors and 1048576 route cells; generation/revision invalidation;
queued searches never prove unreachable. Ground A* and its octile heuristic apply
only to that graph. Use an expanded-graph Dijkstra reference before any nonlocal
connection is enabled; do not mix arbitrary transition costs into the ground A*
heuristic. Transform authority remains integer, including previous state; movement
uses the inherited per-size speed caps with retained 30-Hz displacement remainder.

The **ground slice entry artifact** must state these additional facts explicitly:

- Ground location IDs are baseline cell indices associated with a declared domain,
  layer and world/map revision; they are not universal multi-level locations.
  Public APIs must carry spatial context and generation-safe contact owners, not
  assume X/Z uniquely identifies a destination. Preserve the planned shared
  location/connection boundary for later domains.
- Derive walk masks from actual terrain, hall doors, furniture and physical work
  contacts. The ford is walkable under the baseline and is not a fishing tile.
  Validate static clearance against an explicitly supplied profile. **Exact
  production body/gear clearances are still a profile decision**, not something
  the 1 m mouse height or size-speed category determines. Reference routing with
  synthetic clearance is unblocked; ordinary resident travel cannot be declared
  correct until the starter profiles/contact clearances are specified.
- Work arrival requires the real contact; before arrival no productive WU. Check
  every worker/party member. Reserve inputs/output/contact before travel; renew
  every 30 ticks. Keep planning, temporary occupancy and proven unreachable
  states distinct; retain the inherited 300/900-tick rules only for their actual
  conditions. Cancellation cannot delete occupied crossing state or cargo.
- Reuse the baseline capacity ledger for this bounded fixture only. Enumerate
  every new identity/index/revision field and save obligation. No duplicate full
  world or silently resized array may be hidden in a “temporary” navigation layer.

Acceptance now: deterministic paths/ties/corners, disconnected cache starts,
start/goal stale refs, route storage full, quota exhaustion, retained remainders,
0/1/2/4 equivalence at equal ticks and invisible-view independence. Then connect
real RESERVED → TRAVEL → WORK → output/haul after starter profiles/services and
WU context are complete. A headless routing fixture is not FP-01–12 acceptance.

### 1.3 What the planner must deliver next for full G01

The existing movement design document is a proposal inventory, not a finished
production catalog. The next movement planning deliverable is an **exact G01
parameter pack**, with values, rationale and fixtures for: finite depth/elevation
and cell budget; species/age/body/posture/gear clearance profiles; speeds and
entry/exit costs for each mode; all three interoperable excavation/construction
methods including spoil/support/water; and interruption/rescue/exhaustion/death
outcomes, air budgeting and supported return. Adopted policy is not to be asked
again. New balance values must be presented as authored choices for adoption.

G02 then derives the complete packed capacities/bytes and save topology from
those values. G03 supplies registered controls, G04 actual measured clip/contact
assets and G05 actual correctness/parity/latency/memory evidence. This review
**does not pretend that those outputs exist**, or replace multilevel scope with
one floor. Continue independent work while that parameter pack is authored.

## 2. Resource IDs — use catalog keys, validate the binding

**Engineering resolution consistent with the existing catalog contract:**
`ResourceNode.resource_id` identifies the extracted output's compiled
`ItemDefinition` ID. `ForagePatch.item_id` and the item-ID field for each fish
stock use the same domain. Patch kind, fish species row/habitat and item ID remain
different indexes; never use a compiled item ID to subscript a nine-row fish table.

The five `world_init.Request` fields contain **three scalar IDs plus arrays of
five and nine**, not five scalar values:

| Request field | Exact ItemDefinition keys, in required consumer order | IDs in the inspected artifact, diagnostic only |
|---|---|---|
| tree_resource_id | wood | 59 |
| stone_resource_id | stone | 52 |
| iron_resource_id | iron | 19 |
| forage_item_ids | berries, nuts, mushrooms, herb, roots | 1,35,32,15,39 |
| fish_species_item_ids | trout, dace, salmon, perch, carp, whitefish, herring, mackerel, mussel | 55,8,41,37,5,58,16,20,33 |

Resolve with `Catalog.compiled_id_of("ItemDefinition", key)`, check `.ok`, and
verify the already adopted catalog artifact/hash. Preserve `Forage.PATCH_KEYS`
and `Fishing.SPECIES_KEYS` order; sorting those arrays by compiled IDs would
associate the wrong quotas, yields and habitats. There is no generic `tree`,
`forage` or `fish` ItemDefinition to invent. `fish` in recipes is a selector over
the approved nine keys, not a runtime stock item.

Add a checked request-construction/binding boundary and verify exact expected
keys, not merely a nonnegative int32. `_item_id_is_storable()` currently accepts
an arbitrary valid-looking integer, so it cannot prove correct catalogs. Test
missing keys, a retired key, a valid but wrong key (tree→stone), swapped arrays,
wrong array lengths and stale catalog hash. Fail before touching any store; no
fallback IDs or substituted free resources. Update the three store headers and
GDD §4.2/architecture identity note when adopting this interpretation.

This closes the binding ambiguity. It alone does **not** complete New Settlement:
the current generator clears a shared directory and rejects foreign live rows;
startup composition and proper starter services remain §7.

## 3. Scheduler events — complete the amendment, keep economic IDs stable

Adopt or revise the complete [R07-SCHED-001 proposal](../planning/ready07_scheduler_contract.md)
as task04.1's engineering contract. It specifies a 32-byte record, 256 records,
unsigned sequence ordering, a 32-byte queue header, 8224-byte runtime payload,
separate scheduler/economic barriers, exact accepted kinds/values, capacity
refusal, reserved safety holds and versioned save serialization.

It preserves 30-Hz rules, requested speeds 1/2/4, effective pause 0 and the five
existing reason bits. It does not renumber ARCH-CMD-003's 24 economic commands.
It recommends retaining whole-tick debt, including manual recovery; the existing
`acknowledge_without_catchup()` behavior and tests are not silently approved or
retired. Reconcile ARCH-CLOCK-002's recovery exception with the higher no-skipped-
ticks rule explicitly. Keep prior evidence and log intentional behavior changes.

## 4. Weather, fish closure and season identity

### 4.1 One writer for the weather closure

**Engineering ownership resolution:** ARCH-SYS-006 owns the weather-to-fishery
join and writes the existing `FishStock.closed` event bit. Amend its Reads/Writes
row and both contradictory fishing comments. SYS-005 owns fish stock/quota
recovery using the new day's season; closed stocks still recover. Its earlier
stage cannot copy yesterday's event state as today's closure.

At each day boundary: integrate elapsed-hour effects from the preceding interval;
settle completed-day crop/orchard effects; update/schedule/disclose new-day weather
once; then set each present mussel stock's event bit to
`new_season == SUMMER && active_new_day_event == BLIGHT`. Set it false otherwise,
including autumn blight and the day after expiry. Do this before later job
planning. Calendar spawning closures remain a separate derived predicate:
`harvest_closed = calendar_closed || event_closed`. No other subsystem may reuse
the event bit for another cause. A future additional closure cause needs a typed
reason mask; adding that mask now is unnecessary.

Preflight required season identity/RNG/catalog inputs before a boundary can
partially advance. A scheduling refusal is a failure requiring a diagnostic,
not permission to clear some state and publish an apparently completed tick.
Already-committed work follows existing captured-cycle policy; this ruling does
not silently change captured fish/refunds on an event onset.

### 4.2 Taxonomy and forecast fields

**Recommended minimal schema amendment:** keep the eight existing Weather I32
fields, including the current interpretation of `forecast[3]` as
`(event_id,start_season_day,duration_days)`. Add two I64 fields:
`scheduled_absolute_season` and `forecast_absolute_season`, both empty at -1.
`absolute_season = floor((absolute_day-1)/12)`; a matching current season is
`absolute_season % 4`. This adds **16 payload bytes**, taking Weather from 32 to
48; additional indexes/scratch, if introduced, must be accounted separately.
A disclosed forecast retains its absolute-season identity after event expiry.
Keep scheduled_absolute_season through expiry as the scheduled-once latch; change
it only on a successfully scheduled next season. The existing CropWeather latch
must agree with it on load, or be replaced by this single owner in one migration.
No independent extra latch allocation is implied.
The scheduled event is not automatically active: activity requires matching
absolute season and the half-open day interval `[start,start+duration)`.

Use the existing twelve `AFFECTS_*` bit positions as a versioned **effect mask**,
not a new ambiguous “system enum”: temperature, rain, moisture, crop growth,
crop damage, outdoor work, boats, exposure, lake ice, mussel harvest, orchard
water, frost, in current bit order 0–11. The mask is derived from event ID, season and the versioned typed effect
tables, never a second independently writable truth. Strip MUSSEL_HARVEST for
non-summer blight. UI maps effects to readable impacted systems; temperature/rain
can affect crops, orchards, storage aging and heating/exposure, so a coarse mask
must not falsely report “crops only.” Calm days has no modifiers but still gets
its required forecast. The packed EventDefinition modifiers vector is a separate
catalog-layout issue; retaining typed named effect tables is valid and does not
require inventing positions in that unresolved vector.

This accepts the current forecast tuple interpretation as a recommendation and
fixes its missing temporal identity. It does not add an unnecessary saved
forecast mask or replace all Weather columns with an incompatible new layout.
Version/preserve the tuple, new fields and scheduling latch in the codec. Reject
an ambiguous old snapshot if the absolute season cannot be proven; never infer
it solely from an event eligible in multiple seasons.

### 4.3 Exact season ownership and fixtures

Let a midnight at absolute day D be `tick=(D-1)*18000-4500`.
`elapsed_calendar=calendar(k-1)` and `new_calendar=calendar(k)` identify the two
sides. Crops' closing hour/day use elapsed climate; SYS-005 uses new day/season;
SYS-006 settles old daily effects before refreshing new day/season. Never pass
one season argument to every leg on a season crossing. First-day priming supplies
spring's actual baseline at tick 0; zero-filled weather is not valid opening
weather. Schedule once per absolute season, zero RNG draws for forced first
spring, one per later season; do not reseed.

Required exact checks: summer day 6 tick 301500 closes mussels before planning;
summer day 8 tick 337500 remains closed; day 9 tick 355500 reopens. Summer day 3
forecast is tick 247500. Autumn day 6 tick 517500 permits mussels during blight;
autumn day 3 forecast at 463500 carries absolute season2. At tick 427500 entering
autumn day 1, do not reuse the summer schedule; the preceding hour still uses
summer climate. Use injected valid event fixtures for these checks, not a claim
that the production seed necessarily selects blight. Repeat across years,
expiry, pause and duplicate-boundary calls; full save parity waits on the codec.

## 5. Memory ledger — reconciled in this review

**Applied:** ADR0050 and systems_architecture now contain the correction described
below. Verify it; **do not append another437632 or re-add those fields**. The
carried figure below describes the inspected incoming revision before correction.

**Existing arithmetic, not a new gameplay allowance.** The 135 printed §2.2 field
rows sum to **24993106**. The 23 §2.3 allocations sum to **60256806**. The carried
trail is **59819174**, lower by **437632 = 131072 + 306304 + 256**. Those three
amounts are already inside the Fixed registry payload; adding them there again
would double count them. The §2.2 prose subtotal is stale by the same amount.

| Metric | Corrected current basis, bytes |
|---|---:|
| Planned payload | 60256806 |
| Allocator/object reserve | 8388608 |
| One world + reserve | 68645414 |
| Headroom below 100000000 | 31354586 |
| Second mutable candidate under existing exclusions | 54041222 |
| Rejected two-world peak + reserve | 122686636 |
| Two-world excess | 22686636 |

The second candidate subtracts the existing 6215584 bytes of excluded shared/
transient rows. The two-world peak rises by **875264**, because the missed mutable
state occurs in both worlds. Do not apply only one 437632 correction to that peak.

Append a dated +437632 reconciliation to ARCH-MEM-009 after ADR0049, label the
older running totals historical, and update current tables/clauses in ARCH-MEM-006,
ARCH-MEM-010, §3.1 headroom, ARCH-CONFLICT-011 and the final reconciliation. Do not
rewrite historical ADR measurements. Use a checked arithmetic script so a later
field addition cannot update only half the ledger. Preserve the disk-backed
rollback choice. The corrected ledger still omits named future state and full
expanded movement; it is **not measured live RAM or qualification**.

The scheduler's proposed 8224 and Weather's proposed 16 are **not included** in
the corrected existing total. If both are adopted with no other allocations,
provisional payload becomes 60265046 and one-world plus reserve 68653654; real
integration must add any other newly required fields exactly once.

## 6. Performance ownership and CareHealth

This review assigned ADR0016's owner to **the implementation lead**, with **an
independent performance reviewer**, under ADR0050. This is an ownership decision, not approval for a reduced
simulation frequency or a native rewrite. The next checkpoint is now, on the
currently integrated needs/ecology/crops/command/planner path; another checkpoint
follows real world/startup and travel/work. Report empty/unseeded stores and
missing systems rather than call the current composition a complete colony.

The 1.19 ms quoted in the brief is an early development-build measurement, not
necessarily current release cost or p99. Read all of ADR0016, including later
release and fused-reader evidence; its original “call overhead is the cause”
claim was narrowed by later experiments. Measure current exported release with
build/PCK/catalog/fixture hashes, 12 and 256 residents, normal ticks and boundary
bursts, 1× and 4× aggregation, and live jobs where actually supported. Pair
comparisons against identical integer inputs/command streams. Do not add
percentiles from separate benchmarks or compare an empty planner with live work.
Windows remains deferred; M5 Pro and RTX5090 results do not establish the floor.

**Phase correction:** stage003 owns integration of the elapsed interval;
stage017 owns health/care commits, after 016 and before 019/020. Split these
responsibilities before RoomHeat or injury-care integration. Use reusable packed
scratch for pending deltas/intents and ensure they are applied exactly once.
Closing-interval exposure still uses the interval's prior climate; moving the
function to 017 must not retrospectively apply newly changed room temperature to
that elapsed interval. Same-boundary completed treatment and health/eligibility
ordering need explicit tests, including death, incapacitation, rescued patients
and worker eligibility between003 and 017.

Do not accept “unobservable today” or “exactly one tick late” without a trace:
health/incapacity already affect selection and WU. This is a semantic phase audit,
separate from optimization. Pin current behavior where it matches the owning
interval rules; record intentional hash changes where a wrong order is corrected.
No cadence reduction, skipped offscreen updates or new health coefficients are
approved by this answer.

## 7. Starter colony — reuse the contracts that already exist

### 7.1 Correct the audit

`inventory.gd` already owns packed InventoryContainer rows, capacity/generation
allocation, `create_container`, reserved/used mass, filters and reachability.
The missing part is the **valid Building/Furniture/Room/service ownership and
composition**, not absence of all containers. Do not create a competing
Container store simply because there is no `container.gd` filename.

The current main scene calls `SettlementSystem.create_initial_settlement()` and
there is a real 12-resident cohort path. It is not connected to a complete legal
starter world. State this distinction rather than saying no inhabitants exist
anywhere. In particular, successful resource binding does not fix bootstrap order.

The claim that starter footprints are “authored nowhere” is false. GDD §5.9 has
exact coordinates and dimensions. Correct `world_init.gd`'s header, ADR0048's
operative claim and task04.3's matching blocker, preserving their historical
mistake as a dated correction.

| Starter building | Origin (tile x,z) | Footprint from §5.9 |
|---|---|---|
| Refuge hall | 58,59 | 12×10 |
| Open stockpiles | 50,60; 50,65; 70,60; 70,65 | 4×4 each |
| Well | 64,54 | 2×2 |
| Workbench shelter | 58,54 | 3×3 |

Rotation0. Interior origin=(59,60), size10×8. Copy §5.9's eight layout rows and
room partition exactly. Each of twelve beds has its access tile below it. The
four pantry shelves provide200000g; four stockpiles provide1600000g total.
There is also an `S` in the kitchen row of the diagram: instantiate that furniture
and distinguish it from the four pantry shelves. **Recommended interpretation:**
only the four pantry-room shelves contribute to the named pantry capacity; do not
silently turn that fifth furniture instance into a fifth pantry shelf.

Clear all building footprints and the GDD one-tile apron plus the authored loam
rectangle before placing resources. This legitimately changes the incomplete
1695-node generator fixture/hashes; recalculate expected nodes, do not protect an
obsolete count by putting trees inside the well/workbench/apron. Shared aprons
may overlap as cleared ground; building footprints may not.

### 7.2 Concrete starter implementation order

1. Compile missing BuildingDefinition/FurnitureDefinition/room domains from the
   owning full catalog using stable keys and the established ASCII policy; the
   inspected `catalog_ids.json` has no BuildingDefinition/FurnitureDefinition
   domain. Publish the complete domain or an explicitly versioned schema, not
   seven runtime-only ordinals that later renumber all buildings. Existing
   layout/cost/capacity rows supply values; display names are not ordering keys.
2. Implement packed starter Building/Furniture/Room components using the existing
   registry fields/allocators; provide generation-checked bed, entrance, work and
   storage contacts. Baseline capacities are already ledgered; do not bill those
   original fields a second time or claim they cover underground expansion.
   Keep dependency-gated services visibly unavailable until real operations exist.
3. Refactor bootstrap into one **prepare/validate/publish** coordinator. Today
   `world_init.generate()` clears the directory and publishes ecology/resources;
   it rejects pre-existing foreign rows. Calling it after residents is refused;
   calling it first and then spawning residents consumes IDs before residents
   can receive1–12. Reserve/prepare the entire plan, reset once after validation,
   publish the resident cohort first with its required IDs, then starter owners
   and resources in explicit stable order. The world is not externally active
   until the whole validated publication finishes. Never disable foreign-row
   validation or reset the directory underneath live owners. Expected refusal
   must occur in preflight and preserve the prior world; fallible publication
   needs real rollback under the adopted memory approach, not a second full world.
4. Create legal existing inventory containers for building owners, with actual
   filters/mass. Assign starter lots food-first then compiled item ID, containers
   ascending as §5.9 says. Attribute STARTER quantities once; buildings begin
   completed without consuming starter stock a second time. Assign resident/bed
   refs by the specified ascending order. **Proposed exact opening positions:**
   each resident starts at the walk tile below its assigned bed, at land y512;
   this is authored initialization detail, not a coordinate already specified.
5. Implement the equipped-lot integration left open by ADR0038/R06§4 alongside
   inventory validation/mass consumers: preserve one item identity and durability,
   with valid equipment owner and permitted null-container rules only for equipped
   lots. Seed 24 tools total, twelve equipped and twelve stored, durability1000;
   tier1 clothing is spawn equipment, not twelve invented outfit_tier2 items.
   Until this integration is complete, mark the full starter fixture partial.
6. Prime valid first-day weather, seed the real RNG once, keep initial orders
   empty, start in PLAYER pause and expose the actual committed state. Use real
   ground contacts/navigation before claiming reachable meals/beds or an FP pass.

This is enough to begin task06's pulled-forward starter slice now; it is not a
request to build full construction before any resident can be shown. Full room
heat, construction/editing, occupied underground, family and scenario scope
remain their owning tasks.

## Execution sequence and acceptance evidence

1. Land the small source/header and catalog-binding corrections (§2/§7.1).
2. Verify the memory reconciliation and performance ownership already recorded
   by this review; do not apply their accounting delta again.
3. Adopt scheduler and Weather layout recommendations with one explicit version/
   migration decision; implement their boundary tests independently of movement.
4. In parallel, complete starter catalog/service composition and the reviewed
   ground-profile/contact contract; implement reference routing and UI now.
5. Wire real travel and work, then run FP-01–12. In parallel the planner authors
   the full G01 parameter pack; do not describe the surface checkpoint as release
   movement. Leave BatchState/LotEffect/NoticeCondition/ChildSliceIndex and other
   named future stores to their dependencies, as the incoming brief requests.

Use the configured six-agent flow. Parser/technical reviewer own contract checks;
implementation lead owns shared composition/spec/ledger; game coder owns assigned
modules; economical test-runner role collects real logs; player QA inspects live
UI and refusal feedback; git manager handles only reviewed assigned work. Give
parallel lanes exact disjoint files. This review used separate bounded weather
and memory audits, followed by main review; their suggestions were not blindly
promoted (the Weather proposal was narrowed to preserve the existing tuple).

Required handoff evidence: exact source revision, new versus inherited fields,
current runner summary, targeted counterexamples, accounting totals, event-boundary
traces, catalog hashes, memory derivation and first divergence. Updating a
comment is not implementation; a test count is not movement, survival or performance
qualification. The existing-worktrees directory was left alone. No game code,
commits, pushes, paid assets or new runtime measurements are part of this review.

## Reproduce this review's static checks

Run `python3 -B docs/validation/ready07_arithmetic.py` from the repository root.
[The script](../validation/ready07_arithmetic.py) checks135 field products,23
allocation rows, current metric arithmetic, all 17 item bindings, proposed 32-byte
scheduler layouts, exact synthetic event-boundary ticks and local links.
[The captured report](2026-09-11_ready07_validation.json) passed. These are source
and arithmetic checks, not 1999 newly run tests or gameplay/performance evidence.
The incoming snapshot is fixed; if sources advance, review changed expectations
instead of treating old line counts/totals as permanent architecture limits.
