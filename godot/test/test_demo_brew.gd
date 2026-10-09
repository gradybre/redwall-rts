extends "res://test/framework/test_case.gd"
## Brewing (decision 1621, BREW #19): GDD §5.7's `mead` in the brewery's four vats (§5.9's Brewery) and Brendan's DEC-045
## raspberry cordial at its bench, through the fishery's station jobs on real brains walking the real layout; the drinks
## as pantry items (never eaten raw: "feast ingredient only; no intoxication subsystem"); the vats beside the rack's
## slots; and the regatta's feast pouring them proportionally, never required for Shared Warmth.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
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
const PropsScript := preload("res://demo/props/demo_props.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 6000
const FIRST_VAT: int = 4

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


func tolerates_outside_tree() -> bool:
	"""The fishery's view is driven outside the scene tree (its particles' transforms)."""
	return true


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


func _menu_over(pantry: PantryScript) -> MenuScript:
	"""The regatta's menu over a bare kitchen (its takes) on `pantry` and the demo's stores."""
	var kitchen := KitchenScript.new()
	kitchen.pantry = pantry
	kitchen.stores = _services.stores
	var menu := MenuScript.new()
	menu.configure(kitchen, _services.stores)
	return menu


# --- the numbers -----------------------------------------------------------------------------------------------------------

func test_mead_is_the_gdds_row_and_the_cordial_is_dec_045s() -> void:
	"""§5.7 mead: honey 3, water 3 -> 4, 20 WU + 72 h, Brewery, 1440 h. The cordial: dish_book.gd's row exactly -- berries
	2, honey 0.5, water 2 -> 4 portions, 10 WU, 240 h (decision 1733; it was 72 h)."""
	var m: int = Recipes.R_MEAD
	assert_equal([Recipes.IN_CATEGORY[Recipes.IN_FIRST[m]], Recipes.IN_MILLI[Recipes.IN_FIRST[m]], Recipes.WATER_MILLI[m],
		Recipes.OUT_MILLI[m], Recipes.WORK_MWU[m], Recipes.PASSIVE_HOURS[m], Recipes.STATION[m]],
		[Catalog.CAT_HONEY, 3000, 3000, 4000, 20000, 72, Recipes.STATION_BREWERY], "§5.7 mead")
	assert_equal(Catalog.shelf_hours_of(Catalog.ITEM_MEAD), 1440, "mead keeps 1440 h")
	var c: int = Recipes.R_CORDIAL
	var dish: int = MealRules.DISH_CORDIAL
	assert_equal([Recipes.IN_MILLI[Recipes.IN_FIRST[c]], Recipes.IN_MILLI[Recipes.IN_FIRST[c] + 1]],
		[MealRules.input_milli(dish, 0), MealRules.input_milli(dish, 1)], "the dish's berries and honey")
	assert_equal([Recipes.IN_CATEGORY[Recipes.IN_FIRST[c]], Recipes.IN_CATEGORY[Recipes.IN_FIRST[c] + 1]],
		[MealRules.input_category(dish, 0), MealRules.input_category(dish, 1)], "by category")
	assert_equal([Recipes.WATER_MILLI[c], Recipes.OUT_MILLI[c], Recipes.WORK_MWU[c], Catalog.shelf_hours_of(Catalog.ITEM_CORDIAL)],
		[MealRules.WATER_MILLI[dish], MealRules.PORTIONS_PER_BATCH[dish] * 1000, MealRules.WORK_MWU[dish],
		MealRules.SHELF_HOURS[dish]], "its water, portions, work and shelf")
	assert_false(Recipes.is_passive(c), "made at the bench, no wait")


func test_the_drinks_are_appended_and_never_eaten() -> void:
	"""Mead (34) and the cordial (35) appended; neither is a meal or raw food (§5.7 mead: "No"; the cordial a drink)."""
	assert_equal([Catalog.ITEM_KEYS[34], Catalog.ITEM_KEYS[35]], [&"mead", &"cordial"], "appended")
	assert_equal(Catalog.ITEM_KEYS.size(), Catalog.PANTRY_ITEM_COUNT, "every item keyed")
	assert_equal([Catalog.category_of(34), Catalog.category_of(35)], [Catalog.CAT_MEAD, Catalog.CAT_CORDIAL], "categories")
	assert_equal([MealRules.raw_np_per_u(34), MealRules.raw_np_per_u(35)], [0, 0], "never eaten raw")
	assert_equal([MealRules.CATEGORY_WORDS[16], MealRules.CATEGORY_WORDS[17]], ["mead", "cordial"], "words")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/farm/pantry_index.json"))
	assert_equal((index["items"] as Array).size(), Catalog.PANTRY_ITEM_COUNT, "the index has every item")


func test_the_vats_follow_the_racks_slots() -> void:
	"""§5.9's Brewery: four vats, after the rack's four slots in the one slot table."""
	assert_equal(Recipes.SLOT_COUNT, 10, "the rack's four, the vats' four, the crocks' two (decision 1625)")
	assert_equal([Recipes.station_of_slot(0), Recipes.station_of_slot(3), Recipes.station_of_slot(FIRST_VAT),
		Recipes.station_of_slot(7)], [Recipes.STATION_RACK, Recipes.STATION_RACK, Recipes.STATION_BREWERY,
		Recipes.STATION_BREWERY], "the rack's, then the vats")
	var rig := _rig()
	assert_equal(rig.fishery.tables.s_state.size(), Recipes.SLOT_COUNT, "the table sized for both")
	assert_equal([rig.fishery.free_slot(Recipes.STATION_RACK), rig.fishery.free_slot(Recipes.STATION_BREWERY),
		rig.fishery.free_slot(Recipes.STATION_TABLE)], [0, FIRST_VAT, 8], "each station's first free slot")


# --- brewing ---------------------------------------------------------------------------------------------------------------------

func test_mead_brews_in_a_vat_for_seventy_two_hours() -> void:
	"""Honey 3 set aside at the order, withdrawn with 3 U of water as the work starts, 20 WU, then 72 h in a vat with the
	brewer free, then drawn off: 4 U of mead stored; the steam rises only while it brews."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_HONEY, 5000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_MEAD, PackedInt32Array([1])), "", "ordered")
	assert_equal(f.tables.s_recipe[FIRST_VAT], Recipes.R_MEAD, "the first vat")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_VAT] == Tables.SLOT_CURING), "brewing")
	assert_equal(rig.pantry.milli_of(Catalog.ITEM_HONEY), 2000, "3 U of honey withdrawn")
	assert_equal(_services.stores.water_milli_u, 17000, "3 U of water")
	assert_equal(f.brewing(), 1, "one vat brewing")
	rig.pantry.add_into(Catalog.ITEM_HONEY, 3000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_MEAD, PackedInt32Array()), "", "a second batch")
	assert_equal(f.tables.s_recipe[FIRST_VAT + 1], Recipes.R_MEAD, "into the next vat, the brewing one untouched")
	assert_equal(f.tables.s_state[FIRST_VAT], Tables.SLOT_CURING, "still brewing")
	f.cancel_job(f.tables.j_live.find(1))
	rig.calendar.tick += 72 * SimClock.TICKS_PER_HOUR
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_MEAD) == 4000), "4 U of mead")
	assert_equal([f.batch_in_milli[Recipes.R_MEAD], f.batch_out_milli[Recipes.R_MEAD]], [3000, 4000], "booked")
	assert_equal(f.tables.s_state[FIRST_VAT], Tables.SLOT_EMPTY, "the vat free")
	assert_equal(f.brewing(), 0, "none brewing")


func test_the_vats_are_four_and_say_so_when_full() -> void:
	"""Four batches fill the vats; a fifth is refused in words; the rack's slots are untouched."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_HONEY, 15000, 0, _read)
	for k: int in Recipes.VAT_SLOTS:
		assert_equal(f.order_batch(Recipes.R_MEAD, PackedInt32Array()), "", "vat %d" % k)
	assert_equal(f.batch_refusal(Recipes.R_MEAD), "all 4 vats are brewing", "full")
	assert_equal(f.refused_code, "VATS_FULL", "its code")
	assert_equal(f.free_slot(Recipes.STATION_RACK), 0, "the rack still free")


func test_the_cordial_is_made_at_the_bench() -> void:
	"""Berries 2, honey 0.5 and water 2 at the brewery's bench, 10 WU: 4 U of the raspberry cordial stored."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_BERRIES, 3000, 0, _read)
	rig.pantry.add_into(Catalog.ITEM_HONEY, 1000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_CORDIAL, PackedInt32Array([2])), "", "ordered")
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.tables.j_at[j] == 1 and f.step_of(j) == FisheryScript.S_STATION), "at the bench")
	assert_false(f.packing(), "the cordial is not rations being packed")
	assert_true(_run(rig, func() -> bool: return rig.pantry.milli_of(Catalog.ITEM_CORDIAL) == 4000), "4 U of cordial")
	assert_equal([rig.pantry.milli_of(Catalog.ITEM_BERRIES), rig.pantry.milli_of(Catalog.ITEM_HONEY)], [1000, 500], "its food")
	assert_equal(_services.stores.water_milli_u, 18000, "2 U of water")
	assert_equal(f.brewing(), 0, "no vat used")


func test_brewing_says_what_is_missing() -> void:
	"""No honey: refused with the apiary as its fix; berries short for the cordial: berries named."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	assert_true(f.batch_refusal(Recipes.R_MEAD).begins_with("the stores have no honey free; a batch takes 3 jars of honey"),
		f.batch_refusal(Recipes.R_MEAD))
	assert_equal([f.refused_code, f.refused_fix], ["NO_HONEY", Recipes.IN_FIX[5]], "the apiary")
	rig.pantry.add_into(Catalog.ITEM_HONEY, 1000, 0, _read)
	assert_true(f.batch_refusal(Recipes.R_CORDIAL).begins_with("the stores have no berries free; a batch takes 2 bowls of berries"),
		"the cordial's berries")
	assert_equal(f.refused_code, "NO_BERRIES", "its code")


