extends RefCounted
## Drives the REAL forage store (`scripts/core/forage.gd`) for the demo's woods, on the demo calendar. Decision 0681
## (feature #22: foraging trips). Every ecological number -- the patches' stocks and capacities, seasonal availability,
## the daily regrowth, the sustainable floor, the daily aggregate quota, the claims and their reconciliation, work per U
## and the injury chance -- is forage.gd's own (GDD §5.5, decisions 0026, 0030, 0036); nothing here forks it. The
## driver adds only what the store leaves to its caller, as the fishery's driver does (demo/water/fishing_driver.gd):
##
##   * THE BASIN. One FORAGE HarvestZone, its own basin (forage.gd PROVISIONAL: SELF-REFERENCE AT CREATION -- the
##     world generator's basin, which the demo stands in for), with §5.5's natural danger 1 (forage_rules.gd), enabled,
##     unprotected, Automatic quota; its five patches created at §5.1's 80% with the compiled catalogue's item ids,
##     resolved by key through the verified catalogue boundary (resource_catalog_binding.gd), never generic.
##   * TIME. `follow(tick)` walks the calendar to `tick` and at every offset-calendar midnight crossed runs ecology.gd's
##     §5.5 order exactly: `regrow_daily(season)` (decision 0036's additive regrowth) then `run_midnight(tick, season)`
##     (decision 0030's quota order), with the year boundary's `reset_harvested_year()` first on spring day 1.
##   * CLAIMS. A forager's share is claimed by a real coordinator FORAGE Job (jobs.gd), the claim's owner (decision
##     0030): `open_claim` creates the Job and claims; `collect` collects it -- falling back, if midnight's
##     reconciliation released it, to the store's own unclaimed `harvest` of what it still admits -- and `close`
##     releases what is left and destroys the Job. Uncollected forage is ecological stock, never a lot (forage.gd).
##
## NAMED BLOCKERS -- shown, never invented (the fishery's own, decision 0431): REQ-SET-068's hazard roll and injury
## (no FORAGE RNG stream owner, no injury store in the demo: the chance is published for the panel, never rolled);
## REQ-SET-067's consent (danger 1 needs none); §5.9's wildlife-pressure roll (an ECOLOGY draw ecology.gd owns).

const ForageScript := preload("res://scripts/core/forage.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const CoreCatalog := preload("res://scripts/core/catalog.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const CatalogBinding := preload("res://scripts/core/resource_catalog_binding.gd")
const Rules := preload("res://demo/forage/forage_rules.gd")

const JOB_KIND_FORAGE: int = CoreCatalog.JOB_KIND["FORAGE"]
const NULL_REF: Vector2i = EntityDirectory.NULL_REF
const REFUSE_NONE: StringName = &""
const REFUSE_ITEM_IDS: StringName = &"FORAGE_ITEM_IDS"
const REFUSE_NEGATIVE_TICK: StringName = &"NEGATIVE_TICK"


class IdsResult:
	"""`resolve_item_ids()`'s outcome: five ids in forage.gd PATCH_KEYS order, or why not."""
	var ok: bool = false
	var error: StringName = &""
	var ids: PackedInt32Array = PackedInt32Array()


## The store and its Job store (one directory between them), and the basin.
var forage: ForageScript = null
var jobs: JobsScript = null
var basin: Vector2i = NULL_REF
## The basin's typed zone row (its patch rows are slot x 5 + kind).
var basin_slot: int = -1
## Bumped at every midnight crossed, and on every claim, collection and release (a panel redraws then).
var revision: int = 0
## The last refusal of `open_claim` or `collect` (a forage.gd code).
var last_refusal: StringName = REFUSE_NONE

var _tick: int = 0
var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)
var _read: IntMath.IntResult = IntMath.IntResult.new()


static func resolve_item_ids() -> IdsResult:
	"""The five forage items' compiled ItemDefinition ids, resolved by key through the verified catalogue boundary
	(resource_catalog_binding.gd), in forage.gd PATCH_KEYS order."""
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
	out.ids = bound.binding.forage_item_ids
	out.ok = true
	return out


static func create(item_ids: PackedInt32Array, start_tick: int) -> RefCounted:
	"""A driver over a fresh store with the woods' one basin, starting at `start_tick` (null when it cannot be made: five
	ids in PATCH_KEYS order, a tick at or after 0)."""
	if item_ids.size() != ForageScript.PATCHES_PER_ZONE or start_tick < 0:
		return null
	var driver := new()
	return driver if driver._open(item_ids, start_tick) == REFUSE_NONE else null


func _open(item_ids: PackedInt32Array, start_tick: int) -> StringName:
	"""Build the Job and forage stores, the basin and its five patches, and set the calendar."""
	var residents := ResidentsScript.new()
	jobs = JobsScript.new(residents, PrioritiesScript.new(), ScheduleScript.new(residents.needs()))
	forage = ForageScript.new(null, jobs)
	var zone: ForageScript.OpResult = forage.create_zone(ForageScript.ZONE_TYPE_FORAGE, Rules.NATURAL_DANGER, 0, false, true)
	if not zone.ok:
		return zone.error
	basin = zone.ref
	basin_slot = zone.value
	var patches: ForageScript.OpResult = forage.create_patch_set(basin, item_ids)
	if not patches.ok:
		return patches.error
	_tick = start_tick
	_calendar.set_tick(_tick)
	return REFUSE_NONE


# --- time ----------------------------------------------------------------------------------------------

func follow(to_tick: int) -> int:
	"""Walk the calendar to `to_tick` (never back), running every midnight crossed in order (see TIME). How many."""
	if to_tick <= _tick:
		return 0
	var first_day: int = SimClock.day_index_at(_tick)
	var last_day: int = SimClock.day_index_at(to_tick)
	for day: int in range(first_day + 1, last_day + 1):
		_midnight(day * SimClock.TICKS_PER_DAY - SimClock.CALENDAR_OFFSET_TICKS)
	_tick = to_tick
	_calendar.set_tick(_tick)
	return last_day - first_day


