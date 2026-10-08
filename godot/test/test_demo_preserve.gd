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
const FarmingScript := preload("res://scripts/core/farming.gd")
const RationReserveScript := preload("res://demo/preserve/ration_reserve.gd")
const DemoFisheryScript := preload("res://demo/fishery/demo_fishery.gd")
const WaterPanelScript := preload("res://demo/waterplay/water_panel.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
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


## The kitchen's side of the rack's fish (decision 1739), as Callables over one take of its own: what it holds, and
## giving that back -- each call counted.
class KitchenFish extends RefCounted:
	var takes: TakesScript = null
	var pantry: PantryScript = null
	var take: int = 0
	var asked: Array[int] = []
	## The category it holds: fish, or the mill's grain (decision 1741).
	var crop: int = Catalog.CAT_FISH

	func held() -> int:
		"""The food of its category its take holds in store."""
		return takes.live_milli(pantry, take, TakesScript.AT_STORE, crop)

	func give(milli: int) -> int:
		"""Give back up to `milli`, counted."""
		asked.append(milli)
		return takes.release_milli(pantry, take, milli, 0, crop)


func _kitchen_fish(rig: Rig, milli: int) -> KitchenFish:
	"""A kitchen holding `milli` of fish for meals beyond its next one, bound to the rig's fishery."""
	var k := KitchenFish.new()
	k.takes = rig.takes
	k.pantry = rig.pantry
	k.take = rig.takes.new_take()
	assert_true(rig.takes.reserve_into(rig.pantry, k.take, Catalog.CAT_FISH, milli, 0, _read), "the kitchen holds fish")
	rig.fishery.bind_spare_fish(k.held, k.give)
	return k


func test_dry_fish_takes_the_kitchen_s_fish_beyond_its_next_meal() -> void:
	"""Decision 1739 (F3 (a)): 1 U of fish free and 3 U held by the kitchen beyond its next meal is a batch (4 U):
	the refusal counts both, the order asks the kitchen for exactly the 3 U it lacks, and the batch sets its 4 U aside;
	the card shows what may be taken."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.FIRST_CATCH, 4000, 0, _read)
	var kitchen := _kitchen_fish(rig, 3000)
	var input: int = Recipes.IN_FIRST[Recipes.R_DRY_FISH]
	assert_equal(f.input_available_milli(input), Rules.DRY_IN_MILLI, "1 U free + 3 U beyond the next meal")
	assert_equal(f.batch_refusal(Recipes.R_DRY_FISH), "", "a batch may be ordered")
	assert_equal(f.order_batch(Recipes.R_DRY_FISH, PackedInt32Array()), "", "ordered")
	assert_equal(kitchen.asked, [3000] as Array[int], "the kitchen asked for exactly what was lacking")
	var j: int = f.tables.job_count() - 1
	assert_equal(rig.takes.live_milli(rig.pantry, f.tables.j_take[j]), Rules.DRY_IN_MILLI, "the batch holds its 4 U")
	assert_equal(kitchen.held(), 0, "the kitchen gave its 3 U")


func test_dry_fish_leaves_the_kitchen_alone_when_free_fish_will_do_or_too_little_is_spare() -> void:
	"""Free fish enough: the kitchen is not asked. Free and spare one milli-U short: refused NO_FISH, nothing asked.
	Unbound: only free fish counts."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var input: int = Recipes.IN_FIRST[Recipes.R_DRY_FISH]
	rig.pantry.add_into(Catalog.FIRST_CATCH, 5000, 0, _read)
	var kitchen := _kitchen_fish(rig, 1000)
	assert_equal(f.order_batch(Recipes.R_DRY_FISH, PackedInt32Array()), "", "4 U free: ordered")
	assert_true(kitchen.asked.is_empty(), "the kitchen not asked")
	var short := _rig()
	short.pantry.add_into(Catalog.FIRST_CATCH, Rules.DRY_IN_MILLI - 1, 0, _read)
	var little := _kitchen_fish(short, 1000)
	little.takes.release_milli(short.pantry, little.take, 1, 0, Catalog.CAT_FISH)
	assert_equal(short.fishery.input_available_milli(input), Rules.DRY_IN_MILLI - 1, "one milli-U short in all")
	assert_true(not short.fishery.batch_refusal(Recipes.R_DRY_FISH).is_empty() and short.fishery.refused_code == "NO_FISH",
		"refused for fish")
	assert_true(little.asked.is_empty(), "nothing asked of the kitchen")
	var bare := _rig()
	bare.pantry.add_into(Catalog.FIRST_CATCH, 3000, 0, _read)
	assert_equal(bare.fishery.input_available_milli(input), 3000, "unbound: the free fish only")
	assert_equal(bare.fishery.input_available_milli(Recipes.IN_FIRST[Recipes.R_DRY_FRUIT]), 0, "fruit: no kitchen fish")
	var fruit := _rig()
	var spare := KitchenFish.new()
	spare.takes = fruit.takes
	spare.pantry = fruit.pantry
	spare.take = fruit.takes.new_take()
	fruit.fishery.bind_spare_fish(spare.held, spare.give)
	fruit.fishery._take_spare_fish(Recipes.R_DRY_FRUIT)
	assert_true(spare.asked.is_empty(), "a fruit batch short of fruit never asks the kitchen for fish")



## A kitchen that says it holds fish beyond its next meal but gives none back (the review's M4).
class StingyFish extends RefCounted:
	func held() -> int:
		"""Claims 3 U."""
		return 3000

	func give(_milli: int) -> int:
		"""Gives nothing."""
		return 0


func test_a_kitchen_that_gives_no_fish_back_refuses_the_batch() -> void:
	"""The count said there was fish, but the kitchen gave none back: the order is refused NO_FISH and opens nothing --
	never a short batch (ARCH-AUTH-003; the review of f86d79c2)."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.FIRST_CATCH, 1000, 0, _read)
	var stingy := StingyFish.new()
	f.bind_spare_fish(stingy.held, stingy.give)
	assert_equal(f.batch_refusal(Recipes.R_DRY_FISH), "", "the count passes")
	assert_false(f.order_batch(Recipes.R_DRY_FISH, PackedInt32Array()).is_empty(), "the order refused")
	assert_equal(f.refused_code, "NO_FISH", "for fish")
	assert_equal(f.tables.job_count(), 0, "nothing opened")


func test_only_a_fish_input_counts_the_kitchen_s_fish() -> void:
	"""With the kitchen holding fish beyond its next meal, the dry fruit's fruit is still only the free fruit."""
	var rig := _rig()
	rig.pantry.add_into(Catalog.FIRST_CATCH, 3000, 0, _read)
	rig.pantry.add_into(APPLE, 1000, 0, _read)
	var kitchen := _kitchen_fish(rig, 3000)
	assert_equal(rig.fishery.input_available_milli(Recipes.IN_FIRST[Recipes.R_DRY_FRUIT]), 1000, "fruit: the free fruit only")
	assert_equal(rig.fishery.input_available_milli(Recipes.IN_FIRST[Recipes.R_DRY_FISH]), kitchen.held(),
		"fish: the kitchen's 3 U too")


# --- grain for the mill (decision 1741) --------------------------------------------------------------------------

const WHEAT: int = 13


func _kitchen_grain(rig: Rig, milli: int) -> KitchenFish:
	"""A kitchen holding `milli` of grain for meals beyond its next one, bound to the rig's mill."""
	var k := KitchenFish.new()
	k.takes = rig.takes
	k.pantry = rig.pantry
	k.crop = FarmingScript.CROP_GRAIN
	k.take = rig.takes.new_take()
	assert_true(rig.takes.reserve_into(rig.pantry, k.take, k.crop, milli, 0, _read), "the kitchen holds grain")
	rig.fishery.bind_spare_grain(k.held, k.give)
	return k


func test_the_mill_takes_the_kitchen_s_grain_beyond_its_next_meal() -> void:
	"""Brendan's F6 (decision 1741): 1 U of grain free and 2 U held by the kitchen beyond its next meal is a mill batch
	(3 U): the refusal counts both, the order asks the kitchen for exactly the 2 U it lacks, the batch sets its 3 U
	aside. Free grain enough asks nothing; unbound, only the free grain counts."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(WHEAT, 3000, 0, _read)
	var kitchen := _kitchen_grain(rig, 2000)
	assert_equal(f.grain_available_milli(), Rules.MILL_IN_MILLI, "1 U free + 2 U beyond the next meal")
	assert_equal(f.mill_refusal(), "", "a batch may be ordered")
	assert_equal(f.order_mill(PackedInt32Array()), "", "ordered")
	assert_equal(kitchen.asked, [2000] as Array[int], "the kitchen asked for exactly what was lacking")
	var j: int = f.tables.job_count() - 1
	assert_equal(rig.takes.live_milli(rig.pantry, f.tables.j_take[j]), Rules.MILL_IN_MILLI, "the batch holds its 3 U")
	var plenty := _rig()
	plenty.pantry.add_into(WHEAT, 4000, 0, _read)
	var idle := _kitchen_grain(plenty, 1000)
	assert_equal(plenty.fishery.order_mill(PackedInt32Array()), "", "3 U free: ordered")
	assert_true(idle.asked.is_empty(), "the kitchen not asked")
	var bare := _rig()
	bare.pantry.add_into(WHEAT, 2000, 0, _read)
	assert_equal(bare.fishery.grain_available_milli(), 2000, "unbound: the free grain only")
	assert_false(bare.fishery.mill_refusal().find("the kitchen holds") >= 0, "unbound: the words name no kitchen")


func test_a_kitchen_that_gives_no_grain_back_refuses_the_mill() -> void:
	"""The count said there was grain, but the kitchen gave none back: refused NO_GRAIN, nothing opened; short in all,
	refused NO_GRAIN with the kitchen's grain named and nothing asked."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(WHEAT, 1000, 0, _read)
	var stingy := StingyFish.new()
	f.bind_spare_grain(stingy.held, stingy.give)
	assert_equal(f.mill_refusal(), "", "the count passes")
	assert_false(f.order_mill(PackedInt32Array()).is_empty(), "the order refused")
	assert_equal(f.refused_code, "NO_GRAIN", "for grain")
	assert_equal(f.tables.job_count(), 0, "nothing opened")
	var short := _rig()
	short.pantry.add_into(WHEAT, Rules.MILL_IN_MILLI - 1, 0, _read)
	var little := _kitchen_grain(short, 1000)
	assert_equal(short.fishery.grain_available_milli(), Rules.MILL_IN_MILLI - 1, "free and spare: one milli-U short")
	assert_true(short.fishery.mill_refusal().contains("or the kitchen holds beyond its next meal"), "the kitchen named")
	assert_equal(short.fishery.refused_code, "NO_GRAIN", "one milli-U short in all")
	assert_true(little.asked.is_empty(), "nothing asked of the kitchen")


# --- the ration reserve (decision 1742) --------------------------------------------------------------------------

func _reserve_rig(stock: Array) -> Rig:
	"""A rig whose fishery keeps the demo's ration reserve (6 U), stocked with the [item, milli] pairs, water in the
	butt, and the reserve topped up."""
	var rig := _rig()
	for pair: Array in stock:
		assert_true(rig.pantry.add_into(int(pair[0]), int(pair[1]), 0, _read), "stocked")
	_services.stores.water_milli_u = 5000
	rig.fishery.ration_reserve.target_milli = RationReserveScript.DEMO_TARGET_MILLI
	rig.fishery.top_up_ration_reserve()
	return rig


func test_rations_are_packed_from_what_the_reserve_holds() -> void:
	"""Brendan's F7 (b) (decision 1742): with every input held by the ration reserve and none free, the rations' refusal
	counts the held food, the order takes it from the reserve, and the batch packing counts toward the target (so the
	reserve does not draw a second batch's food while the first is on the board -- here none is left to draw)."""
	var rig := _reserve_rig([[Catalog.ITEM_FLOUR, 2000], [Catalog.ITEM_DRIED_FISH, 1000], [Catalog.ITEM_NUTS, 1000]])
	var f: FisheryScript = rig.fishery
	for category: int in [Catalog.CAT_FLOUR, Catalog.CAT_DRIED_FISH, Catalog.CAT_NUTS]:
		assert_equal(rig.takes.free_milli_of_crop(rig.pantry, category), 0, "category %d all held" % category)
	assert_equal(f.batch_refusal(Recipes.R_RATION), "", "the held food counts for rations")
	assert_equal(f.order_batch(Recipes.R_RATION, PackedInt32Array()), "", "ordered")
	var j: int = f.tables.job_count() - 1
	assert_equal(rig.takes.live_milli(rig.pantry, f.tables.j_take[j]), Recipes.food_in_milli(Recipes.R_RATION),
		"the batch holds its 4 U")
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_FLOUR), 0, "the reserve gave it")
	assert_equal(f.rations_owned_milli(), Recipes.OUT_MILLI[Recipes.R_RATION], "the batch's 3 U count as owned")


