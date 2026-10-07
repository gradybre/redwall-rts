extends "res://test/framework/test_case.gd"
## Preserving (decision 1611, PRESERVE #18): GDD §5.7's `dry_fruit` on the rack (the Dryer, sharing its slots with
## `dry_fish`) and `ration` at the preserving table, through the fishery's station jobs on real brains walking the real
## layout; the new pantry items (dried fruit, rations) with their §5.7 shelf, raw NP and storage ageing; their refusals,
## cards and words; REQ-SET-094's half on a cancel; and the books. Built as test_demo_fishery.gd builds its rig.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const Rules := preload("res://demo/fishery/fishery_rules.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const FisheryViewScript := preload("res://demo/fishery/fishery_view.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const PreserveText := preload("res://demo/preserve/preserve_text.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const FisheryWork := preload("res://demo/work/fishery_work.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 6000
const APPLE: int = Catalog.ITEM_APPLE

## The rig: the placeholder cast on the village water and the fishery's stations over a fresh pantry.
class Rig:
	var cast: DemoCastScript = null
	var fishery: FisheryScript = null
	var pantry: PantryScript = null
	var takes: TakesScript = null
	var calendar: CalendarScript = null
	var driver: Driver = null

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _services: ServicesScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


func _rig() -> Rig:
	"""The placeholder cast walking the real layout round the water's band and the preserving table, and the fishery
	over a fresh pantry, the stores, the calendar at 06:00 spring 1 and a mild weather."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	circles.append_array(Recipes.land_obstacles())
	var links := WaterplayScript.make_links(_map_cache, circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	var ids: Driver.IdsResult = Driver.resolve_species_item_ids()
	rig.driver = Driver.create(ids.ids, 0, 4403).driver as Driver
	rig.calendar = CalendarScript.new()
	var weather := DemoWeatherScript.new()
	weather.observe(0, 1, 8, 120, 0, WeatherCore.EVENT_NONE)
	rig.pantry = PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.takes = TakesScript.new()
	rig.fishery = FisheryScript.new()
	rig.fishery.configure(rig.cast, rig.driver, rig.pantry, rig.takes, _services.stores, rig.calendar, weather, _map_cache)
	return rig


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES, board: bool = true) -> bool:
	"""Step the cast, the calendar and the fishery until `done()` -- handing a waiting job to a free resident who may take
	it, as the work board does (`board`)."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if board and frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.driver.advance_ticks(maxi(rig.calendar.tick - rig.driver.completed_tick(), 0))
		rig.fishery.update(usec)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""Each waiting job to the first idle resident who may take it."""
	var f: FisheryScript = rig.fishery
	for j: int in Tables.MAX_JOBS:
		if not f.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = f.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.in_water and f.eligibility(j, who).is_empty() and f.claim(j, who):
				break


func _stock_rations(rig: Rig) -> void:
	"""A batch's flour 2, dried fish 1 and nuts 1 (and a little over) in the first store, and water in the butt."""
	for item: int in [Catalog.ITEM_FLOUR, Catalog.ITEM_DRIED_FISH, Catalog.ITEM_NUTS]:
		assert_true(rig.pantry.add_into(item, 3000, 0, _read), "%s stocked" % Catalog.ITEM_KEYS[item])
	_services.stores.water_milli_u = 5000


# --- the numbers -----------------------------------------------------------------------------------------------------------

