extends RefCounted
## Drives the REAL fishing store (`scripts/core/fishing.gd`) for the demo's water, on demo-clock game
## time. Decision 0196 (live demo), water foundation. Every number of the fishery -- stocks,
## recovery, seasonal availability, closures, the daily quota, the conservation floors, the 30/40
## restocking latch, the catch formula and effort slots -- is fishing.gd's own; nothing here forks
## its arithmetic. This module adds only what §5.4 states and the store deliberately leaves to its
## caller, each cited below, and it writes into NO pantry or inventory: a cycle's catch comes back
## as lots (species + quantity) for phase 2 to wire.
##
## ---------------------------------------------------------------------------------------
## HABITATS. `create()` runs the store's own `generate_initial_estuary()` -- ruling READY_06 §8B's
## world-generation operation: exactly one coast, lake and river basin, nine stocks at §5.4's 80%
## -- with the nine compiled item ids re-addressed habitat-major through fishing.gd's
## HABITAT_SPECIES_ROWS, exactly as world_init.gd does. The demo's water binds to two of them:
##   * the STREAM is the RIVER habitat -- trout, dace, salmon;
##   * the POND is the LAKE habitat -- perch, carp, whitefish.
## The COAST habitat (herring, mackerel, mussel) exists in the store and has no demo water: this
## village has no coast. The stream's RUN and its FORD are two fishing SITES on the one river
## habitat -- §5.1 "one stock basin of each habitat type; dividing a player zone never creates extra
## ecology stock", and MOVE-TEST-07's "one stock balance ... no separate swimmer stock".
## Eels and pike are hazard encounters, never catch (REQ-SET-056; pantry.json policy
## `hazards_not_food`); freshwater shrimp is not a game fish (pantry.json `fish_whitelist` is the
## nine above, and its game-only map turns "shrimp" into mussel). The content library's pantry is
## NOT_RUNTIME_ACTIVE, so nothing here reads it at run time.
##
## TIME. `advance_usec()` turns demo-clock microseconds (0 while paused) into whole fixed ticks
## (30/s, remainder carried), and at every `SimClock.is_day_boundary` crossing runs §5.4's midnight
## exactly as ecology.gd's fish leg does: `reset_harvested_today()`, then `recover_daily()` on the
## NEW day's season and season-day.
##
## CYCLES. `begin_cycle()` refuses anything §5.4 / REQ-SET-046..050 forbid before a single slot is
## taken, then reserves the gear's WHOLE effort-slot requirement atomically through the store's
## `reserve_effort_slots()`, owned by a real Expedition row and a coordinator FISH Job
## (decision 0017) -- a full habitat refuses with EFFORT_SLOTS_FULL, which is REQ-SET-050's "queue
## further fishers". `complete_cycle()` takes the store's own `catch_milli` (already limited to the
## remaining quota and the stock above the policy floor), debits exactly that with `harvest()`,
## releases the slots and returns the lot. `resolve_cycle()` is the two in one call.
##
## CITED FROM GDD §5.4's GEAR TABLE (the store keeps `base_catch_milli` as an argument precisely
## because it is a gear column): base catch U/cycle, wear/cycle, work WU, base injury chance per
## 10000, trap species ("dace/perch/carp/mussel"), hand net's "all species except offshore
## mackerel", the weir's "River only; flow 4-12 m wide", and the injury formula
## `max(1, base*(1+danger) - 2*crew_skill - 4*additional_crew)` shown before authorisation
## (REQ-SET-055). Gear per site is the demo's: nets and traps from every bank, the weir at the run,
## the boat from the boathouse on the pond.
##
## NAMED BLOCKERS -- not implemented, not invented:
##   * GEAR DURABILITY AND WEAR. gear.gd owns GearInstance durability; the demo owns no gear
##     objects, so no durability is reserved (REQ-SET-044) or worn (REQ-SET-045). Wear/cycle is
##     published for display only.
##   * THE HAZARD ROLL, INJURY AND RESCUE (REQ-SET-053/054). ARCH-RNG-002's FISHING draw belongs
##     to the cycle's owner "which does not exist yet" (rng.gd), and injury needs the resident and
##     injury stores. The risk number and each site's bank landing point (the rescue point) are
##     published; the roll is phase 2's.
##   * THE RARE-QUALITY ROLL -- the same FISHING stream. Every lot is PLAIN.
##   * UNLOCKS (M1 trap, M2 weir, M3 boat), WINTER ICE (REQ-SET-051: the ice kit is offered nowhere)
##     and STORMS (REQ-SET-052) are not evaluated: the demo runs no milestones or weather.