func test_only_the_rations_count_the_reserve_s_food() -> void:
	"""The reserve's nuts are the rations': the nut cheese counts only the free nuts."""
	var rig := _reserve_rig([[Catalog.ITEM_NUTS, 3000]])
	var f: FisheryScript = rig.fishery
	var cheese_nuts: int = -1
	for k: int in Recipes.IN_COUNT[Recipes.R_CHEESE]:
		if Recipes.IN_CATEGORY[Recipes.IN_FIRST[Recipes.R_CHEESE] + k] == Catalog.CAT_NUTS:
			cheese_nuts = Recipes.IN_FIRST[Recipes.R_CHEESE] + k
	var ration_nuts: int = -1
	for k: int in Recipes.IN_COUNT[Recipes.R_RATION]:
		if Recipes.IN_CATEGORY[Recipes.IN_FIRST[Recipes.R_RATION] + k] == Catalog.CAT_NUTS:
			ration_nuts = Recipes.IN_FIRST[Recipes.R_RATION] + k
	assert_equal(f.input_available_milli(cheese_nuts), 2000, "the cheese: the 2 U free")
	assert_equal(f.input_available_milli(ration_nuts), 3000, "the rations: free and held")


func test_the_mill_grinds_the_reserve_s_grain_and_the_reserve_holds_the_flour() -> void:
	"""With no flour, the reserve holds a mill batch's grain (3 U), so none is free; the mill counts it and takes it
	from the reserve first; the flour stored is held at once (before the kitchen's next hour could plan it)."""
	var rig := _reserve_rig([[WHEAT, 3000]])
	var f: FisheryScript = rig.fishery
	assert_equal(f.ration_reserve.held_milli(FarmingScript.CROP_GRAIN), Rules.MILL_IN_MILLI, "a mill batch's grain")
	assert_equal(f.mill_refusal(), "", "the mill counts it")
	assert_equal(f.order_mill(PackedInt32Array()), "", "ordered")
	assert_equal(f.ration_reserve.held_milli(FarmingScript.CROP_GRAIN), 0, "the reserve gave it")
	assert_equal(rig.takes.live_milli(rig.pantry, f.tables.j_take[f.tables.job_count() - 1]), Rules.MILL_IN_MILLI,
		"the mill batch holds it")
	assert_true(rig.pantry.add_into(Catalog.ITEM_FLOUR, 3000, 0, _read), "the flour, stored")
	f._book_stored(Catalog.ITEM_FLOUR, 3000)
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_FLOUR), 2000, "held as it is stored")