func test_the_rows_are_the_gdds() -> void:
	"""§5.7: dry_fruit fruit 4 -> 3, 20 WU + 12 h, Dryer; ration flour 2, dried fish 1, nuts 1, water 1 -> 3, 24 WU,
	Kitchen; dry_fish unchanged (decision 0434)."""
	assert_equal(Recipes.GDD_ROW.slice(0, 3), ["dry_fish", "dry_fruit", "ration"], "the rows")
	assert_equal([Recipes.IN_CATEGORY[1], Recipes.IN_MILLI[1], Recipes.OUT_MILLI[1], Recipes.WORK_MWU[1],
		Recipes.PASSIVE_HOURS[1], Recipes.STATION[1]], [Catalog.CAT_FRUIT, 4000, 3000, 20000, 12, Recipes.STATION_RACK],
		"dry_fruit")
	assert_equal([Recipes.IN_MILLI[2], Recipes.IN_MILLI[3], Recipes.IN_MILLI[4], Recipes.WATER_MILLI[2],
		Recipes.OUT_MILLI[2], Recipes.WORK_MWU[2], Recipes.PASSIVE_HOURS[2]], [2000, 1000, 1000, 1000, 3000, 24000, 0],
		"ration")
	assert_equal([Recipes.IN_MILLI[0], Recipes.OUT_MILLI[0], Recipes.WORK_MWU[0], Recipes.PASSIVE_HOURS[0]],
		[Rules.DRY_IN_MILLI, Rules.DRY_OUT_MILLI, Rules.DRY_WORK_MWU, Rules.DRY_PASSIVE_HOURS], "dry_fish as 0434")
	assert_equal(Recipes.food_in_milli(Recipes.R_RATION), 4000, "a ration batch's food")
	assert_true(Recipes.is_passive(Recipes.R_DRY_FRUIT) and not Recipes.is_passive(Recipes.R_RATION), "passive rows")
	assert_false(Recipes.is_recipe(-1) or Recipes.is_recipe(Recipes.RECIPE_COUNT), "bounds")
	assert_equal(Recipes.category_words(Catalog.CAT_DRIED_FISH), "dried fish", "words")
	assert_equal(Recipes.category_words(99), "food", "an unknown category")


func test_the_new_items_are_appended_with_their_section_5_7_rows() -> void:
	"""Dried fruit (32) and rations (33) appended (never renumbering): 720 h and 1440 h, their own categories, eaten as
	they are at 1400 and 2400 NP; the pantry index carries them."""
	assert_equal([Catalog.ITEM_KEYS[32], Catalog.ITEM_KEYS[33]], [&"dried_fruit", &"ration"], "appended")
	assert_equal(Catalog.ITEM_KEYS.size(), Catalog.PANTRY_ITEM_COUNT, "every item keyed")
	assert_equal([Catalog.shelf_hours_of(Catalog.ITEM_DRIED_FRUIT), Catalog.shelf_hours_of(Catalog.ITEM_RATION)], [720, 1440],
		"§5.7 shelf")
	assert_equal([Catalog.category_of(32), Catalog.category_of(33)], [Catalog.CAT_DRIED_FRUIT, Catalog.CAT_RATION], "categories")
	assert_equal([MealRules.raw_np_per_u(32), MealRules.raw_np_per_u(33)], [1400, 2400], "directly edible")
	assert_equal([MealRules.CATEGORY_WORDS[14], MealRules.CATEGORY_WORDS[15]], ["dried fruit", "rations"], "words")
	assert_true(Catalog.PANTRY_ITEM_COUNT <= TakesScript.MASK_BITS, "fits the takes' item mask")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/farm/pantry_index.json"))
	assert_equal((index["items"] as Array).size(), Catalog.PANTRY_ITEM_COUNT, "the index has every item")
	assert_equal(String((index["items"] as Array)[32]["item_key"]), "dried_fruit", "in order")


func test_a_ration_keeps_longer_in_a_cellar() -> void:
	"""§5.8: the store's factor ages a ration lot -- a cellar (350) keeps it about three times a covered store's (1000)."""
	var storage := StorageScript.new(Vector2.ZERO)
	storage.add_provider(func() -> Array: return [
		{StorageScript.KEY_ID: &"t_covered", StorageScript.KEY_POSITION: Vector2.ZERO, StorageScript.KEY_CAPACITY_U: 50,
			StorageScript.KEY_PERMILLE: 1000, StorageScript.KEY_LABEL: "Covered"},
		{StorageScript.KEY_ID: &"t_cellar", StorageScript.KEY_POSITION: Vector2(4.0, 0.0), StorageScript.KEY_CAPACITY_U: 50,
			StorageScript.KEY_PERMILLE: 350, StorageScript.KEY_LABEL: "Cellar"}])
	var pantry := PantryScript.new(storage)
	assert_true(pantry.add_into(Catalog.ITEM_RATION, 3000, storage.count() - 2, _read), "in the covered store")
	var covered: int = pantry.lot_spoil_hours(_read.value, 0)
	assert_true(pantry.add_into(Catalog.ITEM_RATION, 3000, storage.count() - 1, _read), "in the cellar")
	var cellar: int = pantry.lot_spoil_hours(_read.value, 0)
	assert_true(covered > 0 and cellar > covered * 2, "%d h against %d h" % [cellar, covered])