func _midnight(at: int) -> void:
	"""One midnight at calendar tick `at`: the year boundary's reset, the regrowth, the quota order."""
	_calendar.set_tick(at)
	if _calendar.season == ForageScript.SEASON_SPRING and _calendar.season_day == 1:
		forage.reset_harvested_year()
	forage.regrow_daily(_calendar.season)
	forage.run_midnight(at, _calendar.season)
	revision += 1


func tick() -> int:
	"""The calendar tick the driver stands at."""
	return _tick


func season() -> int:
	"""The §4.3 season now (0 spring .. 3 winter)."""
	return _calendar.season


# --- the readings (the panel's; REQ-SET-055's spirit for forage: what a trip will find before it goes) --------

func row_of(kind: int) -> int:
	"""The basin's patch row of forage.gd patch `kind` (owner-major: slot x 5 + kind)."""
	return basin_slot * ForageScript.PATCHES_PER_ZONE + kind if basin_slot >= 0 else -1


func stock_milli(kind: int) -> int:
	"""The patch's stock, milli-U."""
	return forage.stock_milli_of(row_of(kind)).value


func capacity_milli(kind: int) -> int:
	"""The patch's capacity, milli-U (§5.5)."""
	return forage.patch_capacity_milli_of(row_of(kind)).value


func floor_milli(kind: int) -> int:
	"""The patch's sustainable floor, milli-U (§5.5: 20% of capacity)."""
	return forage.harvest_floor_milli(row_of(kind), false).value


func availability(kind: int) -> int:
	"""The kind's seasonal availability now, per 1000 (0: dormant this season)."""
	return forage.availability_per_1000(kind, season()).value


func harvestable_milli(kind: int) -> int:
	"""The most a new claim on `kind` may take now: min(the basin's quota left today, its stock above the floor not
	already claimed) -- 0 while dormant (forage.gd `harvestable_milli`)."""
	var out: IntMath.IntResult = forage.harvestable_milli(basin, kind, season(), false)
	return out.value if out.ok else 0


func quota_today_milli() -> int:
	"""The basin's daily aggregate quota this season (decision 0030: automatic)."""
	return forage.daily_quota_milli_of(basin_slot, season()).value


func quota_left_milli() -> int:
	"""Today's quota not yet collected or claimed."""
	return forage.available_quota_milli(basin, season()).value


func harvested_today_milli() -> int:
	"""Forage of every kind collected from the basin today."""
	return forage.harvested_today_milli_of(basin_slot).value


func work_per_u_wu(kind: int, level: int) -> int:
	"""§5.5's WU a unit of `kind` takes a forager at FORAGE `level` in this basin."""
	return forage.work_per_u(kind, clampi(level, 0, 10), Rules.NATURAL_DANGER).value


func injury_per_10000(level: int) -> int:
	"""REQ-SET-068's chance per 60 WU of work here, per 10000 (shown, never rolled: see NAMED BLOCKERS)."""
	return forage.injury_chance_per_10000(Rules.NATURAL_DANGER, clampi(level, 0, 10)).value


# --- claims (see CLAIMS) -----------------------------------------------------------------------------------

func open_claim(kind: int, amount_milli: int) -> Vector2i:
	"""A coordinator FORAGE Job claiming `amount_milli` of `kind` now: its reference, or NULL_REF (`last_refusal` says
	why; no Job is left behind)."""
	var job: JobsScript.OpResult = jobs.create_job(JOB_KIND_FORAGE, 0, 0, 0, _tick)
	if not job.ok:
		last_refusal = job.error
		return NULL_REF
	var claimed: ForageScript.OpResult = forage.claim_forage(job.ref, basin, kind, amount_milli, season(), false)
	if not claimed.ok:
		last_refusal = claimed.error
		jobs.destroy_job(job.value)
		return NULL_REF
	last_refusal = REFUSE_NONE
	revision += 1
	return job.ref


func remaining_milli(job: Vector2i) -> int:
	"""What `job`'s claim still holds uncollected (0: none, or released)."""
	if not forage.claim_row_of_into(job, _read):
		return 0
	return forage.claim_remaining_milli_of(_read.value).value


func collect(job: Vector2i, kind: int, amount_milli: int) -> int:
	"""Collect `amount_milli` of `kind` for `job`: from its claim while it holds that much, else -- released at a
	midnight -- the store's unclaimed harvest of what it still admits (never more than asked). What was collected."""
	if amount_milli <= 0:
		return 0
	var got: int = 0
	if remaining_milli(job) >= amount_milli:
		var done: ForageScript.OpResult = forage.collect_claim(job, amount_milli, season(), false)
		got = done.value if done.ok else 0
		last_refusal = REFUSE_NONE if done.ok else done.error
	if got == 0:
		forage.release_claim(job)
		var take: int = mini(amount_milli, harvestable_milli(kind))
		if take > 0 and forage.harvest_into(basin, kind, take, season(), false, _read):
			got = take
	revision += 1
	return got


func close(job: Vector2i) -> void:
	"""`job` is done: what its claim still holds goes back to the basin's allowances, and the Job row is freed."""
	if job == NULL_REF:
		return
	forage.release_claim(job)
	var slot: int = jobs.directory().get_typed_row(job)
	if jobs.directory().is_valid_of_kind(job, EntityDirectory.KIND_JOB) and jobs.is_job_present(slot):
		jobs.destroy_job(slot)
	revision += 1


func open_claims() -> int:
	"""Claims the store holds now (the books' check)."""
	return forage.claim_count()
