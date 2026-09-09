# READY_06 — reviewed answers for the Claude implementation workflow

Date: 2026-09-09. Reviewed checkout: `feat/ecology-rng`, `7764af8` (the register commit after `23056ff`). The supplied file matches `chatgpt-prompts/READY_06_open_items.md` byte-for-byte.

**Status:** planner recommendations for Brendan to hand back to Claude. This review does not implement code, amend the owning specifications, or claim that Brendan already approved newly proposed policies/capacities. If Brendan instructs Claude to adopt this handoff, that instruction supplies approval for the marked recommendations; do not ask again for every individual item. `EXISTING` identifies an inherited contract; `PROPOSED` identifies a precise recommendation to adopt. Incorporate accepted recommendations into their owning GDD/architecture sections and decisions, preserving the historical findings. Do not protect provisional ordinals merely because code already uses them.

The register's 1161 tests / 34,543 assertions are reported implementation evidence, not tests rerun during this document review. No new performance measurements were made here.

## Answers at a glance

| Open item | Recommended answer |
|---|---|
| 1 — job triggers | Player-enabled standing harvest policies; explicit first planting; configured auto-rotation; once-per-day care jobs. |
| 2 — enums | Apply the already-written ASCII compilation rule; separate weather selection order from saved event ID. |
| 3 — pollination links | Six links per farm/orchard recipient, 30720 total references; +49152 link bytes. |
| 4 — gear allocator | Lowest-free pool at the existing 16384 cap; +81924 allocator bytes, +131072 exclusive-Job-claim bytes. Installed-boat identity remains a named follow-on contract. |
| 5 — fishing state | Ratify occupancy and hysteresis, also budget the missing intensive-policy flag; restocking blocks new work unless explicitly overridden. |
| 6 — farming readings | Seeds committed → SOWN; 4 WU finished → GROWING; history counts harvests; compost is a current-season mirror; wither 120 hours after ripening. |
| 7 — redraw exploit | Persist family_streak on tiles; spend the additional 65536 bytes. |
| 8 — ecology limits | Cap regrowth and explicitly choose additive +1 U; three initial habitats within the 32-habitat ceiling; no designation-created stocks. |
| 9 — incomplete fixtures | Assign owners and retain blocked status until actual transaction/UI/save/lease integrations run. |
| 10 — older blockers | Assign performance ownership using current release evidence; define catalog artifact/hash format; enumerate the six GDD golden fixture families. |

## 1. Job creation: standing policies plus condition-driven service jobs

**Answer:** use player-confirmed standing harvest policies, explicit first planting, optional configured automatic rotation, and daily condition-driven care. Do not require a click for every forage unit, fishing cycle, or hive service. Do not enable harvesting simply because an ecological basin was generated.

**Existing context:** ARCH-SYS-009 already gives JobPlanner responsibility for orders, thresholds and field/care service needs on dirty conditions. UI §5's “Plan a safe fishery” already specifies selecting gear/species, quota, priorities, risk and confirmation. REQ-SET-028 permits low-risk FORAGE fallback subject to nonzero resident priority; it does not authorize a new designation, extra quota, or forbidden harvesting. The missing part is the precise producer contract.

**Proposed EARS contracts:**

| ID | Trigger and required response |
|---|---|
| R06-JOB-001 | When a player confirms or enables a valid FORAGE designation bound to an existing basin, JobPlanner shall activate repeat harvest demand subject to the designation and basin's shared daily quotas, floors, availability, protection, legal access and output space. World-generation basin creation alone shall create no harvest demand. |
| R06-JOB-002 | While that demand is enabled, when stock, quota, reservation capacity, output space or access becomes available, JobPlanner shall create eligible FORAGE work against explicitly quantified claims. It shall not reserve the same available quantity twice or bypass the resident's priorities, schedule or danger consent. |
| R06-JOB-003 | When the player confirms a fishery's selected gear/method, explicit species or AUTO selection, and policy, JobPlanner shall activate repeat fishing-cycle demand. A new cycle shall be created only when its species, closure, stock/quota, gear wear, effort slots, crew, access and output obligations can be satisfied. AUTO uses the existing §5.4 species ranking; it does not choose intensive policy or dangerous consent. |
| R06-JOB-004 | When the player confirms the current crop for an EMPTY plot/field, JobPlanner shall request its first sowing cycle. Before publishing sowing jobs it shall apply all REQ-SET-070 gates. Failed plots remain unsown with an explicit reason; a failed gate does not consume seed. Changing a rotation list without confirming planting shall not start work. |
| R06-JOB-005 | When the current configured field planting cycle has finished harvesting/clearing and auto_rotation is enabled, FieldPolicy shall advance its cursor once and request the next configured crop. It shall not advance once per tile, skip blocked entries, or substitute a crop. If its legal window is future, retain the request; if missed, show the existing warning and wait for its next legal window or a player edit. With auto_rotation=false, completion shall not request another sowing cycle. |
| R06-JOB-006 | When an operational, non-abandoned hive enters a spring/summer/autumn service day without that day's completed or pending service, JobPlanner shall create one 20-WU KEEP service job. A hive becoming operational during the day uses the same rule. Winter shall create feed-delivery demand as required, but no tending-labor job. |
| R06-JOB-007 | When a GROWING plot enters a new day without completed/pending tending, JobPlanner shall create its one 1-WU FARM tending service; water is required only under §5.6's moisture condition. Ripe harvest and withered clearing continue to use REQ-SET-073/085. Orchard daily care and legal annual harvest follow the same one-service-period/one-harvest-year pattern under REQ-SET-079/080. |
| R06-JOB-008 | When a relevant policy, stock, season/day, closure, gear, route, reservation or service condition changes, JobPlanner shall mark the affected owner dirty and reconcile its demand before selection. Reevaluation shall be idempotent. Capacity exhaustion shall retain unmet policy demand, report a blocker, and retry when capacity is released; it shall not create a hidden unbounded queue. |

