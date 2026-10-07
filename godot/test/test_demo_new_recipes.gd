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
const CropRoles := preload("res://demo/farm/farm_crop_roles.gd")
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
const DemoFisheryScript := preload("res://demo/fishery/demo_fishery.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")

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
	(the mead rule); keeping 720, 1440, 1440, 1440 h; the index carries them."""
	assert_equal(Catalog.ITEM_KEYS.slice(36, 40), [&"jam", &"cheese", &"ale", &"cider"], "appended")
	assert_equal(Catalog.ITEM_KEYS.size(), Catalog.PANTRY_ITEM_COUNT, "every item keyed")
	assert_equal([MealRules.raw_np_per_u(36), MealRules.raw_np_per_u(37), MealRules.raw_np_per_u(38),
		MealRules.raw_np_per_u(39)], [850, 1600, 0, 0], "raw NP")
	assert_equal([Catalog.shelf_hours_of(36), Catalog.shelf_hours_of(37), Catalog.shelf_hours_of(38), Catalog.shelf_hours_of(39)],
		[720, 1440, 1440, 1440], "shelf")
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
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.tables.j_at[j] == 1 and f.step_of(j) == FisheryScript.S_STATION), "at work")
	assert_true(f.packing(), "the table in use")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_CROCK] == Tables.SLOT_CURING), "setting")
	assert_equal(f.slots_in_use(Recipes.STATION_TABLE), 1, "one crock in use")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_NUTS), 1000, "2 U of nuts")
	rig.calendar.tick += 24 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_CHEESE) == 2000), "2 U of cheese")
	assert_equal(f.tables.s_state[FIRST_CROCK], Tables.SLOT_EMPTY, "the crock free")
	assert_equal(f.preserves_stored_milli, 2000, "booked as a preserve stored")
	assert_equal(Recipes.TAKE_DOWN_WORDS[Recipes.R_CHEESE], "Turn out the cheese", "its take-down's words")


func test_the_crocks_are_two() -> void:
	"""Two cheeses fill the crocks; a third is refused in words; the rack and the vats untouched."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_NUTS, 8000, 0, _read)
	for k: int in Recipes.CROCK_SLOTS:
		assert_equal(f.order_batch(Recipes.R_CHEESE, PackedInt32Array()), "", "crock %d" % k)
	assert_equal(f.batch_refusal(Recipes.R_CHEESE), "all 2 crocks are in use", "full")
	assert_equal([f.refused_code, f.refused_fix], ["CROCKS_FULL", "wait for one to be emptied"], "its code and fix")
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
	assert_equal(f.order_batch(Recipes.R_CIDER, PackedInt32Array()), "", "ordered")
	var j: int = f.tables.j_live.find(1)
	assert_equal(f.tables.j_goal[j], rig.pantry.storage.position_of(0), "the fetch walks to the apples' store")
	assert_true(f.claim(j, 1), "a brewer takes it")
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
	pantry.add_into(Catalog.ITEM_MEAD, 3000, 0, _read)
	pantry.add_into(Catalog.ITEM_ALE, 3000, 0, _read)
	pantry.add_into(Catalog.ITEM_CIDER, 5000, 0, _read)
	var kitchen := KitchenScript.new()
	kitchen.pantry = pantry
	kitchen.stores = _services.stores
	var menu := MenuScript.new()
	menu.configure(kitchen, _services.stores)
	menu.reserve(kitchen.takes.new_take(), 9, 0)
	assert_true(menu.drinks_words(9).contains("ale 3.0 U (free 0.0 U)") and menu.drinks_words(9).contains("cider 3.0 U (free 2.0 U)"),
		"each drink by its own name, its 3 U set aside: %s" % menu.drinks_words(9))
	assert_equal(Array(menu.drinks_planned), [3000, 0, 3000, 3000], "mead, ale and cider set aside")
	menu.second_planned = true
	menu.infusion_planned = true
	var warmth: String = menu.settle(9, 9, 9, 1000, 0)
	assert_equal(Array(menu.drinks_poured_milli), [3000, 0, 3000, 3000], "poured for all nine")
	var dry := MenuScript.new()
	var bare := KitchenScript.new()
	bare.pantry = PantryScript.new(StorageScript.new(Vector2.ZERO))
	bare.stores = _services.stores
	dry.configure(bare, _services.stores)
	dry.second_planned = true
	dry.infusion_planned = true
	assert_equal(warmth, dry.settle(9, 9, 9, 1000, 0), "the warmth's answer is the same with no drink at all")
	assert_true(menu.drinks_words(9).contains("no one is made drunk"), "said")


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


