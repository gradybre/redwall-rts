extends "res://test/framework/test_case.gd"
## The new recipes (decision 1625; Q-D5 (b) and (c), Brendan's "Approve and build Q-d5 and dec-007", 2026-10-07): berry jam
## and the salt-free nut cheese at the preserving table (the cheese setting in one of its two crocks), ale and cider in the
## brewery's vats, each drafted from the content library with PROVISIONAL numbers; the four items appended; ale and
## cider poured at the feast under the mead rule (no intoxication, no effect on Shared Warmth); pickles not built (salt).
## Built over the placeholder cast on the real layout, as test_demo_brew.gd.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Tables := preload("res://demo/fishery/fishery_tables.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const Recipes := preload("res://demo/preserve/preserve_rules.gd")
const PreserveText := preload("res://demo/preserve/preserve_text.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const MenuScript := preload("res://demo/regatta/regatta_menu.gd")
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
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FieldGuideScript := preload("res://demo/guide/field_guide.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 6000
const FIRST_VAT: int = 4
const FIRST_CROCK: int = 8

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
	"""Fresh demo services per test, the butt full."""
	_services = ServicesScript.new()
	_services.stores.water_milli_u = 20000


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
	"""The placeholder cast round the water's band and the stations' props, and the fishery over a fresh pantry."""
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


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES) -> bool:
	"""Step the cast, the calendar and the fishery until `done()`, handing waiting jobs to free residents."""
	for frame: int in frames:
		if bool(done.call()):
			return true
		if frame % 20 == 0:
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


# --- the rows -------------------------------------------------------------------------------------------------------------------

func test_the_four_rows_are_the_drafted_ones() -> void:
	"""Decision 1625's PROVISIONAL rows: jam berries 2 + honey 1 + water 1 -> 3, 16 WU; cheese nuts 2 + water 1 -> 2, 16 WU
	+ 24 h in a crock (no salt); ale barley 3 + water 3 -> 4, 20 WU + 72 h; cider apples 4 + water 1 -> 4, 16 WU + 72 h."""
	var rows: Array = [
		[Recipes.R_JAM, [Catalog.CAT_BERRIES, Catalog.CAT_HONEY], [2000, 1000], 1000, 3000, 16000, 0, Recipes.STATION_TABLE],
		[Recipes.R_CHEESE, [Catalog.CAT_NUTS], [2000], 1000, 2000, 16000, 24, Recipes.STATION_TABLE],
		[Recipes.R_ALE, [Recipes.SEL_BARLEY], [3000], 3000, 4000, 20000, 72, Recipes.STATION_BREWERY],
		[Recipes.R_CIDER, [Recipes.SEL_APPLE], [4000], 1000, 4000, 16000, 72, Recipes.STATION_BREWERY]]
	for row: Array in rows:
		var r: int = row[0]
		var cats: Array = []
		var milli: Array = []
		for k: int in Recipes.IN_COUNT[r]:
			cats.append(Recipes.IN_CATEGORY[Recipes.IN_FIRST[r] + k])
			milli.append(Recipes.IN_MILLI[Recipes.IN_FIRST[r] + k])
		assert_equal([cats, milli, Recipes.WATER_MILLI[r], Recipes.OUT_MILLI[r], Recipes.WORK_MWU[r], Recipes.PASSIVE_HOURS[r],
			Recipes.STATION[r]], row.slice(1), Recipes.GDD_ROW[r])
	assert_equal(Catalog.ITEM_KEYS[Catalog.ITEM_BARLEY], &"barley", "the barley the ale names")
	assert_true(TakesScript.matches(Recipes.SEL_BARLEY, Catalog.ITEM_BARLEY) and not TakesScript.matches(Recipes.SEL_BARLEY, 13),
		"barley alone, never wheat")
	assert_true(TakesScript.matches(Recipes.SEL_APPLE, Catalog.ITEM_APPLE) and not TakesScript.matches(Recipes.SEL_APPLE,
		Catalog.ITEM_PEAR), "apples alone, never pears")
	assert_equal([Recipes.category_words(Recipes.SEL_BARLEY), Recipes.category_words(Catalog.CAT_JAM)], ["barley", "jam"],
		"their words")


func test_the_items_are_appended_with_their_provisional_rows() -> void:
	"""Jam 36, cheese 37, ale 38, cider 39 appended; jam and cheese eaten as they are (850, 1600 NP), ale and cider never
	(the mead rule); keeping 720, 480, 1440, 1440 h; the index carries them."""
	assert_equal(Catalog.ITEM_KEYS.slice(36, 40), [&"jam", &"cheese", &"ale", &"cider"], "appended")
	assert_equal(Catalog.PANTRY_ITEM_COUNT, 40, "40 items")
	assert_equal([MealRules.raw_np_per_u(36), MealRules.raw_np_per_u(37), MealRules.raw_np_per_u(38),
		MealRules.raw_np_per_u(39)], [850, 1600, 0, 0], "raw NP")
	assert_equal([Catalog.shelf_hours_of(36), Catalog.shelf_hours_of(37), Catalog.shelf_hours_of(38), Catalog.shelf_hours_of(39)],
		[720, 480, 1440, 1440], "shelf")
	for item: int in range(36, 40):
		var n: int = 0
		for other: int in Catalog.PANTRY_ITEM_COUNT:
			n += 1 if Catalog.category_of(other) == Catalog.category_of(item) else 0
		assert_equal(n, 1, "%s its own category" % Catalog.ITEM_KEYS[item])
	assert_true(Catalog.PANTRY_ITEM_COUNT <= TakesScript.MASK_BITS, "fits the item mask")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/farm/pantry_index.json"))
	assert_equal((index["items"] as Array).size(), Catalog.PANTRY_ITEM_COUNT, "the index has every item")


func test_the_crocks_follow_the_vats() -> void:
	"""The preserving table's two crocks are slots 8 and 9, after the rack's and the vats'."""
	assert_equal(Recipes.SLOT_COUNT, 10, "ten slots")
	assert_equal([Recipes.station_of_slot(7), Recipes.station_of_slot(FIRST_CROCK), Recipes.station_of_slot(9),
		Recipes.station_of_slot(10)], [Recipes.STATION_BREWERY, Recipes.STATION_TABLE, Recipes.STATION_TABLE, -1], "slots")


# --- making them ---------------------------------------------------------------------------------------------------------------

func test_jam_is_cooked_at_the_preserving_table() -> void:
	"""Berries 2, honey 1 and water 1 at the table, 16 WU: 3 U of jam stored."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_BERRIES, 3000, 0, _read)
	rig.pantry.add_into(Catalog.ITEM_HONEY, 1500, 0, _read)
	assert_equal(f.order_batch(Recipes.R_JAM, PackedInt32Array([1])), "", "ordered")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_JAM) == 3000), "3 U of jam")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_BERRIES), rig.pantry.milli_of(Catalog.ITEM_HONEY)], [1000, 500], "its food")
	assert_equal(_services.stores.water_milli_u, 19000, "1 U of water")
	assert_equal([f.batch_in_milli[Recipes.R_JAM], f.batch_out_milli[Recipes.R_JAM]], [3000, 3000], "booked")


func test_a_cheese_sets_in_a_crock() -> void:
	"""Nuts 2 and water 1 at the table, 16 WU, then 24 h in a crock with the maker free, then turned out: 2 U of cheese."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_NUTS, 3000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_CHEESE, PackedInt32Array([1])), "", "ordered")
	assert_equal(f.tables.s_recipe[FIRST_CROCK], Recipes.R_CHEESE, "the first crock")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_CROCK] == Tables.SLOT_CURING), "setting")
	assert_equal(f.slots_in_use(Recipes.STATION_TABLE), 1, "one crock in use")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_NUTS), 1000, "2 U of nuts")
	rig.calendar.tick += 24 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_CHEESE) == 2000), "2 U of cheese")
	assert_equal(f.tables.s_state[FIRST_CROCK], Tables.SLOT_EMPTY, "the crock free")