func test_the_emergency_action_releases_the_reserve() -> void:
	"""§5.10's "release ordinary production food reserves" (REQ-SET-146, never taken by itself): everything held goes
	free; restored, the reserve gathers again."""
	var rig := _reserve_rig([[Catalog.ITEM_DRIED_FISH, 1000]])
	var f: FisheryScript = rig.fishery
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "held")
	var revision: int = f.revision
	f.release_ration_reserve(true)
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_DRIED_FISH), 1000, "released: free")
	assert_true(f.revision > revision, "the panels learn")
	f.release_ration_reserve(false)
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "restored: held again")


func test_the_reserve_gathers_each_hour_and_when_dried_fish_is_stored() -> void:
	"""Food that comes in by other ways (nuts from a trip) is held at the fishery's next game hour; dried fish off the
	rack is held as it is stored."""
	var rig := _reserve_rig([])
	var f: FisheryScript = rig.fishery
	assert_true(rig.pantry.add_into(Catalog.ITEM_NUTS, 2000, 0, _read), "nuts brought in")
	f._follow_hours()
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_NUTS), 0, "the same hour: not yet")
	rig.calendar.tick += SimClock.TICKS_PER_HOUR
	f._follow_hours()
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_NUTS), 1000, "the next hour: held")
	assert_true(rig.pantry.add_into(Catalog.ITEM_DRIED_FISH, 3000, 0, _read), "dried fish off the rack")
	f._book_stored(Catalog.ITEM_DRIED_FISH, 3000)
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "held as it is stored")