func test_the_new_recipes_say_what_is_missing() -> void:
	"""Each input checked with its own code and fix: the jam's berries and honey, the cheese's nuts."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	f.batch_refusal(Recipes.R_JAM)
	assert_equal([f.refused_code, f.refused_fix], ["NO_BERRIES", Recipes.IN_FIX[8]], "the jam's berries")
	rig.pantry.add_into(Catalog.ITEM_BERRIES, 2000, 0, _read)
	f.batch_refusal(Recipes.R_JAM)
	assert_equal([f.refused_code, f.refused_fix], ["NO_HONEY", Recipes.IN_FIX[9]], "its honey")
	f.batch_refusal(Recipes.R_CHEESE)
	assert_equal([f.refused_code, f.refused_fix], ["NO_NUTS", Recipes.IN_FIX[10]], "the cheese's nuts")
	f.batch_refusal(Recipes.R_ALE)
	assert_equal(f.refused_fix, Recipes.IN_FIX[11], "the barley's fix")


func test_a_cheese_cancelled_after_it_started_spoils_half_its_nuts() -> void:
	"""REQ-SET-094 for a crock row: half of its 2 U of nuts spoiled; the crock freed."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_NUTS, 2000, 0, _read)
	f.order_batch(Recipes.R_CHEESE, PackedInt32Array([1]))
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.tables.j_started[j] == 1), "started")
	assert_equal(f.cancel_job(j), "", "cancelled")
	assert_equal(rig.pantry.spoiled_milli, 1000, "half the 2 U")
	assert_equal(f.tables.s_state[FIRST_CROCK], Tables.SLOT_EMPTY, "the crock free")


func test_every_recipe_button_has_its_row() -> void:
	"""The Water panel's recipe buttons (demo_fishery.gd ACTION_RECIPES): one a row from dry fish to cider."""
	var rows: Array = DemoFisheryScript.ACTION_RECIPES.values()
	rows.sort()
	assert_equal(rows, range(Recipes.RECIPE_COUNT), "every row has its button")
	assert_equal(DemoFisheryScript.ACTION_RECIPES[&"make_jam"], Recipes.R_JAM, "Make jam")
	assert_equal(PreserveText.guide_fields(Catalog.ITEM_CHEESE, 1600)[2], "Nuts eaten as they are keep 720 game hours; set as a cheese they keep twice as long.", "the cheese's alternative")


# --- the vinegar pickle (Brendan's "both vinegar and salt", 2026-10-07) -------------------------------------------------

func test_vinegar_and_pickles_are_the_approved_rows() -> void:
	"""PROVISIONAL, beyond the library by approval: apple vinegar apples 4 + water 1 -> 4, 16 WU + 96 h in a vat; pickles
	roots 3 + vinegar 1 -> 3, 12 WU + 24 h in a crock, NO SALT; vinegar never eaten, pickles at 800 NP, keeping 720 h."""
	var v: int = Recipes.R_VINEGAR
	var p: int = Recipes.R_PICKLES
	assert_equal([Recipes.IN_CATEGORY[Recipes.IN_FIRST[v]], Recipes.IN_MILLI[Recipes.IN_FIRST[v]], Recipes.WATER_MILLI[v],
		Recipes.OUT_MILLI[v], Recipes.WORK_MWU[v], Recipes.PASSIVE_HOURS[v], Recipes.STATION[v]],
		[Recipes.SEL_APPLE, 4000, 1000, 4000, 16000, 96, Recipes.STATION_BREWERY], "vinegar")
	assert_equal([Recipes.IN_CATEGORY[Recipes.IN_FIRST[p]], Recipes.IN_MILLI[Recipes.IN_FIRST[p]],
		Recipes.IN_CATEGORY[Recipes.IN_FIRST[p] + 1], Recipes.IN_MILLI[Recipes.IN_FIRST[p] + 1], Recipes.IN_COUNT[p],
		Recipes.WATER_MILLI[p], Recipes.OUT_MILLI[p], Recipes.WORK_MWU[p], Recipes.PASSIVE_HOURS[p], Recipes.STATION[p]],
		[FarmingScript.CROP_ROOTS, 3000, Catalog.CAT_VINEGAR, 1000, 2, 0, 3000, 12000, 24, Recipes.STATION_TABLE], "pickles")
	assert_equal(Catalog.ITEM_KEYS.slice(40, 42), [&"vinegar", &"pickles"], "appended")
	assert_equal([MealRules.raw_np_per_u(40), MealRules.raw_np_per_u(41)], [0, 800], "vinegar never eaten")
	assert_equal([Catalog.shelf_hours_of(40), Catalog.shelf_hours_of(41)], [1440, 720], "shelf")
	assert_false(MenuScript.DRINK_ITEMS.has(Catalog.ITEM_VINEGAR), "never poured at a feast")