const Fishing := preload("res://scripts/core/fishing.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const CatalogBinding := preload("res://scripts/core/resource_catalog_binding.gd")

const SITE_RUN: int = 0
const SITE_FORD: int = 1
const SITE_POND: int = 2
const SITE_COUNT: int = 3
const SITE_KEYS: Array[StringName] = [&"stream_run", &"ford", &"pond"]
const SITE_HABITAT: Array[int] = [Fishing.HABITAT_RIVER, Fishing.HABITAT_RIVER, Fishing.HABITAT_LAKE]
## Each site's bank landing (water_layout.gd): where a fisher enters and where a rescue happens.
const SITE_LANDING: Array[StringName] = [&"fisher_shelter", &"ford_west", &"boathouse"]

## GDD §5.4 gear table, indexed by fishing.gd's gear rows (boat, hand_net, ice_kit, trap, weir).
const BASE_CATCH_MILLI: Array[int] = [36000, 8000, 6000, 12000, 30000]
const WEAR_PER_CYCLE: Array[int] = [15, 20, 20, 10, 5]
const WORK_MWU: Array[int] = [120000, 60000, 90000, 40000, 30000]
const INJURY_BASE_PER_10000: Array[int] = [20, 12, 24, 8, 5]
const TRAP_SPECIES: Array[int] = [
	Fishing.SPECIES_DACE, Fishing.SPECIES_PERCH, Fishing.SPECIES_CARP, Fishing.SPECIES_MUSSEL,
]
const HAND_NET_EXCLUDED: Array[int] = [Fishing.SPECIES_MACKEREL]
const WEIR_MIN_WIDTH_U: int = 4096
const WEIR_MAX_WIDTH_U: int = 12288
const INJURY_MIN_PER_10000: int = 1
const INJURY_SKILL_TERM: int = 2
const INJURY_CREW_TERM: int = 4

## Gear offered at each site, as bit masks over the gear rows (see the header).
const SITE_GEAR_MASK: Array[int] = [
	(1 << Fishing.GEAR_HAND_NET) | (1 << Fishing.GEAR_TRAP) | (1 << Fishing.GEAR_WEIR),
	(1 << Fishing.GEAR_HAND_NET) | (1 << Fishing.GEAR_TRAP),
	(1 << Fishing.GEAR_HAND_NET) | (1 << Fishing.GEAR_TRAP) | (1 << Fishing.GEAR_BOAT),
]

const JOB_KIND_FISH: int = Catalog.JOB_KIND["FISH"]
const USEC_PER_SECOND: int = 1000000
## Days scanned forward for a closed species' reopening (a whole year).
const REOPEN_SCAN_DAYS: int = SimClock.DAYS_PER_YEAR

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_SITE: StringName = &"INVALID_SITE"
const REFUSE_GEAR_NOT_AT_SITE: StringName = &"GEAR_NOT_AT_SITE"
const REFUSE_GEAR_SPECIES: StringName = &"GEAR_CANNOT_TAKE_SPECIES"
const REFUSE_NEGATIVE_TICK: StringName = &"NEGATIVE_TICK"
const REFUSE_SPECIES_IDS: StringName = &"SPECIES_ID_COUNT"
const REFUSE_NO_HABITAT: StringName = &"NO_HABITAT_OF_TYPE"
const REFUSE_NOT_A_CYCLE: StringName = &"NOT_AN_OPEN_CYCLE"


class CreateResult:
	"""`create()`'s outcome: the driver, or the refusal that stopped it (driver null)."""
	var ok: bool
	var error: StringName
	var driver: RefCounted

	func _init(p_ok: bool, p_error: StringName, p_driver: RefCounted) -> void:
		"""Store the outcome."""
		ok = p_ok
		error = p_error
		driver = p_driver


class IdsResult:
	"""`resolve_species_item_ids()`'s outcome: nine ids in fishing.gd SPECIES_KEYS order, or why not."""
	var ok: bool = false
	var error: StringName = &""
	var ids: PackedInt32Array = PackedInt32Array()


class Preview:
	"""REQ-SET-055's pre-authorisation figures for one site, species and gear (caller-owned)."""
	var ok: bool = false
	var block: StringName = &""
	var species_row: int = 0
	var species_key: StringName = &""
	var stock_milli: int = 0
	var capacity_milli: int = 0
	var depleted: bool = false
	var restocking: bool = false
	var availability_per_1000: int = 0
	var closed: bool = false
	var reopen_season: int = 0
	var reopen_day: int = 0
	var quota_milli: int = 0
	var remaining_quota_milli: int = 0
	var expected_catch_milli: int = 0
	var base_catch_milli: int = 0
	var wear_per_cycle: int = 0
	var slots_needed: int = 0
	var slots_free: int = 0
	var slots_total: int = 0
	var must_queue: bool = false
	var injury_per_10000: int = 0
	var landing: StringName = &""


class Cycle:
	"""An open fishing cycle: its effort claim's owners and what it fishes."""
	var ok: bool = false
	var error: StringName = &""
	var expedition: Vector2i = EntityDirectory.NULL_REF
	var job: Vector2i = EntityDirectory.NULL_REF
	var site: int = 0
	var species_index: int = 0
	var gear: int = 0


class CatchLot:
	"""One caught lot: a species and its quantity -- never a generic "fish" (BAL-CAT-004)."""
	var species_key: StringName = &""
	var species_row: int = 0
	var item_id: int = 0
	var quantity_milli: int = 0
	var site: int = 0
	var landing: StringName = &""


class CatchResult:
	"""A completed cycle: the lots caught (possibly none -- a true zero catch), or a refusal."""
	var ok: bool = false
	var error: StringName = &""
	var quantity_milli: int = 0
	var lots: Array[CatchLot] = []


var _fishing: Fishing = null
var _jobs: JobsScript = null
var _habitat_ref: Array[Vector2i] = []
var _species_ids: PackedInt32Array = PackedInt32Array()
var _site_gear: PackedInt32Array = PackedInt32Array()
var _tick: int = 0
var _tick_carry: int = 0
var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)
var _scan: SimClock.Calendar = SimClock.Calendar.new(0)
var _math: IntMath.IntResult = IntMath.IntResult.new()
## Bumped whenever a stock, a quota or the calendar day changes, so a display redraws only then.
var revision: int = 0