**Lifecycle and ordering:** daily service work is eligible during its service day; midnight settles the preceding day's service/feed outcome before opening the new day's demand. A hive completed mid-day does not receive retroactive service for earlier days. Pending service identity is `(owner EntityRef, operation, absolute service day)`; sowing/rotation identity includes the field cycle. Worker changes preserve the same Job/WIP. These identities and any non-derivable cycle intent must be included in the schema/budget; indexes derived from live jobs may be rebuilt, but completion/policy history may not be discarded.

**Defaults [proposed where not already specified]:** ordinary newly generated work has priority 3, preserving explicit priority-2 ripe harvest and existing rescue/urgency rules. FieldPolicy retains grain/beans/roots, cursor 0, auto_rotation=false, seed_reserve=true. Automatic next-field-cycle advancement waits for all participating plots in the current cycle to resolve, preventing fast tiles from advancing the entire field repeatedly. Erasing a tile is not successful harvest; explicitly cancelled unresolved cycles need a recorded cancellation rather than fabricated completion.

**OrderMode:** preserve ONCE/REPEAT/MAINTAIN_STOCK numeric values. Those currently describe ProductionOrder, whose schema is recipe/building-based. Do not put a habitat ID in `recipe_id` or silently generalize that store. The proposed initial ecology workflow is repeat demand under its own policy; MAINTAIN_STOCK remains a production-order feature until its ecological output accounting is separately specified. Field rotation and daily hive care are not production recipes.

**Implementation boundary:** refine existing DESIGNATE_ZONE, SET_POLICY and SET_FIELD_ROTATION payloads rather than silently renumbering ARCH-CMD-003. Fishery selection and explicit first-plant intent require declared policy/payload fields; derive their packed budgets before merging the producer layer. Sowing gates can be unit-tested independently, but missing command delivery, output bindings or movement must remain explicit blockers. Creating a job does not authorize teleporting its worker into WORK.

**Acceptance:** repeated enable/dirty events create no duplicate claim/service; two workers cannot spend the same quota, effort slot, seed or output reservation; disabled/protected/closed sources create no new work; reopening or midnight recovery resumes demand; auto=false never reseeds; a mixed-duration field advances once; failed seed/output/access gates consume nothing; service is once per day including load/rebuild and worker replacement; winter has no 20-WU hive job. Count these as acceptance requirements, not existing passes.

## 2. Missing enum numbers: apply the existing rule

**Answer [EXISTING]:** GDD §4.2's closing paragraph already says that enum values not individually listed are generated from ascending ASCII catalog keys within their own domain. BAL-CAT-001 repeats that rule; BAL-CAT-002 explicitly includes crop families. The gap is not a missing general numbering policy. It is missing domain/key bindings and code that used display-table order instead.

Use compiled domains for the three fields. Preserve explicitly numbered §4.3 enums; do not add these three as guessed fixed mappings in PROTECTED_ENUM_DOMAINS. Add them to the required compiled-domain/schema registry instead. Reject unknown keys/IDs, and use -1 only where the owner defines absence.

- `FarmPlot.last_family` and TileHistory.last_family reference **CropFamily**. Existing uppercase balance keys compile to CEREAL=0, FIBER=1, LEAF=2, LEGUME=3, ROOT=4; no previous family is -1.
- `Weather.event` references **EventDefinition**: blight=0, calm_days=1, drought=2, early_frost=3, hard_freeze=4, heavy_rain=5, ideal_spell=6, using the existing source keys.
- Bind `FishHabitat.type` to **HabitatType**, with proposed canonical uppercase keys COAST=0, LAKE=1, RIVER=2. The key spelling/domain binding is a new explicit choice; sorting is inherited.

**Weather selection is not ID order.** Keep the already ruled weighted selection traversal `ideal_spell, heavy_rain, drought, blight, early_frost, hard_freeze, calm_days`; select a key in that order, then store its compiled ID. Reindex all event modifier arrays/accessors by the correct domain or explicitly map row→ID. Sorting event IDs must not change WEATHER draw counts or interval boundaries.