func test_the_crocks_are_two() -> void:
	"""Two cheeses fill the crocks; a third is refused in words; the rack and the vats untouched."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_NUTS, 8000, 0, _read)
	for k: int in Recipes.CROCK_SLOTS:
		assert_equal(f.order_batch(Recipes.R_CHEESE, PackedInt32Array()), "", "crock %d" % k)
	assert_equal(f.batch_refusal(Recipes.R_CHEESE), "both crocks hold a cheese", "full")
	assert_equal(f.refused_code, "CROCKS_FULL", "its code")
	assert_equal([f.free_slot(Recipes.STATION_RACK), f.free_slot(Recipes.STATION_BREWERY)], [0, FIRST_VAT], "the others free")


func test_ale_brews_from_barley_alone() -> void:
	"""Barley 3 (never the wheat beside it) and water 3 into a vat, 20 WU, 72 h, drawn off: 4 U of ale."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(13, 5000, 0, _read)
	assert_true(f.batch_refusal(Recipes.R_ALE).begins_with("the stores hold 0 U of barley"), f.batch_refusal(Recipes.R_ALE))
	assert_equal(f.refused_code, "NO_BARLEY", "wheat is no barley")
	rig.pantry.add_into(Catalog.ITEM_BARLEY, 3000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_ALE, PackedInt32Array()), "", "ordered")
	var j: int = f.tables.j_live.find(1)
	assert_equal(f.tables.j_goal[j], rig.pantry.storage.position_of(0), "the fetch walks to the barley's store")
	assert_true(f.claim(j, 1), "a brewer takes it")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_VAT] == Tables.SLOT_CURING), "brewing")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_BARLEY), rig.pantry.milli_of(13)], [0, 5000], "the barley, not the wheat")
	rig.calendar.tick += 72 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_ALE) == 4000), "4 U of ale")


