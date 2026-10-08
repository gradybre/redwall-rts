extends RefCounted
## THE ORCHARD'S STATE (decisions 0671-0677): the trees as REAL OrchardPlot rows of scripts/core/orchard_hive.gd -- §5.6's
## ages, health, tending, chill and harvested-year flags, its yield and its first-eligible-harvest reader, called and
## never retyped -- and round them the demo's own: the four sites, the hedge's one §5.5 Berries patch, the nursery's
## saplings and its plans (ECO-009), the two groups' policies (ECO-010) and the protected grove's record (ECO-015).
## Presentation only: the settlement never reads it. Pure logic (no nodes), so the tests drive it directly.
##
## THE DAY. `close_day(day, temperature_tenths)` runs at each midnight for the day just ended: every tree's §5.6 day
## (`apply_orchard_day`: age, -100 untended or +50 tended health in spring and summer, the winter chill count, the
## harvested flag cleared on a year's first day), then the apiary's hives' (demo/hives/apiary_model.gd, decision 1601:
## in this same store, so a healthy hive within 12 m pollinates a tree, REQ-SET-082), the hedge's §5.5 regrowth, and a
## nursery plan whose 12-day wait is over gets its sapling.
##
## THE HARVEST, per tree and year: a MATURE tree (§5.6 age) gives its §5.6 yield once, in its window (the store's
## `harvest_orchard`, REQ-SET-079/080); a YOUNG tree at least a year old gives decision 0672's early yield (20% of the
## same product) once a year in the same window, until it matures (`early_year`, the demo's own column: the store's
## harvested flag is §5.6's and is left to it).
##
## PLANS (ECO-009). A plan ties one sapling to one site: WAITING (the nursery has not propagated it yet), GROWING (its
## 12-day wait), READY (a sapling held for the site), then closed when it is planted. A grant sapling (the M3 two of each
## species, decision 0672) is FREE stock until a planting takes it. A site with a plan is spoken for.
##
## A MOVE (ECO-009; decision 1721, Brendan's ruling on Q-D7): a planted sapling (its first half-year) lifted and
## replanted on a free site, ONCE. The destination is spoken for from the order (`move_dest`); the tree's row is moved
## only when the replanting is done (`move_tree`: the store's own remove, plant and restore -- its age, health, chill,
## tending and harvested flags carried over), and it then SETTLES for MOVE_SETTLE_DAYS: each midnight's §5.6 day leaves
## its age where it was (`_settle`). While it is out of the ground on its way (`lifted`) it is drawn in its carrier's
## hands and is not tended.
##
## CARTS AND SHARES (ECO-010; decision 1721): a group's handcart (`group_cart`), its fresh-table share in percent
## (`group_fresh_pct`) and what it has hauled this year, all of it and to the kitchen (the share's tallies).