**Migration:** old provisional numbers are not interchangeable with the new numbers. Translate any retained development snapshots/replay fixtures through explicit old-key→new-ID maps, or reject them with an unsupported schema/catalog message. No production save module exists yet, but that does not make silent reinterpretation acceptable. Record changed fixture hashes as an intentional ID/schema change, not an optimization parity success. Explicit old→new conversion maps are Habitat `[2,1,0]`, Weather `[6,5,2,0,3,4,1]`, and Family `[0,4,3,2,1]`. Keep stock-row indexing `habitat_typed_row*3+species_index`, but replace any assumption that species catalog identity is `habitat_type*3+species_index` with an explicit habitat-ID-to-species table.

**Acceptance:** shuffled input order produces identical mappings; existing fixed enums remain unchanged; every source-table row maps to the correct key; all WEATHER boundary fixtures keep selecting the same event identities; invalid/old hashes fail before world mutation. Implement the U1 catalog artifact specified below alongside this.

## 3. HivePollinationLinks: define both owner kinds and budget the missing orchard rows

**Answer [PROPOSED owner mapping]:** use one fixed six-reference slice per recipient. A recipient is one FarmPlot tile or one OrchardPlot tree/block, not a whole arbitrary multi-tile designation. This interpretation needs to be stated in §4.2/ARCH-STATE rather than left implicit in “field block.”

```text
recipient_index(FarmPlot typed row p)    = p            # 0..4095
recipient_index(OrchardPlot typed row o) = 4096 + o     # 4096..5119
link_row(recipient, k)                  = 6*recipient_index + k  # k=0..5
```

Keep two I32 columns, hive slot and generation. Capacity becomes **30720 references**, payload **245760 bytes**, an increase of **49152 bytes** over the current 24576-row/196608-byte table. The old arithmetic only covers 4096 farm recipients; it does not provide independent slices for another 1024 orchard recipients. No extra heap is needed for these fixed slices. The owner lifecycle clears its slice, including on typed-slot reuse.

**Lookup rule [PROPOSED deterministic clarification]:** measure horizontal distance from the crop tile center or orchard tree center to the apiary footprint center, matching the existing ground ecology coordinate model. Use the bounding rectangle of the committed, rotated footprint: `center_x=(min_tile_x+max_tile_x+1)*1024`, likewise z. A crop tile has min=max; an orchard uses its 4×4 block. This handles even dimensions without rounding; apiary rotation is resolved before taking the footprint bounds. Use int64 squared distance `dx*dx+dz*dz <= 150994944`, equivalent to inclusive 12 m at 1024 units/m. This does not define vertical/underground pollinator access or close expanded spatial contracts; non-surface recipients need an explicit ecology-access rule before activation.

Select healthy (`strength>=5000`), active, in-range hives; sort by squared distance then persistent hive ID; retain up to six unique generation-checked Hive references and null-fill the tail. For beans/orchard fruit, count 0/1/2+ eligible hives as factors 1000/1100/1150; other crops remain 1000. Do not cache the nearest six *regardless of health* and miss a qualifying seventh hive. Further hives add no yield.

Refresh affected recipient slices synchronously as part of the committed recipient/hive placement, creation, destruction, strength-eligibility or crop-type change, before any dependent simulation read or end-of-tick hash. Yield/UI reads never repair or mutate links. No mid-computation membership changes. Serialize these slices in the declared owner order and validate/recompute against the canonical selection on load before applying a yield; define this deterministically in the save/hash schema. If later classified purely as a derived cache, change serialization/hash treatment explicitly rather than silently trusting stale links. Use one reusable six-candidate buffer: distance I64[6] (48 bytes), persistent ID I32[6] (24 bytes), and hive slot/generation I32[12] (48 bytes), another 120 scratch bytes. No dirty flags are needed under synchronous refresh. Any later reverse index requires its own budget. The +49152 bytes is the link-column delta only; benchmark rebuild cost before assuming it fits.

Acceptance: first/last farm and orchard rows do not collide; six entries per owner never spill into the next; exactly 12 m qualifies and one coordinate unit beyond does not; 0/1/2/7 healthy-hive cases; health crossing 4999/5000 changes eligibility; removing a cached hive discovers a previously seventh candidate; duplicate/stale refs fail; owner reuse cannot inherit links. No hive-building or pollination evidence is claimed until those owner systems exist.

## 4. GearInstance: budget a real child-store allocator

**Answer:** the **16384 GearInstance rows and 540672-byte fixed-field payload are already budgeted**. U5 here is missing allocator/ownership bookkeeping, not missing gear capacity. Use a lowest-free-row pool, following the reservation-pool pattern rather than inventing one gear row per resident or increasing the global entity directory without a ruling.

**Proposed additions:**

| Storage | Bytes |
|---|---:|
| occupied B8[16384] | 16384 |
| free-row min-heap I32[16384] | 65536 |
| free count I32 | 4 |
| exclusive reserved Job slot/generation, two I32[16384] columns | 131072 |
| **Additional packed payload** | **212996** |