# --- dried fruit on the rack ---------------------------------------------------------------------------------------------------

func test_the_rack_dries_four_fruit_into_three_over_twelve_hours() -> void:
	"""§5.7 dry_fruit at the Dryer (the rack, decision 0434): the 4 U of fruit that spoil first set aside, withdrawn at the
	rack, 20 WU hung, 12 h in its slot with the worker free, taken down: 3 U dried fruit stored; the fish's books
	untouched."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(APPLE, 6000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_DRY_FRUIT, PackedInt32Array([1])), "", "ordered")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_FRUIT), 2000, "4 U set aside")
	assert_equal(f.tables.s_recipe[0], Recipes.R_DRY_FRUIT, "its slot dries fruit")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[0] == Tables.SLOT_CURING), "hung")
	assert_equal(rig.pantry.milli_of(APPLE), 2000, "4 U withdrawn at the rack")
	assert_equal(f.tables.job_count(), 0, "the worker free while it dries")
	rig.calendar.tick += 12 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_DRIED_FRUIT) == 3000), "3 U dried fruit")
	assert_equal([f.batch_in_milli[1], f.batch_out_milli[1], f.preserves_stored_milli], [4000, 3000, 3000], "booked")
	assert_equal([f.dried_in_milli, f.dried_out_milli], [0, 0], "not as fish")
	assert_equal(f.tables.s_state[0], Tables.SLOT_EMPTY, "the slot free")


func test_fish_and_fruit_share_the_racks_four_slots() -> void:
	"""§5.9's Dryer has four passive slots, whatever it dries: two of fish and two of fruit fill it; a fifth is refused."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.FIRST_CATCH, 8000, 0, _read)
	rig.pantry.add_into(APPLE, 10000, 0, _read)
	for recipe: int in [Recipes.R_DRY_FISH, Recipes.R_DRY_FRUIT, Recipes.R_DRY_FISH, Recipes.R_DRY_FRUIT]:
		assert_equal(f.order_batch(recipe, PackedInt32Array()), "", "slot taken")
	assert_equal(f.batch_refusal(Recipes.R_DRY_FRUIT), "all 4 rack slots are taken", "full")
	assert_equal(f.refused_code, "RACK_FULL", "its code")
	assert_equal(Array(f.tables.s_recipe).slice(0, Rules.RACK_SLOTS), [0, 1, 0, 1], "each rack slot's row")


func test_dry_fruit_says_what_is_missing() -> void:
	"""No fruit: refused with the stock and the way to get some (Orchard ▸ Harvest); no room: says so."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(APPLE, 3000, 0, _read)
	assert_equal(f.batch_refusal(Recipes.R_DRY_FRUIT),
		"the stores hold 3.0 U of fruit nobody has set aside; a batch takes 4.0 U", "short")
	assert_equal([f.refused_code, f.refused_fix], ["NO_FRUIT", Recipes.IN_FIX[1]], "code and fix")
	assert_equal(f.order_batch(Recipes.R_DRY_FRUIT, PackedInt32Array()), f.batch_refusal(Recipes.R_DRY_FRUIT), "the order agrees")
	assert_equal(f.tables.job_count(), 0, "nothing opened")


# --- rations at the preserving table ----------------------------------------------------------------------------------------

func test_rations_are_packed_at_the_preserving_table() -> void:
	"""§5.7 ration: flour 2, dried fish 1, nuts 1 set aside at the order, withdrawn with the butt's 1 U of water when the
	work starts at the preserving table, 24 WU, then 3 U of rations carried to the held store."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_stock_rations(rig)
	var water: int = _services.stores.water_milli_u
	assert_equal(f.order_batch(Recipes.R_RATION, PackedInt32Array([2])), "", "ordered")
	var j: int = f.tables.j_live.find(1)
	assert_equal(f.tables.j_kind[j], Tables.KIND_BATCH, "a batch with no passive wait")
	assert_equal(f.place_words(j), "the food set aside", "first, the fetch")
	assert_equal(Recipes.STATION_NAMES[Recipes.STATION[f.tables.j_recipe[j]]], "the preserving table", "then the table")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_FLOUR), 1000, "2 U of flour set aside")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_RATION) == 3000), "3 U of rations stored")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_FLOUR), rig.pantry.milli_of(Catalog.ITEM_DRIED_FISH),
		rig.pantry.milli_of(Catalog.ITEM_NUTS)], [1000, 2000, 2000], "its food withdrawn")
	assert_equal(_services.stores.water_milli_u, water - 1000, "1 U of water")
	assert_equal([f.batch_in_milli[2], f.batch_out_milli[2], f.preserves_stored_milli], [4000, 3000, 3000], "booked")
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0, 400), "over")
	assert_equal(rig.pantry.reserved_milli_of(0), 0, "no room left held")