static func create(species_item_ids: PackedInt32Array, start_tick: int,
		run_width_u: int) -> CreateResult:
	"""A driver over a fresh store with §8B's estuary, starting at `start_tick`. `species_item_ids`
	are the nine compiled ids in fishing.gd SPECIES_KEYS order; `run_width_u` is the stream's width
	at the weir (a weir is offered at the run only if it is 4-12 m, GDD §5.4)."""
	if species_item_ids.size() != Fishing.SPECIES_COUNT:
		return CreateResult.new(false, REFUSE_SPECIES_IDS, null)
	if start_tick < 0:
		return CreateResult.new(false, REFUSE_NEGATIVE_TICK, null)
	var driver := new()
	var code: StringName = driver._open(species_item_ids, start_tick, run_width_u)
	if code != REFUSE_NONE:
		return CreateResult.new(false, code, null)
	return CreateResult.new(true, REFUSE_NONE, driver)


static func resolve_species_item_ids() -> IdsResult:
	"""The nine fish species' compiled ItemDefinition ids, resolved by key through the verified
	catalog boundary (resource_catalog_binding.gd), in fishing.gd SPECIES_KEYS order."""
	var out := IdsResult.new()
	var items := ItemDefinitionsScript.new()
	var loaded: ItemDefinitionsScript.LoadResult = items.load_from_file(
		ItemDefinitionsScript.DEFAULT_JSON_PATH, InventoryScript.new())
	if not loaded.ok:
		out.error = &"ITEM_DEFINITIONS"
		return out
	var opened: CatalogBinding.OpenResult = CatalogBinding.open(items)
	if not opened.ok:
		out.error = opened.error
		return out
	var bound: CatalogBinding.BindResult = (opened.boundary as CatalogBinding).resolve()
	if not bound.ok:
		out.error = bound.error
		return out
	out.ids = bound.binding.fish_species_item_ids
	out.ok = true
	return out