Allocator alone is **81924 bytes**; the remaining **131072** identifies the Job that exclusively claims the gear, as REQ-SET-044 requires. This does not include later reverse indexes or cycle-operation state. Do not describe allocator payload as measured total memory or silently absorb new scratch into it.

Initialize all fields before occupancy publication; on release clear the row and return it to the heap. Full-pool creation refuses before consuming materials or creating a loose lot. Save occupancy and authoritative fields; rebuild the heap ascending on load. **No raw gear-row index may escape as a durable handle** under this minimal layout. APIs resolve validated generation-checked lot/owner references and verify the row's recorded identity. If a later consumer needs a persistent GearRef, add and budget independent generations/retirement explicitly first.

**Instance eligibility [PROPOSED explicit predicate]:** the portable instance-required keys are `tool`, `net`, `trap`, `ice_kit`, and `outfit_tier2`. Basic versus iron tool manufacture uses the existing recipe metadata, not a fabricated new item ID. `candle` remains stackable consumable inventory even though its category is GEAR. Tier-2 outfits retain identity for equipment transfers but have canonical durability/cap 0/0 with wear/repair operations rejected as inapplicable; this introduces no clothing degradation mechanic. Starter tier-1 clothing remains the existing spawn-equipment tier, not an invented ItemDefinition. Test this named predicate independently of the broad item category.

**Equipped portable gear [PROPOSED explicit inventory amendment]:** keep the same indivisible quantity-1000 lot and GearInstance alive while equipped. `InventoryLot.container=NULL_REF` is permitted only for a validated equipped/installed gear record with a live owner; it is not permission for arbitrary orphan lots. Exclude it from loose-stock availability and container/satchel mass. Equip/unequip atomically change that ownership relation and Equipment mirrors; unequip places the same lot into a valid reserved destination. Never clone it, merge it, reset durability, or count it once as equipped and again in storage. This requires inventory validation and consumers to change together; the allocator alone does not authorize null-container lots. The twelve equipped starter tools remain part of the twenty-four total tools.

Gear is claimed by the cycle/coordinator Job, not each worker. Refuse a second owner, repair/equipment swaps while claimed, or a cycle whose available durability is below its specified wear. Freeze the cycle's gear/method/wear contract before commitment. Completion applies wear once; cancellation before completion releases claims under the existing cycle policy. General-tool 1000/1500 caps and 10-WU remainder wear remain distinct from fishing gear's 1000 cap and per-cycle wear; preserve the two different repair recipes. Do not turn gear repair into a full durability reset.

**Limit of closure:** this answers the allocator and portable-gear lifetime questions. Boats/weirs are explicitly installed, not ItemDefinition inventory output. Allowing a null gear lot is appropriate only when a valid installed owner provides identity and a declared gear-kind mapping. The current lack of a fully specified boat owner/instance discriminator must be resolved in the expedition/installed-gear contract; do not mint a fake boat InventoryLot or assume a boathouse is identical to every boat it services. Hand-net/portable gear work can proceed without pretending that installed-boat representation is settled. Record any new installed-owner capacity, discriminator and directory delta before implementing it.

Acceptance: allocate through slot 16383; full refusal is atomic; lowest freed row is reused deterministically; stale lot/owner/job handles fail; equip/unequip preserves identity, age/provenance, quantity and durability; two jobs cannot claim one gear object; exact-wear start succeeds and one-below refuses; completion/cancellation repeats cannot double-debit/release; repair clamps to its correct cap; active and equipped records round-trip once the save module exists.

## 5. Fishing occupancy and depletion policy

**Answer [PROPOSED schema ratification]:** keep `FishHabitat.effort_used:I32[32]` (+128 bytes) and `FishStock.restocking:B8[96]` (+96 bytes). Also account for the implementation's saved `FishHabitat.intensive_harvest:B8[32]` (+32 bytes), which is missing from the ledger: **256 bytes total for these three columns**, before any cycle-ownership indexes.

Effort is measured in slots, not worker count. A cycle must atomically reserve its full gear requirement: one for net/trap/ice kit; two for weir/boat. Preserve river/lake/coast capacities 4/6/6. Two single-slot calls without rollback are not a safe two-slot admission API. Maintain a cycle/Expedition-owned claim so completion, cancellation and stale calls release exactly that owner's slots once. Rebuild/validate the aggregate against live claims on load; a stored total alone cannot prove ownership. Use a fixed `FishingEffortClaim` slice indexed by Expedition typed row (512 rows): `active:B8`, `expedition_generation:I32`, `habitat_slot/generation:I32×2`, `job_slot/generation:I32×2`, `slot_count:I32`. This is six I32 columns plus one B8: **12800 bytes**, no child heap. Validate the incoming Expedition reference through the directory, then its stored generation; only its coordinator Job owns the claim. Claim publication/withdrawal and effort_used change atomically. Null/zero unused rows; reject mismatched owner generations or aggregate totals on load. This new claim budget is additional to the 256-byte aggregate/policy addition.

