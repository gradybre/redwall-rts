extends RefCounted
## THE KITCHEN GARDEN (review ECO-004 and feature #48 -- "kitchen garden plots: small herb and salad beds by the kitchen,
## tended by the cook between meals" -- decision 0883). A place the player makes: small garden beds laid out on the
## garden's sites, grouped under ONE plan, sharing a path, a work shelf and a water point, and tended by the cook.
## Presentation-side control of the demo farm; every crop number is still the settlement's own (farm_sim.gd).
##
## THE SITES are farm_catalog.gd's GARDEN_AT: four bounded 2 m modules round a cross of paths across the road from the
## kitchen. LAYING OUT a bed is a DESIGNATION (GDD §5.6: "field designation is 4-256 tiles ... field grouping is a
## UI/work aggregation") -- at once and free, as painting a field is; the work is the sowing. TAKING ONE UP is refused
## while anything stands in it, and keeps the soil's history (BAL-SAFE-014). The four sites together are four tiles, the
## GDD's smallest field; a single garden bed is the demo's one-tile bed, as every field bed already is (decision 0196).
##
## THE GROUP. The laid garden beds are one group with one PLAN: the crop the garden is sown with (`plan_item`) and one
## order that sows every empty garden bed with it (`sow_all`) -- the review's "group beds under one plan". The tending
## policies hold per group too (farm_tending.gd, decision 0885).
##
## THE SERVICE POINTS, each an adopted rule, none a bonus:
##   * the PATHS between the beds are the GDD §5.9 dirt path's ground (no materials, 2 WU a tile); the demo draws them
##     and does not model their +10% speed;
##   * the WORK SHELF is GDD §5.9's Shelf furniture -- "50000g pantry capacity" -- a pantry store of SHELF_CAPACITY_U
##     (50000 g at §5.7's 250 g a raw unit) at §5.8's pantry factor (750). It goes up with the first bed laid out and
##     stays (food in it is never moved by a garden being taken up). It is an ordinary store: the pantry sends any
##     harvest to the slowest-spoiling store with room, the nearest on a tie (farm_pantry.gd), so the garden's harvests
##     go to it and so may the field's when it is nearer than the kitchen pantry;
##   * the WATER POINT is the village well, the GDD's one water building (§5.9 "Draw water 10 U/10 WU"); a Water job
##     fetches there as for any bed.
## The layout's effect is the WALKING it costs, shown and never turned into a hidden bonus (the review: "show walking
## cost rather than imposing a rectangular perfect-farm bonus"): each bed's distance to the shelf and to the well, and a
## round of the laid beds (`round_metres`). Distances are straight lines on the ground, said as "about".
##
## THE COOK TENDS IT (#48). Between meals -- from the end of breakfast's serving to the hour supper is cooked from
## (meal_rules.gd END_HOUR and COOK_FROM_HOUR: 09:00 to 15:00) -- a waiting job on a garden bed is KEPT for the village
## cook (the kitchen's `designated`) while the cook could take it -- already on garden work, or free by the work board's
## own test (idle, farm work not forbidden to its crew; `bind_claim_check`) -- and for at most KEEP_LIMIT_TICKS (a game
## hour): the work board and the routine crew pass it by for anyone else (`is_kept`, through farm_crew.gd
## `set_keep_rule`). Outside those hours, with the cook busy elsewhere (cooking, drawing water, an order, asleep, indoors),
## after the hour, or with "The cook tends the garden" off, anyone may take it. HERB beds are not offered: herbs are forage in the GDD (§5.5), with no §5.6 crop row to grow by -- a
## proposal of decision 0883. The salad crops are the ingredients the farm already grows.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