func test_the_reserve_counts_the_rations_in_store_and_only_ration_batches() -> void:
	"""Rations in store at the target: nothing held. Another recipe's batch on the board (a Dry fish batch) is not
	rations: the reserve still holds (the review of c9f67f16)."""
	var full := _reserve_rig([[Catalog.ITEM_RATION, 6000], [Catalog.ITEM_DRIED_FISH, 3000]])
	assert_equal(full.fishery.rations_owned_milli(), 6000, "6 U in store")
	assert_equal(full.fishery.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 0, "at the target: nothing held")
	var rig := _reserve_rig([[Catalog.ITEM_DRIED_FISH, 1000], [Catalog.FIRST_CATCH, 4000]])
	assert_equal(rig.fishery.order_batch(Recipes.R_DRY_FISH, PackedInt32Array()), "", "a Dry fish batch on the board")
	var j: int = rig.fishery.tables.open_job(Tables.KIND_BATCH, FisheryScript.PROG_MILL, -1)
	rig.fishery.tables.j_recipe[j] = Recipes.R_CORDIAL
	assert_equal(rig.fishery.rations_owned_milli(), 0, "a cordial batch (a table batch, as rations are) neither")
	rig.fishery.top_up_ration_reserve()
	assert_equal(rig.fishery.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "still held")