**Recommended policy:** “default to restocking” blocks new harvest cycles for the affected stock while its latch is set; it is not just a warning. An explicitly enabled intensive policy may bypass this soft stop down to the existing 10% hard floor, but never closures, unavailable species, quota, danger consent or required gear. Preserve the player's explicit intensive choice rather than silently inventing an automatic policy reset or a new confirmation after every cycle. Continue to show the depletion warning and active override. Update the latch independently of the override so disabling intensive immediately restores the correct restriction.

Exact stock transitions [inherited strict comparisons]: enter when `100*P < 30*K`; clear when `100*P > 40*K`; otherwise retain its previous value. Thus equality at 30% or 40% does not flip the latch. Use checked arithmetic or a proved safe equivalent. Successful existing reservations follow their cycle contract; lowering policy prevents new claims and revalidates uncommitted departures. Never retroactively recreate consumed fish or silently refund spent work.

Acceptance: three of four river slots used → two-slot request refuses without change; one-slot request succeeds; double/stale release cannot free someone else's slots; test both sides and exact 30/40% boundaries, explicit intensive toggle, closed species, and round-trip claim/aggregate validation. Cancellation of one party member must not release the coordinator's whole active cycle claim.

## 6. Farming: settle all five readings

1. **SOWN/GROWING [PROPOSED clarification]:** queued/reserved/travelling sowing leaves the plot EMPTY with a separate outstanding Job. At productive start, consume the exact crop seed quantity and create its persistent sowing WIP atomically; state becomes SOWN. Existing crops require 250 milli-U seed and 4000 milli-WU sowing per tile. Only successful sowing completion enters GROWING. No hourly growth or growing-crop tending/frost/blight applies to SOWN. Worker changes preserve WIP and cannot consume seed again. Before productive start, explicit cancellation releases reservations and leaves EMPTY without seed loss. After seed commitment, explicit cancellation discards the committed seed and unfinished sowing WIP with no seed/compost refund, returns the plot to EMPTY, and preserves soil/family/compost history and XP already earned from valid work. This is a proposed sowing-specific cancellation rule, not the food-batch refund rule. A worker replacement or pause is not this cancellation.
2. **Family streak [EXISTING wording made explicit]:** counts successful completed tile harvests, not sowings. Same family increments; different family resets to 1; withering, fallow time, unfinished sowing and redraw neither reset nor advance it. Use the prior completed history when calculating the current crop's yield, then update history once after successful harvest. A first LEGUME crop is 1000; 1100 requires a prior different family. Saturate the streak at INT32_MAX: if already at the maximum, retain it; otherwise increment. This proposed bound preserves all first/second/third+ yield behavior without overflow; never evaluate an overflowing addition.
3. **`compost_milli` [PROPOSED clarification]:** retain the required GDD field as the quantity successfully applied to this tile **during the current absolute season**, either 0 or 2000. It is not an input buffer, recoverable inventory, lifetime counter, or the eligibility authority. `TileHistory.compost_season` remains authoritative. At plot creation/redraw/load derive or validate the mirror: 2000 iff the tile's application season equals the current absolute season; otherwise 0. Reset the mirror at a season boundary without clearing tile history or fertility. At application completion, atomically consume 2000 milli-U, apply the capped fertility gain, set the tile's absolute season and update the mirror. Preserve the 8-WU service. This resolves the current stale-across-seasons/redraw interpretation without deleting a required field.
4. **Ripe clocks [PROPOSED exact boundary]:** both use the same `ripe_tick`. Keep a 48-hour grace followed by completed 24-hour decay intervals, and wither at elapsed **120 hours**, not 168. The first 10% loss is at 72 hours, the second at 96; at 120 the crop is WITHERED and cannot complete a normal harvest. While harvestable, `loss_count=max(0,floor((elapsed_hours-48)/24))`; apply each loss as `yield_milli=floor(yield_milli*900/1000)`. Do not apply a third *harvestable* decay step at 120. A 100000-milli-U fixture is 100000 just before 72h, 90000 at 72h, 81000 at 96h, then not harvestable at 120h. This formalizes full-day discrete losses; it does not mean the grace itself was extended to 72h. Retain hourly/tick remainder and ripe timestamp so load/redraw cannot restart either clock.
5. **Crop-family values:** use item 2's compiled CropFamily domain, including tile history and every family-indexed lookup.

Acceptance: no seed on a failed preflight; start consumes once; replacement worker finishes the same 4000-milli-WU task; SOWN has no growth; a failed/zero-health crop leaves family history unchanged; test compost application/redraw/reload in the same season and eligibility next year; test ripe timing immediately before/at/after 48/72/96/120 hours and repeated updates. Withering/clearing and output creation still require their owning transaction, not a duplicated reward from two callbacks.

## 7. Persist the entire crop-family streak

**Answer [PROPOSED]: spend the 65,536 bytes.** Add `TileHistory.family_streak:I32[16384]`. Its seven-I32-column group becomes **458752 bytes**, formerly 393216. This does not replace or absorb the separate ripe/growth/service columns; update every affected total and save schema.