func _open(species_item_ids: PackedInt32Array, start_tick: int, run_width_u: int) -> StringName:
	"""Build the stores, generate the estuary, find the river and lake, and set the calendar."""
	var residents := ResidentsScript.new()
	_jobs = JobsScript.new(residents, PrioritiesScript.new(), ScheduleScript.new(residents.needs()))
	_fishing = Fishing.new(null, null, _jobs)
	var habitat_major := PackedInt32Array()
	for position: int in Fishing.SPECIES_COUNT:
		habitat_major.append(species_item_ids[Fishing.HABITAT_SPECIES_ROWS[position]])
	var estuary: Fishing.OpResult = _fishing.generate_initial_estuary(habitat_major)
	if not estuary.ok:
		return estuary.error
	_species_ids = species_item_ids.duplicate()
	for site: int in SITE_COUNT:
		var found: StringName = _find_habitat(SITE_HABITAT[site])
		if found != REFUSE_NONE:
			return found
		_habitat_ref.append(_fishing.habitat_ref_of(_math.value))
	_site_gear = PackedInt32Array(SITE_GEAR_MASK)
	if run_width_u < WEIR_MIN_WIDTH_U or run_width_u > WEIR_MAX_WIDTH_U:
		_site_gear[SITE_RUN] &= ~(1 << Fishing.GEAR_WEIR)
	_tick = start_tick
	_calendar.set_tick(_tick)
	return REFUSE_NONE


func _find_habitat(habitat_type: int) -> StringName:
	"""Leave the live habitat slot of `habitat_type` in `_math`, or name why there is none."""
	for index: int in _fishing.habitat_count():
		var slot: int = _fishing.live_habitat_slot_at(index).value
		if _fishing.habitat_type_of(slot).value == habitat_type:
			_math.succeed(slot)
			return REFUSE_NONE
	return REFUSE_NO_HABITAT


# --- time --------------------------------------------------------------------------------------

func advance_usec(usec: int) -> int:
	"""Advance by `usec` (>= 0) demo microseconds: whole ticks at 30/s, the remainder carried.
	Returns how many midnights were crossed (each ran §5.4's recovery)."""
	assert(usec >= 0, "demo time never runs backwards")
	_tick_carry += usec * SimClock.TICKS_PER_SECOND
	@warning_ignore("integer_division") var ticks: int = _tick_carry / USEC_PER_SECOND
	_tick_carry -= ticks * USEC_PER_SECOND
	return advance_ticks(ticks)


func advance_ticks(ticks: int) -> int:
	"""Advance by `ticks` (>= 0) whole ticks, running every day boundary crossed on the way, in
	order, on its own new day's calendar. Returns how many midnights were crossed."""
	assert(ticks >= 0, "demo time never runs backwards")
	var first_day: int = SimClock.day_index_at(_tick)
	var last_day: int = SimClock.day_index_at(_tick + ticks)
	for day: int in range(first_day + 1, last_day + 1):
		_calendar.set_tick(day * SimClock.TICKS_PER_DAY - SimClock.CALENDAR_OFFSET_TICKS)
		_fishing.reset_harvested_today()
		_fishing.recover_daily(_calendar.season, _calendar.season_day)
	_tick += ticks
	_calendar.set_tick(_tick)
	if last_day > first_day:
		revision += 1
	return last_day - first_day


func completed_tick() -> int:
	"""The driver's current tick (the calendar it fishes on)."""
	return _tick


func season() -> int:
	"""The current §4.3 Season (0 spring .. 3 winter)."""
	return _calendar.season


