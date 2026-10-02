extends RefCounted
## OPTIONAL PRACTICE STORIES (decision 0481; review UX-019): three short situations kept OUTSIDE normal play, each with
## a choice, a run, a DEBRIEF and a RESTART. DEMO UI's model; practice_page.gd draws it.
##
## KEPT OUTSIDE. A story builds its own fixture from the demo's REAL models and rules -- a fresh pantry over its own
## stores, a fresh farm (its own calendar and weather), a fresh bridge surveyor over the village's authored water --
## and holds no reference to the village's services, stores, pantry, cast or calendar: it is given none, so nothing
## it does can touch the main village (test_demo_guide.gd checks the village's figures before and after every story).
## The one thing it may be handed is the WATER MAP (`water_map`): the stream's shape, which nothing writes once it is
## finalised and the bridge survey only reads -- building it costs over a second, too long to do on a click. Without
## one, the stories build the authored map once (WaterLayout) and share it.
## RESTART builds the fixture again from nothing: every run of a choice from the same start gives the same story.
##
## THE STORIES (fixture values below are the story's own, said in its text; the rules are the demo's):
##   CROSSING  Two felled oaks lie across the stream: 24 U of logs for the log stack, a crew of three carrying 6 U a
##             trip. Swim them over (refused: a loaded resident never swims -- swim_rules.gd), carry them round by the
##             ford (wading at WADE_PERMILLE, carrying at the brain's CARRY_WALK_FRACTION), or build a plank
##             footbridge at the neck first (bridges.gd's own survey and cost; the bridgewright's work rate).
##   DELIVERY  A ripe carrot bed and a covered store with no room (farm_pantry.gd's room rule, decision 0222): leave
##             it standing (the real crop arithmetic loses yield after 48 h), cook room out of the store, or rack a
##             root cellar -- the harvest goes in through a real reservation and delivery.
##   PANTRY    A household of four lays in its last harvest on the first day of autumn and must eat until winter
##             ends (24 days): keep the roots in the covered store, rack a root cellar for them, or split them. The
##             pantry ages every hour at the season's real factor; the meals take the dishes' real inputs.