const Rules := preload("res://demo/orchard/orchard_rules.gd")
const Hive := preload("res://scripts/core/orchard_hive.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const ApiaryScript := preload("res://demo/hives/apiary_model.gd")

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
## Decision 1721's move refusals.
const REFUSE_MOVE_DEST: String = "SITE_MOVE_DEST"
const REFUSE_NOT_A_SAPLING: String = "NOT_A_SAPLING"
const REFUSE_MOVED_ONCE: String = "MOVED_ONCE"
const REFUSE_NO_MOVE_SITE: String = "NO_MOVE_SITE"
## How far ahead `next_harvest_day` looks (a pear planted today bears early within two years, fully within four).
const LOOKAHEAD_YEARS: int = 5

var store: Hive = null
## The apiary's hives, in this same store so their pollination links reach the trees (decision 1601).
var apiary: ApiaryScript = null
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
var group_keep: PackedInt32Array = PackedInt32Array()
## Decision 1721: each group's fresh-table share (percent, orchard_rules.gd FRESH_STEPS), whether it has its handcart,
## and this year's hauls -- all of them, and those to the kitchen pantry (milli-U).
var group_fresh_pct: PackedInt32Array = PackedInt32Array()
var group_cart: PackedByteArray = PackedByteArray()
var group_hauled_milli: PackedInt64Array = PackedInt64Array()
var group_kitchen_milli: PackedInt64Array = PackedInt64Array()
## The groves (ECO-015; decision 1721 makes them two): whether each is protected, the season (absolute index) it was
## last observed, and its record.
var grove_protected: PackedByteArray = PackedByteArray()
var grove_seen_season: PackedInt32Array = PackedInt32Array()
var grove_record: Array[PackedStringArray] = []
## Per site (decision 1721): whether its tree has been moved (once only), the days it still settles, whether it is out
## of the ground on its way to a new site, and the site a move from it goes to (NONE).
var moved: PackedByteArray = PackedByteArray()
var settle_days: PackedInt32Array = PackedInt32Array()
var lifted: PackedByteArray = PackedByteArray()
var move_dest: PackedInt32Array = PackedInt32Array()

var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""The village's orchard as it opens: the old trees on their blocks, the empty sites, the hedge, the grant in the
	nursery, the default policies and the grove protected."""
	store = Hive.new(EntityDirectory.new())
	site_ref.resize(Rules.SITE_COUNT)
	site_ref.fill(Hive.NULL_REF)
	for column: PackedInt32Array in [planted_day, early_year, settle_days, move_dest]:
		column.resize(Rules.SITE_COUNT)
	move_dest.fill(NONE)
	for column: PackedByteArray in [inherited, moved, lifted]:
		column.resize(Rules.SITE_COUNT)
	fruit_picked_milli.resize(Hive.SPECIES_COUNT)
	saplings = Rules.GRANT_SAPLINGS.duplicate()
	plan_state.resize(Rules.MAX_PLANS)
	for column: PackedInt32Array in [plan_species, plan_site, plan_ready_day, plan_serial]:
		column.resize(Rules.MAX_PLANS)
	for column: PackedInt32Array in [group_timing, group_keep, group_fresh_pct]:
		column.resize(Rules.GROUP_COUNT)
	group_cart.resize(Rules.GROUP_COUNT)
	for column: PackedInt64Array in [group_hauled_milli, group_kitchen_milli]:
		column.resize(Rules.GROUP_COUNT)
	group_keep[0] = Rules.KEEP_STEPS[1]
	_open_groves()
	_plant_old_trees()
	apiary = ApiaryScript.new(store, Hive.MIN_CALENDAR_DAY)


func _open_groves() -> void:
	"""Every grove protected from the start (decision 0675's North hollow; decision 1721's beech hollow), unobserved."""
	grove_protected.resize(Rules.GROVE_COUNT)
	grove_protected.fill(1)
	grove_seen_season.resize(Rules.GROVE_COUNT)
	grove_seen_season.fill(-1)
	grove_record.resize(Rules.GROVE_COUNT)
	for grove: int in Rules.GROVE_COUNT:
		grove_record[grove] = PackedStringArray()


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
	var age: int = age_of(site) + maxi(0, candidate - today_hint - settle_days[site])
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
	if is_move_dest(site):
		return REFUSE_MOVE_DEST
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
	moved[site] = 0
	settle_days[site] = 0
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
	if is_move_dest(site):
		return REFUSE_MOVE_DEST
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
			_settle(site)
	if Hive.year_of_day(day + 1) != Hive.year_of_day(day):
		group_hauled_milli.fill(0)
		group_kitchen_milli.fill(0)
	apiary.close_day(day)
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

func set_grove_protected(grove: int, on: bool) -> void:
	"""Protect grove `grove` from felling (or lift it)."""
	if Rules.is_grove(grove) and (grove_protected[grove] == 1) != on:
		grove_protected[grove] = 1 if on else 0
		revision += 1


func is_grove_protected(grove: int) -> bool:
	"""Whether grove `grove` is protected."""
	return Rules.is_grove(grove) and grove_protected[grove] == 1


func protected_grove_at(at: Vector2) -> int:
	"""The protected grove `at` stands in (NONE: none, or its grove is not protected)."""
	var grove: int = Rules.grove_of(at)
	return grove if is_grove_protected(grove) else NONE


func record_observation(grove: int, season_index: int, line: String) -> void:
	"""Grove `grove`'s observation for the season `season_index` (absolute: year * 4 + season), kept newest first,
	MAX_RECORDS."""
	grove_seen_season[grove] = season_index
	var record: PackedStringArray = grove_record[grove]
	record.insert(0, line)
	if record.size() > Rules.MAX_RECORDS:
		record.resize(Rules.MAX_RECORDS)
	grove_record[grove] = record
	revision += 1


static func season_index_of_day(day: int) -> int:
	"""Seasons since the calendar began (0: Y1 spring) of absolute day `day`."""
	@warning_ignore("integer_division") var index: int = (day - Hive.MIN_CALENDAR_DAY) / SimClock.DAYS_PER_SEASON
	return index


# --- moving a sapling (ECO-009; decision 1721) ---------------------------------------------------------------------------

func is_move_dest(site: int) -> bool:
	"""Whether a move is bringing a sapling to `site` (it is spoken for)."""
	return Array(move_dest).has(site)


func move_options(site: int) -> int:
	"""The first site a sapling on `site` may be moved to (NONE: none): empty, not promised to a plan or another move."""
	for dest: int in Rules.SITE_COUNT:
		if dest != site and not has_tree(dest) and plan_for_site(dest) == NONE and not is_move_dest(dest):
			return dest
	return NONE


func move_refusal(site: int, dest: int) -> String:
	"""Why the tree on `site` may not be moved to `dest` ("" when it may): a sapling (a planted tree in its first
	half-year), never moved before, to an empty site nothing else is promised to."""
	if not has_tree(site):
		return REFUSE_NOT_ELIGIBLE
	if inherited[site] == 1 or not Rules.is_movable_age(age_of(site)):
		return REFUSE_NOT_A_SAPLING
	if moved[site] == 1:
		return REFUSE_MOVED_ONCE
	if not Rules.is_site(dest) or dest == site or has_tree(dest) or plan_for_site(dest) != NONE:
		return REFUSE_NO_MOVE_SITE
	if is_move_dest(dest) and move_dest[site] != dest:
		return REFUSE_NO_MOVE_SITE
	return ""


func reserve_move(site: int, dest: int) -> bool:
	"""Speak for `dest` for the move from `site` (refused as `move_refusal` says)."""
	if not move_refusal(site, dest).is_empty():
		return false
	move_dest[site] = dest
	revision += 1
	return true


func cancel_move(site: int) -> void:
	"""The move from `site` is over or given up: its destination freed, the sapling back in the ground."""
	if not Rules.is_site(site) or (move_dest[site] == NONE and lifted[site] == 0):
		return
	move_dest[site] = NONE
	lifted[site] = 0
	revision += 1


func set_lifted(site: int, on: bool) -> void:
	"""The sapling on `site` is out of the ground on its way (or set back in its hole)."""
	if Rules.is_site(site) and (lifted[site] == 1) != on:
		lifted[site] = 1 if on else 0
		revision += 1


func move_tree(site: int, day: int) -> bool:
	"""Replant the tree on `site` at its move's destination on `day`: the store's row removed and planted again there
	with its §4.2 state carried over, moved once, settling MOVE_SETTLE_DAYS. False (nothing changed) when refused."""
	var dest: int = move_dest[site]
	if not move_refusal(site, dest).is_empty():
		return false
	var slot: int = slot_of(site)
	var state := PackedInt32Array([species_of(site), age_of(site), health_of(site), store.chill_days_of(slot).value,
		1 if store.is_tended_today(slot) else 0, 1 if store.is_harvested_year(slot) else 0])
	var origin: Vector2i = Rules.SITE_ORIGIN[dest]
	if not store.preview_planting(origin.x, origin.y, state[0], day).ok:
		return false
	store.remove_orchard(site_ref[site])
	var made: Hive.OpResult = store.plant_orchard(origin.x, origin.y, state[0], day)
	store.restore_orchard_state(made.ref, state[1], state[2], state[3], state[4] == 1, state[5] == 1)
	_carry_columns(site, dest, made.ref)
	return true


func _carry_columns(site: int, dest: int, ref: Vector2i) -> void:
	"""The demo's own columns follow the tree from `site` to `dest`: planted day and early year; moved once, settling."""
	site_ref[dest] = ref
	inherited[dest] = 0
	planted_day[dest] = planted_day[site]
	early_year[dest] = early_year[site]
	moved[dest] = 1
	settle_days[dest] = Rules.MOVE_SETTLE_DAYS
	lifted[dest] = 0
	site_ref[site] = Hive.NULL_REF
	for column: PackedInt32Array in [planted_day, early_year, settle_days]:
		column[site] = 0
	moved[site] = 0
	lifted[site] = 0
	move_dest[site] = NONE
	revision += 1


func _settle(site: int) -> void:
	"""A moved tree settling: the day's §5.6 growth undone (its age stands still), health and chill as the day left them."""
	if settle_days[site] <= 0:
		return
	settle_days[site] -= 1
	var slot: int = slot_of(site)
	store.restore_orchard_state(site_ref[site], maxi(0, age_of(site) - 1), health_of(site), store.chill_days_of(slot).value,
		store.is_tended_today(slot), store.is_harvested_year(slot))


# --- the groups' carts and shares (ECO-010; decision 1721) ---------------------------------------------------------------

func haul_load_milli(group: int) -> int:
	"""The most one haul of group `group` carries: its cart's load, else a basket's."""
	return Rules.CART_LOAD_MILLI if has_cart(group) else Rules.HAUL_LOAD_MILLI


func has_cart(group: int) -> bool:
	"""Whether group `group` has its handcart."""
	return Rules.is_group(group) and group_cart[group] == 1


func add_cart(group: int) -> bool:
	"""Group `group`'s handcart is built (false: it has one already)."""
	if not Rules.is_group(group) or group_cart[group] == 1:
		return false
	group_cart[group] = 1
	revision += 1
	return true


func prefers_kitchen(group: int, load_milli: int) -> bool:
	"""Whether group `group`'s next haul of `load_milli` should go to the fresh table (its share, orchard_rules.gd
	`to_kitchen`)."""
	return Rules.to_kitchen(group_fresh_pct[group], group_kitchen_milli[group], group_hauled_milli[group], load_milli)


func note_hauled(group: int, milli: int, to_kitchen: bool) -> void:
	"""`milli` of group `group`'s hauled on, to the kitchen pantry or a keeping store (the share's tallies)."""
	if not Rules.is_group(group) or milli <= 0:
		return
	group_hauled_milli[group] += milli
	if to_kitchen:
		group_kitchen_milli[group] += milli
	revision += 1


func kitchen_share_pct(group: int) -> int:
	"""What share of group `group`'s hauls this year went to the kitchen pantry, percent (0 with none)."""
	if group_hauled_milli[group] <= 0:
		return 0
	@warning_ignore("integer_division") var pct: int = group_kitchen_milli[group] * Rules.PERCENT / group_hauled_milli[group]
	return pct