func season_day() -> int:
	"""The current day within the season, 1..12."""
	return _calendar.season_day


func store() -> Fishing:
	"""The real fishing store this driver runs (read it; do not mutate it around the driver)."""
	return _fishing


# --- per habitat / species ---------------------------------------------------------------------

func habitat_ref_of_site(site: int) -> Vector2i:
	"""The generation-checked FishHabitat reference a valid site fishes."""
	return _habitat_ref[site]


func stock_row(site: int, species_index: int) -> int:
	"""The FishStock row of a valid site's species 0..2 (owner-major, fishing.gd)."""
	return _fishing.habitat_slot_of(_habitat_ref[site]).value * Fishing.SPECIES_PER_HABITAT \
		+ species_index


func species_row_of(site: int, species_index: int) -> int:
	"""§5.4's table row (Fishing.SPECIES_*) of a valid site's species 0..2."""
	return Fishing.HABITAT_SPECIES_ROWS[SITE_HABITAT[site] * Fishing.SPECIES_PER_HABITAT
		+ species_index]


func species_key_of(site: int, species_index: int) -> StringName:
	"""The catalog key (e.g. &"trout") of a valid site's species 0..2."""
	return Fishing.SPECIES_KEYS[species_row_of(site, species_index)]


func gear_offered(site: int, gear: int) -> bool:
	"""Whether `gear` may be used at `site` (both assumed valid)."""
	return _site_gear[site] & (1 << gear) != 0


static func gear_takes_species(gear: int, species_row: int) -> bool:
	"""GDD §5.4's access column: a trap takes only dace/perch/carp/mussel, a hand net everything
	but offshore mackerel; weir, boat and ice kit name no species limit."""
	if gear == Fishing.GEAR_TRAP:
		return TRAP_SPECIES.has(species_row)
	if gear == Fishing.GEAR_HAND_NET or gear == Fishing.GEAR_ICE_KIT:
		return not HAND_NET_EXCLUDED.has(species_row)
	return true


static func injury_per_10000(gear: int, danger: int, crew_skill: int, additional_crew: int) -> int:
	"""GDD §5.4: `max(1, base*(1+danger) - 2*crew_skill - 4*additional_crew)` per 10000 cycles."""
	var chance: int = INJURY_BASE_PER_10000[gear] * (1 + danger) - INJURY_SKILL_TERM * crew_skill \
		- INJURY_CREW_TERM * additional_crew
	return maxi(INJURY_MIN_PER_10000, chance)


func refusal(site: int, species_index: int, gear: int) -> StringName:
	"""Why a cycle of `gear` for this site's species may not start right now, or REFUSE_NONE."""
	if site < 0 or site >= SITE_COUNT:
		return REFUSE_INVALID_SITE
	if not _fishing.is_species_index(species_index):
		return Fishing.REFUSE_INVALID_SPECIES_INDEX
	if not _fishing.is_gear(gear):
		return Fishing.REFUSE_INVALID_GEAR
	if not gear_offered(site, gear):
		return REFUSE_GEAR_NOT_AT_SITE
	if not gear_takes_species(gear, species_row_of(site, species_index)):
		return REFUSE_GEAR_SPECIES
	var row: int = stock_row(site, species_index)
	var block: StringName = _fishing.harvest_block_code(row, _calendar.season, _calendar.season_day)
	if block != REFUSE_NONE:
		return block
	if _fishing.is_quota_reached(_fishing.habitat_slot_of(_habitat_ref[site]).value):
		return Fishing.REFUSE_QUOTA_REACHED
	if _fishing.must_queue(_habitat_ref[site], Fishing.GEAR_EFFORT_SLOTS[gear]):
		return Fishing.REFUSE_EFFORT_SLOTS_FULL
	return REFUSE_NONE


func preview_into(site: int, species_index: int, gear: int, skill: int, out: Preview) -> bool:
	"""Fill REQ-SET-055's figures for one crew member of FISH `skill` (0..10); false when the site,
	species or gear does not exist (nothing written). `out.ok` says whether the cycle may start."""
	if site < 0 or site >= SITE_COUNT or not _fishing.is_species_index(species_index) \
			or not _fishing.is_gear(gear):
		return false
	out.block = refusal(site, species_index, gear)
	out.ok = out.block == REFUSE_NONE
	_preview_stock(site, species_index, out)
	_preview_gear(site, species_index, gear, skill, out)
	return true