Tile history owns `(last_family,family_streak)`. Plot rows mirror it. Update both atomically on completed harvest; restore both on redraw and validate their consistency on load. Initial `(-1,0)` means no prior harvest. A populated family paired with zero streak must not be silently treated as known complete history; any legacy snapshot with missing counts needs explicit migration or rejection.

The existing 700→850 change is still a designation exploit even though it cannot reach 1000. Do not trade away this requirement to preserve the smaller payload figure. Test two same-family harvests → erase/recreate → next same-family harvest still 700; family change still gives 1000, or 1100 for LEGUME. Invalid/stale plot references must not alter tile history. Soil identity comes from world generation, not from whichever soil a redraw caller declares; that separate integration gate also remains explicit.

## 8. Regrowth cap and habitat count

### 8A. Regrowth: cap it, and resolve the additional max-versus-plus discrepancy

**Answer:** stock must remain in `[0,K]`; minimum recruitment cannot overfill a nearly full patch. There is a second discrepancy the register does not spell out: current `daily_regrowth_milli_into()` uses `max(1000, calculated_growth)`, whereas GDD §5.5 says “plus a minimum 1 U,” BAL-CONFLICT-012 explicitly identifies max-versus-plus as a separate clarification, and the approved automatic-quota reference uses an additive 1000.

**Recommended clarification [PROPOSED]: use the additive interpretation consistently.** For nonnegative validated stock `P`, capacity `K`, regrowth `r`, and season availability `S`:

```text
if S == 0 or P == K:
    growth = 0
else:
    growth = min(K-P, floor((K-P)*r*S/1000000) + 1000)
P_next = P + growth
```

Reject malformed `P>K` instead of hiding corrupt state. This preserves the growth coefficient and the approved quota policy; it requires changing the current max-based ecology calculation. For a 500-milli-U gap with r=60,S=300: raw 9+1000 is capped to 500. For a 100000 gap with those factors: growth is 2800, not 1800. These two fixtures distinguish capacity safety from the max-versus-plus choice. Dormant and full patches grow zero. Update the owner formula, tests, module comments and any affected balance probes; do not call changed ecology hashes optimization parity.

### 8B. Fishing: three generated habitats, capacity for 32

**Recommended reconciliation:** the specified initial estuary generates exactly one stock-owning river basin, one lake basin and one coast basin, nine FishStock rows total. Their capacities sum to 2100/2200/3100 U respectively, with species stocks initially at 80%. The 32 habitats/96 stocks are allocation ceilings, not instructions to generate 32 copies of the starting resources.

Only world generation or an explicit ecology-creation operation may create a habitat and its stocks. A player FISH designation binds to existing ecological ownership; overlapping, splitting, deleting, protecting or redrawing it does not create/reset fish, quota history, restocking state or effort capacity. Multiple designations share the same habitat's totals. Existing `FishHabitat.zone` binds to its owning basin, not an arbitrary disposable player designation; resolve designation→existing direct HarvestZone.basin→the unique FishHabitat whose zone equals that basin reference. Validate both generations and require exactly one match. Scan the bounded 32 habitat rows at binding/revalidation, so this contract adds no inverse-map column. Missing, chained, cross-basin or duplicate matches refuse. Player commands cannot invoke the ecology-owner creation path. Future scenarios can contain multiple genuine disconnected basins within the ceiling, but that does not alter this scenario's guarantee or authorize map editing to mint stock.

Acceptance: initial 3/9 counts and exact biomass; alternate designation histories leave identical basin stock/quota/occupancy; cross-basin or stale bindings refuse; ecology allocation beyond 32 refuses atomically. This extends the anti-multiplication principle of accepted R05-BASIN-001–005 to fisheries without inventing a global fish counter.



## 9. Integration fixtures: keep them blocked and give each a concrete owner

**Answer:** these are implementation dependencies, not specification passes to waive. Distinguish a module unit test, an in-process rebuild, and the actual cross-process/integrated acceptance gate.

| Evidence | Required next implementation and acceptance |
|---|---|
| R05-QTEST-12 | Save/replay owner: implement the release-format save/load path under ARCH-SAVE-001/002; save active claims, exit, load in a second process, and compare the complete required state plus every subsequent verification tick under identical commands. A final subset digest or isolated-control codec does not close this. |
| R05-QTEST-14 | Commands/UI owner: deliver the single-basin preview and accepted command path; test displayed bounds, rejected cross-basin extension, cancel-without-mutation, and exactly one command per confirmation. Preview must not create stock. |
| R05-QTEST-15 | Jobs/inventory integration owner: bind reserved output container/mass/lot capacity to the Job, retain those obligations through WIP, and fault-test full capacity at commitment. Already-consumed inputs must not disappear because output allocation failed. |
| R05-QTEST-07 | Jobs/ecology/inventory transaction owner: combine quota-claim consumption, ecological stock debit and inventory cargo creation atomically. `collect_claim()` returning an amount is insufficient. Preflight every possible refusal, or journal and roll back all touched owners; injecting cargo-allocation failure must leave stock, claim and quota unchanged. |
| R05-QUOTA-007 | Jobs/movement lifecycle owner: implement actual lease renewal/expiry and call the existing cancellation/release path. ARCH-JOB-004 already specifies renewal every 30 ticks, expiry after 300 ticks without renewal, and confirmed-unreachable retry after 900 ticks or map revision. A queued route or occupied crossing is not proof of unreachable geometry. |