func test_the_reserve_replaces_the_keep_and_its_release_frees_both() -> void:
	"""1740's keep yields to the reserve (decision 1742): with a target, the keep keeps nothing -- the reserve holds the
	dried fish; released (§5.10), nothing is withheld at all; with no target the keep is as 1740 built it."""
	var rig := _reserve_rig([[Catalog.ITEM_DRIED_FISH, 3000], [Catalog.ITEM_NUTS, 2000], [Catalog.ITEM_FLOUR, 4000]])
	var f: FisheryScript = rig.fishery
	assert_equal(f.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "the reserve holds a batch's dried fish")
	assert_equal(f.ration_keep_milli(Catalog.CAT_DRIED_FISH), 0, "the keep keeps none more")
	f.release_ration_reserve(true)
	assert_equal(f.ration_keep_milli(Catalog.CAT_DRIED_FISH), 0, "released: the keep too")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_DRIED_FISH), 3000, "all free")
	f.release_ration_reserve(false)
	f.ration_reserve.target_milli = 0
	f.top_up_ration_reserve()
	assert_equal(f.ration_keep_milli(Catalog.CAT_DRIED_FISH), 1000, "no target: 1740's keep")
	f.release_ration_reserve(true)
	assert_equal(f.ration_keep_milli(Catalog.CAT_DRIED_FISH), 0, "no target, released: the keep let go too")