func _preview_stock(site: int, species_index: int, out: Preview) -> void:
	"""The stock, latch, availability, closure and quota half of a preview."""
	var row: int = stock_row(site, species_index)
	var slot: int = _fishing.habitat_slot_of(_habitat_ref[site]).value
	out.species_row = species_row_of(site, species_index)
	out.species_key = Fishing.SPECIES_KEYS[out.species_row]
	out.stock_milli = _fishing.population_milli_of(row).value
	out.capacity_milli = _fishing.stock_capacity_milli_of(row).value
	out.depleted = _fishing.is_depleted(row)
	out.restocking = _fishing.is_restocking(row)
	out.availability_per_1000 = _fishing.availability_per_1000(out.species_row, _calendar.season,
		_calendar.season_day).value
	out.closed = _fishing.is_harvest_closed(row, _calendar.season, _calendar.season_day)
	out.quota_milli = _fishing.daily_quota_milli_of(slot).value
	out.remaining_quota_milli = _fishing.remaining_quota_milli(slot).value
	out.reopen_season = _calendar.season
	out.reopen_day = _calendar.season_day
	if out.closed or out.availability_per_1000 == 0:
		_reopening(row, out)
	out.landing = SITE_LANDING[site]


func _preview_gear(site: int, species_index: int, gear: int, skill: int, out: Preview) -> void:
	"""The gear, effort and risk half of a preview; expected catch is the store's `catch_milli`."""
	var slot: int = _fishing.habitat_slot_of(_habitat_ref[site]).value
	out.base_catch_milli = BASE_CATCH_MILLI[gear]
	out.wear_per_cycle = WEAR_PER_CYCLE[gear]
	out.slots_needed = Fishing.GEAR_EFFORT_SLOTS[gear]
	out.slots_total = _fishing.effort_slots_of(slot).value
	out.slots_free = _fishing.effort_slots_free_of(slot).value
	out.must_queue = _fishing.must_queue(_habitat_ref[site], out.slots_needed)
	out.injury_per_10000 = injury_per_10000(gear, _fishing.danger_of(slot).value, skill, 0)
	out.expected_catch_milli = 0
	if gear_offered(site, gear) and gear_takes_species(gear, out.species_row) \
			and _fishing.catch_milli_into(stock_row(site, species_index), out.base_catch_milli, skill,
				_calendar.season, _calendar.season_day, _math):
		out.expected_catch_milli = _math.value


func _reopening(row: int, out: Preview) -> void:
	"""REQ-SET-046's reopening day: the first later day, within a year, on which the store neither
	closes this species by calendar nor rates it unavailable (the stored event bit is not
	predictable and is not scanned)."""
	var species: int = _fishing.species_of_row(row).value
	for ahead: int in range(1, REOPEN_SCAN_DAYS + 1):
		_scan.set_tick(_tick + ahead * SimClock.TICKS_PER_DAY)
		if not _fishing.is_closure_window(species, _scan.season, _scan.season_day) \
				and _fishing.availability_per_1000(species, _scan.season, _scan.season_day).value > 0:
			out.reopen_season = _scan.season
			out.reopen_day = _scan.season_day
			return


# --- cycles ------------------------------------------------------------------------------------