**Sequence:** command transport and persistent policy semantics → producer-to-reservation/output bindings → headless transactional integration → actual movement-dependent lifecycle → preview/UI and full save/replay gates as their owners become available. Independent save codec work may proceed in parallel. Test adapters may expose explicit reachability/gear gates; they are not release movement implementations. Do not use “no save module yet” to omit future-affecting columns now.

## 10. Performance ownership, U1 catalog persistence, and U7 golden fixtures

### 10A. Decision 0016: assign an owner and use current evidence

**Answer:** keep the qualification issue open, but replace “owner unassigned” with **implementation lead, with independent performance review**. Give it a dependency-ready task and a checkpoint after the task-03 integrated ecology/needs/work path exists. Do not leave the next action as “optimize later.”

The register's one-line account is stale. ADR 0016 now records the reader work, lazy persistent-ID retrieval, caller-owned TickResult, verified release-template exports, and the fused reader. ADR 0024's ordered optimization work is complete. Do not send Claude back to implement those changes again or repeat our earlier “no release templates” limitation as current fact.

The recorded release comparison reported combined p99 of **2160–2700 µs at 256 residents** on the M5 Pro at that stage. The later fused-reader report gives pooled medians of **1515 µs WU-only mixed bands**, **1228 µs parties**, and **1767.5 µs uniform**, with run ranges and permutation tests in its evidence. These are different workloads/stages and must not be added or substituted for a newly measured whole tick. They do not include the newly added ecology work as an integrated release loop, and none qualifies the required Windows floor. This review inspected existing reports; it did not measure these numbers again.

**Recommended next experiment [PROPOSED]:** evaluate a column-oriented needs implementation against the retained reference integrator, with unchanged 30-Hz observation/threshold timing. This selects a bounded experiment under 0016 option 2, not permission to replace the release path before validation. Do not stagger needs, introduce cached-factor invalidation, or migrate to native code as an unmeasured incidental change. If it cannot provide useful whole-tick headroom while preserving behavior, return a measured native-kernel proposal rather than deleting checks blindly.

Require the retained interleaved before/after protocol, unchanged-code drift controls, mixed-band/uniform/party/finishing-tick workloads, current release code/PCK hashes, 12 and 256 residents, and every-tick state/threshold parity. Include feeding, health/memory mutation, XP thresholds and same-tick job interruption. Re-measure the integrated whole tick and actual scheduler frame aggregates; the consecutive-pair proxy is insufficient for catch-up frames. No new guaranteed sub-budget is invented here. Windows testing remains deferred by Brendan; REQ-SET-163 cannot be marked passed using the M5 Pro or the 5090 machine.

### 10B. U1: specify `catalog_ids.json` now

**Recommended artifact contract [PROPOSED]:** generate at authoring/build time into `godot/data/catalog_ids.json`, commit it, and include it in exports. Runtime compiles/validates the same domains and compares them with this artifact; it does not silently rewrite it on startup or load.

Logical shape:

```json
{"domains":{"CropFamily":{"CEREAL":0,"FIBER":1,"LEAF":2,"LEGUME":3,"ROOT":4}},"ruleset":"settlement_rules_v2","schema_version":1}
```

The snippet illustrates the shape; it is **not** the complete catalog. `domains` must contain all required enabled definition/enum domains from an explicit build registry, including protected fixed enums. Each domain maps case-sensitive ASCII keys to int32 IDs. Fixed enums preserve explicit values (including gaps); all other domains use ascending-key IDs starting at zero. Reserved numbered entries remain present. Empty-reference sentinel -1 is not a generated catalog entry. Reject duplicate object keys, duplicate IDs within a domain, noninteger/out-of-range IDs, omitted required domains, and unknown schema versions.

Canonical bytes: UTF-8, no BOM; object keys sorted ascending ASCII at every level; no insignificant whitespace; one final LF; integer decimal spelling without leading plus/zeros. Define and test JSON escaping explicitly (standard short escapes for quote/backslash/control characters, lowercase `\\u00xx` for other controls); symbolic domain/entry keys must pass the existing ASCII-key validator. The artifact is produced by one canonical encoder and loader verification compares exact canonical bytes, not platform pretty-printing.

`catalog_hash = SHA256(canonical catalog_ids.json bytes)`. Save-header offset **72** contains those raw 32 digest bytes. `CATALOG_IDS` section **2** contains a little-endian u32 byte length followed by those same canonical bytes; its section descriptor's schema_version is 1 and row_count is the number of domain entries across all domains. No duplicate embedded hash is needed. Validate the embedded mapping, digest and installed catalog before mutating the live world. A mismatch refuses with a catalog/version error unless an explicit migration exists; it does not reassign live IDs.