func test_the_reserve_lets_its_grain_go_while_its_mill_batch_grinds() -> void:
	"""The review's repro: 6 U of grain, a mill batch ordered; at the next top-up the reserve does not hold another 3 U
	for a second batch."""
	var rig := _reserve_rig([[WHEAT, 6000]])
	var f: FisheryScript = rig.fishery
	assert_equal(f.order_mill(PackedInt32Array()), "", "ordered")
	f.top_up_ration_reserve()
	assert_equal(f.ration_reserve.held_milli(FarmingScript.CROP_GRAIN), 0, "no grain held while it grinds")


# --- the reserve's controls (decision 1742; Brendan's R5) ------------------------------------------------------

func _reserve_node(rig: Rig) -> DemoFisheryScript:
	"""The Water panel's fishery node over the rig's fishery (no command, no panel: its words and verbs alone)."""
	var node: DemoFisheryScript = _keep(DemoFisheryScript.new()) as DemoFisheryScript
	node.fishery = rig.fishery
	return node


func test_the_reserve_stepper_steps_a_batch_within_its_range() -> void:
	"""UI-SET-099's stepper: a batch (3 U) a press, never below none nor above ten batches (R6, R7); the line says so."""
	var rig := _rig()
	assert_true(rig.pantry.add_into(Catalog.ITEM_DRIED_FISH, 2000, 0, _read), "dried fish in store")
	var node := _reserve_node(rig)
	assert_equal(node.reserve_text(), DemoFisheryScript.RESERVE_NONE, "no reserve: the line says how to keep one")
	var revision: int = node.fishery.revision
	assert_equal(node.step_reserve(1), "Ration reserve: keep 3.0 U of rations", "a batch up")
	assert_equal(node.fishery.ration_reserve.target_milli, 3000, "3 U")
	assert_true(node.fishery.revision > revision, "the panels learn")
	assert_equal(node.fishery.ration_reserve.held_milli(Catalog.CAT_DRIED_FISH), 1000, "held at once, not next hour")
	assert_true(node.step_reserve(-1).begins_with("Ration reserve: none"), "back to none")
	node.step_reserve(-1)
	assert_equal(node.fishery.ration_reserve.target_milli, 0, "never below none")
	assert_equal(node.step_reserve(100), "Ration reserve: keep 30.0 U of rations", "up to the cap")
	node.step_reserve(1)
	assert_equal(node.fishery.ration_reserve.target_milli, RationReserveScript.TARGET_CAP_MILLI, "never above it")


func test_release_shows_what_it_frees_then_frees_it_and_keeps_them_again() -> void:
	"""§5.10's emergency action: the line says what is held, the card what it frees (before the press); the press frees
	it and says so; the line and the card then offer to keep them again, and that press holds the food again."""
	var rig := _reserve_rig([[Catalog.ITEM_DRIED_FISH, 1000], [Catalog.ITEM_NUTS, 1000], [Catalog.ITEM_FLOUR, 2000]])
	var node := _reserve_node(rig)
	var held: String = "1.0 U dried fish, 1.0 U nuts, 2.0 U flour"
	assert_equal(node.reserve_text(), "Ration reserve: keep 6.0 U of rations (0 U owned)\nHolding %s" % held, "the line")
	var card: CardScript = node.release_card()
	assert_true(card.is_ok() and card.result.begins_with("Frees %s at once" % held), card.result)
	assert_equal(node.toggle_release(), "Food reserves released: %s free for the kitchen and the hungry" % held,
		"the answer")
	assert_true(node.fishery.ration_reserve.released, "released")
	assert_equal(rig.takes.free_milli_of_crop(rig.pantry, Catalog.CAT_FLOUR), 2000, "the flour free")
	assert_true(node.reserve_text().ends_with("\nReleased for an emergency: nothing held back until kept again"),
		node.reserve_text())
	card = node.release_card()
	assert_true(card.is_ok() and card.verb == DemoFisheryScript.KEEP_AGAIN_CAPTION, card.verb)
	assert_equal(card.result, DemoFisheryScript.KEEP_AGAIN_RESERVE, "keeping a reserve again")
	assert_equal(node.toggle_release(), "Food reserves kept again: holding %s" % held, "kept again")
	assert_false(node.fishery.ration_reserve.released, "no longer released")