const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const Rules := preload("res://demo/kitchen/meal_rules.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")
const Yard := preload("res://demo/forestry/forest_yard.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const STORY_CROSSING: int = 0
const STORY_DELIVERY: int = 1
const STORY_PANTRY: int = 2
const STORY_COUNT: int = 3
const TITLES: Array[String] = ["A loaded crew at the stream", "A delivery with nowhere to go", "A winter pantry"]
const SITUATIONS: Array[String] = [
	"Two oaks were felled across the stream: 24 U of logs must reach the log stack. A crew of three carries 6 U a trip. How do they bring it over?",
	"The carrot bed is ripe, but the covered store is full to the roof. A harvest is never cut with nowhere to go. What do you do?",
	"A household of four lays in its last harvest on Autumn 1: 150 U of roots and 100 U of oats. Nothing grows again until spring, 24 days away. Where do the roots go?",
]
const CHOICES: Array = [
	["Swim the logs over", "Carry them round by the ford", "Build a plank footbridge first"],
	["Leave the crop standing", "Cook room out of the store", "Rack a root cellar"],
	["All in the covered store", "Rack a root cellar for them", "Half and half"],
]
const LESSONS: Array[String] = [
	"A loaded resident never swims: carriers need the ford or a bridge. A bridge costs planks and work once, then every load crosses dry at full pace.",
	"A full store holds the harvest in the field, and a ripe crop starts losing yield after 48 hours. Make room before the harvest: eat from the store, or dig and rack a cellar.",
	"Food keeps by where it is kept: a cool root cellar ages it at 350 per mille, the covered store at 1000. In autumn the covered store's roots spoil in ten days.",
]

## CROSSING's fixture: the logs, the load, the crew, the walking pace (demo seconds) and the planks in store.
const LOGS_MILLI: int = 24000
const LOAD_MILLI: int = 6000
const CREW: int = 3
const WALK_M_S: float = 1.0
const PLANKS_IN_STORE_MILLI: int = 10000
## The far-bank pile, this far east of the neck site's east end, metres.
const PILE_BEYOND_M: float = 4.0
const BRIDGEWRIGHT_LEVEL: int = 6
const SKILL_PERMILLE_PER_LEVEL: int = 50
## DELIVERY's fixture: the store's stock (oats to the roof), the room a kitchen batch frees, the cellar's racks.
const STORE_FILL_ITEM: int = 15
const CARROT_BED: int = 2
const CARROT: int = 2
const WAIT_HOURS: int = 72
const RIPEN_LIMIT_HOURS: int = 400
const COOK_ROOM_MILLI: int = 10000
const CELLAR_CAPACITY_U: int = 30
## PANTRY's fixture: the household, the harvest, the days, and the season it starts in.
const HOUSEHOLD: int = 4
const ROOTS_ITEM: int = 2
const OATS_ITEM: int = 15
const ROOTS_MILLI: int = 150000
const OATS_MILLI: int = 100000
const DAYS: int = 24
const AUTUMN: int = 2
const WINTER: int = 3
const CELLAR_ID: StringName = &"practice_cellar"

## The current story's run: its lines, its outcome in a sentence, and its debrief (every choice compared).
var story: int = -1
var choice: int = -1
var log_lines: PackedStringArray = PackedStringArray()
var outcome: String = ""
var debrief: PackedStringArray = PackedStringArray()
var runs: int = 0

## The stream's shape, read-only (see KEPT OUTSIDE); none: the authored map, built once.
var water_map: WaterMapScript = null

var _read: IntMath.IntResult = IntMath.IntResult.new()
static var _authored: WaterMapScript = null


func start(which: int) -> void:
	"""Open story `which` at its start: nothing chosen, nothing run."""
	story = clampi(which, 0, STORY_COUNT - 1)
	restart()


func restart() -> void:
	"""Back to the story's start (the fixture is rebuilt by the next run)."""
	choice = -1
	log_lines = PackedStringArray()
	outcome = ""
	debrief = PackedStringArray()


func choose(which: int) -> void:
	"""Run the story with choice `which` from its fixture, and debrief it against the other choices."""
	if story < 0 or which < 0 or which >= (CHOICES[story] as Array).size():
		return
	restart()
	choice = which
	runs += 1
	var summaries := PackedStringArray()
	for k: int in (CHOICES[story] as Array).size():
		var lines := PackedStringArray()
		var said: String = _run(story, k, lines)
		summaries.append("%s %s: %s" % ["▸" if k == which else "·", CHOICES[story][k], said])
		if k == which:
			log_lines = lines
			outcome = said
	debrief = summaries
	debrief.append(LESSONS[story])


func _run(which_story: int, which_choice: int, lines: PackedStringArray) -> String:
	"""One run of a story's choice from a fresh fixture; its outcome in a sentence."""
	match which_story:
		STORY_CROSSING: return _run_crossing(which_choice, lines)
		STORY_DELIVERY: return _run_delivery(which_choice, lines)
		STORY_PANTRY: return _run_pantry(which_choice, lines)
	return ""


# --- CROSSING ----------------------------------------------------------------------------------------

func _run_crossing(which: int, lines: PackedStringArray) -> String:
	"""Swim (refused), the ford, or a footbridge at the neck first."""
	var map: WaterMapScript = _water()
	var bridges := BridgesScript.new()
	bridges.configure(map, [] as Array[Vector3], Rect2(-80.0, -80.0, 160.0, 160.0))
	var neck: PackedVector2Array = bridges.candidate_ends(0)
	var pile: Vector2 = neck[1] + (neck[1] - neck[0]).normalized() * PILE_BEYOND_M
	var stack: Vector2 = Yard.log_stack_at()
	var rounds: int = ceili(float(LOGS_MILLI) / float(LOAD_MILLI * CREW))
	if which == 0:
		lines.append("The crew walks down the bank with 6 U of logs each and stops at the water: a loaded resident never swims.")
		lines.append("Nothing crossed. The logs still lie on the far bank.")
		return "refused at the water -- 0 U delivered"
	if which == 1:
		var trip_s: float = _ford_round_s(map, pile, stack)
		@warning_ignore("integer_division") lines.append("Each round trip by the ford: %s (wading at %d%% pace, carrying at %d%%)." % [
			CardScript.hours_text(int(trip_s * 1.0e6)), SwimRules.WADE_PERMILLE / 10, int(BrainScript.CARRY_WALK_FRACTION * 100.0)])
		lines.append("%d rounds for %s: %s in all." % [rounds, FarmText.units_text(LOGS_MILLI), CardScript.hours_text(int(trip_s * rounds * 1.0e6))])
		return "%s delivered, %s" % [FarmText.units_text(LOGS_MILLI), CardScript.hours_text(int(trip_s * rounds * 1.0e6))]
	return _bridge_first(bridges, neck, pile, stack, rounds, lines)


func _water() -> WaterMapScript:
	"""The stream's shape: the one handed in, else the authored map (built once)."""
	if water_map != null:
		return water_map
	if _authored == null:
		_authored = WaterLayout.make_map()
	return _authored


func _bridge_first(bridges: BridgesScript, neck: PackedVector2Array, pile: Vector2, stack: Vector2, rounds: int,
		lines: PackedStringArray) -> String:
	"""Survey and build a plank footbridge at the neck (its own cost and work), then carry over it."""
	var survey := BridgesScript.Survey.new()
	if not bridges.survey_candidate_into(0, SwimRules.KIND_PLANK, survey) or survey.planks_milli > PLANKS_IN_STORE_MILLI:
		lines.append("No footbridge can be built at the neck: %s." % survey.reason)
		return "no bridge -- 0 U delivered"
	var build_usec: int = _build_usec(survey)
	var trip_s: float = _bridge_round_s(neck, pile, stack)
	lines.append("The bridgewright builds a %s footbridge at the neck: %s of planks, %s of work." % [
		"%.1f m" % (float(survey.deck_u) / 1024.0), FarmText.units_text(survey.planks_milli), CardScript.hours_text(build_usec)])
	lines.append("Each round trip over it: %s, dry and at full carrying pace." % CardScript.hours_text(int(trip_s * 1.0e6)))
	var total: int = build_usec + int(trip_s * rounds * 1.0e6)
	lines.append("%d rounds for %s: %s in all, the building included. The bridge stays." % [rounds,
		FarmText.units_text(LOGS_MILLI), CardScript.hours_text(total)])
	return "%s delivered, %s with the building; %s of planks spent" % [FarmText.units_text(LOGS_MILLI),
		CardScript.hours_text(total), FarmText.units_text(survey.planks_milli)]


static func _build_usec(survey: BridgesScript.Survey) -> int:
	"""A plank footbridge's work (swim_rules.gd's own stages) at the bridgewright's skill and the woods' rate."""
	var wu: int = 0
	for stage: int in SwimRules.STAGE_COUNT:
		wu += SwimRules.stage_wu(SwimRules.KIND_PLANK, stage, survey.deck_u, survey.piers)
	@warning_ignore("integer_division") return wu * SwimRules.USEC_PER_WU * 1000 / (1000 + SKILL_PERMILLE_PER_LEVEL * BRIDGEWRIGHT_LEVEL)


static func _ford_round_s(map: WaterMapScript, pile: Vector2, stack: Vector2) -> float:
	"""Pile to stack by the ford, loaded, and back empty: the ford's water waded, the rest walked."""
	var ford: PackedVector2Array = _ford_ends(map)
	var wade_m: float = ford[0].distance_to(ford[1])
	var land_m: float = pile.distance_to(ford[1]) + ford[0].distance_to(stack)
	var wade: float = float(SwimRules.WADE_PERMILLE) / 1000.0
	var loaded: float = land_m / (WALK_M_S * BrainScript.CARRY_WALK_FRACTION) \
		+ wade_m / (WALK_M_S * BrainScript.CARRY_WALK_FRACTION * wade)
	return loaded + land_m / WALK_M_S + wade_m / (WALK_M_S * wade)


static func _bridge_round_s(neck: PackedVector2Array, pile: Vector2, stack: Vector2) -> float:
	"""Pile to stack over the neck's bridge, loaded, and back empty."""
	var way_m: float = pile.distance_to(neck[1]) + neck[1].distance_to(neck[0]) + neck[0].distance_to(stack)
	return way_m / (WALK_M_S * BrainScript.CARRY_WALK_FRACTION) + way_m / WALK_M_S


static func _ford_ends(map: WaterMapScript) -> PackedVector2Array:
	"""The map's ford, its two ends in metres."""
	for c: int in map.crossing_count():
		if map.crossing_kind(c) == WaterMapScript.CROSSING_FORD:
			return PackedVector2Array([Vector2(map.crossing_a(c)) / 1024.0, Vector2(map.crossing_b(c)) / 1024.0])
	return PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


# --- DELIVERY ----------------------------------------------------------------------------------------

func _run_delivery(which: int, lines: PackedStringArray) -> String:
	"""A ripe carrot bed and a full store: wait, cook room, or rack a cellar."""
	var sim := SimScript.new()
	_ripen(sim, CARROT_BED)
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var fill: bool = pantry.add_into(STORE_FILL_ITEM, StorageScript.STORE_CAPACITY_U * 1000, 0, _read)
	var crop: int = _read.value if sim.expected_yield_into(CARROT_BED, _read) else 0
	lines.append("The carrot bed is ripe: %s expected. The covered store holds %s of oats%s." % [
		FarmText.units_text(crop), FarmText.units_text(pantry.total_milli()), "" if fill else " (could not fill)"])
	if which == 0:
		return _wait_standing(sim, crop, lines)
	if which == 1:
		_cook_room(pantry, lines)
	else:
		pantry.storage.add_provider(func() -> Array: return [{"id": CELLAR_ID, "position": Vector2(4.0, 0.0),
			"capacity_u": CELLAR_CAPACITY_U, "spoilage_permille": StockAge.STORE_FACTOR[StockAge.STORAGE_CELLAR],
			"label": "Root cellar"}])
		pantry.refresh_locations()
		lines.append("A root cellar is dug and racked: %d U of shelves." % CELLAR_CAPACITY_U)
	return _deliver(pantry, crop, lines)


func _ripen(sim: SimScript, bed: int) -> void:
	"""Grow the farm's own calendar on until `bed` is ripe (bounded)."""
	for hour: int in RIPEN_LIMIT_HOURS:
		if sim.stage_of(bed) == SimScript.STAGE_RIPE:
			return
		sim.advance_usec(CalendarScript.HOUR_USEC)


func _wait_standing(sim: SimScript, crop: int, lines: PackedStringArray) -> String:
	"""Leave the ripe crop uncut for WAIT_HOURS: the real ripe-expiry rule takes its toll."""
	sim.advance_usec(CalendarScript.HOUR_USEC * WAIT_HOURS)
	var standing: bool = sim.stage_of(CARROT_BED) == SimScript.STAGE_RIPE
	var now: int = _read.value if standing and sim.expected_yield_into(CARROT_BED, _read) else 0
	lines.append("Three days on, nobody has made room. The crop still stands, %s." % (
		"now %s" % FarmText.units_text(now) if now > 0 else "withered"))
	return "0 U stored; the crop fell from %s to %s" % [FarmText.units_text(crop), FarmText.units_text(now)]


func _cook_room(pantry: PantryScript, lines: PackedStringArray) -> void:
	"""The kitchen cooks COOK_ROOM_MILLI of the store's oats into meals, freeing that much room."""
	var left: int = COOK_ROOM_MILLI
	for lot: int in PantryScript.MAX_LOTS:
		if left <= 0:
			break
		if pantry.lot_item(lot) != STORE_FILL_ITEM:
			continue
		var take: int = mini(left, pantry.lot_milli(lot))
		if pantry.withdraw_into(lot, pantry.lot_serial(lot), take, _read):
			left -= take
	@warning_ignore("integer_division") lines.append("The kitchen cooks %s of oats into porridge (%d portions): that much room is free." % [
		FarmText.units_text(COOK_ROOM_MILLI - left), (COOK_ROOM_MILLI - left) / Rules.INPUT_MILLI[Rules.DISH_PORRIDGE] * 2])


func _deliver(pantry: PantryScript, crop: int, lines: PackedStringArray) -> String:
	"""The harvest reserves its room, is cut, carried and shelved (a real reservation and delivery)."""
	if not pantry.reserve_near_into(CARROT, crop, Vector2.ZERO, _read):
		lines.append("Still no room for %s: the crop stands." % FarmText.units_text(crop))
		return "0 U stored"
	var hold: int = _read.value
	pantry.hold_location_into(hold, _read)
	var where: int = _read.value
	pantry.store_upto_into(CARROT, crop, where, hold, _read)
	pantry.release(hold)
	@warning_ignore("integer_division") var hours: int = Catalog.shelf_hours_of(CARROT) * 1000 / pantry.storage.permille_of(where)
	lines.append("The carrots are cut, carried and shelved in the %s: %s, keeping about %d hours there." % [
		pantry.storage.label_of(where).to_lower(), FarmText.units_text(_read.value), hours])
	return "%s stored in the %s" % [FarmText.units_text(_read.value), pantry.storage.label_of(where).to_lower()]


# --- PANTRY ------------------------------------------------------------------------------------------

func _run_pantry(which: int, lines: PackedStringArray) -> String:
	"""Lay the harvest in where the choice says, then age and eat it day by day to the end of winter."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	if which > 0:
		@warning_ignore("integer_division") pantry.storage.add_provider(func() -> Array: return [{"id": CELLAR_ID, "position": Vector2(2.0, 0.0),
			"capacity_u": ROOTS_MILLI / 1000, "spoilage_permille": StockAge.STORE_FACTOR[StockAge.STORAGE_CELLAR],
			"label": "Root cellar"}])
		pantry.refresh_locations()
	@warning_ignore("integer_division") var in_cellar: int = 0 if which == 0 else (ROOTS_MILLI if which == 1 else ROOTS_MILLI / 2)
	pantry.add_into(ROOTS_ITEM, ROOTS_MILLI - in_cellar, 0, _read)
	if in_cellar > 0:
		pantry.add_into(ROOTS_ITEM, in_cellar, 1, _read)
	pantry.add_into(OATS_ITEM, OATS_MILLI, 0, _read)
	lines.append("Laid in: %s of carrots in the covered store, %s in the cellar, %s of oats." % [
		FarmText.units_text(ROOTS_MILLI - in_cellar), FarmText.units_text(in_cellar), FarmText.units_text(OATS_MILLI)])
	var short_days: int = 0
	for day: int in DAYS:
		short_days += 1 if _eat_day(pantry, day, lines) else 0
		_age_day(pantry, AUTUMN if day < SimClock.DAYS_PER_SEASON else WINTER, day, lines)
	return "%d of %d days fed in full; %s spoiled" % [DAYS - short_days, DAYS, FarmText.units_text(pantry.spoiled_milli)]


func _eat_day(pantry: PantryScript, day: int, lines: PackedStringArray) -> bool:
	"""Breakfast and supper for the household (porridge, then soup; the other dish when one's food is short). True
	when a meal fell short."""
	var batches: int = ceili(float(HOUSEHOLD) / float(Rules.PORTIONS_PER_BATCH[0]))
	var short: bool = false
	for dish: int in [Rules.DISH_PORRIDGE, Rules.DISH_SOUP]:
		var cooked: int = dish if _food_of(pantry, dish) >= batches * Rules.INPUT_MILLI[dish] else Rules.other(dish)
		var need: int = batches * Rules.INPUT_MILLI[cooked]
		if _food_of(pantry, cooked) < need:
			short = true
			lines.append("%s: not enough food for %s -- the household goes hungry." % [_day_text(day), Rules.MEAL_NAMES[dish]])
			continue
		_take_food(pantry, cooked, need)
	return short


func _age_day(pantry: PantryScript, season: int, day: int, lines: PackedStringArray) -> void:
	"""Twenty-four hours of the pantry's own ageing; say what spoiled."""
	var before: int = pantry.spoiled_milli
	for hour: int in SimClock.HOURS_PER_DAY:
		pantry.age_hour(season)
	if pantry.spoiled_milli > before:
		lines.append("%s: %s of food spoiled in store." % [_day_text(day), FarmText.units_text(pantry.spoiled_milli - before)])


static func _food_of(pantry: PantryScript, dish: int) -> int:
	"""How much of `dish`'s food the pantry holds."""
	var total: int = 0
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		if Rules.is_input(dish, item):
			total += pantry.milli_of(item)
	return total


func _take_food(pantry: PantryScript, dish: int, need: int) -> void:
	"""Take `need` of `dish`'s food, the lot that would spoil soonest first (the kitchen's own order)."""
	while need > 0:
		var lot: int = _soonest_lot(pantry, dish)
		if lot < 0:
			return
		var take: int = mini(need, pantry.lot_milli(lot))
		if not pantry.withdraw_into(lot, pantry.lot_serial(lot), take, _read):
			return
		need -= take


static func _soonest_lot(pantry: PantryScript, dish: int) -> int:
	"""The live lot of `dish`'s food that is oldest against its store's pace (-1 for none)."""
	var best: int = -1
	var best_left: int = 0
	for lot: int in PantryScript.MAX_LOTS:
		if pantry.lot_milli(lot) <= 0 or not Rules.is_input(dish, pantry.lot_item(lot)):
			continue
		@warning_ignore("integer_division") var left: int = (Catalog.shelf_hours_of(pantry.lot_item(lot)) * 1000 - pantry.lot_age(lot)) * 1000 \
			/ maxi(pantry.storage.permille_of(pantry.lot_location(lot)), 1)
		if best < 0 or left < best_left:
			best = lot
			best_left = left
	return best


static func _day_text(day: int) -> String:
	"""'Autumn 3', 'Winter 1' for the story's day `day` (0: Autumn 1)."""
	if day < SimClock.DAYS_PER_SEASON:
		return CalendarScript.day_text(AUTUMN, day + 1)
	return CalendarScript.day_text(WINTER, day - SimClock.DAYS_PER_SEASON + 1)
