extends RefCounted
## THE ORCHARD'S STATE (decisions 0671-0677): the trees as REAL OrchardPlot rows of scripts/core/orchard_hive.gd -- §5.6's
## ages, health, tending, chill and harvested-year flags, its yield and its first-eligible-harvest reader, called and
## never retyped -- and round them the demo's own: the four sites, the hedge's one §5.5 Berries patch, the nursery's
## saplings and its plans (ECO-009), the two groups' policies (ECO-010) and the protected grove's record (ECO-015).
## Presentation only: the settlement never reads it. Pure logic (no nodes), so the tests drive it directly.
##
## THE DAY. `close_day(day, temperature_tenths)` runs at each midnight for the day just ended: every tree's §5.6 day
## (`apply_orchard_day`: age, -100 untended or +50 tended health in spring and summer, the winter chill count, the
## harvested flag cleared on a year's first day), the hedge's §5.5 regrowth, and a nursery plan whose 12-day wait is
## over gets its sapling.
##
## THE HARVEST, per tree and year: a MATURE tree (§5.6 age) gives its §5.6 yield once, in its window (the store's
## `harvest_orchard`, REQ-SET-079/080); a YOUNG tree at least a year old gives decision 0672's early yield (20% of the
## same product) once a year in the same window, until it matures (`early_year`, the demo's own column: the store's
## harvested flag is §5.6's and is left to it).
##
## PLANS (ECO-009). A plan ties one sapling to one site: WAITING (the nursery has not propagated it yet), GROWING (its
## 12-day wait), READY (a sapling held for the site), then closed when it is planted. A grant sapling (the M3 two of each
## species, decision 0672) is FREE stock until a planting takes it. A site with a plan is spoken for.

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const NONE: int = -1
const PLAN_FREE: int = 0
const PLAN_WAITING: int = 1
const PLAN_GROWING: int = 2
const PLAN_READY: int = 3
const PLAN_STATE_NAMES: Array[String] = ["", "Waiting for the nursery", "Growing in the nursery", "Ready to plant"]

const REFUSE_SITE_TAKEN: String = "SITE_TAKEN"
const REFUSE_SITE_PLANNED: String = "SITE_PLANNED"
const REFUSE_NO_SAPLING: String = "NO_SAPLING"
const REFUSE_NO_PLAN_ROW: String = "NO_PLAN_ROW"
const REFUSE_NOT_ELIGIBLE: String = "NOT_ELIGIBLE"
## How far ahead `next_harvest_day` looks (a pear planted today bears early within two years, fully within four).
const LOOKAHEAD_YEARS: int = 5

var store: Hive = null
## The day `next_harvest_day` counts ahead from (the model's own today: moved on by `close_day`, and set by the demo node
## from the calendar).
var today_hint: int = Hive.MIN_CALENDAR_DAY
## Bumped on every change a reader shows (the panel, the view).
var revision: int = 0
## Per site: its tree's OrchardPlot reference (NULL_REF: none), whether it came with the village, the day it was planted
## (0 for an inherited tree) and the year of its last early harvest (0: none).
var site_ref: Array[Vector2i] = []
var inherited: PackedByteArray = PackedByteArray()
var planted_day: PackedInt32Array = PackedInt32Array()
var early_year: PackedInt32Array = PackedInt32Array()
## The hedge's one §5.5 Berries patch (milli-U), and the berries picked (the panel's tally).
var hedge_milli: int = Rules.HEDGE_START_MILLI
var berries_picked_milli: int = 0
## Fruit picked in all, by species (milli-U).
var fruit_picked_milli: PackedInt64Array = PackedInt64Array()
## The nursery: free saplings by species, and the plans' columns.
var saplings: PackedInt32Array = PackedInt32Array()
var plan_state: PackedByteArray = PackedByteArray()
var plan_species: PackedInt32Array = PackedInt32Array()
var plan_site: PackedInt32Array = PackedInt32Array()
var plan_ready_day: PackedInt32Array = PackedInt32Array()
## Each plan's serial, new each time its row is used (a propagation checks it is still working its own plan).
var plan_serial: PackedInt32Array = PackedInt32Array()
var _next_plan_serial: int = 1
## The groups' policies (ECO-010).
var group_timing: PackedInt32Array = PackedInt32Array()
var group_dest: PackedInt32Array = PackedInt32Array()
var group_keep: PackedInt32Array = PackedInt32Array()
## The grove (ECO-015): whether it is protected, the season (absolute index) last observed, and its record.
var grove_protected: bool = true
var grove_seen_season: int = -1
var grove_record: PackedStringArray = PackedStringArray()