Rules hash remains the separate offset-40 hash. A matching ID map does **not** prove unchanged numerical definitions; rule/definition content validation must still occur through its own rules/content contract. Map, lookup and engine hashes remain separate. This ruling closes the catalog-artifact ambiguity only, not the entire save implementation or any still-missing rules-hash serializer.

Acceptance: different definition insertion orders give identical artifact bytes/hash; a one-byte/key/ID mutation fails; fixed enums and reserved slots survive; JSON duplicate keys are rejected; altered numeric definitions cannot masquerade as an unchanged ruleset merely because the ID mapping is unchanged; a load mismatch leaves the current world intact. Do not emit a partial artifact and call it release-complete.

### 10C. U7: enumerate the six existing GDD §7.1 fixture families

**Answer [EXISTING examples, PROPOSED explicit acceptance registry]:** make these the required golden arithmetic set. Add a manifest mapping each ID to its owner, exact expected integers, implementing tests, and separate module/integration status.

| ID | Existing §7.1 fixture and exact anchors |
|---|---|
| R06-GOLD-001 | Demand: 200 small = 1,200,000 NP/day, winter 1,440,000; mixed 120/60/20 = 1,344,000, winter 1,612,800. |
| R06-GOLD-002 | Grain: 64 tiles at fertility 7000 yield 544000 milli-U after 192 ideal growth hours; seeds 16000 milli-U; sow/tend/harvest 256/512/384 WU; 272 porridge batches, 979200 NP before seed replacement, 972000 after; 544 water U, 3264 cooking WU, 27.2 wood U. |
| R06-GOLD-003 | Winter reserve: 17,280,000 NP; 8280000 milli-U ration with reserve margin; 2760 batches; 5520 flour and 2760 each dried_fish/nuts/water U; 66240 WU; 4,140,000 g, five cellars. |
| R06-GOLD-004 | Starter: 408000 ready NP; mixed starter demand 74400 NP/day; 548 centi-food-days. Exclude uncooked grain; do not count roots twice. |
| R06-GOLD-005 | Recipe quality: score 66 → GOOD; three fish-stew portions = 6930 NP; bind R=0 once and do not reroll on worker replacement. |
| R06-GOLD-006 | Mood: 6200 baseline → 6500 with good meal → 4700 after lost friend; the stated latter mood factors remain 1000. |

Several already have tests in `test_int_math.gd`; starter readiness/forecast also has production-consumer tests in `test_economy_system.gd`, and mood uses the needs store in `test_needs.gd`. Inventory these rather than reimplementing them. The recipe-quality subsystem and full crop-to-kitchen chain are not proven merely by helper arithmetic. Keep arithmetic pass and real-module/integration pass separate. The current source review did not establish a production recipe-quality fixture pass.

This manifest is a minimum named arithmetic set, not the complete test plan. Retain conservation, stale references, saturation/overflow, clock/debt, RNG, lifecycle, amendment fixtures, BAL-PROBE-001, and three-year economic runs under their existing requirements. Listing a blocked golden integration fixture does not waive it.

## Execution handoff

Recommended immediate order: fix compiled ID/domain contracts and specify U1 → preserve family streak and settle farming/fishing boundaries → implement gear allocator and pollination lookup → declare producer intent/bindings and implement field/hive producers → complete quota/cargo/output/lease transactions and runtime integration. U7's fixture inventory and independent save work can run in parallel; performance has the explicit owner/checkpoint above. Continue unrelated foundation work when a movement-dependent gate is unresolved.

Before treating an item as closed, amend its owning specification, reconcile packed payload/allocator/scratch/save accounting, implement the code, execute the listed acceptance tests, and update the relevant ADR/task with actual evidence. This handoff's new `R06-*` labels do not silently renumber existing requirements. Do not count publishing these answers as implementation completion.

## Source map

- [Incoming register](../../chatgpt-prompts/READY_06_open_items.md)
- [Authority](../../AGENTS.md), [GDD](../game_gdd.md), [balance](../gameplay_balance.md), [architecture](../systems_architecture.md), [UI flows](../ui_ux_controls.md)
- [Task 03](../tasks/03_ecology_crops_weather.md), [task-02 blockers](../tasks/02_settlement_foundation.md)
- [Previously approved task-03 rulings](2026-09-09_task03_planner_rulings.md)
- [Performance decision 0016](../decisions/0016-needs-tick-consumes-most-of-the-budget.md), [execution order 0024](../decisions/0024-work-tick-optimization-order.md)
- [Fishing state 0027](../decisions/0027-fishing-needs-two-columns-4-2-omits.md), [farming 0032](../decisions/0032-farming-interpretations-and-open-contracts.md)
- [Release evidence](../../validation-results/work-release-2026-09-08/), [fused-reader evidence](../../validation-results/work-fused-2026-09-08/pooled-before-vs-after.md)