func test_release_with_nothing_held_is_still_offered_and_lasts() -> void:
	"""The review of 72817b34 (MEDIUM): with a reserve kept but nothing held now, Release is still offered -- a release
	lasts, so food arriving later is not held back -- and says so; its answer says nothing was held (M27). With no
	reserve and nothing kept from raw eating, it is refused."""
	var node := _reserve_node(_reserve_rig([]))
	var card: CardScript = node.release_card()
	assert_true(card.is_ok(), "offered")
	assert_equal(card.result, DemoFisheryScript.RELEASE_NOTHING_NOW, "nothing now, nothing later")
	assert_equal(node.toggle_release(), DemoFisheryScript.RELEASED_NOTHING, "the answer")
	assert_true(node.fishery.ration_reserve.released, "released")
	var none := _reserve_node(_rig())
	assert_false(none.release_card().is_ok(), "no reserve, nothing kept: refused")
	assert_equal(none.release_card().code, "NO_RESERVE", "why")


func test_release_frees_1740_s_kept_dried_fish_with_no_reserve() -> void:
	"""The review of 72817b34 (MEDIUM): with no reserve target, 1740's keep still keeps a batch's dried fish from raw
	eating; the line says so, Release is offered and frees it."""
	var rig := _rig()
	for pair: Array in [[Catalog.ITEM_DRIED_FISH, 3000], [Catalog.ITEM_NUTS, 2000], [Catalog.ITEM_FLOUR, 4000]]:
		assert_true(rig.pantry.add_into(int(pair[0]), int(pair[1]), 0, _read), "stocked")
	var node := _reserve_node(rig)
	assert_equal(node.fishery.ration_keep_milli(Catalog.CAT_DRIED_FISH), 1000, "1740's keep")
	assert_true(node.reserve_text().ends_with("\nHolding 1.0 U dried fish kept from raw eating"), node.reserve_text())
	var card: CardScript = node.release_card()
	assert_true(card.is_ok() and card.result.begins_with("Frees 1.0 U dried fish kept from raw eating"), card.result)
	node.toggle_release()
	assert_equal(node.fishery.ration_keep_milli(Catalog.CAT_DRIED_FISH), 0, "freed")
	assert_equal(node.release_card().result, DemoFisheryScript.KEEP_AGAIN_KEEP, "no reserve: keeping the keep again")


func test_after_a_release_the_line_card_and_answers_agree() -> void:
	"""The review of 72817b34 (MEDIUM): Release, then Keep fewer to none -- the line still says released, the answer says
	nothing is held until they are kept again, the card keeps the keep again; Keep more then keeps a reserve again. The
	line counts the rations owned (M20)."""
	var rig := _reserve_rig([[Catalog.ITEM_RATION, 3000]])
	var node := _reserve_node(rig)
	assert_true(node.reserve_text().begins_with("Ration reserve: keep 6.0 U of rations (3.0 U owned)"), node.reserve_text())
	node.toggle_release()
	node.step_reserve(-1)
	assert_equal(node.step_reserve(-1),
		"Ration reserve: none — nothing is held back for rations (released: nothing is held until you keep them again)",
		"the answer")
	assert_true(node.reserve_text().begins_with(DemoFisheryScript.RESERVE_NONE)
		and node.reserve_text().contains("Released for an emergency"), node.reserve_text())
	assert_equal(node.release_card().result, DemoFisheryScript.KEEP_AGAIN_KEEP, "no reserve: the keep")
	assert_true(node.step_reserve(1).ends_with("(released: nothing is held until you keep them again)"), "still released")
	assert_equal(node.release_card().result, DemoFisheryScript.KEEP_AGAIN_RESERVE, "a reserve again")