func test_rations_say_what_is_missing() -> void:
	"""Each input checked in turn, nobody's reservations counted: no nuts, no water, no room -- each in words with its fix."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_FLOUR, 2000, 0, _read)
	rig.pantry.add_into(Catalog.ITEM_DRIED_FISH, 1000, 0, _read)
	assert_true(f.batch_refusal(Recipes.R_RATION).begins_with("the stores hold 0 U of nuts"), f.batch_refusal(Recipes.R_RATION))
	assert_equal(f.refused_code, "NO_NUTS", "its code")
	rig.pantry.add_into(Catalog.ITEM_NUTS, 1000, 0, _read)
	_services.stores.water_milli_u = 500
	assert_equal(f.batch_refusal(Recipes.R_RATION), "it needs 1.0 U of water in the butt", "no water")
	_services.stores.water_milli_u = 5000
	assert_equal(f.batch_refusal(Recipes.R_RATION), "", "it can")
	rig.takes.reserve_into(rig.pantry, rig.takes.new_take(), Catalog.CAT_FLOUR, 2000, 0, _read)
	assert_true(f.batch_refusal(Recipes.R_RATION).contains("of flour nobody has set aside"), "the kitchen's flour is not free")


func test_a_ration_batch_cancelled_after_it_started_spoils_half() -> void:
	"""REQ-SET-094: cancelled once its food was withdrawn, half of its 4 U of food becomes spoiled food."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_stock_rations(rig)
	f.order_batch(Recipes.R_RATION, PackedInt32Array([1]))
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.tables.j_started[j] == 1), "started")
	assert_equal(f.cancel_job(j), "", "cancelled while working")
	assert_equal(rig.pantry.spoiled_milli, 2000, "half the 4 U")
	assert_equal(rig.pantry.reserved_milli_of(0), 0, "its room released")


# --- the words ---------------------------------------------------------------------------------------------------------------

func test_the_board_and_the_roster_say_what_is_made() -> void:
	"""The Work screen's action and the roster's words are the recipe's own, not the fish's."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(APPLE, 4000, 0, _read)
	_stock_rations(rig)
	f.order_batch(Recipes.R_DRY_FRUIT, PackedInt32Array())
	f.order_batch(Recipes.R_RATION, PackedInt32Array())
	var work := FisheryWork.new(f)
	var task := TaskRecord.new()
	work.fill(task, 0)
	assert_equal(task.action, "Dry fruit", "the rack's job")
	work.fill(task, 1)
	assert_equal(task.action, "Pack rations", "the table's job")
	assert_equal([f.job_label(0), f.job_label(1)], ["Drying fruit", "Packing rations"], "the roster's")
	assert_equal(Tables.KIND_WORDS[Tables.KIND_BATCH], "Pack rations", "the kind's own words")
	assert_true(f.doing_text(1, f.tables.j_serial[1]).begins_with("Packing rations"), f.doing_text(1, f.tables.j_serial[1]))


func test_the_guide_has_the_preserves() -> void:
	"""The field guide's dried fruit and rations: their use, recipe and shelf (decision 1611)."""
	var guide := FieldGuideScript.new()
	for item: int in [Catalog.ITEM_DRIED_FRUIT, Catalog.ITEM_RATION]:
		var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.item_id(item)))
		assert_equal(entry.summary, PreserveText.summary(item), "%s's summary" % Catalog.ITEM_KEYS[item])
	var fields: PackedStringArray = PreserveText.guide_fields(Catalog.ITEM_RATION, 2400)
	assert_true(fields[1].contains("flour 2.0 U, dried fish 1.0 U, nuts 1.0 U, water 1.0 U make 3.0 U, 24 WU"), fields[1])
	assert_true(PreserveText.guide_fields(Catalog.ITEM_DRIED_FRUIT, 1400)[1].contains("12 hours at the rack"), "the wait")
	assert_true(PreserveText.is_station_good(Catalog.ITEM_RATION) and not PreserveText.is_station_good(APPLE), "which are")
	assert_equal(PreserveText.recipe_of(Catalog.ITEM_DRIED_FISH), -1, "the fish row's dried fish is the guide's own")