var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""The village's orchard as it opens: the old trees on their blocks, the empty sites, the hedge, the grant in the
	nursery, the default policies and the grove protected."""
	store = Hive.new(EntityDirectory.new())
	site_ref.resize(Rules.SITE_COUNT)
	site_ref.fill(Hive.NULL_REF)
	for column: PackedInt32Array in [planted_day, early_year]:
		column.resize(Rules.SITE_COUNT)
	inherited.resize(Rules.SITE_COUNT)
	fruit_picked_milli.resize(Hive.SPECIES_COUNT)
	saplings = Rules.GRANT_SAPLINGS.duplicate()
	plan_state.resize(Rules.MAX_PLANS)
	for column: PackedInt32Array in [plan_species, plan_site, plan_ready_day, plan_serial]:
		column.resize(Rules.MAX_PLANS)
	for column: PackedInt32Array in [group_timing, group_dest, group_keep]:
		column.resize(Rules.GROUP_COUNT)
	group_dest.fill(Rules.DEST_KEEPING)
	group_keep[0] = Rules.KEEP_STEPS[1]
	_plant_old_trees()


func _plant_old_trees() -> void:
	"""ECO-008's inherited old orchard: each starting tree a real row, aged, neglected and last winter's chill kept."""
	for site: int in Rules.SITE_COUNT:
		var species: int = Rules.SITE_START_SPECIES[site]
		if species == NONE:
			continue
		var origin: Vector2i = Rules.SITE_ORIGIN[site]
		var made: Hive.OpResult = store.plant_orchard(origin.x, origin.y, species, Hive.MIN_CALENDAR_DAY)
		assert(made.ok, "the old orchard's blocks are free and in the map")
		site_ref[site] = made.ref
		inherited[site] = 1
		store.restore_orchard_state(made.ref, Rules.OLD_AGE_DAYS[site], Rules.OLD_HEALTH, Rules.OLD_CHILL_DAYS, false,
			false)


# --- reading a site ---------------------------------------------------------------------------------------------------

func has_tree(site: int) -> bool:
	"""Whether a tree stands on `site`."""
	return Rules.is_site(site) and site_ref[site] != Hive.NULL_REF


func slot_of(site: int) -> int:
	"""Site `site`'s OrchardPlot typed row (NONE: no tree)."""
	return store.orchard_row_of(site_ref[site]).value if has_tree(site) else NONE


func species_of(site: int) -> int:
	"""The species on `site` (NONE: no tree)."""
	return store.species_of(slot_of(site)).value if has_tree(site) else NONE


func age_of(site: int) -> int:
	"""The tree's age in days (0: none)."""
	return store.age_days_of(slot_of(site)).value if has_tree(site) else 0


func health_of(site: int) -> int:
	"""The tree's §5.6 health, 0..10000 (0: none)."""
	return store.orchard_health_of(slot_of(site)).value if has_tree(site) else 0


func stage_of(site: int) -> int:
	"""The tree's stage (orchard_rules.gd STAGE_*; NONE: no tree)."""
	if not has_tree(site):
		return NONE
	return Rules.stage_of(age_of(site), species_of(site), inherited[site] == 1)


func is_mature(site: int) -> bool:
	"""Whether the tree has reached §5.6's maturity."""
	return has_tree(site) and store.is_mature(slot_of(site))


func tended_today(site: int) -> bool:
	"""Whether the tree's care is done today."""
	return has_tree(site) and store.is_tended_today(slot_of(site))


func expected_yield_milli(site: int) -> int:
	"""What the tree would give if picked now: §5.6's yield when mature, decision 0672's early share when a year old,
	else 0."""
	if not has_tree(site):
		return 0
	var slot: int = slot_of(site)
	if store.is_mature(slot):
		return _read.value if store.orchard_yield_milli_into(slot, _read) else 0
	if age_of(site) < Rules.EARLY_YIELD_AGE_DAYS:
		return 0
	if not store.orchard_pollination_factor_into(slot, _read):
		return 0
	return Rules.early_yield_milli(Hive.SPECIES_YIELD_MILLI[species_of(site)], health_of(site), _read.value,
		store.chill_factor_of(slot).value)


func harvest_refusal(site: int, day: int) -> String:
	"""Why the tree on `site` cannot be picked on `day` ("" when it can): no tree, outside its window, too young, picked
	already this year (a young tree's early harvest counts: one picking a year, REQ-SET-080)."""
	if not has_tree(site):
		return REFUSE_NOT_ELIGIBLE
	if not Hive.is_harvest_day(species_of(site), day):
		return String(Hive.REFUSE_OUTSIDE_HARVEST_WINDOW)
	if not is_mature(site) and age_of(site) < Rules.EARLY_YIELD_AGE_DAYS:
		return String(Hive.REFUSE_NOT_MATURE)
	if early_year[site] == Hive.year_of_day(day) or (is_mature(site) and store.is_harvested_year(slot_of(site))):
		return String(Hive.REFUSE_ALREADY_HARVESTED_THIS_YEAR)
	return ""