func test_the_brewery_is_drawn_and_steams() -> void:
	"""The vat and the cask stand at the brewery (placeholders unstaged); the jobs' words are the brewer's."""
	var rig := _rig()
	var view: FisheryViewScript = _keep(FisheryViewScript.new()) as FisheryViewScript
	view.configure(rig.fishery, PropsScript.new())
	assert_true(view.has_node(NodePath("Preserves_brew_vat")) and view.has_node(NodePath("Preserves_ale_cask")), "both drawn")
	rig.pantry.add_into(Catalog.ITEM_HONEY, 3000, 0, _read)
	rig.fishery.order_batch(Recipes.R_MEAD, PackedInt32Array())
	assert_equal([rig.fishery.job_words(0), rig.fishery.job_label(0), rig.fishery.place_words(0)],
		["Brew mead", "Brewing mead", "the food set aside"], "the brewer's words")
	assert_true(rig.fishery.spot(&"brewery").distance_to(Recipes.BREWERY_AT) < 2.0, "the brewery's spot")


# --- the feast's drinks ---------------------------------------------------------------------------------------------------------

func test_the_feast_pours_the_drinks_it_holds() -> void:
	"""At confirmation the drinks the pantry holds enough of are set aside (ceil(E/4) U); at the supper's end they are
	poured for those who came (floor(total x attended / E)) and the rest given back; a drink short is not poured."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	assert_true(pantry.add_into(Catalog.ITEM_MEAD, 5000, 0, _read), "mead in store")
	var menu := _menu_over(pantry)
	assert_equal(MenuScript.drink_need_milli(9), 3000, "ceil(9/4) = 3 U")
	assert_true(menu.drinks_words(9).contains("mead 3.0 U (free 5.0 U)"), menu.drinks_words(9))
	assert_true(menu.drinks_words(9).contains("cordial 3.0 U (free 0.0 U) — not poured"), "the cordial short")
	menu.reserve(menu.kitchen.takes.new_take(), 9, 0)
	assert_equal(Array(menu.drinks_planned), [3000, 0, 0, 0], "mead set aside, no cordial, ale or cider")
	assert_equal(menu.free_drink(0), 2000, "3 U of mead reserved")
	menu.settle(9, 6, 6, 1000, 0)
	assert_equal(menu.drinks_poured_milli[0], 2000, "two-thirds of it, for 6 of 9")
	assert_equal(pantry.milli_of(Catalog.ITEM_MEAD), 3000, "the rest in store")
	assert_equal(menu.free_drink(0), 3000, "and given back")
	assert_equal(menu.drink_take, 0, "the take released")


func test_drinks_never_decide_shared_warmth() -> void:
	"""With every course served and 80% come, Shared Warmth is granted with no drink in store at all."""
	var menu := _menu_over(PantryScript.new(StorageScript.new(Vector2.ZERO)))
	menu.second_planned = true
	menu.infusion_planned = true
	assert_true(menu.settle(9, 0, 8, 1000, 0).contains("48 h"), "granted")
	assert_equal(Array(menu.drinks_poured_milli), [0, 0, 0, 0], "nothing poured")


func test_the_guide_has_the_drinks() -> void:
	"""The field guide's mead and cordial: a feast drink, how it is brewed, no one made drunk."""
	var guide := FieldGuideScript.new()
	for item: int in [Catalog.ITEM_MEAD, Catalog.ITEM_CORDIAL]:
		var entry: FieldGuideScript.Entry = guide.entry(guide.index_of(FieldGuideScript.item_id(item)))
		assert_equal(entry.summary, PreserveText.summary(item), Catalog.ITEM_KEYS[item])
	var fields: PackedStringArray = PreserveText.guide_fields(Catalog.ITEM_MEAD, 0)
	assert_true(fields[0].contains("No one is made drunk"), fields[0])
	assert_true(fields[1].contains("honey 3.0 U, water 3.0 U make 4.0 U, 20 WU and 72 hours at the brewery"), fields[1])
	assert_equal(fields[2], PreserveText.DRINK_ALTERNATIVE, "the infusion")