const SHELF_ID: StringName = &"garden_shelf"
const SHELF_LABEL: String = "Garden shelf"
## GDD §5.9: "Shelf | 1x1 | wood 2 | 16 | 50000g pantry capacity"; §5.7: "All raw food units weigh 250 g".
const SHELF_GRAMS: int = 50000
const RAW_UNIT_GRAMS: int = 250
@warning_ignore("integer_division") const SHELF_CAPACITY_U: int = SHELF_GRAMS / RAW_UNIT_GRAMS
const SHELF_PERMILLE: int = StockAge.STORE_FACTOR[StockAge.STORAGE_PANTRY]
const NOBODY: int = -1
const KEPT_WORDS: String = "kept for the cook: the cook tends the kitchen garden between meals"
## A garden job kept for the cook longer than this (calendar ticks: one game hour) is released to anyone.
const KEEP_LIMIT_TICKS: int = SimClock.TICKS_PER_HOUR
const SITE_TITLE: String = "Garden site %d"

## Between-meal hours the cook tends the garden in (see THE COOK TENDS IT): breakfast's serving ends, supper's cooking.
const WINDOW_FROM_HOUR: int = MealRules.END_HOUR[MealRules.MEAL_BREAKFAST]
const WINDOW_TO_HOUR: int = MealRules.COOK_FROM_HOUR[MealRules.MEAL_SUPPER]

## Whether the cook tends the garden (#48); the player may turn it off (Planner ▸ Kitchen garden).
var cook_tends: bool = true
## The garden's shared crop (THE GROUP; NO_ITEM: none chosen yet).
var plan_item: int = Catalog.NO_ITEM
## Whether the work shelf stands (it goes up with the first bed laid out, and stays).
var shelf_up: bool = false
## Bumped by every change a reader could see.
var revision: int = 0

var _sim: SimScript = null
var _crew: CrewScript = null
var _well_at: Vector2 = Vector2.ZERO
## `() -> int`: the village cook's actor index (NOBODY: none).
var _cook_of: Callable = Callable()
var _read: IntMath.IntResult = IntMath.IntResult.new()
## `(who: int) -> bool`: the work board's claim test (`bind_claim_check`); none: the brain's own test.
var _claim_check: Callable = Callable()
## Per job row: the serial last kept and the tick it was first kept (`_kept_for`).
var _kept_serial: PackedInt64Array = PackedInt64Array()
var _kept_since: PackedInt64Array = PackedInt64Array()


func configure(sim: SimScript, crew: CrewScript, well_at: Vector2) -> void:
	"""Run the garden over this farm and crew; water comes from the well at `well_at`. The crew's keep rule is set."""
	_sim = sim
	_crew = crew
	_well_at = well_at
	_kept_serial.resize(JobsScript.MAX_JOBS)
	_kept_serial.fill(-1)
	_kept_since.resize(JobsScript.MAX_JOBS)
	if crew != null:
		crew.set_keep_rule(kept_from)


func bind_cook(cook_of: Callable) -> void:
	"""`cook_of() -> int`: the village cook (the kitchen's `designated`), who tends the garden between meals."""
	_cook_of = cook_of


# --- laying out ---------------------------------------------------------------------------------------------------

func lay_out(bed: int) -> String:
	"""Lay out a garden bed on site `bed` (a designation, at once); the shelf goes up with the first. Returns the
	answer the panel shows."""
	var done: FarmingScript.OpResult = _sim.lay_out(bed)
	if not done.ok:
		return "Can't lay out a bed: %s" % ("a bed is laid out there already" if done.error == SimScript.REFUSE_ALREADY
			else "that is no garden site")
	var first: bool = not shelf_up
	shelf_up = true
	revision += 1
	return "Bed %d laid out in the kitchen garden%s" % [bed + 1, " — the garden's work shelf is up" if first else ""]


func take_up(bed: int) -> String:
	"""Take garden bed `bed` up again (refused while anything stands in it, or a job is on it). Returns the answer."""
	if _crew != null and _has_job(bed):
		return "Can't take the bed up: a job is on it — cancel its jobs first"
	var done: FarmingScript.OpResult = _sim.take_up(bed)
	if not done.ok:
		return "Can't take the bed up: %s" % FarmCard.reason_words(done.error)
	revision += 1
	return "Bed %d taken up: the site is bare again (its soil keeps its history)" % (bed + 1)