func next_harvest_day(site: int, day: int) -> int:
	"""The first day on or after `day` the tree on `site` can be picked, its age counted forward from `today_hint`
	(0: no tree, or none within LOOKAHEAD_YEARS): the panel's "next harvest"."""
	if not has_tree(site):
		return 0
	var species: int = species_of(site)
	var year: int = Hive.year_of_day(day)
	for y: int in range(year, year + LOOKAHEAD_YEARS):
		var first: int = store.first_harvest_window_day_of_year(species, y).value
		var last: int = store.last_harvest_window_day_of_year(species, y).value
		for candidate: int in range(maxi(first, day), last + 1):
			if _eligible_on(site, candidate):
				return candidate
	return 0


func _eligible_on(site: int, candidate: int) -> bool:
	"""Whether the tree on `site` may be picked on `candidate` (a window day), aged forward from today."""
	var age: int = age_of(site) + candidate - today_hint
	var year: int = Hive.year_of_day(candidate)
	if age < Rules.EARLY_YIELD_AGE_DAYS or early_year[site] == year:
		return false
	var this_year: bool = year == Hive.year_of_day(today_hint)
	return age < Hive.SPECIES_MATURITY_DAYS[species_of(site)] or not (this_year and store.is_harvested_year(slot_of(site)))


func first_early_day(species: int, plant_day: int) -> int:
	"""A tree planted on `plant_day`: the first day of decision 0672's early harvest -- the first day of its window on or
	after its first year, if it is still young then (0: it matures first)."""
	var year_old: int = plant_day + Rules.EARLY_YIELD_AGE_DAYS
	var year: int = Hive.year_of_day(year_old)
	var first: int = store.first_harvest_window_day_of_year(species, year).value
	var last: int = store.last_harvest_window_day_of_year(species, year).value
	var day: int = maxi(first, year_old) if year_old <= last else store.first_harvest_window_day_of_year(species,
		year + 1).value
	return day if day < plant_day + Hive.SPECIES_MATURITY_DAYS[species] else 0


# --- changing a site ----------------------------------------------------------------------------------------------------

func record_tending(site: int) -> bool:
	"""§5.6's 20 WU of care done today on `site`'s tree."""
	if not has_tree(site):
		return false
	revision += 1
	return store.record_tending(site_ref[site]).ok


func pick_tree(site: int, day: int) -> int:
	"""Pick `site`'s tree on `day`: its fruit in milli-U (the store's harvest for a mature tree, decision 0672's early
	yield for a young one), its flag set so the year gives no more. 0 when it may not be picked."""
	if not harvest_refusal(site, day).is_empty():
		return 0
	var species: int = species_of(site)
	var milli: int = 0
	if is_mature(site):
		var done: Hive.OpResult = store.harvest_orchard(site_ref[site], day)
		milli = done.value if done.ok else 0
	else:
		milli = expected_yield_milli(site)
		early_year[site] = Hive.year_of_day(day)
	fruit_picked_milli[species] += milli
	revision += 1
	return milli


func plant_refusal(site: int, species: int, day: int, from_plan: bool) -> String:
	"""Why `species` cannot be planted on `site` on `day` ("" when it can): a tree there, the site promised to another
	plan, no sapling, or the store's own refusal (REQ-SET-081's preview refuses for exactly the planting's reasons)."""
	if not Rules.is_site(site) or species < 0 or species >= Hive.SPECIES_COUNT:
		return REFUSE_NOT_ELIGIBLE
	if has_tree(site):
		return REFUSE_SITE_TAKEN
	var plan: int = plan_for_site(site)
	if plan != NONE and not (from_plan and plan_species[plan] == species):
		return REFUSE_SITE_PLANNED
	if not from_plan and saplings[species] <= 0:
		return REFUSE_NO_SAPLING
	if from_plan and (plan == NONE or plan_state[plan] != PLAN_READY):
		return REFUSE_NO_SAPLING
	var origin: Vector2i = Rules.SITE_ORIGIN[site]
	var preview: Hive.PlantingPreview = store.preview_planting(origin.x, origin.y, species, day)
	return "" if preview.ok else String(preview.error)


func take_sapling(site: int, species: int, from_plan: bool) -> bool:
	"""Take the sapling a planting on `site` uses: the site's ready plan's (closing it), else a free one."""
	if from_plan:
		var plan: int = plan_for_site(site)
		if plan == NONE or plan_state[plan] != PLAN_READY:
			return false
		plan_state[plan] = PLAN_FREE
		plan_site[plan] = NONE
		return true
	if saplings[species] <= 0:
		return false
	saplings[species] -= 1
	return true