func test_a_mead_batch_cancelled_after_it_started_spoils_half_its_honey() -> void:
	"""REQ-SET-094 by the row's own food: half of mead's 3 U of honey (not of another row's 4 U) becomes spoiled food."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_HONEY, 3000, 0, _read)
	f.order_batch(Recipes.R_MEAD, PackedInt32Array([1]))
	var j: int = f.tables.j_live.find(1)
	assert_true(_run(rig, func() -> bool: return f.tables.j_started[j] == 1), "started")
	assert_equal(f.cancel_job(j), "", "cancelled while working")
	assert_equal(rig.pantry.spoiled_milli, 1500, "half the 3 U")
	assert_equal(f.tables.s_state[FIRST_VAT], Tables.SLOT_EMPTY, "the vat free")


func test_the_vat_steams_and_the_rack_smokes_each_for_its_own() -> void:
	"""Mead brewing: steam over the vat, no smoke at the rack; a fish batch curing: smoke at the rack, no steam."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	var view: FisheryViewScript = _keep(FisheryViewScript.new()) as FisheryViewScript
	view.configure(f, PropsScript.new())
	rig.pantry.add_into(Catalog.ITEM_HONEY, 3000, 0, _read)
	assert_equal(f.order_batch(Recipes.R_MEAD, PackedInt32Array([1])), "", "mead ordered")
	assert_equal(f.brewing(), 1, "a vat taken from the order")
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[FIRST_VAT] == Tables.SLOT_CURING), "brewing")
	view.refresh()
	assert_true((view.get("_steam") as CPUParticles3D).emitting, "steam over the vat")
	assert_false((view.get("_smoke") as CPUParticles3D).emitting, "no smoke at the rack")
	rig.pantry.add_into(Catalog.FIRST_CATCH, 4000, 0, _read)
	f.order_batch(Recipes.R_DRY_FISH, PackedInt32Array([2]))
	assert_true(_run(rig, func() -> bool: return f.tables.s_state[0] == Tables.SLOT_CURING), "fish hung")
	view.refresh()
	assert_true((view.get("_smoke") as CPUParticles3D).emitting, "smoke at the rack")