func _has_job(bed: int) -> bool:
	"""Whether any job is on the bed's board."""
	for row: int in JobsScript.MAX_JOBS:
		if _crew.jobs.is_live(row) and _crew.jobs.bed[row] == bed:
			return true
	return false


func laid_beds() -> PackedInt32Array:
	"""The garden beds laid out now, in site order."""
	var out := PackedInt32Array()
	for k: int in Catalog.GARDEN_SITES:
		if _sim.is_laid(Catalog.GARDEN_FIRST + k):
			out.append(Catalog.GARDEN_FIRST + k)
	return out


func site_title(bed: int) -> String:
	"""'Garden site 2' for a site not laid out, 'Bed 8 · kitchen garden' once it is."""
	if _sim.is_laid(bed):
		return "Bed %d · kitchen garden" % (bed + 1)
	return SITE_TITLE % (bed - Catalog.GARDEN_FIRST + 1)


# --- the shelf -----------------------------------------------------------------------------------------------------

func provider() -> Callable:
	"""The storage provider (farm_storage.gd STORAGE-PROVIDER API) for the work shelf: `() -> Array`."""
	return shelf_entries


func shelf_entries() -> Array:
	"""The work shelf as a storage entry once it stands; none before (allocates: the pantry asks hourly)."""
	if not shelf_up:
		return []
	return [{
		StorageScript.KEY_ID: SHELF_ID,
		StorageScript.KEY_POSITION: Catalog.GARDEN_SHELF_AT,
		StorageScript.KEY_CAPACITY_U: SHELF_CAPACITY_U,
		StorageScript.KEY_PERMILLE: SHELF_PERMILLE,
		StorageScript.KEY_LABEL: SHELF_LABEL,
	}]


# --- walking (the layout's cost) ----------------------------------------------------------------------------------

func shelf_metres(bed: int) -> float:
	"""How far a bed's centre is from the work shelf (m, straight)."""
	return Catalog.bed_centre_m(bed).distance_to(Catalog.GARDEN_SHELF_AT)


func well_metres(bed: int) -> float:
	"""How far a bed's centre is from the well, the garden's water point (m, straight)."""
	return Catalog.bed_centre_m(bed).distance_to(_well_at)


func walking_text(bed: int) -> String:
	"""'about 2.0 m to the shelf · about 7.4 m to the well' for one bed."""
	return "about %.1f m to the shelf · about %.1f m to the well" % [shelf_metres(bed), well_metres(bed)]


func round_metres() -> int:
	"""A round of the laid garden: every bed watered from the well and its harvest carried to the shelf -- there and
	back for each -- in whole metres (0 with no bed laid)."""
	var total: float = 0.0
	for bed: int in laid_beds():
		total += 2.0 * (well_metres(bed) + shelf_metres(bed))
	return roundi(total)


# --- the group's plan ---------------------------------------------------------------------------------------------

func set_plan_item(item: int) -> void:
	"""The crop the garden is sown with (NO_ITEM: none)."""
	plan_item = item if Catalog.is_item(item) else Catalog.NO_ITEM
	revision += 1


func sow_all(members: PackedInt32Array = PackedInt32Array()) -> String:
	"""THE GROUP's one order: choose `plan_item` for every laid, empty, unrested garden bed and order its sowing (to
	`members`, else the board -- and between meals the cook). Returns what happened, bed by bed."""
	if not Catalog.is_item(plan_item):
		return "Choose the garden's crop first"
	var said := PackedStringArray()
	for bed: int in laid_beds():
		var code: StringName = _sim.sow_refusal(bed, plan_item)
		if code != SimScript.REFUSE_NONE:
			said.append("Bed %d: %s" % [bed + 1, FarmCard.reason_words(code)])
			continue
		said.append("Bed %d: %s" % [bed + 1, _sow(bed, members)])
	if said.is_empty():
		return "No garden bed is laid out yet"
	revision += 1
	return "Sowing the garden with %s — %s" % [Catalog.ITEM_LABELS[plan_item].to_lower(), "; ".join(said)]