func plant(site: int, species: int, day: int) -> bool:
	"""Plant `species` on `site` (its sapling already taken): a new §5.6 row, age 0, health 10000 (BAL-CAT-010)."""
	var origin: Vector2i = Rules.SITE_ORIGIN[site]
	var made: Hive.OpResult = store.plant_orchard(origin.x, origin.y, species, day)
	if not made.ok:
		return false
	site_ref[site] = made.ref
	inherited[site] = 0
	planted_day[site] = day
	early_year[site] = 0
	revision += 1
	return true


# --- the nursery's plans (ECO-009) ------------------------------------------------------------------------------------------

func plan_for_site(site: int) -> int:
	"""The live plan promised to `site` (NONE: none)."""
	for plan: int in Rules.MAX_PLANS:
		if plan_state[plan] != PLAN_FREE and plan_site[plan] == site:
			return plan
	return NONE


func add_plan(species: int, site: int) -> String:
	"""Promise a sapling of `species` to empty `site`: a WAITING plan. "" when made, else why not."""
	if not Rules.is_site(site) or species < 0 or species >= Hive.SPECIES_COUNT:
		return REFUSE_NOT_ELIGIBLE
	if has_tree(site):
		return REFUSE_SITE_TAKEN
	if plan_for_site(site) != NONE:
		return REFUSE_SITE_PLANNED
	var plan: int = Array(plan_state).find(PLAN_FREE)
	if plan < 0:
		return REFUSE_NO_PLAN_ROW
	plan_state[plan] = PLAN_WAITING
	plan_species[plan] = species
	plan_site[plan] = site
	plan_ready_day[plan] = 0
	plan_serial[plan] = _next_plan_serial
	_next_plan_serial += 1
	revision += 1
	return ""


func drop_plan(plan: int) -> bool:
	"""Give up a plan that is not yet growing (a growing or ready sapling stays promised: it goes on to its site)."""
	if plan < 0 or plan >= Rules.MAX_PLANS or plan_state[plan] != PLAN_WAITING:
		return false
	plan_state[plan] = PLAN_FREE
	plan_site[plan] = NONE
	revision += 1
	return true


func start_growing(plan: int, day: int) -> void:
	"""The nursery's 120 WU are done on `plan`: its sapling grows for §5.6's 12 days from `day`."""
	plan_state[plan] = PLAN_GROWING
	plan_ready_day[plan] = day + Hive.NURSERY_WAIT_DAYS
	revision += 1


func plan_count(state: int) -> int:
	"""How many plans are in `state`."""
	return Array(plan_state).count(state)


# --- the day ------------------------------------------------------------------------------------------------------------

func close_day(day: int, temperature_tenths: int) -> void:
	"""Midnight: day `day` is over at `temperature_tenths` (its weather): every tree's §5.6 day, the hedge's regrowth for
	tomorrow's season, the nursery's ready saplings. `today_hint` moves to the day that begins."""
	for site: int in Rules.SITE_COUNT:
		if has_tree(site):
			store.apply_orchard_day(site_ref[site], day, temperature_tenths)
	hedge_milli += Rules.berry_growth_milli(hedge_milli, Hive.season_of_day(day + 1))
	for plan: int in Rules.MAX_PLANS:
		if plan_state[plan] == PLAN_GROWING and plan_ready_day[plan] <= day + 1:
			plan_state[plan] = PLAN_READY
	today_hint = day + 1
	revision += 1


# --- the hedge (§5.5) ------------------------------------------------------------------------------------------------------

func berries_available_milli(season: int) -> int:
	"""Berries that may be picked now: nothing in a dormant season; else the stock above §5.5's sustainable floor."""
	if Rules.berry_availability(season) == 0:
		return 0
	return maxi(0, hedge_milli - Rules.berry_floor_milli())


func pick_berries(milli: int, season: int) -> int:
	"""Take up to `milli` from the hedge (never below its floor, never in a dormant season). How much was taken."""
	var taken: int = mini(milli, berries_available_milli(season))
	if taken <= 0:
		return 0
	hedge_milli -= taken
	berries_picked_milli += taken
	revision += 1
	return taken


# --- the grove (ECO-015) -------------------------------------------------------------------------------------------------

func set_grove_protected(on: bool) -> void:
	"""Protect the grove from felling (or lift it)."""
	if grove_protected != on:
		grove_protected = on
		revision += 1


func record_observation(season_index: int, line: String) -> void:
	"""One observation for the season `season_index` (absolute: year * 4 + season), kept newest first, MAX_RECORDS."""
	grove_seen_season = season_index
	grove_record.insert(0, line)
	if grove_record.size() > Rules.MAX_RECORDS:
		grove_record.resize(Rules.MAX_RECORDS)
	revision += 1


static func season_index_of_day(day: int) -> int:
	"""Seasons since the calendar began (0: Y1 spring) of absolute day `day`."""
	@warning_ignore("integer_division") var index: int = (day - Hive.MIN_CALENDAR_DAY) / SimClock.DAYS_PER_SEASON
	return index