func test_each_batch_takes_its_own_vat_and_the_brewers_go_to_the_brewery() -> void:
	"""Two mead batches take the first two vats; the brewer of each walks to the brewery, the cordial's maker too."""
	var rig := _rig()
	var f: FisheryScript = rig.fishery
	rig.pantry.add_into(Catalog.ITEM_HONEY, 7000, 0, _read)
	rig.pantry.add_into(Catalog.ITEM_BERRIES, 2000, 0, _read)
	f.order_batch(Recipes.R_MEAD, PackedInt32Array())
	f.order_batch(Recipes.R_MEAD, PackedInt32Array())
	f.order_batch(Recipes.R_CORDIAL, PackedInt32Array())
	assert_equal([f.tables.s_recipe[FIRST_VAT], f.tables.s_recipe[FIRST_VAT + 1]], [Recipes.R_MEAD, Recipes.R_MEAD], "two vats")
	assert_equal(f.tables.s_state[FIRST_VAT + 1], Tables.SLOT_LOADING, "the second loading")
	for j: int in 3:
		f.tables.j_pos[j] = 1
		assert_true(f.goal_point(j).distance_to(Recipes.BREWERY_AT) < 2.0, "job %d at the brewery" % j)
	assert_false(f.packing(), "nobody packs rations")