func test_the_reserve_row_is_dressed_and_routes_only_its_own() -> void:
	"""The row: Keep fewer off at none, Keep more off at the cap, Release's caption following the state, the stepper's
	tooltips (M24); its verbs route through the panel's actions, and every other action goes on to its own verb (M28)."""
	var rig := _reserve_rig([])
	var node := _reserve_node(rig)
	var panel: WaterPanelScript = _keep(WaterPanelScript.new()) as WaterPanelScript
	panel.build()
	node._dress_reserve(panel)
	assert_false(panel.button(WaterPanelScript.ACTION_RESERVE_RELEASE).disabled, "Release offered")
	assert_true(panel.button(WaterPanelScript.ACTION_RESERVE_RELEASE).tooltip_text.contains("Nothing is held now"),
		panel.button(WaterPanelScript.ACTION_RESERVE_RELEASE).tooltip_text)
	for key: StringName in [WaterPanelScript.ACTION_RESERVE_FEWER, WaterPanelScript.ACTION_RESERVE_MORE]:
		assert_equal(panel.button(key).tooltip_text, WaterPanelScript.BUTTON_TIPS[key], "%s's tooltip" % key)
	assert_equal([panel.button(WaterPanelScript.ACTION_RESERVE_FEWER).disabled,
		panel.button(WaterPanelScript.ACTION_RESERVE_MORE).disabled], [false, false], "6 U: both ways open")
	node.on_action(WaterPanelScript.ACTION_RESERVE_FEWER)
	node.on_action(WaterPanelScript.ACTION_RESERVE_FEWER)
	node._dress_reserve(panel)
	assert_true(panel.button(WaterPanelScript.ACTION_RESERVE_FEWER).disabled, "none: Keep fewer off")
	node.on_action(WaterPanelScript.ACTION_RESERVE_MORE)
	assert_equal(node.fishery.ration_reserve.target_milli, 3000, "Keep more routes")
	node.step_reserve(100)
	node._dress_reserve(panel)
	assert_true(panel.button(WaterPanelScript.ACTION_RESERVE_MORE).disabled, "the cap: Keep more off")
	node.on_action(WaterPanelScript.ACTION_RESERVE_RELEASE)
	assert_true(node.fishery.ration_reserve.released, "Release routes")
	node._dress_reserve(panel)
	assert_equal(panel.button(WaterPanelScript.ACTION_RESERVE_RELEASE).text, DemoFisheryScript.KEEP_AGAIN_CAPTION,
		"released: the caption keeps them again")
	node.on_action(WaterPanelScript.ACTION_RESERVE_RELEASE)
	node._dress_reserve(panel)
	assert_equal(panel.button(WaterPanelScript.ACTION_RESERVE_RELEASE).text, DemoFisheryScript.RELEASE_CAPTION, "kept")
	assert_false(node._on_reserve(WaterPanelScript.ACTION_MILL), "not the reserve's")
	var mill := _reserve_node(_rig())
	assert_true(mill.fishery.pantry.add_into(WHEAT, 3000, 0, _read), "grain")
	mill.on_action(WaterPanelScript.ACTION_MILL)
	assert_equal(mill.fishery.tables.job_count(), 1, "Mill grain still reaches the mill")