func test_apples_sour_into_vinegar_and_roots_pickle_in_it() -> void:
	"""Apples 4 into a vat for 96 h: 4 U of vinegar; then onions 3 and that vinegar 1 into a crock for 24 h: 3 U of
	pickles -- no salt anywhere."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_APPLE, 4000, 0, _read)
	assert_equal(f.batch_refusal(Recipes.R_PICKLES).begins_with("the stores hold 0 U of roots"), true, "no roots yet")
	assert_equal([f.refused_code, f.refused_fix], ["NO_ROOTS", Recipes.IN_FIX[14]], "the roots' code and fix")
	assert_equal(f.order_batch(Recipes.R_VINEGAR, PackedInt32Array([1])), "", "vinegar ordered")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_VAT] == Tables.SLOT_CURING), "souring")
	rig.calendar.tick += 96 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_VINEGAR) == 4000), "4 U of vinegar")
	rig.pantry.add_into(5, 3000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_PICKLES, PackedInt32Array([2])), "", "pickles ordered")
	assert_equal(f.tables.s_recipe[FIRST_CROCK], Recipes.R_PICKLES, "into a crock")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_CROCK] == Tables.SLOT_CURING), "pickling")
	assert_equal([rig.pantry.milli_of(5), rig.pantry.milli_of(Catalog.ITEM_VINEGAR)], [0, 3000], "onions 3, vinegar 1")
	rig.calendar.tick += 24 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_PICKLES) == 3000), "3 U of pickles")
	assert_equal(f.preserves_stored_milli, 3000, "booked as a preserve")


func test_pickles_without_vinegar_say_so() -> void:
	"""Roots but no vinegar: refused with the way to make it."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(5, 3000, 0, _read)
	assert_true(f.batch_refusal(Recipes.R_PICKLES).contains("of vinegar nobody has set aside"), f.batch_refusal(Recipes.R_PICKLES))
	assert_equal([f.refused_code, f.refused_fix], ["NO_VINEGAR", Recipes.IN_FIX[15]], "its code and fix")


func test_the_guide_calls_vinegar_an_ingredient() -> void:
	"""Vinegar is an ingredient, never a drink; pickles are a reserve with their own alternative."""
	assert_equal(PreserveText.guide_fields(Catalog.ITEM_VINEGAR, 0)[0], PreserveText.VINEGAR_USE, "vinegar")
	assert_true(PreserveText.guide_fields(Catalog.ITEM_VINEGAR, 0)[2].contains("kept for pickling"), "not a drink's alternative")
	assert_true(PreserveText.guide_fields(Catalog.ITEM_PICKLES, 800)[0].contains("800 NP"), "pickles")
	assert_true(PreserveText.guide_fields(Catalog.ITEM_PICKLES, 800)[2].contains("keep 240 game hours; pickled they keep 720"), "their alternative")


func test_the_recipe_card_says_what_each_good_is_for() -> void:
	"""Vinegar's card says it is kept for pickling, not for feasts; pickles are eaten; the drinks are kept for feasts (the
	live harness checks the card itself)."""
	assert_equal([PreserveText.card_use(Recipes.R_VINEGAR), PreserveText.card_use(Recipes.R_PICKLES),
		PreserveText.card_use(Recipes.R_ALE), PreserveText.card_use(Recipes.R_JAM)],
		["kept for pickling", "eaten as it is", "kept for feasts", "eaten as it is"], "uses")


# --- every ingredient's uses come from the recipe rows (Brendan, 2026-10-07: "fix the crop card Uses: gaps") --------------