func test_the_preserving_table_is_drawn_and_walked_round() -> void:
	"""Its shelf of jars and its crock stand at the table (placeholders unstaged); the cast walks round them."""
	var rig := _rig()
	var view: FisheryViewScript = _keep(FisheryViewScript.new()) as FisheryViewScript
	view.configure(rig.fishery, PropsScript.new())
	assert_true(view.has_node(NodePath("Preserves_jar_shelf")) and view.has_node(NodePath("Preserves_crock_stoneware")),
		"both drawn")
	assert_equal(Recipes.land_obstacles().size(), 4, "the table's two circles and the brewery's two")
	assert_true(rig.fishery.spot(&"table").distance_to(Recipes.TABLE_AT) < 2.0, "the table's spot is reachable nearby")


func _shrink_lot(rig: Rig, item: int, to_milli: int) -> void:
	"""Take `item`'s lot down to `to_milli` behind the takes' back (as only a direct withdrawal can)."""
	for lot: int in PantryScript.MAX_LOTS:
		if rig.pantry.lot_item(lot) == item:
			var excess: int = rig.pantry.lot_milli(lot) - to_milli
			assert_true(rig.pantry.withdraw_into(lot, rig.pantry.lot_serial(lot), excess, _read), "shrunk")
			return


func test_a_batch_short_of_one_input_is_given_up_whole() -> void:
	"""All or nothing (REQ-SET-118): a ration batch whose nuts lot shrank below its 1 U after the order is given up when
	its work would start -- no flour or dried fish withdrawn, nothing made, its take and room let go."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_stock_rations(rig)
	assert_equal(f.order_batch(Recipes.R_RATION, PackedInt32Array([1])), "", "ordered")
	_shrink_lot(rig, Catalog.ITEM_NUTS, 500)
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "given up")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_FLOUR), rig.pantry.milli_of(Catalog.ITEM_DRIED_FISH),
		rig.pantry.milli_of(Catalog.ITEM_NUTS), rig.pantry.milli_of(Catalog.ITEM_RATION)], [3000, 3000, 500, 0], "nothing moved")
	assert_equal(f.batch_in_milli[Recipes.R_RATION], 0, "nothing booked")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_FLOUR), 3000, "its take released")
	assert_equal(rig.pantry.reserved_milli_of(0), 0, "its room released")


func test_a_ration_batch_with_the_butt_drawn_down_is_given_up() -> void:
	"""The butt emptied between the order and the start: the batch is given up, nothing withdrawn."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_stock_rations(rig)
	f.order_batch(Recipes.R_RATION, PackedInt32Array([1]))
	_services.stores.water_milli_u = 0
	assert_true(_run(rig, func() -> bool: return f.tables.job_count() == 0), "given up")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_FLOUR), rig.pantry.milli_of(Catalog.ITEM_RATION)], [3000, 0], "nothing moved")


func test_rations_are_worked_at_the_table_and_fruit_at_the_rack() -> void:
	"""Each recipe's worker stands at its own station: the ration packer at the preserving table, a fruit take-down's
	place the rack."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	_stock_rations(rig)
	f.order_batch(Recipes.R_RATION, PackedInt32Array([1]))
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.step_of(j) == FisheryScript.S_STATION and f.tables.j_at[j] == 1), "at work")
	assert_true(f.brain_of(1).surface_point().distance_to(f.spot(&"table")) < 1.5, "at the table")
	f.tables.j_recipe[j] = Recipes.R_DRY_FRUIT
	f.tables.j_kind[j] = Tables.KIND_TAKE_DOWN
	assert_equal(f.place_words(j), "the rack", "a fruit batch's place")