func test_the_stations_stand_clear_of_the_village() -> void:
	"""The preserving table's and the brewery's props overlap no building, rock or tree of the world."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	for mine: Vector3 in Recipes.land_obstacles():
		for theirs: Vector3 in world.obstacles():
			var gap: float = Vector2(mine.x, mine.z).distance_to(Vector2(theirs.x, theirs.z))
			assert_true(gap >= mine.y + theirs.y, "(%.1f, %.1f) clear of (%.1f, %.1f)" % [mine.x, mine.z, theirs.x, theirs.z])


func test_each_drink_category_holds_one_item() -> void:
	"""The feast reserves a drink by its category: each category is that one drink (§5.7: concrete lots, one item)."""
	for item: int in [Catalog.ITEM_MEAD, Catalog.ITEM_CORDIAL]:
		var n: int = 0
		for other: int in Catalog.PANTRY_ITEM_COUNT:
			n += 1 if Catalog.category_of(other) == Catalog.category_of(item) else 0
		assert_equal(n, 1, Catalog.ITEM_KEYS[item])


func test_both_drinks_pour_for_those_who_came_and_holding_again_resets() -> void:
	"""Mead and cordial both reserved and poured two-thirds for 6 of 9; held again with no drink in store, nothing is
	planned or poured; drinks poured or not, Shared Warmth is decided by the courses alone."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	pantry.add_into(Catalog.ITEM_MEAD, 3000, 0, _read)
	pantry.add_into(Catalog.ITEM_CORDIAL, 3000, 0, _read)
	var menu := _menu_over(pantry)
	menu.reserve(menu.kitchen.takes.new_take(), 9, 0)
	menu.second_planned = true
	menu.infusion_planned = true
	var warmth: String = menu.settle(9, 6, 6, 1000, 0)
	assert_equal(Array(menu.drinks_poured_milli), [2000, 2000, 0, 0], "both, for 6 of 9")
	var dry := _menu_over(PantryScript.new(StorageScript.new(Vector2.ZERO)))
	dry.second_planned = true
	dry.infusion_planned = true
	assert_equal(warmth, dry.settle(9, 6, 6, 1000, 0), "the same answer with no drink at all")
	menu.reserve(menu.kitchen.takes.new_take(), 9, 0)
	assert_equal(Array(menu.drinks_planned), [0, 0, 0, 0], "too little left: nothing planned")
	menu.settle(9, 9, 9, 2000, 0)
	assert_equal(Array(menu.drinks_poured_milli), [2000, 2000, 0, 0], "nothing more poured")


func test_a_drink_partly_spoiled_since_the_hold_pours_what_is_left() -> void:
	"""The cordial keeps 240 h: one lot spoiled between the hold and the feast, the rest is still poured."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	pantry.add_into(Catalog.ITEM_CORDIAL, 1000, 0, _read)
	var old: int = _read.value
	pantry.add_into(Catalog.ITEM_CORDIAL, 2000, 0, _read)
	var menu := _menu_over(pantry)
	menu.reserve(menu.kitchen.takes.new_take(), 9, 0)
	assert_equal(menu.drinks_planned[1], 3000, "3 U set aside")
	assert_true(pantry.withdraw_into(old, pantry.lot_serial(old), 1000, _read), "one lot gone")
	menu.settle(9, 9, 9, 1000, 0)
	assert_equal(menu.drinks_poured_milli[1], 2000, "what was left poured")
	assert_equal(pantry.milli_of(Catalog.ITEM_CORDIAL), 0, "none left")