func begin_cycle(site: int, species_index: int, gear: int) -> Cycle:
	"""Open a cycle: refuse (nothing taken) if §5.4 forbids it now, else reserve the gear's whole
	effort requirement for a new Expedition owned by a coordinator FISH Job."""
	var cycle := Cycle.new()
	cycle.error = refusal(site, species_index, gear)
	if cycle.error != REFUSE_NONE:
		return cycle
	var expedition: Vector2i = _fishing.directory().create(EntityDirectory.KIND_EXPEDITION)
	if expedition == EntityDirectory.NULL_REF:
		cycle.error = _fishing.directory().last_refusal()
		return cycle
	var job: JobsScript.OpResult = _jobs.create_job(JOB_KIND_FISH, 0, 0, WORK_MWU[gear], _tick)
	if not job.ok:
		cycle.error = job.error
		_discard_owners(expedition, EntityDirectory.NULL_REF)
		return cycle
	var reserved: Fishing.OpResult = _fishing.reserve_effort_slots(expedition, job.ref,
		_habitat_ref[site], Fishing.GEAR_EFFORT_SLOTS[gear])
	if not reserved.ok:
		cycle.error = reserved.error
		_discard_owners(expedition, job.ref)
		return cycle
	revision += 1
	cycle.ok = true
	cycle.expedition = expedition
	cycle.job = job.ref
	cycle.site = site
	cycle.species_index = species_index
	cycle.gear = gear
	return cycle


func complete_cycle(cycle: Cycle, skill: int) -> CatchResult:
	"""Close an open cycle for a crew of FISH `skill`: take the store's legal catch (quota and floor
	already applied; 0 when the species closed mid-cycle), debit exactly it, free the slots and
	return the lot. Refuses a cycle that is not open (a second completion takes nothing)."""
	var result := CatchResult.new()
	if cycle == null or not cycle.ok or not _fishing.effort_claim_row_into(cycle.expedition, _math):
		result.error = REFUSE_NOT_A_CYCLE
		return result
	var row: int = stock_row(cycle.site, cycle.species_index)
	if not _fishing.catch_milli_into(row, BASE_CATCH_MILLI[cycle.gear], skill, _calendar.season,
			_calendar.season_day, _math):
		result.error = StringName(_math.error)
		return result
	var amount: int = _math.value
	if amount > 0:
		var taken: Fishing.OpResult = _fishing.harvest(_habitat_ref[cycle.site],
			cycle.species_index, amount, _calendar.season, _calendar.season_day)
		if not taken.ok:
			result.error = taken.error
			return result
		result.lots.append(_lot(cycle, amount))
	_close(cycle)
	result.quantity_milli = amount
	result.ok = true
	return result


func cancel_cycle(cycle: Cycle) -> bool:
	"""Abandon an open cycle: free its slots and owners, take nothing. False for a closed cycle."""
	if cycle == null or not cycle.ok or not _fishing.effort_claim_row_into(cycle.expedition, _math):
		return false
	_close(cycle)
	return true


func _close(cycle: Cycle) -> void:
	"""Release an open cycle's effort claim, then its Job and Expedition, and mark it closed."""
	_fishing.release_effort_slots(cycle.expedition)
	_discard_owners(cycle.expedition, cycle.job)
	cycle.ok = false
	revision += 1


func resolve_cycle(site: int, species_index: int, gear: int, skill: int) -> CatchResult:
	"""Begin and complete one cycle at once: the caught lots, or the refusal that stopped it."""
	var cycle: Cycle = begin_cycle(site, species_index, gear)
	if not cycle.ok:
		var refused := CatchResult.new()
		refused.error = cycle.error
		return refused
	return complete_cycle(cycle, skill)


func _lot(cycle: Cycle, amount: int) -> CatchLot:
	"""The lot one completed cycle caught."""
	var lot := CatchLot.new()
	lot.species_row = species_row_of(cycle.site, cycle.species_index)
	lot.species_key = Fishing.SPECIES_KEYS[lot.species_row]
	lot.item_id = _species_ids[lot.species_row]
	lot.quantity_milli = amount
	lot.site = cycle.site
	lot.landing = SITE_LANDING[cycle.site]
	return lot


func _discard_owners(expedition: Vector2i, job: Vector2i) -> void:
	"""Release a cycle's Job row and Expedition reference (either may be null)."""
	if job != EntityDirectory.NULL_REF:
		_jobs.destroy_job(_jobs.directory().get_typed_row(job))
	if expedition != EntityDirectory.NULL_REF:
		_fishing.directory().destroy(expedition)


func open_claims() -> int:
	"""How many effort claims the store holds (the open cycles)."""
	return _fishing.effort_claim_count()