func _sow(bed: int, members: PackedInt32Array) -> String:
	"""Choose the garden's crop for `bed` and order its sowing; a refused order (a full board) puts the bed's own choice
	back. Returns the order's answer."""
	var before: int = _sim.chosen_of(bed)
	_sim.choose(bed, plan_item)
	var said: String = _crew.order(JobsScript.KIND_SOW, bed, members, JobsScript.ORIGIN_PLAYER)
	if not _crew.jobs.job_on_bed_into(JobsScript.KIND_SOW, bed, _read):
		_sim.restore_choice(bed, before)
	return said


# --- the cook (#48) -------------------------------------------------------------------------------------------------

static func in_cook_window(hour: int) -> bool:
	"""Whether `hour` (0..23) is between meals: the cook's garden hours (see THE COOK TENDS IT)."""
	return hour >= WINDOW_FROM_HOUR and hour < WINDOW_TO_HOUR


func cook() -> int:
	"""The village cook's actor index (NOBODY: no kitchen bound)."""
	return int(_cook_of.call()) if _cook_of.is_valid() else NOBODY


func can_tend(who: int) -> bool:
	"""Whether the cook `who` could take a garden job now: already on one, or free to be given work -- the work board's
	own test when the board is bound (`bind_claim_check`: idle, and farm work not forbidden to its crew), else its brain's:
	under no order, on the surface, awake, not lying down, not indoors."""
	if who == NOBODY or _crew == null:
		return false
	if _crew.jobs.job_of_worker_into(who, _read):
		return Catalog.is_garden(_crew.jobs.bed[_read.value])
	if _claim_check.is_valid():
		return bool(_claim_check.call(who))
	var brain: BrainScript = _crew.brain_of(who)
	return brain.order == BrainScript.ORDER_NONE and not brain.underground and not brain.resting and not brain.lying \
		and not brain.indoors


func is_kept(row: int, who: int) -> bool:
	"""Whether waiting job `row` is kept from resident `who` for the cook (see THE COOK TENDS IT): a production job on a
	garden bed, between meals, the garden hours on, `who` not the cook, the cook able to take it, and the job not kept
	longer than KEEP_LIMIT_TICKS already (then it is anyone's). Allocates nothing: the work board asks it per candidate."""
	if not cook_tends or _sim == null or not Catalog.is_garden(_crew.jobs.bed[row]):
		return false
	var the_cook: int = cook()
	if the_cook == NOBODY or who == the_cook:
		return false
	@warning_ignore("integer_division")
	var hour: int = CalendarScript.hour_index_at(_sim.calendar.tick) % SimClock.HOURS_PER_DAY
	if not in_cook_window(hour) or not can_tend(the_cook):
		return false
	return _kept_for(row) <= KEEP_LIMIT_TICKS


func _kept_for(row: int) -> int:
	"""How long job `row` (by its serial) has been kept, in calendar ticks, starting its clock the first time it is."""
	if _kept_serial[row] != _crew.jobs.serial[row]:
		_kept_serial[row] = _crew.jobs.serial[row]
		_kept_since[row] = _sim.calendar.tick
	return _sim.calendar.tick - _kept_since[row]


func kept_from(row: int, who: int) -> String:
	"""farm_crew.gd's keep rule: KEPT_WORDS when job `row` is kept from `who` (`is_kept`), else ""."""
	return KEPT_WORDS if is_kept(row, who) else ""


func bind_claim_check(check: Callable) -> void:
	"""`check(who) -> bool`: whether the work board could give `who` farm work now (its idle test and the crew's farm
	priority); the cook keeps the garden's jobs only while it holds (see THE COOK TENDS IT)."""
	_claim_check = check


func set_cook_tends(on: bool) -> void:
	"""Turn the cook's garden hours on or off (#48)."""
	cook_tends = on
	revision += 1