const ROWS_TAKING: Dictionary = {
	Catalog.ITEM_APPLE: [Recipes.R_DRY_FRUIT, Recipes.R_CIDER, Recipes.R_VINEGAR],
	Catalog.ITEM_PEAR: [Recipes.R_DRY_FRUIT],
	Catalog.ITEM_HONEY: [Recipes.R_MEAD, Recipes.R_CORDIAL, Recipes.R_JAM],
	Catalog.ITEM_NUTS: [Recipes.R_RATION, Recipes.R_CHEESE],
	Catalog.ITEM_BERRIES: [Recipes.R_CORDIAL, Recipes.R_JAM],
	Catalog.ITEM_BARLEY: [Recipes.R_ALE],
	Catalog.ITEM_FLOUR: [Recipes.R_RATION],
	Catalog.ITEM_DRIED_FISH: [Recipes.R_RATION],
	Catalog.ITEM_VINEGAR: [Recipes.R_PICKLES],
	0: [Recipes.R_PICKLES],
	5: [Recipes.R_PICKLES],
}


func test_each_ingredient_feeds_the_rows_that_take_it() -> void:
	"""Apples: dried fruit, cider, vinegar; pears: dried fruit; honey: mead, cordial, jam; nuts: rations, cheese; berries:
	cordial, jam; barley: ale (oats and wheat not); roots (radish, onion): pickles; the catch: none (the fish row's text
	is its own)."""
	for item: int in ROWS_TAKING:
		assert_equal(Array(Recipes.rows_taking(item)), ROWS_TAKING[item], Catalog.ITEM_KEYS[item])
	for item: int in [13, 15, Catalog.FIRST_CATCH, Catalog.ITEM_MEAD]:
		assert_true(Recipes.rows_taking(item).is_empty(), "%s feeds no row" % Catalog.ITEM_KEYS[item])


func test_the_crop_cards_list_the_stations() -> void:
	"""The bed picker's Uses: roots list the preserving table's pickles, barley the brewery's ale; oats neither; raw
	stays last."""
	var radish: PackedStringArray = CropRoles.uses_of(0)
	assert_true(radish.has("the preserving table (pickles)"), ", ".join(radish))
	assert_equal(radish[radish.size() - 1], CropRoles.RAW_USE, "raw last")
	assert_true(CropRoles.uses_of(Catalog.ITEM_BARLEY).has("the brewery (ale)"), CropRoles.uses_text(Catalog.ITEM_BARLEY))
	assert_false(CropRoles.uses_text(15).contains("ale"), "oats make no ale")


func test_no_use_can_drift_from_the_rows() -> void:
	"""Every pantry item a row takes says so: a crop's card and guide entry, every other good's guide entry, naming
	each row's output and linking to it."""
	var guide := FieldGuideScript.new()
	for item: int in Catalog.PANTRY_ITEM_COUNT:
		var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.item_id(item)))
		for recipe: int in Recipes.rows_taking(item):
			var good: String = PreserveText.good_words(recipe)
			assert_true(entry.uses.contains(good), "%s's guide names %s: %s" % [Catalog.ITEM_KEYS[item], good, entry.uses])
			assert_true(entry.links.has(FieldGuideScript.item_id(Recipes.OUT_ITEM[recipe])), "and links it")
			if Catalog.is_item(item):
				assert_true(CropRoles.uses_text(item).contains("(%s)" % good), "%s's card" % Catalog.ITEM_KEYS[item])


func test_the_guide_says_what_the_apple_and_honey_make() -> void:
	"""The apple's entry no longer says no dish cooks it; honey's names the jam."""
	var guide := FieldGuideScript.new()
	var apple: String = guide.entry(guide.index_of(FieldGuideScript.item_id(Catalog.ITEM_APPLE))).uses
	assert_true(apple.contains("Made into: dried fruit at the rack; cider at the brewery; apple vinegar at the brewery."), apple)
	assert_false(apple.contains("No demo dish"), "not 'no dish'")
	var honey: String = guide.entry(guide.index_of(FieldGuideScript.item_id(Catalog.ITEM_HONEY))).uses
	assert_true(honey.contains("berry jam at the preserving table"), honey)
	var onion: String = guide.entry(guide.index_of(FieldGuideScript.crop_id(5))).uses
	assert_true(onion.contains("made into pickles at the preserving table"), onion)