func test_cider_is_pressed_from_apples_alone() -> void:
	"""Apples 4 (never pears) and water 1 into a vat, 16 WU, 72 h, drawn off: 4 U of cider; the fetch walks to the apples."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_PEAR, 6000, 0, _read)
	assert_equal(f.batch_refusal(Recipes.R_CIDER), "the stores hold 0 U of apple nobody has set aside; a batch takes 4.0 U", "pears are no apples")
	rig.pantry.add_into(Catalog.ITEM_APPLE, 4000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_CIDER, PackedInt32Array([1])), "", "ordered")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_VAT] == Tables.SLOT_CURING), "brewing")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_APPLE), rig.pantry.milli_of(Catalog.ITEM_PEAR)], [0, 6000], "apples only")
	rig.calendar.tick += 72 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_CIDER) == 4000), "4 U of cider")
	assert_equal(Recipes.TAKE_DOWN_WORDS[Recipes.R_CIDER], "Draw off the cider", "its words")


# --- the feast and the guide --------------------------------------------------------------------------------------------------

func test_ale_and_cider_follow_the_mead_rule_at_the_feast() -> void:
	"""Brendan's DEC-007 ruling (2026-10-07): ale and cider poured at the feast like mead, a unit for every four guests,
	for those who came; Shared Warmth decided by the courses alone."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	pantry.add_into(Catalog.ITEM_ALE, 3000, 0, _read)
	pantry.add_into(Catalog.ITEM_CIDER, 3000, 0, _read)
	var kitchen := KitchenScript.new()
	kitchen.pantry = pantry
	kitchen.stores = _services.stores
	var menu := MenuScript.new()
	menu.configure(kitchen, _services.stores)
	menu.reserve(kitchen.takes.new_take(), 9, 0)
	assert_equal(Array(menu.drinks_planned), [0, 0, 3000, 3000], "ale and cider set aside")
	menu.second_planned = true
	menu.infusion_planned = true
	var warmth: String = menu.settle(9, 9, 9, 1000, 0)
	assert_equal(Array(menu.drinks_poured_milli), [0, 0, 3000, 3000], "poured for all nine")
	var dry := MenuScript.new()
	var bare := KitchenScript.new()
	bare.pantry = PantryScript.new(StorageScript.new(Vector2.ZERO))
	bare.stores = _services.stores
	dry.configure(bare, _services.stores)
	dry.second_planned = true
	dry.infusion_planned = true
	assert_equal(warmth, dry.settle(9, 9, 9, 1000, 0), "the warmth's answer is the same with no drink at all")
	assert_true(menu.drinks_words(9).contains("ale 3.0 U") and menu.drinks_words(9).contains("no one is made drunk"), "said")


func test_the_guide_has_the_new_recipes() -> void:
	"""The field guide: jam and cheese as food, ale and cider as feast drinks with no one made drunk."""
	var guide := FieldGuideScript.new()
	for item: int in range(Catalog.ITEM_JAM, Catalog.ITEM_CIDER + 1):
		var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.item_id(item)))
		assert_equal(entry.summary, PreserveText.summary(item), Catalog.ITEM_KEYS[item])
	assert_true(PreserveText.guide_fields(Catalog.ITEM_ALE, 0)[0].contains("No one is made drunk"), "ale")
	assert_true(PreserveText.guide_fields(Catalog.ITEM_CHEESE, 1600)[1].contains("nuts 2.0 U, water 1.0 U make 2.0 U, 16 WU and 24 hours at the preserving table"),
		PreserveText.guide_fields(Catalog.ITEM_CHEESE, 1600)[1])
	assert_true(PreserveText.guide_fields(Catalog.ITEM_JAM, 850)[2].contains("Fresh berries"), "jam's alternative")
